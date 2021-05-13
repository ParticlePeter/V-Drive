module vdrive.commander;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;


nothrow @nogc:


VkCommandPool createCommandPool(
    ref Vulkan                  vk,
    uint32_t                    queue_family_index,
    VkCommandPoolCreateFlags    command_pool_cf = 0,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__

    ) {

    VkCommandPoolCreateInfo command_pool_ci = {
        flags               : command_pool_cf,
        queueFamilyIndex    : queue_family_index,
    };

    VkCommandPool command_pool;
    vk.device.vkCreateCommandPool( & command_pool_ci, vk.allocator, & command_pool ).vkAssert( "Create Command Pool", file, line, func );
    return command_pool;
}


VkCommandBuffer allocateCommandBuffer( ref Vulkan vk, VkCommandPool command_pool, VkCommandBufferLevel command_buffer_level = VK_COMMAND_BUFFER_LEVEL_PRIMARY ) {
    VkCommandBufferAllocateInfo command_buffer_ai = {
        commandPool         : command_pool,
        level               : command_buffer_level,
        commandBufferCount  : 1,
    };

    VkCommandBuffer command_buffer;
    vkAllocateCommandBuffers( vk.device, & command_buffer_ai, & command_buffer ).vkAssert;
    return command_buffer;
}


auto allocateCommandBuffers( ref Vulkan vk, VkCommandPool command_pool, size_t command_buffer_count, VkCommandBufferLevel command_buffer_level = VK_COMMAND_BUFFER_LEVEL_PRIMARY ) {
    VkCommandBufferAllocateInfo command_buffer_ai = {
        commandPool         : command_pool,
        level               : command_buffer_level,
        commandBufferCount  : command_buffer_count.toUint,
    };

    import vdrive.util.array;
    auto command_buffers = sizedArray!VkCommandBuffer( command_buffer_count );
    vkAllocateCommandBuffers( vk.device, & command_buffer_ai, command_buffers.ptr ).vkAssert;
    return command_buffers;
}


void allocateCommandBuffers( ref Vulkan vk, VkCommandPool command_pool, VkCommandBuffer[] command_buffers, VkCommandBufferLevel command_buffer_level = VK_COMMAND_BUFFER_LEVEL_PRIMARY ) {
    VkCommandBufferAllocateInfo command_buffer_ai = {
        commandPool         : command_pool,
        level               : command_buffer_level,
        commandBufferCount  : command_buffers.length.toUint,
    };
    vkAllocateCommandBuffers( vk.device, & command_buffer_ai, command_buffers.ptr ).vkAssert;
}


VkCommandBufferBeginInfo createCmdBufferBI( VkCommandBufferUsageFlags command_buffer_usage_flags = 0, const( void )* pNext = null ) {
    VkCommandBufferBeginInfo result = { flags : command_buffer_usage_flags, pNext : pNext };
    return result;
}


alias vdBeginCommandBuffer = beginCommandBuffer;
void beginCommandBuffer( ref VkCommandBuffer cmd_buffer, VkCommandBufferUsageFlags command_buffer_usage_flags = 0, const( void )* pNext = null ) {
    VkCommandBufferBeginInfo cmd_buffer_bi = { flags : command_buffer_usage_flags, pNext : pNext };
    cmd_buffer.vkBeginCommandBuffer( & cmd_buffer_bi );
}


alias vdCmdDispatch = cmdDispatch;
void cmdDispatch( ref VkCommandBuffer cmd_buffer, uint32_t[3] group_count ) {
    cmd_buffer.vkCmdDispatch( group_count[0], group_count[1], group_count[2] );
}


alias SubmitInfo = queueSubmitInfo;
VkSubmitInfo queueSubmitInfo(
    const ref VkCommandBuffer       command_buffer,
    const VkSemaphore[]             wait_semaphores         = null,
    const VkPipelineStageFlags[]    wait_dest_stage_masks   = null,
    const VkSemaphore[]             signal_semaphores       = null,

    ) {
    //*
    return queueSubmitInfo(( & command_buffer )[ 0 .. 1 ], wait_semaphores, wait_dest_stage_masks, signal_semaphores );
    /*/
    VkSubmitInfo submit_info = {
        waitSemaphoreCount      : wait_semaphores.length.toUint,
        pWaitSemaphores         : wait_semaphores.ptr,
        pWaitDstStageMask       : wait_dest_stage_masks.ptr,    //wait_stage_mask.ptr,
        commandBufferCount      : 1,
        pCommandBuffers         : & command_buffer,
        signalSemaphoreCount    : signal_semaphores.length.toUint,
        pSignalSemaphores       : signal_semaphores.ptr,
    };

    return submit_info;
    //*/
}


VkSubmitInfo queueSubmitInfo(
    const VkCommandBuffer[]         command_buffers,
    const VkSemaphore[]             wait_semaphores         = null,
    const VkPipelineStageFlags[]    wait_dest_stage_masks   = null,
    const VkSemaphore[]             signal_semaphores       = null,

    ) {

    VkSubmitInfo submit_info = {
        waitSemaphoreCount      : wait_semaphores.length.toUint,
        pWaitSemaphores         : wait_semaphores.ptr,
        pWaitDstStageMask       : wait_dest_stage_masks.ptr,    //wait_stage_mask.ptr,
        commandBufferCount      : command_buffers.length.toUint,
        pCommandBuffers         : command_buffers.ptr,
        signalSemaphoreCount    : signal_semaphores.length.toUint,
        pSignalSemaphores       : signal_semaphores.ptr,
    };

    return submit_info;
}


alias Submit = queueSubmit;
void queueSubmit(
    VkQueue                         queue,
    const ref VkCommandBuffer       command_buffer,
    const VkSemaphore[]             wait_semaphores         = null,
    const VkPipelineStageFlags[]    wait_dest_stage_masks   = null,
    const VkSemaphore[]             signal_semaphores       = null,
    VkFence                         fence = VK_NULL_HANDLE,
    string                          file = __FILE__,
    size_t                          line = __LINE__,
    string                          func = __FUNCTION__

    ) {

    VkSubmitInfo submit_info = queueSubmitInfo(
        command_buffer, wait_semaphores, wait_dest_stage_masks, signal_semaphores );

    vkQueueSubmit( queue, 1, & submit_info, fence ).vkAssert( "Queue Submit", file, line, func );
}



void queueSubmit(
    VkQueue                         queue,
    const VkCommandBuffer[]         command_buffers,
    const VkSemaphore[]             wait_semaphores         = null,
    const VkPipelineStageFlags[]    wait_dest_stage_masks   = null,
    const VkSemaphore[]             signal_semaphores       = null,
    VkFence                         fence = VK_NULL_HANDLE,
    string                          file = __FILE__,
    size_t                          line = __LINE__,
    string                          func = __FUNCTION__

    ) {

    VkSubmitInfo submit_info = queueSubmitInfo(
        command_buffers, wait_semaphores, wait_dest_stage_masks, signal_semaphores );

    vkQueueSubmit( queue, 1, & submit_info, fence ).vkAssert( "Queue Submit", file, line, func );
}

