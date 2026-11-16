scipy.ndimage.label  crash on 64-bit linux (Trac #742)
_Original ticket http://projects.scipy.org/scipy/ticket/742 on 2008-09-23 by trac user usovalx, assigned to unknown._

It appears that ndimage.label is bugged for 64-bit linux builds. So far I was able to trigger the bug by using reasonably large 3-d datasets. Sample code:
# 

from numpy import *
import scipy.ndimage as nd

shape=(3, 1000, 1000)
a = random.rand(product(shape)).reshape(shape)
m = a > .7
# nd.label(m, nd.generate_binary_structure(3,3))

This code works fine on 32-bit machines, but crashes with "segmentation fault  python" on 64-bit fedora & debian. Both 0.6.0 and (current) trunk versions crash.

