`scipy.signal.{medfilt,medfilt2d}` hit "Windows fatal exception: access violation" with SciPy 1.7.0 on Windows
Since yesterday with the new SciPy 1.7.0 release, CuPy's Windows CI is experiencing the following fatal error (cupy/cupy#5364) and the CI was interrupted.

#### Reproducing code example:
The failing tests can be found here:
https://github.com/cupy/cupy/blob/4469fae998df33c72ff40ef954cb08b8f0004b18/tests/cupyx_tests/scipy_tests/signal_tests/test_signaltools.py#L250-L281

The failure is reproducible only on Windows and **not seen on Linux**.

#### Error message:
```
01:07:54.763807 STDERR 1188] | Windows fatal exception: access violation | &nbsp;
01:07:54.763807 STDERR 1188] | &nbsp; | &nbsp;
01:07:54.763807 STDERR 1188] | Current thread 0x0000121c (most recent call first): | &nbsp;
01:07:54.763807 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\scipy\signal\signaltools.py", line 1538 in medfilt | &nbsp;
01:07:54.763807 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\scipy\signal\signaltools.py", line 1851 in medfilt2d | &nbsp;
01:07:54.763807 STDERR 1188] | File "C:\Windows\TEMP\flexci\run-00151477\work\src\tests\cupyx_tests\scipy_tests\signal_tests\test_signaltools.py", line 281 in test_medfilt2d | &nbsp;
01:07:54.763807 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\cupy\testing\_helper.py", line 47 in _call_func | &nbsp;
01:07:54.763807 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\cupy\testing\_helper.py", line 90 in _call_func_numpy | &nbsp;
01:07:54.763807 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\cupy\testing\_helper.py", line 101 in _call_func_numpy_cupy | &nbsp;
01:07:54.763807 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\cupy\testing\_helper.py", line 265 in test_func | &nbsp;
01:07:54.763807 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\cupy\testing\_helper.py", line 825 in test_func | &nbsp;
01:07:54.764804 STDERR 1188] | File "C:\Development\Python\Python37\lib\unittest\case.py", line 615 in run | &nbsp;
01:07:54.764804 STDERR 1188] | File "C:\Development\Python\Python37\lib\unittest\case.py", line 663 in __call__ | &nbsp;
01:07:54.764804 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\unittest.py", line 321 in runtest | &nbsp;
01:07:54.764804 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\runner.py", line 162 in pytest_runtest_call | &nbsp;
01:07:54.765777 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\callers.py", line 187 in _multicall | &nbsp;
01:07:54.765777 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\manager.py", line 87 in &lt;lambda&gt; | &nbsp;
01:07:54.765777 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\manager.py", line 93 in _hookexec | &nbsp;
01:07:54.765777 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\hooks.py", line 286 in __call__ | &nbsp;
01:07:54.765777 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\runner.py", line 255 in &lt;lambda&gt; | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\runner.py", line 311 in from_call | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\runner.py", line 255 in call_runtest_hook | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\runner.py", line 215 in call_and_report | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\runner.py", line 126 in runtestprotocol | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\runner.py", line 109 in pytest_runtest_protocol | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\callers.py", line 187 in _multicall | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\manager.py", line 87 in &lt;lambda&gt; | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\manager.py", line 93 in _hookexec | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\hooks.py", line 286 in __call__ | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\main.py", line 348 in pytest_runtestloop | &nbsp;
01:07:54.769663 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\callers.py", line 187 in _multicall | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\manager.py", line 87 in &lt;lambda&gt; | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\manager.py", line 93 in _hookexec | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\hooks.py", line 286 in __call__ | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\main.py", line 323 in _main | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\main.py", line 269 in wrap_session | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\main.py", line 316 in pytest_cmdline_main | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\callers.py", line 187 in _multicall | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\manager.py", line 87 in &lt;lambda&gt; | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\manager.py", line 93 in _hookexec | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pluggy\hooks.py", line 286 in __call__ | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\config\__init__.py", line 163 in main | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\_pytest\config\__init__.py", line 185 in console_main | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\site-packages\pytest\__main__.py", line 5 in &lt;module&gt; | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\runpy.py", line 85 in _run_code | &nbsp;
01:07:54.781377 STDERR 1188] | File "C:\Development\Python\Python37\lib\runpy.py", line 193 in _run_module_as_main | 12s
01:08:06.784203 STDOUT 1188] | Last 10 lines from the test output: | &nbsp;
01:08:06.812846 STDOUT 1188] | ........................................................................ [ 75%] | &nbsp;
01:08:06.814324 STDOUT 1188] | ........................................................................ [ 75%] | &nbsp;
01:08:06.814324 STDOUT 1188] | ........................................................................ [ 75%] | &nbsp;
01:08:06.814604 STDOUT 1188] | ........................................................................ [ 75%] | &nbsp;
01:08:06.814604 STDOUT 1188] | ........................................................................ [ 75%] | &nbsp;
01:08:06.814604 STDOUT 1188] | ........................................................................ [ 76%] | &nbsp;
01:08:06.814604 STDOUT 1188] | ........................................................................ [ 76%] | &nbsp;
01:08:06.814604 STDOUT 1188] | ........................................................................ [ 76%] | &nbsp;
01:08:06.814604 STDOUT 1188] | ........................................................................ [ 76%] | &nbsp;
01:08:06.814604 STDOUT 1188] | ............FFFF....FFFF
```

#### Scipy/Numpy/Python version information:
Python: 3.7.2
NumPy: 1.20.3
SciPy: 1.7.0

cc: @kmaehashi @emcastillo
