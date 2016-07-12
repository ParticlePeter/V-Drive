module vdrive.surface;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;

import std.stdio;



/// struct to capture buffer and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct  
struct Meta_Surface {
	mixin 						Vulkan_State_Pointer;
	VkQueue						present_queue = VK_NULL_HANDLE;
	uint32_t					present_queue_family_index;
	VkSwapchainKHR				swapchain;
	VkSwapchainCreateInfoKHR	create_info;

	//alias surface 			=	create_info.surface;
	//alias min_image_count		=	create_info.minImageCount;
	//alias format				=	create_info.imageFormat;
	//alias color_space			=	create_info.imageColorSpace;
	//alias extent				=	create_info.imageExtent;
	//alias array_layers		=	create_info.imageArrayLayers;
	//alias usage				=	create_info.imageUsage;
	//alias sharing_mode		=	create_info.imageSharingMode;
	//alias pre_transform		=	create_info.preTransform;
	//alias composite_alpha		=	create_info.compositeAlpha;
	//alias present_mode		=	create_info.presentMode;
	//alias clipped				=	create_info.clipped;

	// forward all members of vk and create_info to Meta_Surface
	mixin Dispatch_To_Inner_Struct!create_info;

	// convenience to get VkSurfaceFormatKHR from VkSwapchainCreateInfoKHR.imageFormat and .imageColorSpace and set vice versa
	auto surfaceFormat() { return VkSurfaceFormatKHR( create_info.imageFormat, create_info.imageColorSpace ); }
	void surfaceFormat( VkSurfaceFormatKHR surface_format ) {
		create_info.imageFormat = surface_format.format;
		create_info.imageColorSpace = surface_format.colorSpace;
	}

	// two different resource destroy functions for two distinct places
	void destroySurface() { instance.vkDestroySurfaceKHR( create_info.surface, vk.allocator ); }
	void destroySwapchain() { device.vkDestroySwapchainKHR( swapchain, vk.allocator ); }

	// try to destroy together
	void destroyResources() {
		destroySwapchain;
		destroySurface;
	}
}






auto ref selectSurfaceFormat( ref Meta_Surface meta, VkFormat[] include_formats, bool first_available_as_fallback = true ) {
	meta.surfaceFormat = meta.gpu.listSurfaceFormats( meta.surface, false ).filter( include_formats );
	return meta;
}

auto ref selectPresentMode( ref Meta_Surface meta, VkPresentModeKHR[] include_modes, bool first_available_as_fallback = true ) {
	meta.presentMode = meta.gpu.listPresentModes( meta.surface, false ).filter( include_modes );
	return meta;
}

auto ref createSwapchain( ref Meta_Surface meta ) {

	// request different count of images dependent on selected present mode
	if( meta.minImageCount == 0 ) {
		switch( meta.presentMode ) {
			case VK_PRESENT_MODE_MAILBOX_KHR		: meta.minImageCount = 3; break;
			case VK_PRESENT_MODE_FIFO_KHR 			:
			case VK_PRESENT_MODE_FIFO_RELAXED_KHR	: meta.minImageCount = 2; break;
			default									: meta.minImageCount = 1; break;		// VK_PRESENT_MODE_IMMEDIATE_KHR
		}
	}

	// Get GPU surface capabilities
	VkSurfaceCapabilitiesKHR surface_capabilities;
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR( meta.gpu, meta.surface, &surface_capabilities );

	import std.algorithm : clamp;
	meta.minImageCount = meta.minImageCount.clamp( surface_capabilities.minImageCount, surface_capabilities.maxImageCount );
	if( meta.minImageCount == 0 ) {
		printf( "Need at least one image in the swap chain, but max count is: %u", surface_capabilities.maxImageCount );
		VK_ERROR_FEATURE_NOT_PRESENT.vkEnforce;
		return meta;
	}
	
	//printf( "\nImage Count: %u\n", image_count );

	// Determine surface resolution
	if( surface_capabilities.currentExtent.width == -1 ) {
		meta.imageExtent.width  = meta.imageExtent.width.clamp(  surface_capabilities.minImageExtent.width,  surface_capabilities.maxImageExtent.width  );
		meta.imageExtent.height = meta.imageExtent.height.clamp( surface_capabilities.minImageExtent.height, surface_capabilities.maxImageExtent.height );
	} else {
		meta.imageExtent = surface_capabilities.currentExtent;
	}

	// Try to use identity transform, otherwise the surface_capabilities.currentTransform
	if( surface_capabilities.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR ) {
		meta.preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
	} else {
		meta.preTransform = surface_capabilities.currentTransform;
	}

	vkCreateSwapchainKHR( meta.vk.device, &meta.create_info, meta.allocator, &meta.swapchain ).vkEnforce;
	return meta;
}



auto ref initSwapchain( 
	ref Meta_Surface 			meta,
	bool						clipped,
	VkSharingMode				image_sharing_mode = VK_SHARING_MODE_EXCLUSIVE,
	VkImageUsageFlagBits		image_usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
	VkCompositeAlphaFlagBitsKHR	composite_alpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR ) {

	VkFormat[4] request_format = [ VK_FORMAT_R8G8B8_UNORM, VK_FORMAT_B8G8R8_UNORM, VK_FORMAT_R8G8B8A8_UNORM, VK_FORMAT_B8G8R8A8_UNORM ];
	VkPresentModeKHR[2] request_mode = [ VK_PRESENT_MODE_MAILBOX_KHR, VK_PRESENT_MODE_FIFO_KHR ];
	meta.selectSurfaceFormat( request_format );
	meta.selectPresentMode( request_mode );


	meta.imageArrayLayers 	= 1;
	meta.imageUsage 		= image_usage;
	meta.imageSharingMode 	= image_sharing_mode;
	meta.compositeAlpha 	= composite_alpha;
	meta.clipped 			= clipped;

	meta.createSwapchain;
	return meta;

}


auto swapchainImageViews( ref Meta_Surface meta, VkImageAspectFlags subrecource_aspect_mask = VK_IMAGE_ASPECT_COLOR_BIT, VkImageViewType image_view_type = VK_IMAGE_VIEW_TYPE_2D ) {
	VkImageSubresourceRange image_subresource_range = {
		aspectMask 		: VK_IMAGE_ASPECT_COLOR_BIT,
		baseMipLevel	: 0,
		levelCount		: 1,
		baseArrayLayer	: 0,
		layerCount		: 1,
	};
	return swapchainImageViews( meta, image_subresource_range, image_view_type );
}


auto swapchainImageViews( ref Meta_Surface meta, VkImageSubresourceRange image_subresource_range, VkImageViewType image_view_type = VK_IMAGE_VIEW_TYPE_2D ) {
	VkImageViewCreateInfo image_view_create_info = {
		viewType 			: image_view_type,
		format				: meta.imageFormat,
		components			: { VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY },
		subresourceRange	: image_subresource_range,
	};
	return swapchainImageViews( meta, image_view_create_info );
}


auto swapchainImageViews( ref Meta_Surface meta, VkImageViewCreateInfo image_view_create_info ) {

	// Get the swapchain images
	//uint32_t present_image_count = 0;
	//vkGetSwapchainImagesKHR( vk.device, vk.swapchain, &present_image_count, null );
	//vk.present_images.length = present_image_count;
	//vkGetSwapchainImagesKHR( vk.device, vk.swapchain, &present_image_count, vk.present_images.ptr );

	// Create image views of the swapchain images in the passed in argument present_image_views
	auto present_images = listVulkanProperty!( VkImage, vkGetSwapchainImagesKHR, VkDevice, VkSwapchainKHR )( meta.device, meta.swapchain );

	Array!VkImageView present_image_views;
	present_image_views.length = present_images.length;
	foreach( i; 0 .. present_image_views.length ) {
		// complete VkImageViewCreateInfo with image i:
		image_view_create_info.image = present_images[i];

		// create the view for the ith swapchain image
		vkCreateImageView( meta.device, &image_view_create_info, meta.allocator, &present_image_views[i] ).vkEnforce;
	}

	return present_image_views;
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
