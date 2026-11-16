Weighted histogram differs from numpy unless the data is explicity copied.
First, thanks for the great library. I suspect I am hitting a memory issue. Unless I explictly copy the arrays before passing them to histogram2D, the results differ from numpy. So far, I only saw this happen when I am using the weighted version of the 2Dhistogram. Code and output follows

```python
#! /usr/bin/env python
import numpy as np
import fast_histogram as ft

print(f"Numpy version {np.__version__}")
print(f"Fast-histogram version {ft.__version__}")

# Initial data
#######################################################
nbins=100
max_val=17.64
min_val=0.0
set_range=[[min_val, max_val],[min_val, max_val]]
with np.load("data.npz") as d:
    pot = d["pot"]
    displ_new = d["displ_new"]
    bond_ind = d["bond_ind"]


# Without copy
print("NOT EXPLICITLY COPYING THE DATA")
pot_array = pot[:, bond_ind[0,0], bond_ind[0,1]]
arr1 = displ_new[:,bond_ind[0,0]]
arr2 = displ_new[:,bond_ind[0,1]]

#Run the histograms
h_np = np.histogram2d(arr1, arr2, nbins, range=set_range, weights=pot_array)[0]
h_ft = ft.histogram2d(arr1, arr2, nbins, range=set_range, weights=pot_array)

print("===FAST-HIST===")
print(h_ft)
print("===NUMPY===")
print(h_np)


# With copy
print("EXPLICITLY COPYING THE DATA")
pot_array = pot[:, bond_ind[0,0], bond_ind[0,1]].copy()
arr1 = displ_new[:,bond_ind[0,0]].copy()
arr2 = displ_new[:,bond_ind[0,1]].copy()

#Run the histograms
h_np = np.histogram2d(arr1, arr2, nbins, range=set_range, weights=pot_array)[0]
h_ft = ft.histogram2d(arr1, arr2, nbins, range=set_range, weights=pot_array)

print("===FAST-HIST===")
print(h_ft)
print("===NUMPY===")
print(h_np)
```

with output 

```
Numpy version 1.18.1
Fast-histogram version 0.8
NOT EXPLICITLY COPYING THE DATA
===FAST-HIST===
[[0.         0.         0.         ... 0.         0.         0.        ]
 [0.0425809  0.         0.         ... 0.         0.         0.        ]
 [0.         0.         0.01108671 ... 0.         0.         0.        ]
 ...
 [0.         0.         0.         ... 0.         0.         0.        ]
 [0.         0.         0.         ... 0.         0.         0.        ]
 [0.         0.         0.         ... 0.         0.         0.        ]]
===NUMPY===
[[0.         0.         0.         ... 0.         0.         0.        ]
 [0.00524697 0.11627543 0.00218829 ... 0.         0.         0.        ]
 [0.         0.0233833  0.08906353 ... 0.         0.         0.        ]
 ...
 [0.         0.         0.         ... 0.         0.         0.        ]
 [0.         0.         0.         ... 0.         0.         0.        ]
 [0.         0.         0.         ... 0.         0.         0.        ]]
EXPLICITLY COPYING THE DATA
===FAST-HIST===
[[0.         0.         0.         ... 0.         0.         0.        ]
 [0.00524697 0.11627543 0.00218829 ... 0.         0.         0.        ]
 [0.         0.0233833  0.08906353 ... 0.         0.         0.        ]
 ...
 [0.         0.         0.         ... 0.         0.         0.        ]
 [0.         0.         0.         ... 0.         0.         0.        ]
 [0.         0.         0.         ... 0.         0.         0.        ]]
===NUMPY===
[[0.         0.         0.         ... 0.         0.         0.        ]
 [0.00524697 0.11627543 0.00218829 ... 0.         0.         0.        ]
 [0.         0.0233833  0.08906353 ... 0.         0.         0.        ]
 ...
 [0.         0.         0.         ... 0.         0.         0.        ]
 [0.         0.         0.         ... 0.         0.         0.        ]
 [0.         0.         0.         ... 0.         0.         0.        ]]
```

The data file necessary to run the code is attached. Due to github restrictions, I had to zip it first.
[data.npz.zip](https://github.com/astrofrog/fast-histogram/files/4671735/data.npz.zip)


