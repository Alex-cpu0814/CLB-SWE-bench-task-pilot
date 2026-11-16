4.2.0+ font rendering mem leak
### What did you do?
use font in loop and draw image 
### What did you expect to happen?
not leak memory
### What actually happened?
leak memory
### What versions of Pillow and Python are you using?
it doesnt happen in py3.4 pillow <= 4.1.1
it does in >= 4.20
ImageFont.py leaks memory, it happens on default font, but even more on external loaded font with truetype

when running the script below on version 4.2.0+ 
mem usage keeps increasing every cycle for : 
/usr/local/lib/python3.4/dist-packages/PIL/ImageFont.py:113 
/usr/local/lib/python3.4/dist-packages/PIL/ImageFont.py:113: size=15.9 KiB (+15.9 KiB), count=709 (+708), average=23 B
/usr/local/lib/python3.4/dist-packages/PIL/ImageFont.py:113: size=17.2 KiB (+17.2 KiB), count=768 (+767), average=23 B
/usr/local/lib/python3.4/dist-packages/PIL/ImageFont.py:113: size=18.6 KiB (+18.6 KiB), count=827 (+826), average=23 B



```python
from PIL import Image, ImageFont, ImageDraw, ImageFont
import tracemalloc
tracemalloc.start()
count = 0
size = 128, 128
#font2 = ImageFont.truetype('/home/pi/run/fonts/04B_03__.TTF',8) ##use this with own font for more leaking
txt = Image.new('RGBA', size, (255,255,255,0))
d = ImageDraw.Draw(txt)
font2 = ImageFont.load_default()
while True :

	d.text((0, 0), "blabla", font=font2, fill="white")
	if count <= 0:
		snapshot1 = tracemalloc.take_snapshot()
	count += 1
	

	if count == 60 :
		snapshot2 = tracemalloc.take_snapshot()
		count = 1
		top_stats = snapshot2.compare_to(snapshot1, 'lineno')
		print("[ Top 10 differences ]")
		for stat in top_stats[:10]:
			print(stat)
```

