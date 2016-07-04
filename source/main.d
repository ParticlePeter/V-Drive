
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

	debug	const( char* )[1] layers = [ "VK_LAYER_LUNARG_standard_validation" ];
	else	const( char* )[0] layers;


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
	scope( exit ) vk.destroyInstance;		// destroy the instance at scope exist


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
	import vdrive.swapchain;
	Meta_Swapchain meta_swapchain = &vk;
	glfwCreateWindowSurface( vk.instance, window, vk.allocator, &meta_swapchain.create_info.surface ).vkEnforce;
	scope( exit ) meta_swapchain.destroySurface;
	meta_swapchain.imageExtent = VkExtent2D( win_w, win_h );	// Set the desired surface extent, this might change at swapchain creation


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
	auto compute_queues = queue_families.filterQueueFlags( VK_QUEUE_COMPUTE_BIT, VK_QUEUE_GRAPHICS_BIT );			// filterQueueFlags
	auto graphic_queues = queue_families.filterQueueFlags( VK_QUEUE_GRAPHICS_BIT ).filterPresentSupport( gpus[0], meta_swapchain.surface );	// filterQueueFlags.filterPresentSupport

	vk.gpu = gpus[0];
	vk.graphic_queue_family_index = meta_swapchain.present_queue_family_index = graphic_queues.front.family_index;

	//printf( "Graphics queue family count with presentation support: %u\n", graphics_queue.length );

//*
	// Enable graphic Queue
	Queue_Family[1] filtered_queues = [ graphic_queues.front ];
	filtered_queues[0].queueCount = 1;
	filtered_queues[0].priority( 0 ) = 1;
	//writeln( filtered_queues );
/*/
	// Eanable graphic and compute queue
	Queue_Family[2] filtered_queues = [ graphic_queues.front, compute_queues.front ];
	filtered_queues[0].queueCount = 1;
	filtered_queues[0].priority( 0 ) = 1;
	filtered_queues[1].queueCount = 1;			// float[2] compute_priorities = [0.8, 0.5];
	filtered_queues[1].priority( 0 ) = 0.8;		// filtered_queues[1].priorities = compute_priorities;
	//writeln( filtered_queues );
//*/


	// query the device features of the gpu in question, enable shaderClipDistance if available
	VkPhysicalDeviceFeatures features;
	features.shaderClipDistance = vk.gpu.listFeatures( false ).shaderClipDistance;


	// init the logical device
	const( char* )[1] deviceExtensions = [ "VK_KHR_swapchain" ];
	vk.initDevice( filtered_queues, deviceExtensions, layers, &features );
	scope( exit ) vk.destroyDevice;


	// retrieve graphic and present queues
	// for now graphic and present queue are the same, but this might difere on diferent hardeare
	vkGetDeviceQueue( vk.device, vk.graphic_queue_family_index, 0,   &vk.graphic_queue );
	vkGetDeviceQueue( vk.device, meta_swapchain.present_queue_family_index, 0, &meta_swapchain.present_queue );


	//////////////////////////////////////////////////
	// create a swapchain for render result display //
	//////////////////////////////////////////////////
	meta_swapchain.initSwapchain( true );
	auto present_image_views = meta_swapchain.swapchainImageViews; //Array!VkImageView;
	scope( exit ) {
		foreach( ref image_view; present_image_views )
			vk.device.vkDestroyImageView( image_view, vk.allocator );
		meta_swapchain.destroySwapchain;
		//meta_swapchain.destroyResources;
	}



	///////////////////////////////////////////////
	// create a depth image for the framebuffers //
	///////////////////////////////////////////////

	// checking format support
	//VkFormatProperties format_properties;
	//vk.gpu.vkGetPhysicalDeviceFormatProperties( VK_FORMAT_B8G8R8A8_UNORM, &format_properties );
	//format_properties.printTypeInfo;

	// checking image format support (additional capabilities)
	//VkImageFormatProperties image_format_properties;
	//vk.gpu.vkGetPhysicalDeviceImageFormatProperties(
	//	VK_FORMAT_B8G8R8A8_UNORM,
	//	VK_IMAGE_TYPE_2D,
	//	VK_IMAGE_TILING_OPTIMAL,
	//	VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
	//	0,
	//	&image_format_properties).vkEnforce;
	//image_format_properties.printTypeInfo;

	// this will be used for multi sampled images, framebuffer attachment and resolving and pipeline multisample state
	VkSampleCountFlagBits sample_count = VK_SAMPLE_COUNT_4_BIT;

	import vdrive.image;
	VkImageSubresourceRange color_image_subresource_range = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };	// this subresource range is used in additional places
	Meta_Image color_meta_image = &vk;																	// create image with memory and view in a meta image struct
	color_meta_image.createImage( VK_FORMAT_B8G8R8A8_UNORM, meta_swapchain.imageExtent, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, sample_count );
	color_meta_image.bindMemory( VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT );
	color_meta_image.imageView( color_image_subresource_range );
	scope( exit ) color_meta_image.destroyResources;
	
	VkImageSubresourceRange depth_image_subresource_range = { VK_IMAGE_ASPECT_DEPTH_BIT, 0, 1, 0, 1 };	// this subresource range is used in additional places
	Meta_Image depth_meta_image = &vk;																	// create image with memory and view in a meta image struct
	depth_meta_image.createImage( VK_FORMAT_D16_UNORM, meta_swapchain.imageExtent, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, sample_count );
	depth_meta_image.bindMemory( VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT );
	depth_meta_image.imageView( depth_image_subresource_range );
	scope( exit ) depth_meta_image.destroyResources;



	//////////////////////////////////////////
	// create renderpass and framebuffer(s) //
	//////////////////////////////////////////

	// pass this into initRenderPass function
	VkFormat[3] render_pass_formats = [ color_meta_image.image_create_info.format, depth_meta_image.image_create_info.format, meta_swapchain.imageFormat ];

	// pass this into initFramebuffer function
	VkImageView[2] render_targets = [ color_meta_image.image_view, depth_meta_image.image_view ];

	import vdrive.framebuffer;
	auto meta_render_pass = vk.initRenderPass( render_pass_formats, sample_count );
	auto meta_framebuffer = meta_render_pass.initFramebuffer( meta_swapchain.imageExtent, render_targets, present_image_views.data );
	scope( exit ) {
		//foreach( framebuffer; vk.framebuffers ) vk.device.vkDestroyFramebuffer( framebuffer, vk.allocator );
		//vk.device.vkDestroyRenderPass( vk.render_pass, vk.allocator );
		meta_framebuffer.destroyResources;
		meta_render_pass.destroyResources;
	}



	// TODO(pp): does not print struct content, probably because of the pointer member. Fix it!
	//depth_meta_image.printTypeInfo;



	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// create a command pool for drawing command buffers, will be used once for depth image transition //
	/////////////////////////////////////////////////////////////////////////////////////////////////////
	import vdrive.command;
	auto command_pool = vk.createCommandPool( meta_swapchain.present_queue_family_index );
	scope( exit ) vk.device.vkDestroyCommandPool( command_pool, vk.allocator );


	// allocate one command buffer command_buffer is an Array!VkCommandBuffer, the array itself will be destroyd after this scope
	auto init_command_buffer = vk.allocateCommandBuffer( command_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY );


	// create a fence for the transition
	VkFenceCreateInfo fence_create_info;
	VkFence submit_fence;
	vkCreateFence( vk.device, &fence_create_info, vk.allocator, &submit_fence );
	scope( exit ) vk.device.vkDestroyFence( submit_fence, vk.allocator );





	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transition of depth images from VK_IMAGE_LAYOUT_UNDEFINED to VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL //
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// start recording on our setup command buffer:
	{
		VkCommandBufferBeginInfo transition_command_buffer_begin_info;
		vkBeginCommandBuffer( init_command_buffer, &transition_command_buffer_begin_info );
	}

	init_command_buffer.imageTransition(
		color_meta_image.image, color_image_subresource_range,
		VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
		0, VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
	);

	init_command_buffer.imageTransition(
		depth_meta_image.image, depth_image_subresource_range,
		VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		0, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
	);

	vkEndCommandBuffer( init_command_buffer );


	// create a submit info
	import vdrive.command;
	auto submit_info = init_command_buffer.queueSubmitInfo;


	// submit the command buffer with one depth image transitions
	vkQueueSubmit( meta_swapchain.present_queue, 1, &submit_info, submit_fence ).vkEnforce;
	vkWaitForFences( vk.device, 1, &submit_fence, VK_TRUE, uint32_t.max );
	vkResetFences( vk.device, 1, &submit_fence );


	// reset the command pool to start recording drawing commands
	vk.device.vkResetCommandPool( command_pool, 0 );	// second argument is VkCommandPoolResetFlags



	///////////////////////////////////
	// create triangle vertex buffer //
	///////////////////////////////////
	import vdrive.geometry;
	auto vertex_meta_buffer = vk.createTriangleBuffer;
	scope( exit ) {
		vk.device.vkDestroyBuffer( vertex_meta_buffer.buffer, vk.allocator );
		vk.device.vkFreeMemory( vertex_meta_buffer.device_memory, vk.allocator );
	}


	//////////////////////////////////
	// create matrix uniform buffer //
	//////////////////////////////////
	import dlsl.projection;
	auto PROJ = vkPerspective( 60, cast( float )meta_swapchain.imageExtent.width / meta_swapchain.imageExtent.height, 1, 100 );
	auto MOVE = mat4.translation( 0, 0, 5 );
	auto WVPM = mat4( 1 );


	import vdrive.shader; 
	auto descriptor_pool = vk.createDescriptorPool( VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1, 1 );
	auto matrix_meta_buffer = vk.createMatrixBuffer( WVPM );
	auto matrix_uniform_meta_descriptor = vk.createMatrixUniform( matrix_meta_buffer.buffer, descriptor_pool );
	scope( exit ) {
		vk.device.vkDestroyDescriptorSetLayout( matrix_uniform_meta_descriptor.set_layout, vk.allocator );
		vk.device.vkDestroyDescriptorPool( descriptor_pool, vk.allocator );
		vk.device.vkDestroyBuffer( matrix_meta_buffer.buffer, vk.allocator );
		vk.device.vkFreeMemory( matrix_meta_buffer.device_memory, vk.allocator );
	}


	/////////////////////////
	// create the pipeline //
	/////////////////////////
	import vdrive.pipeline;
	auto shader_modules = vk.createPipeline( 
		matrix_uniform_meta_descriptor.set_layout, meta_render_pass.render_pass, meta_swapchain.imageExtent, sample_count );
	scope( exit ) {
		vk.device.vkDestroyPipeline( vk.pipeline, vk.allocator );
		vk.device.vkDestroyPipelineLayout( vk.pipeline_layout, vk.allocator );
		foreach( ref shader_module; shader_modules ) vk.device.vkDestroyShaderModule( shader_module, vk.allocator );
	}


	///////////////////////////
	// prepare for rendering //
	///////////////////////////
/*
	// create render pass clear values for VkRenderPassBeginInfo
	VkClearValue[2] clear_value;
	clear_value[0].color.float32 = [ 0.3f, 0.3f, 0.3f, 1.0f ];
	clear_value[1].depthStencil = VkClearDepthStencilValue( 1.0f, cast( uint32_t )0 );


	// render pass begin info for vkCmdBeginRenderPass
	VkRenderPassBeginInfo render_pass_begin_info = {
		renderPass		: vk.render_pass,
		renderArea		: VkRect2D( VkOffset2D( 0, 0 ), meta_swapchain.imageExtent ),
		clearValueCount	: 2,
		pClearValues	: clear_value.ptr,
	};
*/

	// viewport and scissors (not so) dynamic state for vkCmdSetViewport and vkCmdSetScissor
	auto viewport = VkViewport( 0, 0, meta_swapchain.imageExtent.width, meta_swapchain.imageExtent.height, 0, 1 );
	auto scissors = VkRect2D( VkOffset2D( 0, 0 ), meta_swapchain.imageExtent );


	// rendering and presenting semaphores for VkSubmitInfo, VkPresentInfoKHR and vkAcquireNextImageKHR
	VkSemaphore	image_ready_semaphore, render_done_semaphore;
	VkSemaphoreCreateInfo semaphore_create_info;// = VkSemaphoreCreateInfo( VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, null, 0 );
	vk.device.vkCreateSemaphore( &semaphore_create_info, null, &image_ready_semaphore ).vkEnforce;
	vk.device.vkCreateSemaphore( &semaphore_create_info, null, &render_done_semaphore ).vkEnforce;
	scope( exit ) {
		vk.device.vkDestroySemaphore( render_done_semaphore, null );
		vk.device.vkDestroySemaphore( image_ready_semaphore, null );
	}


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
		pSwapchains			: &meta_swapchain.swapchain,
		//pImageIndices		: &next_image_index,
		pResults			: null,
	};


	// draw command buffer begin info for vkBeginCommandBuffer
	VkCommandBufferBeginInfo draw_command_buffer_begin_info;


	// record command buffer for each swapchain image
	// command_buffers is an Array!VkCommandBuffer, the array itself will be destroyd after this scope
	auto draw_command_buffers = vk.allocateCommandBuffers( command_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, cast( uint32_t )present_image_views.length );

	// queue submit infos for vkQueueSubmit
	auto render_submit_info = sizedArray!VkSubmitInfo( present_image_views.length );


	foreach( i; 0 .. present_image_views.length ) {

		// begin command buffer recording
		draw_command_buffers[ i ].vkBeginCommandBuffer( &draw_command_buffer_begin_info );


		// begin the render_pass
		//render_pass_begin_info.framebuffer = vk.framebuffers[ i ];
		meta_render_pass.attachFramebuffer( meta_framebuffer.framebuffers[ i ] );
		draw_command_buffers[ i ].vkCmdBeginRenderPass( &meta_render_pass.begin_info, VK_SUBPASS_CONTENTS_INLINE );


		// bind graphics pipeline
		draw_command_buffers[ i ].vkCmdBindPipeline( VK_PIPELINE_BIND_POINT_GRAPHICS, vk.pipeline );    


		// take care of dynamic state
		draw_command_buffers[ i ].vkCmdSetViewport( 0, 1, &viewport );
		draw_command_buffers[ i ].vkCmdSetScissor(  0, 1, &scissors );
		draw_command_buffers[ i ].vkCmdBindDescriptorSets(
			VK_PIPELINE_BIND_POINT_GRAPHICS, vk.pipeline_layout, 0, 1, &matrix_uniform_meta_descriptor.set, 0, null );


		// draw the triangle
		draw_command_buffers[ i ].vkCmdBindVertexBuffers( 0, 1, &vertex_meta_buffer.buffer, &vertex_meta_buffer.buffer_offset );
		draw_command_buffers[ i ].vkCmdDraw( 3, 1, 0, 0 );  // vertex count, instance count, first vertex, first instance
		draw_command_buffers[ i ].vkCmdEndRenderPass;


		// end command buffer recording
		draw_command_buffers[ i ].vkEndCommandBuffer;


		// set the draw command buffer into the coresponding queue submit info
		VkPipelineStageFlags render_wait_stage_mask 	= VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;
		render_submit_info[ i ].waitSemaphoreCount		= 1;
		render_submit_info[ i ].pWaitSemaphores			= &image_ready_semaphore;
		render_submit_info[ i ].pWaitDstStageMask		= &render_wait_stage_mask;
		render_submit_info[ i ].commandBufferCount		= 1;
		render_submit_info[ i ].pCommandBuffers			= &draw_command_buffers[ i ];
		render_submit_info[ i ].signalSemaphoreCount	= 1;
		render_submit_info[ i ].pSignalSemaphores		= &render_done_semaphore;
	}
	

	void render() {

		uint32_t next_image_index;
		// acquire next swapchain image - first time that VK_NULL_HANDLE is not working
		vkAcquireNextImageKHR( vk.device, meta_swapchain.swapchain, uint64_t.max, image_ready_semaphore, VK_NULL_ND_HANDLE, &next_image_index );


		// submit command buffer to queue
		meta_swapchain.present_queue.vkQueueSubmit( 1, &render_submit_info[ next_image_index ], render_fence );
		vk.device.vkWaitForFences( 1, &render_fence, VK_TRUE, uint64_t.max );
		vk.device.vkResetFences( 1, &render_fence ).vkEnforce;


		// present rendered image
		present_info.pImageIndices = &next_image_index;
		meta_swapchain.present_queue.vkQueuePresentKHR( &present_info );


		// update the matrix uniform buffer memory for the next frame render
		import vdrive.buffer : bufferData;
		WVPM = PROJ * MOVE * mat4.rotationY( glfwGetTime() );
		matrix_meta_buffer.bufferData( WVPM );
	}



//*
	while( !glfwWindowShouldClose( window )) {
		render;
		glfwSwapBuffers(window);
		glfwPollEvents();
	}	
/*/
	render;
//*/

	// drain work
	vk.device.vkDeviceWaitIdle;

	printf( "\n" );
	return 0;
}

