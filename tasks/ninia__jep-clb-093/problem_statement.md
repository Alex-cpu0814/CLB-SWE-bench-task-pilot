Bug in pyembed_version_unsafe: Crash with unsafe malloc
When switching to Python 3.5, Anaconda 2.4.1 , my application using embedded JEP started crashing systematically:

*** glibc detected *** /opt/gfa/java/latest/bin/java: free(): invalid next size (fast): 0x00007f68d0018ac0 ***
======= Backtrace: =========
/lib64/libc.so.6[0x320be75f3e]
/lib64/libc.so.6[0x320be78dd0]
/import/exchange/tmp/pshell/python/latest/lib/python3.5/site-packages/jep/libjep.so(pyembed_version_unsafe+0x1b8)[0x7f69c5022058]
/import/exchange/tmp/pshell/python/latest/lib/python3.5/site-packages/jep/libjep.so(pyembed_startup+0x15)[0x7f69c50220a5]
[0x7f69f9015994]

I noticed that if I change the contents of /lib/python3.5/version.txt  from "Anaconda 2.4.1 (64-bit)" to any other, but having a different number of bytes, there is no crash. 

I realized then the following bug in pyembed_version_unsafe, line 264, which may justify the problem: in order to strcpy, we should allocate strlen+1 bytes, so that:

    version = malloc(sizeof(char) * strlen(pyversion));
    strcpy(version, pyversion);

should be:

    version = malloc(sizeof(char) * (strlen(pyversion)+1));
    strcpy(version, pyversion);

