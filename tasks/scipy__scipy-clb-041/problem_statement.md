Crash of  interpolate.splprep(task=-1)
Running the circle example but with task = -1 parameter for splprep
http://docs.scipy.org/doc/scipy/reference/tutorial/interpolate.html#spline-interpolation-in-1-d-procedural-interpolate-splxxx

I got a crash in firpack.py at 
<code> t,c,o = _fitpack._parcur(ravel(transpose(x)),w,u,ub,ue,k,task,ipar,s,t,                       nest,wrk,iwrk,per)

Here is my code:

``` python
from scipy import interpolate
import numpy as np
import matplotlib.pyplot as plt

""" tutorial example """
t = np.arange(0, 1.1, .1)
x = np.sin(2*np.pi*t)
y = np.cos(2*np.pi*t)
tck,u = interpolate.splprep([x,y], s=0)
unew = np.arange(0, 1.01, 0.01)
out = interpolate.splev(unew, tck)
plt.figure()
plt.plot(x, y, 'x', out[0], out[1], np.sin(2*np.pi*unew), np.cos(2*np.pi*unew), x, y, 'b')
plt.legend(['Linear', 'Cubic Spline', 'True'])
plt.axis([-1.05, 1.05, -1.05, 1.05])
plt.title('Spline of parametrically-defined curve')
plt.show()

"""test with splprep(task=-1) """
uknots = tck[0]                                    # using the knots from the previous fitting
tck,u = interpolate.splprep([x,y], task=-1, t=uknots)               # here is the crash
plt.figure()
plt.plot(x, y, 'x', out[0], out[1], np.sin(2*np.pi*unew), np.cos(2*np.pi*unew), x, y, 'b')
plt.legend(['Linear', 'Cubic Spline', 'True'])
plt.axis([-1.05, 1.05, -1.05, 1.05])
plt.title('Spline of parametrically-defined curve')
plt.show()
```

Here are the parameters for _fitpack._parcur:
1) in the first case

```
[  0.00000000e+00   1.00000000e+00   5.87785252e-01   8.09016994e-01
   9.51056516e-01   3.09016994e-01   9.51056516e-01  -3.09016994e-01
   5.87785252e-01  -8.09016994e-01   1.22464680e-16  -1.00000000e+00
  -5.87785252e-01  -8.09016994e-01  -9.51056516e-01  -3.09016994e-01
  -9.51056516e-01   3.09016994e-01  -5.87785252e-01   8.09016994e-01
  -2.44929360e-16   1.00000000e+00] [ 1.  1.  1.  1.  1.  1.  1.  1.  1.  1.  1.] [ 0.  0.  0.  0.  0.  0.  0.  0.  0.  0.  0.] 0 1 3 0 False 0 [] 15 [] [] 0
```

2) in the second case (task =-1)

```
[  0.00000000e+00   1.00000000e+00   5.87785252e-01   8.09016994e-01
   9.51056516e-01   3.09016994e-01   9.51056516e-01  -3.09016994e-01
   5.87785252e-01  -8.09016994e-01   1.22464680e-16  -1.00000000e+00
  -5.87785252e-01  -8.09016994e-01  -9.51056516e-01  -3.09016994e-01
  -9.51056516e-01   3.09016994e-01  -5.87785252e-01   8.09016994e-01
  -2.44929360e-16   1.00000000e+00] [ 1.  1.  1.  1.  1.  1.  1.  1.  1.  1.  1.] [ 0.  0.  0.  0.  0.  0.  0.  0.  0.  0.  0.] 0 1 3 -1 False 6.30958424018 [ 0.   0.   0.   0.   0.2  0.3  0.4  0.5  0.6  0.7  0.8  1.   1.   1.   1. ] 17 [] [] 0
```

I'm, using scipy '0.14.0'.

splprep segfaults if fixed knots are specified
interpolate.splprep causes random python segfault if task=-1 and fixed knots are specified, apparently near _fitpack._parcur call.

### Reproducing code example:
```
import numpy as np
from scipy.interpolate import splprep
N = 1000
x = np.arange(N)
# Sinusoid 0-100
y = 100*np.sin(x/30.)
# Add 0-10 random noise
y += np.random.randint(0,10,N)
u = np.arange(N)
# Free knots
resp = splprep([x, y], full_output=True, task=0, k=3, s=15000., u=u)
(tck, u1), err, ier, msg = resp
# Use the obtained knots as fixed:
resp = splprep([x, y], full_output=True, task=-1, k=3, u=u, t=tck[0])
(tck, u1), err, ier, msg = resp
```
If it does not fail immediately, it will if you repeat the calculation in a for loop (eg: 10 times). The behaviour seems quite random.
More detailed explanation here:
https://gist.github.com/mythsmith/9951a8d04092bd11aadbd8a4ef680e22

### Error message:
```
*** Error in `python': free(): invalid pointer: .... ****
```

### Scipy/Numpy/Python version information:
Both:
```
0.18.1 1.11.3 sys.version_info(major=3, minor=6, micro=0, releaselevel='final', serial=0)
'0.17.1', '1.11.1', sys.version_info(major=2, minor=7, micro=13, releaselevel='final', serial=0)
```
The first one was on my local Anaconda3 installation. The second on SageMathCloud.


