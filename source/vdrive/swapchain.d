module vdrive.swapchain;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;


auto init_swapchain( ref Vulkan vk, ref Array!VkImageView present_image_views ) {

	// Get GPU surface formats
	uint32_t surface_formats_count;
	vkGetPhysicalDeviceSurfaceFormatsKHR( vk.gpu, vk.surface, &surface_formats_count, null ).vk_enforce;
	if( surface_formats_count == 0 ) { printf( "No surface format available!\n" ); return VK_ERROR_FEATURE_NOT_PRESENT; }
	auto surface_formats = sizedArray!VkSurfaceFormatKHR( surface_formats_count );
	vkGetPhysicalDeviceSurfaceFormatsKHR( vk.gpu, vk.surface, &surface_formats_count, surface_formats.ptr ).vk_enforce;
	//foreach( i, ref format; surface_formats.data ) { printf( "&u\n", i ); format.printStructInfo; }

	// Select surface format
	vk.present_image_format = surface_formats[0].format;
	VkColorSpaceKHR present_images_color_space = surface_formats[0].colorSpace;
	if( surface_formats.length == 1 && surface_formats[0].format == VK_FORMAT_UNDEFINED ) 
		vk.present_image_format = VK_FORMAT_R8G8B8_UNORM;

	else foreach( ref surface_format; surface_formats )
		if( surface_format.format == VK_FORMAT_R8G8B8_UNORM )
			vk.present_image_format = surface_format.format;





	// Get GPU present modes
	uint32_t present_modes_count;
	vkGetPhysicalDeviceSurfacePresentModesKHR( vk.gpu, vk.surface, &present_modes_count, null ).vk_enforce;
	if( present_modes_count == 0 ) { printf( "No present modes available!\n" ); return VK_ERROR_FEATURE_NOT_PRESENT; }
	auto present_modes = sizedArray!VkPresentModeKHR( present_modes_count );
	vkGetPhysicalDeviceSurfacePresentModesKHR( vk.gpu, vk.surface, &present_modes_count, present_modes.ptr ).vk_enforce;
	//foreach( ref mode; present_modes ) { printf( "%d\n", mode ); }

	// Prefere VK_PRESENT_MODE_MAILBOX_KHR
	bool fifo_available = false;
	VkPresentModeKHR present_mode = VK_PRESENT_MODE_FIFO_KHR;
	foreach( ref mode; present_modes ) {
		if( mode == VK_PRESENT_MODE_FIFO_KHR )  fifo_available = true;
		if( mode == VK_PRESENT_MODE_MAILBOX_KHR ) present_mode = mode;
	}
	if( !fifo_available ) { printf( "VK_PRESENT_MODE_FIFO_KHR not available!\n" ); return VK_ERROR_FEATURE_NOT_PRESENT; }
	//printf( "VK_PRESENT_MODE_MAILBOX_KHR: %d", present_mode = VK_PRESENT_MODE_MAILBOX_KHR );



	// Get GPU surface capabilities
	VkSurfaceCapabilitiesKHR surface_capabilities;
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR( vk.gpu, vk.surface, &surface_capabilities );
	//surface_capabilities.printStructInfo;



	// Try to get 2 images for double buffered presentation
	import std.algorithm : clamp;
	uint32_t image_count = present_mode == VK_PRESENT_MODE_MAILBOX_KHR ? 3 : 2;	// request 3 or 2 images
	image_count = image_count.clamp( surface_capabilities.minImageCount, surface_capabilities.maxImageCount );
	if( image_count == 0 ) { printf( "Need at least one image in the swap chain, but max count is: %u", surface_capabilities.maxImageCount ); return VK_ERROR_FEATURE_NOT_PRESENT;	}
	//printf( "\nImage Count: %u\n", image_count );

	// Determine surface resolution
	if( surface_capabilities.currentExtent.width == -1 ) {
		vk.surface_extent.width  = vk.surface_extent.width.clamp(  surface_capabilities.minImageExtent.width,  surface_capabilities.maxImageExtent.width  );
		vk.surface_extent.height = vk.surface_extent.height.clamp( surface_capabilities.minImageExtent.height, surface_capabilities.maxImageExtent.height );
	} else {
		vk.surface_extent = surface_capabilities.currentExtent;
	}



	// Try to use identity transform, othrewise the surface_capabilities.currentTransform
	VkSurfaceTransformFlagBitsKHR pre_transform = surface_capabilities.currentTransform;
	if( surface_capabilities.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR ) {
		pre_transform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
	}



	// Create the swapchain
	VkSwapchainCreateInfoKHR swapchain_create_info = {
		surface 			: vk.surface,
		minImageCount		: image_count,
		imageFormat			: vk.present_image_format,
		imageColorSpace		: present_images_color_space,
		imageExtent			: vk.surface_extent,
		imageArrayLayers	: 1,
		imageUsage			: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
		imageSharingMode	: VK_SHARING_MODE_EXCLUSIVE,
		preTransform		: pre_transform,
		compositeAlpha		: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		presentMode			: present_mode,
		clipped				: true,     // If we want clipping outside the extents (remember our device features?)
	};

	auto vkResult = vkCreateSwapchainKHR( vk.device, &swapchain_create_info, vk.allocator, &vk.swapchain );
	if( vkResult != VK_SUCCESS ) return vkResult;

	// Get the swapchain images
	uint32_t present_image_count = 0;
	vkGetSwapchainImagesKHR( vk.device, vk.swapchain, &present_image_count, null );
	vk.present_images.length = present_image_count;
	vkGetSwapchainImagesKHR( vk.device, vk.swapchain, &present_image_count, vk.present_images.ptr );

	// Create image views of the swapchain images in the passed in argument present_image_views
	VkImageSubresourceRange present_image_subresource_range = {
		aspectMask 		: VK_IMAGE_ASPECT_COLOR_BIT,
		baseMipLevel	: 0,
		levelCount		: 1,
		baseArrayLayer	: 0,
		layerCount		: 1,
	};

	VkImageViewCreateInfo present_image_view_create_info = {
		viewType 			: VK_IMAGE_VIEW_TYPE_2D,
		format				: vk.present_image_format,
		components			: { VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY },
		subresourceRange	: present_image_subresource_range,
	};


	present_image_views.length = vk.present_images.length;
	foreach( i; 0 .. vk.present_images.length ) {
		// complete VkImageViewCreateInfo with image i:
		present_image_view_create_info.image = vk.present_images[i];

		// create the view for the ith swapchain image
		vkCreateImageView( vk.device, &present_image_view_create_info, vk.allocator, &present_image_views[i] ).vk_enforce;
	}

	return vkResult;
}

