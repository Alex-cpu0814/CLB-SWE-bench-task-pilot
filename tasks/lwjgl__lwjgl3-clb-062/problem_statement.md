clang_getCString returns garbage in lwjgl-llvm module
### Environment

* LWJGL version: `3.2.2` 
* LWJGL build #: `10`
* Java version: `OpenJDK 64-Bit Server VM v11.0.4+11-post-Debian-1bpo91 by Debian `
* Platform: `Linux x86_64`
* Module: `llvm`

### Description
The static method clang_getCString in ClangIndex in the llvm module returns garbage characters. I think that may because native clang_getCString expects a CXString struct passed as value, but lwjgl passes a Pointer/long address?? I'm not sure about that and I'm new to lwjgl.

I have attached a minimum test case illustrating the problem.
[CXStringTest.java.txt](https://github.com/LWJGL/lwjgl3/files/3532091/CXStringTest.java.txt)

Note that the test case also shows you can properly get the String by getting the address of the first member of the CXString struct:

```java
CXString cxstr = CXString.callocStack(stack);
//...
// VVVV--- This works
String cstr = memUTF8Safe(memGetAddress(cxstr.address()));
```


