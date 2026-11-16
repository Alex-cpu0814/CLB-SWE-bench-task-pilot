Java setter method invocation fails in an OSGi environment after a bundle redeploy
Hi, I'm testing jep in an OSGi environment.
In a bundle of mine I use Jep to invoke a python function that returns at the end of computation a simple java bean tree.
The Java bean tree is instantiated from mirrorred Python objects that are used during the computation and which get converted recursively before returning from Jep.  

This is how I dynamically instantiate a Java bean from the corresponding Python object:

```
def load_java_obj(self, j_class_name):
    package_and_class = j_class_name.rsplit(".", 1)
    class_name = package_and_class[1]
    java_module = importlib.import_module(package_and_class[0])
    java_type = getattr(java_module, class_name)
    return java_type()
```

and here is how I call the setter method:

```
outer_obj = load_java_obj("org.example.MyBean")
nested_obj = load_java_obj("org.example.MyNestedBean")
# populate nested_obj properties
setFunct = getattr(outer_obj, "setter_name")
setFunct(nested_obj)
```

I am experiencing the following issue: the above code starts to fail if I redeploy the bundle declaring the Java classes. In the code when the redeploy takes place I create a new Jep instance and I pass the correct class loader, but after the redeploy any call to the setter methods that accept a java bean from Python leads to the following error message: Incorrect object type at 1

I am pretty sure it's not me passing in the wrong class loader to the Jep instance, in fact if I change the setters to accept a java.lang.Object and cast to the correct type within the setter body, the assignement succeeds, meaning that the objects created by Python (Jep) are instances of the classes defined by the appropriate class loader, otherwise I would experience a ClassCastException.

The error message is raised by the native C code of Jep which makes an assignement compatibility check for method arguments before calling a java method from python. 

```
            // check object itself is assignable to that type.
            if(!(*env)->IsAssignableFrom(env,
                                         ((PyJobject_Object *) param)->clazz,
                                         paramType)) {
                PyErr_Format(PyExc_TypeError,
                             "Incorrect object type at %i.",
                             pos + 1);
                return ret;
            }
```

This is why, changing the setter method parameter from a specific type to java.lang.Object makes the invocation successfull in spite of the bundle redeploy.

In practice, it appears that after a bundle redeploy the Jep C code is not correctly recognizing the java bean class anymore, as if the Java class had been defined by a different class loader. But as already written, I am passing in the correct class loader to the new Jep instance. My worry is that Jep is somehow leaking class loaders and re-using the previously passed class loader which is of course invalid after the bundle redeploy. 

As a work around to this problem, instead of calling the Java setter on the bean from Python/Jep, I am now using a more generic helper method in Java which I inwoke from Jep/Python passing in the target object, the setter name, and the setter argument. In this way, by using reflection in Java for invoking the setter, I am bypassing the assignment compatibility check mentioned before.
Alternatively, I could simply comment out such check from the C code and rebuild.

Any idea or recommendation? Any test I can do to help you diagnose the problem?

Thanks in advance.
Matteo.

