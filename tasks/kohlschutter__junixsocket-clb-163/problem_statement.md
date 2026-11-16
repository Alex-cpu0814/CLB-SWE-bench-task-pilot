"java: symbol lookup error: libjunixsocket-native-2.2.0.so: undefined symbol: stat"   on machines with older glibc (< 2.14)
This is a continuation of the previously closed issue https://github.com/kohlschutter/junixsocket/issues/69

I was able to reproduce this same error on my local machine. using version 2.2.0. I am using OpenJDK 1.8, Linux 4.9.217, X86_64.

I haven't tried to use the newest version 2.3.1 yet. But I was able to narrow down the exact line of code that caused this error to occur in 2.2.0. It happened for me in AFUNIXServerSocket.bind(). Hope this helps.
