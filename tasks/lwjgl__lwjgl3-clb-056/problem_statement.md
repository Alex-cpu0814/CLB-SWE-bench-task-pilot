Vulkan: VkFramebufferCreateInfo doesnt allow for just passing the attachmentCount
### Environment

* LWJGL version: `3.3.0` 
* LWJGL build #: `SNAPSHOT`
* Java version: `java.version`
* Platform: `Linux`
* Module: `Vulkan`

### Description Of Issue

for ImagelessFramebuffers (A Core feature of vulkan 1.2), you need to be able to specify just the count of attachments. Specifying the attachments causes problems within Khronos Validation Layers. we have tried `VkFramebufferCreateInfo.nattachmentCount(framebufferInfo.address(), 2);` but this unfortunately doesn't work due to the checks causing a NullPointerException
