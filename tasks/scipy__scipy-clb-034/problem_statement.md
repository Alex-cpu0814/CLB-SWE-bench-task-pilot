BUG: odeint crashes via lsoda instead of giving an error for zero timestep
Reproducable problem, [reported in SO](https://stackoverflow.com/questions/47776535/no-error-message-scipy-odeint-spyder-kernel-died-restarting)

```
from scipy.integrate import odeint
import numpy as np
t = np.linspace(0,0,10)
def func(x):
    return x**2
sol = odeint(func, [1.], t)
```
Results with 
```
 lsoda--  repeated calls with istate = 1 and tout = t (=r1)
      in above message,  r1 =  0.0000000000000D+00
 lsoda--  run aborted.. apparent infinite loop
```
and crashes Python.


----
Windows 10, Python 3.6.2, NumPy1.15.0.dev0+d233e1f, SciPy 1.1.0.dev0+4019b40

