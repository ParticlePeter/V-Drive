module vdrive.renderbuffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;



///////////////////////////////////////
// Meta_Subpass and Meta_Renderpass //
///////////////////////////////////////



/// struct to collect subpass relevant data
private struct Meta_Subpass_T(
    int32_t input_ref_count,
    int32_t color_ref_count,
    int32_t resolve_ref_count,
    int32_t preserve_ref_count,
    ) {
    VkSubpassDescriptionFlags                                   flags;
    VkPipelineBindPoint                                         pipeline_bind_point = VK_PIPELINE_BIND_POINT_GRAPHICS;  // currently this is the only acceptable value, but might change in future
    D_OR_S_ARRAY!( input_ref_count,     VkAttachmentReference ) input_reference;
    D_OR_S_ARRAY!( color_ref_count,     VkAttachmentReference ) color_reference;
    D_OR_S_ARRAY!( resolve_ref_count,   VkAttachmentReference ) resolve_reference;
    D_OR_S_ARRAY!( preserve_ref_count,  VkAttachmentReference ) preserve_reference;
    VkAttachmentReference                                       depth_stencil_reference; //= VK_ATTACHMENT_UNUSED;

    auto static_config() {
        size_t[4] result;
        result[0] = input_reference.length;
        result[1] = color_reference.length;
        result[2] = resolve_reference.length;
        result[3] = preserve_reference.length;
        return result;
    }
}

alias Meta_Subpass  = Meta_Subpass_T!( int32_t.max, int32_t.max, int32_t.max, int32_t.max );


/// private template to constraint template arg to Meta_Graphics or Meta_Compute
private template isRenderpass( T ) { enum isRenderpass = is( typeof( isRenderPassImpl( T.init )));  }
private void isRenderPassImpl( int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, int32_t g, )( Meta_Renderpass_T!( a, b, c, d, e, f, g ) meta_rp ) {}


struct Meta_Renderpass_T(
    int32_t attachment_count,
    int32_t dependency_count,
    int32_t subpass_count,
    int32_t max_input_ref_count,
    int32_t max_color_ref_count,
    int32_t max_resolve_ref_count,
    int32_t max_preserve_ref_count,
    ) {
    mixin                           Vulkan_State_Pointer;
    ref VkRenderPass                render_pass() { return begin_info.renderPass; }
    VkRenderPassBeginInfo           begin_info;     // the actual render pass is stored in a member of this struct

    private Meta_Subpass_T!(
        max_input_ref_count,
        max_color_ref_count,
        max_resolve_ref_count,
        max_preserve_ref_count )*   subpass;
    private VkSubpassDependency*    subpass_dependency;

    D_OR_S_ARRAY!( attachment_count, VkAttachmentDescription )  attachment_descriptions;
    D_OR_S_ARRAY!( dependency_count, VkSubpassDependency )      subpass_dependencies;
    D_OR_S_ARRAY!( subpass_count, Meta_Subpass_T!(
        max_input_ref_count,
        max_color_ref_count,
        max_resolve_ref_count,
        max_preserve_ref_count ))                               subpasses;


    //mixin Dispatch_To_Inner_Struct!begin_info;    // Does not work because it has precedence over UFCS

    auto static_config() {
        size_t[7] result;
        result[0] = attachment_descriptions.length;
        result[1] = subpass_dependencies.length;
        result[2] = subpasses.length;
        foreach( ref sp; subpasses ) {
            if( result[3] < sp.input_reference.length    ) result[3] = sp.input_reference.length;
            if( result[4] < sp.color_reference.length    ) result[4] = sp.color_reference.length;
            if( result[5] < sp.resolve_reference.length  ) result[5] = sp.resolve_reference.length;
            if( result[6] < sp.preserve_reference.length ) result[6] = sp.preserve_reference.length;
        }
        return result;
    }

    void destroyResources() {
        vk.device.vkDestroyRenderPass( render_pass, vk.allocator );
    }
}


alias Meta_Renderpass  = Meta_Renderpass_T!( int32_t.max, int32_t.max, int32_t.max, int32_t.max, int32_t.max, int32_t.max, int32_t.max );

/// reset all internal data and return internal renderpass begin info
/// which holds the render pass as member
auto reset( META )( ref META meta ) if( isRenderpass!META ) {
    meta.subpass = null;
    meta.subpass_dependency = null;
    meta.attachment_descriptions.clear;
    meta.subpass_dependencies.clear;
    meta.subpasses.clear;
    return meta.begin_info;
}


auto beginInfo( META )( ref META meta ) if( isRenderpass!META ) {
    return meta.begin_info;
}




auto ref renderPassAttachment( META )(
    ref META                meta,
    VkFormat                image_format,
    VkSampleCountFlagBits   sample_count,
    VkAttachmentLoadOp      load_op,
    VkAttachmentStoreOp     store_op,
    VkAttachmentLoadOp      stencil_load_op,
    VkAttachmentStoreOp     stencil_store_op,
    VkImageLayout           initial_layout,
    VkImageLayout           final_layout    = VK_IMAGE_LAYOUT_MAX_ENUM
    ) if( isRenderpass!META ) {

    VkAttachmentDescription attachment_description = {
        format              : image_format,
        samples             : sample_count,
        loadOp              : load_op,
        storeOp             : store_op,
        stencilLoadOp       : stencil_load_op,
        stencilStoreOp      : stencil_store_op,
        initialLayout       : initial_layout,
        finalLayout         : final_layout,
    };

    meta.attachment_descriptions.append( attachment_description );
    return meta;
}


auto ref renderPassAttachment( META )(
    ref META                meta,
    VkFormat                image_format,
    VkSampleCountFlagBits   sample_count,
    VkAttachmentLoadOp      load_op,
    VkAttachmentStoreOp     store_op,
    VkImageLayout           initial_layout,
    VkImageLayout           final_layout    = VK_IMAGE_LAYOUT_MAX_ENUM
    ) if( isRenderpass!META ) {
    return renderPassAttachment( meta, image_format, sample_count, load_op, store_op,
        VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
};


auto ref renderPassAttachment_Load_None( META )( ref META meta, VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) {
    return renderPassAttachment( meta, image_format, sample_count, VK_ATTACHMENT_LOAD_OP_LOAD, VK_ATTACHMENT_STORE_OP_DONT_CARE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
};

auto ref renderPassAttachment_Load_Store( META )( ref META meta, VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) {
    return renderPassAttachment( meta, image_format, sample_count, VK_ATTACHMENT_LOAD_OP_LOAD, VK_ATTACHMENT_STORE_OP_STORE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
};

auto ref renderPassAttachment_Clear_None( META )( ref META meta, VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) {
    return renderPassAttachment( meta, image_format, sample_count, VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_DONT_CARE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
};

auto ref renderPassAttachment_Clear_Store( META )( ref META meta, VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) {
    return renderPassAttachment( meta, image_format, sample_count, VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
};

auto ref renderPassAttachment_None_None( META )( ref META meta, VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) {
    return renderPassAttachment( meta, image_format, sample_count, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
};

auto ref renderPassAttachment_None_Store( META )( ref META meta, VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) {
    return renderPassAttachment( meta, image_format, sample_count, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_STORE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
};


enum Subpass_Ref_Type : uint32_t { input, color, resolve, preserve, depth_stencil };


auto ref subpassReference( META )(
    ref META                meta,
    Subpass_Ref_Type        ref_type,
    uint32_t                attachment_index,
    VkImageLayout           render_layout = VK_IMAGE_LAYOUT_MAX_ENUM
    ) if( isRenderpass!META ) {
    if( meta.subpasses.length == 0 )
        meta.addSubpass;

    VkAttachmentReference attachment_reference = {
        attachment  : ( meta.attachment_descriptions.length - 1 ).toUint,
        layout      : render_layout == VK_IMAGE_LAYOUT_MAX_ENUM ? meta.attachment_descriptions[$-1].initialLayout : render_layout,
    };

    // if attachment_descriptions[$-1].finalLayout is VK_IMAGE_LAYOUT_MAX_ENUM this means it is supposed to be the same as render_layout
    if( meta.attachment_descriptions[$-1].finalLayout == VK_IMAGE_LAYOUT_MAX_ENUM )
        meta.attachment_descriptions[$-1].finalLayout = attachment_reference.layout;

    final switch( ref_type ) {
        case Subpass_Ref_Type.input           : meta.subpass.input_reference.append( attachment_reference );      break;
        case Subpass_Ref_Type.color           : meta.subpass.color_reference.append( attachment_reference );      break;
        case Subpass_Ref_Type.resolve         : meta.subpass.resolve_reference.append( attachment_reference );    break;
        case Subpass_Ref_Type.preserve        : meta.subpass.preserve_reference.append( attachment_reference );   break;
        case Subpass_Ref_Type.depth_stencil   : meta.subpass.depth_stencil_reference = attachment_reference;      break;
    }

    return meta;
}


auto ref subpassRefInput(        META )( ref META meta, uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.input,         attachment_index, render_layout ); }
auto ref subpassRefColor(        META )( ref META meta, uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.color,         attachment_index, render_layout ); }
auto ref subpassRefResolve(      META )( ref META meta, uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.resolve,       attachment_index, render_layout ); }
auto ref subpassRefPreserve(     META )( ref META meta, uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.preserve,      attachment_index, render_layout ); }
auto ref subpassRefDepthStencil( META )( ref META meta, uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.depth_stencil, attachment_index, render_layout ); }


// cannot use subpassReference as function overload as aliases bellow cannot be set for function overloads with different args
auto ref subpassReference( META )(
    ref META                meta,
    Subpass_Ref_Type        ref_type,
    VkImageLayout           render_layout = VK_IMAGE_LAYOUT_MAX_ENUM
    ) if( isRenderpass!META ) {
    assert( meta.attachment_descriptions.length > 0 );
    return subpassReference( meta, ref_type, toUint( meta.attachment_descriptions.length - 1 ), render_layout );
}


auto ref subpassRefInput(        META )( ref META meta, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.input,         toUint( meta.attachment_descriptions.length - 1 ), render_layout ); }
auto ref subpassRefColor(        META )( ref META meta, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.color,         toUint( meta.attachment_descriptions.length - 1 ), render_layout ); }
auto ref subpassRefResolve(      META )( ref META meta, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.resolve,       toUint( meta.attachment_descriptions.length - 1 ), render_layout ); }
auto ref subpassRefPreserve(     META )( ref META meta, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.preserve,      toUint( meta.attachment_descriptions.length - 1 ), render_layout ); }
auto ref subpassRefDepthStencil( META )( ref META meta, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) if( isRenderpass!META ) { return meta.subpassReference( Subpass_Ref_Type.depth_stencil, toUint( meta.attachment_descriptions.length - 1 ), render_layout ); }




/// add a Meta_Subpass to the subpasses array of Meta_Renderpass
/// consecutive subpass related function calls will create resources for this Meta_Structure if no index is specified
/// Params:
///     meta = reference to a Meta_Renderpass struct
///     subpass_description_flags = optionally add a ( currently the only one: VK_ATTACHMENT_DESCRIPTION_MAY_ALIAS_BIT ) flag
/// Returns: the passed in Meta_Structure for function chaining
auto ref addSubpass( META )(
    ref META                    meta,
    VkSubpassDescriptionFlags   subpass_description_flags = 0
    ) if( isRenderpass!META ) {
    meta.subpasses.length = meta.subpasses.length + 1;
    meta.subpass = & meta.subpasses[ $-1 ];
    meta.subpass.flags = subpass_description_flags;
    return meta;
}


/// add a VkSubpassDependency to the subpass_dependencies array of Meta_Renderpass
/// consecutive subpass related function calls will create data for this VkSubpassDependency if no index is specified
/// Params:
///     meta = reference to a Meta_Renderpass struct
/// Returns: the passed in Meta_Structure for function chaining
auto ref addDependency( META )( ref META meta ) if( isRenderpass!META ) {
    meta.subpass_dependencies.length = meta.subpass_dependencies.length + 1;
    meta.subpass_dependency = & meta.subpass_dependencies[ $-1 ];
    return meta;
}


/// add a VkSubpassDependency to the subpass_dependencies array of Meta_Renderpass
/// additionally its dependencyFlags is set to VK_DEPENDENCY_BY_REGION_BIT
/// consecutive subpass related function calls will create data for this VkSubpassDependency if no index is specified
/// Params:
///     meta = reference to a Meta_Renderpass struct
/// Returns: the passed in Meta_Structure for function chaining
auto ref addDependencyByRegion( META )( ref META meta ) if( isRenderpass!META ) {
    meta.addDependency;
    meta.subpass_dependencies[ $-1 ].dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT;
    return meta;
}


/// set the source subpass dependencies of the last added dependency item
/// Params:
///     meta = reference to a Meta_Renderpass struct
///     subpass = the source subpass
///     stage_mask = the source stage mask
///     access_mask = the source access mask
/// Returns: the passed in Meta_Structure for function chaining
auto ref srcDependency( META )(
    ref META                meta,
    uint32_t                subpass,
    VkPipelineStageFlags    stage_mask,
    VkAccessFlags           access_mask
    ) if( isRenderpass!META ) {
    assert( meta.subpass_dependencies.length > 0 );
    with( meta.subpass_dependencies[ $-1 ] ) {
        srcSubpass      = subpass;
        srcStageMask    = stage_mask;
        srcAccessMask   = access_mask;
    }
    return meta;
}


/// set the destination subpass dependencies of the last added dependency item
/// Params:
///     meta = reference to a Meta_Renderpass struct
///     subpass = the destination subpass
///     stage_mask = the destination stage mask
///     access_mask = the destination access mask
/// Returns: the passed in Meta_Structure for function chaining
auto ref dstDependency( META )(
    ref META                meta,
    uint32_t                subpass,
    VkPipelineStageFlags    stage_mask,
    VkAccessFlags           access_mask
    ) if( isRenderpass!META ) {
    assert( meta.subpass_dependencies.length > 0 );
    with( meta.subpass_dependencies[ $-1 ] ) {
        dstSubpass      = subpass;
        dstStageMask    = stage_mask;
        dstAccessMask   = access_mask;
    }
    return meta;
}


/// set the subpass dependencies of the last added dependency item
/// Params:
///     meta = reference to a Meta_Renderpass struct
///     source = the source subpass
///     destination = the destination subpass
/// Returns: the passed in Meta_Structure for function chaining
auto ref subpassDependency( META )(
    ref META                meta,
    uint32_t                source,
    uint32_t                destination
    ) if( isRenderpass!META ) {
    assert( meta.subpass_dependencies.length > 0 );
    with( meta.subpass_dependencies[ $-1 ] ) {
        srcSubpass = source;
        dstSubpass = destination;
    }
    return meta;
}


/// set the stage mask dependencies of the last added dependency item
/// Params:
///     meta = reference to a Meta_Renderpass struct
///     source = the source stage mask
///     destination = the destination stage mask
/// Returns: the passed in Meta_Structure for function chaining
auto ref stageMaskDependency( META )(
    ref META                meta,
    VkPipelineStageFlags    source,
    VkPipelineStageFlags    destination
    ) if( isRenderpass!META ) {
    assert( meta.subpass_dependencies.length > 0 );
    with( meta.subpass_dependencies[ $-1 ] ) {
        srcStageMask = source;
        dstStageMask = destination;
    }
    return meta;
}


/// set the access mask dependencies of the last added dependency item
/// Params:
///     meta = reference to a Meta_Renderpass struct
///     source = the source access mask
///     destination = the destination access mask
/// Returns: the passed in Meta_Structure for function chaining
auto ref accessMaskDependency( META )(
    ref META                meta,
    VkAccessFlags           source,
    VkAccessFlags           destination
    ) if( isRenderpass!META ) {
    assert( meta.subpass_dependencies.length > 0 );
    with( meta.subpass_dependencies[ $-1 ] ) {
        srcAccessMask = source;
        dstAccessMask = destination;
    }
    return meta;
}


// As long as only one possible flag exists, the function bellow is redundant
// use addDependencyByRegion instead
/*auto ref dependencyFlags( META )( ref META meta, VkDependencyFlags dependency_flags ) if( isRenderpass!META ) {
    assert( meta.subpass_dependencies.length > 0 );
    meta.subpass_dependencies[ $-1 ].dependencyFlags = dependency_flags;
    return meta;
}
*/

/// set clear values into the render pass begin info
/// usage of either this function or attachFramebuffer(s) is required to set clear values for the later used VkRenderPassBeginInfo
/// Params:
///     meta = reference to a Meta_Renderpass struct
///     clear_value = will be set into the meta render pass VkRenderPassBeginInfo. Storage must be managed outside
/// Returns: the passed in Meta_Structure for function chaining
auto ref clearValues( Array_T, META )(
    ref META meta,
    Array_T clear_value
    ) if( is( Array_T == Array!VkClearValue ) || is( Array_T : VkClearValue[] ) && isRenderpass!META ) {
    meta.begin_info.pClearValues = clear_value.ptr;
    meta.begin_info.clearValueCount = clear_value.length.toUint;
    return meta;
}

// TODO(pp): not having a depth attachment does not work. Fix it!

/// construct a VkRenderPass from specified resources of Meta_Renderpass structure and store it there as well
/// Params:
///     meta = reference to a Meta_Renderpass struct
/// Returns: the passed in Meta_Structure for function chaining
auto ref construct( META )( ref META meta ) if( isRenderpass!META ) {
    // assert that meta struct is initialized with a valid vulkan state pointer
    assert( meta.isValid );

    // extract VkSubpassDescription from Meta_Subpass
    auto subpass_descriptions = sizedArray!VkSubpassDescription( meta.subpasses.length );
    foreach( i, ref subpass; meta.subpasses.data ) {

        // assert that resolve references length is less or equal to color references length
        // do nothing if resolve references length is 0, but if reference length is strictly less then color reference length
        // fill resolve reference length with VkAttachmentReference( VK_ATTACHMENT_UNUSED, layout arbitrary )
        assert( subpass.resolve_reference.length <= subpass.color_reference.length );
        if( subpass.resolve_reference.length > 0 && subpass.resolve_reference.length < subpass.color_reference.length ) {
            auto old_length = subpass.resolve_reference.length;
            subpass.resolve_reference.length = subpass.color_reference.length;
            subpass.resolve_reference[ old_length .. subpass.resolve_reference.length ] = VkAttachmentReference( VK_ATTACHMENT_UNUSED, VK_IMAGE_LAYOUT_UNDEFINED );
        }

        // fill the current VkSubpassDescription with data from corresponding Meta_Subpass
        with( subpass_descriptions[i] ) {
            pipelineBindPoint       =   subpass.pipeline_bind_point;
            inputAttachmentCount    =   subpass.input_reference.length.toUint;
            pInputAttachments       =   subpass.input_reference.ptr;
            colorAttachmentCount    =   subpass.color_reference.length.toUint;
            pColorAttachments       =   subpass.color_reference.ptr;
            pResolveAttachments     =   subpass.resolve_reference.ptr;
            pDepthStencilAttachment = & subpass.depth_stencil_reference;
        }
    }


    // use the new Array!VkSubpassDescription to create the VkRenderPass
    VkRenderPassCreateInfo render_pass_create_info = {
        attachmentCount : meta.attachment_descriptions.length.toUint,
        pAttachments    : meta.attachment_descriptions.ptr,
        subpassCount    : subpass_descriptions.length.toUint,
        pSubpasses      : subpass_descriptions.ptr,
        dependencyCount : meta.subpass_dependencies.length.toUint,
        pDependencies   : meta.subpass_dependencies.ptr,
    };

    vkCreateRenderPass( meta.device, & render_pass_create_info, meta.allocator, & meta.begin_info.renderPass ).vkAssert;
    return meta;
}



//////////////////////
// Meta_Framebuffer //
//////////////////////

struct Meta_FB( int32_t framebuffer_count = 1, int32_t clear_value_count = int32_t.max ) {
    static assert( framebuffer_count != 0, "Count of framebuffers must not be 0!" );
    mixin       Vulkan_State_Pointer;

    // required for template functions
    alias fb_count = framebuffer_count;
    alias cv_count = clear_value_count;

    VkRect2D                                                                render_area;
    D_OR_S_ARRAY!( fb_count, VkFramebuffer )                                framebuffers;
    static if( cv_count > 0 )   D_OR_S_ARRAY!( cv_count, VkClearValue )     clear_values;

    auto ref opCall( ref Vulkan vk ) {
        this.vk( vk );
        return this;
    }

    auto opCall( uint32_t index = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( !empty, "No Framebuffers created so far", file, line, func );
        return framebuffers[ index ];
    }

    auto framebuffer( uint32_t index = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( !empty, "No Framebuffers created so far", file, line, func );
        return framebuffers[ index ];
    }

    auto ptr()      { return framebuffers.ptr; }
    auto length()   { return framebuffers.length.toUint; }
    bool empty()    { return framebuffers.empty; }

    void destroyResources( bool destroy_clear_values = true ) {
        // Required if this struct should be reused for proper render_area reinitialization
        render_area = VkRect2D( VkOffset2D( 0, 0 ), VkExtent2D( 0, 0 ));

        // destroy framebuffers
        foreach( fb; framebuffers )  vk.destroy( fb );
        framebuffers.clear;

        // optionally destroy clear values, default is destroy them
        static if( cv_count > 0 ) if( destroy_clear_values ) clear_values.clear;
    }
}

alias Meta_Framebuffer  = Meta_FB!( 1, int32_t.max );
alias Meta_Framebuffers = Meta_FB!( int32_t.max, int32_t.max );

/// If T is a vector, this evaluates to true, otherwise false
private template isSingleBuffer( T )  {  enum isSingleBuffer = is( typeof( isSingleBufferImpl( T.init ))); }
private void isSingleBufferImpl( uint cv_count )( Meta_FB!( 1, cv_count ) meta ) {}

private template isMultiBuffer( T )  {  enum isMultiBuffer = is( typeof( isMultiBufferImpl( T.init ))); }
private void isMultiBufferImpl( uint fb_count, uint cv_count )( Meta_FB!( fb_count, cv_count ) meta ) {}


/// Set attachment specific (framebuffer attachment index) r, g, b, a clear value
/// The type of all values must be the same and either float, int32_t or uint32_t
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers struct
///     index   = framebuffer attachment index
///     r       = red clear value
///     g       = green clear value
///     b       = blue clear value
///     a       = alpha clear value
/// Returns: the passed in Meta_Structure for function chaining
auto ref setClearValue( META_FB, T )(
    ref META_FB meta,
    uint32_t    index,
    T           r,
    T           g,
    T           b,
    T           a,
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) if( isMultiBuffer!META_FB && ( is( T == float ) || is( T == int32_t ) || is( T == uint32_t ))) {
    T[4] rgba = [ r, g, b, a ];
    return setClearValue( meta, index, rgba, file, line, func );
}


/// Set attachment specific (framebuffer attachment index) rgba clear value array or math vector (e.g. dlsl)
/// The element type must be either float, int32_t or uint32_t
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers struct
///     index   = framebuffer attachment index
///     rgba    = the rgba clear value as array or four component math vector
/// Returns: the passed in Meta_Structure for function chaining
auto ref setClearValue( META_FB, T )(
    ref META_FB meta,
    uint32_t    index,
    T[4]        rgba,
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) if( isMultiBuffer!META_FB && ( is( T == float ) || is( T == int32_t ) || is( T == uint32_t ))) {
    VkClearValue clear_value;
            static if( is( T == float ))    clear_value.color.float32   = rgba;
    else    static if( is( T == int32_t ))  clear_value.color.int32     = rgba;
    else    static if( is( T == uint32_t )) clear_value.color.uint32    = rgba;
    return  setClearValue( meta, index, clear_value, file, line, func );
}


/// Set attachment specific (framebuffer attachment index) depth-stencil clear value
/// Stencil value defaults to 0
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers struct
///     index   = framebuffer attachment index
///     depth   = the depth clear value
///     stencil = the stencil clear value, defaults to 0
/// Returns: the passed in Meta_Structure for function chaining
auto ref setClearValue( META_FB, U )(
    ref META_FB meta,
    uint32_t    index,
    float       depth,
    U           stencil = 0,
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) if( isMultiBuffer!META_FB && is( U : uint32_t )) {
    VkClearValue clear_value = { depthStencil : VkClearDepthStencilValue( depth, stencil ) };
    return setClearValue( meta, index, clear_value, file, line, func );
}


/// Set attachment specific (framebuffer attachment index) VkClearValue
/// Stencil value defaults to 0
/// Params:
///     meta        = reference to a Meta_Framebuffer or Meta_Framebuffers struct
///     index       = framebuffer attachment index
///     clear_value = the VkClearValue clear value
/// Returns: the passed in Meta_Structure for function chaining
auto ref setClearValue( META_FB )(
    ref META_FB     meta,
    uint32_t        index,
    VkClearValue    clear_value,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isMultiBuffer!META_FB ) {

    // Todo(pp): update this to usage of D_OR_S_ARRAY
    // if using dynamic arrays
//    static if( META_FB.cv_count == uint32_t.max ) {
        if( index == uint32_t.max )                     // signal to append clear_value instead of setting to a specific index ...
            index = meta.clear_values.length.toUint;    // ... hence set the index to the length of the current array length
        if( meta.clear_values.length <= index ) {       // if index is greater then the array ...
            meta.clear_values.length  = index + 1;      // ... resize the array
        }
        meta.clear_values[ index ] = clear_value;
//    }
/*
    // if using static arrays
    else {
        if( index == uint32_t.max )                 // signal to append clear_value instead of setting to a specific index ...
            index = clear_values_length;            // ... hence set the index to the length of the current array length
        vkAssert( index < META_FB.cv_count,         // assert that the current index fits into the static array bounds
            "Meta_Framebuffer with static clear value array param index must be greater than the static array length",
            file, line, func );
        clear_values_length = index + 1;            // set the occupied length of the static clear_value array
        meta.clear_values[ index ] = clear_value;
    }
*/
    return meta;
}


/// Add (append) attachment specific (framebuffer attachment index) r, g, b, a clear value
/// The type of all values must be the same and either float, int32_t or uint32_t
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers struct
///     r       = red clear value
///     g       = green clear value
///     b       = blue clear value
///     a       = alpha clear value
/// Returns: the passed in Meta_Structure for function chaining
auto ref addClearValue( META_FB, T )(
    ref META_FB meta,
    T           r,
    T           g,
    T           b,
    T           a,
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) if( isMultiBuffer!META_FB && ( is( T == float ) || is( T == int32_t ) || is( T == uint32_t ))) {
    return setClearValue( meta, uint32_t.max, r, g, b, a, file, line, func );
}


/// Add (append) attachment specific (framebuffer attachment index) rgba clear value array or math vector (e.g. dlsl)
/// The element type must be either float, int32_t or uint32_t
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers struct
///     rgba    = the rgba clear value as array or four component math vector
/// Returns: the passed in Meta_Structure for function chaining
auto ref addClearValue( META_FB, T )(
    ref META_FB meta,
    T[4]        rgba,
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) if( isMultiBuffer!META_FB && ( is( T == float ) || is( T == int32_t ) || is( T == uint32_t ))) {
    return setClearValue( meta, uint32_t.max, rgba, file, line, func );
}


/// Add (append) attachment specific (framebuffer attachment index) depth-stencil clear value
/// Stencil value defaults to 0
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers struct
///     depth   = the depth clear value
///     stencil = the stencil clear value, defaults to 0
/// Returns: the passed in Meta_Structure for function chaining
auto ref addClearValue( META_FB, UINT32_T )(
    ref META_FB meta,
    float       depth,
    UINT32_T    stencil = 0,
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) if( isMultiBuffer!META_FB && is( UINT32_T : uint32_t )) {
    return setClearValue( meta, uint32_t.max, depth, stencil, file, line, func );
}


/// Add (append) attachment specific (framebuffer attachment index) VkClearValue
/// Stencil value defaults to 0
/// Params:
///     meta        = reference to a Meta_Framebuffer or Meta_Framebuffers struct
///     clear_value = the VkClearValue clear value
/// Returns: the passed in Meta_Structure for function chaining
auto ref addClearValue( META_FB )(
    ref META_FB     meta,
    VkClearValue    clear_value,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isMultiBuffer!META_FB ) {
    return setClearValue( meta, uint32_t.max, clear_value, file, line, func );
}


/// set the render area offset separate from the extent
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers
///     offset  = the offset of the render area
/// Returns: the passed in Meta_Structure for function chaining
auto ref renderAreaOffset( META_FB )( ref META_FB meta, VkOffset2D offset ) if( isMultiBuffer!META_FB ) {
    meta.render_area.offset = offset;
    return meta;
}


/// set the render area offset separate from the extent
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers
///     x       = the offset of the render area in x
///     y       = the offset of the render area in y
/// Returns: the passed in Meta_Structure for function chaining
auto ref renderAreaOffset( META_FB )( ref META_FB meta, int32_t x, int32_t y ) if( isMultiBuffer!META_FB ) {
    return meta.renderAreaOffset( VkOffset2D( x, y ));
}


/// set the render area extent separate from the offset
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers
///     extent  = the extent of the render area
/// Returns: the passed in Meta_Structure for function chaining
auto ref renderAreaExtent( META_FB )( ref META_FB meta, VkExtent2D extent ) if( isMultiBuffer!META_FB ) {
    meta.render_area.extent = extent;
    return meta;
}


/// set the render area extent separate from the offset
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers
///     width   = the width of the render area
///     height  = the height of the render area
/// Returns: the passed in Meta_Structure for function chaining
auto ref renderAreaExtent( META_FB )( ref META_FB meta, uint32_t width, uint32_t height ) if( isMultiBuffer!META_FB ) {
    return meta.renderAreaExtent( VkExtent2D( width, height ));
}


/// set the render area
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers
///     area    = the render area
/// Returns: the passed in Meta_Structure for function chaining
auto ref renderArea( META_FB )( ref META_FB meta, VkRect2D area ) if( isMultiBuffer!META_FB ) {
    meta.render_area = area;
    return meta;
}


/// set the render area
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers
///     offset  = the offset of the render area
///     extent  = the extent of the render area
/// Returns: the passed in Meta_Structure for function chaining
auto ref renderAreaExtent( META_FB )( ref META_FB meta, VkOffset2D offset, VkExtent2D extent ) if( isMultiBuffer!META_FB ) {
    return meta.renderArea( VkRect( offset, extent ));
}


/// set the render area
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     meta    = reference to a Meta_Framebuffer or Meta_Framebuffers
///     x       = the offset of the render area in x
///     y       = the offset of the render area in y
///     width   = the width of the render area
///     height  = the height of the render area
/// Returns: the passed in Meta_Structure for function chaining
auto ref renderAreaExtent( META_FB )( ref META_FB meta, int32_t x, int32_t y, uint32_t width, uint32_t height ) if( isMultiBuffer!META_FB ) {
    return meta.renderArea( VkRect( VkOffset2D( x, y ), VkExtent( width, height )));
}



/////////////////////////////////////////////////
// connect Meta_Framebuffer to Meta_Renderpass //
/////////////////////////////////////////////////


/*
/// set members of a Meta_Renderpass.VkRenderPassBeginInfo with the corresponding members of a Meta_Framebuffer structure
/// this should be called once if the framebuffer related members of the VkRenderPassBeginInfo are not changing later on
/// or before vkCmdBeginRenderPass to switch framebuffer, render area (hint, see renderAreaOffset/Extent) and clear values
/// Params:
///     meta_renderpass = reference to a Meta_Renderpass structure holding the VkRenderPassBeginInfo
///     meta_framebuffer = the Meta_Framebuffer structure whose framebuffer and resources will be attached
/// Returns: the passed in Meta_Structure for function chaining
auto ref attachFramebuffer( META_FB )(
    ref Meta_Renderpass meta_renderpass,
    ref META_FB         meta_framebuffer
    ) if( isSingleBuffer!META_FB ) {
    with( meta_renderpass.begin_info ) {
        framebuffer     = meta_framebuffer( 0 );
        renderArea      = meta_framebuffer.render_area;
        pClearValues    = meta_framebuffer.clear_values.ptr;
        clearValueCount = meta_framebuffer.clear_values.length.toUint;
    } return meta_renderpass;
}
*/
/// set members of a Meta_Renderpass.VkRenderPassBeginInfo with the corresponding members of a Meta_Framebuffers structure
/// this should be called once if the framebuffer related members of the VkRenderPassBeginInfo are not changing later on
/// or before vkCmdBeginRenderPass to switch framebuffer, render area (hint, see renderAreaOffset/Extent) and clear values
/// Params:
///     meta_renderpass  = reference to a Meta_Renderpass_T structure holding the VkRenderPassBeginInfo
///     meta_framebuffers = reference to the Meta_Framebuffer structure whose framebuffer and resources will be attached
///     framebuffer_length = the index to select a framebuffer from the member framebuffer array
/// Returns: the passed in Meta_Structure for function chaining
auto ref attachFramebuffer( META_RP, META_FB )(
    ref META_RP         meta_renderpass,
    ref META_FB         meta_framebuffers,
    uint32_t            framebuffer_index = 0
    ) if( isRenderpass!META_RP && isMultiBuffer!META_FB ) {
    meta_renderpass.begin_info.attachFramebuffer( meta_framebuffers, framebuffer_index );
    //with( meta_renderpass.begin_info ) {
    //    framebuffer     = meta_framebuffers( framebuffer_index );
    //    renderArea      = meta_framebuffers.render_area;
    //    pClearValues    = meta_framebuffers.clear_values.ptr;
    //    clearValueCount = meta_framebuffers.clear_values.length.toUint;
    //}
    return meta_renderpass;
}

/// set members of a VkRenderPassBeginInfo with the corresponding members of a Meta_Framebuffers structure
/// this should be called once if the framebuffer related members of the VkRenderPassBeginInfo are not changing later on
/// or before vkCmdBeginRenderPass to switch framebuffer, render area (hint, see renderAreaOffset/Extent) and clear values
/// Params:
///     render_pass_bi      = reference to a VkRenderPassBeginInfo
///     meta_framebuffers   = reference to the Meta_Framebuffer structure whose framebuffer and resources will be attached
///     framebuffer_length  = the index to select a framebuffer from the member framebuffer array
void attachFramebuffer( META_FB )(
    ref VkRenderPassBeginInfo   render_pass_bi,
    ref META_FB                 meta_framebuffers,
    uint32_t                    framebuffer_index = 0
    ) if( isMultiBuffer!META_FB ) {
    render_pass_bi.framebuffer     = meta_framebuffers( framebuffer_index );
    render_pass_bi.renderArea      = meta_framebuffers.render_area;
    render_pass_bi.pClearValues    = meta_framebuffers.clear_values.ptr;
    render_pass_bi.clearValueCount = meta_framebuffers.clear_values.length.toUint;
}

/// set framebuffer member of a Meta_Renderpass.VkRenderPassBeginInfo with a framebuffer not changing its framebuffer related resources
/// Params:
///     meta_renderpass = reference to a Meta_Renderpass structure holding the VkRenderPassBeginInfo
///     framebuffer     = the VkFramebuffer to attach to VkRenderPassBeginInfo
/// Returns: the passed in Meta_Structure for function chaining
auto ref attachFramebuffer( META_RP )( ref META_RP meta_renderpass, VkFramebuffer framebuffer ) if( isRenderpass!META_RP ) {
    meta_renderpass.begin_info.framebuffer = framebuffer;
    return meta_renderpass;
}

/// set framebuffer member of a VkRenderPassBeginInfo with a framebuffer not changing its framebuffer related resources
/// Params:
///     render_pass_bi  = reference to a VkRenderPassBeginInfo
///     framebuffer     = the VkFramebuffer to attach to VkRenderPassBeginInfo
void attachFramebuffer( ref VkRenderPassBeginInfo render_pass_bi, VkFramebuffer framebuffer ) {
    render_pass_bi.framebuffer = framebuffer;
}


/// initialize the VkFramebuffer and store them in the meta structure
/// Params:
///     meta                = reference to a Meta_Framebuffer or Meta_Framebuffers
///     render_pass         = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
///     framebuffer_extent  = the extent of the framebuffer, this is not(!) the render area
///     image_views         = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
/// Returns: the passed in Meta_Structure for function chaining
auto ref initFramebuffer( META_FB )(
    ref META_FB             meta,
    VkRenderPass            render_pass,
    VkExtent2D              framebuffer_extent,
    VkImageView[]           image_views,
    bool                    destroy_old_clear_values = true,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) if( isSingleBuffer!META_FB ) {
    // assert that meta struct is initialized with a valid vulkan state pointer
    vkAssert( meta.isValid, "Meta_Struct is not initialized with a vulkan state pointer!", file, line, func );

    // if we have some old resources we delete them first
    if( !meta.empty ) meta.destroyResources( destroy_old_clear_values );

    // the framebuffer_extent is not(!) the render_area, but rather a specification of how big the framebuffer is
    // the render area specifies a render able window into this framebuffer
    // this window must also be set as scissors in the VkPipeline
    // here, if no render area was specified use the full framebuffer extent
    if( meta.render_area.extent.width == 0 || meta.render_area.extent.height == 0 )
        meta.renderAreaExtent( framebuffer_extent );

    VkFramebufferCreateInfo framebuffer_create_info = {
        renderPass      : render_pass,                  // this defines render pass COMPATIBILITY
        attachmentCount : image_views.length.toUint,    // must be equal to the attachment count on render pass
        pAttachments    : image_views.ptr,
        width           : framebuffer_extent.width,
        height          : framebuffer_extent.height,
        layers          : 1,
    };

    // create the VkFramebuffer
    meta.device
        .vkCreateFramebuffer( & framebuffer_create_info, meta.allocator, meta.framebuffers.ptr )
        .vkAssert( file, line, func );

    return meta;
}


/// initialize the VkFramebuffer and store it in the meta structure
/// Params:
///     meta                = reference to a Meta_Framebuffer or Meta_Framebuffers
///     meta_renderpass     = the render_pass member is required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses,
///                         additionally framebuffer[0], clear_value and extent are set into the VkRenderPassBeginInfo member
///     framebuffer_extent  = the extent of the render area
///     image_views         = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
/// Returns: the passed in Meta_Structure for function chaining
auto ref initFramebuffer( META_FB )(
    ref META_FB             meta,
    Meta_Renderpass         meta_renderpass,
    VkExtent2D              framebuffer_extent,
    VkImageView[]           image_views,
    bool                    destroy_old_clear_values = true,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) if( isSingleBuffer!META_FB ) {
    meta.initFramebuffer( meta_renderpass.begin_info.renderPass, framebuffer_extent, image_views, destroy_old_clear_values, file, line, func );
    meta_renderpass.attachFramebuffer( meta );
    return meta;
}

alias create = initFramebuffer;


auto createFramebuffer(
    ref Vulkan              vk,
    VkRenderPass            render_pass,
    VkExtent2D              framebuffer_extent,
    VkImageView[]           image_views,
    bool                    destroy_old_clear_values = true,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) {
    Meta_Framebuffer meta = vk;
    return meta.initFramebuffer( render_pass, framebuffer_extent, image_views, destroy_old_clear_values, file, line, func );
}


auto createFramebuffer(
    ref Vulkan              vk,
    Meta_Renderpass         meta_renderpass,
    VkExtent2D              framebuffer_extent,
    VkImageView[]           image_views,
    bool                    destroy_old_clear_values = true,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) {
    Meta_Framebuffer meta = vk;
    return meta.initFramebuffer( meta_renderpass, framebuffer_extent, image_views, destroy_old_clear_values, file, line, func );
}


/// initialize the VkFramebuffer(s) and store them in the meta structure
/// Params:
///     meta                = reference to a Meta_Framebuffer or Meta_Framebuffers
///     render_pass         = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
///     framebuffer_extent  = the extent of the framebuffer, this is not(!) the render area
///     first_image_views   = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
///     dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length]
///     last_image views    = these will be attached to each of the VkFramebuffer(s) attachments first_image_views.length + 1 .. last_image_view_length + 1
/// Returns: the passed in Meta_Structure for function chaining
auto ref initFramebuffers( META_FB, uint32_t max_image_view_count = uint32_t.max )(
    ref META_FB             meta,
    VkRenderPass            render_pass,
    VkExtent2D              framebuffer_extent,
    VkImageView[]           first_image_views,
    VkImageView[]           dynamic_image_views,
    VkImageView[]           last_image_views = [],
    bool                    destroy_old_clear_values = true,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) if( isMultiBuffer!META_FB ) {
    // assert that meta struct is initialized with a valid vulkan state pointer
    vkAssert( meta.isValid, "Meta_Struct is not initialized with a vulkan state pointer!", file, line, func );

    // if we have some old resources we delete them first
    if( !meta.empty ) meta.destroyResources( destroy_old_clear_values );

    // the framebuffer_extent is not(!) the render_area, but rather a specification of how big the framebuffer is
    // the render area specifies a render able window into this framebuffer
    // this window must also be set as scissors in the VkPipeline
    // here, if no render area was specified use the full framebuffer extent
    if( meta.render_area.extent.width == 0 || meta.render_area.extent.height == 0 )
        meta.renderAreaExtent( framebuffer_extent );

    // copy the first image views, add another image for the dynamic image views and then the last image views
    // the dynamic image view will be filled with one of the dynamic_image_viewes in the framebuffer create loop
    uint image_view_count = ( first_image_views.length + 1 + last_image_views.length ).toUint;
    static if( max_image_view_count == uint32_t.max )   auto image_views = sizedArray!VkImageView(   image_view_count );
    else                        auto image_views = sizedArray!( max_image_view_count, VkImageView )( image_view_count );

    foreach( i, image_view; first_image_views ) image_views[ i ] = image_view;
    foreach( i, image_view; last_image_views )  image_views[ first_image_views.length + 1 + i ] = image_view;

    VkFramebufferCreateInfo framebuffer_create_info = {
        renderPass      : render_pass,                      // this defines render pass COMPATIBILITY
        attachmentCount : image_views.length.toUint,        // must be equal to the attachment count on render pass
        pAttachments    : image_views.ptr,
        width           : framebuffer_extent.width,
        height          : framebuffer_extent.height,
        layers          : 1,
    };

    // create a framebuffer per dynamic_image_view (e.g. for each swapchain image view)
    meta.framebuffers.length = dynamic_image_views.length.toUint;
    //foreach( i, ref fb; meta.framebuffers.data ) {
    foreach( i; 0 .. meta.framebuffers.length ) {
        image_views[ first_image_views.length ] = dynamic_image_views[ i ];
        meta.device
            .vkCreateFramebuffer( & framebuffer_create_info, meta.allocator, & meta.framebuffers[ i ] )
            .vkAssert( file, line, func );
    }

    return meta;
}


/// initialize the VkFramebuffer(s) and store them in the meta structure
/// Params:
///     meta                = reference to a Meta_Framebuffer or Meta_Framebuffers
///     meta_renderpass = the render_pass member is required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses,
///                             additionally framebuffer[0], clear_value and extent are set into the VkRenderPassBeginInfo member
///     extent              = the extent of the render area
///     first_image_views   = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
///     dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length]
/// Returns: the passed in Meta_Structure for function chaining
auto ref initFramebuffers( META_RP, META_FB, uint32_t max_image_view_count = uint32_t.max )(
    ref META_FB             meta,
    ref META_RP             meta_renderpass,
    VkExtent2D              framebuffer_extent,
    VkImageView[]           first_image_views,
    VkImageView[]           dynamic_image_views,
    VkImageView[]           last_image_views = [],
    bool                    destroy_old_clear_values = true,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) if( isRenderpass!META_RP && isMultiBuffer!META_FB ) {
    meta.initFramebuffers!( META_FB, max_image_view_count )(
        meta_renderpass.begin_info.renderPass, framebuffer_extent,
        first_image_views, dynamic_image_views, last_image_views,
        destroy_old_clear_values, file, line, func );
    meta_renderpass.attachFramebuffer( meta, 0 );
    return meta;
}

alias create = initFramebuffers;



auto createFramebuffers(
    ref Vulkan      vk,
    VkRenderPass    render_pass,
    VkExtent2D      framebuffer_extent,
    VkImageView[]   first_image_views,
    VkImageView[]   dynamic_image_views,
    VkImageView[]   last_image_views = [],
    bool            destroy_old_clear_values = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) {
    Meta_Framebuffers meta = vk;
    return meta.initFramebuffers(
        render_pass, framebuffer_extent,
        first_image_views, dynamic_image_views, last_image_views,
        destroy_old_clear_values, file, line, func );
}


auto createFramebuffers( META_RP )(
    ref Vulkan              vk,
    ref META_RP             meta_renderpass,
    VkExtent2D              framebuffer_extent,
    VkImageView[]           first_image_views,
    VkImageView[]           dynamic_image_views,
    VkImageView[]           last_image_views = [],
    bool                    destroy_old_clear_values = true,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) if( isRenderpass!META_RP ) {
    Meta_Framebuffers  meta = vk;
    return meta.initFramebuffers(
        meta_renderpass, framebuffer_extent,
        first_image_views, dynamic_image_views, last_image_views,
        destroy_old_clear_values, file, line, func );
}
