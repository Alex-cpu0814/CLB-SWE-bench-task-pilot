Dictionary with None values turns the whole dict to None
Hi folks,
Recently we encountered some buggy behavior of our program, which turned out to be a Jep issue. Whenever we try to retrieve a dictionary containing None values from jep (from python space to Java space), what we get is a null (instead of a dictionary with Null values, as one would expect). 

I created a small program to reproduce this, as follows:

```
public class JEPTest {
    public static void main(final String[] args) {
        try {
            final Jep jep = new Jep(false);
            jep.eval("x = {'abc': 111, 'bcd': '222', 'cde': None}");
            jep.eval("def gx():\n\treturn x");
            final Object x = jep.getValue("x");
            final Object xs = jep.invoke("gx");
            System.out.println(x);  // print null
            System.out.println(xs);  // print null
            jep.close();
        }catch (final JepException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }
}
```

in the case of both println I got a null.
I'm using Jep 3.4.1, python 2.7.10 and jdk1.8.

Please kindly advise:) Thank you so much!

Zhikai

