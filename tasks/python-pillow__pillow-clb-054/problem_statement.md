Fatal Python error for negative radius in ImageFilter.BoxBlur()
Hi,

Python crashes without an exception when a negative radius is passed into ImageFilter.BoxBlur().
This is the error message using spyder.

```
Fatal Python error: Aborted

Main thread:
Current thread 0x00007fbab679b740 (most recent call first):
  File "/home/mgouka/miniconda3/envs/bx_gui/lib/python3.9/site-packages/PIL/ImageFilter.py", line 189 in filter
  File "/home/mgouka/miniconda3/envs/bx_gui/lib/python3.9/site-packages/PIL/Image.py", line 1305 in filter
  File "/tmp/ipykernel_28079/2108891280.py", line 1 in <module>


Restarting kernel...
```

And using python in the standard linux terminal it says:

```
Segmentation fault (core dumped)
```

The code below produces the problem.

```python
import numpy as np
from PIL import Image, ImageFilter

img = Image.fromarray(np.ones([100, 100, 3], dtype='uint8'))
img = img.filter(ImageFilter.BoxBlur(-2))
```

