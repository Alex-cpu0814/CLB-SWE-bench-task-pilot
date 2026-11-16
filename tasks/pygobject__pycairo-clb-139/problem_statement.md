device crasher
This crashes, I guess the surface needs to explicitly keep the device alive:

```
f = io.BytesIO()
dev = cairo.ScriptDevice(f)
surface = cairo.ScriptSurface(dev, cairo.Content.COLOR_ALPHA, 42, 10)
surface.get_device()
```

the docs are not clear..
