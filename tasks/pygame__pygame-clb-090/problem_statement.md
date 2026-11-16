freetype.Font.get_rect() ignores style defaults when the style argument is not given
Originally reported by: **Lenard Lindstrom (Bitbucket: [llindstrom](https://bitbucket.org/llindstrom), GitHub: [llindstrom](https://github.com/llindstrom))**

----------------------------------------

The text boundary rectangle returned by *freetype.Font.get_rect()* should match the boundary of the same text rendered directly to a surface. This permits accurate text positioning. To work properly, *get_rect()* should calculate the text boundary to reflect text style, such as **underline**. Instead, it ignores the style settings for the *Font* object when the *style* argument is omitted.

In the *get_rect()* C function *_ftfont_getrect()* of **_freetype.c**, the *style* variable defaults to *0* instead of *FT_STYLE_DEFAULT*. Consequently, by default, no styles are used.

A unit test which reproduces the bug will be added to **freetype_test.py**

----------------------------------------
- Bitbucket: https://bitbucket.org/pygame/pygame/issue/242

