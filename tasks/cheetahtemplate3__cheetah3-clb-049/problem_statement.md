Calling Template.getVar() with a string beginning with "$" crashes
The compiled C version of NameMapper does not handle names beginning with "$" correctly. Specifically on CentOS 6.10, this command results in a Segmentation fault:
`python -c "from Cheetah.Template import Template; print(Template(source='blah').getVar('$'))"`

I get the same result from both Cheetah 3.1.0 and 3.2.5 on Python 2.7.

After deleting _namemapper.so, the same command produces a traceback:

```/home/sscadmin/.local/share/virtualenvs/python2.7/lib64/python2.7/site-packages/Cheetah/Compiler.py:1627: UserWarning: 
You don't have the C version of NameMapper installed! I'm disabling Cheetah's useStackFrames option as it is painfully slow with the Python version of NameMapper. You should get a copy of Cheetah with compiled C version of NameMapper.
  "\nYou don't have the C version of NameMapper installed! "
Traceback (most recent call last):
  File "<string>", line 1, in <module>
  File "/home/sscadmin/.local/share/virtualenvs/python2.7/lib64/python2.7/site-packages/Cheetah/Template.py", line 1446, in getVar
    self.searchList(), varName.replace('$', ''), autoCall)
  File "/home/sscadmin/.local/share/virtualenvs/python2.7/lib64/python2.7/site-packages/Cheetah/NameMapper.py", line 289, in valueFromSearchList
    _raiseNotFoundException(key, searchList)
  File "/home/sscadmin/.local/share/virtualenvs/python2.7/lib64/python2.7/site-packages/Cheetah/NameMapper.py", line 174, in _raiseNotFoundException
    raise NotFound(excString)
Cheetah.NameMapper.NotFound: cannot find ''
```
