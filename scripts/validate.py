from pathlib import Path
import concurrent.futures
import hashlib
import json
import re
import subprocess
import sys, argparse, shutil
from pack_options import load_profiles

parser=argparse.ArgumentParser(description='Compile all shader profiles and fallback configurations.')
parser.add_argument('--glslang',default=shutil.which('glslangValidator') or shutil.which('glslang'))
parser.add_argument('--output',type=Path,default=Path('.validation/glsl'))
args=parser.parse_args()
if not args.glslang:parser.error('Pass --glslang /path/to/glslangValidator')
W=Path(__file__).resolve().parents[1]
S=W/'shaders'
COMPILER=Path(args.glslang).resolve()
TEST=args.output.resolve()
TEST.mkdir(parents=True,exist_ok=True)
PROFILES = load_profiles(S)
PROFILES['ALL_EFFECTS_OFF'] = dict(SHADOWS=False, AO_SAMPLES='0', CLOUD_QUALITY='0', WAVING_FOLIAGE=False, HAND_LIGHT=False, BLOOM=False, FXAA=False, WATER_DETAIL='0', WATER_SSR_STEPS='0', WATER_REFRACTION='0.0', WATER_WAVES='0.0', WATER_FOAM='0.0', WATER_CAUSTICS='0.0', WATER_CLOUD_REFLECTION=False, WATER_RAIN_RIPPLES=False)
PROFILES['OPTION_EXTREMES'] = dict(SHADOW_SOFTNESS='2.5', AO_SAMPLES='12', AO_STRENGTH='1.0', CLOUD_QUALITY='3', CLOUD_COVERAGE='0.65', WATER_DETAIL='3', WATER_WAVES='1.4', WATER_DENSITY='2.0', WATER_REFRACTION='1.0', WATER_SSR_STEPS='40', WATER_SSR_DISTANCE='64.0', WATER_FOAM='0.75', WATER_CAUSTICS='0.4', WIND_STRENGTH='1.4', EXPOSURE='1.5', SATURATION='1.2', FOG_DENSITY='1.5', NIGHT_BRIGHTNESS='0.6', VIGNETTE_STRENGTH='0.25', WATER_CLOUD_REFLECTION=True, WATER_RAIN_RIPPLES=True)
PROFILES['OPTION_EXTREMES']=PROFILES['ULTRA']|PROFILES['OPTION_EXTREMES']|dict(VOXEL_STRENGTH='1.5',VOLUMETRIC_STEPS='32',VOLUMETRIC_DENSITY='2.0',SURFACE_SSR_STEPS='40',DOF_STRENGTH='1.0',BLOOM_STRENGTH='0.3')
PROFILES['VOXEL_WITHOUT_SHADOWS']=PROFILES['ULTRA']|dict(SHADOWS=False,SHADOW_PCSS=False)
PROFILES['VOXEL_NO_MATERIAL_EFFECTS']=PROFILES['ULTRA']|dict(COLORED_LIGHT_BOUNCE=False,COLORED_LIGHT_TRANSMISSION=False)
PROFILES['OPTION_EXTREMES'].update(LIGHT_BOUNCE_STRENGTH='1.25',GLASS_TINT_STRENGTH='0.35')
for name,settings in list(PROFILES.items())[:4]:
    PROFILES['LEGACY_'+name]=settings|{'_legacy':True,'LEGACY_LEFT_HAND':True}
INCLUDE = re.compile(r'^\s*#include\s+"([^"]+)"\s*$',re.M)
DEFINE = re.compile(r'^(\s*#define\s+)(\w+)([^\n]*)$',re.M)
CONST = re.compile(r'^(\s*const\s+(?:int|float)\s+)(\w+)(\s*=\s*)([^;]+)(;[^\n]*)$',re.M)

def expand(file,stack=()):
    file=file.resolve()
    assert file.is_relative_to(S.resolve()),f'Include outside pack: {file}'
    assert file not in stack,f'Include cycle: {file}'
    src=file.read_text(encoding='utf-8')
    def include(match):
        p=match.group(1)
        target=S/p.lstrip('/') if p.startswith('/') else file.parent/p
        assert target.is_file(),f'Missing {p} in {file}'
        return expand(target,stack+(file,))
    return INCLUDE.sub(include,src)

def configure(src,settings):
    for key,value in settings.items():
        if value is True:
            src=re.sub(r'^\s*//\s*#define\s+'+re.escape(key)+r'([^\n]*)$',r'#define '+key+r'\1',src,flags=re.M)
    def define(m):
        key=m.group(2)
        if key not in settings: return m.group(0)
        v=settings[key]
        if isinstance(v,bool): return m.group(1)+key if v else '// disabled: '+key
        return m.group(1)+key+' '+str(v)+' // validation override'
    def constant(m):
        v=settings.get(m.group(2))
        return m.group(1)+m.group(2)+m.group(3)+str(v)+m.group(5) if v is not None else m.group(0)
    src=CONST.sub(constant,DEFINE.sub(define,src))
    capabilities=''.join('#define IRIS_FEATURE_'+flag+'\n' for flag in (['CUSTOM_IMAGES','COMPUTE_SHADERS'] if settings.get('_legacy') else ['CUSTOM_IMAGES','COMPUTE_SHADERS','REVERSED_CULLING','BLOCK_EMISSION_ATTRIBUTE']))
    src=re.sub(r'^(#version[^\n]*\n)',lambda m:m[1]+capabilities,src,count=1)
    return src

jobs={}
references=[]
compute_references=[]
compute_jobs={}
for profile,settings in PROFILES.items():
    for vertex in sorted(p for p in S.rglob('*.vsh') if p.parent.name != 'lib'):
        fragment=vertex.with_suffix('.fsh')
        assert fragment.is_file(),f'Missing fragment: {fragment}'
        a=configure(expand(vertex),settings)
        b=configure(expand(fragment),settings)
        digest=hashlib.sha256((a+'\0'+b).encode()).hexdigest()[:20]
        jobs[digest]=(a,b)
        references.append((profile,vertex.relative_to(S).as_posix(),digest))
    for compute in sorted(p for p in S.rglob('*.csh') if p.parent.name!='lib'):
        a=configure(expand(compute),settings)
        digest=hashlib.sha256(a.encode()).hexdigest()[:20]
        compute_jobs[digest]=a
        compute_references.append((profile,compute.relative_to(S).as_posix(),digest))

def compile_job(item):
    digest,(a,b)=item
    v=TEST/(digest+'.vert'); f=TEST/(digest+'.frag')
    v.write_text(a,encoding='utf-8'); f.write_text(b,encoding='utf-8')
    proc=subprocess.run([str(COMPILER),'-l',str(v),str(f)],capture_output=True,text=True)
    return digest,proc.returncode,proc.stdout+proc.stderr

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    compiled=list(pool.map(compile_job,jobs.items()))
failed={d:log for d,code,log in compiled if code}
def compile_compute(item):
    digest,a=item
    p=TEST/(digest+'.comp');p.write_text(a,encoding='utf-8')
    proc=subprocess.run([str(COMPILER),str(p)],capture_output=True,text=True)
    return digest,proc.returncode,proc.stdout+proc.stderr
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    compute_compiled=list(pool.map(compile_compute,compute_jobs.items()))
compute_failed={d:log for d,code,log in compute_compiled if code}
report={'compiler':subprocess.check_output([str(COMPILER),'--version'],text=True).splitlines()[0],
        'profiles':list(PROFILES),'program_pairs_per_configuration':len([p for p in S.rglob('*.vsh') if p.parent.name != 'lib']),
        'program_configurations_checked':len(references),'unique_source_pairs':len(jobs),
        'failed_pairs':len(failed),
        'compute_configurations_checked':len(compute_references),'unique_compute_sources':len(compute_jobs),'failed_compute':len(compute_failed),
        'scope':'Offline GLSL 4.30 compatibility graphics and compute syntax, vertex/fragment link, includes. No injected format definitions. Not Minecraft runtime or performance.'}
(TEST/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
if failed or compute_failed:
    for digest,log in list(compute_failed.items())[:2]:print('COMPUTE FAILED',digest,log)
    all_failures=failed.copy()
    (TEST/'errors.json').write_text(json.dumps(all_failures,indent=2),encoding='utf-8')
    shown=0
    for profile,path,digest in references:
        if digest in failed:
            print('\nFAILED',profile,path,'\n',failed.pop(digest))
            shown+=1
            if not failed or shown>=4: break
    sys.exit(1)
