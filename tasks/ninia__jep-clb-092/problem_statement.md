Unable to execute compiled script with JEP and Python 3.5.3
I have implemented a compile step to convert .py to .pyc files prior to execution.  Each script is cached and if it is present it is used instead of the interpreted .py.

Everything works great when JEP is asked to execute the .pyc when on Python 2.7.13.  However when I change environment and use Python 3.5.3 I get the following error...

**Bad code object in .pyc file**

_Note_ I am aware of pyc magic numbers - the cached pyc files are cleaned and compiled with 3.5.3. Looking at pyembed.c I am getting past the magic number validation at line 1328 and seeing the error at the validation step at line 1334.

Here's the bit I can't understand.  If I execute the compiled .pyc file using python3 directly it runs just fine.

I have attached a simple example that highlights the problem, the zip contains the following...

jepHello.py - native script
jepHello-2.7.13.pyc - compiled with 2.7.13 - runs from JEP on Python 2.7.13 and native python2
jepHello-3.5.3.pyc - compiled with 3.5.3 - fails with JEP on Python 3.5.3 but runs with native python3

[jepHello.zip](https://github.com/mrj0/jep/files/980875/jepHello.zip)

Please let me know if there's something I'm missing or if this is a bug and needs more investigation I'd be very happy to help.  JEP is an awesome piece of work!

Incidentally I am using JEP as the caching compiler too using the following ...

jep.eval("import py_compile");
String py="py_compile.compile(file='"+scriptFile.getAbsolutePath()+"', cfile='"+compiledFile.getAbsolutePath()+"' )";
jep.eval(py);
jep.eval(null); // flush

This works flawlessly and the JEP generated .pyc runs fine on any version of native python.

Thanks for any help you can offer... 

Peter
