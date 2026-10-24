"""Execute the pack's occlusion GLSL against controlled voxel fixtures.

Requires OpenGL 4.3 compatibility (NVIDIA or Mesa/llvmpipe), not Minecraft.
Linux CI: xvfb-run -a python scripts/test_voxel_occlusion.py
"""
from pathlib import Path
import argparse
import json
import re
import sys
import hashlib
import zipfile
from pack_options import load_profiles

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--python-libs',type=Path,help='Optional dependency directory')
parser.add_argument('--output',type=Path,default=Path('.validation/occlusion/result.json'))
args=parser.parse_args()
if args.python_libs:
    sys.path.insert(0,str(args.python_libs.resolve()))
import glfw
from OpenGL.GL import *
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
S=ROOT/'shaders'
assert glfw.init(), 'GLFW initialization failed (Linux: run under xvfb-run)'
glfw.window_hint(glfw.VISIBLE,glfw.FALSE)
glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR,2)
glfw.window_hint(glfw.CONTEXT_VERSION_MINOR,1)
window=glfw.create_window(1,1,'LumenVale occlusion regression',None,None)
assert window, 'An OpenGL compatibility context is required'
glfw.make_context_current(window)
renderer=glGetString(GL_RENDERER).decode()
version=glGetString(GL_VERSION).decode()
assert (int(glGetIntegerv(GL_MAJOR_VERSION)),int(glGetIntegerv(GL_MINOR_VERSION)))>=(4,3), version
print('Renderer:',renderer,version,flush=True)
profiles=load_profiles(S)

try:
    def expand(p):
        return re.sub(r'^\s*#include\s+"([^"]+)"\s*$',lambda m:expand(S/m[1].lstrip('/')),p.read_text(encoding='utf-8'),flags=re.M)

    def configure_source(s,profile):
        for k,v in profile.items():
            if isinstance(v,bool):
                if v:s=re.sub(r'^\s*//\s*#define\s+'+re.escape(k)+r'([^\n]*)$',r'#define '+k+r'\1',s,flags=re.M)
                s=re.sub(r'^#define\s+'+re.escape(k)+r'(?:\s*//[^\n]*)?$', '#define '+k if v else '// disabled '+k,s,flags=re.M)
            else:
                s=re.sub(r'^(#define\s+'+re.escape(k)+r')\s+[^\n]+$',r'\g<1> '+v,s,flags=re.M)
                s=re.sub(r'^(const (?:int|float) '+re.escape(k)+r' = )[^;]+;',r'\g<1>'+v+';',s,flags=re.M)
        capabilities=''.join('#define IRIS_FEATURE_'+flag+'\n' for flag in ['CUSTOM_IMAGES','COMPUTE_SHADERS','REVERSED_CULLING','BLOCK_EMISSION_ATTRIBUTE'])
        s=re.sub(r'^(#version[^\n]*\n)',lambda m:m[1]+capabilities,s,count=1) if s.startswith('#version') else capabilities+s
        return s

    cache={}
    def link_sources(name,v,f):
        key=hashlib.sha256((v+f).encode()).hexdigest()
        if key in cache:return cache[key]
        shaders=[]
        for stage,text in [(GL_VERTEX_SHADER,v),(GL_FRAGMENT_SHADER,f)]:
            sh=glCreateShader(stage); glShaderSource(sh,text); glCompileShader(sh)
            if not glGetShaderiv(sh,GL_COMPILE_STATUS):raise RuntimeError(name+' '+glGetShaderInfoLog(sh).decode())
            shaders.append(sh)
        pr=glCreateProgram()
        for sh in shaders:glAttachShader(pr,sh)
        glLinkProgram(pr)
        if not glGetProgramiv(pr,GL_LINK_STATUS):raise RuntimeError(name+' '+glGetProgramInfoLog(pr).decode())
        for sh in shaders:glDeleteShader(sh)
        cache[key]=pr
        return pr

    def uniform(p,k,v):
        table_loc=glGetUniformLocation(p,'lvShapeTable')
        if table_loc>=0:glUniform1i(table_loc,14)
        loc=glGetUniformLocation(p,k)
        if loc<0:return
        if isinstance(v,(int,np.integer)):glUniform1i(loc,int(v))
        elif isinstance(v,float):glUniform1f(loc,v)
        else:
            a=np.asarray(v)
            if a.shape==(4,4):glUniformMatrix4fv(loc,1,GL_FALSE,np.ascontiguousarray(a.T,dtype=np.float32))
            elif a.size==3:glUniform3f(loc,*map(float,a))
            elif a.size==2:glUniform2i(loc,*map(int,a))
    def texture(w,h,depth=False,byte=False):
        tex=glGenTextures(1);glBindTexture(GL_TEXTURE_2D,tex)
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST if depth else GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST if depth else GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE)
        glTexImage2D(GL_TEXTURE_2D,0,GL_DEPTH_COMPONENT24 if depth else (GL_RGBA8 if byte else GL_RGBA16F),w,h,0,GL_DEPTH_COMPONENT if depth else GL_RGBA,GL_FLOAT,None)
        return tex
    def fbo(color=None,depth=None):
        fb=glGenFramebuffers(1);glBindFramebuffer(GL_FRAMEBUFFER,fb)
        if color is not None:glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,color,0);glDrawBuffer(GL_COLOR_ATTACHMENT0)
        else:glDrawBuffer(GL_NONE);glReadBuffer(GL_NONE)
        if depth is not None:glFramebufferTexture2D(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_TEXTURE_2D,depth,0)
        assert glCheckFramebufferStatus(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE
        return fb

    def volume_texture(integer=False,depth=64):
        t=glGenTextures(1);glBindTexture(GL_TEXTURE_3D,t)
        glTexParameteri(GL_TEXTURE_3D,GL_TEXTURE_MIN_FILTER,GL_NEAREST if integer else GL_LINEAR)
        glTexParameteri(GL_TEXTURE_3D,GL_TEXTURE_MAG_FILTER,GL_NEAREST if integer else GL_LINEAR)
        for a in [GL_TEXTURE_WRAP_S,GL_TEXTURE_WRAP_T,GL_TEXTURE_WRAP_R]:glTexParameteri(GL_TEXTURE_3D,a,GL_CLAMP_TO_EDGE)
        glTexImage3D(GL_TEXTURE_3D,0,GL_R32UI if integer else GL_RGBA16F,64,64,depth,0,GL_RED_INTEGER if integer else GL_RGBA,GL_UNSIGNED_INT if integer else GL_FLOAT,None)
        return t
    voxels=[volume_texture(True),volume_texture(True),volume_texture(),volume_texture(),volume_texture(),volume_texture(True,384),volume_texture(True)]
    shapeTable=glGenTextures(1)
    glActiveTexture(GL_TEXTURE14);glBindTexture(GL_TEXTURE_2D,shapeTable)
    shapePixels=np.frombuffer((S/'textures/shapes.bin').read_bytes(),dtype='<f4').reshape(-1,2,4)
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA32F,2,len(shapePixels),0,GL_RGBA,GL_FLOAT,shapePixels)
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST)
    glActiveTexture(GL_TEXTURE0)
    image_names=['voxelOccupancy','voxelEmit','voxelLightA','voxelLightB','voxelIndirect','voxelSurface','voxelShape']
    def voxel_bind():
        for i,t in enumerate(voxels):glBindImageTexture(i,t,0,GL_TRUE,0,GL_READ_WRITE,GL_R32UI if i in [0,1,5,6] else GL_RGBA16F)
        glActiveTexture(GL_TEXTURE7);glBindTexture(GL_TEXTURE_3D,voxels[2])
        glActiveTexture(GL_TEXTURE9);glBindTexture(GL_TEXTURE_3D,voxels[3]);glActiveTexture(GL_TEXTURE0)
        glActiveTexture(GL_TEXTURE12);glBindTexture(GL_TEXTURE_3D,voxels[0]);glActiveTexture(GL_TEXTURE0)
        glActiveTexture(GL_TEXTURE13);glBindTexture(GL_TEXTURE_3D,voxels[6]);glActiveTexture(GL_TEXTURE0)
    def full(program,framebuffer,w=1,h=1):
        glBindFramebuffer(GL_FRAMEBUFFER,framebuffer)
        glViewport(0,0,w,h)
        glDisable(GL_DEPTH_TEST)
        glDisable(GL_BLEND)
        glUseProgram(program)
        glBegin(GL_QUADS)
        for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]:
            glVertex2f(x,y)
        glEnd()

    fbB=fbo(texture(1,1))
    """Actual 2.5/working GLSL probes for isolated geometry-related light leaks."""
    with zipfile.ZipFile(ROOT/'downloads/LumenVale-2.5.0-MC1.20.1.zip') as oldzip:
        def old_expand(name):
            return re.sub(r'^\s*#include\s+"([^"]+)"\s*$',lambda m:old_expand('shaders/'+m[1].lstrip('/')),oldzip.read(name).decode(),flags=re.M)
        old_code={n:old_expand('shaders/lib/'+n) for n in ['voxel_sample.glsl','hand_light.glsl','lighting.glsl']}
        old_compute=[old_expand('shaders/shadowcomp'+(str(i) if i else '')+'.csh') for i in range(13)]
    profile=profiles['ULTRA']
    prefix='#version 430 compatibility\n#define DIM_NETHER\n'+''.join(expand(S/'lib'/n) for n in ['settings.glsl','uniforms.glsl','math.glsl'])
    vertex='#version 430 compatibility\nvoid main(){gl_Position=gl_Vertex;}'
    suffix='''
    uniform vec3 qaPoint;
    uniform vec3 qaEnd;
    uniform int qaMode;
    uniform float qaBlock;
    void main() {
        if(qaMode==0) gl_FragColor=voxelLightAt(qaPoint,vec3(0.0,0.0,1.0));
        else if(qaMode==1) gl_FragColor=voxelFogLightAt(qaPoint);
        else if(qaMode==2) gl_FragColor=vec4(handTransmission(qaPoint,qaEnd),1.0);
        else {
            float shadow;
            gl_FragColor=vec4(surfaceLight(vec3(1.0),vec3(0.0,1.0,0.0),qaPoint,qaPoint,vec2(qaBlock,0.0),1.0,0.0,shadow),1.0);
        }
    }
    '''
    programs={}
    for name in ['2.5.0','2.6.0']:
        body=''.join(old_code[n] if name=='2.5.0' else expand(S/'lib'/n) for n in old_code)
        programs[name]=link_sources('Occlusion probes '+name,vertex,configure_source(prefix+body+suffix,profile))
    voxel_bind()
    slab_line=next(line for line in (S/'block.properties').read_text().splitlines()
                   if 'minecraft:oak_slab:type=bottom' in line)
    slab=int(slab_line.split('=',1)[0].split('.')[1])-20000

    def leak_upload(occ,a=None,b=None,shapes=None):
        if a is None:a=np.zeros((64,64,64,4),np.float32)
        if b is None:b=np.zeros_like(a)
        if shapes is None:shapes=np.zeros_like(occ)
        # In 2.6 the final direct pass repurposes A.alpha after propagation.
        # 2.5 probes never consume A.alpha; RGB input is identical for both.
        a=a.copy();a[...,3]=((occ&0x80000000)!=0).astype(np.float32)
        for index,data in [(0,occ),(6,shapes),(2,a),(3,b)]:
            glBindTexture(GL_TEXTURE_3D,voxels[index]);integer=index in [0,6]
            glTexSubImage3D(GL_TEXTURE_3D,0,0,0,0,64,64,64,GL_RED_INTEGER if integer else GL_RGBA,GL_UNSIGNED_INT if integer else GL_FLOAT,np.ascontiguousarray(data))
        glMemoryBarrier(GL_TEXTURE_FETCH_BARRIER_BIT)

    def leak_probe(name,mode,point,end=(1.25,1.25,.5),block=0.):
        pr=programs[name];glUseProgram(pr)
        for k,v in {'cameraPosition':[0.,64.,0.],'gbufferModelViewInverse':np.eye(4),'fogColor':[0.,0.,0.],
                    'voxelOccupancySampler':12,'voxelShapeSampler':13,'voxelLightSampler':7,'voxelLightBSampler':9,
                    'heldItemId':-1,'heldItemId2':-1,'heldBlockLightValue':0,'heldBlockLightValue2':0,
                    'qaPoint':point,'qaEnd':end,'qaMode':mode,'qaBlock':float(block)}.items():uniform(pr,k,v)
        full(pr,fbB,w=1,h=1)
        out=np.empty((1,1,4),np.float32);glReadPixels(0,0,1,1,GL_RGBA,GL_FLOAT,out)
        assert np.isfinite(out).all()
        return out[0,0,:3].copy()

    def compare(mode,point,**kwargs):return {n:leak_probe(n,mode,point,**kwargs).tolist() for n in programs}
    z,y,x=np.mgrid[0:64,0:64,0:64]
    occ=np.zeros((64,64,64),np.uint32)
    occ[((x<32)&(y>=32))|((x>=32)&(y<32))]=0x80808080
    a=np.zeros((64,64,64,4),np.float32);a[(x<32)&(y<32),:3]=2.
    leak_upload(occ,a)
    reports={}
    reports['sealed_corner_surface']=compare(0,(.15,.15,.5))
    reports['sealed_corner_fog']=compare(1,(.15,.15,.5))
    reports['sealed_corner_hand']=compare(2,(-1.25,-1.25,.5))
    # Indirect light uses the same geometric rejection, even when A is dark.
    leak_upload(occ,b=a)
    reports['sealed_corner_bounce']=compare(0,(.15,.15,.5))
    assert max(reports['sealed_corner_bounce']['2.5.0'])>.3
    assert max(reports['sealed_corner_bounce']['2.6.0'])<.0001

    occ=np.zeros_like(occ);occ[:,32,:]=0xa0808080
    shapes=np.zeros_like(occ);shapes[:,32,:]=slab
    a=np.zeros_like(a);a[:,32:,:,:3]=2.
    leak_upload(occ,a,shapes=shapes)
    reports['fog_below_solid_slab']=compare(1,(.5,-.01,.5))
    reports['fog_above_slab_control']=compare(1,(.5,.8,.5))

    occ=np.zeros_like(occ);occ[:,:32,:]=0x90808080
    a=np.zeros_like(a);a[:,31,:,:3]=4.;a[:,32:,:,:3]=.5
    leak_upload(occ,a)
    reports['fog_at_full_emitter']=compare(1,(.5,.1,.5))
    reports['surface_at_full_emitter']=compare(0,(.5,.1,.5))

    occ=np.zeros_like(occ);occ[32,32,32]=0x80808080
    a=np.zeros_like(a);a[...,:3]=2.;a[32,32,32,:3]=0.
    leak_upload(occ,a)
    reports['surface_inside_opaque_cell']=compare(0,(.6,.6,.6))

    occ=np.zeros_like(occ);leak_upload(occ)
    reports['vanilla_fill_in_occluded_field']={}
    for name in programs:
        reports['vanilla_fill_in_occluded_field'][name]=(leak_probe(name,3,(.5,.5,.5),block=1.)-leak_probe(name,3,(.5,.5,.5),block=0.)).tolist()

    occ=np.zeros_like(occ);occ[:,:,32]=0x40000000|255|(13<<8)|(5<<16)
    leak_upload(occ)
    reports['glass_control']=compare(2,(-1.25,.5,.5),end=(1.25,.5,.5))
    assert max(reports['sealed_corner_surface']['2.5.0'])>.3
    assert max(reports['sealed_corner_fog']['2.5.0'])>.2
    assert min(reports['sealed_corner_hand']['2.5.0'])>.99
    assert max(reports['fog_below_solid_slab']['2.5.0'])>.8
    assert max(reports['vanilla_fill_in_occluded_field']['2.5.0'])>.2
    for case in ['sealed_corner_surface','sealed_corner_fog','sealed_corner_hand','fog_below_solid_slab','surface_inside_opaque_cell','vanilla_fill_in_occluded_field']:
        assert max(reports[case]['2.6.0'])<.0001,(case,reports[case])
    assert min(reports['fog_above_slab_control']['2.6.0'])>1.9
    assert np.allclose(reports['fog_at_full_emitter']['2.6.0'],reports['surface_at_full_emitter']['2.6.0'],atol=.001)
    assert np.allclose(reports['surface_at_full_emitter']['2.6.0'],[.5,.5,.5],atol=.001)
    assert np.allclose(reports['glass_control']['2.6.0'],reports['glass_control']['2.5.0'],atol=.001)
    # A connected, non-convex air neighborhood still has a blocked direct segment.
    occ=np.zeros_like(occ)
    occ[(x<32)&(y>=32)]=0x80808080
    a=np.zeros_like(a);a[(x<32)&(y<32),:3]=2.
    leak_upload(occ,a)
    reports['connected_corner_surface']=compare(0,(.05,.45,.5))
    assert max(reports['connected_corner_surface']['2.5.0'])>.01
    assert max(reports['connected_corner_surface']['2.6.0'])<.0001

    # Crossing three axes also touches double-axis flank cells.
    occ=np.zeros_like(occ);occ[31,32,32]=0x80808080
    leak_upload(occ)
    reports['three_axis_hand']=compare(2,(-1.25,-1.25,-1.25),end=(1.25,1.25,1.25))
    reports['three_axis_hand_reverse']=compare(2,(1.25,1.25,1.25),end=(-1.25,-1.25,-1.25))
    for case in ['three_axis_hand','three_axis_hand_reverse']:
        assert min(reports[case]['2.5.0'])>.99
        assert max(reports[case]['2.6.0'])<.0001

    occ=np.zeros_like(occ);occ[:,32,:]=0xa0808080
    shapes=np.zeros_like(occ);shapes[:,32,:]=slab
    a=np.zeros_like(a);a[...,:3]=1.
    leak_upload(occ,a,shapes=shapes)
    reports['slab_shared_edge_interior']=compare(0,(0.,.3,.5))
    assert max(reports['slab_shared_edge_interior']['2.6.0'])<.0001

    # Run the actual 13 direct compute stages on a 4^3 subvolume. The final
    # metadata change must preserve RGB and mark full/partial geometry only.
    compute_versions={'2.5.0':old_compute,
                      '2.6.0':[expand(S/('shadowcomp'+(str(i) if i else '')+'.csh')) for i in range(13)]}
    compute_outputs={}
    occ=np.zeros((64,64,64),np.uint32)
    occ[1,1,1]=0x90808080
    occ[2,1,1]=0xa0808080
    occ[1,2,1]=0x80808080
    shapes=np.zeros_like(occ);shapes[2,1,1]=slab
    emission=np.zeros_like(occ);emission[1,1,1]=0xff0000ff
    for name,codes in compute_versions.items():
        for index in range(7):
            integer=index in [0,1,5,6]
            depth=384 if index==5 else 64
            data=np.zeros((depth,64,64) if integer else (depth,64,64,4),
                          np.uint32 if integer else np.float32)
            if index==0:data=occ
            elif index==1:data=emission
            elif index==6:data=shapes
            glBindTexture(GL_TEXTURE_3D,voxels[index])
            glTexSubImage3D(GL_TEXTURE_3D,0,0,0,0,64,64,depth,
                            GL_RED_INTEGER if integer else GL_RGBA,
                            GL_UNSIGNED_INT if integer else GL_FLOAT,data)
        voxel_bind()
        for code in codes:
            shader=glCreateShader(GL_COMPUTE_SHADER)
            glShaderSource(shader,configure_source(code,profile));glCompileShader(shader)
            assert glGetShaderiv(shader,GL_COMPILE_STATUS), glGetShaderInfoLog(shader)
            program=glCreateProgram();glAttachShader(program,shader);glLinkProgram(program)
            glDeleteShader(shader)
            assert glGetProgramiv(program,GL_LINK_STATUS), glGetProgramInfoLog(program)
            glUseProgram(program)
            for unit,image in enumerate(image_names):
                uniform(program,image,unit)
            uniform(program,'cameraPosition',[0.,64.,0.])
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT|GL_TEXTURE_FETCH_BARRIER_BIT)
            glDispatchCompute(1,1,1)
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT|GL_TEXTURE_FETCH_BARRIER_BIT)
            glDeleteProgram(program)
        glBindTexture(GL_TEXTURE_3D,voxels[2])
        result=np.empty((64,64,64,4),np.float32)
        glGetTexImage(GL_TEXTURE_3D,0,GL_RGBA,GL_FLOAT,result)
        compute_outputs[name]=result[:4,:4,:4].copy()
    old,new=compute_outputs['2.5.0'],compute_outputs['2.6.0']
    assert np.array_equal(old[...,:3],new[...,:3])
    assert np.array_equal(new[...,3],((occ[:4,:4,:4]&0x80000000)!=0).astype(np.float32))
    assert old[1,1,1,3]>1. and new[1,1,1,3]==1.
    reports['direct_compute_metadata']={'rgb_identical_to_2_5':True,'geometry_mask_exact':True,
                                        'stages':13,'dispatch_cells':[4,4,4]}
    error=int(glGetError());assert error==0,error
    report={'renderer':renderer,'opengl':version,'cases':reports,'gl_error':error,
            'scope':"Actual packaged 2.5.0 and current GLSL executed against controlled voxel fixtures. Not Minecraft runtime or game FPS."}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2),flush=True)
finally:
    glfw.destroy_window(window)
    glfw.terminate()
