scipy.signal.sepfir2d reads random memory when given even sized hrow or hcol
`scipy.signal.sepfir2d` reads random memory when given even sized `hrow` or `hcol`. Deep down in the source code for `sepfir2` there is a comment than only odd-lengths are acceptable:
https://github.com/scipy/scipy/blob/d06791710acae119e099829087f8e1aedc4e1bd7/scipy/signal/S_bspline_util.c#L173
https://github.com/scipy/scipy/blob/d06791710acae119e099829087f8e1aedc4e1bd7/scipy/signal/D_bspline_util.c#L177
https://github.com/scipy/scipy/blob/d06791710acae119e099829087f8e1aedc4e1bd7/scipy/signal/C_bspline_util.c#L176
https://github.com/scipy/scipy/blob/d06791710acae119e099829087f8e1aedc4e1bd7/scipy/signal/Z_bspline_util.c#L173
However, this is not documented or enforced in `sepfir2d`.
