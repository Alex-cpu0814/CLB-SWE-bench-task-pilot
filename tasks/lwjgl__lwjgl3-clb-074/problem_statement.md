JEMalloc trying to load jemalloc32.dll on Windows 10 64 bit
I'm using a 64-bit Windows Operating System and am getting an exception when launching LWJGL. It is expecting to load 32-bit DLL which is not found (I removed it from disk purposefully since this is a 64-bit build).

```
[INFO 11/13/2015 8:22:05 PM] java.lang.ExceptionInInitializerError
[INFO 11/13/2015 8:22:05 PM] at java.lang.Class.forName0(Native Method)
[INFO 11/13/2015 8:22:05 PM] at java.lang.Class.forName(Class.java:264)
[INFO 11/13/2015 8:22:05 PM] at org.lwjgl.system.MemoryManage.getInstance(MemoryManage.java:34)
[INFO 11/13/2015 8:22:05 PM] at org.lwjgl.system.MemoryUtil.<clinit>(MemoryUtil.java:66)
[INFO 11/13/2015 8:22:05 PM] at org.lwjgl.system.Pointer.<clinit>(Pointer.java:24)
[INFO 11/13/2015 8:22:05 PM] at org.lwjgl.glfw.GLFW.<clinit>(GLFW.java:592)
[INFO 11/13/2015 8:22:05 PM] at com.shc.silenceengine.core.glfw.GLFW3.init(GLFW3.java:72)
[INFO 11/13/2015 8:22:05 PM] at com.shc.silenceengine.core.Game.start(Game.java:254)
[INFO 11/13/2015 8:22:05 PM] at com.shc.silenceengine.tests.BillBoardModelTest.main(BillBoardModelTest.java:65)
[INFO 11/13/2015 8:22:05 PM] at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
[INFO 11/13/2015 8:22:05 PM] at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
[INFO 11/13/2015 8:22:05 PM] at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
[INFO 11/13/2015 8:22:05 PM] at java.lang.reflect.Method.invoke(Method.java:497)
[INFO 11/13/2015 8:22:05 PM] at com.intellij.rt.execution.application.AppMain.main(AppMain.java:144)
[INFO 11/13/2015 8:22:05 PM] at org.lwjgl.system.windows.WindowsUtil.windowsThrowException(WindowsUtil.java:28)
[INFO 11/13/2015 8:22:05 PM] at org.lwjgl.system.windows.WindowsLibrary.<init>(WindowsLibrary.java:33)
[INFO 11/13/2015 8:22:05 PM] at org.lwjgl.system.APIUtil.apiCreateLibrary(APIUtil.java:76)
[INFO 11/13/2015 8:22:05 PM] at org.lwjgl.system.Library.loadNative(Library.java:140)
[INFO 11/13/2015 8:22:05 PM] at org.lwjgl.system.jemalloc.JEmalloc.<clinit>(JEmalloc.java:89)
[INFO 11/13/2015 8:22:05 PM] ... 14 more
[INFO 11/13/2015 8:22:05 PM] [LWJGL] MemoryUtil allocator: StdlibAllocator
[WARNING 11/13/2015 8:22:05 PM] Caused by: java.lang.RuntimeException: Failed to load library: jemalloc32.dll (error code = 0)
[INFO 11/13/2015 8:22:05 PM] [LWJGL] Loaded native library: C:\Users\Harsha\AppData\Local\Temp\SilenceEngine5784509329819832952\glfw.dll
[WARNING 11/13/2015 8:22:05 PM] [LWJGL] [MemoryAllocator] Failed to load the jemalloc library.
```

Where this line indicates that you are trying to load 32-bit DLL.

```
[WARNING 11/13/2015 8:22:05 PM] Caused by: java.lang.RuntimeException: Failed to load library: jemalloc32.dll (error code = 0)
```

Shouldn't it load it instead?

