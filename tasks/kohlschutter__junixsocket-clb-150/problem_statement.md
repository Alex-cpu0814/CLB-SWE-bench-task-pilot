Length of name in abstract namespace is not respected anymore
When upgrading an existing Linux project from junixsocket 2.3.2 to 2.5.1, the below (previously working) code pattern stopped working. The scenario involves a Java process listening on a Unix domain socket in an abstract namespace and a C client process trying to connect to it.

Java server process:
```java
String socketName = "foobar";
AFUNIXServerSocket serverSocket = AFUNIXServerSocket.newInstance();
serverSocket.bind(AFUNIXSocketAddress.inAbstractNamespace(socketName));
AFUNIXSocket socket = serverSocket.accept();
```

C client process:
```cpp
const char *socket_name = "foobar";
sockaddr_un socket_addr;
bzero(&socket_addr, sizeof(socket_addr));
socket_addr.sun_family = AF_UNIX;
strncpy(socket_addr.sun_path + 1, socket_name, strlen(socket_name));
int server_socket = socket(AF_UNIX, SOCK_STREAM, 0);
connect(server_socket, (struct sockaddr *) &socket_addr,
        offsetof(sockaddr_un, sun_path) + strlen(socket_name) + 1);
```

Using strace revealed the new version of junixsocket does not respect the length of the given socket name and always considers the entire content of `sun_path` as a socket name (i.e. all 108 bytes, instead of just 7):
```
[pid 10013] bind(138, {sa_family=AF_LOCAL, sun_path=@"foobar"}, 110) = 0

[pid 10238] connect(17, {sa_family=AF_LOCAL, sun_path=@"foobar"}, 9) = -1 ECONNREFUSED (Connection refused)
```
The workaround is to use a socket name that has the maximum possible length on a given platform (i.e. 107 bytes on Linux, leaving room just for the initial null byte).
