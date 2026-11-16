BUG: np.lexsort MemoryError on empty array with non-standard strides
Numpy 1.17.0 raises MemoryError when using `lexsort` on an empty array with non-standard `strides`. If `strides` is the natural one, or if there is >= 1 element in the input, then it works as expected.

### Reproducing code example:

```python
import numpy as np

xs = np.array([], dtype='i8')
assert xs.strides == (8,)
assert np.lexsort((xs,)).shape[0] == 0 # Works

ys = np.array([0], dtype='i8')
ys.strides = (16,)
assert np.lexsort((ys,)).shape[0] == 1 # Works

xs.strides = (16,)
assert np.lexsort((xs,)).shape[0] == 0 # MemoryError
```

### Numpy/Python version information:

1.17.0 3.6.1 (v3.6.1:69c0db5, Mar 21 2017, 18:41:36) [MSC v.1900 64 bit (AMD64)]
