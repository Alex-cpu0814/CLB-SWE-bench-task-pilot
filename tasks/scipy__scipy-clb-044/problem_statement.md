segfault from map_coordinates
I received segmentation faults when running `map_coordinates` with `order=1` on a large array when attempting to access data that was past the 4GB level if the input data array type was `float32`.  I have verified that changing from `float32` -> `float64` or using `order=3` both avoid the problem.  

I suspect these lines in `map_coordinates` should include a coercion to `float64` in the `order <= 1` case:

```
    if prefilter and order > 1:
        filtered = spline_filter(input, order, output=numpy.float64)
    else:
        filtered = input
```

