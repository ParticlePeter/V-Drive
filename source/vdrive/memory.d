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


/// struct to capture buffer/image and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct  
struct Meta_Buffer_Or_Image( alias Meta_Members ) {
	mixin 					Vulkan_State_Pointer;
	mixin					Meta_Members;
	VkMemoryRequirements	memory_requirements;
	VkDeviceMemory			device_memory;
	private VkDeviceSize	device_memory_offset;
	private bool			owns_device_memory = false;

	VkDeviceSize offset()	{ return device_memory_offset; }
	VkDeviceSize size()		{ return memory_requirements.size; }

	// bulk destroy the resources belonging to this meta struct
	void destroyResources() {
		destroyObjects();
		if( owns_device_memory ) {
			vk.device.vkFreeMemory( device_memory, vk.allocator );
		}
	}
}

alias Meta_Buffer	= Meta_Buffer_Or_Image!Meta_Buffer_Members;
alias Meta_Image	= Meta_Buffer_Or_Image!Meta_Image_Members;

auto memoryTypeIndex( META )( ref META meta, VkMemoryPropertyFlags memory_property_flags ) 
if( is( META == Meta_Buffer ) || is( META == Meta_Image )) {
	return memoryTypeIndex( meta.memory_properties, meta.memory_requirements, memory_property_flags );
}


auto requiredMemorySize( META )( ref META meta ) if( is( META == Meta_Buffer ) || is( META == Meta_Image )) {
	return meta.memory_requirements.size;
}

auto alignedMemorySize( META )( ref META meta ) if( is( META == Meta_Buffer ) || is( META == Meta_Image )) {
	auto size = meta.memory_requirements.size;
	if(  size % meta.memory_requirements.alignment > 0 ) {
		auto alignment = meta.memory_requirements.alignment;
		size = ( size / alignment + 1 ) * alignment;
	}
	return size;
}


/// allocate and bind a VkDeviceMemory object to the VkBuffer/VkImage (which must have been created beforehand) in the meta struct
/// the memory properties of the underlying VkPhysicalDevicethe are used and the resulting memory object is stored
/// The memory object is allocated of the size required by the buffer, another function overload will exist with an argument 
/// for an existing memory object where the buffer is supposed to suballocate its memory from
/// the Meta_Buffer struct is returned for function chaining
auto ref createMemoryImpl( META )( ref META meta, VkMemoryPropertyFlags memory_property_flags ) 
if( is( META == Meta_Buffer ) || is( META == Meta_Image )) {
	meta.owns_device_memory = true;
	meta.device_memory = allocateMemory( *meta.vk, meta.memory_requirements.size, meta.memoryTypeIndex( memory_property_flags ));
	static if( is( META == Meta_Buffer ))	meta.device.vkBindBufferMemory( meta.buffer, meta.device_memory, 0 ).vkEnforce;
	else									meta.device.vkBindImageMemory( meta.image, meta.device_memory, 0 ).vkEnforce;
	return meta;
}


auto ref bindMemoryImpl( META )( ref META meta, VkDeviceMemory device_memory, VkDeviceSize device_memory_offset = 0 )
if( is( META == Meta_Buffer ) || is( META == Meta_Image )) {
	meta.owns_device_memory = false;
	meta.device_memory = device_memory;
	meta.device_memory_offset = device_memory_offset;
	static if( is( META == Meta_Buffer ))	meta.device.vkBindBufferMemory( meta.buffer, device_memory, device_memory_offset ).vkEnforce;
	else									meta.device.vkBindImageMemory( meta.image, device_memory, device_memory_offset ).vkEnforce;
	return meta;
}

// alias buffer this in Meta_Goemetry does not work with the Impl finctions above
// but it does work with the aliased functions bellow  
alias createMemory = createMemoryImpl!Meta_Buffer;
alias createMemory = createMemoryImpl!Meta_Image;
alias bindMemory = bindMemoryImpl!Meta_Buffer;
alias bindMemory = bindMemoryImpl!Meta_Image;
