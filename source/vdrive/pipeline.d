module vdrive.pipeline;

import core.stdc.stdio : printf;

import vdrive.util.array, vdrive.util.util;
import vdrive.state;

import erupted;


nothrow @nogc:


////////////////////////////////////////////
// Meta_Graphics and Meta_Compute related //
////////////////////////////////////////////

/// overload to simplify VkPipelineLayout construction
VkPipelineLayout createPipelineLayout(
    ref Vulkan              vk,
    VkDescriptorSetLayout[] descriptor_set_layouts,
    VkPushConstantRange[]   push_constant_ranges = [],
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    VkPipelineLayoutCreateInfo pipeline_layout_ci = {
        setLayoutCount                  : descriptor_set_layouts.length.toUint,
        pSetLayouts                     : descriptor_set_layouts.ptr,
        pushConstantRangeCount          : push_constant_ranges.length.toUint,
        pPushConstantRanges             : push_constant_ranges.ptr,
    };

    VkPipelineLayout pipeline_layout;
    vk.device.vkCreatePipelineLayout( & pipeline_layout_ci, vk.allocator, & pipeline_layout ).vkAssert( "Pipeline Layout", file, line, func );
    return pipeline_layout;
}

/// overload to simplify VkPipelineLayout construction
VkPipelineLayout createPipelineLayout(
    ref Vulkan              vk,
    VkDescriptorSetLayout   descriptor_set_layout,
    VkPushConstantRange     push_constant_range,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    return vk.createPipelineLayout(
        ( & descriptor_set_layout )[ 0 .. 1 ],
        ( & push_constant_ranges  )[ 0 .. 1 ],
        file, line, func );
}

/// overload to simplify VkPipelineLayout construction
VkPipelineLayout createPipelineLayout(
    ref Vulkan              vk,
    VkDescriptorSetLayout   descriptor_set_layout,
    VkPushConstantRange[]   push_constant_ranges = [],
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    return vk.createPipelineLayout(
        ( & descriptor_set_layout )[ 0 .. 1 ], push_constant_ranges, file, line, func );
}

/// overload to simplify VkPipelineLayout construction
VkPipelineLayout createPipelineLayout(
    ref Vulkan              vk,
    VkPushConstantRange     push_constant_range,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    return vk.createPipelineLayout(
        ( & push_constant_range )[ 0 .. 1 ], file, line, func );
}

/// overload to simplify VkPipelineLayout construction
VkPipelineLayout createPipelineLayout(
    ref Vulkan              vk,
    VkPushConstantRange[]   push_constant_ranges = [],
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    return vk.createPipelineLayout(
        VkDescriptorSetLayout[].init, push_constant_ranges, file, line, func );    // second argument cannot be null due other matching overload
}


/// convenience function to create a pipeline ccache with one call
VkPipelineCache createPipelineCache(
    ref Vulkan  vk,
    void[]      initial_data = [],
    string      file    = __FILE__,
    size_t      line    = __LINE__,
    string      func    = __FUNCTION__
    ) {
    VkPipelineCacheCreateInfo pipeline_cache_ci = {
        initialDataSize : initial_data.length.toUint,
        pInitialData    : initial_data.ptr
    };

    VkPipelineCache pipeline_cache;
    vk.device.vkCreatePipelineCache(
        & pipeline_cache_ci,
        vk.allocator,
        & pipeline_cache
        ).vkAssert( "Pipeline Cache", file, line, func );

    return pipeline_cache;
}


/// Wraps the essential Vulkan objects created with the editing procedure
/// of Meta_Graphics and Meta_Compute, all other internal structures are obsolete
/// after construction so that the Meta_Descriptor_Layout can be reused
/// after being reset
struct Core_Pipeline {
    nothrow @nogc:
    VkPipeline              pipeline;
    VkPipelineLayout        pipeline_layout;
    bool is_null() { return pipeline.is_null_handle; }      // query if internal pso is null_handle
}


/// destroy all wrapped Vulkan objects
/// Params:
///     vk = Vulkan state struct with the VkDevice through which these resources were created
///     core = Wraps the VkPipelinekPipeline and VkPipelineLayout wrapper to be destroyed.
/// Returns: the passed in Meta_Structure for function chaining
void destroy( ref Vulkan vk, ref Core_Pipeline core ) {
    vk.destroyHandle( core.pipeline );
    vk.destroyHandle( core.pipeline_layout );
}


/// mixin methods common Meta_Graphics and Meta_Compute
private mixin template Meta_Pipeline_Common() {

    /// add VkDescriptorSetLayout to either Meta_Graphics or Meta_Pipeline
    auto ref addDescriptorSetLayout( VkDescriptorSetLayout descriptor_set_layout ) {
        descriptor_set_layouts.append = descriptor_set_layout;
        return this;
    }

    /// add VkPushConstantRange to either Meta_Graphics or Meta_Pipeline
    auto ref addPushConstantRange( VkPushConstantRange push_constant_range ) {
        push_constant_ranges.append = push_constant_range;
        return this;
    }

    /// add VkPushConstantRange to either Meta_Graphics or Meta_Pipeline
    auto ref addPushConstantRange( VkShaderStageFlags stage_flags, size_t offset, size_t size ) {
        return addPushConstantRange( VkPushConstantRange( stage_flags, offset.toUint, size.toUint ));
    }

    /// query if internal pso is null_handle
    bool is_null() { return pipeline.is_null_handle; }
}




///////////////////////////
// Meta_Graphics related //
///////////////////////////


/// Meta struct to configure a graphics VkPipeline and VkPipelineLayout.
/// Dynamic arrays exist to add several related config structs.
/// Must be initialized with a Vulkan state struct.
alias  Meta_Graphics = Meta_Graphics_T!();


/// Meta struct to configure a graphics VkPipeline and VkPipelineLayout.
/// Parametrizeable static or dynamic arrays exist to add several related config structs.
/// Must be initialized with a Vulkan state struct.
struct Meta_Graphics_T(
    int32_t shader_stage_count          = int32_t.max,
    int32_t binding_description_count   = int32_t.max,
    int32_t attribute_description_count = int32_t.max,
    int32_t viewport_count              = int32_t.max,
    int32_t scissor_count               = int32_t.max,
    int32_t color_blend_state_count     = int32_t.max,
    int32_t dynamic_state_count         = int32_t.max,
    int32_t descriptor_set_layout_count = int32_t.max,
    int32_t push_constant_range_count   = int32_t.max,

    ) {

    nothrow @nogc:
    mixin                                               Vulkan_State_Pointer;
    VkPipeline                                          pipeline;
    VkPipelineCreateFlags                               pipeline_cf;
    D_OR_S_ARRAY!( VkPipelineShaderStageCreateInfo,     shader_stage_count )            shader_stages;

    D_OR_S_ARRAY!( VkVertexInputBindingDescription,     binding_description_count )     vertex_input_binding_descriptions;
    D_OR_S_ARRAY!( VkVertexInputAttributeDescription,   attribute_description_count )   vertex_input_attribute_descriptions;
    VkPipelineInputAssemblyStateCreateInfo              input_assembly_state_ci;

    uint32_t                                            tesselation_patch_control_points;

    D_OR_S_ARRAY!( VkViewport, viewport_count )         viewports;
    D_OR_S_ARRAY!( VkRect2D,   scissor_count )          scissors;

    VkPipelineRasterizationStateCreateInfo              rasterization_state_ci = { frontFace : VK_FRONT_FACE_CLOCKWISE, depthBiasConstantFactor : 0, depthBiasClamp : 0, depthBiasSlopeFactor : 0, lineWidth : 1 };
    VkPipelineMultisampleStateCreateInfo                multisample_state_ci   = { rasterizationSamples : VK_SAMPLE_COUNT_1_BIT, minSampleShading : 0 };
    VkPipelineDepthStencilStateCreateInfo               depth_stencil_state_ci = { minDepthBounds : 0, maxDepthBounds : 0 };
    VkPipelineColorBlendStateCreateInfo                 color_blend_state_ci   = { blendConstants : [ 0, 0, 0, 0 ] };
    D_OR_S_ARRAY!( VkPipelineColorBlendAttachmentState, color_blend_state_count )       color_blend_states;

    //VkPipelineDynamicStateCreateInfo                  dynamic_state_ci;
    D_OR_S_ARRAY!( VkDynamicState,                      dynamic_state_count )           dynamic_states;

    //VkPipelineLayoutCreateInfo                        pipeline_layout_ci
    VkPipelineLayout                                    pipeline_layout;
    D_OR_S_ARRAY!( VkDescriptorSetLayout,               descriptor_set_layout_count )   descriptor_set_layouts;
    D_OR_S_ARRAY!( VkPushConstantRange,                 push_constant_range_count )     push_constant_ranges;

    VkRenderPass                                        render_pass;
    uint32_t                                            subpass;
    VkPipeline                                          base_pipeline_handle = VK_NULL_HANDLE;
    //int32_t                                           base_pipeline_index  = -1;  // Todo(pp): this is only meaningfull for multi-pipeline construction. Implement!


    /// Get minimal config for internal D_OR_S_ARRAY.
    auto static_config() {
        size_t[9] result;
        result[0] = shader_stages.length;
        result[1] = vertex_input_binding_descriptions.length;
        result[2] = vertex_input_attribute_descriptions.length;
        result[3] = viewports.length;
        result[4] = scissors.length;
        result[5] = color_blend_states.length;
        result[6] = dynamic_states.length;
        result[7] = descriptor_set_layouts.length;
        result[8] = push_constant_ranges.length;
        return result;
    }


    void destroyResources() {
        vk.destroyHandle( pipeline );
        vk.destroyHandle( pipeline_layout );
    }


    /// reset all internal data and return wrapped Vulkan objects
    /// VkPipeline and VkPipelineLayout
    auto reset() {
        Core_Pipeline result = { pipeline, pipeline_layout };
        shader_stages.clear;
        vertex_input_binding_descriptions.clear;
        vertex_input_attribute_descriptions.clear;
        viewports.clear;
        scissors.clear;
        color_blend_states.clear;
        dynamic_states.clear;
        descriptor_set_layouts.clear;
        push_constant_ranges.clear;
        return result;
    }


    /// extract core pipeline elements VkPipeline and VkPipelineLayout
    /// without resetting the internal data structures
    auto extractCore() {
        return Core_Pipeline( pipeline, pipeline_layout );
    }



    ///////////////////////////
    // pipeline create flags //
    ///////////////////////////
    auto ref pipelineCreateFlags( VkPipelineCreateFlags pipeline_cf ) {
        this.pipeline_cf = pipeline_cf;
        return this;
    }



    //////////////////////////////
    // shader stage create info //
    //////////////////////////////
    auto ref addShaderStageCreateInfo( VkPipelineShaderStageCreateInfo shader_stage_ci ) {
        shader_stages.append = shader_stage_ci;
        return this;
    }

    auto ref addShaderStageCreateInfo( VkPipelineShaderStageCreateInfo[] shader_stage_cis ) {
        foreach( ref shader_stage_ci; shader_stage_cis )
            shader_stages.append = shader_stage_ci;
        return this;
    }

    /// destroy shader modules, can happen immediatelly after PSO construction, if modules are not shared
    auto ref destroyShaderModules() {
        foreach( ref shader_stage; shader_stages )
            if( !shader_stage._module.is_null )
                vk.destroyHandle( shader_stage._module );
        shader_stages.clear;
        return this;
    }



    ////////////////////////////////////////////////////////
    // vertex input, input assembly and tesselation state //
    ////////////////////////////////////////////////////////
    auto ref addBindingDescription( size_t binding, size_t stride, VkVertexInputRate input_rate = VK_VERTEX_INPUT_RATE_VERTEX ) {
        vertex_input_binding_descriptions.append( VkVertexInputBindingDescription( binding.toUint, stride.toUint, input_rate ));
        return this;
    }

    auto ref addAttributeDescription( size_t location, size_t binding, VkFormat format, size_t offset = 0 ) {
        vertex_input_attribute_descriptions.append( VkVertexInputAttributeDescription( location.toUint, binding.toUint, format, offset.toUint ));
        return this;
    }

    auto ref inputAssembly( VkPrimitiveTopology primitive_topology, VkBool32 primitive_restart_enable = VK_FALSE ) {
        input_assembly_state_ci.topology = primitive_topology;
        input_assembly_state_ci.primitiveRestartEnable = primitive_restart_enable;
        return this;
    }

    auto ref patchControlPoints( uint32_t patch_control_points ) {
        tesselation_patch_control_points = patch_control_points;
        return this;
    }



    ////////////////////////////////
    // viewport and scissor state //
    ////////////////////////////////
    auto ref addViewport( float x, float y, float width, float height, float minDepth = 0, float maxDepth = 1 ) {
        viewports.append = VkViewport( x, y, width, height, minDepth, maxDepth );
        return this;
    }

    auto ref addViewport( VkOffset2D offset, VkExtent2D extent, float minDepth = 0, float maxDepth = 1 ) {
        return addViewport( offset.x, offset.y, extent.width, extent.height, minDepth, maxDepth );
    }

    auto ref addViewport( VkRect2D rect, float minDepth = 0, float maxDepth = 1 ) {
        return addViewport( rect.offset.x, rect.offset.y, rect.extent.width, rect.extent.height, minDepth, maxDepth );
    }

    auto ref addScissors( int32_t x, int32_t y, uint32_t width, uint32_t height ) {
        return addScissors( VkRect2D( VkOffset2D( x, y ), VkExtent2D( width, height )));
    }

    auto ref addScissors( VkOffset2D offset, VkExtent2D extent ) {
        return addScissors( VkRect2D( offset, extent ));
    }

    auto ref addScissors( VkRect2D rect ) {
        scissors.append = rect;
        return this;
    }

    auto ref addViewportAndScissors( float x, float y, float width, float height, float minDepth = 0, float maxDepth = 1 ) {
        return addViewport( x, y, width, height, minDepth, maxDepth ).addScissors( x.toInt32_t, y.toInt32_t, width.toInt32_t, height.toInt32_t );
    }

    auto ref addViewportAndScissors( VkOffset2D offset, VkExtent2D extent, float minDepth = 0, float maxDepth = 1 ) {
        return addViewport( offset, extent, minDepth, maxDepth ).addScissors( offset, extent );
    }

    auto ref addViewportAndScissors( VkRect2D rect, float minDepth = 0, float maxDepth = 1 ) {
        return addViewport( rect, minDepth, maxDepth ).addScissors( rect );
    }



    /////////////////////////
    // rasterization state //
    /////////////////////////

    /// the mixin bellow generates following setter functions:
    /// auto ref depthClampEnable(        VkBool32         depth_clamp_enable );
    /// auto ref rasterizerDiscardEnable( VkBool32         rasterizer_discard_enable );
    /// auto ref polygonMode(             VkPolygonMode    polygon_mode );
    /// auto ref cullMode(                VkCullModeFlags  cull_mode );
    /// auto ref frontFace(               VkFrontFace      front_face );
    /// auto ref depthBiasEnable(         VkBool32         depth_bias_enable );
    /// auto ref depthBiasConstantFactor( float            depth_bias_constant_factor );
    /// auto ref depthBiasClamp(          float            depth_bias_clamp );
    /// auto ref depthBiasSlopeFactor(    float            depth_bias_slope_factor );
    /// auto ref lineWidth(               float            line_width );
    mixin Forward_To_Inner_Struct!( VkPipelineRasterizationStateCreateInfo, "rasterization_state_ci" );

    auto ref depthBias( float constant_factor, float clamp, float slope_factor, VkBool32 enable = VK_TRUE ) {
        with( rasterization_state_ci ) {
            depthBiasConstantFactor = constant_factor;
            depthBiasClamp          = clamp;
            depthBiasSlopeFactor    = slope_factor;
            depthBiasEnable         = enable ;
        } return this;
    }



    ///////////////////////
    // multisample state //
    ///////////////////////

    /// the mixin bellow generates following setter functions:
    /// auto ref rasterizationSamples(  VkSampleCountFlagBits   rasterization_samples );
    /// auto ref sampleShadingEnable(   VkBool32                sample_shading_enable );
    /// auto ref minSampleShading(      float                   min_sample_shading );
    /// auto ref pSampleMask(           const( VkSampleMask )*  p_sample_mask );
    /// auto ref alphaToCoverageEnable( VkBool32                alpha_to_coverage_enable );
    /// auto ref alphaToOneEnable(      VkBool32                alpha_to_one_enable );
    mixin Forward_To_Inner_Struct!( VkPipelineMultisampleStateCreateInfo, "multisample_state_ci" );

    auto ref multisampleShading( float min_sample_shading, const( VkSampleMask )* sample_mask = null, VkBool32 enable = VK_TRUE ) {
        with( multisample_state_ci ) {
            minSampleShading        = min_sample_shading;
            pSampleMask             = sample_mask;
            sampleShadingEnable     = enable;
        } return this;
    }

    auto ref multisampleAlpha( VkBool32 to_coverage, VkBool32 to_one ) {
        with( multisample_state_ci ) {
            alphaToCoverageEnable   = to_coverage;
            alphaToOneEnable        = to_one;
        } return this;
    }



    /////////////////
    // depth state //
    /////////////////

    /// the mixin bellow generates following setter functions:
    /// auto ref depthTestEnable(       VkBool32     depth_test_enable );
    /// auto ref depthWriteEnable(      VkBool32     depth_write_enable );
    /// auto ref depthCompareOp(        VkCompareOp  depth_compare_op );
    /// auto ref depthBoundsTestEnable( VkBool32     depth_bounds_test_enable );
    /// auto ref stencilTestEnable(     VkBool32     stencil_test_enable );
    /// auto ref minDepthBounds(        float        min_depth_bounds );
    /// auto ref maxDepthBounds(        float        max_depth_bounds );
    mixin Forward_To_Inner_Struct!( VkPipelineDepthStencilStateCreateInfo, "depth_stencil_state_ci", "front", "back" );

    auto ref depthState( VkCompareOp compare_op = VK_COMPARE_OP_LESS_OR_EQUAL, VkBool32 write_enable = VK_TRUE, VkBool32 test_enable = VK_TRUE ) {
        with( depth_stencil_state_ci ) {
            depthCompareOp          = compare_op;
            depthWriteEnable        = write_enable;
            depthTestEnable         = test_enable;
        } return this;
    }



    ///////////////////
    // stencil state //
    ///////////////////
    auto ref stencilState( VkStencilOpState front_op_state, VkStencilOpState back_op_state, VkBool32 stencil_test_enable = VK_TRUE ) {
        with( depth_stencil_state_ci ) {
            stencilTestEnable   = stencil_test_enable;
            front               = front_op_state;
            back                = back_op_state;
        } return this;
    }

    auto ref stencilStateFront( VkStencilOpState stencil_op_state, VkBool32 stencil_test_enable = VK_TRUE ) {
        with( depth_stencil_state_ci ) {
            stencilTestEnable   = stencil_test_enable;
            front               = stencil_op_state;
        } return this;
    }

    auto ref stencilStateBack( VkStencilOpState stencil_op_state, VkBool32 stencil_test_enable = VK_TRUE ) {
        with( depth_stencil_state_ci ) {
            stencilTestEnable   = stencil_test_enable;
            back                = stencil_op_state;
        } return this;
    }

    auto ref stencilStateFront(
        VkStencilOp         fail_op,
        VkStencilOp         pass_op,
        VkStencilOp         depth_fail_op,
        VkCompareOp         compare_op,
        uint32_t            compare_mask,
        uint32_t            write_mask,
        uint32_t            reference,
        VkBool32            stencil_test_enable = VK_TRUE
        ) {
        stencilStateFront(
            VkStencilOpState( fail_op, pass_op, depth_fail_op, compare_op, compare_mask, write_mask, reference ), stencil_test_enable );
        return this;
    }

    auto ref stencilStateBack(
        VkStencilOp         fail_op,
        VkStencilOp         pass_op,
        VkStencilOp         depth_fail_op,
        VkCompareOp         compare_op,
        uint32_t            compare_mask,
        uint32_t            write_mask,
        uint32_t            reference,
        VkBool32            stencil_test_enable = VK_TRUE
        ) {
        stencilStateBack(
            VkStencilOpState( fail_op, pass_op, depth_fail_op, compare_op, compare_mask, write_mask, reference ), stencil_test_enable );
        return this;
    }



    ////////////////////////
    // color blend states //
    ////////////////////////

    /// the mixin bellow generates following setter functions:
    /// auto ref logicOpEnable(  VkBool32   logic_op_enable );
    /// auto ref logicOp(        VkLogicOp  logic_op );
    /// auto ref blendConstants( float[4]   blend_constants );
    mixin Forward_To_Inner_Struct!( VkPipelineColorBlendStateCreateInfo, "color_blend_state_ci", "attachmentCount", "pAttachments" );

    auto ref colorBlendLogicOp( VkLogicOp logic_op, VkBool32 enable = VK_TRUE ) {
        with( color_blend_state_ci ) {
            logicOp         = logic_op;
            logicOpEnable   = enable;
        } return this;
    }

    auto ref addColorBlendState( VkPipelineColorBlendAttachmentState color_blend_attachment_state ) {
        color_blend_states.append( color_blend_attachment_state );
        return this;
    }

    // deafult values from: https://vulkan-tutorial.com/Drawing_a_triangle/Graphics_pipeline_basics/Fixed_functions#page_Color_blending
    auto ref addColorBlendState(
        VkBool32                blendEnable         = VK_FALSE,
        VkBlendFactor           srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA,
        VkBlendFactor           dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        VkBlendOp               colorBlendOp        = VK_BLEND_OP_ADD,
        VkBlendFactor           srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE,
        VkBlendFactor           dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO,
        VkBlendOp               alphaBlendOp        = VK_BLEND_OP_ADD,
        VkColorComponentFlags   colorWriteMask      = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT ) {
        addColorBlendState( VkPipelineColorBlendAttachmentState(
            blendEnable, srcColorBlendFactor, dstColorBlendFactor, colorBlendOp, srcAlphaBlendFactor, dstAlphaBlendFactor, alphaBlendOp, colorWriteMask ));
        return this;
    }



    auto ref setColorBlendState( VkBlendFactor src_blend_factor, VkBlendFactor dst_blend_factor, VkBlendOp blend_op = VK_BLEND_OP_ADD, VkBool32 blend_enable = VK_TRUE ) {
        if( color_blend_states.length == 0 )
            addColorBlendState( blend_enable );
        with( color_blend_states[ $-1 ] ) {
            srcColorBlendFactor     = src_blend_factor;
            dstColorBlendFactor     = dst_blend_factor;
            colorBlendOp            = blend_op;
            blendEnable             = blend_enable;
        } return this;
    }

    auto ref setAlphaBlendState( VkBlendFactor src_blend_factor, VkBlendFactor dst_blend_factor, VkBlendOp blend_op = VK_BLEND_OP_ADD, VkBool32 blend_enable = VK_TRUE ) {
        if( color_blend_states.length == 0 )
            addColorBlendState( blend_enable );
        with( color_blend_states[ $-1 ] ) {
            srcAlphaBlendFactor         = src_blend_factor;
            dstAlphaBlendFactor         = dst_blend_factor;
            alphaBlendOp                = blend_op;
            blendEnable                 = blend_enable;
        } return this;
    }

    auto ref setColorWriteMask( VkColorComponentFlags color_write_mask ) {
        if( color_blend_states.length == 0 )
            addColorBlendState( VK_FALSE );
        color_blend_states[ $-1 ].colorWriteMask = color_write_mask;
        return this;
    }

    auto ref setColorBlendEnable( VkBool32 blend_enable ) {
        if( color_blend_states.length == 0 )
            addColorBlendState( blend_enable );
        else
            color_blend_states[ $-1 ].blendEnable = blend_enable;
        return this;
    }



    ///////////////////
    // Dynamic State //
    ///////////////////
    auto ref addDynamicState( VkDynamicState dynamic_state ) {
        dynamic_states.append = dynamic_state;
        return this;
    }



    /////////////////////
    // pipeline layout //
    /////////////////////
    mixin Meta_Pipeline_Common;



    ////////////////////////////////////////////////////////////////////////////
    // render pass, subpass, base pipeline, optimization and flags in general //
    ////////////////////////////////////////////////////////////////////////////
    auto ref renderPass( VkRenderPass render_pass, size_t subpass = 0 ) {
        this.render_pass = render_pass;
        this.subpass = subpass.toUint;
        return this;
    }

    /// set base pipeline handle for derivated pipelines
    auto ref basePipeline( VkPipeline base_pipeline_handle ) {
        this.base_pipeline_handle = base_pipeline_handle;
        return this;
    }

    // not using multi pipeline creation yet
    //auto ref basePipeline( int32_t base_pipeline_index ) {
    //    this.base_pipeline_index = base_pipeline_index;
    //    return this;
    //}


    /// disable pipeline optimization
    auto ref disableOptimization() {
        pipeline_cf |= VK_PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT;
        return this;
    }

    /// allow that this piplein can have derivative pipleines
    auto ref allowDerivatives() {
        pipeline_cf |= VK_PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT;
        return this;
    }

    /// general variant for setting flags
    auto ref pipelineCeateFlags( VkPipelineCreateFlags flags ) {
        pipeline_cf = flags;
        return this;
    }



    /////////////////////////////////////////
    // construct the pipeline state object //
    /////////////////////////////////////////
    auto ref construct(
        VkPipelineCache     pipeline_cache  = VK_NULL_HANDLE,
        VkPipelineLayout    pipeline_layout = VK_NULL_HANDLE,
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Meta_Struct not initialized with a vulkan state pointer", file, line, func );

        VkPipelineVertexInputStateCreateInfo vertex_input_state_ci = {
            vertexBindingDescriptionCount   : vertex_input_binding_descriptions.length.toUint,
            pVertexBindingDescriptions      : vertex_input_binding_descriptions.ptr,
            vertexAttributeDescriptionCount : vertex_input_attribute_descriptions.length.toUint,
            pVertexAttributeDescriptions    : vertex_input_attribute_descriptions.ptr,
        };

        VkPipelineTessellationStateCreateInfo tessellation_state_ci = {
            patchControlPoints              : tesselation_patch_control_points,
        };

        VkPipelineViewportStateCreateInfo viewport_state_ci = {
            viewportCount                   : viewports.length.toUint,
            pViewports                      : viewports.ptr,
            scissorCount                    : scissors.length.toUint,
            pScissors                       : scissors.ptr,
        };

        if( color_blend_states.length == 0 )
            addColorBlendState( VK_FALSE );

        color_blend_state_ci.attachmentCount  = color_blend_states.length.toUint;
        color_blend_state_ci.pAttachments     = color_blend_states.ptr;


        VkPipelineDynamicStateCreateInfo dynamic_state_ci = {
            dynamicStateCount               : dynamic_states.length.toUint,
            pDynamicStates                  : dynamic_states.ptr,
        };

        if( pipeline_layout )
            this.pipeline_layout = pipeline_layout;
        else
            this.pipeline_layout = vk.createPipelineLayout( descriptor_set_layouts.data, push_constant_ranges.data, file, line, func );

        // create the pipeline object
        VkGraphicsPipelineCreateInfo pipeline_ci = {
            flags               :   pipeline_cf,
            stageCount          :   shader_stages.length.toUint,
            pStages             :   shader_stages.ptr,
            pVertexInputState   : & vertex_input_state_ci,
            pInputAssemblyState : & input_assembly_state_ci,
            pTessellationState  :   tesselation_patch_control_points > 0 ? & tessellation_state_ci : null,  // assume inputAssembly = VK_PRIMITIVE_TOPOLOGY_PATCH_LIST
            pViewportState      : & viewport_state_ci,
            pRasterizationState : & rasterization_state_ci,
            pMultisampleState   : & multisample_state_ci,
            pDepthStencilState  : & depth_stencil_state_ci,
            pColorBlendState    : & color_blend_state_ci,
            pDynamicState       : & dynamic_state_ci,
            layout              :   this.pipeline_layout,
            renderPass          :   render_pass,
            subpass             :   subpass,
            basePipelineHandle  :   base_pipeline_handle,
            basePipelineIndex   :   -1,//base_pipeline_index,
        };

        if( base_pipeline_handle  != VK_NULL_HANDLE /*|| base_pipeline_index != -1*/ )
            pipeline_ci.flags |= VK_PIPELINE_CREATE_DERIVATIVE_BIT;

        vk.device.vkCreateGraphicsPipelines(
            pipeline_cache,             // pipelineCache
            1,                          // createInfoCount
            & pipeline_ci,              // pCreateInfos
            allocator,                  // pAllocator
            & pipeline                  // pPipelines
            ).vkAssert( "Construct Graphics Pipeline", file, line, func );

        return this;
    }


    auto ref construct(
        VkPipelineLayout    pipeline_layout,
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        return construct( VK_NULL_HANDLE, pipeline_layout, file, line, func );
    }
}



//////////////////////////
// Meta_Compute related //
//////////////////////////


/// meta struct to configure a graphics VkPipeline and allocate a
/// dynamic arrays exist to add VkDescriptorSetLayout and VkPushConstantRange
/// must be initialized with a Vulkan state struct
alias Meta_Compute = Meta_Compute_T!();
struct Meta_Compute_T(
    int32_t descriptor_set_layout_count = int32_t.max,
    int32_t push_constant_range_count   = int32_t.max,

    ) {

    mixin                                       Vulkan_State_Pointer;
    VkPipeline                                  pipeline;
    VkComputePipelineCreateInfo                 pipeline_ci;

    D_OR_S_ARRAY!( VkDescriptorSetLayout,       descriptor_set_layout_count )   descriptor_set_layouts;
    D_OR_S_ARRAY!( VkPushConstantRange,         push_constant_range_count )     push_constant_ranges;

    VkPipelineLayout                            pipeline_layout() { return pipeline_ci.layout; }



    /// get minimal config for internal D_OR_S_ARRAY
    auto static_config() {
        size_t[2] result;
        result[0] = descriptor_set_layouts.length;
        result[1] = push_constant_ranges.length;
        return result;
    }


    void destroyResources() {
        vk.destroyHandle( pipeline );
        vk.destroyHandle( pipeline_ci.layout );
    }



    /// reset all internal data and return wrapped Vulkan objects
    /// VkPipeline and VkPipelineLayout
    auto reset() {
        Core_Pipeline result = { pipeline, pipeline_ci.layout };
        descriptor_set_layouts.clear;
        push_constant_ranges.clear;
        return result;
    }


    /// extract core pipeline elements VkPipeline and VkPipelineLayout
    /// without resetting the internal data structures
    auto extractCore() {
        return Core_Pipeline( pipeline, pipeline_ci.layout );
    }



    //////////////////////////////
    // shader stage create info //
    //////////////////////////////
    auto ref shaderStageCreateInfo( VkPipelineShaderStageCreateInfo shader_stage_ci ) {
        pipeline_ci.stage = shader_stage_ci;
        return this;
    }

    /// destroy shader module, can happen immediatelly after PSO construction
    auto ref destroyShaderModule() {
        if( !pipeline_ci.stage._module.is_null )
            vk.destroyHandle( pipeline_ci.stage._module );
        return this;
    }



    /////////////////////
    // pipeline layout //
    /////////////////////
    mixin Meta_Pipeline_Common;



    //////////////////////////////////////////////////////
    // base pipeline, optimization and flags in general //
    //////////////////////////////////////////////////////

    /// set base pipeline handle for derivated pipelines
    auto ref basePipeline( VkPipeline base_pipeline_handle ) {
        pipeline_ci.basePipelineHandle = base_pipeline_handle;
        if( base_pipeline_handle != VK_NULL_HANDLE )    // we might not know if the passed in pipeline was created already
            pipeline_ci.flags |= VK_PIPELINE_CREATE_DERIVATIVE_BIT;
        return this;
    }

    // not using multi pipeline creation yet
    //auto ref basePipeline( int32_t base_pipeline_index ) {
    //    pipeline_ci.basePipelineIndex = base_pipeline_index;
    //    return this;
    //}


    /// disable pipeline optimization
    auto ref disableOptimization() {
        pipeline_ci.flags |= VK_PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT;
        return this;
    }

    /// allow that this piplein can have derivative pipleines
    auto ref allowDerivatives() {
        pipeline_ci.flags |= VK_PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT;
        return this;
    }

    /// general variant for setting flags
    auto ref pipelineCeateFlags( VkPipelineCreateFlags flags ) {
        pipeline_ci.flags = flags;
    }



    /////////////////////////////////////////
    // construct the pipeline state object //
    /////////////////////////////////////////
    auto ref construct(
        VkPipelineCache     pipeline_cache  = VK_NULL_HANDLE,
        VkPipelineLayout    pipeline_layout = VK_NULL_HANDLE,
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__

        ) {

        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Meta_Struct not initialized with a vulkan state pointer", file, line, func );

        if( pipeline_layout )
            pipeline_ci.layout = pipeline_layout;
        else
            pipeline_ci.layout = vk.createPipelineLayout( descriptor_set_layouts.data, push_constant_ranges.data );

        vk.device.vkCreateComputePipelines(
            pipeline_cache,             // pipelineCache
            1,                          // createInfoCount
            & pipeline_ci,              // pCreateInfos
            allocator,                  // pAllocator
            & pipeline                  // pPipelines
            ).vkAssert( "Construct Compute Pipeline", file, line, func );

        return this;
    }



    auto ref construct(
        VkPipelineLayout    pipeline_layout,
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        return construct( VK_NULL_HANDLE, pipeline_layout, file, line, func );
    }
}
