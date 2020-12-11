module vdrive.command;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;


nothrow @nogc:


VkCommandPool createCommandPool(
    ref Vulkan                  vk,
    uint32_t                    queue_family_index,
    VkCommandPoolCreateFlags    command_pool_create_flags = 0,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__

    ) {

    VkCommandPoolCreateInfo command_pool_create_info = {
        flags               : command_pool_create_flags,
        queueFamilyIndex    : queue_family_index,
    };

    VkCommandPool command_pool;
    vk.device.vkCreateCommandPool( & command_pool_create_info, vk.allocator, & command_pool ).vkAssert( "Create Command Pool", file, line, func );
    return command_pool;
}


VkCommandBuffer allocateCommandBuffer( ref Vulkan vk, VkCommandPool command_pool, VkCommandBufferLevel command_buffer_level ) {
    VkCommandBufferAllocateInfo command_buffer_allocation_info = {
        commandPool         : command_pool,
        level               : command_buffer_level,
        commandBufferCount  : 1,
    };

    VkCommandBuffer command_buffer;
    vkAllocateCommandBuffers( vk.device, & command_buffer_allocation_info, & command_buffer ).vkAssert;
    return command_buffer;
}


auto allocateCommandBuffers( ref Vulkan vk, VkCommandPool command_pool, VkCommandBufferLevel command_buffer_level, size_t command_buffer_count ) {
    VkCommandBufferAllocateInfo command_buffer_allocation_info = {
        commandPool         : command_pool,
        level               : command_buffer_level,
        commandBufferCount  : command_buffer_count.toUint,
    };

    import vdrive.util.array;
    auto command_buffers = sizedArray!VkCommandBuffer( command_buffer_count );
    vkAllocateCommandBuffers( vk.device, & command_buffer_allocation_info, command_buffers.ptr ).vkAssert;
    return command_buffers;
}


void allocateCommandBuffers( ref Vulkan vk, VkCommandPool command_pool, VkCommandBufferLevel command_buffer_level, VkCommandBuffer[] command_buffers ) {
    VkCommandBufferAllocateInfo command_buffer_allocation_info = {
        commandPool         : command_pool,
        level               : command_buffer_level,
        commandBufferCount  : command_buffers.length.toUint,
    };
    vkAllocateCommandBuffers( vk.device, & command_buffer_allocation_info, command_buffers.ptr ).vkAssert;
}


VkCommandBufferBeginInfo createCmdBufferBI( VkCommandBufferUsageFlags command_buffer_usage_flags = 0, const( void )* pNext = null ) {
    VkCommandBufferBeginInfo result = { flags : command_buffer_usage_flags, pNext : pNext };
    return result;
}


alias vdBeginCommandBuffer = beginCommandBuffer;
void beginCommandBuffer( ref VkCommandBuffer out_cmd_buffer, VkCommandBufferUsageFlags command_buffer_usage_flags = 0, const( void )* pNext = null ) {
    VkCommandBufferBeginInfo cmd_buffer_bi = { flags : command_buffer_usage_flags, pNext : pNext };
    out_cmd_buffer.vkBeginCommandBuffer( & cmd_buffer_bi );
}


alias vdCmdDispatch = cmdDispatch;
void cmdDispatch( ref VkCommandBuffer cmd_buffer, uint32_t[3] group_count ) {
    cmd_buffer.vkCmdDispatch( group_count[0], group_count[1], group_count[2] );
}


// this function cannot forward the command buffer array overload, as we need a living address
VkSubmitInfo queueSubmitInfo(
    const ref VkCommandBuffer   command_buffer,
    VkSemaphore[]               wait_semaphores = [],
    VkPipelineStageFlags[]      wait_dest_stage_masks = [],
    VkSemaphore[]               signal_semaphores = []

    ) {

    VkSubmitInfo submit_info = {
        waitSemaphoreCount      : cast( uint32_t )wait_semaphores.length,
        pWaitSemaphores         : wait_semaphores.ptr,
        pWaitDstStageMask       : wait_dest_stage_masks.ptr,    //wait_stage_mask.ptr,
        commandBufferCount      : 1,
        pCommandBuffers         : & command_buffer,
        signalSemaphoreCount    : cast( uint32_t )signal_semaphores.length,
        pSignalSemaphores       : signal_semaphores.ptr,
    };

    return submit_info;
}


VkSubmitInfo queueSubmitInfo(
    VkCommandBuffer[]       command_buffers,
    VkSemaphore[]           wait_semaphores = [],
    VkPipelineStageFlags[]  wait_dest_stage_masks = [],
    VkSemaphore[]           signal_semaphores = []

    ) {

    VkSubmitInfo submit_info = {
        waitSemaphoreCount      : cast( uint32_t )wait_semaphores.length,
        pWaitSemaphores         : wait_semaphores.ptr,
        pWaitDstStageMask       : wait_dest_stage_masks.ptr,    //wait_stage_mask.ptr,
        commandBufferCount      : cast( uint32_t )command_buffers.length,
        pCommandBuffers         : command_buffers.ptr,
        signalSemaphoreCount    : cast( uint32_t )signal_semaphores.length,
        pSignalSemaphores       : signal_semaphores.ptr,
    };

    return submit_info;
}



void queueSubmit(
    VkQueue                     queue,
    const ref VkCommandBuffer   command_buffer,
    VkSemaphore[]               wait_semaphores = [],
    VkPipelineStageFlags[]      wait_dest_stage_masks = [],
    VkSemaphore[]               signal_semaphores = [],
    VkFence                     fence = VK_NULL_HANDLE,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__

    ) {

    VkSubmitInfo submit_info = queueSubmitInfo(
        command_buffer, wait_semaphores, wait_dest_stage_masks, signal_semaphores );

    vkQueueSubmit( queue, 1, & submit_info, fence ).vkAssert( "Queue Submit", file, line, func );
}



void queueSubmit(
    VkQueue                     queue,
    VkCommandBuffer[]           command_buffers,
    VkSemaphore[]               wait_semaphores = [],
    VkPipelineStageFlags[]      wait_dest_stage_masks = [],
    VkSemaphore[]               signal_semaphores = [],
    VkFence                     fence = VK_NULL_HANDLE,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__

    ) {

    VkSubmitInfo submit_info = queueSubmitInfo(
        command_buffers, wait_semaphores, wait_dest_stage_masks, signal_semaphores );

    vkQueueSubmit( queue, 1, & submit_info, fence ).vkAssert( "Queue Submit", file, line, func );
}

