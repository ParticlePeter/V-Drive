//module appstruct;

import derelict.glfw3;
import dlsl.matrix;
import erupted;
import vdrive;
import input;





struct VDriveState {
	//mixin 				Vulkan_State_Pointer;
	Vulkan						vk;
	alias						vk this;

	GLFWwindow* 				window;
	TrackballButton				tb;
	VkDebugReportCallbackEXT	debugReportCallback;

	Meta_Surface				surface;
	VkSampleCountFlagBits		sample_count;
	Array!VkImageView			present_image_views;

	Meta_Image					depth_image;

	Meta_Memory					buffer_memory;
	Meta_Buffer					wvpm_buffer;
	VkMappedMemoryRange			wvpm_flush;
	mat4* 						wvpm;
	mat4						proj;

	Meta_Geometry				triangle;

	Meta_Renderpass				render_pass;
	Meta_Framebuffers			framebuffers;

	VkDescriptorPool			descriptor_pool;
	Meta_Descriptor				wvpm_descriptor;

	Meta_Graphics				pipeline;
	VkViewport					viewport;
	VkRect2D					scissors;

	VkCommandPool				cmd_pool;
	Array!VkCommandBuffer		cmd_buffers;

	VkSemaphore					swapchain_semaphore;
	VkSemaphore					frame_end_semaphore;

	VkPipelineStageFlags		wait_stage_mask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;//VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;

	VkSubmitInfo				submit_info;

	VkPresentInfoKHR			present_info;

	VkFence 					submit_fence;

	bool 						window_resized = false;

	@disable this();

	this( GLFWwindow* window ) {
		this.window = window;
	}


	void draw() {
	
		uint32_t next_image_index;
		// acquire next swapchain image - first time that VK_NULL_HANDLE is not working
		vkAcquireNextImageKHR( vk.device, surface.swapchain, uint64_t.max, swapchain_semaphore, VK_NULL_ND_HANDLE, &next_image_index );

		// submit command buffer to queue
		submit_info.pCommandBuffers = &cmd_buffers[ next_image_index ];
		graphic_queue.vkQueueSubmit( 1, &submit_info, submit_fence );

		// wait for finished drawing
		device.vkWaitForFences( 1, &submit_fence, VK_TRUE, uint64_t.max );
		device.vkResetFences( 1, &submit_fence ).vkEnforce;

		// present rendered image
		present_info.pImageIndices = &next_image_index;
		surface.present_queue.vkQueuePresentKHR( &present_info );

		if( window_resized ) {
			window_resized = false;
			int win_w, win_h;
			glfwGetWindowSize( window, &win_w, &win_h );
			recreateSwapchain( win_w, win_h );
		}
	}


	void wvpmUpdate() {
		//auto time = cast( float )glfwGetTime();
		*wvpm = proj * tb.matrix;// * mat4.rotationY( time );
		vk.device.vkFlushMappedMemoryRanges( 1, &wvpm_flush );
		vk.device.vkInvalidateMappedMemoryRanges( 1, &wvpm_flush );
	}


	void recreateSwapchain( uint32_t win_w, uint32_t win_h ) nothrow {

		vk.device.vkDeviceWaitIdle;

		try {

			// recreate swapchain and image views
			import images;
			foreach( ref image_view; present_image_views ) vk.device.vkDestroyImageView( image_view, vk.allocator );
			surface.create_info.oldSwapchain = surface.swapchain;
			surface.create_info.imageExtent  = VkExtent2D( win_w, win_h );	// Set the desired surface extent, this might change at swapchain creation
			this.setupSurface;
			vk.device.vkDestroySwapchainKHR( surface.create_info.oldSwapchain, vk.allocator );
	
			// recreate additional render target images (depth buffer image)
			depth_image.destroyResources;
			this.createImages( sample_count );
			this.transitionImages;		// also resets the command pool
	
			// recreate framebuffers, renderpasses can be reused
			import renderpasses;
			framebuffers.destroyResources;
			//framebuffers.renderAreaExtent = surface.imageExtent;
			this.createFramebuffers;


			// update dynamic state
			viewport = VkViewport( 0, 0, win_w, win_h, 0, 1 ); 
			scissors = VkRect2D( VkOffset2D( 0, 0 ), surface.imageExtent );
	
			// record drawing commands
			import commands;
			this.createCommands;
	
			// recreate projection
			import dlsl.projection;
			proj = vkPerspective( 60, cast( float )surface.imageExtent.width / surface.imageExtent.height, 0.01, 1000 );
			wvpmUpdate;					// multiplies projection trackball (view) matrix and uploads to uniform buffer
		}

		catch( Exception ) {}

	}



	void destroyResources() {
		foreach( ref image_view; present_image_views ) vk.device.vkDestroyImageView( image_view, vk.allocator );
		surface.destroyResources;

		depth_image.destroyResources;

		vk.device.vkUnmapMemory( wvpm_buffer.device_memory );
		wvpm_buffer.destroyResources;
		triangle.destroyResources;

		render_pass.destroyResources;
		framebuffers.destroyResources;

		wvpm_descriptor.destroyResources;
		vk.device.vkDestroyDescriptorPool( descriptor_pool, vk.allocator );

		pipeline.destroyResources;
		pipeline.destroyShaderModules;

		vk.device.vkDestroyCommandPool( cmd_pool, vk.allocator );

		vk.device.vkDestroySemaphore( swapchain_semaphore, vk.allocator );
		vk.device.vkDestroySemaphore( frame_end_semaphore, vk.allocator );

		vk.device.vkDestroyFence( submit_fence, vk.allocator );

		vk.destroyDevice;
		debug vk.instance.vkDestroyDebugReportCallbackEXT( debugReportCallback, vk.allocator );
		vk.destroyInstance;

		glfwDestroyWindow( window );
		glfwTerminate();
	}
}
