viewing an array with a fieldless structured dtype does not update the dtype:
As discovered in #14310 , viewing an array with a fieldless structured dtype does not update the dtype/itemsize:

```python
>>> a = np.zeros(2, dtype={'names':[], 'formats':[], 'offsets':[], 'itemsize':8})
>>> b = a.view(np.dtype([]))
>>> b
array([], shape=(2, 0),
      dtype={'names':[], 'formats':[], 'offsets':[], 'itemsize':8})
>>> b.dtype == np.dtype([])
False
```


