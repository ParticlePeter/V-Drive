module vdrive.image;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;


import erupted;

/// container for buffer related data
struct Meta_Image {
	this( Vulkan* vk )		{  this.vk = vk;  }
	alias 					vk this;
	Vulkan*					vk;
	VkImage					image;
	VkImageCreateInfo		image_create_info;
	VkImageView				image_view;
	VkImageViewCreateInfo	image_view_create_info;
	VkMemoryRequirements	memory_requirements;
	VkDeviceMemory			device_memory;
}


/// create a VkImage, store vulkan data in argument meta image container, return container for piping
auto ref createImage( ref Meta_Image meta, const ref VkImageCreateInfo image_create_info ) {
	
	// general create image function gets the image creat info as argument
	meta.image_create_info = image_create_info;
	meta.device.vkCreateImage( &meta.image_create_info, meta.allocator, &meta.image ).vk_enforce;
	meta.device.vkGetImageMemoryRequirements( meta.image, &meta.memory_requirements );
	return meta;
}


/// allocate required VkDeviceMemory and bind to VkImage
/// store vulkan data in argument meta image container, return container for piping 
auto ref bindMemory( ref Meta_Image meta, VkMemoryPropertyFlags memory_property_flags ) {

	import vdrive.memory;
	meta.device_memory = ( *meta.vk ).allocateMemory( meta.memory_requirements.size,
		meta.memory_properties.memoryTypeIndex( meta.memory_requirements, memory_property_flags ));

	meta.device.vkBindImageMemory( meta.image, meta.device_memory, 0 ).vk_enforce;

	return meta;
}


/// create a VkImageView which closely coresponds to the underlying VkImage type
/// store vulkan data in argument meta image container, return container for piping
auto ref imageView( ref Meta_Image meta, VkImageSubresourceRange subresource_range ) {

	meta.image_view_create_info.image				= meta.image;
	meta.image_view_create_info.viewType			= cast( VkImageViewType )meta.image_create_info.imageType;
	meta.image_view_create_info.format			= meta.image_create_info.format;
	meta.image_view_create_info.subresourceRange	= subresource_range;
	meta.image_view_create_info.components		= 
		VkComponentMapping(
			VK_COMPONENT_SWIZZLE_IDENTITY, 
			VK_COMPONENT_SWIZZLE_IDENTITY, 
			VK_COMPONENT_SWIZZLE_IDENTITY, 
			VK_COMPONENT_SWIZZLE_IDENTITY 
		);

	vkCreateImageView( meta.device, &meta.image_view_create_info, meta.allocator, &meta.image_view ).vk_enforce;
	return meta;
}


/// create typical depth buffer VkImage, store vulkan data in argument meta image container, return container for piping
auto ref createDepthBufferImage( ref Meta_Image meta, VkFormat depth_image_format, VkExtent2D depth_image_extent ) {

	VkImageCreateInfo depth_image_create_info = {
		imageType				: VK_IMAGE_TYPE_2D,
		format					: depth_image_format,						// notice me senpai!
		extent					: { depth_image_extent.width, depth_image_extent.height, 1 },
		mipLevels				: 1,
		arrayLayers				: 1,
		samples					: VK_SAMPLE_COUNT_1_BIT,						// notice me senpai!
		tiling					: VK_IMAGE_TILING_OPTIMAL,
		usage					: VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,	// notice me senpai!
		sharingMode				: VK_SHARING_MODE_EXCLUSIVE,
		queueFamilyIndexCount	: 0,
		pQueueFamilyIndices		: null,
		initialLayout			: VK_IMAGE_LAYOUT_UNDEFINED,             		// notice me senpai!
	};

	return meta.createImage( depth_image_create_info );
}


/// records a VkImage transition command in argument command buffer 
void imageTransition(
	VkCommandBuffer			command_buffer,
	VkImage 				image, 
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

