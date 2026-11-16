Saving an image with JPEG2000 format doesn't accept Path object
### What did you do?

Save a JPEG 2000 image using a `Path` argument:
```python
from pathlib import Path
from PIL import Image

img = Image.new('RGBA', (5, 5), '#00000000')
img.save(Path('image.jp2'), format='JPEG2000')
```

### What did you expect to happen?

It should save the file correctly, since [the documentation says that passing in a `Path` object is allowed](https://pillow.readthedocs.io/en/latest/reference/Image.html#PIL.Image.Image.save).

### What actually happened?

```
Traceback (most recent call last):
  File "/home/jtai/Desktop/pillow-fail/fail.py", line 5, in <module>
    img.save(Path('image.jp2'), format='JPEG2000')
  File "/home/jtai/Desktop/pillow-fail/venv/lib/python3.9/site-packages/PIL/Image.py", line 2235, in save
    save_handler(self, fp, filename)
  File "/home/jtai/Desktop/pillow-fail/venv/lib/python3.9/site-packages/PIL/Jpeg2KImagePlugin.py", line 247, in _save
    if filename.endswith(".j2k"):
AttributeError: 'PosixPath' object has no attribute 'endswith'
```

### What are your OS, Python and Pillow versions?

* OS: Pop!_OS 21.04
* Python: 3.9.5
* Pillow: 8.3.1
