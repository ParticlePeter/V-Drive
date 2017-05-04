module appstate;

import derelict.glfw3 : GLFWwindow;
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

    // camera transforms and trackball
    TrackballButton             tb;                         // Trackball manipulator updating View Matrix
    mat4*                       wvpm;                       // World View Projection Matrix
    mat4                        projection;                 // Projection Matrix
    float                       projection_fovy =   60;     // Projection Field Of View in Y dimension
    float                       projection_near = 0.01;     // Projection near plane distance
    float                       projection_far  = 1000;     // Projection  far plane distance

    // surface and swapchain
    Meta_Surface                surface;
    VkSampleCountFlagBits       sample_count = VK_SAMPLE_COUNT_1_BIT;
    VkFormat                    depth_image_format = VK_FORMAT_D16_UNORM;

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
    VkSemaphore                 acquired_semaphore;
    VkSemaphore                 rendered_semaphore;

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


}

nothrow:

// convenience functions for perspective computations in main
auto windowWidth(  ref VDrive_State vd ) { return vd.surface.imageExtent.width;  }
auto windowHeight( ref VDrive_State vd ) { return vd.surface.imageExtent.height; }


// this is used in windowResizeCallback
// there only a VDrive_State pointer is available and we avoid ugly dereferencing
void swapchainExtent( VDrive_State* vd, uint32_t win_w, uint32_t win_h ) {
    vd.surface.create_info.imageExtent = VkExtent2D( win_w, win_h );
}


// update projection matrix from member data _fovy, _near, _far
// and the swapchain extent converted to aspect
void updateProjection( ref VDrive_State vd ) {
    import dlsl.projection;
    vd.projection = vkPerspective( vd.projection_fovy, cast( float )vd.windowWidth / vd.windowHeight, vd.projection_near, vd.projection_far );
}


// multiply projection with trackball (view) matrix and upload to uniform buffer
void updateWVPM( ref VDrive_State vd ) {
    *( vd.wvpm ) = vd.projection * vd.tb.matrix;
    vd.device.vkFlushMappedMemoryRanges( 1, &vd.wvpm_flush );
}


void draw( ref VDrive_State vd ) {

    // this bool and and the surface.create_info.imageExtent
    // was set in the window resize callback
    if( vd.window_resized ) {
        vd.window_resized = false;

        // swapchain might not have the same extent as the window dimension
        // the data we use for projection computation is the glfw window extent at this place
        vd.updateProjection;            // compute projection matrix from new window extent
        vd.updateWVPM;                  // multiplies projection trackball (view) matrix and uploads to uniform buffer

        // notify trackball manipulator about height change, this has effect on panning speed
        vd.tb.windowHeight( vd.windowHeight );

        // wait till device is idle
        vd.device.vkDeviceWaitIdle;

        try {
            // destroy old and recreate new window size dependent resources
            import triangle;
            vd.resizeResources;
        }

        catch( Exception ) {}
    }

    uint32_t next_image_index;
    // acquire next swapchain image
    vd.device.vkAcquireNextImageKHR( vd.surface.swapchain, uint64_t.max, vd.acquired_semaphore, VK_NULL_HANDLE, &next_image_index );

    // wait for finished drawing
    vd.device.vkWaitForFences( 1, &vd.submit_fence[ next_image_index ], VK_TRUE, uint64_t.max );
    vd.device.vkResetFences( 1, &vd.submit_fence[ next_image_index ] ).vkAssert;

    // submit command buffer to queue
    vd.submit_info.pCommandBuffers = &vd.cmd_buffers[ next_image_index ];
    vd.graphic_queue.vkQueueSubmit( 1, &vd.submit_info, vd.submit_fence[ next_image_index ] );   // or VK_NULL_HANDLE, fence is only requieed if syncing to CPU for e.g. UBO updates per frame

    // present rendered image
    vd.present_info.pImageIndices = &next_image_index;
    vd.surface.present_queue.vkQueuePresentKHR( &vd.present_info );

}