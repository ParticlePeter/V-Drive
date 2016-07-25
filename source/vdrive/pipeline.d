module vdrive.pipeline;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.surface;
import vdrive.geometry;

import erupted;



auto createPipeline(
	ref Vulkan 				vk,
	ref Meta_Geometry		meta_geometry,
	VkDescriptorSetLayout	descriptor_set_layout,
	VkRenderPass			render_pass,
	VkExtent2D				viewport_extent,
	VkSampleCountFlagBits	sample_count = VK_SAMPLE_COUNT_4_BIT ) {

	// Create an empty pipeline
	VkPipelineLayoutCreateInfo layout_create_info = {
		setLayoutCount			: 1,
		pSetLayouts				: &descriptor_set_layout,
		pushConstantRangeCount	: 0,
		pPushConstantRanges		: null,
	};

	vk.device.vkCreatePipelineLayout( &layout_create_info, vk.allocator, &vk.pipeline_layout ).vkEnforce;



	// describe shaders
	// git repo has only the shader sources, they must be manually converted to spv files for now(!)
	// TODO(pp): use OS process and glslangValidator to compile the shaders and load the binary version
	import vdrive.shader;
	VkPipelineShaderStageCreateInfo[2] shaderStageCreateInfo = [
		vk.createPipelineShaderStageCreateInfo( VK_SHADER_STAGE_VERTEX_BIT, "shader/simple_normal_vert.spv" ),
		vk.createPipelineShaderStageCreateInfo( VK_SHADER_STAGE_FRAGMENT_BIT, "shader/simple_normal_frag.spv" )
	];

	// viewport state
	VkViewport viewport = {};
	viewport.x = 0;
	viewport.y = 0;
	viewport.width  = viewport_extent.width;
	viewport.height = viewport_extent.height;
	viewport.minDepth = 0;
	viewport.maxDepth = 1;

	VkRect2D scissors = {};
	scissors.offset = VkOffset2D( 0, 0 );
	scissors.extent = viewport_extent;

	VkPipelineViewportStateCreateInfo viewportState = {};
	viewportState.viewportCount = 1;
	viewportState.pViewports = &viewport;
	viewportState.scissorCount = 1;
	viewportState.pScissors = &scissors;


	// rasterisation state
	VkPipelineRasterizationStateCreateInfo rasterizationState = {};
	rasterizationState.depthClampEnable = VK_FALSE;
	rasterizationState.rasterizerDiscardEnable = VK_FALSE;
	rasterizationState.polygonMode = VK_POLYGON_MODE_FILL;
	rasterizationState.cullMode = VK_CULL_MODE_NONE;
	rasterizationState.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
	rasterizationState.depthBiasEnable = VK_FALSE;
	rasterizationState.depthBiasConstantFactor = 0;
	rasterizationState.depthBiasClamp = 0;
	rasterizationState.depthBiasSlopeFactor = 0;
	rasterizationState.lineWidth = 1;


	// sampling state
	VkPipelineMultisampleStateCreateInfo multisampleState = {};
	multisampleState.rasterizationSamples = sample_count;
	multisampleState.sampleShadingEnable = VK_FALSE;
	multisampleState.minSampleShading = 0;
	multisampleState.pSampleMask = null;
	multisampleState.alphaToCoverageEnable = VK_FALSE;
	multisampleState.alphaToOneEnable = VK_FALSE;



	// depth stencil state
	VkStencilOpState noOPStencilState = {};
	noOPStencilState.failOp = VK_STENCIL_OP_KEEP;
	noOPStencilState.passOp = VK_STENCIL_OP_KEEP;
	noOPStencilState.depthFailOp = VK_STENCIL_OP_KEEP;
	noOPStencilState.compareOp = VK_COMPARE_OP_ALWAYS;
	noOPStencilState.compareMask = 0;
	noOPStencilState.writeMask = 0;
	noOPStencilState.reference = 0;

	VkPipelineDepthStencilStateCreateInfo depthState = {};
	depthState.depthTestEnable = VK_TRUE;
	depthState.depthWriteEnable = VK_TRUE;
	depthState.depthCompareOp = VK_COMPARE_OP_LESS_OR_EQUAL;
	depthState.depthBoundsTestEnable = VK_FALSE;
	depthState.stencilTestEnable = VK_FALSE;
	depthState.front = noOPStencilState;
	depthState.back = noOPStencilState;
	depthState.minDepthBounds = 0;
	depthState.maxDepthBounds = 0;



	// color blend state
	VkPipelineColorBlendAttachmentState colorBlendAttachmentState = {};
	colorBlendAttachmentState.blendEnable = VK_FALSE;
	colorBlendAttachmentState.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_COLOR;
	colorBlendAttachmentState.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR;
	colorBlendAttachmentState.colorBlendOp = VK_BLEND_OP_ADD;
	colorBlendAttachmentState.srcAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
	colorBlendAttachmentState.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
	colorBlendAttachmentState.alphaBlendOp = VK_BLEND_OP_ADD;
	colorBlendAttachmentState.colorWriteMask = 0xf;

	VkPipelineColorBlendStateCreateInfo colorBlendState = {};
	colorBlendState.logicOpEnable = VK_FALSE;
	colorBlendState.logicOp = VK_LOGIC_OP_CLEAR;
	colorBlendState.attachmentCount = 1;
	colorBlendState.pAttachments = &colorBlendAttachmentState;
	colorBlendState.blendConstants = [ 0.0f, 0.0f, 0.0f, 0.0f ];
	//colorBlendState.blendConstants[0] = 0.0;
	//colorBlendState.blendConstants[1] = 0.0;
	//colorBlendState.blendConstants[2] = 0.0;
	//colorBlendState.blendConstants[3] = 0.0;


	// describe dynamic states
	VkDynamicState[2] dynamicState = [ VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR ];
	VkPipelineDynamicStateCreateInfo dynamicStateCreateInfo;
	dynamicStateCreateInfo.dynamicStateCount = 2;
	dynamicStateCreateInfo.pDynamicStates = dynamicState.ptr;



	// create the pipeline object
	VkGraphicsPipelineCreateInfo pipelineCreateInfo = {};
	pipelineCreateInfo.stageCount = 2;
	pipelineCreateInfo.pStages = shaderStageCreateInfo.ptr;
	pipelineCreateInfo.pVertexInputState = &meta_geometry.vertex_input_create_info;
	pipelineCreateInfo.pInputAssemblyState = &meta_geometry.input_assembly_create_info;
	pipelineCreateInfo.pTessellationState = null;
	pipelineCreateInfo.pViewportState = &viewportState;
	pipelineCreateInfo.pRasterizationState = &rasterizationState;
	pipelineCreateInfo.pMultisampleState = &multisampleState;
	pipelineCreateInfo.pDepthStencilState = &depthState;
	pipelineCreateInfo.pColorBlendState = &colorBlendState;
	pipelineCreateInfo.pDynamicState = &dynamicStateCreateInfo;
	pipelineCreateInfo.layout = vk.pipeline_layout;
	pipelineCreateInfo.renderPass = render_pass;
	pipelineCreateInfo.subpass = 0;
	pipelineCreateInfo.basePipelineHandle = VK_NULL_ND_HANDLE;
	pipelineCreateInfo.basePipelineIndex = 0;



	vk.device.vkCreateGraphicsPipelines( VK_NULL_ND_HANDLE, 1, &pipelineCreateInfo, vk.allocator, &vk.pipeline ).vkEnforce;

	auto shader_modules = sizedArray!VkShaderModule( 2 );
	shader_modules[0] = shaderStageCreateInfo[0]._module;
	shader_modules[1] = shaderStageCreateInfo[1]._module;

	return shader_modules;


}


