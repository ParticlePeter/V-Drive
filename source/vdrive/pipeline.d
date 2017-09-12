module vdrive.pipeline;

import core.stdc.stdio : printf;

import vdrive.util.array, vdrive.util.util;
import vdrive.state;

import erupted;


////////////////////////////////////////////
// Meta_Graphics and Meta_Compute related //
////////////////////////////////////////////


/// Wraps the essential Vulkan objects created with the editing procedure
/// of Meta_Graphics and Meta_Compute, all other internal structures are obsolete
/// after construction so that the Meta_Descriptor_Layout can be reused
/// after being reset
struct Core_Pipeline {
    VkPipeline          pipeline;
    VkPipelineLayout    pipeline_layout;
}


/// destroy all wrapped Vulkan objects
/// Params:
///     vk = Vulkan state struct holding the device through which these resources were created
///     core = the wrapped VkDescriptorPool ( with it the VkDescriptorSet ) and the VkDescriptorSetLayout to destroy
/// Returns: the passed in Meta_Structure for function chaining
void destroy( ref Vulkan vk, ref Core_Pipeline core ) {
    vdrive.state.destroy( vk, core.pipeline );          // no nice syntax, vdrive.state.destroy overloads
    vdrive.state.destroy( vk, core.pipeline_layout );   // get confused with this one in the module scope
}



/// private template to constraint template arg to Meta_Graphics or Meta_Compute
private template isPipeline( T ) {
    enum isPipeline = is( T == Meta_Graphics ) || is( T == Meta_Compute );
}

/// add VkDescriptorSetLayout to either Meta_Graphics or Meta_Pipeline, use alias addDescriptorSetLayout instead
auto ref addDescriptorSetLayoutImpl( META )( ref META meta, VkDescriptorSetLayout descriptor_set_layout ) if( isPipeline!META ) {
    meta.descriptor_set_layouts.append = descriptor_set_layout;
    return meta;
}

/// add VkPushConstantRange to either Meta_Graphics or Meta_Pipeline, use alias addPushConstantRangeImpl instead
auto ref addPushConstantRangeImpl_1( META )( ref META meta, VkPushConstantRange push_constant_range ) if( isPipeline!META ) {
    meta.push_constant_ranges.append = push_constant_range;
    return meta;
}

/// add VkPushConstantRange to either Meta_Graphics or Meta_Pipeline, use alias addPushConstantRangeImpl instead
auto ref addPushConstantRangeImpl_2( META )( ref META meta, VkShaderStageFlags stage_flags, size_t offset, size_t size ) if( isPipeline!META ) {
    return meta.addPushConstantRange( VkPushConstantRange( stage_flags, offset.toUint, size.toUint ));
}


/// overload to simplify VkPipelineLayout construction
VkPipelineLayout createPipelineLayout(
    ref Vulkan              vk,
    VkDescriptorSetLayout[] descriptor_set_layouts,
    VkPushConstantRange[]   push_constant_ranges = [],
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    VkPipelineLayoutCreateInfo pipeline_layout_create_info = {
        setLayoutCount                  : descriptor_set_layouts.length.toUint,
        pSetLayouts                     : descriptor_set_layouts.ptr,
        pushConstantRangeCount          : push_constant_ranges.length.toUint,
        pPushConstantRanges             : push_constant_ranges.ptr,
    };

    VkPipelineLayout pipeline_layout;
    vk.device.vkCreatePipelineLayout( &pipeline_layout_create_info, vk.allocator, &pipeline_layout ).vkAssert( "Pipeline Layout", file, line, func );
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
    VkDescriptorSetLayout[1]    descriptor_set_layouts  = [ descriptor_set_layout ];
    VkPushConstantRange[1]      push_constant_ranges    = [ push_constant_range ];
    return createPipelineLayout( vk, descriptor_set_layouts, push_constant_ranges, file, line, func );
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
    VkDescriptorSetLayout[1]    descriptor_set_layouts  = [ descriptor_set_layout ];
    return createPipelineLayout( vk, descriptor_set_layouts, push_constant_ranges, file, line, func );
}

/// overload to simplify VkPipelineLayout construction
VkPipelineLayout createPipelineLayout(
    ref Vulkan              vk,
    VkPushConstantRange     push_constant_range,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    VkPushConstantRange[1]      push_constant_ranges    = [ push_constant_range ];
    return createPipelineLayout( vk, [], push_constant_ranges, file, line, func );
}

/// overload to simplify VkPipelineLayout construction
VkPipelineLayout createPipelineLayout(
    ref Vulkan              vk,
    VkPushConstantRange[]   push_constant_ranges = [],
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    return createPipelineLayout( vk, [], push_constant_ranges, file, line, func );
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
        &pipeline_cache_ci,
        vk.allocator,
        &pipeline_cache
        ).vkAssert( "Pipeline Cache", file, line, func );

    return pipeline_cache;
}



///////////////////////////
// Meta_Graphics related //
///////////////////////////

/// meta struct to configure a graphics VkPipeline and allocate a
/// dynamic arrays exist to add several related config structs
/// must be initialized with a Vulkan state struct
struct Meta_Graphics {
    mixin                                       Vulkan_State_Pointer;

    VkPipeline                                  pipeline;
    VkPipelineCreateFlags                       pipeline_create_flags;
    Array!VkPipelineShaderStageCreateInfo       shader_stages;

    //VkPipelineVertexInputStateCreateInfo      vertex_input_state_create_info;
    Array!VkVertexInputBindingDescription       vertex_input_binding_descriptions;
    Array!VkVertexInputAttributeDescription     vertex_input_attribute_descriptions;
    VkPipelineInputAssemblyStateCreateInfo      input_assembly_state;

    //VkPipelineTessellationStateCreateInfo     tessellation_state_create_info;
    uint32_t                                    tesselation_patch_control_points;

    //VkPipelineViewportStateCreateInfo         viewport_state_create_info;
    Array!VkViewport                            viewports;
    Array!VkRect2D                              scissors;

    VkPipelineRasterizationStateCreateInfo      rasterization_state = { frontFace : VK_FRONT_FACE_CLOCKWISE, depthBiasConstantFactor : 0, depthBiasClamp : 0, depthBiasSlopeFactor : 0, lineWidth : 1 };
    VkPipelineMultisampleStateCreateInfo        multisample_state   = { rasterizationSamples : VK_SAMPLE_COUNT_1_BIT, minSampleShading : 0 };
    VkPipelineDepthStencilStateCreateInfo       depth_stencil_state = { minDepthBounds : 0, maxDepthBounds : 0 };
    VkPipelineColorBlendStateCreateInfo         color_blend_state   = { blendConstants : [ 0, 0, 0, 0 ] };
    Array!VkPipelineColorBlendAttachmentState   color_blend_states;

    //VkPipelineDynamicStateCreateInfo          dynamic_state_create_info;
    Array!VkDynamicState                        dynamic_states;

    //VkPipelineLayoutCreateInfo                pipeline_layout_create_info
    VkPipelineLayout                            pipeline_layout;
    Array!VkDescriptorSetLayout                 descriptor_set_layouts;
    Array!VkPushConstantRange                   push_constant_ranges;

    VkRenderPass                                render_pass;
    uint32_t                                    subpass;
    VkPipeline                                  base_pipeline_handle = VK_NULL_HANDLE;
    //int32_t                                   base_pipeline_index  = -1;  // Todo(pp): this is only meaningfull for multi-pipeline construction. Implement!

    void destroyResources() {
        vdrive.state.destroy( vk, pipeline );          // no nice syntax, vdrive.state.destroy overloads
        vdrive.state.destroy( vk, pipeline_layout );   // get confused with this one in the module scope
    }
}


/// reset all internal data and return wrapped Vulkan objects
/// VkPipeline and VkPipelineLayout
auto reset( ref Meta_Graphics meta ) {
    Core_Pipeline result = { meta.pipeline, meta.pipeline_layout };
    meta.shader_stages.clear;
    meta.vertex_input_binding_descriptions.clear;
    meta.vertex_input_attribute_descriptions.clear;
    meta.viewports.clear;
    meta.scissors.clear;
    meta.color_blend_states.clear;
    meta.dynamic_states.clear;
    meta.descriptor_set_layouts.clear;
    meta.push_constant_ranges.clear;
    return result;
}


/// extract core pipeline elements VkPipeline and VkPipelineLayout
/// without resetting the internal data structures
auto extractCore( ref Meta_Graphics meta ) {
    return Core_Pipeline( meta.pipeline, meta.pipeline_layout );
}


///////////////////////////
// pipeline create flags //
///////////////////////////
auto ref pipelineCreateFlags( ref Meta_Graphics meta, VkPipelineCreateFlags pipeline_create_flags ) {
    meta.pipeline_create_flags = pipeline_create_flags;
    return meta;
}



//////////////////////////////
// shader stage create info //
//////////////////////////////
auto ref addShaderStageCreateInfo( ref Meta_Graphics meta, VkPipelineShaderStageCreateInfo shader_stage_create_info ) {
    meta.shader_stages.append = shader_stage_create_info;
    return meta;
}

auto ref addShaderStageCreateInfo( ref Meta_Graphics meta, VkPipelineShaderStageCreateInfo[] shader_stage_create_infos ) {
    foreach( ref shader_stage_create_info; shader_stage_create_infos )
        meta.shader_stages.append = shader_stage_create_info;
    return meta;
}

/// destroy shader modules, can happen immediatelly after PSO construction, if modules are not shared
auto ref destroyShaderModules( ref Meta_Graphics meta ) {
    foreach( ref shader_stage; meta.shader_stages )
        vdrive.state.destroy( meta, shader_stage._module );
    meta.shader_stages.clear;
    return meta;
}


////////////////////////////////////////////////////////
// vertex input, input assembly and tesselation state //
////////////////////////////////////////////////////////
auto ref addBindingDescription( ref Meta_Graphics meta, size_t binding, size_t stride, VkVertexInputRate input_rate = VK_VERTEX_INPUT_RATE_VERTEX ) {
    meta.vertex_input_binding_descriptions.append( VkVertexInputBindingDescription( binding.toUint, stride.toUint, input_rate ));
    return meta;
}

auto ref addAttributeDescription( ref Meta_Graphics meta, size_t location, size_t binding, VkFormat format, size_t offset = 0 ) {
    meta.vertex_input_attribute_descriptions.append( VkVertexInputAttributeDescription( location.toUint, binding.toUint, format, offset.toUint ));
    return meta;
}

auto ref inputAssembly( ref Meta_Graphics meta, VkPrimitiveTopology primitive_topology, VkBool32 primitive_restart_enable = VK_FALSE ) {
    meta.input_assembly_state.topology = primitive_topology;
    meta.input_assembly_state.primitiveRestartEnable = primitive_restart_enable;
    return meta;
}

auto ref patchControlPoints( ref Meta_Graphics meta, uint32_t patch_control_points ) {
    meta.tesselation_patch_control_points = patch_control_points;
    return meta;
}



////////////////////////////////
// viewport and scissor state //
////////////////////////////////
auto ref addViewport( ref Meta_Graphics meta, float x, float y, float width, float height, float minDepth = 0, float maxDepth = 1 ) {
    meta.viewports.append = VkViewport( x, y, width, height, minDepth, maxDepth );
    return meta;
}

auto ref addViewport( ref Meta_Graphics meta, VkOffset2D offset, VkExtent2D extent, float minDepth = 0, float maxDepth = 1 ) {
    return meta.addViewport( offset.x, offset.y, extent.width, extent.height, minDepth, maxDepth );
}

auto ref addViewport( ref Meta_Graphics meta, VkRect2D rect, float minDepth = 0, float maxDepth = 1 ) {
    return meta.addViewport( rect.offset.x, rect.offset.y, rect.extent.width, rect.extent.height, minDepth, maxDepth );
}

auto ref addScissors( ref Meta_Graphics meta, int32_t x, int32_t y, uint32_t width, uint32_t height ) {
    return meta.addScissors( VkRect2D( VkOffset2D( x, y ), VkExtent2D( width, height )));
}

auto ref addScissors( ref Meta_Graphics meta, VkOffset2D offset, VkExtent2D extent ) {
    return meta.addScissors( VkRect2D( offset, extent ));
}

auto ref addScissors( ref Meta_Graphics meta, VkRect2D rect ) {
    meta.scissors.append = rect;
    return meta;
}

auto ref addViewportAndScissors( ref Meta_Graphics meta, float x, float y, float width, float height, float minDepth = 0, float maxDepth = 1 ) {
    return meta.addViewport( x, y, width, height, minDepth, maxDepth ).addScissors( x.toInt32_t, y.toInt32_t, width.toInt32_t, height.toInt32_t );
}

auto ref addViewportAndScissors( ref Meta_Graphics meta, VkOffset2D offset, VkExtent2D extent, float minDepth = 0, float maxDepth = 1 ) {
    return meta.addViewport( offset, extent, minDepth, maxDepth ).addScissors( offset, extent );
}

auto ref addViewportAndScissors( ref Meta_Graphics meta, VkRect2D rect, float minDepth = 0, float maxDepth = 1 ) {
    return meta.addViewport( rect, minDepth, maxDepth ).addScissors( rect );
}



/////////////////////////
// rasterization state //
/////////////////////////

/// the mixin bellow generates following setter functions:
/// auto ref depthClampEnable(           Meta_Graphics meta, VkBool32            depth_clamp_enable          );
/// auto ref rasterizerDiscardEnable(    Meta_Graphics meta, VkBool32            rasterizer_discard_enable   );
/// auto ref polygonMode(                Meta_Graphics meta, VkPolygonMode       polygon_mode                );
/// auto ref cullMode(                   Meta_Graphics meta, VkCullModeFlags     cull_mode                   );
/// auto ref frontFace(                  Meta_Graphics meta, VkFrontFace         front_face                  );
/// auto ref depthBiasEnable(            Meta_Graphics meta, VkBool32            depth_bias_enable           );
/// auto ref depthBiasConstantFactor(    Meta_Graphics meta, float               depth_bias_constant_factor  );
/// auto ref depthBiasClamp(             Meta_Graphics meta, float               depth_bias_clamp            );
/// auto ref depthBiasSlopeFactor(       Meta_Graphics meta, float               depth_bias_slope_factor     );
/// auto ref lineWidth(                  Meta_Graphics meta, float               line_width                  );
mixin( Forward_To_Inner_Struct!( Meta_Graphics, VkPipelineRasterizationStateCreateInfo, "meta.rasterization_state" ));

auto ref depthBias(
    ref Meta_Graphics   meta,
    float               constant_factor,
    float               clamp,
    float               slope_factor,
    VkBool32            enable = VK_TRUE ) {
    return meta
        .depthBiasConstantFactor( constant_factor )
        .depthBiasClamp( clamp )
        .depthBiasSlopeFactor( slope_factor )
        .depthBiasEnable( enable );
}



///////////////////////
// multisample state //
///////////////////////

/// the mixin bellow generates following setter functions:
/// auto ref rasterizationSamples(      Meta_Graphics meta, VkSampleCountFlagBits   rasterization_samples       );
/// auto ref sampleShadingEnable(       Meta_Graphics meta, VkBool32                sample_shading_enable       );
/// auto ref minSampleShading(          Meta_Graphics meta, float                   min_sample_shading          );
/// auto ref pSampleMask(               Meta_Graphics meta, const( VkSampleMask )*  p_sample_mask               );
/// auto ref alphaToCoverageEnable(     Meta_Graphics meta, VkBool32                alpha_to_coverage_enable    );
/// auto ref alphaToOneEnable(          Meta_Graphics meta, VkBool32                alpha_to_one_enable         );
mixin( Forward_To_Inner_Struct!( Meta_Graphics, VkPipelineMultisampleStateCreateInfo, "meta.multisample_state" ));

auto ref multisampleShading(
    ref Meta_Graphics       meta,
    float                   min_sample_shading,
    const( VkSampleMask )*  sample_mask = null,
    VkBool32                enable = VK_TRUE ) {
    return meta.minSampleShading( min_sample_shading ).pSampleMask( sample_mask ).sampleShadingEnable( enable );
}

auto ref multisampleAlpha( ref Meta_Graphics meta, VkBool32 to_coverage, VkBool32 to_one ) {
    return meta.alphaToCoverageEnable( to_coverage ).alphaToOneEnable( to_one );
}



/////////////////
// depth state //
/////////////////

/// the mixin bellow generates following setter functions:
/// auto ref depthTestEnable(       Meta_Graphics meta, VkBool32           depth_test_enable         );
/// auto ref depthWriteEnable(      Meta_Graphics meta, VkBool32           depth_write_enable        );
/// auto ref depthCompareOp(        Meta_Graphics meta, VkCompareOp        depth_compare_op          );
/// auto ref depthBoundsTestEnable( Meta_Graphics meta, VkBool32           depth_bounds_test_enable  );
/// auto ref stencilTestEnable(     Meta_Graphics meta, VkBool32           stencil_test_enable       );
/// auto ref minDepthBounds(        Meta_Graphics meta, float              min_depth_bounds          );
/// auto ref maxDepthBounds(        Meta_Graphics meta, float              max_depth_bounds          );
mixin( Forward_To_Inner_Struct!( Meta_Graphics, VkPipelineDepthStencilStateCreateInfo, "meta.depth_stencil_state", "front", "back" ));

auto ref depthState(
    ref Meta_Graphics   meta,
    VkCompareOp         compare_op      = VK_COMPARE_OP_LESS_OR_EQUAL,
    VkBool32            write_enable    = VK_TRUE,
    VkBool32            test_enable     = VK_TRUE ) {
    return meta
        .depthCompareOp( compare_op )
        .depthWriteEnable( write_enable )
        .depthTestEnable( test_enable );
}



///////////////////
// stencil state //
///////////////////
auto ref stencilState(
    ref Meta_Graphics   meta,
    VkStencilOpState    front_op_state,
    VkStencilOpState    back_op_state,
    VkBool32            stencil_test_enable = VK_TRUE ) {
    meta.depth_stencil_state.stencilTestEnable = stencil_test_enable;
    meta.depth_stencil_state.front = front_op_state;
    meta.depth_stencil_state.back = back_op_state;
    return meta;
}

auto ref stencilStateFront(
    ref Meta_Graphics   meta,
    VkStencilOpState    stencil_op_state,
    VkBool32            stencil_test_enable = VK_TRUE ) {
    meta.depth_stencil_state.stencilTestEnable = stencil_test_enable;
    meta.depth_stencil_state.front = stencil_op_state;
    return meta;
}

auto ref stencilStateBack(
    ref Meta_Graphics   meta,
    VkStencilOpState    stencil_op_state,
    VkBool32            stencil_test_enable = VK_TRUE ) {
    meta.depth_stencil_state.stencilTestEnable = stencil_test_enable;
    meta.depth_stencil_state.back = stencil_op_state;
    return meta;
}

auto ref stencilStateFront(
    ref Meta_Graphics   meta,
    VkStencilOp         fail_op,
    VkStencilOp         pass_op,
    VkStencilOp         depth_fail_op,
    VkCompareOp         compare_op,
    uint32_t            compare_mask,
    uint32_t            write_mask,
    uint32_t            reference,
    VkBool32            stencil_test_enable = VK_TRUE ) {
    return meta.stencilStateFront(
        VkStencilOpState( fail_op, pass_op, depth_fail_op, compare_op, compare_mask, write_mask, reference ),
        stencil_test_enable
    );
}

auto ref stencilStateBack(
    ref Meta_Graphics   meta,
    VkStencilOp         fail_op,
    VkStencilOp         pass_op,
    VkStencilOp         depth_fail_op,
    VkCompareOp         compare_op,
    uint32_t            compare_mask,
    uint32_t            write_mask,
    uint32_t            reference,
    VkBool32            stencil_test_enable = VK_TRUE ) {
    return meta.stencilStateBack(
        VkStencilOpState(
            fail_op, pass_op, depth_fail_op, compare_op, compare_mask, write_mask, reference ),
        stencil_test_enable
    );
}



////////////////////////
// color blend states //
////////////////////////

/// the mixin bellow generates following setter functions:
/// auto ref logicOpEnable(     Meta_Graphics meta, VkBool32       logic_op_enable  );
/// auto ref logicOp(           Meta_Graphics meta, VkLogicOp      logic_op         );
/// auto ref blendConstants(    Meta_Graphics meta, float[4]       blend_constants  );
mixin( Forward_To_Inner_Struct!( Meta_Graphics, VkPipelineColorBlendStateCreateInfo, "meta.color_blend_state", "attachmentCount", "pAttachments" ));

auto ref colorBlendLogicOp( ref Meta_Graphics meta, VkLogicOp logic_op, VkBool32 enable = VK_TRUE ) {
    return meta.logicOp( logic_op ).logicOpEnable( enable );
}

auto ref addColorBlendState( ref Meta_Graphics meta, VkPipelineColorBlendAttachmentState color_blend_attachment_state ) {
    meta.color_blend_states.append( color_blend_attachment_state );
    return meta;
}

// deafult values from: https://vulkan-tutorial.com/Drawing_a_triangle/Graphics_pipeline_basics/Fixed_functions#page_Color_blending
auto ref addColorBlendState(
    ref Meta_Graphics       meta,
    VkBool32                blendEnable         = VK_FALSE,
    VkBlendFactor           srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA,
    VkBlendFactor           dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
    VkBlendOp               colorBlendOp        = VK_BLEND_OP_ADD,
    VkBlendFactor           srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE,
    VkBlendFactor           dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO,
    VkBlendOp               alphaBlendOp        = VK_BLEND_OP_ADD,
    VkColorComponentFlags   colorWriteMask      = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT ) {
    return meta.addColorBlendState(
        VkPipelineColorBlendAttachmentState(
            blendEnable, srcColorBlendFactor, dstColorBlendFactor, colorBlendOp, srcAlphaBlendFactor, dstAlphaBlendFactor, alphaBlendOp, colorWriteMask
        )
    );
}

auto ref setColorBlendState(
    ref Meta_Graphics   meta,
    VkBlendFactor       src_blend_factor,
    VkBlendFactor       dst_blend_factor,
    VkBlendOp           blend_op        = VK_BLEND_OP_ADD,
    VkBool32            blend_enable    = VK_TRUE ) {
    if( meta.color_blend_states.length == 0 )
        meta.addColorBlendState( VK_TRUE );
    meta.color_blend_states[ $-1 ].srcColorBlendFactor = src_blend_factor;
    meta.color_blend_states[ $-1 ].dstColorBlendFactor = dst_blend_factor;
    meta.color_blend_states[ $-1 ].colorBlendOp = blend_op;
    meta.color_blend_states[ $-1 ].blendEnable  = blend_enable;
    return meta;
}

auto ref setAlphaBlendState(
    ref Meta_Graphics   meta,
    VkBlendFactor       src_blend_factor,
    VkBlendFactor       dst_blend_factor,
    VkBlendOp           blend_op        = VK_BLEND_OP_ADD,
    VkBool32            blend_enable    = VK_TRUE ) {
    if( meta.color_blend_states.length == 0 )
        meta.addColorBlendState( VK_TRUE );
    meta.color_blend_states[ $-1 ].srcAlphaBlendFactor = src_blend_factor;
    meta.color_blend_states[ $-1 ].dstAlphaBlendFactor = dst_blend_factor;
    meta.color_blend_states[ $-1 ].alphaBlendOp = blend_op;
    meta.color_blend_states[ $-1 ].blendEnable  = blend_enable;
    return meta;
}

auto ref setColorWriteMask( ref Meta_Graphics meta, VkColorComponentFlags color_write_mask ) {
    if( meta.color_blend_states.length == 0 )
        meta.addColorBlendState( VK_FALSE );
    meta.color_blend_states[ $-1 ].colorWriteMask = color_write_mask;
    return meta;
}

auto ref setColorBlendEnable( ref Meta_Graphics meta, VkBool32 blend_enable ) {
    if( meta.color_blend_states.length == 0 )
        meta.addColorBlendState( blend_enable );
    else
        meta.color_blend_states[ $-1 ].blendEnable = blend_enable;
    return meta;
}



///////////////////
// Dynamic State //
///////////////////
auto ref addDynamicState( ref Meta_Graphics meta, VkDynamicState dynamic_state ) {
    meta.dynamic_states.append = dynamic_state;
    return meta;
}



/////////////////////
// pipeline layout //
/////////////////////
alias addDescriptorSetLayout = addDescriptorSetLayoutImpl!Meta_Graphics;
alias addPushConstantRange   = addPushConstantRangeImpl_1!Meta_Graphics;
alias addPushConstantRange   = addPushConstantRangeImpl_2!Meta_Graphics;



////////////////////////////////////////////////////////////////////////////
// render pass, subpass, base pipeline, optimization and flags in general //
////////////////////////////////////////////////////////////////////////////
auto ref renderPass( ref Meta_Graphics meta, VkRenderPass render_pass, size_t subpass = 0 ) {
    meta.render_pass = render_pass;
    meta.subpass = subpass.toUint;
    return meta;
}

/// set base pipeline handle for derivated pipelines
auto ref basePipeline( ref Meta_Graphics meta, VkPipeline base_pipeline_handle ) {
    meta.base_pipeline_handle = base_pipeline_handle;
    return meta;
}

/* not using multi pipeline creation yet
auto ref basePipeline( ref Meta_Graphics meta, int32_t base_pipeline_index ) {
    meta.base_pipeline_index = base_pipeline_index;
    return meta;
}
*/

/// disable pipeline optimization
auto ref disableOptimization( ref Meta_Graphics meta ) {
    meta.pipeline_create_flags |= VK_PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT;
    return meta;
}

/// allow that this piplein can have derivative pipleines
auto ref allowDerivatives( ref Meta_Graphics meta ) {
    meta.pipeline_create_flags |= VK_PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT;
    return meta;
}

/// general variant for setting flags
auto ref pipelineCeateFlags( ref Meta_Graphics meta, VkPipelineCreateFlags flags ) {
    meta.pipeline_create_flags = flags;
}



/////////////////////////////////////////
// construct the pipeline state object //
/////////////////////////////////////////
auto ref construct(
    ref Meta_Graphics   meta,
    VkPipelineCache     pipeline_cache  = VK_NULL_HANDLE,
    VkPipelineLayout    pipeline_layout = VK_NULL_HANDLE,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    // assert that meta struct is initialized with a valid vulkan state pointer
    meta.isValid.vkAssert( "Meta Struct not initialized", file, line, func );

    VkPipelineVertexInputStateCreateInfo vertex_input_state_create_info = {
        vertexBindingDescriptionCount   : meta.vertex_input_binding_descriptions.length.toUint,
        pVertexBindingDescriptions      : meta.vertex_input_binding_descriptions.ptr,
        vertexAttributeDescriptionCount : meta.vertex_input_attribute_descriptions.length.toUint,
        pVertexAttributeDescriptions    : meta.vertex_input_attribute_descriptions.ptr,
    };

    VkPipelineTessellationStateCreateInfo tessellation_state_create_info = {
        patchControlPoints              : meta.tesselation_patch_control_points,
    };

    VkPipelineViewportStateCreateInfo viewport_state_create_info = {
        viewportCount                   : meta.viewports.length.toUint,
        pViewports                      : meta.viewports.ptr,
        scissorCount                    : meta.scissors.length.toUint,
        pScissors                       : meta.scissors.ptr,
    };

    if( meta.color_blend_states.length == 0 )
        meta.addColorBlendState( VK_FALSE );

    meta.color_blend_state.attachmentCount  = meta.color_blend_states.length.toUint;
    meta.color_blend_state.pAttachments     = meta.color_blend_states.ptr;


    VkPipelineDynamicStateCreateInfo dynamic_state_create_info = {
        dynamicStateCount               : meta.dynamic_states.length.toUint,
        pDynamicStates                  : meta.dynamic_states.ptr,
    };

    if( pipeline_layout )
        meta.pipeline_layout = pipeline_layout;
    else
        meta.pipeline_layout = meta.createPipelineLayout( meta.descriptor_set_layouts.data, meta.push_constant_ranges.data, file, line, func );

    // create the pipeline object
    VkGraphicsPipelineCreateInfo pipeline_create_info = {
        flags               : meta.pipeline_create_flags,
        stageCount          : meta.shader_stages.length.toUint,
        pStages             : meta.shader_stages.ptr,
        pVertexInputState   : & vertex_input_state_create_info,
        pInputAssemblyState : & meta.input_assembly_state,
        pTessellationState  : meta.tesselation_patch_control_points > 0 ? & tessellation_state_create_info : null,  // assume inputAssembly = VK_PRIMITIVE_TOPOLOGY_PATCH_LIST
        pViewportState      : & viewport_state_create_info,
        pRasterizationState : & meta.rasterization_state,
        pMultisampleState   : & meta.multisample_state,
        pDepthStencilState  : & meta.depth_stencil_state,
        pColorBlendState    : & meta.color_blend_state,
        pDynamicState       : & dynamic_state_create_info,
        layout              : meta.pipeline_layout,
        renderPass          : meta.render_pass,
        subpass             : meta.subpass,
        basePipelineHandle  : meta.base_pipeline_handle,
        basePipelineIndex   : -1,//meta.base_pipeline_index,
    };

    if( meta.base_pipeline_handle  != VK_NULL_HANDLE /*|| meta.base_pipeline_index != -1*/ )
        pipeline_create_info.flags |= VK_PIPELINE_CREATE_DERIVATIVE_BIT;

    meta.device.vkCreateGraphicsPipelines(
        pipeline_cache,         // pipelineCache
        1,                      // createInfoCount
        &pipeline_create_info,  // pCreateInfos
        meta.allocator,         // pAllocator
        &meta.pipeline          // pPipelines
        ).vkAssert( "Construct Graphics Pipeline", file, line, func );

    return meta;
}


auto ref construct(
    ref Meta_Graphics   meta,
    VkPipelineLayout    pipeline_layout,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    return meta.construct( VK_NULL_HANDLE, pipeline_layout, file, line, func );
}



//////////////////////////
// Meta_Compute related //
//////////////////////////


/// meta struct to configure a graphics VkPipeline and allocate a
/// dynamic arrays exist to add VkDescriptorSetLayout and VkPushConstantRange
/// must be initialized with a Vulkan state struct
struct Meta_Compute {
    mixin                                       Vulkan_State_Pointer;

    VkPipeline                                  pipeline;
    VkComputePipelineCreateInfo                 pipeline_create_info;

    Array!VkDescriptorSetLayout                 descriptor_set_layouts;
    Array!VkPushConstantRange                   push_constant_ranges;

    VkPipelineLayout                            pipeline_layout() { return pipeline_create_info.layout; }

    void destroyResources() {
        vdrive.state.destroy( vk, pipeline );                               // no nice syntax, vdrive.state.destroy overloads
        vdrive.state.destroy( vk, pipeline_create_info.layout );    // get confused with this one in the module scope
    }
}


/// reset all internal data and return wrapped Vulkan objects
/// VkPipeline and VkPipelineLayout
auto reset( ref Meta_Compute meta ) {
    Core_Pipeline result = { meta.pipeline, meta.pipeline_create_info.layout };
    meta.descriptor_set_layouts.clear;
    meta.push_constant_ranges.clear;
    return result;
}


//////////////////////////////
// shader stage create info //
//////////////////////////////
auto ref shaderStageCreateInfo( ref Meta_Compute meta, VkPipelineShaderStageCreateInfo shader_stage_create_info ) {
    meta.pipeline_create_info.stage = shader_stage_create_info;
    return meta;
}

/// destroy shader module, can happen immediatelly after PSO construction
auto ref destroyShaderModule( ref Meta_Compute meta ) {
    vdrive.state.destroy( meta, meta.pipeline_create_info.stage._module );
    return meta;
}


/////////////////////
// pipeline layout //
/////////////////////
alias addDescriptorSetLayout = addDescriptorSetLayoutImpl!Meta_Compute;
alias addPushConstantRange   = addPushConstantRangeImpl_1!Meta_Compute;
alias addPushConstantRange   = addPushConstantRangeImpl_2!Meta_Compute;



//////////////////////////////////////////////////////
// base pipeline, optimization and flags in general //
//////////////////////////////////////////////////////

/// set base pipeline handle for derivated pipelines
auto ref basePipeline( ref Meta_Compute meta, VkPipeline base_pipeline_handle ) {
    meta.pipeline_create_info.basePipelineHandle = base_pipeline_handle;
    if( base_pipeline_handle != VK_NULL_HANDLE )    // we might not know if the passed in pipeline was created already
        meta.pipeline_create_info.flags |= VK_PIPELINE_CREATE_DERIVATIVE_BIT;
    return meta;
}

/* not using multi pipeline creation yet
auto ref basePipeline( ref Meta_Compute meta, int32_t base_pipeline_index ) {
    meta.pipeline_create_info.basePipelineIndex = base_pipeline_index;
    return meta;
}
*/

/// disable pipeline optimization
auto ref disableOptimization( ref Meta_Compute meta ) {
    meta.pipeline_create_info.flags |= VK_PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT;
    return meta;
}

/// allow that this piplein can have derivative pipleines
auto ref allowDerivatives( ref Meta_Compute meta ) {
    meta.pipeline_create_info.flags |= VK_PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT;
    return meta;
}

/// general variant for setting flags
auto ref pipelineCeateFlags( ref Meta_Compute meta, VkPipelineCreateFlags flags ) {
    meta.pipeline_create_info.flags = flags;
}



/////////////////////////////////////////
// construct the pipeline state object //
/////////////////////////////////////////
auto ref construct(
    ref Meta_Compute    meta,
    VkPipelineCache     pipeline_cache  = VK_NULL_HANDLE,
    VkPipelineLayout    pipeline_layout = VK_NULL_HANDLE,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    // assert that meta struct is initialized with a valid vulkan state pointer
    meta.isValid.vkAssert( "Meta Struct not initialized", file, line, func );

    if( pipeline_layout )
        meta.pipeline_create_info.layout = pipeline_layout;
    else
        meta.pipeline_create_info.layout = meta.createPipelineLayout( meta.descriptor_set_layouts.data, meta.push_constant_ranges.data );

    meta.device.vkCreateComputePipelines(
        pipeline_cache,             // pipelineCache
        1,                          // createInfoCount
        &meta.pipeline_create_info, // pCreateInfos
        meta.allocator,             // pAllocator
        &meta.pipeline              // pPipelines
        ).vkAssert( "Construct Compute Pipeline", file, line, func );

    return meta;
}



auto ref construct(
    ref Meta_Compute    meta,
    VkPipelineLayout    pipeline_layout,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    return meta.construct( VK_NULL_HANDLE, pipeline_layout, file, line, func );
}



bool is_null( Core_Pipeline pso ) { return pso.pipeline.is_null_handle; }
bool is_null( Meta_Graphics pso ) { return pso.pipeline.is_null_handle; }
bool is_null( Meta_Compute  pso ) { return pso.pipeline.is_null_handle; }

bool is_constructed( Core_Pipeline pso ) { return !pso.is_null; }
bool is_constructed( Meta_Graphics pso ) { return !pso.is_null; }
bool is_constructed( Meta_Compute  pso ) { return !pso.is_null; }