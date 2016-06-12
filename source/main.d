
import std.stdio;
import vdrive.util.array;

import erupted;

//import vdrive.glfw.vulkan_glfw3;
import derelict.glfw3;

import vdrive.util.info;
import vdrive.util.util;
import vdrive.state;



extern( C ) void key_callback( GLFWwindow * window, int key, int scancode, int val, int mod ) nothrow {
	if( key == GLFW_KEY_ESCAPE && val == GLFW_PRESS ) {
		glfwSetWindowShouldClose( window, GLFW_TRUE );
	}
}

extern( System ) VkBool32 debugReport(
	VkDebugReportFlagsEXT       flags,
	VkDebugReportObjectTypeEXT  objectType,
	uint64_t                    object,
	size_t                      location,
	int32_t                     messageCode,
	const char*                 pLayerPrefix,
	const char*                 pMessage,
	void*                       pUserData) nothrow @nogc
{
	printf( "ObjectTpye  : %i\nMessage     : %s\n", objectType, pMessage );
	return VK_FALSE;
}
 
mixin DerelictGLFW3_VulkanBind;

int main() {

	printf( "\n" );

	// Initialize Vulkan with DerelictErupted
	//DerelictErupted.load();

	// Initialize Vulkan with GLFW3
	DerelictGLFW3.load;
	DerelictGLFW3_loadVulkan();

	glfwInit();
	loadGlobalLevelFunctions( cast( typeof( vkGetInstanceProcAddr ))
		glfwGetInstanceProcAddress( null, "vkGetInstanceProcAddr" ));


	immutable uint32_t win_w = 720, win_h = 480;



	// glfw window specification
	glfwWindowHint( GLFW_CLIENT_API, GLFW_NO_API );
	GLFWwindow* window = glfwCreateWindow( win_w, win_h, "Vulkan Erupted", null, null );
	glfwSetKeyCallback( window, &key_callback );

	// destroy the window and terminate glfw at scope exist
	scope( exit ) {
		glfwDestroyWindow( window );
		glfwTerminate();
	}

	//listExtensions;
	//listLayers;
	//list_glfw_required_extensions;		// glfw required extensions

	verbose = false;

	//"VK_LAYER_LUNARG_standard_validation".isLayer;

	static if( true )	const( char* )[1] layers = [ "VK_LAYER_LUNARG_standard_validation" ];
	else				const( char* )[7] layers = [ 
		"VK_LAYER_GOOGLE_threading",
		"VK_LAYER_LUNARG_parameter_validation",
		"VK_LAYER_LUNARG_device_limits",
		"VK_LAYER_LUNARG_object_tracker",
		"VK_LAYER_LUNARG_image",
		"VK_LAYER_LUNARG_core_validation",
		"VK_LAYER_LUNARG_swapchain",
		//"VK_LAYER_GOOGLE_unique_objects"
	];


	// Checking for extensions
	const( char* )[3] extensions = [ "VK_KHR_surface", "VK_KHR_win32_surface", "VK_EXT_debug_report" ];
	foreach( extension; extensions ) {
		if( !extension.isExtension( false )) {
			printf( "Required layer %s not available. Exiting!\n", extension );
			return 1;
		}
	}

	// Create vdrive vulkan state struct and initialize the instance
	Vulkan vk;
	vk.initInstance( extensions, layers );
	//vk.initInstance( "VK_KHR_surface\0VK_KHR_win32_surface\0VK_EXT_debug_report\0", "VK_LAYER_LUNARG_standard_validation\0" );		//string[2] extensions = [ "VK_KHR_surface", "VK_KHR_win32_surface" ];
	scope( exit ) vk.destroy_instance;		// destroy the instance at scope exist

	// setup debug report callback
	VkDebugReportCallbackCreateInfoEXT callbackCreateInfo = {
		flags		: VK_DEBUG_REPORT_ERROR_BIT_EXT | VK_DEBUG_REPORT_WARNING_BIT_EXT | VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT,
		pfnCallback	: &debugReport,
		pUserData	: null,
	};

	VkDebugReportCallbackEXT debugReportCallback;
	vkCreateDebugReportCallbackEXT( vk.instance, &callbackCreateInfo, vk.allocator, &debugReportCallback );
	scope( exit ) vkDestroyDebugReportCallbackEXT( vk.instance, debugReportCallback, vk.allocator );

	// create the window VkSurfaceKHR with the instance, surface is stored in the state object 
	glfwCreateWindowSurface( vk.instance, window, null, &vk.surface ).vk_enforce;
	scope( exit ) vk.destroy_surface;

	// Set the desired surface extent, this might change at swapchain creation 
	vk.surface_extent = VkExtent2D( win_w, win_h );

	// enumerate gpus
	auto gpus = vk.instance.listPhysicalDevices( false );

	//foreach( ref gpu; gpus ) gpu.listProperties( GPU_Info.properties /*| GPU_Info.limits | GPU_Info.sparse_properties*/ );
	//foreach( ref gpu; gpus ) gpu.listFeatures;
	//foreach( ref gpu; gpus ) gpu.listLayers;
	//foreach( ref gpu; gpus ) gpu.listExtensions;
	//foreach( ref gpu; gpus ) printf( "Present supported: %u\n", gpu.presentSupport( vk.surface ));

	// set the desired gpu into the state object
	// TODO(pp): find a suitable "best fit" gpu

	auto queue_families = listQueueFamilies( gpus[0], false );
	auto compute_queues = queue_families.filter_queue_flags( VK_QUEUE_COMPUTE_BIT, VK_QUEUE_GRAPHICS_BIT );
	auto graphic_queues = queue_families.filter_queue_flags( VK_QUEUE_GRAPHICS_BIT ).filterPresentSupport( gpus[0], vk.surface );

	vk.gpu = gpus[0];
	vk.present_queue_family_index = graphic_queues.front.family_index;

	// memory properties of the current gpu
	// TODO(pp): the memory properties do not print nicely, fix this
	vk.memory_properties = vk.gpu.listMemoryProperties( false );

	//printf( "Graphics queue family count with presentation support: %u\n", graphics_queue.length );

	// Enable graphic Queue
	//Queue_Family[1] filtered_queues = [ graphic_queues.front ];
	//filtered_queues[0].queueCount = 1;
	//filtered_queues[0].priority( 0 ) = 1;
	//writeln( filtered_queues );

	// Eanable graphic and compute queue
	Queue_Family[2] filtered_queues = [ graphic_queues.front, compute_queues.front ];
	filtered_queues[0].queueCount = 1;
	filtered_queues[0].priority( 0 ) = 1;
	filtered_queues[1].queueCount = 1;			// float[2] compute_priorities = [0.8, 0.5];
	filtered_queues[1].priority( 0 ) = 0.8;		// filtered_queues[1].priorities = compute_priorities;
	//writeln( filtered_queues );



	// query the device features of the gpu in question, enable shaderClipDistance if available
	VkPhysicalDeviceFeatures features;
	features.shaderClipDistance = vk.gpu.listFeatures( false ).shaderClipDistance;


	// init the logical device
	const( char* )[1] deviceExtensions = [ "VK_KHR_swapchain" ];
	vk.initDevice( filtered_queues, deviceExtensions, layers, &features );
	scope( exit ) vk.destroyDevice;


	// retrieve graphic and present queues
	// for now graphic and present queue are the same, but this might difere on diferent hardeare
	vkGetDeviceQueue( vk.device, vk.present_queue_family_index, 0, &vk.present_queue );


	//////////////////////////////////////////////////
	// create a swapchain for render result display //
	//////////////////////////////////////////////////
	import vdrive.swapchain;
	Array!VkImageView present_image_views;
	vk.init_swapchain( present_image_views ).vk_enforce;
	scope( exit ) {
		foreach( ref image_view; present_image_views ) vk.device.vkDestroyImageView( image_view, vk.allocator );
		vk.device.vkDestroySwapchainKHR( vk.swapchain, vk.allocator );
	}



	///////////////////////////////////////////////
	// create a depth image for the framebuffers //
	///////////////////////////////////////////////

	// this subresource range is used in additional places
	VkImageSubresourceRange depth_image_subresource_range = { VK_IMAGE_ASPECT_DEPTH_BIT, 0, 1, 0, 1 };

	// for now this is required for framebuffer creation, TODO(pp): remove dependency
	vk.depth_image_format = VK_FORMAT_D16_UNORM;

	// create image with memory and view in a meta image struct
	import vdrive.image;
	Meta_Image depth_meta_image = &vk;
	//depth_meta_image.createImage( depth_image_create_info );
	depth_meta_image.createDepthBufferImage( vk.depth_image_format, vk.surface_extent );
	depth_meta_image.bindMemory( VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT );
	depth_meta_image.imageView( depth_image_subresource_range );

	scope( exit ) {
		vk.device.vkDestroyImage( depth_meta_image.image, vk.allocator );
		vk.device.vkFreeMemory( depth_meta_image.device_memory, vk.allocator );
		vk.device.vkDestroyImageView( depth_meta_image.image_view, vk.allocator );
	}

	vk.depth_image = depth_meta_image.image ;
	vk.depth_image_view = depth_meta_image.image_view;

	depth_meta_image.printStructInfo;



	//////////////////////////////////////////////////
	// create a command pools for image transitions //
	//////////////////////////////////////////////////
	import vdrive.command;
	auto command_pool = vk.createCommandPool( vk.present_queue_family_index, VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT );
	scope( exit ) vk.device.vkDestroyCommandPool( command_pool, vk.allocator );

	{	// command_buffers is an Array!VkCommandBuffer, the array itself will be destroyd after this scope
		auto command_buffers = vk.allocateCommandBuffers( command_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, 2 );
		vk.init_command_buffer = command_buffers[0];
		vk.draw_command_buffer = command_buffers[1];
	}

	VkCommandBufferBeginInfo transition_command_buffer_begin_info = {
		flags : VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	};

	// create a fence for the transition
	VkFenceCreateInfo fence_create_info;
	VkFence submit_fence;
	vkCreateFence( vk.device, &fence_create_info, vk.allocator, &submit_fence );
	scope( exit ) vk.device.vkDestroyFence( submit_fence, vk.allocator );







	///////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transition of presentation images and depth image from VK_IMAGE_LAYOUT_UNDEFINED to               //
	// VK_IMAGE_LAYOUT_PRESENT_SRC_KHR and VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL respectively //
	///////////////////////////////////////////////////////////////////////////////////////////////////////

	// start recording on our setup command buffer:
	vkBeginCommandBuffer( vk.init_command_buffer, &transition_command_buffer_begin_info );

	// this subresource range is used in additional places
	VkImageSubresourceRange color_image_subresource_range = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };

	// loop over presentable images and add the transition to vk.init_command_buffer
	import vdrive.image;
	foreach( i; 0 .. vk.present_images.length ) {
		
		vk.init_command_buffer.imageTransition(
			vk.present_images[i], color_image_subresource_range,
			VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
			0, VK_ACCESS_MEMORY_READ_BIT
		);
	}





	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transition of depth images from VK_IMAGE_LAYOUT_UNDEFINED to VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL //
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	vk.init_command_buffer.imageTransition(
		vk.depth_image, depth_image_subresource_range,
		VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		0, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
	);

	vkEndCommandBuffer( vk.init_command_buffer );

	// create a submit info
	import vdrive.command;
	auto submit_info = vk.init_command_buffer.queueSubmitInfo;

	// submit the command buffer with swachain length + one depth image transitions
	vkQueueSubmit( vk.present_queue, 1, &submit_info, submit_fence ).vk_enforce;
	vkWaitForFences( vk.device, 1, &submit_fence, VK_TRUE, uint32_t.max );
	vkResetFences( vk.device, 1, &submit_fence );
	vkResetCommandBuffer( vk.init_command_buffer, 0 );




	//////////////////////////////////////////
	// create renderpass and framebuffer(s) //
	//////////////////////////////////////////
	import vdrive.framebuffer;
	vk.initFramebuffer( present_image_views.data );
	scope( exit ) {
		foreach( framebuffer; vk.framebuffers ) vk.device.vkDestroyFramebuffer( framebuffer, vk.allocator );
		vk.device.vkDestroyRenderPass( vk.render_pass, vk.allocator );
	}


	///////////////////////////////////
	// create triangle vertex buffer //
	///////////////////////////////////
	import vdrive.geometry;
	auto vertex_meta_buffer = vk.initTriangle;
	scope( exit ) {
		vk.device.vkDestroyBuffer( vertex_meta_buffer.buffer, vk.allocator );
		vk.device.vkFreeMemory( vertex_meta_buffer.device_memory, vk.allocator );
	}


	/////////////////////////
	// create the pipeline //
	/////////////////////////
	import vdrive.pipeline;
	auto shader_modules = vk.createPipeline;
	scope( exit ) {
		vk.device.vkDestroyPipeline( vk.pipeline, vk.allocator );
		vk.device.vkDestroyPipelineLayout( vk.pipeline_layout, vk.allocator );
		foreach( ref shader_module; shader_modules ) vk.device.vkDestroyShaderModule( shader_module, vk.allocator );
	}


	///////////////////////////
	// prepare for rendering //
	///////////////////////////

	// draw command buffer begin info for vkBeginCommandBuffer
	VkCommandBufferBeginInfo draw_command_buffer_begin_info = {
		flags : VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	};


	// transition swapchain image from undefined ( old present data ) to attachment for vkCmdPipelineBarrier
	VkImageMemoryBarrier undefined_to_attachment_barrier = {
	//	srcAccessMask		: VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
		dstAccessMask		: VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
		oldLayout			: VK_IMAGE_LAYOUT_UNDEFINED,	// VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,	// Old Data irrelevant, this is faster
		newLayout			: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
		srcQueueFamilyIndex	: VK_QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex	: VK_QUEUE_FAMILY_IGNORED,
		subresourceRange	: color_image_subresource_range,
	};


	// create render pass clear values for VkRenderPassBeginInfo
	VkClearValue[2] clear_value;
	clear_value[0].color.float32 = [ 1.0f, 1.0f, 1.0f, 1.0f ];
	clear_value[1].depthStencil = VkClearDepthStencilValue( 1.0f, cast( uint32_t )0 );

	// render pass begin info for vkCmdBeginRenderPass
	VkRenderPassBeginInfo renderPassBeginInfo = {
		renderPass		: vk.render_pass,
		renderArea		: VkRect2D( VkOffset2D( 0, 0 ), vk.surface_extent ),
		clearValueCount	: 2,
		pClearValues	: clear_value.ptr,
	};


	// viewport and scissors (not so) dynamic state for vkCmdSetViewport and vkCmdSetScissor
	auto viewport = VkViewport( 0, 0, vk.surface_extent.width, vk.surface_extent.height, 0, 1 );
	auto scissors = VkRect2D( VkOffset2D( 0, 0 ), vk.surface_extent );


	// transition swapchain image from attachment to presentable for vkCmdPipelineBarrier
	VkImageMemoryBarrier attachment_to_present_barrier = {
		srcAccessMask		: VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
		dstAccessMask		: VK_ACCESS_MEMORY_READ_BIT,
		oldLayout			: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
		newLayout			: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
		srcQueueFamilyIndex	: VK_QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex	: VK_QUEUE_FAMILY_IGNORED,
		subresourceRange	: color_image_subresource_range,
	};

	// rendering and presenting semaphores for VkSubmitInfo, VkPresentInfoKHR and vkAcquireNextImageKHR
	VkSemaphore	image_ready_semaphore, render_done_semaphore;
	VkSemaphoreCreateInfo semaphore_create_info;// = VkSemaphoreCreateInfo( VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, null, 0 );
	vk.device.vkCreateSemaphore( &semaphore_create_info, null, &image_ready_semaphore ).vk_enforce;
	vk.device.vkCreateSemaphore( &semaphore_create_info, null, &render_done_semaphore ).vk_enforce;
	scope( exit ) {
		vk.device.vkDestroySemaphore( render_done_semaphore, null );
		vk.device.vkDestroySemaphore( image_ready_semaphore, null );
	}

	// queue submit info for vkQueueSubmit
	VkPipelineStageFlags render_wait_stage_mask = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;
	VkSubmitInfo render_submit_info = {
		waitSemaphoreCount		: 1,
		pWaitSemaphores			: &image_ready_semaphore,
		pWaitDstStageMask		: &render_wait_stage_mask,
		commandBufferCount		: 1,
		pCommandBuffers			: &vk.draw_command_buffer,
		signalSemaphoreCount	: 1,
		pSignalSemaphores		: &render_done_semaphore,
	};


	// fence waiting for queue completion
	VkFence render_fence;
	VkFenceCreateInfo fenceCreateInfo = {};
	vkCreateFence( vk.device, &fenceCreateInfo, null, &render_fence );
	scope( exit ) vkDestroyFence( vk.device, render_fence, null );


	// present info for vkQueuePresentKHR
	VkPresentInfoKHR present_info = {
		waitSemaphoreCount	: 1,
		pWaitSemaphores		: &render_done_semaphore,
		swapchainCount		: 1,
		pSwapchains			: &vk.swapchain,
		//pImageIndices		: &next_image_index,
		pResults			: null,
	};


	

	void render() {

		uint32_t next_image_index;
		// acquire next swapchain image - first time that VK_NULL_HANDLE is not working
		vkAcquireNextImageKHR( vk.device, vk.swapchain, uint64_t.max, image_ready_semaphore, VK_NULL_ND_HANDLE, &next_image_index );


		// Transition presentable image layout
		vk.draw_command_buffer.vkBeginCommandBuffer( &draw_command_buffer_begin_info );


		// change image layout from VK_IMAGE_LAYOUT_UNDEFINED to VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
		undefined_to_attachment_barrier.image = vk.present_images[ next_image_index ];
		vk.draw_command_buffer.vkCmdPipelineBarrier(
			VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, 0,	// flags
			0, null, 0, null, 1, &undefined_to_attachment_barrier						// barriers
		);


		// begin the render_pass
		renderPassBeginInfo.framebuffer = vk.framebuffers[ next_image_index ];
		vk.draw_command_buffer.vkCmdBeginRenderPass( &renderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE );


		// bind graphics pipeline
		vk.draw_command_buffer.vkCmdBindPipeline( VK_PIPELINE_BIND_POINT_GRAPHICS, vk.pipeline );    


		// take care of dynamic state
		vk.draw_command_buffer.vkCmdSetViewport( 0, 1, &viewport );
		vk.draw_command_buffer.vkCmdSetScissor(  0, 1, &scissors );


		// draw the triangle
		vk.draw_command_buffer.vkCmdBindVertexBuffers( 0, 1, &vertex_meta_buffer.buffer, &vertex_meta_buffer.buffer_offset );
		vk.draw_command_buffer.vkCmdDraw( 3, 1, 0, 0 );  // vertex count, instance count, first vertex, first instance
		vk.draw_command_buffer.vkCmdEndRenderPass;


		// transition the next swapchain image to presentable with a VkImageMemoryBarrier
		attachment_to_present_barrier.image = vk.present_images[ next_image_index ];
		vk.draw_command_buffer.vkCmdPipelineBarrier(
			VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, 0,	// flags 
			0, null, 0, null, 1, &attachment_to_present_barrier								// barriers
		);

		// end command buffer recording
		vk.draw_command_buffer.vkEndCommandBuffer;


		// submit command buffer to queue
		vk.present_queue.vkQueueSubmit( 1, &render_submit_info, render_fence );
		vk.device.vkWaitForFences( 1, &render_fence, VK_TRUE, uint64_t.max );
		vk.device.vkResetFences( 1, &render_fence ).vk_enforce;


		// present rendered image
		present_info.pImageIndices = &next_image_index;
		vk.present_queue.vkQueuePresentKHR( &present_info );
	}



//*
	while( !glfwWindowShouldClose( window )) {
		render;
		glfwSwapBuffers(window);
		glfwPollEvents();
	}	
//*/
	
	// drain work
	vk.device.vkDeviceWaitIdle;

	printf( "\n" );
	return 0;
}

