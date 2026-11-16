pygame.freetype.Font.get_metrics does not respect style & rotation

- [x] write a unit test based on the code below. Would go in this file. test/freetype_test.py (**good first issue**)
- [x] try the C code fix below in src_c/_freetype.c

---

The following python code 

```
    font = freetype.Font(os.path.join (fontdir, "fonts", "sans.ttf"), 36)
    print(font.get_metrics('|'))
    font.rotation = 90
    print(font.get_metrics('|'))
```
output:
[(3, 7, 4294967288, 26, 9.0, 0.0)]
[(3, 7, 4294967288, 26, 9.0, 0.0)]
The two results are identical, which does not follow what the doc [https://www.pygame.org/docs/ref/freetype.html#pygame.freetype.Font.get_metrics](pygame.freetype.Font.get_metrics) says:
**The metrics are adjusted for the current rotation, strong, and oblique settings.**

I dived into the source code and found that in src_c/_freetype.c, the body in function _ftfont_getmetrics:
`    /*
     * Build the render mode with the given size and no
     * rotation/styles/vertical text
     */
    if (_PGFT_BuildRenderMode(self->freetype, self, &render, face_size,
                              FT_STYLE_NORMAL, 0))
        goto error;`
The parameters of _PGFT_BuildRenderMode are the cause of the problem, which i think may be:
`if (_PGFT_BuildRenderMode(self->freetype, self, &render, face_size,
                              FT_STYLE_DEFAULT, self->rotation))
        goto error;`



