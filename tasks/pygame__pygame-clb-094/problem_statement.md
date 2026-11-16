Method Surface.fill can segfault is passed an out-of-bounds boundary rectange
Originally reported by: **Lenard Lindstrom (Bitbucket: [llindstrom](https://bitbucket.org/llindstrom), GitHub: [llindstrom](https://github.com/llindstrom))**

----------------------------------------

The //Surface.fill// method can segfault when doing a
//BLEND_RGB_ADD// fill if the optional boundary rectangle goes
outside of the surface.

This addresses Pygame mailing list messages:

http://www.mail-archive.com/pygame-users@seul.org/msg09485.html

and

http://www.mail-archive.com/pygame-users@seul.org/msg09485.html

The cause is that the custom fill methods in surface_blit.c  do no
boundary checks.

----------------------------------------
- Bitbucket: https://bitbucket.org/pygame/pygame/issue/93

