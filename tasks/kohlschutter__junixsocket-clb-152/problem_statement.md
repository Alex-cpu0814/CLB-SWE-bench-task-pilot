0 treated as invalid socket
Hi!  I was trying to use `AFUNIXServerSocket.newInstance(FileDescriptor.in)`, with Apache's fcgid module invoking the process with FD 0 as a bound `AF_UNIX` socket, but it throws `SocketException` with "Not a valid socket".  This seems to be down to `socket.c` regarding FD 0 as invalid.
I don't think there's any reason why 0 can't be a socket, is there (other than it usually being occupied by stdin)?  And FastCGI actually depends on it.
Cheers!
