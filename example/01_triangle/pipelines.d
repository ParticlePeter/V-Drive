module pipelines;

import erupted;
import derelict.glfw3;

import std.stdio;

import vdrive.state;
import vdrive.shader;
import vdrive.surface;
import vdrive.pipeline;
import vdrive.util.info;
import vdrive.util.util;
import vdrive.util.array;

import appstruct;





auto ref createPipelines( ref VDriveState vd, VkSampleCountFlagBits	sample_count ) {

	//////////////////////
	// create pipelines //
	//////////////////////
	// add shader stages - git repo needs only to keep track of the shader sources, 
	// vdrive will compile them into spir-v with glslangValidator (must be in path !)
	vd.pipeline( vd )
		.addShaderStageCreateInfo( vd.createPipelineShaderStage( VK_SHADER_STAGE_VERTEX_BIT,   "example/01_triangle/shader/simple.vert" ))
		.addShaderStageCreateInfo( vd.createPipelineShaderStage( VK_SHADER_STAGE_FRAGMENT_BIT, "example/01_triangle/shader/simple.frag" ))

		// add vertex binding and attribute descriptions
		// indices and vertex attributes are stored consecutively and noninterleaved in one VkBuffer (indices, positions, normals)
		.addBindingDescription( 0, 3 * float.sizeof, VK_VERTEX_INPUT_RATE_VERTEX )
		.addAttributeDescription( 0, 0, VK_FORMAT_R32G32B32_SFLOAT, 0 )

		// set the inputAssembly
		.inputAssembly( VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST )

		// add viewport and scissor state
		.addViewportAndScissors( VkOffset2D( 0, 0 ), vd.surface.imageExtent )

		// set rasterization state
		//.cullMode( VK_CULL_MODE_BACK_BIT )
	
		// set depth state - enable depth test with default attributes
		.depthState

		// color blend state - append common (default) color blend attachment state
		.addColorBlendState( VK_FALSE )

		// add dynamic states
		.addDynamicState( VK_DYNAMIC_STATE_VIEWPORT )
		.addDynamicState( VK_DYNAMIC_STATE_SCISSOR )

		// describe pipeline[0] layout
		.addDescriptorSetLayout( vd.wvpm_descriptor.set_layout )

		// describe compatible render pass 
		.renderPass( vd.render_pass.render_pass )

		// create the pipeline[0] state object
		.construct;

	// specify initial viewport and scissors
	vd.viewport = VkViewport( 0, 0, vd.surface.imageExtent.width, vd.surface.imageExtent.height, 0, 1 ); 
	vd.scissors = VkRect2D( VkOffset2D( 0, 0 ), vd.surface.imageExtent );

	return vd;
}





auto createDescriptorSets( ref VDriveState vd ) {

	//vd.descriptor_pool = vd.createDescriptorPool( VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER | VK_DESCRIPTOR_TYPE_STORAGE_BUFFER | VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 3, 2 );
	VkDescriptorPoolSize[1] descriptor_pool_sizes = [ VkDescriptorPoolSize( VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1 ) ];
	vd.descriptor_pool = vd.createDescriptorPool( descriptor_pool_sizes, 1 );

	// the meta struct bellow is callable with a Vulkan state struct parameter to be initialized returning a reference to itself
	vd.wvpm_descriptor( vd ).create(
		vd.descriptor_pool, 0, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1, VK_SHADER_STAGE_VERTEX_BIT );



	// When a set is allocated all values are undefined and all 
	// descriptors are uninitialised. must init all statically used bindings:

// TODO(pp): create overloads of createDescriptorInfo in shader module for the struct bellow and VkDescriptorImageInfo

	VkDescriptorBufferInfo descriptor_wvpm_info = {
		buffer	: vd.wvpm_buffer.buffer,
		offset	: 0,
		range	: vd.wvpm_buffer.size,	// VK_WHOLE_SIZE not working here, Driver Bug?	
	};



	VkWriteDescriptorSet[1] write_descriptor_sets;
	write_descriptor_sets[0].dstSet				= vd.wvpm_descriptor.set;
	write_descriptor_sets[0].dstBinding			= 0;
	write_descriptor_sets[0].dstArrayElement	= 0;
	write_descriptor_sets[0].descriptorCount	= 1;
	write_descriptor_sets[0].descriptorType		= VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
	write_descriptor_sets[0].pImageInfo			= null;
	write_descriptor_sets[0].pBufferInfo		= &descriptor_wvpm_info;
	write_descriptor_sets[0].pTexelBufferView	= null;

// TODO(pp): remove VkBufferView from Meta_Buffer, as VkBufferView is only required for the above pTexelBufferView

	vd.device.vkUpdateDescriptorSets( write_descriptor_sets.length.toUint, write_descriptor_sets.ptr, 0, null );	// last parameters are copy count and pointer to copies

	return vd;
}