JVM crash when closing a jep instance associated to a terminated thread
I have a cache of jep instances which are bound to the container thread that created them.
If the originating thread is disposed by the web container and at a later time I try to close the corresponding jep instance I experience the following JVM crash:

```
 # A fatal error has been detected by the Java Runtime Environment:
 #
 #  SIGSEGV (0xb) at pc=0x00007fba779f1285, pid=25044, tid=140441049380608
 #
 # JRE version: Java(TM) SE Runtime Environment (7.0_80-b15) (build 1.7.0_80-b15)
 # Java VM: Java HotSpot(TM) 64-Bit Server VM (24.80-b11 mixed mode linux-amd64 compressed   oops)
 # Problematic frame:
 # C  [libjep.so+0x13285]  pyembed_thread_close+0xb5
```

