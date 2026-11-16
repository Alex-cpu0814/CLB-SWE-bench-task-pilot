pygame.draw.rect() with width > 1 has weird corners
**Environment:**

- **Operating system** (e.g. Windows, Linux(Debian), Linux(Ubuntu), Mac): Linux (Ubuntu)
- **Python version** (e.g. 3.7.9, 3.8.5) : 3.9.7
- **SDL version** (e.g. SDL 2.0.12): 2.0.16
- **PyGame version** (e.g. 2.0.0.dev10, 1.9.6): 2.1.0
**Current behavior:**

![rect](https://user-images.githubusercontent.com/617224/143325878-37b13319-d33e-4c83-9af9-407ddc6d5f59.png)

On the left is the output of 

```python
pygame.draw.rect(screen, (255, 255, 0), Rect((20, 20), (100, 100)), width=9)
```

The right is what I expect. I implemented this by drawing 4 filled rects.
