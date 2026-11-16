assertion error on invalid value for Surface.set_device_scale
Rather than an exception.
```Python
surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 100, 100)
surface.set_device_scale(1, 0)
```
```
python: /build/buildd/cairo-1.13.0~20140204/src/cairo-surface.c:1700: cairo_surface_set_device_scale: Assertion `status == CAIRO_STATUS_SUCCESS' failed.
```
