module vdrive.swapchain;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;

import std.stdio;



////////////////////////////
// utility info functions //
////////////////////////////



/// Result type to list surface formats using Vulkan_State scratch memory
alias List_Surface_Formats_Result = Scratch_Result!VkSurfaceFormatKHR;



/// list surface formats, using scratch memory
auto ref listSurfaceFormats( Result_T )(
    ref Result_T    result,
    VkSurfaceKHR    surface,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = result.vk.gpu;
    else                                    auto gpu = result.query;

    // Enumerate surface formats
    listVulkanProperty!( Result_T.Array_T, vkGetPhysicalDeviceSurfaceFormatsKHR, VkPhysicalDevice, VkSurfaceKHR )( result.array, file, line, func, gpu, surface );

    if( result.length == 0 ) {
        printf( "No Surface Formats available for the passed in physical device!\n" );
    } else if( print_info ) {
        foreach( surface_format; result )
            surface_format.printTypeInfo;
        println;
    }
    return result.array;
}



/// list surface formats, alocates heap memory
auto listSurfaceFormats(
    VkPhysicalDevice    gpu,
    VkSurfaceKHR        surface,
    bool                print_info = true,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) {

    auto result = Dynamic_Result!( VkSurfaceFormatKHR, VkPhysicalDevice )( gpu );
    listSurfaceFormats!( typeof( result ))( result, surface, print_info, file, line, func );
    return result.array.release;
}



/// filter surface formats
alias filter = filterSurfaceFormats;
auto filterSurfaceFormats( Array_T )(
    ref Array_T surface_formats,
    VkFormat[]  include_formats,
    bool        first_available_as_fallback = true

    ) if( isDataArray!( Array_T, VkSurfaceFormatKHR ) || is( Array_T : VkSurfaceFormatKHR[] )) {

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



/// Result type to list presentation modes using Vulkan_State scratch memory
alias List_Present_Modes_Result = Scratch_Result!VkPresentModeKHR;



/// list presentation modes, using scratch memory
auto ref listPresentModes( Result_T )(
    ref Result_T    present_modes,
    VkSurfaceKHR    surface,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = present_modes.vk.gpu;
    else                                    auto gpu = present_modes.query;

    listVulkanProperty!( Result_T.Array_T, vkGetPhysicalDeviceSurfacePresentModesKHR, VkPhysicalDevice, VkSurfaceKHR )( present_modes.array, file, line, func, gpu, surface );
    //auto present_modes = listVulkanProperty!(
    //    max_modes, VkPresentModeKHR, vkGetPhysicalDeviceSurfacePresentModesKHR, VkPhysicalDevice, VkSurfaceKHR )( file, line, func, gpu, surface );

    if( print_info ) {
        if( present_modes.length == 0 )  {
            printf( "Present Modes: None\n" );
        } else {
            // if we have passed Vulkan_State instead of just the VkPhysicalDevice, we can use the scratch array to sub-allocate string z conversion
            static if( isScratchResult!Result_T )   auto present_mode_z = Block_Array!char( present_modes.vk.scratch );
            else                                    auto present_mode_z = Dynamic_Array!char();         // allocates
            printf( "VkPresentModeKHR\n=================\n" );
            foreach( present_mode; present_modes ) {
                present_mode.toStringz( present_mode_z );
                printf( "\tPresent Mode: %s\n", present_mode_z.ptr );

            }
        }
        writeln;
    }
    return present_modes.array;
}



/// list presentation modes, allocates heap memory
auto listPresentModes(
    VkPhysicalDevice    gpu,
    VkSurfaceKHR        surface,
    bool                print_info = true,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) {

    auto present_modes = Dynamic_Result!( VkPresentModeKHR, VkPhysicalDevice )( gpu );
    listPresentModes!( typeof( present_modes ))( present_modes, surface, print_info, file, line, func );
    return present_modes.array.release;
}



/// filter presentation modes
alias filter = filterPresentModes;
auto  filterPresentModes( Array_T )(
    ref Array_T present_modes,
    VkPresentModeKHR[] include_modes,
    bool first_available_as_fallback = true

    ) if( isDataArray!( Array_T, VkPresentModeKHR ) || is( Array_T : VkPresentModeKHR[] )) {

    // if first_available_as_fallback is false and no present mode can be filtered this returns an non existing present mode
    auto result_mode = first_available_as_fallback && present_modes.length > 0 ? present_modes[0] : VK_PRESENT_MODE_MAX_ENUM_KHR;

    // few are available, search for the first match
    foreach( include_mode; include_modes )
        foreach( present_mode; present_modes )
            if( present_mode == include_mode )
                return include_mode;

    return result_mode;
}



/// get swapchain images using a VkDevice and its VkSwapchainKHR
alias getSwapchainImages = getSwapchainImages_t!( int32_t.max );
auto  getSwapchainImages_t( int32_t max_image_count )(
    VkDevice        device,
    VkSwapchainKHR  swapchain,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) {
    return listVulkanProperty!( max_image_count, VkImage, vkGetSwapchainImagesKHR, VkDevice, VkSwapchainKHR )( file, line, func, device, swapchain );
}



/// get swapchain image view using a VkDevice and its VkSwapchainKHR
alias getSwapchainImageViews = getSwapchainImageViews_t!( int32_t.max );
auto  getSwapchainImageViews_t( int32_t max_image_count )(
    ref Vulkan              vk,
    VkSwapchainKHR          swapchain,
    VkImageViewCreateInfo   image_view_ci,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) {
    // get swapchain images
    auto swapchain_images = getSwapchainImages_t!max_image_count( vk.device, swapchain, file, line, func );

    // allocate storage for image views and create one view per swapchain image in a loop
    D_OR_S_ARRAY!( max_image_count, VkImageView ) swapchain_image_views;
    swapchain_image_views.length = swapchain_images.length;
    foreach( i; 0 .. swapchain_images.length ) {
        image_view_ci.image = swapchain_images[i];   // complete VkImageViewCreateInfo with image i:
        vkCreateImageView( vk.device, & image_view_ci, vk.allocator, & swapchain_image_views[i] ).vkAssert( "Create Image View", file, line, func );
    }
    return swapchain_image_views;
}



/// struct to capture buffer and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct
struct Meta_Swapchain_T( int32_t max_image_count ) {
    mixin                                           Vulkan_State_Pointer;
    VkQueue                                         present_queue = VK_NULL_HANDLE;
    VkSwapchainKHR                                  swapchain;
    VkSwapchainCreateInfoKHR                        swapchain_ci;
    D_OR_S_ARRAY!( max_image_count, VkImageView )   swapchain_image_views;
    alias present_image_views = swapchain_image_views;  // Todo(pp): rename to all project wide occurrences present_image_views to swapchain_image_views

    // convenience function to get the refernce or pointer to the VkSurface of swapchain_ci
    auto surface_ptr()      { return & swapchain_ci.surface; }

    // convenience to get the swapchain image count
    auto imageCount()       { return swapchain_image_views.length.toUint; }

    // convenience to get VkSurfaceFormatKHR from VkSwapchainCreateInfoKHR.imageFormat and .imageColorSpace and set vice versa
    auto surfaceFormat()    { return VkSurfaceFormatKHR( swapchain_ci.imageFormat, swapchain_ci.imageColorSpace ); }
    void surfaceFormat( VkSurfaceFormatKHR surface_format ) {
        swapchain_ci.imageFormat = surface_format.format;
        swapchain_ci.imageColorSpace = surface_format.colorSpace;
    }

    // two different resource destroy functions for two distinct places
    void destroySurface() { vk.destroy( swapchain_ci.surface ); }
    void destroySwapchain() { vk.destroy( swapchain ); }
    void destroyImageViews() {
        foreach( ref image_view; swapchain_image_views ) {
            vk.destroy( image_view );
        }
    }

    // try to destroy together
    void destroyResources() {
        destroySwapchain;
        destroySurface;
        destroyImageViews;
    }


    auto ref selectSurfaceFormat( VkFormat[] include_formats, bool first_available_as_fallback = true ) {
        // store available surface formats temporarily in an util.array : Static_Array with max length of count of all VkFormat and filter with the requested include_formats
        auto surface_formats = List_Surface_Formats_Result( vk );
        surfaceFormat = listSurfaceFormats( surface_formats, surface, false ).filter( include_formats );
        return this;
    }


    auto ref selectPresentMode( VkPresentModeKHR[] include_modes, bool first_available_as_fallback = true ) {
        // store available present modes temporarily in an util.array : Static_Array with max length of count of all VkPresentModeKHR and filter with the requested include_modes
        auto prsent_modes = List_Present_Modes_Result( vk );
        presentMode = listPresentModes( prsent_modes, surface, false ).filter( include_modes );
        return this;
    }


    // forward members of Meta_Swapchain.swapchain_ci to setter and getter functions
    mixin( Forward_To_Inner_Struct!( VkSwapchainCreateInfoKHR, "swapchain_ci" ));



    auto ref createSwapchain( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );

        // request different count of images dependent on selected present mode
        if( minImageCount == 0 ) {
            switch( presentMode ) {
                case VK_PRESENT_MODE_MAILBOX_KHR        : minImageCount = 3; break;
                case VK_PRESENT_MODE_FIFO_KHR           :
                case VK_PRESENT_MODE_FIFO_RELAXED_KHR   : minImageCount = 2; break;
                default                                 : minImageCount = 1; break;        // VK_PRESENT_MODE_IMMEDIATE_KHR
            }
        }

        // Get GPU surface capabilities
        VkSurfaceCapabilitiesKHR surface_capabilities;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR( gpu, surface, & surface_capabilities );

              if( minImageCount < surface_capabilities.minImageCount )  minImageCount = surface_capabilities.minImageCount;
        else  if( minImageCount > surface_capabilities.maxImageCount )  minImageCount = surface_capabilities.maxImageCount;
        vkAssert( minImageCount > 0, "No image in the swapchain", file, line, func );

        //printf( "\nImage Count: %u\n", image_count );

        // Determine surface resolution
        if( surface_capabilities.currentExtent.width == uint32_t.max ) {
                  if( imageExtent.width  < surface_capabilities.minImageExtent.width  )  imageExtent.width  = surface_capabilities.minImageExtent.width;
            else  if( imageExtent.width  > surface_capabilities.maxImageExtent.width  )  imageExtent.width  = surface_capabilities.maxImageExtent.width;
                  if( imageExtent.height < surface_capabilities.minImageExtent.height )  imageExtent.height = surface_capabilities.minImageExtent.height;
            else  if( imageExtent.height > surface_capabilities.maxImageExtent.height )  imageExtent.height = surface_capabilities.maxImageExtent.height;
        } else {
            imageExtent = surface_capabilities.currentExtent;
        }

        // Try to use identity transform, otherwise the surface_capabilities.currentTransform
        if( surface_capabilities.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR ) {
            preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
        } else {
            preTransform = surface_capabilities.currentTransform;
        }

        swapchain_ci.oldSwapchain = swapchain;         // store this in case we are recreating the swapchain
        vkCreateSwapchainKHR( vk.device, & swapchain_ci, allocator, & swapchain ).vkAssert( "Create Swapchain", file, line, func );
        if( swapchain_ci.oldSwapchain )                // if the old swapchain was valid
            vk.destroy( swapchain_ci.oldSwapchain );   // destroy it now

        return this;
    }


    auto swapchainImages( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return listVulkanProperty!( max_image_count, VkImage, vkGetSwapchainImagesKHR, VkDevice, VkSwapchainKHR )
            ( file, line, func, vk.device, swapchain );
    }


    auto ref createImageViews(
        VkImageAspectFlags  subrecource_aspect_mask = VK_IMAGE_ASPECT_COLOR_BIT,
        VkImageViewType     image_view_type = VK_IMAGE_VIEW_TYPE_2D,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__
        ) {
        VkImageSubresourceRange image_subresource_range = {
            aspectMask      : VK_IMAGE_ASPECT_COLOR_BIT,
            baseMipLevel    : 0,
            levelCount      : 1,
            baseArrayLayer  : 0,
            layerCount      : 1,
        };

        createImageViews( image_subresource_range, image_view_type, file, line, func );
        return this;
    }


    auto ref createImageViews(
        VkImageSubresourceRange image_subresource_range,
        VkImageViewType         image_view_type = VK_IMAGE_VIEW_TYPE_2D,
        string                  file = __FILE__,
        size_t                  line = __LINE__,
        string                  func = __FUNCTION__
        ) {
        VkImageViewCreateInfo image_view_ci = {
            viewType            : image_view_type,
            format              : imageFormat,
            components          : { VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY },
            subresourceRange    : image_subresource_range,
        };

        createImageViews( image_view_ci, file, line, func );
        return this;
    }


    auto ref createImageViews(
        VkImageViewCreateInfo   image_view_ci,
        string                  file = __FILE__,
        size_t                  line = __LINE__,
        string                  func = __FUNCTION__
        ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );

        // destroy old image views if they exist
        foreach( ref image_view; swapchain_image_views ) vk.destroy( image_view );

        // get swapchain images
        auto swapchain_images = swapchainImages( file, line, func );

        // allocate storage for image views and create one view per swapchain image in a loop
        swapchain_image_views.length = swapchain_images.length;
        foreach( i; 0 .. swapchain_images.length ) {
            image_view_ci.image = swapchain_images[i];   // complete VkImageViewCreateInfo with image i:
            vkCreateImageView( vk.device, & image_view_ci, allocator, & swapchain_image_views[i] ).vkAssert( "Create Image View", file, line, func );
        }

        // Todo(pp): debug this, not working variant (access violation)
        //swapchain_image_views = vk.getSwapchainImageViews_t!max_image_count( swapchain, image_view_ci );

        return this;
    }


    /// construct swapchain and image views from internal data
    auto ref construct( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        createSwapchain( file, line, func );
        createImageViews( VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_VIEW_TYPE_2D, file, line, func );    // must pass same default values to reach file, line, func
        return this;
    }


    /// get minimal config for internal D_OR_S_ARRAY
    auto static_config() {
        size_t[1] result;   // return static array even if we have only one value to maintain conssitency
        result[0] = swapchain_image_views.length;
        return result;
    }
}


// Meta_Swapchain is an alias for Meta_Swapchain_T with a dynamic array as data backing
alias Meta_Swapchain = Meta_Swapchain_T!( int32_t.max );


/*
// Todo(pp): this function is only a stub and must be merged with the one above.
// issue with the approach bellow: the two overloads above and bellow must return the same type
// ... as overloads based on return type only are not allowed
// hence both must return some kind of dynamic array which is optionally able to use scratch memory
// moreover, to not over complicate the argument amount the option to use scratch space
// should be set globally and recorded in the vulkan state struct
// see requirements and recipe on array in util.array module
auto createImageViews( ref Meta_Swapchain meta, VkImageViewCreateInfo image_view_ci, void* scratch = null, uint32_t* size_used = null ) {
    // assert that meta struct is initialized with a valid vulkan state pointer
    vkAssert( meta.isValid, "Vulkan state not assigned" );

    // Create image views of the swapchain images in the passed in argument swapchain_image_views
    auto swapchain_images = listVulkanProperty!( VkImage, vkGetSwapchainImagesKHR, VkDevice, VkSwapchainKHR )( scratch, meta.device, meta.swapchain );

    // offset scratch pointer and use the remaining memory to store the image views
    scratch += swapchain_images.sizeof;
    auto swapchain_image_views = ( cast( VkImageView* )scratch )[ 0 .. swapchain_images.length ];
    foreach( i; 0 .. swapchain_image_views.length ) {
        image_view_ci.image = swapchain_images[i];   // complete VkImageViewCreateInfo with image i:
        vkCreateImageView( meta.device, & image_view_ci, meta.allocator, & swapchain_image_views[i] ).vkAssert;
    }

    if( size_used )
        *size_used = swapchain_images.sizeof + swapchain_image_views.sizeof;

    return swapchain_image_views;
}
*/
