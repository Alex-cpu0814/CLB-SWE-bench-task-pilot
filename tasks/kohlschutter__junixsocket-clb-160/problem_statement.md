setSoTimeout should force timed out calls to InputStream read to throw java.net.SocketTimeoutException
**Describe the bug**
Setting `AFUNIXSocket.setSoTimeout` should force timed out calls to `InputStream` read to throw `java.net.SocketTimeoutException`. [See here](https://docs.oracle.com/javase/7/docs/api/java/net/Socket.html#setSoTimeout(int)).

This does not happen --- instead `read` returns -1.

**To Reproduce**
Here's some sample code. Assumes that `nc` is available on host platform.

```
import org.newsclub.net.unix.AFUNIXServerSocket;
import org.newsclub.net.unix.AFUNIXSocket;
import org.newsclub.net.unix.AFUNIXSocketAddress;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

public class Test {
    public static void main(String [] args) throws IOException, InterruptedException {

        AFUNIXServerSocket server = AFUNIXServerSocket.newInstance();
        Path temp = Files.createTempFile("brainopener", ".sock");
        final AFUNIXSocketAddress address = new AFUNIXSocketAddress(temp.toFile());

        System.out.println("Binding...");
        server.bind(address);

        System.out.println("Starting nc...");
        new ProcessBuilder("nc", "-U", temp.toString()).start();

        final AFUNIXSocket socket = server.accept();
        System.out.println("Accepted...");
        socket.setSoTimeout(5000);
        byte[] buf = new byte[socket.getReceiveBufferSize()];
        int read;
        InputStream in = socket.getInputStream();

        while ((read = in.read(buf)) != -1) {
                System.out.write(buf, 0, read);
        }

        System.out.println("Done.");
    }
}
```


**Expected behavior**
The call to `in.read(buf)` should throw `java.net.SocketTimeoutException` in the timeout condition.

**Environment (please complete the following information):**
 - OS: macOS 11.4 (20F71), Darwin 20.5.0. Intel.
 - JVM: OpenJDK Runtime Environment AdoptOpenJDK-16.0.1+9 (build 16.0.1+9)

Self test output attached.
[selftest.txt](https://github.com/kohlschutter/junixsocket/files/6690032/selftest.txt)


**Notes**
Should `OutputStream.write` also throw an exception on timeout condition?
