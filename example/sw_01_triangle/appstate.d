module appstate;

import derelict.glfw3;
import dlsl.matrix;
import erupted;
import vdrive;
import input;


// struct to manage vulkan objects and state
struct VDrive_State {

    // initialize
    Vulkan                      vk;
    alias                       vk this;
    VkQueue                     graphic_queue;
    uint32_t                    graphic_queue_family_index; // required for command pool
    GLFWwindow*                 window;
    VkDebugReportCallbackEXT    debugReportCallback;

    // surface and swapchain
    Meta_Surface                surface;
    VkSampleCountFlagBits       sample_count = VK_SAMPLE_COUNT_1_BIT;

    // trackball
    TrackballButton             tb;
    mat4*                       wvpm;           // World View Projection Matrix
    mat4                        proj;           // Projection Matrix

    // memory Resources
    Meta_Buffer                 wvpm_buffer;
    VkMappedMemoryRange         wvpm_flush;
    Meta_Image                  depth_image;
    Meta_Geometry               triangle;

    // command and related
    VkCommandPool               cmd_pool;
    Array!VkCommandBuffer       cmd_buffers;
    VkPresentInfoKHR            present_info;
    VkSubmitInfo                submit_info;    // the wait_stage_mask must stay alive, hence its a member
    VkPipelineStageFlags        submit_wait_stage_mask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

    // synchronize
    VkFence[2]                  submit_fence;
    VkSemaphore                 swapchain_semaphore;
    VkSemaphore                 frame_end_semaphore;

    // render setup
    Meta_Renderpass             render_pass;
    Meta_Descriptor             wvpm_descriptor;
    Meta_Graphics               pipeline;
    Meta_Framebuffers           framebuffers;

    // dynamic state 
    VkViewport                  viewport;
    VkRect2D                    scissors;

    // window resize callback result
    bool                        window_resized = false;

    // convenience functions for perspective computations in main
    auto windowWidth()  { return surface.imageExtent.width; }
    auto windowHeight() { return surface.imageExtent.height; }

    void wvpmUpdate() nothrow {
        auto time = cast( float )glfwGetTime();
        *( wvpm + 0 ) = proj * tb.matrix;
        vk.device.vkFlushMappedMemoryRanges( 1, &wvpm_flush );
    }


    void recreateSwapchain( uint32_t win_w, uint32_t win_h ) nothrow {
        vk.device.vkDeviceWaitIdle;
        try {
            // set the desired surface extent
            // the extent might change at swapchain creation when the specified extent is not usable
            surface.create_info.imageExtent = VkExtent2D( win_w, win_h );

            // destroy old and recreate new window size dependent resources 
            import triangle;
            this.createResources( true );

            // recreate projection
            import dlsl.projection;
            proj = vkPerspective( 60, cast( float )windowWidth / windowHeight, 0.01, 1000 );
            wvpmUpdate;                 // multiplies projection trackball (view) matrix and uploads to uniform buffer

            // notify trackball manipulator about win height change, this has effect on panning speed
            tb.windowHeight( win_h );
        }

        catch( Exception ) {}
    }


    void draw() {
    
        uint32_t next_image_index;
        // acquire next swapchain image - first time that VK_NULL_HANDLE is not working
        vkAcquireNextImageKHR( vk.device, surface.swapchain, uint64_t.max, swapchain_semaphore, VK_NULL_HANDLE, &next_image_index );

        // wait for finished drawing
        device.vkWaitForFences( 1, &submit_fence[ next_image_index ], VK_TRUE, uint64_t.max );
        device.vkResetFences( 1, &submit_fence[ next_image_index ] ).vkAssert;

        // submit command buffer to queue
        submit_info.pCommandBuffers = &cmd_buffers[ next_image_index ];
        graphic_queue.vkQueueSubmit( 1, &submit_info, submit_fence[ next_image_index ] );   // or VK_NULL_HANDLE, fence is only requieed if syncing to CPU for e.g. UBO updates per frame

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
}
