module vdrive.buffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;


struct Meta_Buffer {
	this( Vulkan* vk )		{  this.vk = vk;  }
	alias 					vk this;
	Vulkan*					vk;
	VkBuffer				buffer;
	VkDeviceSize			buffer_offset;
	VkBufferCreateInfo		buffer_create_info;
	VkBufferView			buffer_view;
	VkBufferViewCreateInfo	buffer_view_create_info;
	VkMemoryRequirements	memory_requirements;
	VkDeviceMemory			device_memory;
}


auto ref createBuffer( ref Meta_Buffer meta, VkBufferUsageFlags usage, VkDeviceSize size ) {

	// buffer create info from arguments
	meta.buffer_create_info.size 		= size; // size in Bytes
	meta.buffer_create_info.usage		= usage;
	meta.buffer_create_info.sharingMode	= VK_SHARING_MODE_EXCLUSIVE;
	
	meta.device.vkCreateBuffer( &meta.buffer_create_info, meta.allocator, &meta.buffer ).vk_enforce;
	meta.device.vkGetBufferMemoryRequirements( meta.buffer, &meta.memory_requirements );

	return meta;
}

auto ref bindMemory( ref Meta_Buffer meta, VkMemoryPropertyFlags memory_property_flags ) {

	import vdrive.memory;
	meta.device_memory = ( *meta.vk ).allocateMemory( meta.memory_requirements.size,
		meta.memory_properties.memoryTypeIndex( meta.memory_requirements, memory_property_flags ));

	meta.device.vkBindBufferMemory( meta.buffer, meta.device_memory, 0 ).vk_enforce;

	return meta;
}


auto bufferData( T )( Meta_Buffer meta, T[] data ) {

	void* mapped_memory;
	vkMapMemory( meta.device, meta.device_memory, 0, VK_WHOLE_SIZE, 0, &mapped_memory ).vk_enforce;

	T* data_memory = cast( T* )mapped_memory;
	data_memory[ 0 .. data.length ] = data[];
	vkUnmapMemory( meta.device, meta.device_memory );

	return meta;
}
