module vdrive.renderbuffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;



///////////////////////////////////////
// Meta_Subpass and Meta_Render_Pass //
///////////////////////////////////////

/// struct to collect subpass relevant data
private struct Meta_Subpass_T(
    int32_t input_ref_count,
    int32_t color_ref_count,
    int32_t resolve_ref_count,
    int32_t preserve_ref_count,
    ) {
    alias ir_count = input_ref_count;
    alias cr_count = color_ref_count;
    alias rr_count = resolve_ref_count;
    alias pr_count = preserve_ref_count;

    static assert( resolve_ref_count == 0 || resolve_ref_count == color_ref_count,
        "Template param resolve_ref_count must be either 0 or equal to preserve_ref_count!" );
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

//alias Meta_Subpass = Meta_Subpass_T!( int32_t.max, int32_t.max, int32_t.max, int32_t.max );

enum Subpass_Ref_Type : uint32_t { input, color, resolve, preserve, depth_stencil };


/// private template to constraint template arg to Meta_Graphics or Meta_Compute
private template isRenderPass( T ) { enum isRenderPass = is( typeof( isRenderPassImpl( T.init )));  }
private void isRenderPassImpl( int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, int32_t g, )( Meta_Render_Pass_T!( a, b, c, d, e, f, g ) meta_rp ) {}


/// Wraps the essential Vulkan objects created with the editing procedure
/// of Meta_Render_Pass, all other internal structures are obsolete
/// after construction so that the Meta_Descriptor_Layout can be reused
/// after being reset
struct Core_Render_Pass {
    VkRenderPassBeginInfo           render_pass_bi;     // the actual render pass is stored in a member of this struct
    ref VkRenderPass                render_pass() { return render_pass_bi.renderPass; }
    // Todo(pp): Why does mixing in the template result in: Error: need 'this' for 'renderPass' of type 'VkRenderPass_handle*' ?
//  mixin     Is_Null_Constructed!( render_pass_bi.renderPass );
    bool is_null()         { return render_pass_bi.renderPass == VK_NULL_HANDLE; }
    bool is_constructed()  { return render_pass_bi.renderPass != VK_NULL_HANDLE; }

}


/// destroy all wrapped Vulkan objects
/// Params:
///     vk      = Vulkan state struct holding the device through which these resources were created
///     core    = the wrapped VkDescriptorPool ( with it the VkDescriptorSet ) and the VkDescriptorSetLayout to destroy
/// Returns: this reference for function chaining
void destroy( ref Vulkan vk, ref Core_Render_Pass core ) {
    vdrive.state.destroy( vk, core.render_pass );          // no nice syntax, vdrive.state.destroy overloads
}


struct Meta_Render_Pass_T(
    int32_t attachment_count,
    int32_t dependency_count,
    int32_t subpass_count,
    int32_t max_input_ref_count,
    int32_t max_color_ref_count,
    int32_t max_resolve_ref_count,
    int32_t max_preserve_ref_count,
    ) {
    mixin                           Vulkan_State_Pointer;
    ref VkRenderPass                render_pass() { return render_pass_bi.renderPass; }
    VkRenderPassBeginInfo           render_pass_bi;     // the actual render pass is stored in a member of this struct
    alias Subpass_T = Meta_Subpass_T!(
        max_input_ref_count,
        max_color_ref_count,
        max_resolve_ref_count,
        max_preserve_ref_count );

    private Subpass_T*              subpass;
    private VkSubpassDependency*    subpass_dependency;

    D_OR_S_ARRAY!( attachment_count, VkAttachmentDescription )  attachment_descriptions;
    D_OR_S_ARRAY!( dependency_count, VkSubpassDependency )      subpass_dependencies;
    D_OR_S_ARRAY!( subpass_count, Subpass_T )                   subpasses;


    /// get minimal config for internal D_OR_S_ARRAY
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


    /// reset all internal data and return wrapped Vulkan object
    /// VkRenderPassBeginInfo which holds the VkRenderPass as member
    auto reset() {
        Core_Render_Pass result = { render_pass_bi };
        render_pass_bi = VkRenderPassBeginInfo.init;
        subpass = null; subpass_dependency = null;
        attachment_descriptions.clear;
        subpass_dependencies.clear;
        subpasses.clear;
        return result;
    }


    /// extract core render pass element VkRenderPassBeginInfo with VkRenderPass
    /// without resetting the internal data structures
    auto extractCore() {
        return Core_Render_Pass( render_pass_bi );
    }


    /// get the internal VkRenderPassBeginInfo with VkRenderPass
    auto beginInfo() {
        return render_pass_bi;
    }



    //////////////////////////
    // data massage methods //
    //////////////////////////

    auto ref renderPassAttachment(
        VkFormat                image_format,
        VkSampleCountFlagBits   sample_count,
        VkAttachmentLoadOp      load_op,
        VkAttachmentStoreOp     store_op,
        VkAttachmentLoadOp      stencil_load_op,
        VkAttachmentStoreOp     stencil_store_op,
        VkImageLayout           initial_layout,
        VkImageLayout           final_layout    = VK_IMAGE_LAYOUT_MAX_ENUM
        ) {
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

        attachment_descriptions.append( attachment_description );
        return this;
    }


    auto ref renderPassAttachment(
        VkFormat                image_format,
        VkSampleCountFlagBits   sample_count,
        VkAttachmentLoadOp      load_op,
        VkAttachmentStoreOp     store_op,
        VkImageLayout           initial_layout,
        VkImageLayout           final_layout    = VK_IMAGE_LAYOUT_MAX_ENUM
        ) {
        return renderPassAttachment( image_format, sample_count, load_op, store_op,
            VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
    };


    auto ref renderPassAttachment_Load_None( VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) {
        return renderPassAttachment( image_format, sample_count, VK_ATTACHMENT_LOAD_OP_LOAD, VK_ATTACHMENT_STORE_OP_DONT_CARE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
    };

    auto ref renderPassAttachment_Load_Store( VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) {
        return renderPassAttachment( image_format, sample_count, VK_ATTACHMENT_LOAD_OP_LOAD, VK_ATTACHMENT_STORE_OP_STORE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
    };

    auto ref renderPassAttachment_Clear_None( VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) {
        return renderPassAttachment( image_format, sample_count, VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_DONT_CARE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
    };

    auto ref renderPassAttachment_Clear_Store( VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) {
        return renderPassAttachment( image_format, sample_count, VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
    };

    auto ref renderPassAttachment_None_None( VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) {
        return renderPassAttachment( image_format, sample_count, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
    };

    auto ref renderPassAttachment_None_Store( VkFormat image_format, VkSampleCountFlagBits sample_count, VkImageLayout initial_layout, VkImageLayout final_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) {
        return renderPassAttachment( image_format, sample_count, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_STORE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
    };



    /// add a Meta_Subpass to the subpasses array of Meta_Render_Pass
    /// consecutive subpass related function calls will create resources for this Meta_Structure if no index is specified
    /// Params:
    ///     subpass_description_flags = optionally add a ( currently the only one: VK_ATTACHMENT_DESCRIPTION_MAY_ALIAS_BIT ) flag
    /// Returns: this reference for function chaining
    auto ref addSubpass( VkSubpassDescriptionFlags subpass_description_flags = 0 ) {
        subpasses.length = subpasses.length + 1;
        subpass = & subpasses[ $-1 ];
        subpass.flags = subpass_description_flags;
        return this;
    }



    auto ref subpassReference(
        Subpass_Ref_Type    ref_type,
        uint32_t            attachment_index,
        VkImageLayout       render_layout = VK_IMAGE_LAYOUT_MAX_ENUM
        ) {
        if( subpasses.length == 0 )
            addSubpass;

        VkAttachmentReference attachment_reference = {
            attachment  : ( attachment_descriptions.length - 1 ).toUint,
            layout      : render_layout == VK_IMAGE_LAYOUT_MAX_ENUM ? attachment_descriptions[ $-1 ].initialLayout : render_layout,
        };

        // if attachment_descriptions[ $-1 ].finalLayout is VK_IMAGE_LAYOUT_MAX_ENUM this means it is supposed to be the same as render_layout
        if( attachment_descriptions[ $-1 ].finalLayout == VK_IMAGE_LAYOUT_MAX_ENUM )
            attachment_descriptions[ $-1 ].finalLayout = attachment_reference.layout;

        final switch( ref_type ) {
            case Subpass_Ref_Type.input           : subpass.input_reference.append( attachment_reference );      break;
            case Subpass_Ref_Type.color           : subpass.color_reference.append( attachment_reference );      break;
            case Subpass_Ref_Type.resolve         : subpass.resolve_reference.append( attachment_reference );    break;
            case Subpass_Ref_Type.preserve        : subpass.preserve_reference.append( attachment_reference );   break;
            case Subpass_Ref_Type.depth_stencil   : subpass.depth_stencil_reference = attachment_reference;      break;
        }

        return this;
    }


    auto ref subpassRefInput(        uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.input,         attachment_index, render_layout ); }
    auto ref subpassRefColor(        uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.color,         attachment_index, render_layout ); }
    auto ref subpassRefResolve(      uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.resolve,       attachment_index, render_layout ); }
    auto ref subpassRefPreserve(     uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.preserve,      attachment_index, render_layout ); }
    auto ref subpassRefDepthStencil( uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.depth_stencil, attachment_index, render_layout ); }


    // cannot use subpassReference as function overload as aliases bellow cannot be set for function overloads with different args
    auto ref subpassReference( Subpass_Ref_Type ref_type, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert an attachment description was added at least once
        vkAssert( attachment_descriptions.length > 0, "No attachment description has been added so far", file, line, func );
        return subpassReference( ref_type, toUint( attachment_descriptions.length - 1 ), render_layout );
    }


    auto ref subpassRefInput(        VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.input,         toUint( attachment_descriptions.length - 1 ), render_layout ); }
    auto ref subpassRefColor(        VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.color,         toUint( attachment_descriptions.length - 1 ), render_layout ); }
    auto ref subpassRefResolve(      VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.resolve,       toUint( attachment_descriptions.length - 1 ), render_layout ); }
    auto ref subpassRefPreserve(     VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.preserve,      toUint( attachment_descriptions.length - 1 ), render_layout ); }
    auto ref subpassRefDepthStencil( VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) { return subpassReference( Subpass_Ref_Type.depth_stencil, toUint( attachment_descriptions.length - 1 ), render_layout ); }


    /// add a VkSubpassDependency to the subpass_dependencies array of Meta_Render_Pass
    /// consecutive subpass related function calls will create data for this VkSubpassDependency if no index is specified
    /// Returns: this reference for function chaining
    auto ref addDependency(
        uint32_t                src_subpass,
        VkPipelineStageFlags    src_stage_mask,
        VkAccessFlags           src_access_mask,
        uint32_t                dst_subpass,
        VkPipelineStageFlags    dst_stage_mask,
        VkAccessFlags           dst_access_mask,
        VkDependencyFlags       dependency_flags = 0
        ) {
        subpass_dependencies.length = subpass_dependencies.length + 1;
        subpass_dependency = & subpass_dependencies[ $-1 ];
        with( subpass_dependency ) {
            srcSubpass      = src_subpass;
            dstSubpass      = dst_subpass;
            srcStageMask    = src_stage_mask;
            dstStageMask    = dst_stage_mask;
            srcAccessMask   = src_access_mask;
            dstAccessMask   = dst_access_mask;
            dependencyFlags = dependency_flags;
        }
        return this;
    }


    /// add a VkSubpassDependency to the subpass_dependencies array of Meta_Render_Pass
    /// consecutive subpass related function calls will create data for this VkSubpassDependency if no index is specified
    /// Returns: this reference for function chaining
    auto ref addDependency( VkDependencyFlags dependency_flags = 0 ) {
        subpass_dependencies.length = subpass_dependencies.length + 1;
        subpass_dependency = & subpass_dependencies[ $-1 ];
        subpass_dependency.dependencyFlags = dependency_flags;
        return this;
    }


    /// set the source subpass dependencies of the last added dependency item
    /// Params:
    ///     subpass = the source subpass
    ///     stage_mask = the source stage mask
    ///     access_mask = the source access mask
    /// Returns: this reference for function chaining
    auto ref srcDependency( uint32_t subpass, VkPipelineStageFlags stage_mask, VkAccessFlags access_mask, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert an attachment description was added at least once
        vkAssert( attachment_descriptions.length > 0, "No attachment description has been added so far", file, line, func );
        with( subpass_dependencies[ $-1 ] ) {
            srcSubpass      = subpass;
            srcStageMask    = stage_mask;
            srcAccessMask   = access_mask;
        }
        return this;
    }


    /// set the destination subpass dependencies of the last added dependency item
    /// Params:
    ///     subpass = the destination subpass
    ///     stage_mask = the destination stage mask
    ///     access_mask = the destination access mask
    /// Returns: this reference for function chaining
    auto ref dstDependency( uint32_t subpass, VkPipelineStageFlags stage_mask, VkAccessFlags access_mask, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert an attachment description was added at least once
        vkAssert( attachment_descriptions.length > 0, "No attachment description has been added so far", file, line, func );
        with( subpass_dependencies[ $-1 ] ) {
            dstSubpass      = subpass;
            dstStageMask    = stage_mask;
            dstAccessMask   = access_mask;
        }
        return this;
    }


    /// set the subpass dependencies of the last added dependency item
    /// Params:
    ///     source = the source subpass
    ///     destination = the destination subpass
    /// Returns: this reference for function chaining
    auto ref subpassDependency( uint32_t source, uint32_t destination, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert an attachment description was added at least once
        vkAssert( attachment_descriptions.length > 0, "No attachment description has been added so far", file, line, func );
        with( subpass_dependencies[ $-1 ] ) {
            srcSubpass = source;
            dstSubpass = destination;
        }
        return this;
    }


    /// set the stage mask dependencies of the last added dependency item
    /// Params:
    ///     source = the source stage mask
    ///     destination = the destination stage mask
    /// Returns: this reference for function chaining
    auto ref stageMaskDependency( VkPipelineStageFlags source, VkPipelineStageFlags destination, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert an attachment description was added at least once
        vkAssert( attachment_descriptions.length > 0, "No attachment description has been added so far", file, line, func );
        with( subpass_dependencies[ $-1 ] ) {
            srcStageMask = source;
            dstStageMask = destination;
        }
        return this;
    }


    /// set the access mask dependencies of the last added dependency item
    /// Params:
    ///     source = the source access mask
    ///     destination = the destination access mask
    /// Returns: this reference for function chaining
    auto ref accessMaskDependency( VkAccessFlags source, VkAccessFlags destination, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert an attachment description was added at least once
        vkAssert( attachment_descriptions.length > 0, "No attachment description has been added so far", file, line, func );
        with( subpass_dependencies[ $-1 ] ) {
            srcAccessMask = source;
            dstAccessMask = destination;
        }
        return this;
    }


    /// set clear values into the render pass begin info
    /// usage of either this function or attachFramebuffer(s) is required to set clear values for the later used VkRenderPassBeginInfo
    /// Params:
    ///     clear_values = will be set into the meta render pass VkRenderPassBeginInfo. Storage must be managed outside
    /// Returns: this reference for function chaining
    auto ref clearValues( Array_T )( ref Array_T clear_values ) if( isDataArray!( Array_T, VkClearValue ) || is( Array_T : VkClearValue[] )) {
        render_pass_bi.pClearValues = clear_values.ptr;
        render_pass_bi.clearValueCount = clear_values.length.toUint;
        return this;
    }

    // TODO(pp): not having a depth attachment does not work. Fix it!

    /// construct a VkRenderPass from specified resources of Meta_Render_Pass structure and store it there as well
    /// Params:
    /// Returns: this reference for function chaining
    auto ref construct( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Meta_Struct not initialized with a vulkan state pointer", file, line, func );

        // extract VkSubpassDescription from Meta_Subpass
        auto subpass_descriptions = sizedArray!( subpass_count, VkSubpassDescription )( subpasses.length );
        foreach( i, ref subpass; subpasses.data ) {

            // assert that resolve references length is less or equal to color references length
            // do nothing if resolve references length is 0, but if reference length is strictly less then color reference length
            // fill resolve reference length with VkAttachmentReference( VK_ATTACHMENT_UNUSED, layout arbitrary )
            vkAssert( subpass.resolve_reference.length <= subpass.color_reference.length, "Resolve reference count must be less or equal to color reference count", file, line, func );

            // We need this static if here as Empty_Array has no opSlice operator
            // An Empty_Arry is used when subpass.resolve_ref_count is zero
            static if( subpass.rr_count > 0 ) {
                if( subpass.resolve_reference.length < subpass.color_reference.length ) {
                    auto old_length = subpass.resolve_reference.length;
                    subpass.resolve_reference.length = subpass.color_reference.length;
                    subpass.resolve_reference[ old_length .. subpass.resolve_reference.length ] = VkAttachmentReference( VK_ATTACHMENT_UNUSED, VK_IMAGE_LAYOUT_UNDEFINED );
                }
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


        // use the new subpass_descriptions array to create the VkRenderPass
        VkRenderPassCreateInfo render_pass_create_info = {
            attachmentCount : attachment_descriptions.length.toUint,
            pAttachments    : attachment_descriptions.ptr,
            subpassCount    : subpass_descriptions.length.toUint,
            pSubpasses      : subpass_descriptions.ptr,
            dependencyCount : subpass_dependencies.length.toUint,
            pDependencies   : subpass_dependencies.ptr,
        };

        vkCreateRenderPass( device, & render_pass_create_info, allocator, & render_pass_bi.renderPass ).vkAssert;
        return this;
    }



    /// set members of this.render_pass_bi with the corresponding members of a Meta_Framebuffer (multi) structure
    /// this should be called once if the framebuffer related members of the VkRenderPassBeginInfo are not changing later on
    /// or before vkCmdBeginRenderPass to switch framebuffer, render area (hint, see renderAreaOffset/Extent) and clear values
    /// Params:
    ///     meta_framebuffers = reference to the Meta_Framebuffer structure whose framebuffer and resources will be attached
    ///     framebuffer_length = the index to select a framebuffer from the member framebuffer array
    /// Returns: this reference for function chaining
    auto ref attachFramebuffer( META_FB )( ref META_FB meta_framebuffer, uint32_t framebuffer_index = 0 ) if( isMultiBuffer!META_FB ) {
        meta_framebuffer.attachToRenderPassBI( render_pass_bi, framebuffer_index );
        return this;
    }



    /// set framebuffer member of a Meta_Render_Pass.VkRenderPassBeginInfo with a framebuffer not changing its framebuffer related resources
    /// Params:
    ///     framebuffer     = the VkFramebuffer to attach to VkRenderPassBeginInfo
    /// Returns: this reference for function chaining
    auto ref attachFramebuffer( VkFramebuffer framebuffer ) {
        render_pass_bi.framebuffer = framebuffer;
        return this;
    }
}

// Todo(pp): investigate error when the last 4 entries are also set to int32_t.max we get errors about Meta_Subpass not being copyable
// the alias bellow should not be able to trigger any kind of copy operation which we, nonetheless, get informed about
alias Meta_Render_Pass = Meta_Render_Pass_T!( int32_t.max, int32_t.max, int32_t.max, 16, 16, 16, 16 );


//////////////////////
// Meta_Framebuffer //
//////////////////////

// Todo(pp): do we really require Multi Framebuffer after split off? An array of simple framebuffer should work as well with a free function
//           and/or mixin template for attaching first, dynamic and last image views
//           Update: implemented, needs additional testing. Moreover free functions must also work if we use an array of Frame_Resource with Frame_Resource.framebuffer

deprecated( "Use (array of) VkFramebuffer in combination with free functions and UFCS instead." )
struct Meta_Framebuffer_T( int32_t framebuffer_count = 1, int32_t clear_value_count = int32_t.max ) {
    static assert( framebuffer_count != 0, "Count of framebuffers must not be 0!" );
    mixin Vulkan_State_Pointer                  vulkan_state_pointer;

    // required for template functions
    alias fb_count = framebuffer_count;
    alias cv_count = clear_value_count;

    VkRect2D                                    render_area;
    D_OR_S_ARRAY!( fb_count, VkFramebuffer )    framebuffers;
    D_OR_S_ARRAY!( cv_count, VkClearValue )     clear_values;

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
        foreach( fb; framebuffers )
            vdrive.state.destroy( vk, fb );
        framebuffers.clear;

        // optionally destroy clear values, default is destroy them
        static if( cv_count > 0 ) if( destroy_clear_values ) clear_values.clear;
    }


    /// set attachment specific (framebuffer attachment index) r, g, b, a clear value
    /// The type of all values must be the same and either float, int32_t or uint32_t
    /// Params:
    ///     index   = framebuffer attachment index
    ///     r       = red clear value
    ///     g       = green clear value
    ///     b       = blue clear value
    ///     a       = alpha clear value
    /// Returns: this reference for function chaining
    auto ref setClearValue( T )( uint32_t index, T r, T g, T b, T a, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__
        ) if( is( T == float ) || is( T == int32_t ) || is( T == uint32_t )) {
        T[4] rgba = [ r, g, b, a ];
        return setClearValue( index, rgba, file, line, func );
    }


    /// set attachment specific (framebuffer attachment index) rgba clear value array or math vector (e.g. dlsl)
    /// The element type must be either float, int32_t or uint32_t
    /// Params:
    ///     index   = framebuffer attachment index
    ///     rgba    = the rgba clear value as array or four component math vector
    /// Returns: this reference for function chaining
    auto ref setClearValue( T )( uint32_t index, T[4] rgba, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__
        ) if( is( T == float ) || is( T == int32_t ) || is( T == uint32_t )) {
        VkClearValue clear_value;
             static if( is( T == float ))    clear_value.color.float32 = rgba;
        else static if( is( T == int32_t ))  clear_value.color.int32   = rgba;
        else static if( is( T == uint32_t )) clear_value.color.uint32  = rgba;
        return setClearValue( index, clear_value, file, line, func );
    }


    /// set attachment specific (framebuffer attachment index) depth-stencil clear value
    /// Stencil value defaults to 0
    /// Params:
    ///     index   = framebuffer attachment index
    ///     depth   = the depth clear value
    ///     stencil = the stencil clear value, defaults to 0
    /// Returns: this reference for function chaining
    auto ref setClearValue( UINT32_T )( uint32_t index, float depth, UINT32_T stencil = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__
        ) if( is( UINT32_T : uint32_t )) {
        VkClearValue clear_value = { depthStencil : VkClearDepthStencilValue( depth, stencil ) };
        return setClearValue( index, clear_value, file, line, func );
    }


    /// set attachment specific (framebuffer attachment index) VkClearValue
    /// Stencil value defaults to 0
    /// Params:
    ///     index       = framebuffer attachment index
    ///     clear_value = the VkClearValue clear value
    /// Returns: this reference for function chaining
    auto ref setClearValue( uint32_t index, VkClearValue clear_value, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( index < clear_values.length, "Index out of bounds. Resize the array clear_values array first if possible", file, line, func );
        clear_values[ index ] = clear_value;
        return this;
    }


    /// add (append) attachment specific (framebuffer attachment index) r, g, b, a clear value
    /// The type of all values must be the same and either float, int32_t or uint32_t
    /// Params:
    ///     r       = red clear value
    ///     g       = green clear value
    ///     b       = blue clear value
    ///     a       = alpha clear value
    /// Returns: this reference for function chaining
    auto ref addClearValue( T )( T r, T g, T b, T a ) if( is( T == float ) || is( T == int32_t ) || is( T == uint32_t )) {
        T[4] rgba = [ r, g, b, a ];
        return addClearValue( rgba );
    }


    /// add (append) attachment specific (framebuffer attachment index) rgba clear value array or math vector (e.g. dlsl)
    /// The element type must be either float, int32_t or uint32_t
    /// Params:
    ///     rgba    = the rgba clear value as array or four component math vector
    /// Returns: this reference for function chaining
    auto ref addClearValue( T )( T[4] rgba ) if( is( T == float ) || is( T == int32_t ) || is( T == uint32_t )) {
        VkClearValue clear_value;
             static if( is( T == float ))    clear_value.color.float32 = rgba;
        else static if( is( T == int32_t ))  clear_value.color.int32   = rgba;
        else static if( is( T == uint32_t )) clear_value.color.uint32  = rgba;
        return addClearValue( clear_value );
    }


    /// add (append) attachment specific (framebuffer attachment index) depth-stencil clear value
    /// Stencil value defaults to 0
    /// Params:
    ///     depth   = the depth clear value
    ///     stencil = the stencil clear value, defaults to 0
    /// Returns: this reference for function chaining
    auto ref addClearValue( UINT32_T )( float depth, UINT32_T stencil = 0 ) if( is( UINT32_T : uint32_t )) {
        VkClearValue clear_value = { depthStencil : VkClearDepthStencilValue( depth, stencil ) };
        return addClearValue( clear_value );
    }


    /// add (append) attachment specific (framebuffer attachment index) VkClearValue
    /// Params:
    ///     clear_value = the VkClearValue clear value
    /// Returns: this reference for function chaining
    auto ref addClearValue( VkClearValue clear_value ) {
        clear_values.append( clear_value );
        return this;
    }


    /// set the render area offset separate from the extent
    /// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
    /// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
    /// Params:
    ///     offset  = the offset of the render area
    /// Returns: this reference for function chaining
    auto ref renderAreaOffset( VkOffset2D offset ) {
        render_area.offset = offset;
        return this;
    }


    /// set the render area offset separate from the extent
    /// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
    /// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
    /// Params:
    ///     x       = the offset of the render area in x
    ///     y       = the offset of the render area in y
    /// Returns: this reference for function chaining
    auto ref renderAreaOffset( int32_t x, int32_t y ) {
        return renderAreaOffset( VkOffset2D( x, y ));
    }


    /// set the render area extent separate from the offset
    /// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
    /// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
    /// Params:
    ///     extent  = the extent of the render area
    /// Returns: this reference for function chaining
    auto ref renderAreaExtent( VkExtent2D extent ) {
        render_area.extent = extent;
        return this;
    }


    /// set the render area extent separate from the offset
    /// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
    /// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
    /// Params:
    ///     width   = the width of the render area
    ///     height  = the height of the render area
    /// Returns: this reference for function chaining
    auto ref renderAreaExtent( uint32_t width, uint32_t height ) {
        return renderAreaExtent( VkExtent2D( width, height ));
    }


    /// set the render area
    /// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
    /// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
    /// Params:
    ///     area    = the render area
    /// Returns: this reference for function chaining
    auto ref renderArea( VkRect2D area ) {
        render_area = area;
        return this;
    }


    /// set the render area
    /// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
    /// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
    /// Params:
    ///     offset  = the offset of the render area
    ///     extent  = the extent of the render area
    /// Returns: this reference for function chaining
    auto ref renderAreaExtent( VkOffset2D offset, VkExtent2D extent ) {
        return renderArea( VkRect2D( offset, extent ));
    }


    /// set the render area
    /// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
    /// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
    /// Params:
    ///     x       = the offset of the render area in x
    ///     y       = the offset of the render area in y
    ///     width   = the width of the render area
    ///     height  = the height of the render area
    /// Returns: this reference for function chaining
    auto ref renderAreaExtent( int32_t x, int32_t y, uint32_t width, uint32_t height ) {
        return renderArea( VkRect2D( VkOffset2D( x, y ), VkExtent2D( width, height )));
    }



    //////////////////////////////////////////////////
    // connect Meta_Framebuffer to Meta_Render_Pass //
    //////////////////////////////////////////////////

    /// set members of a VkRenderPassBeginInfo with the corresponding members of this structure
    /// this should be called once if the framebuffer related members of the VkRenderPassBeginInfo are not changing later on
    /// or before vkCmdBeginRenderPass to switch framebuffer, render area (hint, see renderAreaOffset/Extent) and clear values
    /// Params:
    ///     render_pass_bi      = reference to a VkRenderPassBeginInfo
    ///     framebuffer_length  = the index to select a framebuffer from the member framebuffer array
    //static if( fb_count == 1 ) {
    //    void attachToRenderPassBI( ref VkRenderPassBeginInfo render_pass_bi ) {
    //        render_pass_bi.framebuffer      = framebuffer;
    //        render_pass_bi.renderArea       = render_area;
    //        render_pass_bi.pClearValues     = clear_values.ptr;
    //        render_pass_bi.clearValueCount  = clear_values.length.toUint;
    //    }
    //} else {
    void attachToRenderPassBI( ref VkRenderPassBeginInfo render_pass_bi, uint32_t framebuffer_index = 0 ) {
        render_pass_bi.framebuffer      = framebuffers[ framebuffer_index ];
        render_pass_bi.renderArea       = render_area;
        render_pass_bi.pClearValues     = clear_values.ptr;
        render_pass_bi.clearValueCount  = clear_values.length.toUint;
    }
    //}


    /// construct the internal VkFramebuffer
    /// Params:
    ///     render_pass         = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
    ///     framebuffer_extent  = the extent of the framebuffer, this is not(!) the render area
    ///     image_views         = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
    /// Returns: this reference for function chaining
    auto ref construct(
        VkRenderPass            render_pass,
        VkExtent2D              framebuffer_extent,
        VkImageView[]           image_views,
        bool                    destroy_old_clear_values = true,
        string                  file = __FILE__,
        size_t                  line = __LINE__,
        string                  func = __FUNCTION__

        ) {

        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Meta_Struct not initialized with a vulkan state pointer", file, line, func );

        // if we have some old resources we delete them first
        if( !empty ) destroyResources( destroy_old_clear_values );

        // the framebuffer_extent is not(!) the render_area, but rather a specification of how big the framebuffer is
        // the render area specifies a render able window into this framebuffer
        // this window must also be set as scissors in the VkPipeline
        // here, if no render area was specified use the full framebuffer extent
        if( render_area.extent.width == 0 || render_area.extent.height == 0 )
            renderAreaExtent( framebuffer_extent );

        VkFramebufferCreateInfo framebuffer_ci = {
            renderPass      : render_pass,                  // this defines render pass COMPATIBILITY
            attachmentCount : image_views.length.toUint,    // must be equal to the attachment count on render pass
            pAttachments    : image_views.ptr,
            width           : framebuffer_extent.width,
            height          : framebuffer_extent.height,
            layers          : 1,
        };

        // create the VkFramebuffer
        device.vkCreateFramebuffer( & framebuffer_ci, allocator, framebuffers.ptr ).vkAssert( "Construct Framebuffer", file, line, func );
        return this;
    }


    /// construct the internal VkFramebuffer(s), internally a D_OR_S_ARRAY is used to merge passed in image views into one array
    /// with the template argument max_attachment_count the allocation strategy can be specified. This approach will be enhanced with using
    /// a Block_Array, borrowing scratch storage managed via Vulkan_State
    /// Params:
    ///     max_attachment_count    = template arg to specify allocation strategy temporary D_OR_S_ARRAY (reordering passed in image views)
    ///     render_pass         = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
    ///     framebuffer_extent  = the extent of the framebuffer, this is not(!) the render area
    ///     first_image_views   = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
    ///     dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length]
    ///     last_image views    = these will be attached to each of the VkFramebuffer(s) attachments first_image_views.length + 1 .. last_image_view_length + 1
    ///     destroy_old_clear_values = should old clear_values be destroyed, and the corresponding array set to length zero
    /// Returns: this reference for function chaining
    auto ref construct( int32_t max_attachment_count )(
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
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Meta_Struct not initialized with a vulkan state pointer", file, line, func );

        // if we have some old resources we delete them first
        if( !empty ) destroyResources( destroy_old_clear_values );

        // the framebuffer_extent is not(!) the render_area, but rather a specification of how big the framebuffer is
        // the render area specifies a render able window into this framebuffer
        // this window must also be set as scissors in the VkPipeline
        // here, if no render area was specified use the full framebuffer extent
        if( render_area.extent.width == 0 || render_area.extent.height == 0 )
            renderAreaExtent( framebuffer_extent );

        // copy the first image views, add another image for the dynamic image views and then the last image views
        // the dynamic image view will be filled with one of the dynamic_image_views in the framebuffer create loop
        uint image_view_count = ( first_image_views.length + 1 + last_image_views.length ).toUint;
        auto image_views = sizedArray!( max_attachment_count, VkImageView )( image_view_count );

        foreach( i, image_view; first_image_views ) image_views[ i ] = image_view;
        foreach( i, image_view; last_image_views )  image_views[ first_image_views.length + 1 + i ] = image_view;

        VkFramebufferCreateInfo framebuffer_ci = {
            renderPass      : render_pass,                      // this defines render pass COMPATIBILITY
            attachmentCount : image_views.length.toUint,        // must be equal to the attachment count on render pass
            pAttachments    : image_views.ptr,
            width           : framebuffer_extent.width,
            height          : framebuffer_extent.height,
            layers          : 1,
        };

        // create a framebuffer per dynamic_image_view (e.g. for each swapchain image view)
        framebuffers.length = dynamic_image_views.length.toUint;
        //foreach( i, ref fb; meta.framebuffers.data ) {
        foreach( i; 0 .. framebuffers.length ) {
            image_views[ first_image_views.length ] = dynamic_image_views[ i ];
            device.vkCreateFramebuffer( & framebuffer_ci, allocator, & framebuffers[ i ] ).vkAssert( "Construct Framebuffers", file, line, func );
        }

        return this;
    }


    /// construct the internal VkFramebuffer(s), non-template overload using a Dynamic_Array internally (see above), simply forwarding to template one
    /// Params:
    ///     render_pass         = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
    ///     framebuffer_extent  = the extent of the framebuffer, this is not(!) the render area
    ///     first_image_views   = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
    ///     dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length]
    ///     last_image views    = these will be attached to each of the VkFramebuffer(s) attachments first_image_views.length + 1 .. last_image_view_length + 1
    ///     destroy_old_clear_values = should old clear_values be destroyed, and the corresponding array set to length zero
    /// Returns: this reference for function chaining
    auto ref construct()(
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
        return construct!( int.max )(
            render_pass, framebuffer_extent, first_image_views, dynamic_image_views, last_image_views, destroy_old_clear_values,
            file, line, func
        );
    }


    /// construct the internal VkFramebuffer(s), cannot use template param here as the struct itself is a template already
    /// Params:
    ///     vk = reference to a VulkanState struct
    ///     render_pass         = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
    ///     framebuffer_extent  = the extent of the framebuffer, this is not(!) the render area
    ///     first_image_views   = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
    ///     dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length]
    ///     last_image views    = these will be attached to each of the VkFramebuffer(s) attachments first_image_views.length + 1 .. last_image_view_length + 1
    ///     destroy_old_clear_values = should old clear_values be destroyed, and the corresponding array set to length zero
    /// Returns: this reference for function chaining
    this(
        ref Vulkan      vk,
        VkRenderPass    render_pass,
        VkExtent2D      framebuffer_extent,
        VkImageView[]   first_image_views,
        VkImageView[]   dynamic_image_views,
        VkImageView[]   last_image_views = [],
        string          file = __FILE__,
        size_t          line = __LINE__,
        string          func = __FUNCTION__
        ) {
        this.vk = vk;
        // in a constructor we assume that clear_values are empty, hence if any existed before we always destroy them first
        construct!( int.max )( render_pass, framebuffer_extent, first_image_views, dynamic_image_views, last_image_views, true, file, line, func );
    }

    // mixed in constructor is not woking but can be made working with the following line:
    // source: http://arsdnet.net/this-week-in-d/2016-feb-07.html
    alias __ctor = vulkan_state_pointer.__ctor;
}


alias Meta_FB = Meta_Framebuffer_T;
alias Meta_Framebuffer  = Meta_Framebuffer_T!( 1, int32_t.max );
alias Meta_Framebuffers = Meta_Framebuffer_T!( int32_t.max, int32_t.max );

/// If T is a vector, this evaluates to true, otherwise false
private template isSingleBuffer( T )  {  enum isSingleBuffer = is( typeof( isSingleBufferImpl( T.init ))); }
private void isSingleBufferImpl( uint cv_count )( Meta_Framebuffer_T!( 1, cv_count ) meta ) {}

private template isMultiBuffer( T )  {  enum isMultiBuffer = is( typeof( isMultiBufferImpl( T.init ))); }
private void isMultiBufferImpl( uint fb_count, uint cv_count )( Meta_Framebuffer_T!( fb_count, cv_count ) meta ) {}



/// factory function so that we can parametrize the Meta_Struct, its temporary construction storage and initialization parameters in on go
/// Params:
//      framebuffer_count       = template arg to specify struct count of framebuffers allocation strategy
//      clear_value_count       = template arg to specify struct count of clear values allocation strategy
//      max_attachment_count    = template arg to specify temporary storage allocation strategy
///     vk = reference to a VulkanState struct
///     render_pass         = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
///     framebuffer_extent  = the extent of the framebuffer, this is not(!) the render area
///     first_image_views   = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
///     dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length]
///     last_image views    = these will be attached to each of the VkFramebuffer(s) attachments first_image_views.length + 1 .. last_image_view_length + 1
///     destroy_old_clear_values = should old clear_values be destroyed, and the corresponding array set to length zero
/// Returns: this reference for function chaining
auto createFramebuffer(
    int32_t framebuffer_count,
    int32_t clear_value_count = int32_t.max,
    int32_t max_attachment_count = int32_t.max
    )(
    ref Vulkan      vk,
    VkRenderPass    render_pass,
    VkExtent2D      framebuffer_extent,
    VkImageView[]   first_image_views,
    VkImageView[]   dynamic_image_views,
    VkImageView[]   last_image_views = [],
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) {
    auto result = Meta_Framebuffer_T!( framebuffer_count, clear_value_count )( vk ); // does not work, bug?
    result.construct!max_attachment_count( render_pass, framebuffer_extent, first_image_views, dynamic_image_views, last_image_views );
    return result;
}


private template isClearValueType( T ) { enum isClearValueType = is( T == float ) || is( T == int32_t ) || is( T == uint32_t ); }


/// set attachment specific (framebuffer attachment index) r, g, b, a clear value
/// The type of all values must be the same and either float, int32_t or uint32_t
/// Params:
///     clear_values    = clear values array which will be mutated
///     index           = array index as well as framebuffer attachment index of attachment to apply this clear values
///     r               = red clear value
///     g               = green clear value
///     b               = blue clear value
///     a               = alpha clear value
/// Returns: reference to clear_vaues for function chaining
auto ref set( Array_T, T )(
    ref Array_T     clear_values,
    uint32_t        index,
    T               r,
    T               g,
    T               b,
    T               a,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isDataArrayOrSlice!( Array_T, VkClearValue ) && isClearValueType!T ) {

    T[4] rgba = [ r, g, b, a ];
    return set( clear_values, index, rgba, file, line, func );
}


/// set attachment specific (framebuffer attachment index) rgba clear value array or math vector (e.g. dlsl)
/// The element type must be either float, int32_t or uint32_t
/// Params:
///     clear_values    = clear values array which will be mutated
///     index           = array index as well as framebuffer attachment index of attachment to apply this clear values
///     rgba            = the rgba clear value as array or four component math vector
/// Returns: reference to clear_vaues for function chaining
auto ref set( Array_T, T )(
    ref Array_T     clear_values,
    uint32_t        index,
    T[4]            rgba,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isDataArrayOrSlice!( Array_T, VkClearValue ) && isClearValueType!T ) {

    VkClearValue clear_value;
         static if( is( T == float ))    clear_value.color.float32 = rgba;
    else static if( is( T == int32_t ))  clear_value.color.int32   = rgba;
    else static if( is( T == uint32_t )) clear_value.color.uint32  = rgba;
    return set( clear_values, index, clear_value, file, line, func );
}


/// set attachment specific (framebuffer attachment index) depth-stencil clear value
/// Stencil value defaults to 0
/// Params:
///     clear_values    = clear values array which will be mutated
///     index           = array index as well as framebuffer attachment index of attachment to apply this clear values
///     depth           = the depth clear value
///     stencil         = optional stencil clear value, defaults to 0
/// Returns: reference to clear_vaues for function chaining
auto ref set( Array_T, UINT32_T )(
    ref Array_T     clear_values,
    uint32_t        index,
    float           depth,
    UINT32_T        stencil = 0,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isDataArrayOrSlice!( Array_T, VkClearValue ) && is(  UINT32_T : uint32_t )) {

    VkClearValue clear_value = { depthStencil : VkClearDepthStencilValue( depth, stencil ) };
    return set( clear_values, index, clear_value, file, line, func );
}


/// set attachment specific (framebuffer attachment index) VkClearValue
/// Stencil value defaults to 0
/// Params:
///     clear_values    = clear values array which will be mutated
///     index           = array index as well as framebuffer attachment index of attachment to apply this clear values
///     clear_value = the VkClearValue clear value
/// Returns: reference to clear_vaues for function chaining
auto ref set( Array_T )(
    ref Array_T     clear_values,
    uint32_t        index,
    VkClearValue    clear_value,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isDataArrayOrSlice!( Array_T, VkClearValue )) {

    vkAssert( index < clear_values.length, "Index out of bounds. Resize the clear_values array first if possible", file, line, func );
    clear_values[ index ] = clear_value;
    return clear_values;
}


/// add (append) attachment specific (framebuffer attachment index) r, g, b, a clear value
/// The type of all values must be the same and either float, int32_t or uint32_t
/// Params:
///     clear_values    = clear values array which will be mutated
///     r               = red clear value
///     g               = green clear value
///     b               = blue clear value
///     a               = alpha clear value
/// Returns: reference to clear_vaues for function chaining
auto ref add( Array_T, T )(
    ref Array_T     clear_values,
    T               r,
    T               g,
    T               b,
    T               a

    ) if( isDataArray!( Array_T, VkClearValue ) && isClearValueType!T ) {

    T[4] rgba = [ r, g, b, a ];
    return add( clear_values, rgba );
}


/// add (append) attachment specific (framebuffer attachment index) rgba clear value array or math vector (e.g. dlsl)
/// The element type must be either float, int32_t or uint32_t
/// Params:
///     clear_values    = clear values array which will be mutated
///     rgba            = the rgba clear value as array or four component math vector
/// Returns: reference to clear_vaues for function chaining
auto ref add( Array_T, T )( ref Array_T clear_values, T[4] rgba ) if( isDataArray!( Array_T, VkClearValue ) && isClearValueType!T ) {
    VkClearValue clear_value;
         static if( is( T == float ))    clear_value.color.float32 = rgba;
    else static if( is( T == int32_t ))  clear_value.color.int32   = rgba;
    else static if( is( T == uint32_t )) clear_value.color.uint32  = rgba;
    return add( clear_values, clear_value );
}


/// add (append) attachment specific (framebuffer attachment index) depth-stencil clear value
/// Stencil value defaults to 0
/// Params:
///     clear_values    = clear values array which will be mutated
///     depth           = the depth clear value
///     stencil         = optional stencil clear value, defaults to 0
/// Returns: reference to clear_vaues for function chaining
auto ref add( Array_T, UINT32_T )( ref Array_T clear_values, float depth, UINT32_T stencil = 0 ) if( isDataArray!( Array_T, VkClearValue ) && is( UINT32_T : uint32_t )) {
    VkClearValue clear_value = { depthStencil : VkClearDepthStencilValue( depth, stencil ) };
    return add( clear_values, clear_value );
}


/// add (append) attachment specific (framebuffer attachment index) VkClearValue
/// Params:
///     clear_values    = clear values array which will be mutated
/// Returns: reference to clear_vaues for function chaining
auto ref add( Array_T )( ref Array_T clear_values, VkClearValue clear_value ) if( isDataArray!( Array_T, VkClearValue )) {
    clear_values.append( clear_value );
    return clear_values;
}



/// attach clear values to a VkRenderPassBeginInfo, the clear values are not consumed and must be kept alive
/// Params:
///     render_pass_bi  = the begin info struct to which clear value get attached
///     clear_values    = clear values array which will be attached
/// Returns: render_pass_bi reference for function chaining
auto ref clearValues( Array_T )( ref VkRenderPassBeginInfo render_pass_bi, ref Array_T clear_values ) if( isDataArrayOrSlice!( Array_T, VkClearValue )) {
    render_pass_bi.pClearValues     = clear_values.ptr;
    render_pass_bi.clearValueCount  = clear_values.length.toUint;
    return render_pass_bi;
}



/// set the render area offset separate from the extent
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     render_pass_bi  = the begin info struct for which the render area offset is specified
///     offset          = the offset of the render area
/// Returns: render_pass_bi reference for function chaining
auto ref renderAreaOffset( ref VkRenderPassBeginInfo render_pass_bi, VkOffset2D offset ) {
    render_pass_bi.renderArea.offset = offset;
    return render_pass_bi;
}


/// set the render area offset separate from the extent
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     render_pass_bi  = the begin info struct for which the render area offset is specified
///     x               = the offset of the render area in x
///     y               = the offset of the render area in y
/// Returns: render_pass_bi reference for function chaining
auto ref renderAreaOffset( ref VkRenderPassBeginInfo render_pass_bi, int32_t x, int32_t y ) {
    return renderAreaOffset( render_pass_bi, VkOffset2D( x, y ));
}


/// set the render area extent separate from the offset
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     render_pass_bi  = the begin info struct for which the render area extent is specified
///     extent          = the extent of the render area
/// Returns: render_pass_bi reference for function chaining
auto ref renderAreaExtent( ref VkRenderPassBeginInfo render_pass_bi, VkExtent2D extent ) {
    render_pass_bi.renderArea.extent = extent;
    return render_pass_bi;
}


/// set the render area extent separate from the offset
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     render_pass_bi  = the begin info struct for which the render area extent is specified
///     width   = the width of the render area
///     height  = the height of the render area
/// Returns: render_pass_bi reference for function chaining
auto ref renderAreaExtent( ref VkRenderPassBeginInfo render_pass_bi, uint32_t width, uint32_t height ) {
    return renderAreaExtent( render_pass_bi, VkExtent2D( width, height ));
}


/// set the render area
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     render_pass_bi  = the begin info struct for which the render area is specified
///     area            = the render area
/// Returns: render_pass_bi reference for function chaining
auto ref renderArea( ref VkRenderPassBeginInfo render_pass_bi, VkRect2D area ) {
    render_pass_bi.renderArea = area;
    return render_pass_bi;
}


/// set the render area
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     render_pass_bi  = the begin info struct for which the render area is specified
///     offset          = the offset of the render area
///     extent          = the extent of the render area
/// Returns: render_pass_bi reference for function chaining
auto ref renderArea( ref VkRenderPassBeginInfo render_pass_bi, VkOffset2D offset, VkExtent2D extent ) {
    return renderArea( render_pass_bi, VkRect2D( offset, extent ));
}


/// set the render area
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
/// for vulkan itself this parameter is just an optimization hint and must be properly set as scissor parameter of VkPipelineViewportStateCreateInfo
/// Params:
///     render_pass_bi  = the begin info struct for which the render area is specified
///     x               = the offset of the render area in x
///     y               = the offset of the render area in y
///     width           = the width of the render area
///     height          = the height of the render area
/// Returns: render_pass_bi reference for function chaining
auto ref renderArea( ref VkRenderPassBeginInfo render_pass_bi, int32_t x, int32_t y, uint32_t width, uint32_t height ) {
    return renderArea( render_pass_bi, VkRect2D( VkOffset2D( x, y ), VkExtent2D( width, height )));
}



/// construct one VkFramebuffer
/// Params:
///     vk          = Vulkan state struct holding the device through which this resource is created
///     render_pass = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
///     width       = framebuffer width, this is not(!) the render area width
///     height      = framebuffer height, this is not(!) the render area height
///     layers      = framebuffer layers, for 3D image attachments
///     image_views = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
/// Returns: a constructed VkFraemebuffer
auto createFramebuffer(
    ref Vulkan      vk,
    VkRenderPass    render_pass,
    uint32_t        width,
    uint32_t        height,
    uint32_t        layers,
    VkImageView[]   image_views,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) {

    VkFramebufferCreateInfo framebuffer_ci = {
        renderPass      : render_pass,                  // this defines render pass COMPATIBILITY
        attachmentCount : image_views.length.toUint,    // must be equal to the attachment count on render pass
        pAttachments    : image_views.ptr,
        width           : width,
        height          : height,
        layers          : layers,
    };

    // create the VkFramebuffer
    VkFramebuffer framebuffer;
    vk.device.vkCreateFramebuffer( & framebuffer_ci, vk.allocator, & framebuffer ).vkAssert( "Create Framebuffer", file, line, func );
    return framebuffer;
}



/// construct one VkFramebuffer, convenience function with implicit layers argument of 1
/// Params:
///     vk          = Vulkan state struct holding the device through which this resource is created
///     render_pass = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
///     width       = framebuffer width, this is not(!) the render area width
///     height      = framebuffer height, this is not(!) the render area height
///     image_views = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
/// Returns: a constructed VkFraemebuffer
auto createFramebuffer( Array_T )(
    ref Vulkan      vk,
    VkRenderPass    render_pass,
    uint32_t        width,
    uint32_t        height,
    VkImageView[]   image_views,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) {
    return vk.createFramebuffer( render_pass, width, height, 1, image_views, file, line, func );
}



/// construct multiple VkFramebuffer, which are stored in out_buffers argument
/// the count of created framebuffers is given through the length of out_buffers argument
/// if any of the elements of out_buffers is already a constructed framebuffer, it will be destroyed and recreated
/// Params:
///     vk                  = Vulkan state struct holding the device through which this resource is created
///     render_pass         = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
///     width               = framebuffer width, this is not(!) the render area width
///     height              = framebuffer height, this is not(!) the render area height
///     layers              = framebuffer layers, for 3D image attachments
///     first_image_views   = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
///     dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length]
///     last_image views    = these will be attached to each of the VkFramebuffer(s) attachments first_image_views.length + 1 .. last_image_view_length + 1
/// Returns: a VkResut enum
VkResult createFramebuffers(
    ref Vulkan      vk,
    VkFramebuffer[] out_buffers,
    VkRenderPass    render_pass,
    uint32_t        width,
    uint32_t        height,
    uint32_t        layers,
    VkImageView[]   first_image_views,
    VkImageView[]   dynamic_image_views,
    VkImageView[]   last_image_views = [],
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) {

    // assert that dynamic image view count is at least as high as framebuffer count
    vkAssert( out_buffers.length <= dynamic_image_views.length, "Dynamic image view count must be at least as high as framebuffer count", file, line, func );

    // copy the first image views, add another image for the dynamic image views and then the last image views
    // the dynamic image view will be filled with one of the dynamic_image_views in the framebuffer create loop
    uint image_view_count = ( first_image_views.length + 1 + last_image_views.length ).toUint;

    // create temporary storage to order image views for buffer attachment
    auto image_views = Block_Array!VkImageView( vk.scratch );
    image_views.length = image_view_count;

    foreach( i, image_view; first_image_views ) image_views[ i ] = image_view;
    foreach( i, image_view; last_image_views )  image_views[ first_image_views.length + 1 + i ] = image_view;

    VkFramebufferCreateInfo framebuffer_ci = {
        renderPass      : render_pass,                      // this defines render pass COMPATIBILITY
        attachmentCount : image_view_count,                 // must be equal to the attachment count on render pass
        pAttachments    : image_views.ptr,
        width           : width,
        height          : height,
        layers          : layers,
    };

    // now attach each dynamic image view to the corresponding slot of one of the out framebuffers
    foreach( i; 0 .. out_buffers.length ) {

        // attach dynamic (swapchain) image view to the current framebuffer
        image_views[ first_image_views.length ] = dynamic_image_views[ i ];

        // destroy existing frame buffer
        import vdrive.state : destroy;
        if( out_buffers[ i ] != VK_NULL_HANDLE )
            vdrive.state.destroy( vk, out_buffers[ i ] );

        // create new framebuffer
        auto vk_result = vk.device.vkCreateFramebuffer( & framebuffer_ci, vk.allocator, & out_buffers[ i ] );

        // check result
        vkAssert( vk_result, "Create Framebuffers", file, line, func );

        // bale out if something went wrong
        if( vk_result != VK_SUCCESS ) return vk_result;
    }

    return VK_SUCCESS;
}



/// construct multiple VkFramebuffer, which are stored in out_buffers argument
/// the count of created framebuffers is given through the length of out_buffers argument
/// if any of the elements of out_buffers is already a constructed framebuffer, it will be destroyed and recreated
/// in this convenience function the layers argument is omitted, and implicitly set to 1
/// Params:
///     vk                  = Vulkan state struct holding the device through which this resource is created
///     render_pass         = required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
///     width               = framebuffer width, this is not(!) the render area width
///     height              = framebuffer height, this is not(!) the render area height
///     layers              = framebuffer layers, for 3D image attachments
///     first_image_views   = these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
///     dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length]
///     last_image views    = these will be attached to each of the VkFramebuffer(s) attachments first_image_views.length + 1 .. last_image_view_length + 1
/// Returns: a VkResut enum
VkResult createFramebuffers(
    ref Vulkan      vk,
    VkFramebuffer[] out_buffers,
    VkRenderPass    render_pass,
    uint32_t        width,
    uint32_t        height,
    VkImageView[]   first_image_views,
    VkImageView[]   dynamic_image_views,
    VkImageView[]   last_image_views = [],
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) {

    return vk.createFramebuffers(
        out_buffers, render_pass, width, height, 1, first_image_views, dynamic_image_views, last_image_views, file, line, func );
}