module vdrive.memory;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.image;
import vdrive.buffer;

import erupted;


struct Meta_Memory {
	mixin 					Vulkan_State_Pointer;
	VkDeviceMemory			device_memory;
	private VkDeviceSize	device_memory_size;

	// bulk destroy the resources belonging to this meta struct
	void destroyResources() {
		vk.device.vkFreeMemory( device_memory, vk.allocator );
	}
}


// memory_type_bits is a bitfield where if bit i is set, it means that the VkMemoryType i 
// of the VkPhysicalDeviceMemoryProperties structure satisfies the memory requirements
auto memoryTypeIndex(
	VkPhysicalDeviceMemoryProperties memory_properties,
	VkMemoryRequirements memory_requirements,
	VkMemoryPropertyFlags memory_property_flags ) {

	uint32_t memory_type_bits = memory_requirements.memoryTypeBits;
	uint32_t memory_type_index;
	foreach( i; 0u .. memory_properties.memoryTypeCount ) {
		VkMemoryType memory_type = memory_properties.memoryTypes[i];
		if( memory_type_bits & 1 ) {
			if( ( memory_type.propertyFlags & memory_property_flags ) == memory_property_flags ) {
				memory_type_index = i;
				break;
			}
		}
		memory_type_bits = memory_type_bits >> 1;
	}

	return memory_type_index;
}


auto allocateMemory( ref Vulkan vk, VkDeviceSize allocation_size, uint32_t memory_type_index ) {

	// construct a memory allocation info from arguments
	VkMemoryAllocateInfo memory_allocate_info = {
		allocationSize	: allocation_size,
		memoryTypeIndex	: memory_type_index,
	};

	// allocate device memory
	VkDeviceMemory device_memory;
	vkAllocateMemory( vk.device, &memory_allocate_info, vk.allocator, &device_memory ).vkEnforce;

	return device_memory;
}


auto ref createMemory( ref Meta_Memory meta, VkDeviceSize allocation_size, uint32_t memory_type_index ) {
	meta.device_memory = allocateMemory( *meta.vk, allocation_size, memory_type_index );
	meta.device_memory_size = allocation_size;
	return meta;
}

auto ref initMemory( ref Vulkan vk, VkDeviceSize allocation_size, uint32_t memory_type_index ) {
	Meta_Memory meta = vk;
	return meta.createMemory( allocation_size, memory_type_index );
}

