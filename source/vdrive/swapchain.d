module vdrive.swapchain;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;

import std.stdio;



/// struct to capture buffer and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct  
struct Meta_Swapchain {
	this( Vulkan* vk )		{  this.vk = vk;  }
	alias 					vk this;
	Vulkan*					vk;

	VkSurfaceKHR		surface;
	VkSurfaceFormatKHR 	surface_format;
	VkExtent2D			surface_extent;
	VkPresentModeKHR	present_mode;
	VkSwapchainKHR		swapchain;
}






auto ref selectSurfaceFormat( ref Meta_Swapchain meta, VkFormat[] include_formats, bool first_available_as_fallback = true ) {
	meta.surface_format = meta.gpu.listSurfaceFormats( meta.surface, false ).filter( include_formats );
	return meta;
}

auto ref selectPresentMode( ref Meta_Swapchain meta, VkPresentModeKHR[] include_modes, bool first_available_as_fallback = true ) {
	meta.present_mode = meta.gpu.listPresentModes( meta.surface, false ).filter( include_modes );
	return meta;
}



auto init_swapchain( ref Vulkan vk, ref Array!VkImageView present_image_views ) {

	//VkFormat[4] request_format = [ VK_FORMAT_R8G8B8_UNORM, VK_FORMAT_B8G8R8_UNORM, VK_FORMAT_R8G8B8A8_UNORM, VK_FORMAT_B8G8R8A8_UNORM ];
	//VkPresentModeKHR[2] request_mode = [ VK_PRESENT_MODE_MAILBOX_KHR, VK_PRESENT_MODE_FIFO_KHR ];
	//meta.selectSurfaceFormat( request_format );
	//meta.selectPresentMode( request_mode );

	// Get GPU surface formats
	auto surface_formats = listSurfaceFormats( vk.gpu, vk.surface, false );
	//foreach( ref format; surface_formats ) { format.printTypeInfo;

	if( surface_formats.length == 0 ) { 
		printf( "No surface format available!\n" );
		return VK_ERROR_FEATURE_NOT_PRESENT;
	}

	// Select surface format

	VkFormat[4] request_format = [ VK_FORMAT_R8G8B8_UNORM, VK_FORMAT_B8G8R8_UNORM, VK_FORMAT_R8G8B8A8_UNORM, VK_FORMAT_B8G8R8A8_UNORM ];
	auto present_surface_format = surface_formats.filterSurfaceFormats( request_format );
	vk.present_image_format = present_surface_format.format;
	//present_surface_format.printTypeInfo;

	
	// Get GPU present modes
	VkPresentModeKHR[2] request_mode = [ VK_PRESENT_MODE_MAILBOX_KHR, VK_PRESENT_MODE_FIFO_KHR ];
	auto present_mode = vk.gpu.listPresentModes( vk.surface, false ).filter( request_mode );
	printf( "Selected Present Mode: %s\n", present_mode.toStringz.ptr );


	// Get GPU surface capabilities
	VkSurfaceCapabilitiesKHR surface_capabilities;
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR( vk.gpu, vk.surface, &surface_capabilities );
	//surface_capabilities.printTypeInfo;



	// Try to get 2 images for double buffered presentation
	import std.algorithm : clamp;
	uint32_t image_count;// = present_mode == VK_PRESENT_MODE_MAILBOX_KHR ? 3 : 2;	// request 3, 2 or 1 image(s)
	switch( present_mode ) {
		case VK_PRESENT_MODE_MAILBOX_KHR		: image_count = 3; break;
		case VK_PRESENT_MODE_FIFO_KHR 			:
		case VK_PRESENT_MODE_FIFO_RELAXED_KHR	: image_count = 2; break;
		default									: image_count = 1; break;		// VK_PRESENT_MODE_IMMEDIATE_KHR
	}

	image_count = image_count.clamp( surface_capabilities.minImageCount, surface_capabilities.maxImageCount );
	if( image_count == 0 ) {
		printf( "Need at least one image in the swap chain, but max count is: %u", surface_capabilities.maxImageCount );
		return VK_ERROR_FEATURE_NOT_PRESENT;
	}
	
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
		imageColorSpace		: present_surface_format.colorSpace,
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
		vkCreateImageView( vk.device, &present_image_view_create_info, vk.allocator, &present_image_views[i] ).vkEnforce;
	}

	return vkResult;
}



////////////////////////////
// utility info functions //
////////////////////////////

/// list surface formats 
auto listSurfaceFormats( VkPhysicalDevice gpu, VkSurfaceKHR surface, bool printInfo = true ) {
	auto surface_formats = listVulkanProperty!( 
		VkSurfaceFormatKHR, vkGetPhysicalDeviceSurfaceFormatsKHR, VkPhysicalDevice, VkSurfaceKHR )( gpu, surface );

	if(	surface_formats.length == 0 ) {
		printf( "No Surface Formats available!" );
	} else if( printInfo ) {
		foreach( surface_format; surface_formats ) 
			surface_format.printTypeInfo;
		println;
	}
	return surface_formats;
}

/// filter surface formats
alias filter = filterSurfaceFormats;
auto filterSurfaceFormats( Array_T )( Array_T surface_formats, VkFormat[] include_formats, bool first_available_as_fallback = true )
if( is( Array_T == Array!VkSurfaceFormatKHR ) || is( Array_T : VkSurfaceFormatKHR[] )) {
	// if this function returns surfac_format.format == VK_FORMAT_MAX_ENUM this means that no requested format could be found
	auto result_format = first_available_as_fallback && surface_formats.length > 0 ? 
		surface_formats[0] : 
		VkSurfaceFormatKHR( VK_FORMAT_MAX_ENUM, VK_COLORSPACE_SRGB_NONLINEAR_KHR );

	// All formats are available, pick the first requested
	if( surface_formats.length == 1 && result_format.format == VK_FORMAT_UNDEFINED ) {
		result_format.format = include_formats[0];
		return result_format;
	}

	// few are available, search for the first match
	foreach( include_format; include_formats ) {
		foreach( surface_format; surface_formats ) {
			if( surface_format.format == include_format ) {
				result_format.format = include_format;
				return result_format;
			}
		}
	}

	return result_format;
}


/// list presentation modes
auto listPresentModes( VkPhysicalDevice gpu, VkSurfaceKHR surface, bool printInfo = true ) {
	auto present_modes = listVulkanProperty!( 
		VkPresentModeKHR, vkGetPhysicalDeviceSurfacePresentModesKHR, VkPhysicalDevice, VkSurfaceKHR )( gpu, surface );

	if( printInfo ) {
		if(	present_modes.length == 0 )  {
			printf( "Present Modes: None\n" );
		} else {
			printf( "VkPresentModeKHR\n=================\n" ); 
			foreach( present_mode; present_modes ) {
				printf( "\tPresent Mode: %s\n", present_mode.toStringz.ptr );

			}
		}	
		writeln;
	}
	return present_modes;
}

/// list presentation modes
alias filter = filterPresentModes;
auto filterPresentModes( Array_T )( Array_T present_modes, VkPresentModeKHR[] include_modes, bool first_available_as_fallback = true )
if( is( Array_T == Array!VkPresentModeKHR ) || is( Array_T : VkPresentModeKHR[] )) {
	// if first_available_as_fallback is false and no present mode can be filtered this returns an non existing present mode
	auto result_mode = first_available_as_fallback && present_modes.length > 0 ? present_modes[0] : VK_PRESENT_MODE_MAX_ENUM_KHR;

	// few are available, search for the first match
	foreach( include_mode; include_modes )
		foreach( present_mode; present_modes )
			if( present_mode == include_mode )
				return include_mode;

	return result_mode;
}
/*
auto ref selectSurfaceFormat( ref Meta_Swapchain meta, VkFormat[] include_formats, bool first_available_as_fallback = true ) {
	meta.surface_format = meta.gpu.listSurfaceFormats( meta.surface, false ).filter( include_formats );
	return meta;
}

auto ref selectPresentMode( ref Meta_Swapchain meta, VkPresentModeKHR[] include_modes, bool first_available_as_fallback = true ) {
	meta.present_mode = meta.gpu.listPresentModes( meta.surface, false ).filter( include_modes );
	return meta;
}
*/