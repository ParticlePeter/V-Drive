module vdrive.descriptor;

import erupted;

import vdrive.util;
import vdrive.state;

debug import core.stdc.stdio : printf;


nothrow @nogc:


/////////////////////
// Descriptor Pool //
/////////////////////



/// create a one descriptor type VkDescriptorPool
/// the max_descriptor_sets parameter is by default set to one it has been suggested ( e.g. GDC2016/17 )
/// to use only one huge descriptor set for all shader module
/// Params:
///     vk = reference to a VulkanState struct
///     descriptor_type = type of each descriptor which can be allocated from m_descriptor_pool
///     descriptor_count = count of the descriptors which can be allocated from m_descriptor_pool
///     max_descriptor_sets = optional ( default = 1 ) max descriptor sets which can be created from the descriptors
///     create_flags = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
/// Returns: VkDescriptorPool
auto createDescriptorPool(
    ref Vulkan          vk,
    VkDescriptorType    descriptor_type,            // specifies the only descriptor type which can be allocated from the m_descriptor_pool
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

    VkDescriptorPoolCreateInfo pool_ci = {
        flags           : create_flags,
        maxSets         : max_sets,
        poolSizeCount   : descriptor_pool_sizes.length.toUint,
        pPoolSizes      : descriptor_pool_sizes.ptr,
    };

    VkDescriptorPool descriptor_pool;
    vk.device.vkCreateDescriptorPool( & pool_ci, vk.allocator, & descriptor_pool ).vkAssert( null, file, line, func );
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

    const VkDescriptorSetLayoutBinding[1] set_layout_bindings = [
        VkDescriptorSetLayoutBinding( binding, descriptor_type, descriptor_count, shader_stage_flags, immutable_samplers )
    ];
    return vk.createSetLayout( set_layout_bindings, 0, file, line, func );
}


/// create VkDescriptorSetLayout from one VkDescriptorSetLayoutBinding
/// parameters are the same as those of a VkDescriptorSetLayoutBinding but missing immutable_samplers
/// instead set_layout_cf ( _create_flags ) for the set layout is provided
/// in the case of one layout binding set layout immutable samplers and
/// VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR are mutually exclusive
/// internally one VkDescriptorSetLayoutBinding is created and passed to vkCreateDescriptorSetLayout
/// Params:
///     vk = reference to a VulkanState struct
///     binding = binding index of the layout
///     descriptor_count = count of the descriptors in case of an array of descriptors
///     shader_stage_flags = shader stages where the descriptor can be used
///     set_layout_cf = only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
/// Returns: VkDescriptorSetLayout
auto createSetLayout(
    ref Vulkan          vk,
    uint32_t            binding,
    VkDescriptorType    descriptor_type,
    uint32_t            descriptor_count,
    VkShaderStageFlags  shader_stage_flags,
    VkDescriptorSetLayoutCreateFlags set_layout_cf,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) {

    const VkDescriptorSetLayoutBinding[1] set_layout_bindings = [
        VkDescriptorSetLayoutBinding( binding, descriptor_type, descriptor_count, shader_stage_flags, null ) ];
    return vk.createSetLayout( set_layout_bindings, set_layout_cf, file, line, func );
}


/// create a VkDescriptorSetLayout from several VkDescriptorSetLayoutBinding(s)
/// Params:
///     vk = reference to a VulkanState struct
///     set_layout_bindings = to specify the multi binding set layout
///     set_layout_cf = only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
/// Returns: VkDescriptorSetLayout
auto createSetLayout(
    ref Vulkan                              vk,
    const VkDescriptorSetLayoutBinding[]    set_layout_bindings,
    VkDescriptorSetLayoutCreateFlags        set_layout_cf = 0,
    string                                  file = __FILE__,
    size_t                                  line = __LINE__,
    string                                  func = __FUNCTION__

    ) {

    VkDescriptorSetLayoutCreateInfo descriptor_set_layout_ci = {
        flags           : set_layout_cf,
        bindingCount    : set_layout_bindings.length.toUint,
        pBindings       : set_layout_bindings.ptr,
    };

    VkDescriptorSetLayout descriptor_set_layout;
    vk.device.vkCreateDescriptorSetLayout(
        & descriptor_set_layout_ci,
        vk.allocator, & descriptor_set_layout ).vkAssert( null, file, line, func );
    return descriptor_set_layout;
}


/// allocate a VkDescriptorSet from a VkDescriptorPool with given VkDescriptorSetLayout
/// Params:
///     vk = reference to a VulkanState struct
///     descriptor_pool = the m_descriptor_pool from which the descriptors of the set will be allocated
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

    VkDescriptorSetAllocateInfo descriptor_ai = {
        descriptorPool      : descriptor_pool,
        descriptorSetCount  : 1,
        pSetLayouts         : & descriptor_set_layout,
    };

    VkDescriptorSet descriptor_set;
    vk.device
        .vkAllocateDescriptorSets( & descriptor_ai, & descriptor_set )
        .vkAssert( null, file, line, func );
    return descriptor_set;
}


/// allocate multiple VkDescriptorSet(s) from a VkDescriptorPool with given VkDescriptorSetLayout(s)
/// Params:
///     vk = reference to a VulkanState struct
///     descriptor_pool = the m_descriptor_pool from which the descriptors of the set will be allocated
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

    VkDescriptorSetAllocateInfo descriptor_ai = {
        descriptorPool      : descriptor_pool,
        descriptorSetCount  : descriptor_sets_layouts.length.toUint,
        pSetLayouts         : descriptor_sets_layouts.ptr,
    };
    auto descriptor_sets = sizedArray!VkDescriptorSet( descriptor_sets_layouts.length );
    vk.device
        .vkAllocateDescriptorSets( & descriptor_ai, descriptor_sets.ptr )
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
    VkDescriptorPool        descriptor_pool;        alias pool       = descriptor_pool;
    VkDescriptorSetLayout   descriptor_set_layout;  alias set_layout = descriptor_set_layout;
    VkDescriptorSet         descriptor_set;         alias set        = descriptor_set;
}


/// destroy all wrapped Vulkan objects
/// Params:
///     vk = Vulkan state struct holding the device through which these resources were created
///     core = the wrapped VkDescriptorPool ( with it the VkDescriptorSet ) and the VkDescriptorSetLayout to destroy
/// Returns: the passed in Meta_Structure for function chaining
void destroy( ref Vulkan vk, ref Core_Descriptor core ) {
    vk.destroyHandle( core.descriptor_set_layout ); // no nice syntax, vdrive.state.destroy overloads
    vk.destroyHandle( core.descriptor_pool );       // get confused with this one in the module scope
    //core.descriptor_set_layout = VK_NULL_HANDLE;          // handled by the destroy overload
    //core.descriptor_pool = VK_NULL_HANDLE;                // handled by the destroy overload
    core.descriptor_set = VK_NULL_HANDLE;
}


/// meta struct to configure a VkDescriptorSetLayout and allocate a
/// VkDescriptorSet from an external or internally managed VkDescriptorPool
/// dynamic arrays exist to add VkDescriptorSetLayoutBinding and immutable VkSampler
/// must be initialized with a Vulkan state struct
alias Meta_Descriptor_Layout = Meta_Descriptor_Layout_T!();
struct Meta_Descriptor_Layout_T(

    int32_t set_layout_binding_count    = int32_t.max,
    int32_t immutable_sampler_count     = int32_t.max,

    ) {

    nothrow @nogc:
    mixin                               Vulkan_State_Pointer;
    private VkDescriptorPool            m_descriptor_pool = VK_NULL_HANDLE;          // this must not be directly set able other than from module
    auto descriptor_pool()              { return m_descriptor_pool; }                // use getter function to get a copy
    VkDescriptorSetLayout               descriptor_set_layout;
    VkDescriptorSet                     descriptor_set;

    D_OR_S_ARRAY!( VkDescriptorSetLayoutBinding, set_layout_binding_count ) set_layout_bindings;            // the set layout bindings of the resulting set
    D_OR_S_ARRAY!( VkSampler,                    immutable_sampler_count  ) immutable_samplers;             // slices of this member can be associated with any layout binding


    /// get minimal config for internal D_OR_S_ARRAY
    auto static_config() {
        size_t[2] result;
        result[0] = set_layout_bindings.length;
        result[1] = immutable_samplers.length;
        return result;
    }


    /// destroy the VkDescriptorLayout and, if internal, the VkDescriptorPool
    void destroyResources() {
        vk.destroyHandle( descriptor_set_layout );
        if( m_descriptor_pool != VK_NULL_HANDLE ) vk.destroyHandle( m_descriptor_pool );
    }


    /// reset all internal data and return wrapped Vulkan objects
    /// VkDescriptorPool, VkDescriptorSet and VkDescriptorSetLayout
    auto reset() {
        Core_Descriptor result = { m_descriptor_pool, descriptor_set_layout, descriptor_set };
        set_layout_bindings.clear;
        immutable_samplers.clear;
        descriptor_set_layout = VK_NULL_HANDLE;
        descriptor_set = VK_NULL_HANDLE;
        m_descriptor_pool = VK_NULL_HANDLE;
        return result;
    }


    /// extract core descriptor elements VkDescriptorPool, VkDescriptorSet and VkDescriptorSetLayout
    /// without resetting the internal data structures
    auto extractCore() {
        return Core_Descriptor( m_descriptor_pool, descriptor_set_layout, descriptor_set );
    }


    /// add a VkDescriptorSetLayoutBinding to the Meta_Descriptor_Layout
    /// Params:
    ///     meta = reference to a Meta_Descriptor_Layout struct
    ///     binding = index of the layout binding
    ///     descriptor_count = count of descriptors in this layout binding, if set to 0 this binding entry
    ///         is reserved and the resource must not be accessed from any stage via this binding within
    ///         any pipeline using the set layout (see Spec on struct VkDescriptorSetLayoutBinding)
    ///     descriptor_type  = the type of the layout binding and hence descriptor(s)
    ///     shader_stage_flags = shader stage access filter for this layout binding
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addLayoutBinding(
        uint32_t            binding,
        VkDescriptorType    descriptor_type,
        VkShaderStageFlags  shader_stage_flags,
        uint32_t            descriptor_count,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        VkDescriptorSetLayoutBinding layout_binding = {
            binding             : binding,
            descriptorType      : descriptor_type,
            descriptorCount     : descriptor_count,
            stageFlags          : shader_stage_flags,
            pImmutableSamplers  : null,
        };
        set_layout_bindings.append( layout_binding, file, line, func );
        return this;
    }

    /// convenience func
    auto ref addSamplerBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_SAMPLER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addSamplerImageBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addSampledImageBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addStorageImageBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addUniformTexelBufferBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addStorageTexelBufferBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addUniformBufferBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addStorageBufferBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addUniformBufferDynamicBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addStorageBufferDynamicBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addInputAttachmentBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT, shader_stage_flags, descriptor_count, file, line, func );
    }


    /// add a VkDescriptorSetLayoutBinding to the Meta_Descriptor_Layout
    /// to configure immutable samplers, consequently this layout will only accept
    /// descriptor_type VK_DESCRIPTOR_TYPE_SAMPLER or VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
    /// Params:
    ///     meta = reference to a Meta_Descriptor_Layout struct
    ///     binding = index of the layout binding
    ///     descriptor_count = count of descriptors in this layout binding, must be > 0
    ///     descriptor_type  = the type of the layout binding and hence descriptor(s)
    ///                        allowed is only VK_DESCRIPTOR_TYPE_SAMPLER and VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
    ///     shader_stage_flags = shader stage access filter for this layout binding
    /// Returns: the passed in Meta_Structure for function chaining
    private auto ref addImmutableBinding(
        uint32_t            binding,
        VkDescriptorType    descriptor_type,
        VkShaderStageFlags  shader_stage_flags,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        vkAssert( descriptor_type == VK_DESCRIPTOR_TYPE_SAMPLER || descriptor_type == VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            "param descriptor_type of addImmutableBinding() must VK_DESCRIPTOR_TYPE_SAMPLER or VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER",
            file, line, func );

        // first call the normal addLayoutBinding()
        addLayoutBinding( binding, descriptor_type, shader_stage_flags, 0, file, line, func );

        // than mark the added VkDescriptorSetLayoutBinding accepting only immutable samplers
        // we do this by setting the pImmutableSamplers field to an arbitrary address, not null.
        // Later when we actually create the VkDescriptorSetLayout we will attach the proper
        // Meta_Descriptor_Layout.immutable_samplers to that field (anyway)
        auto layout_binding = & set_layout_bindings[ $-1 ];                     // grab the address of recently added layout binding
        layout_binding.pImmutableSamplers = cast( VkSampler* )layout_binding;   // attach the address of its latest added immuatable sampler
        return this;
    }

    /// convenience func
    auto ref addImmutableSamplerImageBinding(
        uint32_t            binding,
        VkShaderStageFlags  shader_stage_flags,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__
        ) {
        return addImmutableBinding( binding, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, shader_stage_flags, file, line, func );
    }

    /// convenience func
    auto ref addImmutableSamplerBinding(
        uint32_t            binding,
        VkShaderStageFlags  shader_stage_flags,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        return addImmutableBinding( binding, VK_DESCRIPTOR_TYPE_SAMPLER, shader_stage_flags, file, line, func );
    }

    /// add an immutable VkSampler to the last VkDescriptorSetLayoutBinding
    /// Params:
    ///     meta = reference to a Meta_Descriptor_Layout struct
    ///     sampler = to immutably bound to the last added layout binding
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addImmutableSampler(
        VkSampler                   sampler,
        string                      file = __FILE__,
        size_t                      line = __LINE__,
        string                      func = __FUNCTION__

        ) {

        // enforce that a layout binding has been added so far
        vkAssert( !set_layout_bindings.empty,
            "addLayoutBinding() must have been called first",
            file, line, func );

        // append the immutable sampler
        immutable_samplers.append( sampler, file, line, func );

        // shortcut to the last set_layout_bindings
        auto layout_binding = & set_layout_bindings[ $-1 ];

        // helper to store different values in the lower and upper 16 bits
        // the actual descriptorCount is stored in the lower 16 bits, see bellow
        Pack_Index_And_Count piac = layout_binding.descriptorCount;         // preserve index and count
        ++piac.count;

        if( layout_binding.pImmutableSamplers == cast( VkSampler* )layout_binding ) {

            // this is not safe, the data in descriptor_array might get reallocate when descriptor is appended
            // but it will be patched in createSetLayout( ... ) function bellow with the right address
            layout_binding.pImmutableSamplers = immutable_samplers.ptr_back;

            // as in the general addDescriptorType() function we need to keep track of the index in
            // the immutable_samplers array to recreate the proper address in case of a reallocation
            // we take the upper 16 bits of the latest set_layout_bindings.descriptorCount
            // ( its unlikely that we'll ever need more than 65536 immutable samplers in one set )
            piac.index = cast( ushort )( immutable_samplers.length - 1 );  // setting the upper 16 bits
        }

        // do not increment the count, the requested count was specified with Meta_Descriptor_Layout.addImmutableBinding
        layout_binding.descriptorCount = piac.descriptor_count;             // assigning back to the original member
        return this;
    }


    /// create the VkDescriptorSetLayout and store it as a member of the Meta_Descriptor_Layout struct
    /// from the so far specified descriptor set layout bindings and optional immutable samplers
    /// Params:
    ///     meta = reference to a Meta_Descriptor_Layout struct
    ///     set_layout_cf = optional, only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref createSetLayout(
        VkDescriptorSetLayoutCreateFlags    set_layout_cf = 0,
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
        foreach( ref layout_binding; set_layout_bindings ) {
            if( layout_binding.pImmutableSamplers !is null ) {
                Pack_Index_And_Count piac = layout_binding.descriptorCount;
                layout_binding.pImmutableSamplers = & immutable_samplers[ piac.index ];
                layout_binding.descriptorCount = piac.count;
            }
        }

        descriptor_set_layout = vk.createSetLayout( set_layout_bindings.data, set_layout_cf, file, line, func );
        return this;
    }


    /// allocate the VkDescriptorSet stored in descriptor_set member of Meta_Descriptor_Layout
    /// from the internal Meta_Descriptor_Layout VkDescriptorPool with sufficient descriptor memory
    /// created before allocating in this function
    /// Params:
    ///     meta = reference to a Meta_Descriptor_Layout struct
    ///     descriptor_pool_cf = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref allocateSet(
        VkDescriptorPoolCreateFlags descriptor_pool_cf = 0,
        string                      file = __FILE__,
        size_t                      line = __LINE__,
        string                      func = __FUNCTION__

        ) {

        // The count of type of all the required descriptors are stored in the recorded layout bindings.
        // We would like to create a descriptor pool with the minimum amount of required memory for these descriptors.
        // To achieves this we undergo two transformations of the recorded layout bindings:
        // 1.)  we loop through all the bindings and extract its descriptor count. We extract it as we have stored
        //      the count and index of each required descriptor Packed in the member of count VkDescriptorSetLayoutBinding.
        //      We use a static uint32_t array of VK_DESCRIPTOR_TYPE_RANGE_SIZE to store the total count of each required
        //      descriptor type. As not all descriptor types are required this creates a possible sparse array
        uint32_t [ VK_DESCRIPTOR_TYPE_RANGE_SIZE ] descriptor_types_count;
        foreach( ref layout_binding; set_layout_bindings )
            descriptor_types_count[ layout_binding.descriptorType ] += Pack_Index_And_Count( layout_binding.descriptorCount ).count;

        // 2.)  To create the VkDescriptorPool we need an array of VkDescriptorPoolSize with only the actually required descriptors.
        //      For that we use an static array of that type VkDescriptorPoolSize with size of VK_DESCRIPTOR_TYPE_RANGE_SIZE. As this
        //      is the maximum count of descriptor types possible. We might not require all the entries but will use them up from start
        //      and also count how many descriptor types are used.
        //      We iterate our descriptor_size_count, while each index corresponds to a VkDescriptorType enum. Each index/type having
        //      a grater value than zero will be recorded in the next VkDescriptorPoolSize.
        size_t pool_size_index;
        VkDescriptorPoolSize[ VK_DESCRIPTOR_TYPE_RANGE_SIZE ] descriptor_pool_sizes;
        foreach( descriptor_type, descriptor_count; descriptor_types_count ) {
            if( descriptor_count > 0 ) {
                descriptor_pool_sizes[ pool_size_index ].type = cast( VkDescriptorType )descriptor_type;
                descriptor_pool_sizes[ pool_size_index ].descriptorCount = descriptor_count;
                ++pool_size_index;
                //printf( "%d : %s\n", descriptor_count, toCharPtr( cast( VkDescriptorType )descriptor_type ));
            }
        }

        // create the descriptor m_descriptor_pool, pool_size_index now represents the count of used m_descriptor_pool sizes
        m_descriptor_pool = vk.createDescriptorPool( descriptor_pool_sizes[ 0 .. pool_size_index ], 1, descriptor_pool_cf );

        // forward to next overload
        return allocateSet( descriptor_pool, file, line, func );
    }


    /// allocate the VkDescriptorSet stored in descriptor_set member of Meta_Descriptor_Layout
    /// from an external VkDescriptorPool, must have sufficient descriptor memory
    /// Params:
    ///     meta = reference to a Meta_Descriptor_Layout struct
    ///     descriptor_pool_cf = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref allocateSet(
        VkDescriptorPool            descriptor_pool,
        string                      file = __FILE__,
        size_t                      line = __LINE__,
        string                      func = __FUNCTION__

        ) {

        // call createSetLayout() if the descriptor_set_layout has not been called so far
        // if it is necessary to pass a VkDescriptorSetLayoutCreateFlags to the corresponding create info
        // createSetLayout must be called manually beforehand
        if( descriptor_set_layout == VK_NULL_HANDLE )
            createSetLayout( 0, file, line, func );

        // allocate the VkDescriptorSet
        descriptor_set = vk.allocateSet( descriptor_pool, descriptor_set_layout, file, line, func );

        // free temporary memory which is not required after the VkDescriptorSet has been allocated
        set_layout_bindings.clear;
        immutable_samplers.clear;
        return this;
    }
}



////////////////////////////
// Descriptor_Update //
////////////////////////////



/// meta struct to configure an dynamic array of VkWriteDescriptorSet to update a VkDescriptorSet
/// additional arrays exist to add VkDescriptorImageInfo, VkDescriptorBufferInfo and VkDescriptorBufferInfo
/// several versions of this struct (partially) updating one VkDescriptorSet are meant to coexist
/// must be initialized with a Vulkan state struct
alias Descriptor_Update = Descriptor_Update_T!();
struct Descriptor_Update_T(
    int32_t write_set_count         = int32_t.max,
    int32_t image_info_count        = int32_t.max,
    int32_t buffer_info_count       = int32_t.max,
    int32_t texel_buffer_view_count = int32_t.max,

    ) {

    nothrow @nogc:
    D_OR_S_ARRAY!( VkWriteDescriptorSet,    write_set_count )       write_descriptor_sets;          // write descriptor sets in case we want to update the set
    D_OR_S_ARRAY!( VkDescriptorImageInfo,   image_info_count )      image_infos;                    // slices of these three members ...
    D_OR_S_ARRAY!( VkDescriptorBufferInfo,  buffer_info_count )     buffer_infos;                   // ... can be associated with ...
    D_OR_S_ARRAY!( VkBufferView,      texel_buffer_view_count )     texel_buffer_views;             // ... any write_descriptor_set


    /// get minimal config for internal D_OR_S_ARRAY
    auto static_config() {
        size_t[4] result;
        result[0] = write_descriptor_sets.length;
        result[1] = image_infos.length;
        result[2] = buffer_infos.length;
        result[3] = texel_buffer_views.length;
        return result;
    }


    /// reset all internal data, no date to be returned
    void reset() {
        write_descriptor_sets.clear;
        image_infos.clear;
        buffer_infos.clear;
        texel_buffer_views.clear;
    }


    /// add a VkWriteDescriptorSet to the Descriptor_Update
    /// Params:
    ///     meta = reference to a Descriptor_Update struct
    ///     binding = index of the corresponding layout binding
    ///     descriptor_type  = the type of the corresponding layout binding and hence descriptor(s)
    ///     dst_array_element = optional starting index of the array element which should be updated, defaults to 0
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addBindingUpdate(
        uint32_t                    binding,
        VkDescriptorType            descriptor_type,
        uint32_t                    dst_array_element = 0,
        string                      file = __FILE__,
        size_t                      line = __LINE__,
        string                      func = __FUNCTION__

        ) {

        VkWriteDescriptorSet write_set = {
            dstBinding          : binding,
            dstArrayElement     : dst_array_element,
            descriptorCount     : 0,
            descriptorType      : descriptor_type,
            pImageInfo          : null,
            pBufferInfo         : null,
            pTexelBufferView    : null,
        };
        write_descriptor_sets.append( write_set, file, line, func );
        return this;
    }

    /// convenience func
    auto ref addSamplerUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_SAMPLER, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addSamplerImageUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addSampledImageUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addStorageImageUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addUniformTexelBufferUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addStorageTexelBufferUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addUniformBufferUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addStorageBufferUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addUniformBufferDynamicUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addStorageBufferDynamicUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC, dst_array_element, file, line, func );
    }

    /// convenience func
    auto ref addInputAttachmentUpdate( uint32_t binding, uint32_t dst_array_element = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addBindingUpdate( binding, VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT, dst_array_element, file, line, func );
    }


    /// private template function to add either
    /// VkDescriptorImageInfo, VkDescriptorBufferInfo or VkDescriptorBufferInfo
    /// to the Descriptor_Update
    /// Params:
    ///     descriptor_array = evaluates to image_infos, buffer_infos or texel_buffer_views
    ///     write_pointer = evaluates to pImageInfo, pBufferInfo or pTexelBufferView
    ///     meta = reference to a Descriptor_Update struct
    ///     descriptor = VkDescriptorImageInfo, VkDescriptorBufferInfo or VkDescriptorBufferInfo
    ///     dst_array_element = starting index of the array element which should be updated
    ///     descriptor_type = the type of the corresponding layout binding and hence descriptor(s)
    /// Returns: the passed in Meta_Structure for function chaining
    private auto ref addDescriptorTypeUpdate( Descriptor_T )( // , alias descriptor_array, alias write_pointer : last two template arguments not needed, keep as note
        Descriptor_T                descriptor,
        string                      file = __FILE__,
        size_t                      line = __LINE__,
        string                      func = __FUNCTION__

        ) if( isDescriptor!Descriptor_T ) {

        //pragma( inline, true ); // this function should be inlined

        // shortcut to the last write_descriptor_sets
        auto write_set = & write_descriptor_sets[ $-1 ];

        // add proper VkImageInfo usage checks here
        // source of checks: Spec 1.0.48, section 13.2.4 (one of Valid usage tables) p.387, pdf p.396


        static if( is( Descriptor_T == VkDescriptorImageInfo )) {
            const( char )* msg( int code ) pure nothrow @nogc {
                switch( code ) {
                    case 0 : return "VkImageView is VK_NULL_HANDLE and VkSampler is VK_NULL_HANDLE";
                    case 1 : return "VkImageView is VK_NULL_HANDLE and VkSampler is not VK_NULL_HANDLE";
                    case 2 : return "VkImageView is not VK_NULL_HANDLE and VkSampler is VK_NULL_HANDLE";
                    case 3 : return "VkImageView is VK_NULL_HANDLE";
                    case 4 : return "VkImageView is not VK_NULL_HANDLE";
                    case 5 : return "VkSampler is VK_NULL_HANDLE";
                    case 6 : return "VkSampler is not VK_NULL_HANDLE";
                    default: return null;
                }
            }
            switch( write_set.descriptorType ) {
                case VK_DESCRIPTOR_TYPE_SAMPLER : vkAssert( descriptor.sampler != VK_NULL_HANDLE && descriptor.imageView == VK_NULL_HANDLE,
                    descriptor.sampler == VK_NULL_HANDLE && descriptor.imageView != VK_NULL_HANDLE
                        ? msg( 2 ) : descriptor.sampler == VK_NULL_HANDLE ? msg( 5 ) : descriptor.imageView != VK_NULL_HANDLE ? msg( 4 ) : null,
                    file, line, func, "\n             : VK_DESCRIPTOR_TYPE_SAMPLER requires a VkSampler without VkImageView" ); break;

                case VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER : vkAssert( /*descriptor.sampler != VK_NULL_HANDLE && */ descriptor.imageView != VK_NULL_HANDLE,  // if an immutable sampler was created at this binding we do not need to pass the sampler here again
                    descriptor.imageView == VK_NULL_HANDLE ? msg( 3 ) : null,
                    file, line, func, "\n             : VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER requires a VkImageView and VkSampler" ); break;

                case VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE : vkAssert( descriptor.sampler == VK_NULL_HANDLE && descriptor.imageView != VK_NULL_HANDLE,
                    descriptor.sampler != VK_NULL_HANDLE && descriptor.imageView == VK_NULL_HANDLE
                        ? msg( 1 ) : descriptor.sampler != VK_NULL_HANDLE ? msg( 6 ) : descriptor.imageView == VK_NULL_HANDLE ? msg( 3 ) : null,
                    file, line, func, "\n             : VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE requires a VkImageView without VkSampler" ); break;

                case VK_DESCRIPTOR_TYPE_STORAGE_IMAGE : vkAssert( descriptor.sampler == VK_NULL_HANDLE && descriptor.imageView != VK_NULL_HANDLE,
                    descriptor.sampler != VK_NULL_HANDLE && descriptor.imageView == VK_NULL_HANDLE
                        ? msg( 1 ) : descriptor.sampler != VK_NULL_HANDLE ? msg( 6 ) : descriptor.imageView == VK_NULL_HANDLE ? msg( 3 ) : null,
                    file, line, func, "\n             : VK_DESCRIPTOR_TYPE_STORAGE_IMAGE requires a VkImageView without VkSampler" ); break;

                case VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT : vkAssert( descriptor.sampler == VK_NULL_HANDLE && descriptor.imageView != VK_NULL_HANDLE,
                    descriptor.sampler != VK_NULL_HANDLE && descriptor.imageView == VK_NULL_HANDLE
                        ? msg( 1 ) : descriptor.sampler != VK_NULL_HANDLE ? msg( 6 ) : descriptor.imageView == VK_NULL_HANDLE ? msg( 3 ) : null,
                    file, line, func, "\n             : VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT requires a VkImageView without VkSampler" ); break;

                default : vkAssert( false,
                    "VkDescriptorImageInfo is not compatible with VkDescriptorType ", file, line, func, toCharPtr( write_set.descriptorType )); break;
            }
        } else static if( is( Descriptor_T == VkDescriptorBufferInfo )) {
            vkAssert(
                write_set.descriptorType == VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER || write_set.descriptorType == VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC
            ||  write_set.descriptorType == VK_DESCRIPTOR_TYPE_STORAGE_BUFFER || write_set.descriptorType == VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC,
                "VkDescriptorBufferInfo is not compatible with VkDescriptorType ", file, line, func, toCharPtr( write_set.descriptorType )
            );
        } else {    // Descriptor_T == VkBufferView
            vkAssert(
                write_set.descriptorType == VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER || write_set.descriptorType == VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER,
                "VkBufferView is not compatible with VkDescriptorType ", file, line, func, toCharPtr( write_set.descriptorType )
            );
        }

        // helper to store different values in the lower and upper 16 bits
        // the actual descriptorCount is stored in the lower 16 bits, see bellow
        Pack_Index_And_Count piac = write_set.descriptorCount;              // preserve original descriptorCount

        // first call of any static if: this is not safe, the data in descriptor_array might get reallocate when descriptor is appended
        // but it will be patched in updateSet( ... ) function bellow with the right address
        //
        // second call of any static if: as in the Meta_Descriptor_Layout.addSampler() overload we need to keep track of the index
        // in the immutable_samplers array to recreate the proper address in case of a reallocation
        // we take the upper 16 bits of the latest set_layout_bindings.descriptorCount
        // ( its unlikely that we'll ever need more than 65536 immutable samplers in one set )
        static if( is( Descriptor_T == VkDescriptorImageInfo )) {
            image_infos.append( descriptor );
            if( write_set.pImageInfo is null ) {
                write_set.pImageInfo = image_infos.ptr_back;
                piac.index = cast( ushort )( image_infos.length - 1 ).toUint;
            }
        } else static if( is( Descriptor_T == VkDescriptorBufferInfo )) {
            buffer_infos.append( descriptor );
            if( write_set.pBufferInfo is null ) {
                write_set.pBufferInfo = buffer_infos.ptr_back;
                piac.index = cast( ushort )( buffer_infos.length - 1 ).toUint;
            }
        } else {            // Descriptor_T == VkBufferView
            texel_buffer_views.append( descriptor );
            if( write_set.pTexelBufferView is null ) {
                write_set.pTexelBufferView = texel_buffer_views.ptr_back;
                piac.index = cast( ushort )( texel_buffer_views.length - 1 ).toUint;
            }
        }

        // increase the descriptorCount of last set_layout_bindings with the bit filter struct
        ++piac.count;
        write_set.descriptorCount = piac.descriptor_count;

        return this;
    }


    /// add a (mutable) VkSampler descriptor, convenience function to create and add VkImageInfo
    /// no image view and image layout are required in this case
    /// Params:
    ///     sampler = the mutable VkSampler
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addSampler( VkSampler sampler, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addDescriptorTypeUpdate( VkDescriptorImageInfo( sampler, VK_NULL_HANDLE, VK_IMAGE_LAYOUT_UNDEFINED ), file, line, func );
    }


    /// add a VkImageInfo with specifying its members as function params to the Descriptor_Update
    /// several sampler less image attachments do not require a sampler specification
    /// Params:
    ///     meta = reference to a Descriptor_Update struct
    ///     image_view = of an VkImage which should be accessed through the VkDescriptorSet
    ///     image_layout = layout of the image when it will be accessed in a shader
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addImage( VkImageView image_view, VkImageLayout image_layout, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addDescriptorTypeUpdate( VkDescriptorImageInfo( VK_NULL_HANDLE, image_view, image_layout ), file, line, func );
    }


    /// add a VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER VkImageInfo with specifying its members as function params
    /// to the Descriptor_Update
    /// Params:
    ///     sampler = optional VkSampler, required for e.g. VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
    ///     image_view = of an VkImage which should be accessed through the VkDescriptorSet
    ///     image_layout = layout of the image when it will be accessed in a shader
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addSamplerImage( VkSampler sampler, VkImageView image_view, VkImageLayout image_layout, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addDescriptorTypeUpdate( VkDescriptorImageInfo( sampler, image_view, image_layout ), file, line, func );
    }


    /// add a VkBufferInfo with specifying its members as function params to the Descriptor_Update
    /// offset and range are optional, in this case the whole buffer will be attached
    /// if only offset is specified the buffer from offset till its end will be attached
    /// Params:
    ///     meta = reference to a Descriptor_Update struct
    ///     buffer = to be accessed through the VkDescriptorSet
    ///     offset = optional offset into the buffer
    ///     range  = optional range of the buffer access, till end if not specified
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addBufferInfo( VkBuffer buffer, VkDeviceSize offset = 0, VkDeviceSize range = VK_WHOLE_SIZE, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addDescriptorTypeUpdate( VkDescriptorBufferInfo( buffer, offset, range ), file, line, func );
    }


    /// add VkBufferInfos with specifying its members as function params to the Descriptor_Update
    /// offset and range are optional and common to each buffer, in this case the whole buffer will be attached
    /// if only offset is specified the buffer from offset till its end will be attached
    /// Params:
    ///     meta = reference to a Descriptor_Update struct
    ///     buffers = to be accessed through the VkDescriptorSet
    ///     offset = optional offset into each of the buffers
    ///     range  = optional range of each of the buffer access, till end if not specified
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addBufferInfos( VkBuffer[] buffers, VkDeviceSize  offset = 0, VkDeviceSize range = VK_WHOLE_SIZE, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        foreach( ref buffer; buffers )
            addDescriptorTypeUpdate( VkDescriptorBufferInfo( buffer, offset, range ), file, line, func );
        return this;
    }


    /// add a VkBufferView handle as textel uniform or shader storage buffers
    /// Params:
    ///     meta = reference to a Descriptor_Update struct
    ///     buffer_view = to access the underlying VkBuffer through the VkDescriptorSet
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addTexelBufferView( VkBufferView buffer_view, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addDescriptorTypeUpdate!VkBufferView( buffer_view, file, line,func );
    }


    /// add VkBufferView handles as texel unifor or shader storage buffers
    /// Params:
    ///     meta = reference to a Descriptor_Update struct
    ///     buffer_views = to access the array of VkBuffers through the VkDescriptorSet
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addTexelBufferViews( VkBufferView[] buffer_views, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        foreach( ref buffer_view; buffer_views )
            addDescriptorTypeUpdate!VkBufferView( buffer_view, file, line,func );
        return this;
    }


    /// set the VkDescriptorSet which is supposed to be updated in VkWriteDescriptorSet struct
    /// additionally in the case of using dynamic resource arrays the memory of the arrays
    /// might have been reallocated when descriptor infos or buffer views were added
    /// this means that the VkWriteDescriptorSet might point to wrong memory location
    /// the pointers get properly re-connected with this function
    /// Params:
    ///     meta = reference to a Descriptor_Update struct
    ///     descriptor_set = which should be updated in a later step
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref attachSet( VkDescriptorSet descriptor_set ) {
        foreach( ref write_set; write_descriptor_sets ) {
            write_set.dstSet = descriptor_set;  // store a valid and matching descriptor set in each write struct
            Pack_Index_And_Count piac = write_set.descriptorCount;  // extract original descriptorCount and index

            // only one of the following can be not null and must be patched with a possibly reallocated pointer
                 if( write_set.pImageInfo !is null )        write_set.pImageInfo        = image_infos.ptr_at( piac.index );
            else if( write_set.pBufferInfo !is null )       write_set.pBufferInfo       = buffer_infos.ptr_at( piac.index );
            else if( write_set.pTexelBufferView !is null )  write_set.pTexelBufferView  = texel_buffer_views.ptr_at( piac.index );

            write_set.descriptorCount = piac.count; // set the proper descriptorCount to its original value
        }
        return this;
    }


    /// update the VkWriteDescriptorSet
    /// calls solely vkUpdateDescriptorSets using the internal structures of the Descriptor_Update
    ///     vk = reference to a Vulkan state struct
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref update( ref Vulkan vk ) nothrow {
        vk.device.vkUpdateDescriptorSets(
            write_descriptor_sets.length.toUint,
            write_descriptor_sets.ptr, 0, null
        );  // last parameters are copy count and pointer to copies
        return this;
    }
}


/// Convenience function to update the VkWriteDescriptorSet of the passed in Descriptor_Update struct.
/// Makes more syntactical sense using UFCS.
///     vk = reference to a Vulkan state struct
///     descriptor_update = reference to a Descriptor_Update struct
/// Returns: the passed in Meta_Structure for function chaining
void updateDescriptor( ref Vulkan vk, ref Descriptor_Update descriptor_update ) {
    descriptor_update.update( vk );
}



//////////////////////////////////////////////////////////////////////////////////
// Meta_Descriptor to connect Meta_Descriptor_Layout and Descriptor_Update //
//////////////////////////////////////////////////////////////////////////////////


/// meta struct which combines the data structures and functionality of
/// Meta_Descriptor_Layout and Descriptor_Update
/// the purpose is to create and and update (initialize) a VkDescriptorSet
/// with one set of functions, without redundantly specifying same parameters
/// must be initialized with a Vulkan state struct which will be passed to
/// the wrapped meta structs
alias Meta_Descriptor = Meta_Descriptor_T!();
struct Meta_Descriptor_T(
    int32_t set_layout_binding_count    = int32_t.max,
    int32_t immutable_sampler_count     = int32_t.max,
    int32_t write_set_count             = int32_t.max,
    int32_t image_info_count            = int32_t.max,
    int32_t buffer_info_count           = int32_t.max,
    int32_t texel_buffer_view_count     = int32_t.max,

    ) {

    nothrow @nogc:
    alias Layout_T = Meta_Descriptor_Layout_T!(
        set_layout_binding_count,
        immutable_sampler_count );

    alias Update_T = Descriptor_Update_T!(
        write_set_count,
        image_info_count,
        buffer_info_count,
        texel_buffer_view_count );

    Layout_T    descriptor_layout;
    Update_T    descriptor_update;
    alias       descriptor_layout this;
    bool        add_write_descriptor = false;

    // the two following statements constructor and function are necessary
    // to override the same from mixed in Vulkan_State_Pointer of the descriptor_update
    this( ref Vulkan vk )               { descriptor_layout.vk_ptr = & vk; }
    auto ref opCall( ref Vulkan vk )    { descriptor_layout.vk_ptr = & vk; return this; }


    /// get minimal config for internal D_OR_S_ARRAY
    auto static_config() {
        size_t[6] result;
        result[ 0 .. 2 ] = descriptor_layout.static_config[];
        result[ 2 .. 6 ] = descriptor_update.static_config[];
        return result;
    }


    /// reset all internal data and return wrapped Vulkan objects
    /// VkDescriptorPool, VkDescriptorSet and VkDescriptorSetLayout
    /// of the internal Meta_Descriptor_Layout
    auto reset() {
        descriptor_update.reset;
        return descriptor_layout.reset;
    }


    /// add a VkDescriptorSetLayoutBinding to the Meta_Descriptor
    /// Parameter order is different as opposed to the Meta_Descriptor_Layout overload
    /// specifying a descriptor_count (optional) creates descriptor_count descriptors
    /// that will not be updated with any of the VkWriteDescriptorSet
    /// the descriptor_count will be incremented automatically while editing
    /// and all descriptors after descriptor count will be updated
    /// Params:
    ///     meta = reference to a Meta_Descriptor struct
    ///     binding = index of the layout binding
    ///     descriptor_type  = the type of the layout binding and hence descriptor(s)
    ///     shader_stage_flags = shader stage access filter for this layout binding
    ///     descriptor_count = optional count of descriptors in this layout binding, defaults to 0
    /// Returns: the passed in Meta_Structure for function chaining
    private auto ref addLayoutBinding(
        uint32_t            binding,
        VkDescriptorType    descriptor_type,
        VkShaderStageFlags  shader_stage_flags,
        uint32_t            descriptor_count = 0,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        // descriptor_count, in this case, is a starting value which will increase when using
        // Meta_Descriptor to create and update the descriptor set
        // Note however, that, in this case these descriptor_count descriptors will not be updated when
        // editing has finished. They must be updated later on either using Descriptor_Update or manually.
        // The count will be reset to 0 first, when adding immutable samplers, as those cannot have any offset.
        add_write_descriptor = true;
        descriptor_layout.addLayoutBinding( binding, descriptor_type, shader_stage_flags, descriptor_count, file, line, func );
        return this;
    }

    /// convenience func
    auto ref addSamplerBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_SAMPLER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addSamplerImageBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addSampledImageBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addStorageImageBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addUniformTexelBufferBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addStorageTexelBufferBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addUniformBufferBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addStorageBufferBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addUniformBufferDynamicBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addStorageBufferDynamicBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC, shader_stage_flags, descriptor_count, file, line, func );
    }

    /// convenience func
    auto ref addInputAttachmentBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, uint32_t descriptor_count = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addLayoutBinding( binding, VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT, shader_stage_flags, descriptor_count, file, line, func );
    }


    /// add a VkDescriptorSetLayoutBinding to the Meta_Descriptor
    /// to configure immutable samplers, consequently this layout will only accept
    /// descriptor_type VK_DESCRIPTOR_TYPE_SAMPLER or VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
    /// Params:
    ///     meta = reference to a Meta_Descriptor struct
    ///     binding = index of the layout binding
    ///     descriptor_type  = the type of the layout binding and hence descriptor(s)
    ///                        allowed is only VK_DESCRIPTOR_TYPE_SAMPLER and VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
    ///     shader_stage_flags = shader stage access filter for this layout binding
    /// Returns: the passed in Meta_Structure for function chaining
    private auto ref addImmutableBinding(
        uint32_t            binding,
        VkDescriptorType    descriptor_type,
        VkShaderStageFlags  shader_stage_flags,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        // Todo(pp): fix comments bellow, they are not valid for Immutable version as we do not have a descriptor_count param
        // descriptor_count in this case is a starting value which will increase when using
        // Meta_Descriptor to create and update the descriptor set
        // note however, that in this case these descriptor_count descriptors will not be updated when
        // editing has finished they must be updated later on either using Descriptor_Update or manually
        // When editing immutable samplers there cannot be any offset, so that this value is reset to 0
        // descriptor_count = 0 cannot be passed to the Meta_Descriptor_Layout.addLayoutBinding function
        // hence the descriptor_count is incremented by one for the call and decremented from
        // the added layout binding afterwards
        if( descriptor_type == VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER )
            add_write_descriptor = true;
        descriptor_layout.addImmutableBinding( binding, descriptor_type, shader_stage_flags, file, line, func );
        return this;
    }


    /// convenience func
    auto ref addImmutableSamplerBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addImmutableBinding( binding, VK_DESCRIPTOR_TYPE_SAMPLER, shader_stage_flags, file, line, func );
    }


    /// convenience func
    auto ref addImmutableSamplerImageBinding( uint32_t binding, VkShaderStageFlags shader_stage_flags, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return addImmutableBinding( binding, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, shader_stage_flags, file, line, func );
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
    private auto ref addDescriptorType( Descriptor_T )( // , alias descriptor_array, alias write_pointer : last two template arguments not needed, keep as note
        Descriptor_T        descriptor,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) if( isDescriptor!Descriptor_T ) {

        // shortcut to the last descriptor_set_layout_binding
        auto layout_binding = & set_layout_bindings[ $-1 ];

        // A write descriptor should be added only in this function
        // and only if the last command was to add a layout binding
        if( add_write_descriptor ) {
            add_write_descriptor = false;
            descriptor_update.addBindingUpdate( layout_binding.binding, layout_binding.descriptorType );
        }

        Pack_Index_And_Count piac = layout_binding.descriptorCount;         // preserve index and count
        ++piac.count;                                                       // increasing the lower 16 bits
        layout_binding.descriptorCount = piac.descriptor_count;             // assigning back to the original member

        // we must not update the descriptor if we have added an immutable sampler without image
        descriptor_update.addDescriptorTypeUpdate( descriptor, file, line, func ); // Former additional template args: descriptor_array, write_pointer )
        return this;
    }


    /// add a (mutable) VkSampler descriptor, convenience function to create and add VkImageInfo
    /// no image view and image layout are required in this case
    /// Params:
    ///     meta = reference to a Meta_Descriptor struct
    ///     sampler = the mutable VkSampler
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addSampler(
        VkSampler           sampler,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__
        ) {
        auto layout_binding = & set_layout_bindings[ $-1 ];
        vkAssert( layout_binding.descriptorType == VK_DESCRIPTOR_TYPE_SAMPLER,
            "Latest added layout binding is not compatible, it must be either VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE or VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, but it is: ",
            file, line, func, toCharPtr( layout_binding.descriptorType ));

        // if the pImmutableSamplers field of the latest layout binding is null then we add an VkImageInfo and update it
        // otherwise immutable samplers are used for this binding and we add another one
        if( set_layout_bindings[ $-1 ].pImmutableSamplers is null )
            addDescriptorType( VkDescriptorImageInfo( sampler, VK_NULL_HANDLE, VK_IMAGE_LAYOUT_UNDEFINED ), file, line, func );
        else
            descriptor_layout.addImmutableSampler( sampler, file, line, func );
        return this;
    }


    //Todo(pp): finish dis!!!
    auto ref addImage(
        VkImageView         image_view,
        VkImageLayout       image_layout,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        auto layout_binding = & set_layout_bindings[ $-1 ];
        vkAssert( layout_binding.descriptorType == VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE || layout_binding.descriptorType == VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            "Latest added layout binding is not compatible, it must be either VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE or VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, but it is: ",
            file, line, func, toCharPtr( layout_binding.descriptorType ));

        return addDescriptorType( VkDescriptorImageInfo( VK_NULL_HANDLE, image_view, image_layout ), file, line, func );
    }


    /// add a VkImageInfo with specifying its members as function params to the Meta_Descriptor
    /// several sampler-less image attachments do not require a sampler specification
    /// hence a VkSample is optional
    /// Params:
    ///     meta = reference to a Meta_Descriptor struct
    ///     image_view = of an VkImage which should be accessed through the VkDescriptorSet
    ///     image_layout = layout of the image when it will be accessed in a shader
    ///     sampler = optional VkSampler, required for e.g. VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addSamplerImage(
        VkSampler           sampler,
        VkImageView         image_view,
        VkImageLayout       image_layout,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        //pragma( inline, true ); // functions in this body should be be inlined

        // We need to catch the special case of VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
        // in connection with immutable samplers. Immutable samplers are used when the
        // pImmutableSamplers filed of the recently added layout binding is not null
        // in that case we simply attach the sampler to the Meta_Descriptor_Layout.immutable_samplers
        // instead of calling addSampler, which would increase the required count of VK_DESCRIPTOR_TYPE_SAMPLER
        // we should still pass the sampler on to the following function, it will become part of the
        // created VkDescriptorImageInfo, but should be ignored by vulkan
        auto layout_binding = & set_layout_bindings[ $-1 ];
        vkAssert( layout_binding.descriptorType == VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            "Latest added layout binding is not compatible, it must be either VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE or VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, but it is: ",
            file, line, func, toCharPtr( layout_binding.descriptorType ));

        if( layout_binding.pImmutableSamplers !is null ) {
            descriptor_layout.immutable_samplers.append( sampler, file, line, func );
            addDescriptorType( VkDescriptorImageInfo( VK_NULL_HANDLE, image_view, image_layout ), file, line, func );
        } else
            addDescriptorType( VkDescriptorImageInfo( sampler, image_view, image_layout ), file, line, func );
        return this;
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
        VkBuffer            buffer,
        VkDeviceSize        offset = 0,
        VkDeviceSize        range = VK_WHOLE_SIZE,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        //pragma( inline, true ); // functions in this body should be be inlined. Former additional tempalte args: "buffer_infos", "pBufferInfo" )
        addDescriptorType( VkDescriptorBufferInfo( buffer, offset, range ), file, line, func );
        return this;
    }


    /// add VkBufferInfos with specifying its members as function params to the Meta_Descriptor
    /// offset and range are optional and common to each buffer, in this case the whole buffer will be attached
    /// if only offset is specified the buffer from offset till its end will be attached
    /// Params:
    ///     meta = reference to a Descriptor_Update struct
    ///     buffers = to be accessed through the VkDescriptorSet
    ///     offset = optional offset into each of the buffers
    ///     range  = optional range of each of the buffer access, till end if not specified
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addBufferInfos(
        VkBuffer[]          buffers,
        VkDeviceSize        offset = 0,
        VkDeviceSize        range = VK_WHOLE_SIZE,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        //pragma( inline, true ); // functions in this body should be be inlined. Former additional template args: "buffer_infos", "pBufferInfo" )
        foreach( ref buffer; buffers )
            addDescriptorType( VkDescriptorBufferInfo( buffer, offset, range ), file, line, func );
        return this;
    }


    /// add a VkBufferView handle as texel uniform or shader storage buffers
    /// Params:
    ///     meta = reference to a Meta_Descriptor struct
    ///     buffer_view = to access the underlying VkBuffer through the VkDescriptorSet
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addTexelBufferView(
        VkBufferView        buffer_view,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        //pragma( inline, true ); // functions in this body should be be inlined. Former additional tempalte args: "texel_buffer_views", "pTexelBufferView" )
        addDescriptorType( buffer_view, file, line, func );
        return this;
    }


    /// add VkBufferView handles as texel unifor or shader storage buffers
    /// Params:
    ///     meta = reference to a Descriptor_Update struct
    ///     buffer_views = to access the array of VkBuffers through the VkDescriptorSet
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref addTexelBufferViews(
        VkBufferView[]      buffer_views,
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        //pragma( inline, true ); // functions in this body should be be inlined. Former additional tempalte args: "texel_buffer_views", "pTexelBufferView" )
        foreach( ref buffer_view; buffer_views )
            addDescriptorType( buffer_view, file, line,func );
        return this;
    }


    /// construct the managed Vulkan objects, convenience function
    /// calls Meta_Descriptor_Layout allocateSet() and Meta_Descriptor_Layout attachSet()
    /// Params:
    ///     meta = reference to a Meta_Descriptor struct
    ///     descriptor_pool_cf = = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref construct(
        VkDescriptorPoolCreateFlags descriptor_pool_cf = 0,
        string                      file = __FILE__,
        size_t                      line = __LINE__,
        string                      func = __FUNCTION__

        ) {

        descriptor_layout.allocateSet( descriptor_pool_cf, file, line, func );
        descriptor_update.attachSet( descriptor_set ).update( vk );
        return this;
    }


    /// construct the managed Vulkan objects, convenience function
    /// calls Meta_Meta_Descriptor_Layout createSetLayout() with param set_layout_cf
    /// Meta_Descriptor_Layout allocateSet() and Meta_Descriptor_Layout attachSet()
    /// Params:
    ///     meta = reference to a Meta_Descriptor struct
    ///     set_layout_cf = only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
    ///     descriptor_pool_cf = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref construct(
        VkDescriptorSetLayoutCreateFlags    set_layout_cf,
        VkDescriptorPoolCreateFlags         descriptor_pool_cf = 0,
        string                              file = __FILE__,
        size_t                              line = __LINE__,
        string                              func = __FUNCTION__

        ) {

        descriptor_layout
            .createSetLayout( set_layout_cf, file, line, func )
            .allocateSet( descriptor_pool_cf, file, line, func );
        descriptor_update.attachSet( descriptor_set ).update( vk );
        return this;
    }

    /// construct the managed Vulkan objects, convenience function
    /// calls Meta_Meta_Descriptor_Layout createSetLayout() with param set_layout_cf
    /// Meta_Descriptor_Layout allocateSet() with param descriptor_pool and
    /// Meta_Descriptor_Layout attachSet()
    /// Params:
    ///     meta = reference to a Meta_Descriptor struct
    ///     descriptor_pool = external VkDescriptorPool from which the descriptors will be allocated
    ///     set_layout_cf = optional, only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
    /// Returns: the passed in Meta_Structure for function chaining
    auto ref construct(
        VkDescriptorPool                    descriptor_pool,
        VkDescriptorSetLayoutCreateFlags    set_layout_cf = 0,
        string                              file = __FILE__,
        size_t                              line = __LINE__,
        string                              func = __FUNCTION__

        ) {

        descriptor_layout
            .createSetLayout( set_layout_cf, file, line, func )
            .allocateSet( descriptor_pool, file, line, func );
        descriptor_update.attachSet( descriptor_set ).update( vk );
        return this;
    }
}



/// private struct to help store count of immutable samplers and starting index into immutable_samplers array
private struct Pack_Index_And_Count {
    nothrow @nogc:
    this( uint32_t dc ) { descriptor_count = dc; }
    union {
        uint32_t descriptor_count;
        struct {
            version( BigEndian )    uint16_t index, count;  // consider endianness
            else                    uint16_t count, index;
        }
    }
}



/// private template to test whether template argument is VkDescriptorImageInfo, VkDescriptorBufferInfo or VkBufferView
template isDescriptor( D ) { enum isDescriptor = is( D == VkDescriptorImageInfo ) || is( D == VkDescriptorBufferInfo ) || is( D == VkBufferView ); }



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