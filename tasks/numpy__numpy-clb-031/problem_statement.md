choose does not broadcast index array appropriately (Trac #925)
_Original ticket http://projects.scipy.org/numpy/ticket/925 on 2008-10-03 by @teoliphant, assigned to unknown._

The advertised behavior of choose(choices, sequence_of_arrays) is that the choices array and all the arrays in the sequence must be broadcastable to the same shape which is the shape of the output. 

However, NumPy does not look at the shape of the choices array, only the sequence_of_arrays. 

This requires an adaptation of the code in PyArray_Choose function in C.   Probably the easiest thing is to construct a MultiIterator object to handle the broadcasting internal to that function, construct the output, and then fill appropriately.

