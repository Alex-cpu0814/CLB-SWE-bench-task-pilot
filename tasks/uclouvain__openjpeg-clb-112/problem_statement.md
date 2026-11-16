opj_compress fails to compress lossless on gcc/x86 (-m32)
I am having an issue with OPJ 1.5 and the following file:

http://gdcm.sourceforge.net/thingies/lossless_issue.pgm

It looks as if I cannot do a round-trip lossless compression / decompression, within a 32bits schroot. Everything is fine within a 64bits schroot system (debian jessie if that matter).

