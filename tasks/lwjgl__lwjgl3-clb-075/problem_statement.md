DebugAllocator should not raise an error when using null pointers with memFree
When using `org.lwjgl.util.DebugAllocator`, calling `memFree` with a `null` value results in:

> java.lang.IllegalStateException: The memory address specified is not being tracked

However, the JavaDoc of `memFree` specifically says

> If `ptr` is a `NULL` pointer, the function does nothing.

So the DebugAllocator shouldn't raise an error when passing `null`.

