np.unravel_index() does not accept empty inputs
I would expect a tuple of empty outputs back. I get the following:

```
>>> np.unravel_index([], (10, 12))
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: Iterator operand 0 dtype could not be cast from dtype('float64') to dtype('int64') according to the rule 'same_kind'
```

This does not seem to be a regression, as I can see this with numpy v1.9.2, but it does seem silly.

