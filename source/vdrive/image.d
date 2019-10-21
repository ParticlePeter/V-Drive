module vdrive.image;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.memory;

import erupted;



/////////////////////////////////////////////
// VkImage, VkImageView, VkSampler related //
/////////////////////////////////////////////



/// Create a VkImage of type VK_IMAGE_TYPE_2D (VK_IMAGE_TYPE_1D if height is set to 0)
/// without one mipmap level and one layer.
/// several parameters are deducted (e.g. image type) from other parameters,
/// or combined into one (e.g. sharingMode, queueFamilyIndexCount, pQueueFamilyIndices
/// as uint32_t[] sharing_queue_family_indices). Parameters are arranged in importance
/// while les important parameters have most used defaults.
/// Params:
///     vk      = reference to a VulkanState struct
///     format  = format of the image
///     width   = width of the image
///     height  = height of the image (if set to 0, a VK_IMAGE_TYPE_1D will be created)
///     usage   = the usage of the image
///     samples = optional sample count, default is VK_SAMPLE_COUNT_1_BIT
///     tiling  = optional image tiling, default is VK_IMAGE_TILING_OPTIMAL
///     initial_layout = optional image layout, default is VK_IMAGE_LAYOUT_UNDEFINED
///     sharing_queue_family_indices = optional, default is [], length must not be 1,
///         if length > 1 sharingMode is set to VK_SHARING_MODE_CONCURRENT,
///         specifies queueFamilyIndexCount (length) and assigns the pQueueFamilyIndices pointer
///     flags   = optional create flags of the image
/// Returns: VkImage
VkImage createImage(
    ref Vulkan              vk,
    VkFormat                format,
    uint32_t                width,
    uint32_t                height,
    VkImageUsageFlags       usage,
    VkSampleCountFlagBits   samples = VK_SAMPLE_COUNT_1_BIT,
    VkImageTiling           tiling  = VK_IMAGE_TILING_OPTIMAL,
    VkImageLayout           initial_layout = VK_IMAGE_LAYOUT_UNDEFINED,
    uint32_t[]              sharing_queue_family_indices = [],
    VkImageCreateFlags      flags   = 0,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__

    ) {

    return vk.createImage(
        format, width, height, 0, 1, 1, usage, samples,
        tiling, initial_layout, sharing_queue_family_indices, flags,
        file, line, func );
}


/// Create a VkImage of type VK_IMAGE_TYPE_3D / _2D if depth is set to 0 / _1D if height to 0
/// several parameters are deducted (e.g. imageType) from other parameters,
/// or combined into one (e.g. sharingMode, queueFamilyIndexCount, pQueueFamilyIndices
/// as uint32_t[] sharing_queue_family_indices). Parameters are arranged in importance
/// while les important parameters have most used defaults.
/// Params:
///     vk          = reference to a VulkanState struct
///     format      = format of the image
///     width       = width of the image
///     height      = height of the image (if set to 0, a VK_IMAGE_TYPE_1D will be created)
///     depth       = depth  of the image (if set to 0, a VK_IMAGE_TYPE_2D will be created)
///     mip_levels  = mipmap levels of the image
///     array_layers= array layers of the image
///     usage       = the usage of the image
///     samples     = optional sample count, default is VK_SAMPLE_COUNT_1_BIT
///     tiling      = optional image tiling, default is VK_IMAGE_TILING_OPTIMAL
///     initial_layout = optional image layout, default is VK_IMAGE_LAYOUT_UNDEFINED
///     sharing_queue_family_indices = optional, default is [], length must not be 1,
///         if length > 1 sharingMode is set to VK_SHARING_MODE_CONCURRENT,
///         specifies queueFamilyIndexCount (length) and assigns the pQueueFamilyIndices pointer
///     flags       = optional create flags of the image
/// Returns: VkImage
VkImage createImage(
    ref Vulkan              vk,
    VkFormat                format,
    uint32_t                width,
    uint32_t                height,
    uint32_t                depth,
    uint32_t                mip_levels,
    uint32_t                array_layers,
    VkImageUsageFlags       usage,
    VkSampleCountFlagBits   samples = VK_SAMPLE_COUNT_1_BIT,
    VkImageTiling           tiling  = VK_IMAGE_TILING_OPTIMAL,
    VkImageLayout           initial_layout = VK_IMAGE_LAYOUT_UNDEFINED,
    uint32_t[]              sharing_queue_family_indices = [],
    VkImageCreateFlags      flags   = 0,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__

    ) {

    vkAssert( sharing_queue_family_indices.length != 1,
        "Length of sharing_queue_family_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)",
        file, line, func );

    VkImageCreateInfo image_ci = {
        flags                   : flags,
        imageType               : height == 0 ? VK_IMAGE_TYPE_1D : depth == 0 ? VK_IMAGE_TYPE_2D : VK_IMAGE_TYPE_3D,
        format                  : format,
        extent                  : { width, height == 0 ? 1 : height, depth == 0 ? 1 : depth },
        mipLevels               : mip_levels,
        arrayLayers             : array_layers,
        samples                 : samples,
        tiling                  : tiling,
        usage                   : usage,
        initialLayout           : initial_layout,
    };

    if( sharing_queue_family_indices.length > 1 ) {
        image_ci.sharingMode           = VK_SHARING_MODE_CONCURRENT;
        image_ci.queueFamilyIndexCount = sharing_queue_family_indices.length.toUint;
        image_ci.pQueueFamilyIndices   = sharing_queue_family_indices.ptr;
    }

    VkImage image;
    vk.device.vkCreateImage( & image_ci, vk.allocator, & image ).vkAssert( "Create Image", file, line, func );
    return image;
}


/// Create a VkImage, prioritizing image create flags, of type VK_IMAGE_TYPE_3D /
/// _2D if depth is set to 0 / _1D if height to 0.
/// several parameters are deducted (e.g. imageType) from other parameters,
/// or combined into one (e.g. sharingMode, queueFamilyIndexCount, pQueueFamilyIndices
/// as uint32_t[] sharing_queue_family_indices). Parameters are arranged in importance
/// while les important parameters have most used defaults.
/// Params:
///     vk          = reference to a VulkanState struct
///     flags       = create flags of the image
///     format      = format of the image
///     width       = width of the image
///     height      = height of the image (if set to 0, a VK_IMAGE_TYPE_1D will be created)
///     depth       = depth  of the image (if set to 0, a VK_IMAGE_TYPE_2D will be created)
///     mip_levels  = mipmap levels of the image
///     array_layers= array layers of the image
///     usage       = the usage of the image
///     samples     = optional sample count, default is VK_SAMPLE_COUNT_1_BIT
///     tiling      = optional image tiling, default is VK_IMAGE_TILING_OPTIMAL
///     initial_layout = optional image layout, default is VK_IMAGE_LAYOUT_UNDEFINED
///     sharing_queue_family_indices = optional, default is [], length must not be 1,
///         if length > 1 sharingMode is set to VK_SHARING_MODE_CONCURRENT,
///         specifies queueFamilyIndexCount (length) and assigns the pQueueFamilyIndices pointer
/// Returns: VkImage
VkImage createImage(
    ref Vulkan              vk,
    VkImageCreateFlags      flags,
    VkFormat                format,
    uint32_t                width,
    uint32_t                height,
    uint32_t                depth,
    uint32_t                mip_levels,
    uint32_t                array_layers,
    VkImageUsageFlags       usage,
    VkSampleCountFlagBits   samples = VK_SAMPLE_COUNT_1_BIT,
    VkImageTiling           tiling  = VK_IMAGE_TILING_OPTIMAL,
    VkImageLayout           initial_layout = VK_IMAGE_LAYOUT_UNDEFINED,
    uint32_t[]              sharing_queue_family_indices = [],
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    return vk.createImage(
        format, width, height, depth, mip_levels, array_layers, usage, samples,
        tiling, initial_layout, sharing_queue_family_indices, flags,
        file, line, func );
}



/// Create a VkImageView using expanded parameters of sub-structs
/// Params:
///     vk              = reference to a VulkanState struct, other params same as VkImageViewCreateInfo
///     image           = the VkImage base for the resulting VkImageView
///     viewType        = the view type of the image view ( VK_IMAGE_VIEW_TYPE_1D / 2D / 3D / CUBE / ...)
///     format          = format of the image view
///     aspectMask      = optional aspect mask, default is VK_IMAGE_ASPECT_COLOR_BIT
///     baseMipLevel    = optional base mipmap level, default is 0
///     levelCount      = optional mipmap level count, default is 1
///     baseArrayLayer  = optional base array layer, default is 0
///     layerCount      = optional layer count, default is 1
///     flags           = optional create flags of the image view
///     r               = optional component swizzle r, default is VK_COMPONENT_SWIZZLE_IDENTITY
///     g               = optional component swizzle g, default is VK_COMPONENT_SWIZZLE_IDENTITY
///     b               = optional component swizzle b, default is VK_COMPONENT_SWIZZLE_IDENTITY
///     a               = optional component swizzle a, default is VK_COMPONENT_SWIZZLE_IDENTITY
/// Returns: VkImageView
VkImageView createImageView(
    ref Vulkan              vk,
    ref VkImage             image,
    VkImageViewType         viewType,
    VkFormat                format,
    VkImageAspectFlags      aspectMask          = VK_IMAGE_ASPECT_COLOR_BIT,
    uint32_t                baseMipLevel        = 0,
    uint32_t                levelCount          = 1,
    uint32_t                baseArrayLayer      = 0,
    uint32_t                layerCount          = 1,
    VkImageViewCreateFlags  flags               = 0,
    VkComponentSwizzle      r                   = VK_COMPONENT_SWIZZLE_IDENTITY,
    VkComponentSwizzle      g                   = VK_COMPONENT_SWIZZLE_IDENTITY,
    VkComponentSwizzle      b                   = VK_COMPONENT_SWIZZLE_IDENTITY,
    VkComponentSwizzle      a                   = VK_COMPONENT_SWIZZLE_IDENTITY,
    string                  file                = __FILE__,
    size_t                  line                = __LINE__,
    string                  func                = __FUNCTION__

    ) {

    return vk.createImageView( image, flags, viewType, format,
        VkImageSubresourceRange( aspectMask, baseMipLevel, levelCount, baseArrayLayer, layerCount ),
        VkComponentMapping( r, g, b, a ), file, line, func );
}


/// Create a VkImageView, prioritizing image view create flags, requiring sub-structs as parameters.
/// Params:
///     vk              = reference to a VulkanState struct, other params same as VkImageViewCreateInfo
///     image           = the VkImage base for the resulting VkImageView
///     flags           = create flags of the image view
///     viewType        = the view type of the image view ( VK_IMAGE_VIEW_TYPE_1D / 2D / 3D / CUBE / ...)
///     format          = format of the image view
///     subresourceRange= subresource range of the image view, default is VkImageSubresourceRange( VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 )
///     flags           = optional flags
///     components      = the component mapping of the image view, dafault is all VK_COMPONENT_SWIZZLE_IDENTITY
/// Returns: VkImageView
VkImageView createImageView(
    ref Vulkan              vk,
    ref VkImage             image,
    VkImageViewCreateFlags  flags,
    VkImageViewType         viewType,
    VkFormat                format,
    VkImageSubresourceRange subresourceRange    = VkImageSubresourceRange( VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 ),
    VkComponentMapping      components          = VkComponentMapping( VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY ),
    string                  file                = __FILE__,
    size_t                  line                = __LINE__,
    string                  func                = __FUNCTION__

    ) {

    VkImageViewCreateInfo image_view_ci = {
        flags               : flags,
        image               : image,
        viewType            : viewType,
        format              : format,
        components          : components,
        subresourceRange    : subresourceRange,
    };

    VkImageView image_view;
    vk.device.vkCreateImageView( & image_view_ci, vk.allocator, & image_view ).vkAssert( "Create image view", file, line, func );
    return image_view;
}



/// Create a VkSampler, parameters are sorted by importance, are all optional and have usefull defaults.
/// Params:
///     vk                  = reference to a VulkanState struct
///     mag_filter          = the magnification filter of the sampler, default is VK_FILTER_LINEAR
///     min_filter          = the minification  filter of the sampler, default is VK_FILTER_LINEAR
///     mipmap_mode         = the mipmap mode of the sampler, default is VK_SAMPLER_MIPMAP_MODE_NEAREST
///     address_mode_u      = address mode in u direction, default is VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
///     address_mode_v      = address mode in v direction, default is VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
///     address_mode_w      = address mode in w direction, default is VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
///     border_color        = border color of the image, default is VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK
///     mip_lod_bias        = mipmap lod bias setting, default is 0.0f
///     anisotropy_enable   = whether to enable anisotropic filtering, default VK_FALSE
///     max_anisotropy      = max anisotropy setting, default is 1.0f
///     compare_enable      = whether to eanble comparison functionality, default is VK_FALSE
///     compare_op          = the comparison operation, default is VK_COMPARE_OP_NEVER
///     min_lod             = the minimum lod, defualt is 0.0f disabling minimum bound
///     max_lod             = the maximum lod, default is 0.0f disabling maximum bound
///     unnormalized_coordinates = whether to use unnormalized coordinate, default is VK_FALSE
///     flags               = sampler create flags
/// Returns: VkSampler
VkSampler createSampler(
    ref Vulkan              vk,
    VkFilter                mag_filter          = VK_FILTER_LINEAR,
    VkFilter                min_filter          = VK_FILTER_LINEAR,
    VkSamplerMipmapMode     mipmap_mode         = VK_SAMPLER_MIPMAP_MODE_NEAREST,
    VkSamplerAddressMode    address_mode_u      = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    VkSamplerAddressMode    address_mode_v      = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    VkSamplerAddressMode    address_mode_w      = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    VkBorderColor           border_color        = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
    float                   mip_lod_bias        = 0.0f,
    VkBool32                anisotropy_enable   = VK_FALSE,
    float                   max_anisotropy      = 1.0f,
    VkBool32                compare_enable      = VK_FALSE,
    VkCompareOp             compare_op          = VK_COMPARE_OP_NEVER,
    float                   min_lod             = 0.0f,
    float                   max_lod             = 0.0f,
    VkBool32                unnormalized_coordinates = VK_FALSE,
    VkSamplerCreateFlags    flags               = 0,
    string                  file                = __FILE__,
    size_t                  line                = __LINE__,
    string                  func                = __FUNCTION__

    ) {

    VkSamplerCreateInfo sampler_ci = {
        flags                   : flags,
        magFilter               : mag_filter,
        minFilter               : min_filter,
        mipmapMode              : mipmap_mode,
        addressModeU            : address_mode_u,
        addressModeV            : address_mode_v,
        addressModeW            : address_mode_w,
        mipLodBias              : mip_lod_bias,
        anisotropyEnable        : anisotropy_enable,
        maxAnisotropy           : max_anisotropy,
        compareEnable           : compare_enable,
        compareOp               : compare_op,
        minLod                  : min_lod,
        maxLod                  : max_lod,
        borderColor             : border_color,
        unnormalizedCoordinates : unnormalized_coordinates,
    };

    VkSampler sampler;
    vk.device.vkCreateSampler( & sampler_ci, vk.allocator, & sampler ).vkAssert( "Create sampler", file, line, func );
    return sampler;
}


/// Create a VkSampler, prioritizing image view create flags. Parameters are sorted by importance,
/// are all optional except sampler create flags and have usefull defaults.
/// Params:
///     vk                  = reference to a VulkanState struct
///     flags               = sampler create flags
///     mag_filter          = the magnification filter of the sampler, default is VK_FILTER_LINEAR
///     min_filter          = the minification  filter of the sampler, default is VK_FILTER_LINEAR
///     mipmap_mode         = the mipmap mode of the sampler, default is VK_SAMPLER_MIPMAP_MODE_NEAREST
///     address_mode_u      = address mode in u direction, default is VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
///     address_mode_v      = address mode in v direction, default is VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
///     address_mode_w      = address mode in w direction, default is VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
///     border_color        = border color of the image, default is VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK
///     mip_lod_bias        = mipmap lod bias setting, default is 0.0f
///     anisotropy_enable   = whether to enable anisotropic filtering, default VK_FALSE
///     max_anisotropy      = max anisotropy setting, default is 1.0f
///     compare_enable      = whether to eanble comparison functionality, default is VK_FALSE
///     compare_op          = the comparison operation, default is VK_COMPARE_OP_NEVER
///     min_lod             = the minimum lod, defualt is 0.0f disabling minimum bound
///     max_lod             = the maximum lod, default is 0.0f disabling maximum bound
///     unnormalized_coordinates = whether to use unnormalized coordinate, default is VK_FALSE
/// Returns: VkSampler
VkSampler createSampler(
    ref Vulkan              vk,
    VkSamplerCreateFlags    flags,
    VkFilter                mag_filter          = VK_FILTER_LINEAR,
    VkFilter                min_filter          = VK_FILTER_LINEAR,
    VkSamplerMipmapMode     mipmap_mode         = VK_SAMPLER_MIPMAP_MODE_NEAREST,
    VkSamplerAddressMode    address_mode_u      = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    VkSamplerAddressMode    address_mode_v      = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    VkSamplerAddressMode    address_mode_w      = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    VkBorderColor           border_color        = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
    float                   mip_lod_bias        = 0.0f,
    VkBool32                anisotropy_enable   = VK_FALSE,
    float                   max_anisotropy      = 1.0f,
    VkBool32                compare_enable      = VK_FALSE,
    VkCompareOp             compare_op          = VK_COMPARE_OP_NEVER,
    float                   min_lod             = 0.0f,
    float                   max_lod             = 0.0f,
    VkBool32                unnormalized_coordinates = VK_FALSE,
    string                  file                = __FILE__,
    size_t                  line                = __LINE__,
    string                  func                = __FUNCTION__

    ) {

    return vk.createSampler( mag_filter, min_filter, mipmap_mode, address_mode_u, address_mode_v, address_mode_w, border_color, mip_lod_bias,
        anisotropy_enable, max_anisotropy, compare_enable, compare_op, min_lod, max_lod, unnormalized_coordinates, flags, file, line, func );
}


/// Query the physical device image properties of a certain image format, type, tiling, usage and create flags.
/// Params:
///     vk      = reference to a VulkanState struct
///     format  = image format for the query
///     type    = image type for the query
///     tiling  = image tiling  for the query
///     usage   = image usage for the query
///     flags   = optional image create flags for the query
/// return VkImageFormatProperties
VkImageFormatProperties imageFormatProperties(
    ref Vulkan          vk,
    VkFormat            format,
    VkImageType         type,
    VkImageTiling       tiling,
    VkImageUsageFlags   usage,
    VkImageCreateFlags  flags = 0,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) {

    VkImageFormatProperties image_format_properties;
    vk.gpu.vkGetPhysicalDeviceImageFormatProperties(
        format, type, tiling, usage, flags, & image_format_properties ).vkAssert( "Image Format Properties", file, line, func );
    return image_format_properties;
}


// TODO(pp): create functions for VkImageSubresourceRange, VkBufferImageCopy and conversion functions between them




    alias vc = view_count;

    VkImageViewCreateInfo   image_view_ci = {
        viewType            : VK_IMAGE_VIEW_TYPE_MAX_ENUM,
        format              : VK_FORMAT_MAX_ENUM,
        subresourceRange    : {
            aspectMask          : VK_IMAGE_ASPECT_COLOR_BIT,
            levelCount          : 1,
            layerCount          : 1
        }
    };

    static if( vc == 1 ) {

        VkImageView         image_view;


        /// Construct the image from specified data. If format or type was not specified, the corresponding image format and/or type will be used.
        auto ref constructView( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

            // assert validity
            assureValidView( file, line, func );

            // construct the image view
            vkCreateImageView( vk.device, & image_view_ci, vk.allocator, & image_view ).vkAssert( "Construct image view", file, line, func );
            return this;
        }


        /// Destroy the image view
        void destroyImageView() {
            if( image_view != VK_NULL_HANDLE )
                vk.destroyHandle( image_view );
        }


        /// get image view and reset it to VK_NULL_HANDLE such that a new, different view can be created
        auto resetImageView() {
            auto result = image_view;
            image_view  = VK_NULL_HANDLE;
            initImageViewCreateInfo;
            return result;
        }
    }

    else {

        VkImageView[vc]     image_view;


        /// Construct the image from specified data. If format or type was not specified, the corresponding image format and/or type will be used.
        auto ref constructView( uint32_t view_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

            // assert validity
            assureValidView( file, line, func );

            // construct the image view
            vk.device.vkCreateImageView( & image_view_ci, vk.allocator, & image_view[ view_index ] ).vkAssert( "Construct image view", file, line, func );
            return this;
        }


        /// Destroy the image views
        void destroyImageView() {
            foreach( ref view; image_view )
                if( view != VK_NULL_HANDLE )
                    vk.destroyHandle( view );
        } alias destroyImageViews = destroyImageView;


        /// get one image view and reset it to VK_NULL_HANDLE such that a new, different view can be created at that index
        auto resetImageView( uint index ) {
            auto result = image_view[ index ];
            image_view[ index ] = VK_NULL_HANDLE;
            return result;
        }


        /// get all image views and reset them to VK_NULL_HANDLE such that a new, different views can be created
        auto resetImageView() {
            auto result = image_view;
            foreach( ref view; image_view )
                view = VK_NULL_HANDLE;
            initImageViewCreateInfo;
            return result;
        } alias resetImageViews = resetImageView;
    }


    private void assureValidView( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );

        // Check validity only if embedding struct has memory member and is backing an actual image (e.g. Meta_IView_T does not)
        static if( hasMemReqs!( typeof( this ))) {

            // check if memory was bound to the image
            vkAssert( image != VK_NULL_HANDLE, "No image constructed.", file, line, func, "First construct the underlying image before creating an image view for the image." );

            // check if memory was bound to the image
            vkAssert( device_memory != VK_NULL_HANDLE, "No memory bound to image.", file, line, func, "First allocate and bind memory to the underlying image before creating an image view for the image." );

            // assign the valid image to the image_view_ci.image member
            image_view_ci.image = image;

            // check if view type was specified
            if( image_view_ci.viewType == VK_IMAGE_VIEW_TYPE_MAX_ENUM )
                image_view_ci.viewType = cast( VkImageViewType )image_ci.imageType;

            // check if view format was specified
            if( image_view_ci.format == VK_FORMAT_MAX_ENUM )
                image_view_ci.format = image_ci.format;
        }
    }


    /// Initialize image view create info to useful defaults
    void initImageViewCreateInfo() {
        image_view_ci = VkImageViewCreateInfo.init;
        image_view_ci.viewType  = VK_IMAGE_VIEW_TYPE_MAX_ENUM;
        image_view_ci.format    = VK_FORMAT_MAX_ENUM;
        image_view_ci.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        image_view_ci.subresourceRange.levelCount = 1;
        image_view_ci.subresourceRange.layerCount = 1;
    }


    /// Override image view type. If not specified, the image type will be used.
    auto ref viewType( VkImageViewType view_type ) {
        image_view_ci.viewType = view_type;
        return this;
    }


    /// Override image view format. If not specified, the image format will be used.
    auto ref viewFormat( VkFormat view_format ) {
        image_view_ci.format = view_format;
        return this;
    }


    /// Specify image view subresource aspect mask.
    auto ref viewAspect( VkImageAspectFlags subresource_aspect_mask ) {
        image_view_ci.subresourceRange.aspectMask = subresource_aspect_mask;
        return this;
    }


    /// Specify image view subresource base mip level and level count.
    auto ref viewMipLevels( uint32_t base_mip_level, uint32_t mip_level_count ) {
        image_view_ci.subresourceRange.baseMipLevel = base_mip_level;
        image_view_ci.subresourceRange.levelCount   = mip_level_count;
        return this;
    }


    /// Specify image view subresource base array layer and array layer count.
    auto ref viewArrayLayers( uint32_t base_array_layer, uint32_t array_layer_count ) {
        image_view_ci.subresourceRange.baseArrayLayer   = base_array_layer;
        image_view_ci.subresourceRange.layerCount       = array_layer_count;
        return this;
    }


    /// Specify image view subresource range.
    auto ref subresourceRange( VkImageAspectFlags subresource_aspect_mask, uint32_t base_mip_level, uint32_t mip_level_count, uint32_t base_array_layer, uint32_t array_layer_count ) {
        image_view_ci.subresourceRange.aspectMask       = subresource_aspect_mask;
        image_view_ci.subresourceRange.baseMipLevel     = base_mip_level;
        image_view_ci.subresourceRange.levelCount       = mip_level_count;
        image_view_ci.subresourceRange.baseArrayLayer   = base_array_layer;
        image_view_ci.subresourceRange.layerCount       = array_layer_count;
        return this;
    }


    /// Specify image view subresource range.
    auto ref subresourceRange( VkImageSubresourceRange subresource_range ) {
        image_view_ci.subresourceRange = subresource_range;
        return this;
    }


    /// image_view_ci subrescourceRange shortcut
    auto const ref subresourceRange() {
        return image_view_ci.subresourceRange;
    }


    /// Specify component mapping.
    auto ref components( VkComponentSwizzle r, VkComponentSwizzle g, VkComponentSwizzle b, VkComponentSwizzle a ) {
        image_view_ci.components.r = r;
        image_view_ci.components.g = g;
        image_view_ci.components.b = b;
        image_view_ci.components.a = a;
        return this;
    }


    /// Specify component mapping.
    auto ref components( VkComponentMapping component_mapping ) {
        image_view_ci.components = component_mapping;
        return this;
    }
}



// Todo(pp) document
// Create a VkSampler with useful default values
auto createSampler(
    ref Vulkan              vk,
    VkFilter                mag_filter          = VK_FILTER_LINEAR,
    VkFilter                min_filter          = VK_FILTER_LINEAR,
    VkSamplerMipmapMode     mipmap_mode         = VK_SAMPLER_MIPMAP_MODE_NEAREST,
    VkSamplerAddressMode    address_mode_u      = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    VkSamplerAddressMode    address_mode_v      = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    VkSamplerAddressMode    address_mode_w      = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    VkBorderColor           border_color        = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
    float                   mip_lod_bias        = 0,
    VkBool32                anisotropy_enable   = VK_FALSE,
    float                   max_anisotropy      = 1,
    VkBool32                compare_enable      = VK_FALSE,
    VkCompareOp             compare_op          = VK_COMPARE_OP_NEVER,
    float                   min_lod             = 0,
    float                   max_lod             = 0,
    VkBool32                unnormalized_coordinates = VK_FALSE,
//  VkSamplerCreateFlags    flags               = 0,
    string                  file                = __FILE__,
    size_t                  line                = __LINE__,
    string                  func                = __FUNCTION__

    ) {

    VkSamplerCreateInfo sampler_ci = {
    //  flags                   : 0,
        magFilter               : mag_filter,
        minFilter               : min_filter,
        mipmapMode              : mipmap_mode,
        addressModeU            : address_mode_u,
        addressModeV            : address_mode_v,
        addressModeW            : address_mode_w,
        mipLodBias              : mip_lod_bias,
        anisotropyEnable        : anisotropy_enable,
        maxAnisotropy           : max_anisotropy,
        compareEnable           : compare_enable,
        compareOp               : compare_op,
        minLod                  : min_lod,
        maxLod                  : max_lod,
        borderColor             : border_color,
        unnormalizedCoordinates : unnormalized_coordinates,
    };

    VkSampler sampler;
    vk.device.vkCreateSampler( &sampler_ci, vk.allocator, &sampler ).vkAssert( null, file, line, func );
    return sampler;
}



mixin template Sampler_Member( uint sampler_count ) if( sampler_count > 0 ) {

    alias sc = sampler_count;

    VkSamplerCreateInfo sampler_ci = {
    //  flags                   : 0,
        magFilter               : VK_FILTER_LINEAR,
        minFilter               : VK_FILTER_LINEAR,
        mipmapMode              : VK_SAMPLER_MIPMAP_MODE_NEAREST,
        addressModeU            : VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        addressModeV            : VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        addressModeW            : VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        mipLodBias              : 0,
        anisotropyEnable        : VK_FALSE,
        maxAnisotropy           : 1,
        compareEnable           : VK_FALSE,
        compareOp               : VK_COMPARE_OP_NEVER,
        minLod                  : 0,
        maxLod                  : 0,
        borderColor             : VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
        unnormalizedCoordinates : VK_FALSE,
    };

    static if( sc == 1 ) {

        VkSampler       sampler;


        /// Construct the sampler from specified data.
        auto ref constructSampler( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
            vkAssert( isValid, "Meta Struct not initialized", file, line, func );   // assert that meta struct is initialized with a valid vulkan state pointer
            device.vkCreateSampler( & sampler_ci, allocator, & sampler ).vkAssert( "Construct Sampler", file, line, func );
            return this;
        }


        /// Destroy the sampler
        void destroySampler() {
            if( sampler != VK_NULL_HANDLE )
                vk.destroyHandle( sampler );
        }


        /// get sampler and reset the mamber to VK_NULL_HANDLE such that a new, different sampler can be created
        auto resetSampler() {
            auto result = sampler;
            sampler = VK_NULL_HANDLE;
            return result;
        }
    }

    else {

        VkSampler[sc]   sampler;


        /// Construct the sampler from specified data.
        auto ref constructSampler( uint32_t sampler_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
            vkAssert( isValid, "Meta Struct not initialized", file, line, func );   // assert that meta struct is initialized with a valid vulkan state pointer
        device.vkCreateSampler( & sampler_ci, allocator, & sampler[ sampler_index ] ).vkAssert( "Construct Sampler", file, line, func );
        return this;
        }


        /// Destroy the samplers
        void destroySampler() {
            foreach( ref smp; sampler )
                if( smp != VK_NULL_HANDLE )
                    vk.destroyHandle( smp );
        } alias destroySamplers = destroySampler;


        /// get one sampler and reset it to VK_NULL_HANDLE such that a new, different dampler can be created at thta index
        auto resetSampler( uint index ) {
            auto result = sampler[ index ];
            sampler[ index ] = VK_NULL_HANDLE;
            return result;
        }


        /// get all samplers views and reset them to VK_NULL_HANDLE such that a new, different samplers can be created
        auto resetSampler() {
            auto result = sampler;
            foreach( ref smp; sampler )
                smp = VK_NULL_HANDLE;
            return result;
        } alias resetSamplers = resetSampler;
    }


    /// Initialize image view create info to useful defaults
    void initSamplerCreateInfo() {
        sampler_ci = VkSamplerCreateInfo.init;
        sampler_ci.magFilter               = VK_FILTER_LINEAR;
        sampler_ci.minFilter               = VK_FILTER_LINEAR;
        sampler_ci.mipmapMode              = VK_SAMPLER_MIPMAP_MODE_NEAREST;
        sampler_ci.addressModeU            = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_ci.addressModeV            = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_ci.addressModeW            = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_ci.mipLodBias              = 0;
        sampler_ci.anisotropyEnable        = VK_FALSE;
        sampler_ci.maxAnisotropy           = 1;
        sampler_ci.compareEnable           = VK_FALSE;
        sampler_ci.compareOp               = VK_COMPARE_OP_NEVER;
        sampler_ci.minLod                  = 0;
        sampler_ci.maxLod                  = 0;
        sampler_ci.borderColor             = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
        sampler_ci.unnormalizedCoordinates = VK_FALSE;
    }


    /// Specify filter settings.
    auto ref filter(
        VkFilter            mag_filter,
        VkFilter            min_filter,
        VkBorderColor       border_color = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK
        ) {
        sampler_ci.magFilter   = mag_filter;
        sampler_ci.minFilter   = min_filter;
        sampler_ci.borderColor = border_color;
        return this;
    }


    /// Specify mipmap settings.
    auto ref mipmap(
        VkSamplerMipmapMode mipmap_mode,
        float               mip_lod_bias = 0,
        float               min_lod = 0,
        float               max_lod = 0
        ) {
        sampler_ci.mipmapMode  = mipmap_mode;
        sampler_ci.mipLodBias  = mip_lod_bias;
        sampler_ci.minLod      = min_lod;
        sampler_ci.maxLod      = max_lod;
        return this;
    }


    /// Specify address mode aka texture border behavior.
    auto ref addressMode(
        VkSamplerAddressMode    addressModeU,
        VkSamplerAddressMode    addressModeV,
        VkSamplerAddressMode    addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
        ) {
        sampler_ci.addressModeU = addressModeU;
        sampler_ci.addressModeV = addressModeV;
        sampler_ci.addressModeW = addressModeW;
        return this;
    }


    /// Specify whether to use anisotropy with an optional maximum anisotropy parameter.
    auto ref anisotropy( VkBool32 anisotropy_enable, float max_anisotropy = 1 ) {
        sampler_ci.anisotropyEnable    = anisotropy_enable;
        sampler_ci.maxAnisotropy       = max_anisotropy;
        return this;
    }


    /// Enable and specify comparison operations.
    auto ref compare( VkBool32 compare_enable, VkCompareOp compare_op = VK_COMPARE_OP_NEVER ) {
        sampler_ci.compareEnable   = compare_enable;
        sampler_ci.compareOp       = compare_op;
        return this;
    }


    /// Specify whether to use unnormalized coordinates.
    auto ref unnormalizedCoordinates( VkBool32 unnormalized_coordinates ) {
        sampler_ci.unnormalizedCoordinates   = unnormalized_coordinates;
        return this;
    }
}


alias Meta_Sampler = Meta_Sampler_T!1;
/// Meta struct to configure and construct a VkSampler.
/// Must be initialized with a Vulkan state struct.
struct Meta_Sampler_T( uint32_t sampler_count ) {
    mixin Vulkan_State_Pointer;
    mixin Sampler_Member!sampler_count;
    alias construct = constructSampler;
}



////////////////////////////
// Meta_Image and related //
////////////////////////////



/// query the properties of a certain image format
auto imageFormatProperties(
    ref Vulkan          vk,
    VkFormat            format,
    VkImageType         type,
    VkImageTiling       tiling,
    VkImageUsageFlags   usage,
    VkImageCreateFlags  flags = 0,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) {

    VkImageFormatProperties image_format_properties;
    vk.gpu.vkGetPhysicalDeviceImageFormatProperties(
        format, type, tiling, usage, flags, & image_format_properties ).vkAssert( "Image Format Properties", file, line, func );
    return image_format_properties;
}



alias   Core_Image                  = Core_Image_T!(0, 0);
alias   Core_Image_View             = Core_Image_T!(1, 0);
alias   Core_Image_View_T( uint c ) = Core_Image_T!(c, 0);
alias   Core_Image_View_Sampler     = Core_Image_T!(1, 1);

/// Wraps the essential Vulkan objects created with the editing procedure
/// of Meta_Image_T, all other internal structures are obsolete
/// after construction so that the Meta_Image_Sampler_T can be reused
/// after being reset.
struct  Core_Image_T( uint view_count, uint sampler_count ) {
    alias vc = view_count;
    alias sc = sampler_count;

    VkImage image;

         static if( view_count == 1 )       VkImageView                 image_view;
    else static if( view_count  > 1 )       VkImageView[ view_count ]   image_view;

         static if( sampler_count == 1 )    VkSampler                   sampler;
    else static if( sampler_count  > 1 )    VkSampler[ sampler_count ]  sampler;
}


/// Bulk destroy the resources belonging to this meta struct.
void destroy( CORE )( ref Vulkan vk, ref CORE core, bool destroy_sampler = true ) if( isCoreImage!CORE ) {
    vk.destroyHandle( core.image );

         static if( core.vc == 1 )  { if( core.view != VK_NULL_HANDLE ) vk.destroyHandle( core.view ); }
    else static if( core.vc  > 1 )  { foreach( ref v; core.view )  if( v != VK_NULL_HANDLE ) vk.destroyHandle( v ); }

    if( destroy_sampler ) {
             static if( core.sc == 1 )  { if( core.sampler != VK_NULL_HANDLE ) vk.destroyHandle( core.sampler ); }
        else static if( core.sc  > 1 )  { foreach( ref s; core.sampler )  if( s != VK_NULL_HANDLE ) vk.destroyHandle( s ); }
    }
}


/// Private template to identify Core_Image_T .
private template isCoreImage( T ) { enum isCoreImage = is( typeof( isCoreImageImpl( T.init ))); }
private void isCoreImageImpl( uint view_count, uint sampler_count )( Core_Image_T!( view_count, sampler_count ) ivs ) {}



alias   Meta_Image                      = Meta_Image_T!(0, 0);
alias   Meta_Image_View                 = Meta_Image_T!(1, 0);
alias   Meta_Image_Sampler              = Meta_Image_T!(1, 1);
alias   Meta_Image_View_Sampler         = Meta_Image_T!(1, 1);
alias   Meta_Image_View_T( uint c )     = Meta_Image_T!(c, 0);
alias   Meta_Image_Sampler_T( uint c )  = Meta_Image_T!(1, c);

/// Struct to capture image and memory creation as well as binding.
/// The struct can travel through several methods and can be filled with necessary data.
/// first thing after creation of this struct must be the assignment of the address of a
/// valid vulkan state struct. VkImageView(s) and VkSampler(s) are statically optional.
struct  Meta_Image_T( uint view_count, uint sampler_count ) {
    alias                   vc = view_count;
    alias                   sc = sampler_count;
    mixin                   Vulkan_State_Pointer;
    VkImage                 image           = VK_NULL_HANDLE;
    VkImageCreateInfo       image_ci        = { mipLevels : 1, arrayLayers : 1, samples : VK_SAMPLE_COUNT_1_BIT };
    mixin                   Memory_Member;
    mixin                   Memory_Buffer_Image_Common;
    static if( vc > 0 )     mixin  IView_Memeber!vc;
    static if( sc > 0 )     mixin  Sampler_Member!sc;

    version( DEBUG_NAME )   string name;


    /// bulk destroy the resources belonging to this meta struct
    void destroyResources( bool destroy_sampler = true ) {
        vk.destroyHandle( image );
        if( owns_device_memory )    vk.destroyHandle( device_memory );
        static if( vc > 0 )         destroyImageView;
        static if( sc > 0 )         if( destroy_sampler ) destroySampler;
        resetMemoryMember;
    }


    /// reset all internal data and return wrapped Vulkan objects
    /// VkImage as well as optional VkImageView(s) and VkSampler(s)
    auto reset() {
        Core_Image_T!( vc, sc ) result;
        result.image = resetImage;
        static if( vc > 0 ) result.image_view   = resetImageView;
        static if( sc > 0 ) result.sampler      = resetSampler;
        return result;
    }


    /// extract core descriptor elements VkDescriptorPool, VkDescriptorSet and VkDescriptorSetLayout
    /// without resetting the internal data structures
    auto extractCore() {
        Core_Image_T!( vc, sc ) result;
        result.image = image;
        static if( vc > 0 ) result.image_view   = image_view;
        static if( sc > 0 ) result.sampler      = sampler;
        return result;
    }


    //////////////////////
    // VkImage specific //
    //////////////////////


    /// reset all internal data and return wrapped Vulkan objects
    /// VkImage as well as optional VkImageView(s) and VkSampler(s)
    auto resetImage() {
        VkImage result = image;
        image = VK_NULL_HANDLE;
        initImageCreateInfo;
        return result;
    }


    /// Initialize image create info to useful defaults
    void initImageCreateInfo() {
        image_ci = VkImageCreateInfo.init;
        image_ci.mipLevels      = 1;
        image_ci.arrayLayers    = 1;
        image_ci.samples        = VK_SAMPLE_COUNT_1_BIT;
    }


    /// image_ci extent shortcut
    auto const ref extent() {
        return image_ci.extent;
    }


    /// specify format of image
    auto ref format( VkFormat format ) {
        image_ci.format = format;
        return this;
    }


    /// Specify image type and extent. For 2D type omit depth extent argument, for 1D type omit height extent argument.
    auto ref extent( uint32_t width, uint32_t height = 0, uint32_t depth = 0 ) {
        image_ci.imageType  = height == 0 ? VK_IMAGE_TYPE_1D : depth == 0 ? VK_IMAGE_TYPE_2D : VK_IMAGE_TYPE_3D;
        image_ci.extent     = VkExtent3D( width, height == 0 ? 1 : height, depth == 0 ? 1 : depth );
        return this;
    }


    /// Specify 2D image type and extent.
    auto ref extent( VkExtent2D extent, VkImageType image_type = VK_IMAGE_TYPE_2D ) {
        image_ci.imageType  = image_type;
        image_ci.extent     = VkExtent3D( extent.width, extent.height, 1 );
        return this;
    }


    /// Specify 3D image type and extent.
    auto ref extent( VkExtent3D extent, VkImageType image_type = VK_IMAGE_TYPE_3D ) {
        image_ci.imageType  = image_type;
        image_ci.extent     = extent;
        return this;
    }


    /// Specify image usage.
    auto ref usage( VkImageUsageFlags usage ) {
        image_ci.usage = usage;
        return this;
    }


    /// Add image usage. The added usage will be or-ed with the existing one.
    auto ref addUsage( VkImageUsageFlags usage ) {
        image_ci.usage |= usage;
        return this;
    }


    /// Specify mipmap levels.
    auto ref mipLevels( uint32_t levels ) {
        image_ci.mipLevels = levels;
        return this;
    }


    /// Specify array layers.
    auto ref arrayLayers( uint32_t layers ) {
        image_ci.arrayLayers = layers;
        return this;
    }


    /// Specify sample count, this function is aliased more descriptively to sampleCount.
    auto ref samples( VkSampleCountFlagBits samples ) {
        image_ci.samples = samples;
        return this;
    }
    alias sampleCount = samples;


    /// Specify image tiling.
    auto ref tiling( VkImageTiling tiling ) {
        image_ci.tiling = tiling;
        return this;
    }


    /// Specify the sharing queue families and implicitly the sharing mode, which defaults to VK_SHARING_MODE_EXCLUSIVE.
    auto ref sharingQueueFamilies( uint32_t[] sharing_family_queue_indices ) {
        image_ci.sharingMode            = VK_SHARING_MODE_CONCURRENT;
        image_ci.queueFamilyIndexCount  = sharing_family_queue_indices.length.toUint;
        image_ci.pQueueFamilyIndices    = sharing_family_queue_indices.ptr;
    }


    /// Specify the initial image layout. Can only be VK_IMAGE_LAYOUT_UNDEFINED or VK_IMAGE_LAYOUT_PREINITIALIZED.
    auto ref initialLayout( VkImageLayout layout,  string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {
        vkAssert( layout == VK_IMAGE_LAYOUT_UNDEFINED || VK_IMAGE_LAYOUT_PREINITIALIZED,
            "Initial image layout must be either VK_IMAGE_LAYOUT_UNDEFINED or VK_IMAGE_LAYOUT_PREINITIALIZED.", file, line, func );
        image_ci.initialLayout = layout;
        return this;
    }


    /// Construct the image from specified data.
    auto ref constructImage( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );

        // assert that 3D format is not combined with array layers if(!A != !B)
        vkAssert( image_ci.imageType == VK_IMAGE_TYPE_3D ? image_ci.arrayLayers == 1 : true,
            "Length of sharing_family_queue_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)",
            file, line, func );

        // assert that sharing_family_queue_indices is not 1
        vkAssert( image_ci.queueFamilyIndexCount != 1,
            "Length of sharing_family_queue_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)",
            file, line, func );

        vk.device.vkCreateImage( & image_ci, allocator, & image ).vkAssert( "Construct Image", file, line, func );
        vk.device.vkGetImageMemoryRequirements( image, & memory_requirements );

        return this;
    }


    /// Convenience function exists if we have 0 image view and 0 sampler or 1 image view and 0 or 1 sampler
    static if(( vc == 0 && sc == 1 ) || ( vc == 1 && sc <= 1 )) {
        /// Construct the Image, and possibly ImageView and Sampler from specified data.
        auto ref construct( VkMemoryPropertyFlags memory_property_flags, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
            constructImage( file, line, func );
            allocateMemory( memory_property_flags );
            static if( vc == 1 )    constructView( file, line, func );
            static if( sc == 1 )    constructSampler( file, line, func );
            return this;
        }
    }
}


/// package template to identify Meta_Image_T
package template isMetaImage( T ) { enum isMetaImage = is( typeof( isMetaImageImpl( T.init ))); }
private void isMetaImageImpl( uint view_count, uint sampler_count )( Meta_Image_T!( view_count, sampler_count ) meta_image ) {}


deprecated( "Use member methods to edit and Meta_Image_Sampler_T.construct instead" ) {
    /// init a simple VkImage with one level and one layer, sharing_family_queue_indices controls the sharing mode
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref initImage(
        ref Meta_Image          meta,
        VkFormat                format,
        uint32_t                width,
        uint32_t                height,
        VkImageUsageFlags       usage,
        VkSampleCountFlagBits   samples = VK_SAMPLE_COUNT_1_BIT,
        VkImageTiling           tiling = VK_IMAGE_TILING_OPTIMAL,
        VkImageLayout           initial_layout = VK_IMAGE_LAYOUT_UNDEFINED,
        uint32_t[]              sharing_family_queue_indices = [],
        VkImageCreateFlags      flags   = 0,
        string                  file    = __FILE__,
        size_t                  line    = __LINE__,
        string                  func    = __FUNCTION__

        ) {

        return meta.create(
            format, width, height, 0, 1, 1, usage, samples,
            tiling, initial_layout, sharing_family_queue_indices, flags,
            file, line, func );
    }


    /// init a VkImage, sharing_family_queue_indices controls the sharing mode
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref initImage(
        ref Meta_Image          meta,
        VkFormat                format,
        uint32_t                width,
        uint32_t                height,
        uint32_t                depth,
        uint32_t                mip_levels,
        uint32_t                array_layers,
        VkImageUsageFlags       usage,
        VkSampleCountFlagBits   samples = VK_SAMPLE_COUNT_1_BIT,
        VkImageTiling           tiling  = VK_IMAGE_TILING_OPTIMAL,
        VkImageLayout           initial_layout = VK_IMAGE_LAYOUT_UNDEFINED,
        uint32_t[]              sharing_family_queue_indices = [],
        VkImageCreateFlags      flags   = 0,
        string                  file    = __FILE__,
        size_t                  line    = __LINE__,
        string                  func    = __FUNCTION__

        ) {

        vkAssert( sharing_family_queue_indices.length != 1,
            "Length of sharing_family_queue_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)",
            file, line, func );

        VkImageCreateInfo image_ci = {
            flags                   : flags,
            imageType               : height == 0 ? VK_IMAGE_TYPE_1D : depth == 0 ? VK_IMAGE_TYPE_2D : VK_IMAGE_TYPE_3D,
            format                  : format,
            extent                  : { width, height == 0 ? 1 : height, depth == 0 ? 1 : depth },
            mipLevels               : mip_levels,
            arrayLayers             : array_layers,
            samples                 : samples,
            tiling                  : tiling,
            usage                   : usage,
            sharingMode             : sharing_family_queue_indices.length > 1 ? VK_SHARING_MODE_CONCURRENT : VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount   : sharing_family_queue_indices.length.toUint,
            pQueueFamilyIndices     : sharing_family_queue_indices.length > 1 ? sharing_family_queue_indices.ptr : null,
            initialLayout           : initial_layout,
        };

        return meta.create( image_ci, file, line, func );
    }


    /// init a VkImage, general create image function, gets a VkImageCreateInfo as argument
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref initImage(
        ref Meta_Image              meta,
        const ref VkImageCreateInfo image_ci,
        string                      file = __FILE__,
        size_t                      line = __LINE__,
        string                      func = __FUNCTION__
        ) {
        vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );     // meta struct must be initialized with a valid vulkan state pointer

        if( meta.image != VK_NULL_HANDLE )                      // if an VkImage was created with this meta struct already
            meta.destroyHandle( meta.image );                         // destroy it first

        meta.image_ci = image_ci;
        meta.device.vkCreateImage( & meta.image_ci, meta.allocator, & meta.image ).vkAssert( "Init Image", file, line, func );
        meta.device.vkGetImageMemoryRequirements( meta.image, & meta.memory_requirements );
        return meta;
    }

    alias create = initImage;
}



deprecated( "Use member methods to edit and Meta_Image_Sampler_T.constructView instead" ) {

    /// create a VkImageView which closely corresponds to the underlying VkImage type
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref createView( ref Meta_Image_View meta, VkImageAspectFlags subrecource_aspect_mask = VK_IMAGE_ASPECT_COLOR_BIT ) {
        VkImageSubresourceRange subresource_range = {
            aspectMask      : subrecource_aspect_mask,
            baseMipLevel    : cast( uint32_t )0,
            levelCount      : meta.image_ci.mipLevels,
            baseArrayLayer  : cast( uint32_t )0,
            layerCount      : meta.image_ci.arrayLayers, };
        return meta.createView( subresource_range );
    }

    /// create a VkImageView which closely corresponds to the underlying VkImage type
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref createView( ref Meta_Image_View meta, VkImageSubresourceRange subresource_range ) {
        return meta.createView( subresource_range, cast( VkImageViewType )meta.image_ci.imageType, meta.image_ci.format );
    }

    /// create a VkImageView with choosing an image view type and format for the underlying VkImage, component mapping is identity
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref createView( ref Meta_Image_View meta, VkImageSubresourceRange subresource_range, VkImageViewType view_type, VkFormat view_format ) {
        return meta.createView( subresource_range, view_type, view_format, VkComponentMapping(
            VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY ));
    }

    /// create a VkImageView with choosing an image view type, format and VkComponentMapping for the underlying VkImage
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref createView(
        ref Meta_Image_View     meta,
        VkImageSubresourceRange subresource_range,
        VkImageViewType         view_type,
        VkFormat                view_format,
        VkComponentMapping      component_mapping,
        string                  file = __FILE__,
        size_t                  line = __LINE__,
        string                  func = __FUNCTION__
        ) {
        if( meta.image_view != VK_NULL_HANDLE )
            meta.destroyHandle( meta.image_view );
        with( meta.image_view_ci ) {
            image               = meta.image;
            viewType            = view_type;
            format              = view_format;
            subresourceRange    = subresource_range;
            components          = component_mapping;
        }
        meta.device.vkCreateImageView( & meta.image_view_ci, meta.allocator, & meta.image_view ).vkAssert( "Create View", file, line, func );
        return meta;
    }
}



alias  Meta_IView = Meta_IView_T!1;
struct Meta_IView_T( uint32_t view_count ) {
    mixin Vulkan_State_Pointer;
    mixin IView_Memeber!view_count;
    alias construct = constructView;


    ///
    auto ref setImage( ref Meta_Image meta_image ) {
        // assign the valid image to the image_view_ci.image member
        image_view_ci.image = meta_image.image;

        // check if view type was specified
        if( image_view_ci.viewType == VK_IMAGE_VIEW_TYPE_MAX_ENUM )
            image_view_ci.viewType = cast( VkImageViewType )meta_image.image_ci.imageType;

        // check if view format was specified
        if( image_view_ci.format == VK_FORMAT_MAX_ENUM )
            image_view_ci.format = meta_image.image_ci.format;

        return this;
    }


    auto ref setImage( VkImage image ) {
        // assign the valid image to the image_view_ci.image member
        image_view_ci.image = image;
        return this;
    }
}




// TODO(pp): create functions for VkImageSubresourceRange, VkBufferImageCopy and conversion functions between them


/// records a VkImage transition command in argument command buffer
void recordTransition(
    VkCommandBuffer         cmd_buffer,
    VkImage                 image,
    VkImageSubresourceRange subresource_range,
    VkImageLayout           old_layout,
    VkImageLayout           new_layout,
    VkAccessFlags           src_accsess_mask,
    VkAccessFlags           dst_accsess_mask,
    VkPipelineStageFlags    src_stage_mask = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
    VkPipelineStageFlags    dst_stage_mask = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
    VkDependencyFlags       dependency_flags = 0,
    ) nothrow {
    VkImageMemoryBarrier layout_transition_barrier = {
        srcAccessMask       : src_accsess_mask,
        dstAccessMask       : dst_accsess_mask,
        oldLayout           : old_layout,
        newLayout           : new_layout,
        srcQueueFamilyIndex : VK_QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex : VK_QUEUE_FAMILY_IGNORED,
        image               : image,
        subresourceRange    : subresource_range,
    };

    // Todo(pp): consider using these cases

/*  switch (old_image_layout) {
        case VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL:
            image_memory_barrier.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            break;

        case VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL:
            image_memory_barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            break;

        case VK_IMAGE_LAYOUT_PREINITIALIZED:
            image_memory_barrier.srcAccessMask = VK_ACCESS_HOST_WRITE_BIT;
            break;

        default:
            break;
    }

    switch (new_image_layout) {
        case VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            break;

        case VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            break;

        case VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            break;

        case VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            break;

        case VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
            break;

        default:
            break;
    }
*/
    cmd_buffer.vkCmdPipelineBarrier(
        src_stage_mask, dst_stage_mask, dependency_flags,
        0, null, 0, null, 1, & layout_transition_barrier
    );
}



// bool is_null(        Meta_Image meta ) { return meta.image.is_null_handle; }
// bool is_constructed( Meta_Image meta ) { return !meta.is_null; }



// checking format support
//VkFormatProperties format_properties;
//vk.gpu.vkGetPhysicalDeviceFormatProperties( VK_FORMAT_B8G8R8A8_UNORM, & format_properties );
//format_properties.printTypeInfo;

// checking image format support (additional capabilities)
//VkImageFormatProperties image_format_properties;
//vk.gpu.vkGetPhysicalDeviceImageFormatProperties(
//  VK_FORMAT_B8G8R8A8_UNORM,
//  VK_IMAGE_TYPE_2D,
//  VK_IMAGE_TILING_OPTIMAL,
//  VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
//  0,
//  & image_format_properties).vkAssert;
//image_format_properties.printTypeInfo;
