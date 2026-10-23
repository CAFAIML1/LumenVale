import java.nio.file.*;
import java.lang.reflect.*;
import java.util.*;
public class Loader {
    static Object call(Object host,String method) throws Exception {return host.getClass().getMethod(method).invoke(host);}
    public static void main(String[] a) throws Exception {
        String prefix=a[0];Path root=Path.of(a[1]);
        Class<?> pathClass=Class.forName(prefix+".shaderpack.include.AbsolutePackPath");
        List<Object> starts=new ArrayList<>();
        try(var paths=Files.walk(root)) {
            for(Path p:paths.filter(p->p.toString().endsWith(".vsh")||p.toString().endsWith(".fsh")||p.toString().endsWith(".csh")).toList())
                if(!p.getParent().getFileName().toString().equals("lib"))
                    starts.add(pathClass.getMethod("fromAbsolutePath",String.class).invoke(null,"/"+root.relativize(p).toString().replace('\\','/')));
        }
        Class<?> listClass=Class.forName("com.google.common.collect.ImmutableList");
        Object immutable=listClass.getMethod("copyOf",Collection.class).invoke(null,starts);
        Class<?> graphClass=Class.forName(prefix+".shaderpack.include.IncludeGraph");
        Object graph;
        try {graph=graphClass.getConstructor(Path.class,listClass).newInstance(root,immutable);}
        catch(NoSuchMethodException ex) {graph=graphClass.getConstructor(Path.class,listClass,boolean.class).newInstance(root,immutable,false);}
        if(!((Map<?,?>)call(graph,"getFailures")).isEmpty()) throw new AssertionError("Include graph failure");
        Class<?> optsClass=Class.forName(prefix+".shaderpack.option.ShaderPackOptions");
        Map<String,String> values=new HashMap<>();
        for(String line:Files.readAllLines(Path.of(a[2]))) {String[] parts=line.split("=",2);values.put(parts[0],parts[1]);}
        Object options=optsClass.getConstructor(graphClass,Map.class).newInstance(graph,values);
        String pair=prefix.equals("net.coderbot.iris")?prefix+".shaderpack.StringPair":prefix+".helpers.StringPair";
        var ctor=Class.forName(pair).getConstructor(String.class,String.class);
        List<Object> defines=new ArrayList<>();
        for(String line:Files.readAllLines(Path.of(a[3]))) {
            if(line.isBlank()) continue;String[] parts=line.split("=",2);
            defines.add(ctor.newInstance(parts[0],parts.length==2?parts[1]:""));
        }
        String cls=prefix+".shaderpack."+(prefix.equals("net.coderbot.iris")?"":"properties.")+"ShaderProperties";
        Object properties=Class.forName(cls).getConstructor(String.class,optsClass,Iterable.class)
            .newInstance(Files.readString(root.resolve("shaders.properties")),options,defines);
        Map<?,?> profiles=(Map<?,?>)call(properties,"getProfiles");
        if(profiles.size()!=4 || !profiles.get("ULTRA").toString().contains("VOXEL_LIGHTING")) throw new AssertionError("Profile names changed: "+profiles);
        var images=(List<?>)call(properties,"getIrisCustomImages");
        var textures=(Map<?,?>)call(properties,"getIrisCustomTextures");
        boolean voxel=Boolean.parseBoolean(a[4]);
        if(images.size()!=(voxel?7:0) || textures.size()!=(voxel?1:0)) throw new AssertionError("Resources "+images.size()+" / "+textures.size());
        var conditions=(Map<?,?>)call(properties,"getConditionallyEnabledPrograms");
        for(var entry:conditions.entrySet()) if(entry.getKey().toString().contains("shadowcomp") && !voxel && defines.size()<4 && !entry.getValue().equals("false")) throw new AssertionError("Compute enabled: "+entry);
        if(!((List<?>)call(properties,"getRequiredFeatureFlags")).isEmpty()) throw new AssertionError("Required flags");
        Map<?,?> bools=(Map<?,?>)call(call(options,"getOptionSet"),"getBooleanOptions");
        for(String name:List.of("SHADOWS","VOXEL_LIGHTING","LEGACY_LEFT_HAND","HAND_LIGHT")) if(!bools.containsKey(name)) throw new AssertionError("Option lost: "+name);
        System.out.println("PASS original include graph, option scanner, profiles, properties, resources and compute guards: "+a[2]);
    }
}
