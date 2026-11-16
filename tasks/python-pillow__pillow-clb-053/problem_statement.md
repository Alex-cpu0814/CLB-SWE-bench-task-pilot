ImageDraw only uses lower 8-bits of colors in I;16 images
### What did you do?

`ImageDraw` on an image with mode `I;16` fails to work correctly. When given a fill color (in the range 0...0xFFFF), it draws the shapes correctly, but uses a color with the lower 8-bits repeated twice.

### What did you expect to happen?
The full 16-bit fill color provided should be used to draw on the image.

### What actually happened?
Only the lower 8-bits (duplicated into the higher and lower byte) were used.

### What are your OS, Python and Pillow versions?

* OS: macOS 12 (also confirmed on Ubuntu 20.04)
* Python: 3.10
* Pillow: 9.5.0

```python
from PIL import Image, ImageDraw
image = Image.new("I;16", (10, 10))
draw = ImageDraw.Draw(image)

c = 0x1234
draw.point([(0, 0)], fill=c)
print(hex(image.load()[0, 0]))
# --> 0x3434
# (but we expect it to be 0x1234)

c = 0x4567
draw.line([(0, 0), (5, 0)], fill=c)
print(hex(image.load()[0, 0]))
# --> 0x6767
# (but we expect it to be 0x4567)

c = 0x89AB
draw.rectangle([(0, 0), (5, 5)], fill=c)
print(hex(image.load()[0, 0]))
# --> 0xABAB
# (but we expect it to be 0x89AB)
```

As you can see, for each color, the *actual* color applied to the image is based on the lower 8-bits, duplicated twice.

I suspect this has something to do with this: https://github.com/python-pillow/Pillow/blob/7c945f5131cf8596084b32af582f90a43b090540/src/libImaging/Draw.c#L71-L72
(Which was originally added in #3899)

Note that that issue is also referenced by #5598, so I suspect there might be a similar issue with drawing text.

