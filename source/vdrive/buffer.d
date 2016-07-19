module vdrive.buffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;


/// struct to capture buffer and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct  
struct Meta_Buffer {
	mixin 					Vulkan_State_Pointer;
	VkBuffer				buffer;
	VkDeviceSize			buffer_offset;
	VkBufferCreateInfo		buffer_create_info;
	VkBufferView			buffer_view;
	VkBufferViewCreateInfo	buffer_view_create_info;
	VkMemoryRequirements	memory_requirements;
	VkDeviceMemory			device_memory;

	private bool			owns_device_memory = false;

	// bulk destroy the resources belonging to this meta struct
	void destroyResources() {
		vk.device.vkDestroyBuffer( buffer, vk.allocator );

		if( buffer_view != VK_NULL_ND_HANDLE )
			vk.device.vkDestroyBufferView( buffer_view, vk.allocator );
		
		if( owns_device_memory )
			vk.device.vkFreeMemory( device_memory, vk.allocator );
	}
}


/// create a VkBuffer object, this function must be called first as additional operations require the buffer
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


/// allocate and bind a VkDeviceMemory object to the VkBuffer (which must have been created beforehand) in the Meta_Buffer struct
/// the memory properties of the underlying VkPhysicalDevicethe are used and the resulting memory object is stored
/// The memory object is allocated of the size required by the buffer, another function overload will exist with an argument 
/// for an existing memory object where the buffer is supposed to suballocate its memory from
/// the Meta_Buffer struct is returned for function chaining
auto ref bindMemory( ref Meta_Buffer meta, VkMemoryPropertyFlags memory_property_flags ) {

	import vdrive.memory;
	meta.owns_device_memory = true;
	meta.device_memory = ( *meta.vk ).allocateMemory(
		meta.memory_requirements.size,
		meta.memory_properties.memoryTypeIndex( 
			meta.memory_requirements, memory_property_flags 
		)
	);

	meta.device.vkBindBufferMemory( meta.buffer, meta.device_memory, 0 ).vkEnforce;

	return meta;
}


/// upload data to the VkDeviceMemory object of the coresponding buffer through memory mapping
auto bufferData( Meta_Buffer meta, void[] data ) {

	void* mapped_memory;
	vkMapMemory( meta.device, meta.device_memory, 0, VK_WHOLE_SIZE, 0, &mapped_memory ).vkEnforce;
	mapped_memory[ 0 .. data.length ] = data[];
	vkUnmapMemory( meta.device, meta.device_memory );

	return meta;
}
