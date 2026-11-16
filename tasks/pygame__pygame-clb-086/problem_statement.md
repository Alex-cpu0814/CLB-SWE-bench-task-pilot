pygame.draw.polygon handles x and y direction inconsistently
Originally reported by: **donLorenzo (Bitbucket: [donLorenzo](https://bitbucket.org/donLorenzo), GitHub: [donLorenzo](https://github.com/donLorenzo))**

----------------------------------------

Reported by Florian Krause on the [pygame mailing list](http://article.gmane.org/gmane.comp.python.pygame/25542):


```
#!plain

Hi there,

I think I found another bug. When drawing a cross, defined as:

pygame.draw.polygon(screen, [255,0,0], [[11, 0], [11, 9], [20, 9], [20, 11], [11, 11], [11, 20], [9, 20], [9, 11], [0, 11], [0, 9], [9, 9], [9, 0]], 0)

the result will show a cross with 2 pixel thickness in the vertical direction, but 3 pixels thickness in the horizontal direction. Which one is "correct" is probably debatable, but Pygame should at least treat both directions equal, shouldn't it?
```

note that the simple example:
```
#!python

import pygame
pygame.init()
screen = pygame.display.set_mode((100,100))
pygame.draw.polygon(screen, [255,0,0], [[0, 0], [3, 0], [3, 3], [0, 3]], 0)
pygame.display.update()
```
yields a 4x4 rect

----------------------------------------
- Bitbucket: https://bitbucket.org/pygame/pygame/issue/234

