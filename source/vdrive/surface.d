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
//	uint32_t					present_queue_family_index;			// does not seem to be required so far
	VkSwapchainKHR				swapchain;
	VkSwapchainCreateInfoKHR	create_info;

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


// forward members of Meta_Surface.create_info to setter and getter functions
mixin( Forward_To_Inner_Struct!( Meta_Surface, VkSwapchainCreateInfoKHR, "meta.create_info" ));


auto ref construct( ref Meta_Surface meta ) {
	// assert that meta struct is initialized with a valid vulkan state pointer
	assert( meta.isValid );

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

	meta.create_info.oldSwapchain = meta.swapchain; 		// store this in case we are reecreating the swapchain
	vkCreateSwapchainKHR( meta.vk.device, &meta.create_info, meta.allocator, &meta.swapchain ).vkEnforce;
	if( meta.create_info.oldSwapchain )						// if the old swapchain was valid
		meta.destroy( meta.create_info.oldSwapchain );		// destroy it now

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
	// assert that meta struct is initialized with a valid vulkan state pointer
	assert( meta.isValid );

	// Create image views of the swapchain images in the passed in argument present_image_views
	auto present_images = listVulkanProperty!( VkImage, vkGetSwapchainImagesKHR, VkDevice, VkSwapchainKHR )( meta.device, meta.swapchain );

	// allocate storage for image views and create one view per swapchain image in a loop
	auto present_image_views = sizedArray!VkImageView( present_images.length );
	foreach( i; 0 .. present_image_views.length ) {
		image_view_create_info.image = present_images[i];	// complete VkImageViewCreateInfo with image i:
		vkCreateImageView( meta.device, &image_view_create_info, meta.allocator, &present_image_views[i] ).vkEnforce;
	}
	return present_image_views;
}


// Todo(pp): this function is only a stub and must be merged with the one above.
// issue with the approach bellow: the two overloads above and bellow must return the same type
// ... as overloads based on return type only are not allowed
// hence both must return some kind of dynamic array which is optionally able to use scratch memory
// moreover, to not over complicate the argument amount the option to use scratch space
// should be set globally and recorded in the vulkan state struct
// see requirements and recipe on array in util.array module 
auto swapchainImageViews( ref Meta_Surface meta, VkImageViewCreateInfo image_view_create_info, void* scratch = null, uint32_t* size_used = null ) {
	// assert that meta struct is initialized with a valid vulkan state pointer
	assert( meta.isValid );

	// Create image views of the swapchain images in the passed in argument present_image_views
	auto present_images = listVulkanProperty!( VkImage, vkGetSwapchainImagesKHR, VkDevice, VkSwapchainKHR )( scratch, meta.device, meta.swapchain );

	// offset scratch pointer and use the remaining memory to store the image views
	scratch += present_images.sizeof;
	auto present_image_views = ( cast( VkImageView* )scratch )[ 0 .. present_images.length ];
	foreach( i; 0 .. present_image_views.length ) {
		image_view_create_info.image = present_images[i];	// complete VkImageViewCreateInfo with image i:
		vkCreateImageView( meta.device, &image_view_create_info, meta.allocator, &present_image_views[i] ).vkEnforce;
	}

	if( size_used )
		*size_used = present_images.sizeof + present_image_views.sizeof;

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
