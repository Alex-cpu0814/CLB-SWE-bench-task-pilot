Memory leak in ImageSurface.get_data
When creating an ImageSurface in a loop and calling `get_data()` on it, memory leaks.
It's about 5KB in resident memory, shown by the mem function, and about 1MB of virtual memory, observable in htop, which is about the size of the surface.

Calling `get_data` in the loop on the same SurfaceImage does not allocate more memory.

```python
#!/usr/bin/env python3

import cairo
import resource

def mem():
    print("Memory usage: {:.0f}M".format(
        resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024))

mem()

for i in range(10000):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 500, 500)
    s.get_data()

mem()
#input()
```

I'm using Python 3.6.1 and the latest commit from master as well as 1.13.2+5+gcd6b840-1 (from the ArchLinux repos).
