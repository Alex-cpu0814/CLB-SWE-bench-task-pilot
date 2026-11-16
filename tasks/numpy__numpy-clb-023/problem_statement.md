np.place warning: WRITEBACKIFCOPY detected in array_dealloc
Hello there,

I'm having a problem with getting a runtime warning:

/.../.virtualenv/python_3_env/lib/python3.6/site-packages/numpy/lib/function_base.py:1725: RuntimeWarning: WRITEBACKIFCOPY detected in array_dealloc.  Required call to PyArray_ResolveWritebackIfCopy or PyArray_DiscardWritebackIfCopy is missing.

Actually, I'm curious about what this warning actually means?
The origin of the warning is from a numpy.place, wich is placed in a generator:

```
def mygen():
    ...
    yield np.place(arr, bool_mask, vals)
```

If I remove the np.place operation, there is no warning.
The weird thing is, that I only get this warning, after I call the generator for the second time, e.g.

```
a = mygen() # no warning
a = mygen() # warning
a = mygen() # no warnings more from here on
...

```

I'm using Python 3.6.2 and numpy 1.16.0.





