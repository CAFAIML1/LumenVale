"""Execute original Iris option/property/JCPP code for the pinned official releases."""
from pathlib import Path
import os,re,json,subprocess,hashlib,concurrent.futures,argparse,shutil,urllib.request,zipfile
from pack_options import load_profiles
ROOT=Path(__file__).resolve().parents[1];S=ROOT/'shaders';HOST=ROOT/'scripts/iris_test'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cache',type=Path,default=ROOT/'.validation/iris')
parser.add_argument('--iris-jars',type=Path,help='Reuse an existing directory of official release JARs.')
parser.add_argument('--java-bin',type=Path,default=Path(shutil.which('java') or 'java').resolve().parent)
parser.add_argument('--glslang',help='Optional GLSL compiler executable; otherwise compilation is marked skipped.')
args=parser.parse_args();T=args.cache.resolve();T.mkdir(parents=True,exist_ok=True)
JAVA=args.java_bin
java=JAVA/('java.exe' if os.name=='nt' else 'java');javac=JAVA/('javac.exe' if os.name=='nt' else 'javac')
DEPENDENCIES=[{'path': 'com/google/guava/guava/31.1-jre/guava-31.1-jre.jar', 'sha256': 'a42edc9cab792e39fe39bb94f3fca655ed157ff87a8af78e1d6ba5b07c4a00ab'}, {'path': 'org/slf4j/slf4j-api/2.0.9/slf4j-api-2.0.9.jar', 'sha256': '0818930dc8d7debb403204611691da58e49d42c50b6ffcfdce02dadb7c3c2b6c'}, {'path': 'it/unimi/dsi/fastutil/8.5.9/fastutil-8.5.9.jar', 'sha256': '9578bf2a1700cf20d21746a2ee89e57ba1abbd37fa9feda68ff5e9a28473a7f9'}, {'path': 'org/joml/joml/1.10.5/joml-1.10.5.jar', 'sha256': 'cac9f22f83a7aa33eebda73c16ff5261e3cb4911b6bafcf4c79ea486099d0c9a'}]
def download(url,path,algorithm,expected):
    if not path.exists():
        path.parent.mkdir(parents=True,exist_ok=True)
        request=urllib.request.Request(url,headers={'User-Agent':'LumenVale-compatibility-tests/2.5.0'})
        with urllib.request.urlopen(request,timeout=60) as response:path.write_bytes(response.read())
    if hashlib.new(algorithm,path.read_bytes()).hexdigest()!=expected:raise RuntimeError('Hash mismatch: '+path.name)
    return path

deps=[download('https://repo.maven.apache.org/maven2/'+d['path'],T/'dependencies'/Path(d['path']).name,'sha256',d['sha256']) for d in DEPENDENCIES]
subprocess.run([str(javac),'-d',str(T/'classes'),str(HOST/'Loader.java'),str(HOST/'Preprocess.java'),*map(str,(HOST/'stubs').rglob('*.java'))],check=True)
profiles=load_profiles(S)
def expand(p):return re.sub(r'^\s*#include\s+"([^"]+)"\s*$',lambda m:expand(S/m[1].lstrip('/')),p.read_text(encoding='utf-8'),flags=re.M)
def configure(src,settings):
    for key,value in settings.items():
        if isinstance(value,bool):
            src=re.sub(r'^(?://)?#define '+key+r'(?:\s*//[^\n]*)?$',('#define '+key) if value else ('// disabled '+key),src,flags=re.M)
        else:
            src=re.sub(r'^(#define '+key+r')\s+[^\n]+$',r'\g<1> '+value,src,flags=re.M)
            src=re.sub(r'^(const (?:int|float) '+key+r' = )[^;]+;',r'\g<1>'+value+';',src,flags=re.M)
    return src
selected=['gbuffers_terrain.vsh','gbuffers_hand.vsh','gbuffers_hand.fsh','gbuffers_water.fsh','deferred.fsh','final.fsh','shadow.vsh','shadowcomp.csh','shadowcomp13.csh','shadowcomp14.csh','world-1/deferred.fsh','world1/deferred.fsh']
rows=json.loads((HOST/'releases.json').read_text());results=[];compile_jobs={}
for row in rows:
    jar=(args.iris_jars or T/'jars')/row['filename']
    if jar.exists():
        if hashlib.sha512(jar.read_bytes()).hexdigest()!=row['sha512']:raise RuntimeError('Iris hash mismatch: '+jar.name)
    else:
        request=urllib.request.Request(row['metadata_url'],headers={'User-Agent':'LumenVale-compatibility-tests/2.5.0'})
        with urllib.request.urlopen(request,timeout=60) as response:release=json.load(response)
        file=next(f for f in release['files'] if f['filename']==row['filename'])
        download(file['url'],jar,'sha512',row['sha512'])
    folder=T/jar.stem;folder.mkdir(exist_ok=True)
    with zipfile.ZipFile(jar) as z:
        for entry in z.namelist():
            if entry.startswith('META-INF/jars/') and entry.endswith('.jar'):
                (folder/Path(entry).name).write_bytes(z.read(entry))
    cp=os.pathsep.join(map(str,[T/'classes',jar,folder/'*',*deps]))
    defines=folder/'shader-defines.txt'
    defines.write_text(''.join('IRIS_FEATURE_'+f+'=\n' for f in row['available_voxel_flags']))
    props_defines=folder/'property-defines.txt'
    # 1.6.4 does not inject capability flags before parsing properties.
    props_defines.write_text('' if row['iris'].startswith('1.6.4') else defines.read_text())
    manifest=[]
    for name,profile in profiles.items():
        options=folder/(name+'.options');options.write_text(''.join(k+'='+str(v).lower()+'\n' for k,v in profile.items()))
        full=name=='ULTRA' and row['full_voxel_candidate']
        run=subprocess.run([str(java),'-cp',cp,'Loader',row['namespace'],str(S),str(options),str(props_defines),str(full).lower()],capture_output=True,text=True)
        assert run.returncode==0,(row['iris'],name,run.stdout,run.stderr)
        for path in selected:
            code=configure(expand(S/path),profile)
            file=folder/(name+'-'+path.replace('/','_'));file.write_text(code)
            out=file.with_name(file.name+'.preprocessed')
            manifest.append('\t'.join(['glsl',str(defines),str(file),str(out)]))
    batch=folder/'batch.tsv';batch.write_text('\n'.join(manifest))
    run=subprocess.run([str(java),'-cp',cp,'Preprocess',row['namespace'],'batch',str(batch)],capture_output=True,text=True)
    assert run.returncode==0,(row['iris'],run.stdout,run.stderr)
    for line in manifest:
        path=Path(line.split('\t')[3]);code=path.read_text()
        is_full=row['full_voxel_candidate'] and path.name.startswith('ULTRA-')
        if not is_full:
            assert 'uniform uimage3D voxelOccupancy' not in code
            assert 'uniform usampler3D voxelOccupancySampler' not in code
        if not row['uniforms']['isRightHanded']:assert 'uniform bool isRightHanded' not in code
        suffix=next(s for s in ['vsh','fsh','csh'] if ('.'+s+'.') in path.name)
        extension={'vsh':'vert','fsh':'frag','csh':'comp'}[suffix]
        digest=hashlib.sha256((extension+code).encode()).hexdigest()
        compile_jobs[digest]=(code,extension)
    results.append(row|{'option_property_profile_resource_checks':4,'original_jcpp_sources_checked':len(manifest),'mode':'full Ultra' if row['full_voxel_candidate'] else 'legacy fallback'})
    print('Original Iris loader parsers and GLSL preprocessing passed:',row['iris'],flush=True)
out=T/'compile';out.mkdir(exist_ok=True)
def compile_one(item):
    digest,(code,ext)=item;p=out/(digest+'.'+ext);p.write_text(code)
    r=subprocess.run([args.glslang,str(p)],capture_output=True,text=True)
    assert r.returncode==0,(p,r.stdout,r.stderr)
if args.glslang:
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(compile_one,compile_jobs.items()))
report={'releases':results,'original_property_option_profile_configurations':len(rows)*len(profiles),'original_jcpp_sources_checked':len(rows)*len(profiles)*len(selected),
        'unique_preprocessed_stages_compiled':len(compile_jobs) if args.glslang else 0,'glsl_compilation':'passed' if args.glslang else 'skipped: no --glslang supplied','errors':0,
        'scope':'Official SHA512-verified Iris JARs. Original include graph, option scanner, profile/property/resource parsers and JCPP executed. Only game logging/debug-config hosts stubbed; no renderer, Fabric resolution, shader patcher, Minecraft launch or game FPS test.'}
(T/'result.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='releases'},indent=2),flush=True)
