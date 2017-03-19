module vdrive.synchronize;

import erupted;

import vdrive.state;
import vdrive.util.util : vkAssert;


/// create a VkFence
/// Params:
///     vk = reference to a VulkanState struct
///     fence_create_flags = optional: only flag is VK_FENCE_CREATE_SIGNALED_BIT
/// Returns: VkFence 
auto createFence( ref Vulkan vk, VkFenceCreateFlags fence_create_flags = 0 ) {
    VkFenceCreateInfo fence_create_info = { flags : fence_create_flags };
    VkFence fence;
    vkCreateFence( vk.device, &fence_create_info, vk.allocator, &fence ).vkAssert;
    return fence;
}


/// create a VkSemaphore
/// the implicitly created VkSemaphoreCreateInfo has a flags member which currently must always be 0
/// if this changes in a later release ( current v1.0.42 ) an optional parameter will be added
/// Params:
///     vk = reference to a VulkanState struct
/// Returns: VkSemaphore 
auto createSemaphore( ref Vulkan vk ) {
    VkSemaphoreCreateInfo semaphore_create_info;
    VkSemaphore semaphore;
    vkCreateSemaphore( vk.device, &semaphore_create_info, vk.allocator, &semaphore ).vkAssert;
    return semaphore;
}


/// create a VkEvent
/// the implicitly created VkEventCreateInfo has a flags member which currently must always be 0
/// if this changes in a later release ( current v1.0.42 ) an optional parameter will be added
/// Params:
///     vk = reference to a VulkanState struct
/// Returns: VkEvent 
auto createEvent( ref Vulkan vk ) {
    VkEventCreateInfo event_create_info;
    VkEvent event;
    vkCreateEvent( vk.device, &event_create_info, vk.allocator, &event ).vkAssert;
    return event;
}