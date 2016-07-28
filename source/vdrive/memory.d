module vdrive.memory;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;



//////////////////////////////
// general memory functions //
//////////////////////////////

// memory_type_bits is a bitfield where if bit i is set, it means that the VkMemoryType i 
// of the VkPhysicalDeviceMemoryProperties structure satisfies the memory requirements
auto memoryTypeIndex(
	VkPhysicalDeviceMemoryProperties	memory_properties,
	VkMemoryRequirements				memory_requirements,
	VkMemoryPropertyFlags				memory_property_flags ) {

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



///////////////////////////////////////
// meta memory and related functions //
///////////////////////////////////////

struct Meta_Memory {
	mixin 					Vulkan_State_Pointer;
	VkDeviceMemory			device_memory;
	private VkDeviceSize	device_memory_size;

	// bulk destroy the resources belonging to this meta struct
	void destroyResources() {
		vk.device.vkFreeMemory( device_memory, vk.allocator );
	}
}


auto ref createMemory( ref Meta_Memory meta, VkDeviceSize allocation_size, uint32_t memory_type_index ) {
	meta.device_memory = allocateMemory( meta, allocation_size, memory_type_index );
	meta.device_memory_size = allocation_size;
	return meta;
}


auto ref initMemory( ref Vulkan vk, VkDeviceSize allocation_size, uint32_t memory_type_index ) {
	Meta_Memory meta = vk;
	return meta.createMemory( allocation_size, memory_type_index );
}



///////////////////////////////////////////////////////////
// meta buffer and meta image related template functions //
///////////////////////////////////////////////////////////

mixin template Memory_Member() {
	VkMemoryRequirements	memory_requirements;
	VkDeviceMemory			device_memory;
	private VkDeviceSize	device_memory_offset;
	private bool			owns_device_memory = false;
	VkDeviceSize offset()	{ return device_memory_offset; }
	VkDeviceSize size()		{ return memory_requirements.size; }
}

private template hasMemReqs( T ) { 
	enum hasMemReqs = __traits( hasMember, T, "memory_requirements" );
		//&& is( typeof( __traits( getMemeber, T, "memory_requirements" )) == VkMemoryRequirements )
}



auto memoryTypeIndex( ref Meta_Buffer meta, VkMemoryPropertyFlags memory_property_flags ) {				// can't be a template function as another overload exists already (general function)
	return memoryTypeIndex( meta.memory_properties, meta.memory_requirements, memory_property_flags );
}


auto memoryTypeIndex( ref Meta_Image meta, VkMemoryPropertyFlags memory_property_flags ) {				// can't be a template function as another overload exists already (general function)
	return memoryTypeIndex( meta.memory_properties, meta.memory_requirements, memory_property_flags );
}


auto requiredMemorySize( META )( ref META meta ) if( hasMemReqs!META ) {
	return meta.memory_requirements.size;
}


auto alignedMemorySize( META )( ref META meta ) if( hasMemReqs!META ) {
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
auto ref createMemoryImpl( META )( ref META meta, VkMemoryPropertyFlags memory_property_flags ) if( hasMemReqs!META ) {
	meta.owns_device_memory = true;
	meta.device_memory = allocateMemory( meta, meta.memory_requirements.size, meta.memoryTypeIndex( memory_property_flags ));
	static if( is( META == Meta_Buffer ))	meta.device.vkBindBufferMemory( meta.buffer, meta.device_memory, 0 ).vkEnforce;
	else									meta.device.vkBindImageMemory( meta.image, meta.device_memory, 0 ).vkEnforce;
	return meta;
}


auto ref bindMemoryImpl( META )( ref META meta, VkDeviceMemory device_memory, VkDeviceSize device_memory_offset = 0 )if( hasMemReqs!META ) {
	meta.owns_device_memory = false;
	meta.device_memory = device_memory;
	meta.device_memory_offset = device_memory_offset;
	static if( is( META == Meta_Buffer ))	meta.device.vkBindBufferMemory( meta.buffer, device_memory, device_memory_offset ).vkEnforce;
	else									meta.device.vkBindImageMemory( meta.image, device_memory, device_memory_offset ).vkEnforce;
	return meta;
}


// alias buffer this (in e.g. Meta_Goemetry) does not work with the Impl functions above
// but it does work with the aliases for that functions bellow  
alias createMemory = createMemoryImpl!Meta_Buffer;
alias createMemory = createMemoryImpl!Meta_Image;
alias bindMemory = bindMemoryImpl!Meta_Buffer;
alias bindMemory = bindMemoryImpl!Meta_Image;




///////////////////////////////////////
// meta buffer and related functions //
///////////////////////////////////////

/// struct to capture buffer and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct  
struct Meta_Buffer {
	mixin 					Vulkan_State_Pointer;
	VkBuffer				buffer;
	VkBufferCreateInfo		buffer_create_info;
	VkBufferView			buffer_view;
	VkBufferViewCreateInfo	buffer_view_create_info;

	mixin					Memory_Member;

	// bulk destroy the resources belonging to this meta struct
	void destroyResources() {
		vk.device.vkDestroyBuffer( buffer, vk.allocator );
		if( buffer_view != VK_NULL_ND_HANDLE )
			vk.device.vkDestroyBufferView( buffer_view, vk.allocator );
		if( owns_device_memory )
			vk.device.vkFreeMemory( device_memory, vk.allocator );
	}
	debug string name;
}


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



/// struct to capture image and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct  
struct Meta_Image {
	mixin 					Vulkan_State_Pointer;
	VkImage					image;
	VkImageCreateInfo		image_create_info;
	VkImageView				image_view;
	VkImageViewCreateInfo	image_view_create_info;

	mixin					Memory_Member;

	// bulk destroy the resources belonging to this meta struct
	void destroyResources() {
		vk.device.vkDestroyImage( image, vk.allocator );
		if( image_view != VK_NULL_ND_HANDLE )
			vk.device.vkDestroyImageView( image_view, vk.allocator );
		if( owns_device_memory )
			vk.device.vkFreeMemory( device_memory, vk.allocator );
	}
	debug string name;
}



//////////////////////////////////////
// meta image and related functions //
//////////////////////////////////////

/// create simple VkImage with one level and one layer, assume VK_IMAGE_TILING_OPTIMAL and VK_SHARING_MODE_EXCLUSIVE
/// store vulkan data in argument meta image container, return container for piping 
auto ref createImage( 
	ref Meta_Image			meta,
	VkFormat				image_format,
	VkExtent2D				image_extent,
	VkImageUsageFlags		image_usage,
	VkSampleCountFlagBits	image_samples = VK_SAMPLE_COUNT_1_BIT ) {

	VkImageCreateInfo image_create_info = {
		imageType				: VK_IMAGE_TYPE_2D,
		format					: image_format,									// notice me senpai!
		extent					: { image_extent.width, image_extent.height, 1 },
		mipLevels				: 1,
		arrayLayers				: 1,
		samples					: image_samples,								// notice me senpai!
		tiling					: VK_IMAGE_TILING_OPTIMAL,
		usage					: image_usage,									// notice me senpai!
		sharingMode				: VK_SHARING_MODE_EXCLUSIVE,
		queueFamilyIndexCount	: 0,
		pQueueFamilyIndices		: null,
		initialLayout			: VK_IMAGE_LAYOUT_UNDEFINED,             		// notice me senpai!
	};

	return meta.createImage( image_create_info );
}



/// init a simple VkImage with one level and one layer, assume VK_IMAGE_TILING_OPTIMAL and VK_SHARING_MODE_EXCLUSIVE
/// store vulkan data in argument meta image container, return container for piping 
auto initImage(
	ref Vulkan				vk,
	VkFormat				image_format,
	VkExtent2D				image_extent,
	VkImageUsageFlags		image_usage,
	VkSampleCountFlagBits	image_samples = VK_SAMPLE_COUNT_1_BIT ) {

	Meta_Image meta = vk;
	return meta.createImage( image_format, image_extent, image_usage, image_samples );
} 



/// create a VkImage, general create image function, gets a VkImageCreateInfo as argument 
/// store vulkan data in argument meta image container, return container for piping
auto ref createImage( ref Meta_Image meta, const ref VkImageCreateInfo image_create_info ) {
	meta.image_create_info = image_create_info;
	meta.device.vkCreateImage( &meta.image_create_info, meta.allocator, &meta.image ).vkEnforce;
	meta.device.vkGetImageMemoryRequirements( meta.image, &meta.memory_requirements );
	return meta;
}



/// init a VkImage, general init image function, gets a VkImageCreateInfo as argument 
/// store vulkan data in argument meta image container, return container for piping
auto initImage( ref Vulkan vk, const ref VkImageCreateInfo image_create_info ) {
	Meta_Image meta = vk;
	return meta.createImage( image_create_info );
}



/// create a VkImageView which closely coresponds to the underlying VkImage type
/// store vulkan data in argument meta image container, return container for piping
auto ref imageView( ref Meta_Image meta, VkImageAspectFlags subrecource_aspect_mask ) {
	VkImageSubresourceRange subresource_range = {
		aspectMask		: subrecource_aspect_mask,
		baseMipLevel	: cast( uint32_t )0,
		levelCount		: meta.image_create_info.mipLevels,
		baseArrayLayer	: cast( uint32_t )0,
		layerCount		: meta.image_create_info.arrayLayers, };
	return meta.imageView( subresource_range );
}

/// create a VkImageView which closely coresponds to the underlying VkImage type
/// store vulkan data in argument meta image container, return container for piping
auto ref imageView( ref Meta_Image meta, VkImageSubresourceRange subresource_range ) {
	return meta.imageView( subresource_range, cast( VkImageViewType )meta.image_create_info.imageType, meta.image_create_info.format );
}

/// create a VkImageView with choosing a image view type and format for the underlying VkImage, component mapping is identity
/// store vulkan data in argument meta image container, return container for piping
auto ref imageView( ref Meta_Image meta, VkImageSubresourceRange subresource_range, VkImageViewType view_type, VkFormat format ) {
	return meta.imageView( subresource_range, view_type, format, VkComponentMapping(
		VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY ));
}

/// create a VkImageView with choosing a image view type, format and VkComponentMapping for the underlying VkImage
/// store vulkan data in argument meta image container, return container for piping
auto ref imageView( ref Meta_Image meta, VkImageSubresourceRange subresource_range, VkImageViewType view_type, VkFormat format, VkComponentMapping component_mapping ) {
	meta.image_view_create_info.image				= meta.image;
	meta.image_view_create_info.viewType			= view_type;
	meta.image_view_create_info.format				= format;
	meta.image_view_create_info.subresourceRange	= subresource_range;
	meta.image_view_create_info.components			= component_mapping;
	vkCreateImageView( meta.device, &meta.image_view_create_info, meta.allocator, &meta.image_view ).vkEnforce;
	return meta;
}


/// records a VkImage transition command in argument command buffer 
void recordTransition(
	VkImage 				image,
	VkCommandBuffer			command_buffer,
	VkImageSubresourceRange	subresource_range,
	VkImageLayout 			old_layout,
	VkImageLayout 			new_layout,
	VkAccessFlags 			src_accsess_mask,
	VkAccessFlags 			dst_accsess_mask,
	VkDependencyFlags		dependency_flags = 0,
	VkPipelineStageFlags	src_stage_mask = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
	VkPipelineStageFlags	dst_stage_mask = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT ) {

	VkImageMemoryBarrier layout_transition_barrier = {
		srcAccessMask		: src_accsess_mask,
		dstAccessMask		: dst_accsess_mask,
		oldLayout			: old_layout,
		newLayout			: new_layout,
		srcQueueFamilyIndex	: VK_QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex	: VK_QUEUE_FAMILY_IGNORED,
		image				: image,
		subresourceRange	: subresource_range,
	};

	command_buffer.vkCmdPipelineBarrier(   
		src_stage_mask, dst_stage_mask, dependency_flags,
		0, null, 0, null, 1, &layout_transition_barrier
	);
}



// checking format support
//VkFormatProperties format_properties;
//vk.gpu.vkGetPhysicalDeviceFormatProperties( VK_FORMAT_B8G8R8A8_UNORM, &format_properties );
//format_properties.printTypeInfo;

// checking image format support (additional capabilities)
//VkImageFormatProperties image_format_properties;
//vk.gpu.vkGetPhysicalDeviceImageFormatProperties(
//	VK_FORMAT_B8G8R8A8_UNORM,
//	VK_IMAGE_TYPE_2D,
//	VK_IMAGE_TILING_OPTIMAL,
//	VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
//	0,
//	&image_format_properties).vkEnforce;
//image_format_properties.printTypeInfo;
