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
alias Surface_Formats_Result = Scratch_Result!VkSurfaceFormatKHR;



/// list surface formats, using scratch memory
auto ref listSurfaceFormats( Result_T )(
    ref Result_T    result,
    VkSurfaceKHR    surface,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isScratchResult!Result_T || isDynamicOrStaticResult!Result_T ) {

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
    auto result_format = first_available_as_fallback && surface_formats.length > 0
        ? surface_formats[0] : VkSurfaceFormatKHR( VK_FORMAT_MAX_ENUM, VK_COLORSPACE_SRGB_NONLINEAR_KHR );

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

    // if this function returns surfac_format.format == VK_FORMAT_MAX_ENUM this means that no requested format could be found
    return result_format;
}



/// Select surface format from passed in prefered formats, optionally select the first available if prefered cannot be found.
VkSurfaceFormatKHR selectSurfaceFormat( ref Vulkan vk, VkSurfaceKHR surface, VkFormat[] include_formats, bool first_available_as_fallback = true ) {
    auto surface_formats = Surface_Formats_Result( vk );
    return listSurfaceFormats( surface_formats, surface, false ).filterSurfaceFormats( include_formats, first_available_as_fallback );
}



/// Query whether a specific surface format is available
bool hasSurfaceFormat( ref Vulkan vk, VkSurfaceKHR surface, VkFormat surface_format ) {
    return selectSurfaceFormat( vk, surface, ( & surface_format )[ 0 .. 1 ], false ) != VkSurfaceFormatKHR( VK_FORMAT_MAX_ENUM, VK_COLORSPACE_SRGB_NONLINEAR_KHR );
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

    ) if( isScratchResult!Result_T || isDynamicOrStaticResult!Result_T ) {

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

    // Static_Result count should not be set to VK_PRESENT_MODE_RANGE_SIZE_KHR, as that count leaves out extension entries.
    // It is more future proof to get the count of entries and subtract the four meta entries at the end of the enum
    // using: __traits( allMembers, VkPresentModeKHR ).length - 4
    auto present_modes = Static_Result!( VkPresentModeKHR, VkPhysicalDevice, __traits( allMembers, VkPresentModeKHR ).length - 4 )( gpu );
    listPresentModes!( typeof( present_modes ))( present_modes, surface, print_info, file, line, func );
    return present_modes.array.release;
}



/// filter presentation modes
alias filter = filterPresentModes;
auto  filterPresentModes( Array_T )(
    ref Array_T         present_modes,
    VkPresentModeKHR[]  include_modes,
    bool first_available_as_fallback = true

    ) if( isDataArray!( Array_T, VkPresentModeKHR ) || is( Array_T : VkPresentModeKHR[] )) {

    // few are available, search for the first match
    foreach( include_mode; include_modes )
        foreach( present_mode; present_modes )
            if( present_mode == include_mode )
                return include_mode;

    // if first_available_as_fallback is false and no present mode can be filtered this returns an non existing present mode
    return first_available_as_fallback && present_modes.length > 0 ? present_modes[0] : VK_PRESENT_MODE_MAX_ENUM_KHR;
}



/// Select presentation mode from passed in prefered modes, optionally select the first available if prefered cannot be found.
auto ref selectPresentMode( ref Vulkan vk, VkSurfaceKHR surface, VkPresentModeKHR[] include_modes, bool first_available_as_fallback = true ) {
    auto present_modes = List_Present_Modes_Result( vk );
    return listPresentModes( present_modes, surface, false ).filter( include_modes, first_available_as_fallback );
}


/// Query whether a specific present mode is available
bool hasPresentMode( ref Vulkan vk, VkSurfaceKHR surface, VkPresentModeKHR present_mode ) {
    return selectPresentMode( vk, surface, ( & present_mode )[ 0 .. 1 ], false ) != VK_PRESENT_MODE_MAX_ENUM_KHR;
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
    D_OR_S_ARRAY!( VkImageView, max_image_count ) image_views;
    image_views.length = swapchain_images.length;
    foreach( i; 0 .. swapchain_images.length ) {
        image_view_ci.image = swapchain_images[i];   // complete VkImageViewCreateInfo with image i:
        vkCreateImageView( vk.device, & image_view_ci, vk.allocator, & image_views[i] ).vkAssert( "Create Image View", file, line, func );
    }
    return image_views;
}



alias SMC = Swapchain_Member_Copy;
enum Swapchain_Member_Copy : uint32_t {
    None        = 0,
    Queue       = 1,
    Extent      = 2,
    Format      = 4,
    PresentMode = 8,
};


alias   Core_Swapchain                              = Core_Swapchain_T!(  4, SMC.None   );
alias   Core_Swapchain_Queue                        = Core_Swapchain_T!(  4, SMC.Queue  );
alias   Core_Swapchain_Extent                       = Core_Swapchain_T!(  4, SMC.Extent );
alias   Core_Swapchain_Queue_Extent                 = Core_Swapchain_T!(  4, SMC.Queue  | SMC.Extent );
alias   Core_Swapchain_T( uint ic )                 = Core_Swapchain_T!( ic, SMC.None   );
alias   Core_Swapchain_Queue_T( uint ic )           = Core_Swapchain_T!( ic, SMC.Queue  );
alias   Core_Swapchain_Extent_T( uint ic )          = Core_Swapchain_T!( ic, SMC.Extent );
alias   Core_Swapchain_Queue_Extent_T( uint ic )    = Core_Swapchain_T!( ic, SMC.Queue  | SMC.Extent );

/// Wraps the essential Vulkan objects created with the editing procedure
/// of Meta_Image_T, all other internal structures are obsolete
/// after construction so that the Meta_Image_Sampler_T can be reused
/// after being reset.
struct Core_Swapchain_T( int32_t max_image_count, uint32_t member_copies = SMC.None ) if( max_image_count > 0 ) {
    alias ic = max_image_count;
    alias mc = member_copies;

    VkSurfaceKHR    surface;
    VkSwapchainKHR  swapchain;
    D_OR_S_ARRAY!(  VkImageView, max_image_count )          image_views;
    static if( mc & SMC.Queue  )        VkQueue             present_queue;
    static if( mc & SMC.Extent )        VkExtent2D          image_extent;
    static if( mc & SMC.Format )        VkFormat            image_format;
    static if( mc & SMC.PresentMode )   VkPresentModeKHR    present_mode;

    auto image_count()                  { return image_views.length.toUint; }

    bool is_null()                      { return swapchain.is_null_handle; }
}


/// Bulk destroy the resources belonging to this meta struct.
void destroy( CORE )( ref Vulkan vk, ref CORE core, bool destroy_surface = true, bool destroy_swapchain = true, bool destroy_image_view = true ) if( isCoreSwapchain!CORE ) {

    if( destroy_image_view ) {
             static if( core.ic == 1 )  { if( !core.image_view.is_null_handle ) vk.destroyHandle( core.image_view ); }
        else static if( core.ic  > 1 )  { foreach( ref v; core.image_views )  if( !v.is_null_handle ) vk.destroyHandle( v ); }
    }

    if( destroy_swapchain )
        vk.destroyHandle( core.swapchain );

    if( destroy_surface )
        vk.destroyHandle( core.surface );
}


/// Private template to identify Core_Image_T .
private template isCoreSwapchain( T ) { enum isCoreSwapchain = is( typeof( isCoreSwapchainImpl( T.init ))); }
private void isCoreSwapchainImpl( int32_t max_view_count, uint32_t member_copies )( Core_Swapchain_T!( max_view_count, member_copies ) cs ) {}




alias Meta_Swapchain = Meta_Swapchain_T!( int32_t.max );
alias Meta_Swapchain_T( T ) = Meta_Swapchain_T!( T.ic, T.mc );

/// struct to capture buffer and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct
struct Meta_Swapchain_T( int32_t max_image_count, uint member_copies = SMC.None )  if( max_image_count > 0 ) {
    alias ic = max_image_count;
    alias mc = member_copies;

    mixin                                           Vulkan_State_Pointer;
    VkQueue                                         present_queue = VK_NULL_HANDLE;
    VkSwapchainKHR                                  swapchain;
    VkSwapchainCreateInfoKHR                        swapchain_ci;
    D_OR_S_ARRAY!( VkImageView, max_image_count )   image_views;

    // convenience function to get the refernce or pointer to the VkSurface of swapchain_ci
    auto surface_ptr()      { return & swapchain_ci.surface; }

    // convenience to get the swapchain image count
    auto image_count()      { return image_views.length.toUint; }

    // convenience to get VkSurfaceFormatKHR from VkSwapchainCreateInfoKHR.imageFormat and .imageColorSpace and set vice versa
    auto surface_format()   { return VkSurfaceFormatKHR( swapchain_ci.imageFormat, swapchain_ci.imageColorSpace ); }
    void surface_format( VkSurfaceFormatKHR surface_format ) {
        swapchain_ci.imageFormat = surface_format.format;
        swapchain_ci.imageColorSpace = surface_format.colorSpace;
    }

    // two different resource destroy functions for two distinct places
    void destroySurface() { vk.destroyHandle( swapchain_ci.surface ); }
    void destroySwapchain() { vk.destroyHandle( swapchain ); }
    void destroyImageViews() {
        foreach( ref image_view; image_views ) {
            vk.destroyHandle( image_view );
        }
    }

    // try to destroy together
    void destroyResources() {
        destroySwapchain;
        destroySurface;
        destroyImageViews;
    }


    /// reset all internal data and return wrapped Vulkan objects
    /// VkSurface, VkSwapchain, VkImageviews and other optional members
    /// in the passed in ref Core_Swapchain_T.
    auto reset() {
        Core_Swapchain_T!( ic, mc ) out_core;
        reset( out_core );
        return out_core;
    }


    /// reset all internal data and return wrapped Vulkan objects
    /// VkSurface, VkSwapchain, VkImageviews and other optional members
    /// in a new matching Core_Swapchain_T.
    auto ref reset( ref Core_Swapchain_T!( ic, mc ) out_core ) {
                                                    out_core.surface        = resetHandle( swapchain_ci.surface );
                                                    out_core.swapchain      = resetHandle( swapchain );
                                                    out_core.image_views    = image_views.release;
        static if( mc & SMC.Extent  )               out_core.image_extent   = swapchain_ci.imageExtent;
        static if( mc & SMC.Format  )               out_core.image_format   = swapchain_ci.imageFormat;
        static if( mc & SMC.PresentMode )           out_core.present_mode   = swapchain_ci.presentMode;
        static if( mc & SMC.Queue   )           if( out_core.present_queue.is_null_handle && !present_queue.is_null_handle )
                                                    out_core.present_queue  = resetHandle( present_queue );

        return this;
    }


    /// Select surface format from passed in prefered formats, optionally select the first available if prefered cannot be found.
    auto ref selectSurfaceFormat( VkFormat[] include_formats, bool first_available_as_fallback = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );     // assert that meta struct is initialized with a valid vulkan state pointer
        surface_format = vk.selectSurfaceFormat( surface, include_formats, first_available_as_fallback );
        return this;
    }


    /// Select presentation mode from passed in prefered modes, optionally select the first available if prefered cannot be found.
    auto ref selectPresentMode( VkPresentModeKHR[] include_modes, bool first_available_as_fallback = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        presentMode = vk.selectPresentMode( surface, include_modes, first_available_as_fallback );
        return this;
    }


    // forward members of Meta_Swapchain.swapchain_ci to setter and getter functions
    mixin Forward_To_Inner_Struct!( VkSwapchainCreateInfoKHR, "swapchain_ci", "imageSharingMode", "queueFamilyIndexCount", "pQueueFamilyIndices" );


    /// Specify the sharing queue families and implicitly the sharing mode, which defaults to VK_SHARING_MODE_EXCLUSIVE.
    auto ref sharingQueueFamilies( uint32_t[] sharing_queue_family_indices, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( sharing_queue_family_indices.length != 1,
            "Length of sharing_queue_family_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)", file, line, func );
        swapchain_ci.imageSharingMode       = sharing_queue_family_indices.length > 1 ? VK_SHARING_MODE_CONCURRENT : VK_SHARING_MODE_EXCLUSIVE;
        swapchain_ci.queueFamilyIndexCount  = sharing_queue_family_indices.length.toUint;
        swapchain_ci.pQueueFamilyIndices    = sharing_queue_family_indices.ptr;
    }


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
            vk.destroyHandle( swapchain_ci.oldSwapchain );   // destroy it now

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
        foreach( ref image_view; image_views ) vk.destroyHandle( image_view );

        // get swapchain images
        auto swapchain_images = swapchainImages( file, line, func );

        // allocate storage for image views and create one view per swapchain image in a loop
        image_views.length = swapchain_images.length;
        foreach( i; 0 .. swapchain_images.length ) {
            image_view_ci.image = swapchain_images[i];   // complete VkImageViewCreateInfo with image i:
            vkCreateImageView( vk.device, & image_view_ci, allocator, & image_views[i] ).vkAssert( "Create Image View", file, line, func );
        }

        // Todo(pp): debug this, not working variant (access violation)
        //image_views = vk.getSwapchainImageViews_t!max_image_count( swapchain, image_view_ci );

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
        result[0] = image_views.length;
        return result;
    }
}



