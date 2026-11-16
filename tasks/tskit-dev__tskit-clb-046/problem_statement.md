.newick() raises: LibraryError: Supplied buffer if too small
Hi all, 

I'm getting a buffer size error when calling `.newick()` on a tree with large Ne. The problem seems to be derived from C code in `._ll_sparse_tree.get_newick()`. I see in the trees.py code that if you provide a `node_labels` argument to `.newick()` it skips the compiled `get_newick()` function and instead uses the Python function `__build_newick()` in trees.py. The latter function works fine, but the C code raises the error. 

You should be able to recreate the error with the following code which will print the first newick string successfully but raise the `LibraryError` on the second one:

```python
import msprime

# get a tree sequence
ts = msprime.simulate(10, Ne=100e6, length=10, random_seed=123)

# iterate over trees
for i in ts.trees():
    
    # this works. It calls Py code under the hood.
    nwk1 = i.newick(node_labels={})
    print(nwk1)
    
    # this doesn't work. It call C code under the hood.
    nwk2 = i.newick()
```

output:
```python
(:288429157.63675111532211,(:172974721.34986978769302,((:73244998.80208450555801,((:8406986.89599480479956,:8406986.89599480479956):12158249.56021711230278,(:14131513.13161224499345,:14131513.13161224499345):6433723.32459967210889):52679762.34587258845568):33927916.07371711730957,(:90580458.18467475473881,(:5298987.32885717041790,:5298987.32885717041790):85281470.85581758618355):16592456.69112686812878):65801806.47406816482544):115454436.28688132762909);

---------------------------------------------------------------------------
LibraryError                              Traceback (most recent call last)
<ipython-input-138-354e8c4c4dae> in <module>
     10 
     11     # c code
---> 12     nwk2 = i.newick()

~/miniconda3/envs/py36/lib/python3.6/site-packages/msprime/trees.py in newick(self, precision, root, node_labels)
   1153             root = self.root
   1154         if node_labels is None:
-> 1155             s = self._ll_sparse_tree.get_newick(precision=precision, root=root)
   1156             if not IS_PY2:
   1157                 s = s.decode()

LibraryError: Supplied buffer if too small
```

I'll use the `node_labels` arg for now as a workaround, but I figured this looks like it is probably a bug. If it helps, I'm using msprime v.0.6.1 in Python 3.6 on Ubuntu. 
