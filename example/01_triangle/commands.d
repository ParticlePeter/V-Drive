module commands;

import erupted;

//import std.stdio;

import vdrive.state;
import vdrive.command;
import vdrive.util.util;
import vdrive.util.array;

import appstruct;



auto ref createFenceAndCommandPool( ref VDriveState vd ) {

	VkFenceCreateInfo fence_create_info;
	vkCreateFence( vd.device, &fence_create_info, vd.allocator, &vd.submit_fence );

	vd.cmd_pool = vdrive.command.createCommandPool( vd, vd.surface.present_queue_family_index );

	// rendering and presenting semaphores for VkSubmitInfo, VkPresentInfoKHR and vkAcquireNextImageKHR
	VkSemaphoreCreateInfo semaphore_create_info;// = VkSemaphoreCreateInfo( VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, null, 0 );

	vd.device.vkCreateSemaphore( &semaphore_create_info, vd.allocator, &vd.swapchain_semaphore ).vkEnforce;
	vd.device.vkCreateSemaphore( &semaphore_create_info, vd.allocator, &vd.frame_end_semaphore ).vkEnforce;

	return vd;
}


auto ref createCommands( ref VDriveState vd ) {

	// draw command buffer begin info for vkBeginCommandBuffer, can be used in any command buffer
	VkCommandBufferBeginInfo cmd_buffer_begin_info;


	// cmd_buffers is an Array!VkCommandBuffer, the array itself will be destroyd after this scope
	vd.cmd_buffers = vd.allocateCommandBuffers( vd.cmd_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, vd.present_image_views.length );


	import vdrive.renderpass : attachFramebuffer;
	// record command buffer for each swapchain image
	foreach( i, ref cmd_buffer; vd.cmd_buffers.data ) {

		// attach one of the framebuffers to the render pass
		vd.render_pass.attachFramebuffer( vd.framebuffers.framebuffer[ i ] );


		// begin command buffer recording
		cmd_buffer.vkBeginCommandBuffer( &cmd_buffer_begin_info );


		// begin the render_pass
		cmd_buffer.vkCmdBeginRenderPass( &vd.render_pass.begin_info, VK_SUBPASS_CONTENTS_INLINE );


		// bind graphics vd.geom_pipeline
		cmd_buffer.vkCmdBindPipeline( VK_PIPELINE_BIND_POINT_GRAPHICS, vd.pipeline.pipeline );    


		// take care of dynamic state
		cmd_buffer.vkCmdSetViewport( 0, 1, &vd.viewport );
		cmd_buffer.vkCmdSetScissor(  0, 1, &vd.scissors );
		cmd_buffer.vkCmdBindDescriptorSets(
			VK_PIPELINE_BIND_POINT_GRAPHICS, vd.pipeline.pipeline_layout, 0, 1, &vd.wvpm_descriptor.set, 0, null );


		// record triangle draw commands
		vd.triangle.recordDrawCommands( cmd_buffer );


		// end the render pass
		cmd_buffer.vkCmdEndRenderPass;


		// end command buffer recording
		cmd_buffer.vkEndCommandBuffer;
	}



	// draw submit info for vkQueueSubmit
	with( vd.submit_info ) {
		waitSemaphoreCount		= 1;
		pWaitSemaphores			= &vd.swapchain_semaphore;
		pWaitDstStageMask		= &vd.wait_stage_mask;
		commandBufferCount		= 1;
		//pCommandBuffers		= &vd.cmd_buffers[ i ];		// set this parameter before submission, choosing cmd_buffers[0/1]
		signalSemaphoreCount	= 1;
		pSignalSemaphores		= &vd.frame_end_semaphore;
	}



	// present info for vkQueuePresentKHR
	with( vd.present_info ) {
		waitSemaphoreCount	= 1;
		pWaitSemaphores		= &vd.frame_end_semaphore;
		swapchainCount		= 1;
		pSwapchains			= &vd.surface.swapchain;
		//pImageIndices		= &next_image_index;			// set this parameter before presentation, using the acquired next_image_index
		pResults			= null;
	}

	return vd;
}