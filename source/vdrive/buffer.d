module vdrive.buffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
public import vdrive.memory;


import erupted;



mixin template Meta_Buffer_Members() {
	VkBuffer				buffer;
	VkBufferCreateInfo		buffer_create_info;
	VkBufferView			buffer_view;
	VkBufferViewCreateInfo	buffer_view_create_info;

	private void destroyObjects() {
		vk.device.vkDestroyBuffer( buffer, vk.allocator );
		if( buffer_view != VK_NULL_ND_HANDLE ) {
			vk.device.vkDestroyBufferView( buffer_view, vk.allocator );
		}
	}
}

/*
/// struct to capture buffer and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct  
struct Meta_Buffer {
	mixin 					Vulkan_State_Pointer;
	VkBuffer				buffer;
	VkBufferCreateInfo		buffer_create_info;
	VkBufferView			buffer_view;
	VkBufferViewCreateInfo	buffer_view_create_info;
	VkMemoryRequirements	memory_requirements;
	VkDeviceMemory			device_memory;
	private VkDeviceSize	device_memory_offset;
	private bool			owns_device_memory = false;

	VkDeviceSize offset()	{ return device_memory_offset; }
	VkDeviceSize size()		{ return memory_requirements.size; }

	// bulk destroy the resources belonging to this meta struct
	void destroyResources() {
		vk.device.vkDestroyBuffer( buffer, vk.allocator );

		if( buffer_view != VK_NULL_ND_HANDLE )
			vk.device.vkDestroyBufferView( buffer_view, vk.allocator );
		
		if( owns_device_memory )
			vk.device.vkFreeMemory( device_memory, vk.allocator );
	}
}
*/

/// create a VkBuffer object, this function or initBuffer must be called first, further operations require the buffer
/// the resulting buffer and its create info are stored in the Meta_Buffer struct
/// the Meta_Buffer struct is returned for function chaining
auto ref createBuffer( ref Meta_Buffer meta, VkBufferUsageFlags usage, VkDeviceSize size ) {

	// buffer create info from arguments
	meta.buffer_create_info.size 		= size; // size in Bytes
	meta.buffer_create_info.usage		= usage;
	meta.buffer_create_info.sharingMode	= VK_SHARING_MODE_EXCLUSIVE;
	
	meta.device.vkCreateBuffer( &meta.buffer_create_info, meta.allocator, &meta.buffer ).vkEnforce;
	meta.device.vkGetBufferMemoryRequirements( meta.buffer, &meta.memory_requirements );

	return meta;
}

/// create a VkBuffer object, this function or createBuffer must be called first, further operations require the buffer
/// the resulting buffer and its create info are stored in the Meta_Buffer struct
/// the Meta_Buffer struct is returned for function chaining
auto initBuffer( ref Vulkan vk, VkBufferUsageFlags usage, VkDeviceSize size ) {
	Meta_Buffer meta = vk;
	return meta.createBuffer( VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, size );
}


/// upload data to the VkDeviceMemory object of the coresponding buffer through memory mapping
auto bufferData( Meta_Buffer meta, void[] data, VkDeviceSize offset = 0 ) {
	void* mapped_memory;

	// map the memory
	//vkMapMemory( meta.device, meta.device_memory, 0, VK_WHOLE_SIZE, 0, &mapped_memory ).vkEnforce;
	vkMapMemory( meta.device, meta.device_memory, meta.offset + offset, data.length.toUint, 0, &mapped_memory ).vkEnforce;
	mapped_memory[ 0 .. data.length ] = data[];

	// flush the mapped memory
	VkMappedMemoryRange flush_mapped_memory_range = {
		memory	: meta.device_memory,
		offset	: meta.offset + offset,
		size	: data.length.toUint,
	};
	vkFlushMappedMemoryRanges( meta.device, 1, &flush_mapped_memory_range );

	// unmap the memory
	vkUnmapMemory( meta.device, meta.device_memory );
	return meta;
}
