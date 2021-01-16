module vdrive.synchronize;

import erupted;

import vdrive.state;
import vdrive.util.util : vkAssert;


nothrow @nogc:


/// create a VkFence
/// Params:
///     vk = reference to a VulkanState struct
///     fence_cf = optional: only flag is VK_FENCE_CREATE_SIGNALED_BIT
/// Returns: VkFence
auto createFence( ref Vulkan vk, VkFenceCreateFlags fence_cf = 0 ) {
    VkFenceCreateInfo fence_ci = { flags : fence_cf };
    VkFence fence;
    vkCreateFence( vk.device, & fence_ci, vk.allocator, & fence ).vkAssert;
    return fence;
}


/// create a VkSemaphore
/// the implicitly created VkSemaphoreCreateInfo has a flags member which currently must always be 0
/// if this changes in a later release ( current v1.0.42 ) an optional parameter will be added
/// Params:
///     vk = reference to a VulkanState struct
/// Returns: VkSemaphore
auto createSemaphore( ref Vulkan vk ) {
    VkSemaphoreCreateInfo semaphore_ci;
    VkSemaphore semaphore;
    vkCreateSemaphore( vk.device, & semaphore_ci, vk.allocator, & semaphore ).vkAssert;
    return semaphore;
}


/// create a VkEvent
/// the implicitly created VkEventCreateInfo has a flags member which currently must always be 0
/// if this changes in a later release ( current v1.0.42 ) an optional parameter will be added
/// Params:
///     vk = reference to a VulkanState struct
/// Returns: VkEvent
auto createEvent( ref Vulkan vk ) {
    VkEventCreateInfo event_ci;
    VkEvent event;
    vkCreateEvent( vk.device, & event_ci, vk.allocator, & event ).vkAssert;
    return event;
}