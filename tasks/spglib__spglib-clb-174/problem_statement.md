Segmentation fault in `v2.0.1` for a specific cell input
## Describe the bug

Segmentation fault when calling `spglib.get_symmetry` for a specific cell input after pip installing `v2.0.1`. Previous versions are fine.

## To Reproduce

The script below causes a segmentation fault on Linux and MacOS systems (**works fine on Windows**) with the following GNU debugger output:
```
Thread 1 "python" received signal SIGSEGV, Segmentation fault.
0x00007fffab38f91e in get_symmetry_with_site_tensors (equivalent_atoms=equivalent_atoms@entry=0x555558c8cd40, permutations=permutations@entry=0x7fffffffbc88, primitive_lattice=primitive_lattice@entry=0x555558cf8770, cell=cell@entry=0x555558cdad90, with_time_reversal=with_time_reversal@entry=1, is_axial=is_axial@entry=0, symprec=symprec@entry=0.10000000000000001, angle_tolerance=angle_tolerance@entry=5, mag_symprec=mag_symprec@entry=-1, max_size=2592) at src/spglib.c:1787
```

```python
import spglib #v2.0.1
import numpy as np

# Cell data taken from task "mp-806965" in the Materials Project database.

data = (
    (
        np.array(
            [
                [5.2419100e00, 0.0000000e00, 0.0000000e00],
                [-3.4590000e-03, 5.6005340e00, 0.0000000e00],
                [-2.6184020e00, -1.8789800e00, 1.1148141e01],
            ]
        ),
        np.array(
            [
                [0.730776, 0.31474, 0.510679],
                [0.943931, 0.414234, 0.832868],
                [0.056367, 0.524886, 0.155721],
                [0.829407, 0.834674, 0.662821],
                [0.665078, 0.665214, 0.316142],
                [0.49794, 0.497249, 0.995771],
                [0.332764, 0.334746, 0.669724],
                [0.001174, 0.996383, 0.002809],
                [0.181127, 0.169218, 0.349259],
                [0.697256, 0.577902, 0.159052],
                [0.308683, 0.416793, 0.832813],
                [0.366841, 0.258942, 0.50616],
                [0.325228, 0.466901, 0.290137],
                [0.188427, 0.691028, 0.042737],
                [0.452284, 0.963256, 0.296948],
                [0.318269, 0.200207, 0.036324],
                [0.647716, 0.725678, 0.498078],
                [0.025986, 0.916766, 0.83257],
                [0.862965, 0.366944, 0.373363],
                [0.976455, 0.141503, 0.623984],
                [0.989161, 0.872155, 0.371099],
                [0.112981, 0.629933, 0.630065],
                [0.981407, 0.10434, 0.16776],
                [0.683769, 0.794257, 0.959752],
                [0.550973, 0.033926, 0.704626],
                [0.812861, 0.30269, 0.957533],
                [0.689973, 0.527716, 0.707103],
            ]
        ),
        [1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
        [
            0.001,
            0.001,
            0.001,
            1.927,
            1.947,
            1.94,
            1.94,
            1.928,
            1.949,
            -0.084,
            -0.079,
            -0.085,
            0.002,
            0.008,
            0.01,
            -0.002,
            -0.004,
            -0.001,
            0.002,
            0.008,
            0.011,
            -0.001,
            -0.005,
            -0.003,
            -0.003,
            0.005,
            0.006,
        ],
    ),
    0.1, # symprec
    5.0, # angle_tol
)

d = spglib.get_symmetry(data[0], symprec=data[1], angle_tolerance=data[2])

```

## Environment
 
- Python version: Tested with 3.8, 3.9, 3.10, and 3.11
- Spglib's version: 2.0.1


