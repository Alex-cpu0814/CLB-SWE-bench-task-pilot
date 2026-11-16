'indent' parameter for `dumps` doesn't indent properly in 3.0.0
I'm unsure if this is also a problem in other places.

### What actually happened?

Using the example in `README.rst`:

- ujson version 3.0.0
```python
>>> import ujson
>>> ujson.dumps({"foo": "bar"})
'{"foo":"bar"}'
>>> ujson.dumps({"foo": "bar"}, indent=4)
'{\n "foo": "bar"\n}'
>>> ujson.dumps({"foo": "bar"}, indent=20)
'{\n "foo": "bar"\n}'
```

- ujson version 2.0.3
```python
>>> import ujson
>>> ujson.dumps({"foo": "bar"})
'{"foo":"bar"}'
>>> ujson.dumps({"foo": "bar"}, indent=4)
'{\n    "foo": "bar"\n}'
>>> ujson.dumps({"foo": "bar"}, indent=20)
'{\n                    "foo": "bar"\n}'
```

### What versions are you using?

* OS: Ubuntu 18.04
* Python: 3.8.1
* UltraJSON: 3.0.0 (works properly in 2.0.3)
