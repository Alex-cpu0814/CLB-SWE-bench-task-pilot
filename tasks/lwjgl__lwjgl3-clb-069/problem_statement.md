ALUtil.getStringList is returning incorrect values with OpenJDK 10.0.1
### Environment

* LWJGL version: 3.2.0 build 12
* Platform: `Windows`
* Module: `openal`

### Description

ALUtil.getStringList is returning incorrect values on OpenJDK 10.0.1 64 bit.

		System.out.println(ALUtil.getStringList(0, ALC11.ALC_ALL_DEVICES_SPECIFIER));
		System.out.println(ALC11.alcGetString(0, ALC11.ALC_ALL_DEVICES_SPECIFIER));

prints 

![untitled](https://user-images.githubusercontent.com/8334578/44628819-9be9d380-a915-11e8-9555-97cb8daf8d3f.png)

It works with Java 1.8.0_74 64 bit:

[OpenAL Soft on Speakers (Realtek High Definition Audio)]
OpenAL Soft on Speakers (Realtek High Definition Audio)

I also tried with ALC_CAPTURE_DEVICE_SPECIFIER with similar results:

1.8:
[OpenAL Soft on Microphone (Realtek High Definition Audio), OpenAL Soft on Microphone (DroidCam Virtual Audio)]
OpenAL Soft on Microphone (Realtek High Definition Audio)

10.0.1:

![untitled](https://user-images.githubusercontent.com/8334578/44628876-5548a900-a916-11e8-8b83-f7222faf1f82.png)

The bad characters are different every time.

Edit:

It works correctly when I move getStringList to my own class and add two buffer.position() calls:


    public static List<String> getStringList(long deviceHandle, int token) {
        long __result = nalcGetString(deviceHandle, token);
        if (__result == 0) {
            return null;
        }

        ByteBuffer buffer = MemoryUtil.memByteBuffer(__result, Integer.MAX_VALUE);

        List<String> strings = new ArrayList<>();

        int offset = 0;
        while (true) {
            if (buffer.get() == 0) {
                int limit = buffer.position() - 1;
                if (limit == offset) { // Previous char was also a \0 == end of list.
                    break;
                }
                buffer.position(0);
                strings.add(MemoryUtil.memUTF8(buffer, limit - offset, offset));
                buffer.position(limit + 1);
                offset = buffer.position();
            }
        }

        return strings;
    }

It looks like the java9 MemoryTextDecoding here (https://github.com/LWJGL/lwjgl3/blob/14a47551f2ec55361c31654c89c0c5c006cb3997/modules/lwjgl/core/src/main/java9/org/lwjgl/system/MemoryTextDecoding.java) uses the buffer's position while the java 8 version does not.

