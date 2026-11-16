Indented empty array/object serialization differs from stdlib
In most cases with `escape_forward_slashes=False` `ujson` matches the stdlib `json`, but with empty objects it doesn't.

* OS: ArchLinux
* Python: 3.8.5
* UltraJSON: 3.2.0

```python
In [4]: ujson.dumps({}, indent=1)
Out[4]: '{\n\n}'

In [5]: ujson.dumps([], indent=1)
Out[5]: '[\n\n]'

In [8]: json.dumps({}, indent=1)
Out[8]: '{}'

In [9]: json.dumps([], indent=1)
Out[9]: '[]'
```

It would be nice if `ujson` could match stdlib in this case too.
