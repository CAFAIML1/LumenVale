import java.nio.file.*;
import java.lang.reflect.*;
import java.util.*;
public class Preprocess {
    public static void main(String[] a) throws Exception {
        if(a[1].equals("batch")) {
            for(String line:Files.readAllLines(Path.of(a[2]))) {
                String[] columns=line.split("\t");
                main(new String[]{a[0],columns[0],columns[1],columns[2],columns[3]});
            }
            return;
        }
        String prefix=a[0];
        String pair=prefix.equals("net.coderbot.iris")?prefix+".shaderpack.StringPair":prefix+".helpers.StringPair";
        var constructor=Class.forName(pair).getConstructor(String.class,String.class);
        List<Object> defines=new ArrayList<>();
        for(String line:Files.readAllLines(Path.of(a[2]))) {
            if(line.isBlank()) continue;
            String[] parts=line.split("=",2);
            defines.add(constructor.newInstance(parts[0],parts.length==2?parts[1]:"1"));
        }
        String cls=prefix+".shaderpack.preprocessor."+(a[1].equals("properties")?"PropertiesPreprocessor":"JcppProcessor");
        String method=a[1].equals("properties")?"preprocessSource":"glslPreprocessSource";
        try {
            String result=(String)Class.forName(cls).getMethod(method,String.class,Iterable.class)
                .invoke(null,Files.readString(Path.of(a[3])),defines);
            Files.writeString(Path.of(a[4]),result);
        } catch(InvocationTargetException ex) {throw new RuntimeException(ex.getCause());}
    }
}
