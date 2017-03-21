import com.ceph.rados.Rados;
import com.ceph.rados.exceptions.RadosException;
import java.io.File;
import com.ceph.rados.IoCTX;
public class CephExample {
    public static void main (String args[]){
      try {
          Rados cluster = new Rados("admin");
          File f = new File("/etc/ceph/ceph.conf");
          cluster.confReadFile(f);
          cluster.connect();
          System.out.println("Connected to the cluster.");
          IoCTX io = cluster.ioCtxCreate("data"); /* Pool Name */
          String oidone = "kyle-say";
          String contentone = "Hello World!";
          io.write(oidone, contentone);
          String oidtwo = "my-object";
          String contenttwo = "This is my object.";
          io.write(oidtwo, contenttwo);
          String[] objects = io.listObjects();
          for (String object: objects)
              System.out.println("Put " + object);

          /* io.remove(oidone);
             io.remove(oidtwo); */

          cluster.ioCtxDestroy(io);

        } catch (RadosException e) {
          System.out.println(e.getMessage() + ": " + e.getReturnValue());
        }
    }
}
