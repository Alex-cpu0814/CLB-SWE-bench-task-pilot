For a string with trailing spaces, freetype ignores the last space in boundary calculations
Originally reported by: **Lenard Lindstrom (Bitbucket: [llindstrom](https://bitbucket.org/llindstrom), GitHub: [llindstrom](https://github.com/llindstrom))**

----------------------------------------

For non-rotated horizontal text, a string of one space, " ", will produce a zero width rectangle or surface. A string of two spaces produces a rectangle or surface of only one space in
width.

Fix: include the advance of a terminating space of a string in the calculation of the text boundary. Normally only the bitmap width of the last character in a string is used when determining the text boundary. This avoids boundary padding, empty rows or columns. But a space is nothing but padding; its bitmap has width and height of zero. So make an exception for the trailing space and use its advance to extend the boundary.

An test for the bug will be included in the unit tests.

----------------------------------------
- Bitbucket: https://bitbucket.org/pygame/pygame/issue/243

