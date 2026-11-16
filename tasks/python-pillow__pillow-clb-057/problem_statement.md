Pillow fails/hangs on PSD hidden background layer
Depending on file content, Pillow:

- fails with "cannot identify image file";
- fails with "Truncated File Read";
- just hangs inside the `PsdImagePlugin._layerinfo` function because it thinks there are 65534 layers.

See attachment: [pillow-psd-fail.zip](https://github.com/python-pillow/Pillow/files/6815914/pillow-psd-fail.zip)

GIMP works fine with these files.
