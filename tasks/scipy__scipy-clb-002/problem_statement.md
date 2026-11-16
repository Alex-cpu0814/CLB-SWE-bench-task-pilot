interpolation.zoom incorrect output for certain cases
I found the behaviour of zoom to be incorrect when working with 3D arrays for nearest neighbour interpolation.

for example, try the following:

```
x = numpy.zeros(32, 32, 11)
x[12, 16, 8] = 1
y = interpolation.zoom(x, 4, order=0)
```

and when I check to see at `y[12*4, 16*4, 8*4]` I find its 0, not 1.
on closer analysis, if I do `numpy.where(y==1)` I find:

```
(array([48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 49,
       49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 50, 50,
       50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 51, 51, 51,
       51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51]),
 array([64, 64, 64, 64, 65, 65, 65, 65, 66, 66, 66, 66, 67, 67, 67, 67, 64,
       64, 64, 64, 65, 65, 65, 65, 66, 66, 66, 66, 67, 67, 67, 67, 64, 64,
       64, 64, 65, 65, 65, 65, 66, 66, 66, 66, 67, 67, 67, 67, 64, 64, 64,
       64, 65, 65, 65, 65, 66, 66, 66, 66, 67, 67, 67, 67]),
 array([33, 34, 35, 36, 33, 34, 35, 36, 33, 34, 35, 36, 33, 34, 35, 36, 33,
       34, 35, 36, 33, 34, 35, 36, 33, 34, 35, 36, 33, 34, 35, 36, 33, 34,
       35, 36, 33, 34, 35, 36, 33, 34, 35, 36, 33, 34, 35, 36, 33, 34, 35,
       36, 33, 34, 35, 36, 33, 34, 35, 36, 33, 34, 35, 36]))
```

it looks like the last dimension is off by 1.

in contrast, if I perform the same test with skimage.transform.resize 

```
y2 = transform.resize(x, numpy.asarray(x.shape)*4, order=0)
```
- it provides me with the right output for `numpy.where(y2==1)`:

```
(array([48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 49,
       49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 50, 50,
       50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 51, 51, 51,
       51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51]),
 array([64, 64, 64, 64, 65, 65, 65, 65, 66, 66, 66, 66, 67, 67, 67, 67, 64,
       64, 64, 64, 65, 65, 65, 65, 66, 66, 66, 66, 67, 67, 67, 67, 64, 64,
       64, 64, 65, 65, 65, 65, 66, 66, 66, 66, 67, 67, 67, 67, 64, 64, 64,
       64, 65, 65, 65, 65, 66, 66, 66, 66, 67, 67, 67, 67]),
 array([32, 33, 34, 35, 32, 33, 34, 35, 32, 33, 34, 35, 32, 33, 34, 35, 32,
       33, 34, 35, 32, 33, 34, 35, 32, 33, 34, 35, 32, 33, 34, 35, 32, 33,
       34, 35, 32, 33, 34, 35, 32, 33, 34, 35, 32, 33, 34, 35, 32, 33, 34,
       35, 32, 33, 34, 35, 32, 33, 34, 35, 32, 33, 34, 35]))
```

unexpected zero output values from zoom
Last lines / columns of zoomed images seem to have unexpected zero values in some cases.

After running 

``` python
import numpy as np
from scipy.ndimage import zoom
a = zoom(np.ones((110, 72), np.float32), (51. / 110, 40. / 72))
```

`all(a[-1] == 0)` yields `True`

The issue is that after resizing a white image, you don't expect getting a black line at its bottom.

Zoom does not return the same values when resizing a sub-array relative to the entire array
When you resize a sub-array with a factor of 3 (or higher) the result should be the same when resizing the entire array and then taking the same sub-array (3 times larger of course). However, when using zoom it is not, regardless of interpolation order

Code to reproduce:

```
import numpy
from scipy.ndimage import zoom
from scipy.misc import imresize
arr = numpy.array(range(36))
arr.shape = (6,6)
res = zoom(arr, 3., order=0)
res_sub = zoom(arr[0:4,0:4], 3., order=0)
numpy.abs(res[0:12,0:12] - res_sub).sum()
```

The last result should return zero, but it does not. When using imresize, the result is as expected:

```
arr = numpy.array(range(36))
arr.shape = (6,6)
res = imresize(arr, 3., interp='nearest', mode='F').astype(int)
res_sub = imresize(arr[0:4,0:4], 3., interp='nearest', mode='F').astype(int)
numpy.abs(res[0:12,0:12] - res_sub).sum()
```

sicpy.ndimage.zoom returns artefacts and boundaries in some cases
I just ran into some strange behaviour of `scipy.ndimage.zoom` which I did not expect from the documentation. I am not sure whether it is a bug or me missunderstanding the expected behaviour. Here is my example:

``` python
>>> from scipy.ndimage import zoom
>>> img = np.ones((768, 1024))
>>> zoom(img, (0.125, 0.125), order=1)

array([[ 1.,  1.,  1., ...,  1.,  1.,  1.],
       [ 1.,  1.,  1., ...,  1.,  1.,  1.],
       [ 1.,  1.,  1., ...,  1.,  1.,  1.],
       ..., 
       [ 1.,  1.,  1., ...,  1.,  1.,  1.],
       [ 1.,  1.,  1., ...,  1.,  1.,  1.],
       [ 0.,  0.,  0., ...,  0.,  0.,  0.]])
```

Is there something I am missing here or is this bug?

scipy.ndimage.zoom bad interpolation when downsampling (zoom < 1)
Importing `ndimage` and `skimage` for comparsion:
~~~python
import scipy.ndimage as ndimage
import skimage
~~~
Now let's produce simple `a` array as an example:
~~~python
a = np.fromfunction(lambda x, y: x + y, (8, 8))
# produces:
array([[  0.,   1.,   2.,   3.,   4.,   5.,   6.,   7.],
       [  1.,   2.,   3.,   4.,   5.,   6.,   7.,   8.],
       [  2.,   3.,   4.,   5.,   6.,   7.,   8.,   9.],
       [  3.,   4.,   5.,   6.,   7.,   8.,   9.,  10.],
       [  4.,   5.,   6.,   7.,   8.,   9.,  10.,  11.],
       [  5.,   6.,   7.,   8.,   9.,  10.,  11.,  12.],
       [  6.,   7.,   8.,   9.,  10.,  11.,  12.,  13.],
       [  7.,   8.,   9.,  10.,  11.,  12.,  13.,  14.]])
~~~
Now scale it does by 2x:
~~~python
ndimage.zoom(a, zoom=0.5, order=0)
# produces:
array([[  0.,   2.,   5.,   7.],
       [  2.,   4.,   7.,   9.],
       [  5.,   7.,  10.,  12.],
       [  7.,   9.,  12.,  14.]])
~~~
Top left values? Okie, let's try bilinear.
~~~
ndimage.zoom(a, zoom=0.5, order=1)
# produces:
array([[  0.        ,   2.33333333,   4.66666667,   7.        ],
       [  2.33333333,   4.66666667,   7.        ,   9.33333333],
       [  4.66666667,   7.        ,   9.33333333,  11.66666667],
       [  7.        ,   9.33333333,  11.66666667,  14.        ]])
~~~
What are these values!? How 0. is a bilinear for `[[0, 1], [1, 2]]`?
For comparsion I do the same with `skimage`:
~~~python
skimage.transform.rescale(a, scale=0.5, order=1)
# produces correct and expected values:
array([[  1.,   3.,   5.,   7.],
       [  3.,   5.,   7.,   9.],
       [  5.,   7.,   9.,  11.],
       [  7.,   9.,  11.,  13.]])
~~~
Seems like `ndimage.zoom` is doing some awkward resampling, so the `(0, 0)` of new 4x4 grid matches top left corner of `(0, 0)` input 8x8 grid, while `(3, 3)` of 4x4 matches **bottom-right** of 8x8, while the interior pixels are somehow interpolated with this 1/3 steps.

Why `ndimage.zoom` is not resampling using pixel centers? But use pixel corners? This looks like a bug in the implementation. While `skimage` produces correct (and expected) values.
ndimage.interpolation.zoom() option to work like skimage.transform.resize()
**Is your feature request related to a problem? Please describe.**

Given an array as below...

```py
>>> B = np.arange(0, 9).reshape((3, 3))
array([[0, 1, 2],
       [3, 4, 5],
       [6, 7, 8]])
```

I'd like to be able to resample it with scipy.ndimage.interpolation.zoom():

```py
>>> interpolation.zoom(B, zoom = 2, order = 0)
array([[0, 0, 1, 1, 2, 2],
       [0, 0, 1, 1, 2, 2],
       [3, 3, 4, 4, 5, 5],
       [3, 3, 4, 4, 5, 5],
       [6, 6, 7, 7, 8, 8],
       [6, 6, 7, 7, 8, 8]])
```

So far, so good!

```py
>>> interpolation.zoom(B, zoom = 3, order = 0)
array([[0, 0, 1, 1, 1, 1, 2, 2, 2],
       [0, 0, 1, 1, 1, 1, 2, 2, 2],
       [3, 3, 4, 4, 4, 4, 5, 5, 5],
       [3, 3, 4, 4, 4, 4, 5, 5, 5],
       [3, 3, 4, 4, 4, 4, 5, 5, 5],
       [3, 3, 4, 4, 4, 4, 5, 5, 5],
       [6, 6, 7, 7, 7, 7, 8, 8, 8],
       [6, 6, 7, 7, 7, 7, 8, 8, 8],
       [6, 6, 7, 7, 7, 7, 8, 8, 8]])
```

WRONG. Why is this subset:

```py
>>> interpolation.zoom(B, zoom = 3, order = 0)[0:3,0:3]
array([[0, 0, 1],
       [0, 0, 1],
       [3, 3, 4]])
```

NOT equal to:

```py
array([[0, 0, 0],
       [0, 0, 0],
       [0, 0, 0]])
```

**Describe the solution you'd like**

This is what I would have expected for a zeroth-order (nearest neighbor) resampling:

```
array([[ 0.,  0.,  0.,  1.,  1.,  1.,  2.,  2.,  2.],
       [ 0.,  0.,  0.,  1.,  1.,  1.,  2.,  2.,  2.],
       [ 0.,  0.,  0.,  1.,  1.,  1.,  2.,  2.,  2.],
       [ 3.,  3.,  3.,  4.,  4.,  4.,  5.,  5.,  5.],
       [ 3.,  3.,  3.,  4.,  4.,  4.,  5.,  5.,  5.],
       [ 3.,  3.,  3.,  4.,  4.,  4.,  5.,  5.,  5.],
       [ 6.,  6.,  6.,  7.,  7.,  7.,  8.,  8.,  8.],
       [ 6.,  6.,  6.,  7.,  7.,  7.,  8.,  8.,  8.],
       [ 6.,  6.,  6.,  7.,  7.,  7.,  8.,  8.,  8.]])
```

This issue has confounded others before, but no clear solution within `scipy` or `numpy` exists:

- https://stackoverflow.com/questions/33721988/scipy-ndimage-zoom-result-depends-on-image-size
- https://stackoverflow.com/questions/48211632/scipy-ndimage-zoom-vs-skimage-transform-rescale-with-order-0?noredirect=1&lq=1

It'd be nice if `scipy.ndimage.interpolation.zoom()` supported this, because:

- Many people seem to *believe* this is what `zoom()` will do (and will be confused when it doesn't);
- `scikit-learn` / `skimage` has many, many more dependencies and this feature is *almost* available in `scipy` as-is.

**Describe alternatives you've considered**

In skimage.transform.resize(), I get the desired result:

```py
>>> skimage.transform.resize(B, (9, 9), order = 0, preserve_range = True)
array([[ 0.,  0.,  0.,  1.,  1.,  1.,  2.,  2.,  2.],
       [ 0.,  0.,  0.,  1.,  1.,  1.,  2.,  2.,  2.],
       [ 0.,  0.,  0.,  1.,  1.,  1.,  2.,  2.,  2.],
       [ 3.,  3.,  3.,  4.,  4.,  4.,  5.,  5.,  5.],
       [ 3.,  3.,  3.,  4.,  4.,  4.,  5.,  5.,  5.],
       [ 3.,  3.,  3.,  4.,  4.,  4.,  5.,  5.,  5.],
       [ 6.,  6.,  6.,  7.,  7.,  7.,  8.,  8.,  8.],
       [ 6.,  6.,  6.,  7.,  7.,  7.,  8.,  8.,  8.],
       [ 6.,  6.,  6.,  7.,  7.,  7.,  8.,  8.,  8.]])
```

Thanks for your consideration!

