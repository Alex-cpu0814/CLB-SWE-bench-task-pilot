`get_magnetic_symmetry` causes segmentation fault with high symprec
The following example causes a segmentation fault in the last line (the structure is adapted from https://github.com/materialsproject/pymatgen/issues/2641).
It seems ordinary symprec (1e-5) is fine, but high symprec (1e-2) causes the segmentation fault from `get_magnetic_symmetry`.

```python
from spglib import get_symmetry, get_magnetic_symmetry

lattice = [
    [3.36017962, 0.0, 0.95244787],
    [1.70747655, 3.84457132, 0.37960516],
    [-0.0117898, -0.29501452, 6.4450749],
]
positions = [
    [0.0, 0.0, 0.0],
    [0.26737473, 0.2232512, 0.24199933],
    [0.73262527, 0.7767488, 0.75800067],
]
numbers = [0, 1, 1]
magmoms = [
    0.005, 0.002, 0.002,
]

cell = (lattice, positions, numbers)
cell_with_magmoms = (lattice, positions, numbers, magmoms)

def check(symprec, angle_tolerance):
    symmetry = get_symmetry(cell, symprec=symprec, angle_tolerance=angle_tolerance)
    print(f"# of symmetry operations: {len(symmetry['rotations'])}")

    magnetic_symmetry = get_magnetic_symmetry(cell_with_magmoms, symprec=symprec, angle_tolerance=angle_tolerance)
    print(f"# of magnetic symmetry operations: {len(magnetic_symmetry['rotations'])}")


print("With moderate symprec")
check(symprec=1e-5, angle_tolerance=-1)

print("With rough symprec")
check(symprec=1e-2, angle_tolerance=-1)
```
