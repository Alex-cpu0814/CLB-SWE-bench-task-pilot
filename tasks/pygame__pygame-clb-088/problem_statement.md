Segfault on surface.get_bounding_rect()
Originally reported by: **Anonymous**

----------------------------------------

Hi!

I keep getting a strange segfault using the surface.get_bounding_rect() method.

I'm attaching a test case for it. It reliably produces a segmentation fault on my system:
Windows 7 x64
Python 2.7.5 x64
pygame-1.9.2a0.win-amd64-py2.7 (from lfd.uci.edu)
SDL 1.2.15.0
and
SDL 1.2.14.0

Also tried:
Python 2.7.5 32bit
pygame 1.9.1-py2.7
SDL 1.2.15.0
and
SDL 1.2.14.0

----------------------------------------
- Bitbucket: https://bitbucket.org/pygame/pygame/issue/180

