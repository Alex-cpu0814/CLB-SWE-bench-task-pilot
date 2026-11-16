Incorrect work for 3d np.array
I'm going to use your package because it is exactly what I need (I just need to add normalization). I found out that `histogram1d()` works incorrectly with 3d np.arrays. 
Here is an example of my test:
```
from future import division
from fast_histogram import histogram1d
import numpy as np
import matplotlib.pyplot as plt

def pdf_from_array_np(array, bins, range):
pdf, _ = np.histogram(array, bins=bins, range=range, normed=1)
return pdf

def pdf_from_array(array, bins, range):
pdf = histogram1d(array, bins=bins, range=range)
norm = np.sum(pdf)/bins
return pdf/norm

arr = np.random.uniform(-0.5, 0.5, 64**3)
arr = arr.reshape((64, 64, 64))
x = np.linspace(-0.5, 0.5, 100)
pdf_np = pdf_from_array_np(arr, 100, [-0.5, 0.5])
plt.plot(x, pdf_np, label='np')
pdf_fast = pdf_from_array(arr, 100, [-0.5, 0.5])
plt.plot(x, pdf_fast, label='fast')
plt.legend()
plt.show()
print(np.sum((pdf_fast-pdf_np)**2))
```
![figure_1](https://user-images.githubusercontent.com/26126781/42704521-5d10feae-868d-11e8-899c-afab42ccc8cf.png)


 
