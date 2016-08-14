module vdrive.command;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;


import erupted;


auto createCommandPool( ref Vulkan vk, uint32_t queue_family_index, VkCommandPoolCreateFlags command_pool_create_flags = 0 ) {

	VkCommandPoolCreateInfo command_pool_create_info = {
		flags				: command_pool_create_flags,
		queueFamilyIndex	: queue_family_index,
	};

	VkCommandPool command_pool;
	vk.device.vkCreateCommandPool( &command_pool_create_info, vk.allocator, &command_pool ).vkEnforce;
	return command_pool;
}


auto allocateCommandBuffer( ref Vulkan vk, VkCommandPool command_pool, VkCommandBufferLevel command_buffer_level ) {

	VkCommandBufferAllocateInfo command_buffer_allocation_info = {
		commandPool			: command_pool,
		level				: command_buffer_level,
		commandBufferCount	: 1,
	};

	VkCommandBuffer command_buffer;
	vkAllocateCommandBuffers( vk.device, &command_buffer_allocation_info, &command_buffer ).vkEnforce;
	return command_buffer;
}


auto allocateCommandBuffers( ref Vulkan vk, VkCommandPool command_pool, VkCommandBufferLevel command_buffer_level, size_t command_buffer_count ) {

	VkCommandBufferAllocateInfo command_buffer_allocation_info = {
		commandPool			: command_pool,
		level				: command_buffer_level,
		commandBufferCount	: command_buffer_count.toUint,
	};

	import vdrive.util.array;
	auto command_buffers = sizedArray!VkCommandBuffer( command_buffer_count );
	vkAllocateCommandBuffers( vk.device, &command_buffer_allocation_info, command_buffers.ptr ).vkEnforce;
	return command_buffers;
}



auto queueSubmitInfo( 
	const ref VkCommandBuffer	command_buffer,
	VkSemaphore[]				wait_semaphores = [],
	VkPipelineStageFlags[]		wait_dest_stage_masks = [],
	VkSemaphore[]				signal_semaphores = [] ) {

	VkSubmitInfo submit_info = {
		waitSemaphoreCount		: cast( uint32_t )wait_semaphores.length,
		pWaitSemaphores			: wait_semaphores.ptr,
		pWaitDstStageMask		: wait_dest_stage_masks.ptr,	//wait_stage_mask.ptr,
		commandBufferCount		: 1,
		pCommandBuffers			: &command_buffer,
		signalSemaphoreCount	: cast( uint32_t )signal_semaphores.length,
		pSignalSemaphores		: signal_semaphores.ptr,
	};

	return submit_info;
}


auto queueSubmitInfo( 
	VkCommandBuffer[]		command_buffers,
	VkSemaphore[]			wait_semaphores = [],
	VkPipelineStageFlags[]	wait_dest_stage_masks = [],
	VkSemaphore[]			signal_semaphores = [] ) {

	VkSubmitInfo submit_info = {
		waitSemaphoreCount		: cast( uint32_t )wait_semaphores.length,
		pWaitSemaphores			: wait_semaphores.ptr,
		pWaitDstStageMask		: wait_dest_stage_masks.ptr,	//wait_stage_mask.ptr,
		commandBufferCount		: cast( uint32_t )command_buffers.length,
		pCommandBuffers			: command_buffers.ptr,
		signalSemaphoreCount	: cast( uint32_t )signal_semaphores.length,
		pSignalSemaphores		: signal_semaphores.ptr,
	};

	return submit_info;
}




