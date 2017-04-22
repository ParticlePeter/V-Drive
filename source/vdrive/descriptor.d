module vdrive.descriptor;

import erupted;

import vdrive.util;
import vdrive.state;

import core.stdc.stdio : printf;


/////////////////
// Descriptors //
/////////////////



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


/// create a VkBufferView which can be exclusively used as a descriptor
/// Params:
///     vk = reference to a VulkanState struct
///     buffer = for which the view will be created
///     format = of the view
///     offset = into the original buffer
///     range  = of the view, can be VK_WHOLE_SIZE (starting at offset)
/// Returns: VkDescriptorPool
auto createBufferView(
    ref Vulkan      vk,
    VkBuffer        buffer,
    VkFormat        format,
    VkDeviceSize    offset,
    VkDeviceSize    range,
//  VkBufferViewCreateFlags flags = 0,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) {
    VkBufferViewCreateInfo buffer_view_ci = {
    //  flags   : flags,
        buffer  : buffer,
        format  : format,
        offset  : offset,
        range   : range,
    };

    VkBufferView buffer_view;
    vk.device.vkCreateBufferView( &buffer_view_ci, vk.allocator, &buffer_view ).vkAssert( null, file, line, func );
    return buffer_view;
}



/////////////////////
// Descriptor Pool //
/////////////////////



/// create a one descriptor type VkDescriptorPool
/// the max_descriptor_sets parameter is by default set to one it has been suggested ( e.g. GDC2016/17 )
/// to use only one huge descriptor set for all shader module
/// Params:
///     vk = reference to a VulkanState struct
///     descriptor_type = type of each descriptor which can be allocated from pool
///     descriptor_count = count of the descriptors which can be allocated from pool
///     max_descriptor_sets = optional ( default = 1 ) max descriptor sets which can be created from the descriptors
///     create_flags = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
/// Returns: VkDescriptorPool
auto createDescriptorPool(
    ref Vulkan          vk,
    VkDescriptorType    descriptor_type,            // specifies the only descriptor type which can be allocated from the pool
    uint32_t            descriptor_count,           // count of the descriptors of that particular type
    uint32_t            max_descriptor_sets = 1,    // max descriptor sets which can be created from these descriptors
    VkDescriptorPoolCreateFlags create_flags = 0,   // only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    VkDescriptorPoolSize[1] pool_size_descriptor_counts = [ VkDescriptorPoolSize( descriptor_type, descriptor_count ) ];
    return vk.createDescriptorPool( pool_size_descriptor_counts, max_descriptor_sets, create_flags, file, line, func );
}


/// create a multi descriptor type VkDescriptorPool
/// the max_descriptor_sets parameter is by default set to one it has been suggested ( e.g. GDC2016/17 )
/// to use only one huge descriptor set for all shader module
/// Params:
///     vk = reference to a VulkanState struct
///     descriptor_pool_sizes = array of VkDescriptorPoolSize each specifying a descriptor type and count
///     max_descriptor_sets = optional ( default = 1 ) max descriptor sets which can be created from the descriptors
///     create_flags = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
/// Returns: VkDescriptorPool
auto createDescriptorPool(
    ref Vulkan              vk,
    VkDescriptorPoolSize[]  descriptor_pool_sizes,  // array of structs with type and count of descriptor
    uint32_t                max_sets,               // max descriptor sets which can be created from these descriptors
    VkDescriptorPoolCreateFlags create_flags = 0,   // only one flag possible: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) {
    VkDescriptorPoolCreateInfo pool_create_info = {
        flags           : create_flags,
        maxSets         : max_sets,
        poolSizeCount   : descriptor_pool_sizes.length.toUint,
        pPoolSizes      : descriptor_pool_sizes.ptr,
    };

    VkDescriptorPool descriptor_pool;
    vk.device.vkCreateDescriptorPool( &pool_create_info, vk.allocator, &descriptor_pool ).vkAssert( null, file, line, func );
    return descriptor_pool;
}



///////////////////////////////
// Descriptor Set and Layout //
///////////////////////////////



/// create VkDescriptorSetLayout from one VkDescriptorSetLayoutBinding
/// parameters are the same as those of a VkDescriptorSetLayoutBinding
/// internally one VkDescriptorSetLayoutBinding is created and passed to vkCreateDescriptorSetLayout
/// Params:
///     vk = reference to a VulkanState struct
///     binding = binding index of the layout
///     descriptor_count = count of the descriptors in case of an array of descriptors
///     shader_stage_flags = shader stages where the descriptor can be used
///     immutable_samplers = optional, pointer to ( an array of descriptor_count length ) of immutable samplers
/// Returns: VkDescriptorSetLayout
auto createSetLayout(
    ref Vulkan          vk,
    uint32_t            binding,
    VkDescriptorType    descriptor_type,
    uint32_t            descriptor_count,
    VkShaderStageFlags  shader_stage_flags,
    const( VkSampler )* immutable_samplers = null,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    const VkDescriptorSetLayoutBinding[1] descriptor_set_layout_bindings = [
        VkDescriptorSetLayoutBinding( binding, descriptor_type, descriptor_count, shader_stage_flags, immutable_samplers )
    ];
    return vk.createSetLayout( descriptor_set_layout_bindings, 0, file, line, func );
}


/// create VkDescriptorSetLayout from one VkDescriptorSetLayoutBinding
/// parameters are the same as those of a VkDescriptorSetLayoutBinding but missing immutable_samplers
/// instead set_layout_create_flags for the set layout is provided
/// in the case of one layout binding set layout immutable samplers and
/// VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR are mutually exclusive
/// internally one VkDescriptorSetLayoutBinding is created and passed to vkCreateDescriptorSetLayout
/// Params:
///     vk = reference to a VulkanState struct
///     binding = binding index of the layout
///     descriptor_count = count of the descriptors in case of an array of descriptors
///     shader_stage_flags = shader stages where the descriptor can be used
///     set_layout_create_flags = only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
/// Returns: VkDescriptorSetLayout
auto createSetLayout(
    ref Vulkan          vk,
    uint32_t            binding,
    VkDescriptorType    descriptor_type,
    uint32_t            descriptor_count,
    VkShaderStageFlags  shader_stage_flags,
    VkDescriptorSetLayoutCreateFlags set_layout_create_flags,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    const VkDescriptorSetLayoutBinding[1] descriptor_set_layout_bindings = [
        VkDescriptorSetLayoutBinding( binding, descriptor_type, descriptor_count, shader_stage_flags, null ) ];
    return vk.createSetLayout( descriptor_set_layout_bindings, set_layout_create_flags, file, line, func );
}


/// create a VkDescriptorSetLayout from several VkDescriptorSetLayoutBinding(s)
/// Params:
///     vk = reference to a VulkanState struct
///     descriptor_set_layout_bindings = to specify the multi binding set layout
///     set_layout_create_flags = only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
/// Returns: VkDescriptorSetLayout
auto createSetLayout(
    ref Vulkan                              vk,
    const VkDescriptorSetLayoutBinding[]    descriptor_set_layout_bindings,
    VkDescriptorSetLayoutCreateFlags        set_layout_create_flags = 0,
    string                                  file = __FILE__,
    size_t                                  line = __LINE__,
    string                                  func = __FUNCTION__
    ) {
    VkDescriptorSetLayoutCreateInfo descriptor_set_layout_create_info = {
        flags           : set_layout_create_flags,
        bindingCount    : descriptor_set_layout_bindings.length.toUint,
        pBindings       : descriptor_set_layout_bindings.ptr,
    };

    VkDescriptorSetLayout descriptor_set_layout;
    vk.device.vkCreateDescriptorSetLayout(
        &descriptor_set_layout_create_info,
        vk.allocator, &descriptor_set_layout ).vkAssert( null, file, line, func );
    return descriptor_set_layout;
}


/// allocate a VkDescriptorSet from a VkDescriptorPool with given VkDescriptorSetLayout
/// Params:
///     vk = reference to a VulkanState struct
///     descriptor_pool = the pool from which the descriptors of the set will be allocated
///     descriptor_set_layout = the layout for the resulting descriptor set
/// Returns: VkDescriptorSet
auto allocateSet(
    ref Vulkan              vk,
    VkDescriptorPool        descriptor_pool,
    VkDescriptorSetLayout   descriptor_set_layout,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) {
    VkDescriptorSetAllocateInfo descriptor_allocate_info = {
        descriptorPool      : descriptor_pool,
        descriptorSetCount  : 1,
        pSetLayouts         : &descriptor_set_layout,
    };

    VkDescriptorSet descriptor_set;
    vk.device
        .vkAllocateDescriptorSets( &descriptor_allocate_info, &descriptor_set )
        .vkAssert( null, file, line, func );
    return descriptor_set;
}


/// allocate multiple VkDescriptorSet(s) from a VkDescriptorPool with given VkDescriptorSetLayout(s)
/// Params:
///     vk = reference to a VulkanState struct
///     descriptor_pool = the pool from which the descriptors of the set will be allocated
///     descriptor_sets_layouts = the layouts for the resulting descriptor set
/// Returns: std.container.array!VkDescriptorSet
auto allocateSet(
    ref Vulkan              vk,
    VkDescriptorPool        descriptor_pool,
    VkDescriptorSetLayout[] descriptor_sets_layouts,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) {
    VkDescriptorSetAllocateInfo descriptor_allocate_info = {
        descriptorPool      : descriptor_pool,
        descriptorSetCount  : descriptor_sets_layouts.length.toUint,
        pSetLayouts         : descriptor_sets_layouts.ptr,
    };
    auto descriptor_sets = sizedArray!VkDescriptorSet( descriptor_sets_layouts.length );
    vk.device
        .vkAllocateDescriptorSets( &descriptor_allocate_info, descriptor_sets.ptr )
        .vkAssert( null, file, line, func );
    return descriptor_sets;
}



////////////////////////////
// Meta_Descriptor_Layout //
////////////////////////////



/// Wraps the essential Vulkan objects created with the editing procedure
/// of Meta_Descriptor_Layout, all other internal structures are obsolete
/// after construction so that the Meta_Descriptor_Layout can be reused
/// after being reset
struct Core_Descriptor {
    VkDescriptorPool        descriptor_pool;
    VkDescriptorSetLayout   descriptor_set_layout;
    VkDescriptorSet         descriptor_set;
}


/// destroy all wrapped Vulkan objects
/// Params:
///     vk = Vulkan state struct holding the device through which these resources were created
///     core = the wrapped VkDescriptorPool ( with it the VkDescriptorSet ) and the VkDescriptorSetLayout to destroy
/// Returns: the passed in Meta_Structure for function chaining
void destroy( ref Vulkan  vk, ref Core_Descriptor core ) {
    vdrive.state.destroy( vk, core.descriptor_set_layout ); // no nice syntax, vdrive.state.destroy overloads
    vdrive.state.destroy( vk, core.descriptor_pool );       // get confused with this one in the module scope
    //core.descriptor_set_layout = VK_NULL_HANDLE;          // handled by the destroy overload
    //core.descriptor_pool = VK_NULL_HANDLE;                // handled by the destroy overload
    core.descriptor_set = VK_NULL_HANDLE;
}


/// meta struct to configure a VkDescriptorSetLayout and allocate a
/// VkDescriptorSet from an external or internally managed VkDescriptorPool
/// dynamic arrays exist to add VkDescriptorSetLayoutBinding and immutable VkSampler
/// must be initialized with a Vulkan state struct
struct Meta_Descriptor_Layout {
    mixin                               Vulkan_State_Pointer;

    private VkDescriptorPool            pool = VK_NULL_HANDLE;          // this must not be directly set able other than from module
    auto descriptor_pool()              { return pool; }                // use getter function to get a copy
    uint32_t[ VK_DESCRIPTOR_TYPE_RANGE_SIZE ] descriptor_types_count;
    VkDescriptorSetLayout               descriptor_set_layout;
    VkDescriptorSet                     descriptor_set;

    Array!VkDescriptorSetLayoutBinding  descriptor_set_layout_bindings; // the set layout bindings of the resulting set
    Array!VkSampler                     immutable_samplers;             // slices of this member can be associated with any layout binding

    /// reset all internal data and return wrapped Vulkan objects
    /// VkDescriptorPool, VkDescriptorSet and VkDescriptorSetLayout
    auto reset() {
        Core_Descriptor result = { pool, descriptor_set_layout, descriptor_set };
        descriptor_types_count[] = 0;
        descriptor_set_layout = VK_NULL_HANDLE;
        descriptor_set = VK_NULL_HANDLE;
        pool = VK_NULL_HANDLE;
        return result;
    }

    /// destroy the VkDescriptorLayout and, if internal, the VkDescriptorPool
    void destroyResources() {
        vdrive.state.destroy( vk, descriptor_set_layout );
        if( pool != VK_NULL_HANDLE ) vdrive.state.destroy( vk, pool );
    }
}



/// add a VkDescriptorSetLayoutBinding to the Meta_Descriptor_Layout
/// Params:
///     meta = reference to a Meta_Descriptor_Layout struct
///     binding = index of the layout binding
///     descriptor_count = count of descriptors in this layout binding, must be > 0
///     descriptor_type  = the type of the layout binding and hence descriptor(s)
///     shader_stage_flags = shader stage access filter for this layout binding
/// Returns: the passed in Meta_Structure for function chaining
auto ref addLayoutBinding(
    ref Meta_Descriptor_Layout meta,
    uint32_t            binding,
    uint32_t            descriptor_count,
    VkDescriptorType    descriptor_type,
    VkShaderStageFlags  shader_stage_flags,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    vkAssert( descriptor_count > 0,
        "param descriptor_count of addLayoutBinding() must be greater 0",
        file, line, func );

    VkDescriptorSetLayoutBinding layout_binding = {
        binding             : binding,
        descriptorType      : descriptor_type,
        descriptorCount     : descriptor_count,
        stageFlags          : shader_stage_flags,
        pImmutableSamplers  : null, // might be added in addImmutableSampler
    };
    meta.descriptor_set_layout_bindings.append( layout_binding );
    meta.descriptor_types_count[ cast( size_t )descriptor_type ] += descriptor_count;

    return meta;
}


/// add an immutable VkSampler to the last VkDescriptorSetLayoutBinding
/// Params:
///     meta = reference to a Meta_Descriptor_Layout struct
///     sampler = to immutably bound to the last added layout binding
/// Returns: the passed in Meta_Structure for function chaining
auto ref addImmutableSampler(
    ref Meta_Descriptor_Layout  meta,
    VkSampler   sampler,
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) {
    // enforce that a layout binding has been added so far
    vkAssert( !meta.descriptor_set_layout_bindings.empty,
        "addLayoutBinding() must have been called first",
        file, line, func );

    meta.immutable_samplers.append( sampler );

    // shortcut to the last  meta.descriptor_set_layout_bindings
    auto layout_binding = & meta.descriptor_set_layout_bindings[ $-1 ];

    // increase the descriptor_count of the current descriptor_type
    ++meta.descriptor_types_count[ cast( size_t )layout_binding.descriptorType ];

    // helper to store different values in the lower and upper 16 bits
    // the actual descriptorCount is stored in the lower 16 bits, see bellow
    Pack_Index_And_Count piac = layout_binding.descriptorCount;         // preserve index and count

    if( layout_binding.pImmutableSamplers is null ) {

        // When adding immutable samplers the descriptorCount must initially be 0
        // as it is increased with adding a sampler
        // if no sampler was added so far we guarantee that it is 0
        piac.count = 0;

        // this is not safe, the data in descriptor_array might get reallocate when descriptor is appended
        // but it will be patched in createSetLayout( ... ) function bellow with the right address
        layout_binding.pImmutableSamplers = & meta.immutable_samplers[ $-1 ];

        // as in the general addDescriptorType() function we need to keep track of the index in
        // the immutable_samplers array to recreate the proper address in case of a reallocation
        // we take the upper 16 bits of the latest descriptor_set_layout_bindings.descriptorCount
        // ( its unlikely that we'll ever need more than 65536 immutable samplers in one set )
        piac.index = cast( ushort )( meta.immutable_samplers.length - 1 );  // setting the upper 16 bits
    }

    // increase the descriptorCount of last descriptor_set_layout_bindings with the bit filter struct
    ++piac.count;                                                       // increasing the lower 16 bits
    layout_binding.descriptorCount = piac.descriptor_count;             // assigning back to the original member

    return meta;
}


/// if we want to avoid dynamic array allocations within the meta struct we can directly 'set' exactly one slice or a reference
/// to descriptor type definition structs/handles of VkSampler, VkDescriptorImageInfo, VkDescriptorBufferInfo or VkBufferView
/// this approach is mutually exclusive per layout binding to 'add' these structs one by one
/// memory to hold these type definition must be valid up until we call attachSet()
// Todo(pp): is this useful? We would have to tediously create arrays of info structs our selves
// only valid use case seems to be for immutable samplers and texel buffer views



/// create the VkDescriptorSetLayout and store it as a member of the Meta_Descriptor_Layout struct
/// from the so far specified descriptor set layout bindings and optional immutable samplers
/// Params:
///     meta = reference to a Meta_Descriptor_Layout struct
///     set_layout_create_flags = optional, only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
/// Returns: the passed in Meta_Structure for function chaining
auto ref createSetLayout(
    ref Meta_Descriptor_Layout          meta,
    VkDescriptorSetLayoutCreateFlags    set_layout_create_flags = 0,
    string                              file = __FILE__,
    size_t                              line = __LINE__,
    string                              func = __FUNCTION__
    ) {
    // the dynamic array immutable_samplers might have reallocated during append operations
    // this means that the layout_binding.pImmutableSamplers might be invalid and must be patched
    // for that purpose we stored the starting index of immutable_samplers array
    // in the upper 16 bits of layout_binding.descriptorCount array
    // we need to separate the lower and upper bits, store back the right count ( lower bits )
    // and patch pImmutableSamplers with the pointer to immutable_samplers[ upper 16 bits ] element
    foreach( ref layout_binding; meta.descriptor_set_layout_bindings ) {
        if( layout_binding.pImmutableSamplers !is null ) {
            Pack_Index_And_Count piac = layout_binding.descriptorCount;
            layout_binding.pImmutableSamplers = & meta.immutable_samplers[ piac.index ];
            layout_binding.descriptorCount = piac.count;
        }
    }

    meta.descriptor_set_layout = meta.createSetLayout(
        meta.descriptor_set_layout_bindings.data, set_layout_create_flags, file, line, func );
    return meta;
}


/// allocate the VkDescriptorSet stored in descriptor_set member of Meta_Descriptor_Layout
/// from the internal Meta_Descriptor_Layout VkDescriptorPool with sufficient descriptor memory
/// created before allocating in this function
/// Params:
///     meta = reference to a Meta_Descriptor_Layout struct
///     descriptor_pool_create_flags = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
/// Returns: the passed in Meta_Structure for function chaining
auto ref allocateSet(
    ref Meta_Descriptor_Layout  meta,
    VkDescriptorPoolCreateFlags descriptor_pool_create_flags = 0,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    // create an static array of pool VkDescriptorPoolSize
    VkDescriptorPoolSize[ VK_DESCRIPTOR_TYPE_RANGE_SIZE ] descriptor_pool_sizes;

    // use this to edit data at descriptor_pool_sizes[ pool_size_index ]
    // with this approach we are merging used meta.descriptor_types_count ( non zero values in at index descriptor_type )
    size_t pool_size_index;

    // the iter index descriptor_type corresponds to a certain VkDescriptorType enum
    foreach( descriptor_type, descriptor_count; meta.descriptor_types_count ) {
        if( descriptor_count > 0 ) {
            descriptor_pool_sizes[ pool_size_index ].type = cast( VkDescriptorType )descriptor_type;
            descriptor_pool_sizes[ pool_size_index ].descriptorCount = descriptor_count;
            ++pool_size_index;
        }
    }

    // create the descriptor pool, pool_size_index now represents the count of used pool sizes
    meta.pool = meta.createDescriptorPool(      // in descriptor_pool_sizes
        descriptor_pool_sizes[ 0 .. pool_size_index ], 1, descriptor_pool_create_flags );

    // forward to next overload
    return meta.allocateSet( meta.descriptor_pool, file, line, func );
}

/// allocate the VkDescriptorSet stored in descriptor_set member of Meta_Descriptor_Layout
/// from an external VkDescriptorPool, must have sufficient descriptor memory
/// Params:
///     meta = reference to a Meta_Descriptor_Layout struct
///     descriptor_pool_create_flags = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
/// Returns: the passed in Meta_Structure for function chaining
auto ref allocateSet(
    ref Meta_Descriptor_Layout  meta,
    VkDescriptorPool            descriptor_pool,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    // call createSetLayout() if the meta.descriptor_set_layout has not been called so far
    // if it is necessary to pass a VkDescriptorSetLayoutCreateFlags to the corresponding create info
    // createSetLayout must be called manually beforehand
    if( meta.descriptor_set_layout == VK_NULL_HANDLE )
        meta.createSetLayout( 0, file, line, func );

    // allocate the VkDescriptorSet
    meta.descriptor_set = meta.allocateSet( descriptor_pool, meta.descriptor_set_layout, file, line, func );

    // free temporary memory which is not required after the VkDescriptorSet has been allocated
    meta.descriptor_set_layout_bindings.clear;
    meta.immutable_samplers.clear;

    return meta;
}



////////////////////////////
// Meta_Descriptor_Update //
////////////////////////////



/// meta struct to configure an dynamic array of VkWriteDescriptorSet to update a VkDescriptorSet
/// additional arrays exist to add VkDescriptorImageInfo, VkDescriptorBufferInfo and VkDescriptorBufferInfo
/// several versions of this struct (partially) updating one VkDescriptorSet are meant to coexist
/// must be initialized with a Vulkan state struct
struct Meta_Descriptor_Update {
    mixin                               Vulkan_State_Pointer;
    Array!VkWriteDescriptorSet          write_descriptor_sets;          // write descriptor sets in case we want to update the set
    Array!VkDescriptorImageInfo         image_infos;                    // slices of these three members ...
    Array!VkDescriptorBufferInfo        buffer_infos;                   // ... can be associated with ...
    Array!VkBufferView                  texel_buffer_views;             // ... any write_descriptor_set

    void reset() {
        write_descriptor_sets.clear;
        image_infos.clear;
        buffer_infos.clear;
        texel_buffer_views.clear;
    }
}



/// add a VkWriteDescriptorSet to the Meta_Descriptor_Update
/// Params:
///     meta = reference to a Meta_Descriptor_Update struct
///     binding = index of the corresponding layout binding
///     dst_array_element = starting index of the array element which should be updated
///     descriptor_type  = the type of the corresponding layout binding and hence descriptor(s)
/// Returns: the passed in Meta_Structure for function chaining
auto ref addBindingUpdate(
    ref Meta_Descriptor_Update  meta,
    uint32_t                    binding,
    uint32_t                    dst_array_element,
    VkDescriptorType            descriptor_type
    ) {
    VkWriteDescriptorSet write_set = {
    //  dstSet              : meta.descriptor_set,
        dstBinding          : binding,
        dstArrayElement     : dst_array_element,
        descriptorCount     : 0,    // descriptorCount, will increase addDescriptorTypeUpdate
        descriptorType      : descriptor_type,
        pImageInfo          : null,
        pBufferInfo         : null,
        pTexelBufferView    : null,
    };
    meta.write_descriptor_sets.append( write_set );

    return meta;
}


/// private template function to add either
/// VkDescriptorImageInfo, VkDescriptorBufferInfo or VkDescriptorBufferInfo
/// to the Meta_Descriptor_Update
/// Params:
///     descriptor_array = evaluates to image_infos, buffer_infos or texel_buffer_views
///     write_pointer = evaluates to pImageInfo, pBufferInfo or pTexelBufferView
///     meta = reference to a Meta_Descriptor_Update struct
///     descriptor = VkDescriptorImageInfo, VkDescriptorBufferInfo or VkDescriptorBufferInfo
///     dst_array_element = starting index of the array element which should be updated
///     descriptor_type = the type of the corresponding layout binding and hence descriptor(s)
/// Returns: the passed in Meta_Structure for function chaining
private auto ref addDescriptorTypeUpdate(
    DESCRIPTOR_TYPE,
    alias descriptor_array,
    alias write_pointer
    )(
    ref Meta_Descriptor_Update  meta,
    DESCRIPTOR_TYPE             descriptor,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    pragma( inline, true ); // this function should be inlined

    // shortcut to the last meta.write_descriptor_sets
    auto write_set = & meta.write_descriptor_sets[ $-1 ];

    // add proper VkImageInfo usage checks here
    static if( is( DESCRIPTOR_TYPE == VkDescriptorImageInfo )) {
        switch( write_set.descriptorType ) {
            case VK_DESCRIPTOR_TYPE_SAMPLER : vkAssert( descriptor.sampler != VK_NULL_HANDLE && descriptor.imageView == VK_NULL_HANDLE,
                "VK_DESCRIPTOR_TYPE_SAMPLER requires a VkSampler without VkImageView", file, line, func ); break;
            case VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER : vkAssert( /*descriptor.sampler != VK_NULL_HANDLE &&*/ descriptor.imageView != VK_NULL_HANDLE,  // if an immutable sampler was created at this binding we do not need to pass the sampler here again
                "VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER requires a VkImageView and VkSampler", file, line, func ); break;
            case VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE : vkAssert( descriptor.sampler == VK_NULL_HANDLE && descriptor.imageView != VK_NULL_HANDLE,
                "VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE requires a VkImageView without VkSampler", file, line, func ); break;
            case VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT : vkAssert( descriptor.sampler == VK_NULL_HANDLE && descriptor.imageView != VK_NULL_HANDLE,
                "VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT requires a VkImageView without VkSampler", file, line, func ); break;
            default : vkAssert( false,
                "VkDescriptorImageInfo is not compatible with VkDescriptorType ", file, line, func, toCharPtr( write_set.descriptorType )); break;
        }
    } else static if( is( DESCRIPTOR_TYPE == VkDescriptorBufferInfo )) {
        vkAssert(
            write_set.descriptorType == VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER || write_set.descriptorType == VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC
        ||  write_set.descriptorType == VK_DESCRIPTOR_TYPE_STORAGE_BUFFER || write_set.descriptorType == VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC,
            "VkDescriptorBufferInfo is not compatible with VkDescriptorType ", file, line, func, toCharPtr( write_set.descriptorType )
        );
    } else {    // DESCRIPTOR_TYPE == VkBufferView
        vkAssert(
            write_set.descriptorType == VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER || write_set.descriptorType == VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER,
            "VkBufferView is not compatible with VkDescriptorType ", file, line, func, toCharPtr( write_set.descriptorType )
        );
    }

    __traits( getMember, meta, descriptor_array ).append( descriptor ); // evaluates to:
    // 1.) meta.image_infos.append( descriptor_image_info );
    // 2.) meta.buffer_infos.append( descriptor_buffer_info );
    // 3.) meta.texel_buffer_views.append( descriptor_buffer_view );

    // helper to store different values in the lower and upper 16 bits
    // the actual descriptorCount is stored in the lower 16 bits, see bellow
    Pack_Index_And_Count piac = write_set.descriptorCount;              // preserve original descriptorCount

    if( __traits( getMember, write_set, write_pointer ) is null ) {     // evaluates to: see bellow next expression

        // this is not safe, the data in descriptor_array might get reallocate when descriptor is appended
        // but it will be patched in updateSet( ... ) function bellow with the right address
        __traits( getMember, write_set, write_pointer ) = &__traits( getMember, meta, descriptor_array )[ $-1 ];
        // 1.) write_set.pImageInfo                     = & meta.image_infos[ $-1 ];
        // 2.) write_set.pBufferInfo                    = & meta.buffer_infos[ $-1 ];
        // 3.) write_set.pTexelBufferView               = & meta.texel_buffer_views[ $-1 ];

        // as in the addImmutableSampler() function we need to keep track of the index in
        // the immutable_samplers array to recreate the proper address in case of a reallocation
        // we take the upper 16 bits of the latest descriptor_set_layout_bindings.descriptorCount
        // ( its unlikely that we'll ever need more than 65536 immutable samplers in one set )
        piac.index = cast( ushort )( __traits( getMember, meta, descriptor_array ).length - 1 );    // setting the upper 16 bits
        // 1.index = cast( ushort )( meta.image_infos.length - 1 ).toUint;
        // 2.index = cast( ushort )( meta.buffer_infos.length - 1 ).toUint;
        // 3.index = cast( ushort )( meta.texel_buffer_views.length - 1 ).toUint;

    }
    // increase the descriptorCount of last descriptor_set_layout_bindings with the bit filter struct
    ++piac.count;
    write_set.descriptorCount = piac.descriptor_count;

    return meta;
}


/// add a (mutable) VkSampler descriptor, convenience function to create and add VkImageInfo
/// no image view and image layout are required in this case
/// Params:
///     meta = reference to a Meta_Descriptor_Update struct
///     sampler = the mutable VkSampler
/// Returns: the passed in Meta_Structure for function chaining
auto ref addSampler(
    ref Meta_Descriptor_Update  meta,
    VkSampler                   sampler,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    return meta.addImageInfo( VK_NULL_HANDLE, VK_IMAGE_LAYOUT_UNDEFINED, sampler, file, line, func );
}


/// add a VkImageInfo with specifying its members as function params to the Meta_Descriptor_Update
/// several sampler less image attachments do not require a sampler specification
/// hence a VkSample is optional
/// Params:
///     meta = reference to a Meta_Descriptor_Update struct
///     image_view = of an VkImage which should be accessed through the VkDescriptorSet
///     image_layout = layout of the image when it will be accessed in a shader
///     sampler = optional VkSampler, required for e.g. VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
/// Returns: the passed in Meta_Structure for function chaining
auto ref addImageInfo(
    ref Meta_Descriptor_Update  meta,
    VkImageView                 image_view,
    VkImageLayout               image_layout,
    VkSampler                   sampler = VK_NULL_HANDLE,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    return addDescriptorTypeUpdate!
        ( VkDescriptorImageInfo, "image_infos", "pImageInfo" )
        ( meta, VkDescriptorImageInfo( sampler, image_view, image_layout ), file, line, func );
}


/// add a VkBufferInfo with specifying its members as function params to the Meta_Descriptor_Update
/// offset and range are optional, in this case the whole buffer will be attached
/// if only offset is specified the buffer from offset till its end will be attached
/// Params:
///     meta = reference to a Meta_Descriptor_Update struct
///     buffer = to be accessed through the VkDescriptorSet
///     offset = optional offset into the buffer
///     range  = optional range of the buffer access, till end if not specified
/// Returns: the passed in Meta_Structure for function chaining
auto ref addBufferInfo(
    ref Meta_Descriptor_Update  meta,
    VkBuffer                    buffer,
    VkDeviceSize                offset = 0,
    VkDeviceSize                range = VK_WHOLE_SIZE
    ) {
    // Todo(pp): check if compatible to meta.write_descriptor_sets[ $-1 ].descriptor_type;
    // see spec 1.0.42 p. 382, pdf p. 391
    // VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
    // VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC
    return addDescriptorTypeUpdate!
        ( VkDescriptorBufferInfo, "buffer_infos", "pBufferInfo" )
        ( meta, VkDescriptorBufferInfo( buffer, offset, range ));
}


/// add a VkBufferView handle as texture or shader storage buffers
/// Params:
///     meta = reference to a Meta_Descriptor_Update struct
///     buffer_view = to access the underlying VkBuffer through the VkDescriptorSet
/// Returns: the passed in Meta_Structure for function chaining
auto ref addTexelBufferView(
    ref Meta_Descriptor_Update  meta,
    VkBufferView                buffer_view ) {
    // Todo(pp): check if compatible to meta.write_descriptor_sets[ $-1 ].descriptor_type;
    // see spec 1.0.42 p. 382, pdf p. 391
    // VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER, VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER
    return addDescriptorTypeUpdate!
        ( VkBufferView, "texel_buffer_views", "pTexelBufferView" )
        ( meta, buffer_view );
}


/// set the VkDescriptorSet which is supposed to be updated into VkWriteDescriptorSet struct
/// additionally in the case of using dynamic resource arrays the memory of the arrays
/// might have been reallocated when descriptor infos or buffer views were added
/// this means that the VkWriteDescriptorSet might point to wrong memory location
/// the pointers get properly re-connected with this function
/// Params:
///     meta = reference to a Meta_Descriptor_Update struct
///     descriptor_set = which should be updated in a later step
/// Returns: the passed in Meta_Structure for function chaining
auto ref attachSet( ref Meta_Descriptor_Update meta, VkDescriptorSet descriptor_set ) {

    foreach( ref write_set; meta.write_descriptor_sets ) {
        write_set.dstSet = descriptor_set;  // store a valid and matching descriptor set in each write struct
        Pack_Index_And_Count piac = write_set.descriptorCount;  // extract original descriptorCount and index

        // only one of the following can be not null and must be patched with a possibly reallocated pointer
        if( write_set.pImageInfo !is null ) write_set.pImageInfo = & meta.image_infos[ piac.index ];
        else if( write_set.pBufferInfo !is null ) write_set.pBufferInfo = & meta.buffer_infos[ piac.index ];
        else write_set.pTexelBufferView = & meta.texel_buffer_views[ piac.index ];

        write_set.descriptorCount = piac.count; // set the proper descriptorCount to its original value
    }
    return meta.update;
}


/// update the VkWriteDescriptorSet
/// calls solely vkUpdateDescriptorSets using the internal structures of the Meta_Descriptor_Update
///     meta = reference to a Meta_Descriptor_Update struct
/// Returns: the passed in Meta_Structure for function chaining
auto ref update( ref Meta_Descriptor_Update meta ) nothrow {
    meta.device.vkUpdateDescriptorSets(
        meta.write_descriptor_sets.length.toUint,
        meta.write_descriptor_sets.ptr, 0, null
    );  // last parameters are copy count and pointer to copies
    return meta;
}



//////////////////////////////////////////////////////////////////////////////////
// Meta_Descriptor to connect Meta_Descriptor_Layout and Meta_Descriptor_Update //
//////////////////////////////////////////////////////////////////////////////////


/// meta struct which combines the data structures and functionality of
/// Meta_Descriptor_Layout and Meta_Descriptor_Update
/// the purpose is to create and and update (initialize) a VkDescriptorSet
/// with one set of functions, without redundantly specifying same parameters
/// must be initialized with a Vulkan state struct which will be passed to
/// the wrapped meta structs
struct Meta_Descriptor {
//  mixin                               Vulkan_State_Pointer;
    Meta_Descriptor_Layout              meta_descriptor_layout;
    Meta_Descriptor_Update              meta_descriptor_update;
    alias meta_descriptor_layout        this;

    bool add_write_descriptor = false;

    // the two following statements constructor and function are necessary
    // to override the same from mixed in Vulkan_State_Pointer of the meta_descriptor_update
    this( ref Vulkan vk )               { meta_descriptor_layout.vk_ptr = meta_descriptor_update.vk_ptr = &vk; }
    auto ref opCall( ref Vulkan vk )    { meta_descriptor_layout.vk_ptr = meta_descriptor_update.vk_ptr = &vk; return this; }

    auto reset() {
        meta_descriptor_update.reset;
        return meta_descriptor_layout.reset;
    }
}


/// add a VkDescriptorSetLayoutBinding to the Meta_Descriptor
/// Parameter order is different as opposed to the Meta_Descriptor_Layout overload
/// as the descriptor_count is optional, it will be incremented automatically while editing
/// specifying a descriptor_count creates descriptors which at the corresponding locations
/// which will not be updated with any of the VkWriteDescriptorSet
/// Params:
///     meta = reference to a Meta_Descriptor struct
///     binding = index of the layout binding
///     descriptor_type  = the type of the layout binding and hence descriptor(s)
///     shader_stage_flags = shader stage access filter for this layout binding
///     descriptor_count = optional count of descriptors in this layout binding, defaults to 0
/// Returns: the passed in Meta_Structure for function chaining
auto ref addLayoutBinding(
    ref Meta_Descriptor meta,
    uint32_t            binding,
    VkDescriptorType    descriptor_type,
    VkShaderStageFlags  shader_stage_flags,
    uint32_t            descriptor_count = 0,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    // descriptor_count in this case is a starting value which will increase when using
    // Meta_Descriptor to create and update the descriptor set
    // note however, that in this case these descriptor_count descriptors will not be updated when
    // editing has finished they must be updated later on either using Meta_Descriptor_Update or manually
    // When editing immutable samplers there cannot be any offset, so that this value is reset to 0
    // descriptor_count = 0 cannot be passed to the Meta_Descriptor_Layout.addLayoutBinding function
    // hence it the descriptor_count is incremented by one for the call and decremented from
    // the added layout binding afterwards
    meta.add_write_descriptor = true;
    meta.meta_descriptor_layout     //descriptor_count must not be 0, increment it and add the layout binding
        .addLayoutBinding( binding, ++descriptor_count, descriptor_type, shader_stage_flags, file, line, func )
        .descriptor_set_layout_bindings[ $-1 ]      // access the added layout binding (last)
        .descriptorCount--;     // decrement its descriptorCount - crazy that all this works!

    // we also must decrement the descriptor types count of the current descriptor_type
    // as it was increased by one too trick the meta_descriptor_layout.addLayoutBinding overload
    --meta.meta_descriptor_layout.descriptor_types_count[ cast( size_t )descriptor_type ];
    return meta;
}


/// add an immutable VkSampler to the last VkDescriptorSetLayoutBinding
/// Params:
///     meta = reference to a Meta_Descriptor struct
///     sampler = to immutably bound to the last added layout binding
/// Returns: the passed in Meta_Structure for function chaining
auto ref addImmutableSampler(
    ref Meta_Descriptor meta,
    VkSampler           sampler,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    meta.meta_descriptor_layout.addImmutableSampler( sampler, file, line, func );
    return meta;
}


/// private template function, forwards to addDescriptorTypeUpdate, to add either
/// VkDescriptorImageInfo, VkDescriptorBufferInfo or VkDescriptorBufferInfo
/// to the Meta_Descriptor
/// Params:
///     descriptor_array = evaluates to image_infos, buffer_infos or texel_buffer_views
///     write_pointer = evaluates to pImageInfo, pBufferInfo or pTexelBufferView
///     meta = reference to a Meta_Descriptor_Layout struct
///     descriptor = VkDescriptorImageInfo, VkDescriptorBufferInfo or VkDescriptorBufferInfo
///     dst_array_element = starting index of the array element which should be updated
///     descriptor_type = the type of the corresponding layout binding and hence descriptor(s)
/// Returns: the passed in Meta_Structure for function chaining
private auto ref addDescriptorType(
    DESCRIPTOR_TYPE,
    alias descriptor_array,
    alias write_pointer
    )(
    ref Meta_Descriptor meta,
    DESCRIPTOR_TYPE descriptor,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    pragma( inline, true ); // this function should be inlined

    // shortcut to the last descriptor_set_layout_binding
    auto layout_binding = & meta.descriptor_set_layout_bindings[ $-1 ];

    // A write descriptor should be added only in this function
    // and only if the last command was to add a layout binding
    if( meta.add_write_descriptor ) {
        meta.add_write_descriptor = false;
        meta.meta_descriptor_update.addBindingUpdate( layout_binding.binding, 0, layout_binding.descriptorType );
    }

    ++meta.descriptor_types_count[ cast( size_t )layout_binding.descriptorType ];
    ++layout_binding.descriptorCount;

    addDescriptorTypeUpdate!
        ( DESCRIPTOR_TYPE, descriptor_array, write_pointer )
        ( meta.meta_descriptor_update, descriptor, file, line, func );
    return meta;
}


/// add a (mutable) VkSampler descriptor, convenience function to create and add VkImageInfo
/// no image view and image layout are required in this case
/// Params:
///     meta = reference to a Meta_Descriptor struct
///     sampler = the mutable VkSampler
/// Returns: the passed in Meta_Structure for function chaining
auto ref addSampler(
    ref Meta_Descriptor meta,
    VkSampler           sampler,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    meta.addImageInfo(
        VK_NULL_HANDLE, VK_IMAGE_LAYOUT_UNDEFINED, sampler, file, line, func );
    return meta;
}


/// add a VkImageInfo with specifying its members as function params to the Meta_Descriptor
/// several sampler less image attachments do not require a sampler specification
/// hence a VkSample is optional
/// Params:
///     meta = reference to a Meta_Descriptor struct
///     image_view = of an VkImage which should be accessed through the VkDescriptorSet
///     image_layout = layout of the image when it will be accessed in a shader
///     sampler = optional VkSampler, required for e.g. VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
/// Returns: the passed in Meta_Structure for function chaining
auto ref addImageInfo(
    ref Meta_Descriptor meta,
    VkImageView         image_view,
    VkImageLayout       image_layout,
    VkSampler           sampler = VK_NULL_HANDLE,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    addDescriptorType!
        ( VkDescriptorImageInfo, "image_infos", "pImageInfo" )
        ( meta, VkDescriptorImageInfo( sampler, image_view, image_layout ), file, line, func );
    return meta;
}


/// add a VkBufferInfo with specifying its members as function params to the Meta_Descriptor
/// offset and range are optional, in this case the whole buffer will be attached
/// if only offset is specified the buffer from offset till its end will be attached
/// Params:
///     meta = reference to a Meta_Descriptor struct
///     buffer = to be accessed through the VkDescriptorSet
///     offset = optional offset into the buffer
///     range  = optional range of the buffer access, till end if not specified
/// Returns: the passed in Meta_Structure for function chaining
auto ref addBufferInfo(
    ref Meta_Descriptor meta,
    VkBuffer            buffer,
    VkDeviceSize        offset = 0,
    VkDeviceSize        range = VK_WHOLE_SIZE,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    // Todo(pp): check if compatible to meta.write_descriptor_sets[ $-1 ].descriptor_type;
    // see spec 1.0.42 p. 382, pdf p. 391
    // VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
    // VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC
    addDescriptorType!
        ( VkDescriptorBufferInfo, "buffer_infos", "pBufferInfo" )
        ( meta, VkDescriptorBufferInfo( buffer, offset, range ), file, line, func );
    return meta;
}


/// add a VkBufferView handle as texture or shader storage buffers
/// Params:
///     meta = reference to a Meta_Descriptor struct
///     buffer_view = to access the underlying VkBuffer through the VkDescriptorSet
/// Returns: the passed in Meta_Structure for function chaining
auto ref addTexelBufferView(
    ref Meta_Descriptor meta,
    VkBufferView        buffer_view,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    // Todo(pp): check if compatible to meta.write_descriptor_sets[ $-1 ].descriptor_type;
    // see spec 1.0.42 p. 382, pdf p. 391
    // VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER, VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER
    addDescriptorType!
        ( VkBufferView, "texel_buffer_views", "pTexelBufferView" )
        ( meta, buffer_view, file, line, func );
    return meta;
}


/// construct the managed Vulkan objects, convenience function
/// calls Meta_Descriptor_Layout allocateSet() and Meta_Descriptor_Layout attachSet()
/// Params:
///     meta = reference to a Meta_Descriptor struct
///     descriptor_pool_create_flags = = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
/// Returns: the passed in Meta_Structure for function chaining
auto ref construct(
    ref Meta_Descriptor         meta,
    VkDescriptorPoolCreateFlags descriptor_pool_create_flags = 0,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    meta.meta_descriptor_layout.allocateSet( descriptor_pool_create_flags, file, line, func );
    meta.meta_descriptor_update.attachSet( meta.descriptor_set );
    return meta;
}

/// construct the managed Vulkan objects, convenience function
/// calls Meta_Meta_Descriptor_Layout createSetLayout() with param set_layout_create_flags
/// Meta_Descriptor_Layout allocateSet() and Meta_Descriptor_Layout attachSet()
/// Params:
///     meta = reference to a Meta_Descriptor struct
///     set_layout_create_flags = only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
///     descriptor_pool_create_flags = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
/// Returns: the passed in Meta_Structure for function chaining
auto ref construct(
    ref Meta_Descriptor                 meta,
    VkDescriptorSetLayoutCreateFlags    set_layout_create_flags,
    VkDescriptorPoolCreateFlags         descriptor_pool_create_flags = 0,
    string                              file = __FILE__,
    size_t                              line = __LINE__,
    string                              func = __FUNCTION__
    ) {
    meta.meta_descriptor_layout
        .createSetLayout( set_layout_create_flags, file, line, func )
        .allocateSet( descriptor_pool_create_flags, file, line, func );
    meta.meta_descriptor_update.attachSet( meta.descriptor_set );
    return meta;
}

/// construct the managed Vulkan objects, convenience function
/// calls Meta_Meta_Descriptor_Layout createSetLayout() with param set_layout_create_flags
/// Meta_Descriptor_Layout allocateSet() with param descriptor_pool and
/// Meta_Descriptor_Layout attachSet()
/// Params:
///     meta = reference to a Meta_Descriptor struct
///     descriptor_pool = external VkDescriptorPool from which the descriptors will be allocated
///     set_layout_create_flags = optional, only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
/// Returns: the passed in Meta_Structure for function chaining
auto ref construct(
    ref Meta_Descriptor                 meta,
    VkDescriptorPool                    descriptor_pool,
    VkDescriptorSetLayoutCreateFlags    set_layout_create_flags = 0,
    string                              file = __FILE__,
    size_t                              line = __LINE__,
    string                              func = __FUNCTION__
    ) {
    meta.meta_descriptor_layout
        .createSetLayout( set_layout_create_flags, file, line, func )
        .allocateSet( descriptor_pool, file, line, func );
    meta.meta_descriptor_update.attachSet( meta.descriptor_set );
    return meta;
}



/// private struct to help store count of immutable samplers and starting index into immutable_samplers array
private struct Pack_Index_And_Count {
    this( uint32_t dc ) { descriptor_count = dc; }
    union {
        uint32_t descriptor_count;
        struct {
            version( BigEndian )    uint16_t index, count;  // consider endianness
            else                    uint16_t count, index;
        }
    }
}


/// private function to convert an
private const( char )* toCharPtr( VkDescriptorType vkDescriptorType ) nothrow @nogc {
    switch( vkDescriptorType ) {
        case VK_DESCRIPTOR_TYPE_SAMPLER                 : return "VK_DESCRIPTOR_TYPE_SAMPLER";
        case VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER  : return "VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER";
        case VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE           : return "VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE";
        case VK_DESCRIPTOR_TYPE_STORAGE_IMAGE           : return "VK_DESCRIPTOR_TYPE_STORAGE_IMAGE";
        case VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER    : return "VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER";
        case VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER    : return "VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER";
        case VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER          : return "VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER";
        case VK_DESCRIPTOR_TYPE_STORAGE_BUFFER          : return "VK_DESCRIPTOR_TYPE_STORAGE_BUFFER";
        case VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC  : return "VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC";
        case VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC  : return "VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC";
        case VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT        : return "VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT";
        default                                         : return "UNKNOWN_RESULT";
    }
}