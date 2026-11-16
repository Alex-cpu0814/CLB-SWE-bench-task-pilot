Junix socket 2.7.2 crashes on unix hosts with /tmp mounted as non-exec
**Describe the bug**
We have an application that uses junix-socket 2.7.2 and we are seeing that on SE Linux enabled system with /tmp mounted with non-exec permission, we see the junix socket is crashing. I am attacheding the self test results. We don't see that problem if /tmp is mounted with exec permission. I have done the self test for both 2.7.2 and 2.8.0 and both seem to fail.

**To Reproduce**
Steps to reproduce the behavior:
1. Have an SE Linux enabled RHEL host and /tmp mounted as nonexec
2. Run the junix socket app 
3. Observe that it crashes

**Expected behavior**
It shouldn't crash

**Output/Screenshots**
Suppressed: java.lang.UnsatisfiedLinkError: /tmp/libtmp3251380450989097213libjunixsocket-native-2.7.2.so: /tmp/libtmp3251380450989097213libjunixsocket-native-2.7.2.so: failed to map segment from shared object
                at java.base/java.lang.ClassLoader$NativeLibrary.load0(Native Method)
                at java.base/java.lang.ClassLoader$NativeLibrary.load(ClassLoader.java:2450)
                at java.base/java.lang.ClassLoader$NativeLibrary.loadLibrary(ClassLoader.java:2506)
                at java.base/java.lang.ClassLoader.loadLibrary0(ClassLoader.java:2705)
                at java.base/java.lang.ClassLoader.loadLibrary(ClassLoader.java:2635)
                at java.base/java.lang.Runtime.load0(Runtime.java:768)
                at java.base/java.lang.System.load(System.java:1850)
                at org.newsclub.net.unix.NativeLibraryLoader$ClasspathLibraryCandidate.load(NativeLibraryLoader.java:195)


**Please make sure to test the problem still occurs on the latest version of junixsocket**
Please add the output of the selftest from the latest version available, for example:

`java -jar junixsocket-selftest-2.7.0-jar-with-dependencies.jar`

The selftest is available from the [Release section](https://github.com/kohlschutter/junixsocket/releases) on GitHub.

All minor version updates (e.g., 2.4.x -> 2.5.x) are supposed to be backwards compatible.
If you find that this isn't the case, please mention it in your report. Thank you!

**Notes**
Add any other context about the problem here. Please link/attach any source code that is useful to diagnose the issue.
[selftest_result_2.8.0_failed.txt](https://github.com/kohlschutter/junixsocket/files/12762652/selftest_result_2.8.0_failed.txt)
[self_test_result_2.7.2_failed.txt](https://github.com/kohlschutter/junixsocket/files/12762655/self_test_result_2.7.2_failed.txt)

