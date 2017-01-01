module images;

import erupted;
import derelict.glfw3;

import std.stdio;

import vdrive.state;
import vdrive.memory;
import vdrive.surface;
import vdrive.util.info;
import vdrive.util.util;
import vdrive.util.array;

import appstruct;

//nothrow:
auto ref setupSurface( ref VDriveState vd ) {

	//////////////////////////////////////////////////
	// create a swapchain for render result display //
	//////////////////////////////////////////////////

	// Get GPU surface capabilities to check for possible image usages
	//VkSurfaceCapabilitiesKHR surface_capabilities;
	//vkGetPhysicalDeviceSurfaceCapabilitiesKHR( surface.gpu, surface.surface, &surface_capabilities );
	//surface_capabilities.printTypeInfo;

	VkFormat[4] request_format = [ VK_FORMAT_R8G8B8_UNORM, VK_FORMAT_B8G8R8_UNORM, VK_FORMAT_R8G8B8A8_UNORM, VK_FORMAT_B8G8R8A8_UNORM ];
	VkPresentModeKHR[3] request_mode = [ VK_PRESENT_MODE_IMMEDIATE_KHR, VK_PRESENT_MODE_MAILBOX_KHR, VK_PRESENT_MODE_FIFO_KHR ];
	//VkPresentModeKHR[2] request_mode = [ VK_PRESENT_MODE_MAILBOX_KHR, VK_PRESENT_MODE_FIFO_KHR ];

	vd.surface( vd )
		.selectSurfaceFormat( request_format )
		.selectPresentMode( request_mode )
		.imageArrayLayers( 1 )
		.imageUsage( VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT )
		.construct;

	vd.present_image_views = vd.surface.swapchainImageViews;

	return vd;
}


auto ref createImages( ref VDriveState vd, VkSampleCountFlagBits sample_count ) {

	///////////////////
	// create images //
	///////////////////
	
	vd.depth_image( vd )
		.create( VK_FORMAT_D16_UNORM, vd.surface.imageExtent, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, sample_count )
		.createMemory( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT )
		.createView( VkImageSubresourceRange( VK_IMAGE_ASPECT_DEPTH_BIT, 0, 1, 0, 1 ));

	return vd;
}



void transitionImages( ref VDriveState vd ) {
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// record ransition of depth image from VK_IMAGE_LAYOUT_UNDEFINED to VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL //
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// allocate one command buffer cmd_buffer is an Array!VkCommandBuffer, the array itself will be destroyd after this scope
	import vdrive.command : allocateCommandBuffer, queueSubmitInfo;
	auto cmd_buffer = vd.allocateCommandBuffer( vd.cmd_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY );

	VkCommandBufferBeginInfo cmd_buffer_begin_info;
	vkBeginCommandBuffer( cmd_buffer, &cmd_buffer_begin_info );

	vd.depth_image.image.recordTransition(
		cmd_buffer, vd.depth_image.image_view_create_info.subresourceRange,
		VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		0, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
	);

	vkEndCommandBuffer( cmd_buffer );


	// submit info stays local
	auto submit_info = queueSubmitInfo( cmd_buffer );

	// submit the command buffer with one depth and one color image transitions
	vkQueueSubmit( vd.surface.present_queue, 1, &submit_info, vd.submit_fence ).vkEnforce;
	vkWaitForFences( vd.device, 1, &vd.submit_fence, VK_TRUE, uint32_t.max );
	vkResetFences( vd.device, 1, &vd.submit_fence );

	// reset the command pool to start recording drawing commands
	vd.device.vkResetCommandPool( vd.cmd_pool, 0 );	// second argument is VkCommandPoolResetFlags
}
