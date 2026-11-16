Static method calls not always resolved correctly
How to reproduce:

> jarr = jpy.array(String, ['a', 'b', 'c'])
> jpy.diag.flags = jpy.diag.F_METH
> jstr = Arrays.toString(jarr)
> print(jstr)

Expected output: [a, b, c]
Actual output: [Ljava.lang.String;@23f7d05d

From the debug output it becomes clear that during jpy's method selection process the java.lang.Object.toString() instance method is preferred over the Arrays.toString(Object[]) static method:

JOverloadedMethod_FindMethod: argCount=1, visitSuperClass=1
    Py_TYPE(pyArgs[0])->tp_name = [Ljava.lang.String;
JOverloadedMethod_FindMethod0: method 'java.util.Arrays#toString': overloadCount=9
JMethod_MatchPyArgs: pyArgs[0]: matchValue=0
JOverloadedMethod_FindMethod0: methodList[0]: paramCount=1, matchValue=0
JMethod_MatchPyArgs: pyArgs[0]: matchValue=0
JOverloadedMethod_FindMethod0: methodList[1]: paramCount=1, matchValue=0
JMethod_MatchPyArgs: pyArgs[0]: matchValue=0
JOverloadedMethod_FindMethod0: methodList[2]: paramCount=1, matchValue=0
JMethod_MatchPyArgs: pyArgs[0]: matchValue=0
JOverloadedMethod_FindMethod0: methodList[3]: paramCount=1, matchValue=0
JMethod_MatchPyArgs: pyArgs[0]: matchValue=0
JOverloadedMethod_FindMethod0: methodList[4]: paramCount=1, matchValue=0
JMethod_MatchPyArgs: pyArgs[0]: matchValue=0
JOverloadedMethod_FindMethod0: methodList[5]: paramCount=1, matchValue=0
JMethod_MatchPyArgs: pyArgs[0]: matchValue=0
JOverloadedMethod_FindMethod0: methodList[6]: paramCount=1, matchValue=0
JMethod_MatchPyArgs: pyArgs[0]: matchValue=0
JOverloadedMethod_FindMethod0: methodList[7]: paramCount=1, matchValue=0
JMethod_MatchPyArgs: pyArgs[0]: matchValue=80
JOverloadedMethod_FindMethod0: methodList[8]: paramCount=1, matchValue=80
JOverloadedMethod_FindMethod0: method 'java.lang.Object#toString': overloadCount=1
JMethod_MatchPyArgs: no-argument method (matchValue=100)
JOverloadedMethod_FindMethod0: methodList[0]: paramCount=0, matchValue=100
[Ljava.lang.String;@23f7d05d

