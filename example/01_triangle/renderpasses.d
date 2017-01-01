module renderpasses;

import erupted;
import derelict.glfw3;

import std.stdio;

import vdrive.state;
import vdrive.memory;
import vdrive.surface;
import vdrive.renderpass;
import vdrive.util.info;
import vdrive.util.util;
import vdrive.util.array;

import appstruct;



auto ref createRenderPasses( ref VDriveState vd, VkSampleCountFlagBits sample_count ) {

	//////////////////////////
	// create render passes //
	//////////////////////////

	//render_passes.append( vd.initRenderPass )
	vd.render_pass( vd )
		.renderPassAttachment_Clear_None(  vd.depth_image.image_create_info.format, sample_count, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL ).subpassRefDepthStencil
		.renderPassAttachment_Clear_Store( vd.surface.imageFormat, sample_count, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR ).subpassRefColor( VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL )

		// specify dependencies despite of only one subpass, as suggested by:
		// https://software.intel.com/en-us/articles/api-without-secrets-introduction-to-vulkan-part-4#
		.addDependencyByRegion
		.srcDependency( VK_SUBPASS_EXTERNAL, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT         , VK_ACCESS_MEMORY_READ_BIT )
		.dstDependency( 0                  , VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT )

		//.subpassDependency( VK_SUBPASS_EXTERNAL, 0 )
		//.stageMaskDependency( VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT )
		//.accessMaskDependency( VK_ACCESS_MEMORY_READ_BIT, VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT )

		.addDependencyByRegion
		.srcDependency( 0                  , VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT )
		.dstDependency( VK_SUBPASS_EXTERNAL, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT         , VK_ACCESS_MEMORY_READ_BIT )

		.construct;

	return vd;
}



auto ref createFramebuffers( ref VDriveState vd ) {

	// compose render targets into an array
	VkImageView[1] render_targets = [ vd.depth_image.image_view ];

	vd.framebuffers( vd )
		.create( vd.render_pass.render_pass, vd.surface.imageExtent, render_targets, vd.present_image_views.data )
		.setClearValue( 0, 1.0f, 0 )					// first arg is the image_view index of the Meta_Framebuffer for clearing, ... 
		.setClearValue( 1, 0.3f, 0.3f, 0.3f, 1.0f );	// ... this prevents appending instead of setting of clear values when resizing, Meta_Framebuffer is reused
	//scope( exit ) sample_framebuffers.destroyResources;
	// attaching the framebuffer also sets the clear values and render area extent into the render pass begin info
	// setting clear values coresponding to framebuffer attachments and framebuffer extent could have happend before, e.g.:
	//		vd.sample_pass.clearValues( some_clear_values );
	//		vd.sample_pass.begin_info.renderArea = some_render_area;
	// but meta framebuffer(s) has the storage for them, hence no need to create and manage extra storage/variables
	vd.render_pass.attachFramebuffer( vd.framebuffers, 0 );

	return vd;
}


