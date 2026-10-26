module appstate;

import bindbc.glfw : GLFWwindow;

import dlsl.matrix, dlsl.vector;
import erupted;
import vdrive;
import input;


nothrow @nogc:


// struct to manage vulkan objects and state
struct App_State {
    nothrow @nogc:

    // count of maximum per frame resources, might be less dependent on swapchain image count
    enum                        MAX_FRAMES = 2;

    // initialize
    Vulkan                      vk;
    alias                       vk this;
    VkQueue                     graphics_queue;
    uint32_t                    graphics_queue_family_index;    // required for command pool
    GLFWwindow*                 window;
    VkDebugReportCallbackEXT    debugReportCallback;

    // camera transforms and trackball
    TrackballButton             tbb;                            // Trackball manipulator updating View Matrix
    mat4*                       wvpm;                           // World View Projection Matrix
    mat4                        projection;                     // Projection Matrix
    float                       projection_fovy =   60;         // Projection Field Of View in Y dimension
    float                       projection_near = 0.01;         // Projection near plane distance
    float                       projection_far  = 1000;         // Projection  far plane distance




    // return window width and height stored in Meta_Swapchain struct
    auto windowWidth()  @nogc { return swapchain.image_extent.width;  }
    auto windowHeight() @nogc { return swapchain.image_extent.height; }

    // set window width and hight before recreating swapchain
    void windowWidth(  uint32_t w ) @nogc { swapchain.image_extent.width  = w; }
    void windowHeight( uint32_t h ) @nogc { swapchain.image_extent.height = h; }

    // this is used in windowResizeCallback
    // there only a VDrive_State pointer is available and we avoid ugly dereferencing
    void swapchainExtent( uint32_t win_w, uint32_t win_h ) {
        swapchain.image_extent = VkExtent2D( win_w, win_h );
    }

    // swapchain and swapchain
    //Meta_Swapchain_T!( 4 )    swapchain;
    Core_Swapchain_Queue_Extent swapchain;
    VkSampleCountFlagBits       sample_count = VK_SAMPLE_COUNT_1_BIT;

    // memory Resources
    alias                       Ubo_Buffer = Core_Buffer_T!( 0, BMC.Memory | BMC.Mem_Range );
    Ubo_Buffer                  wvpm_buffer;
    Core_Image_Memory_View      depth_image;
    Core_Buffer_Memory          geometry;

    // command and related
    VkCommandPool               cmd_pool;
    VkCommandBuffer[MAX_FRAMES] cmd_buffers;
    VkPresentInfoKHR            present_info;
    VkSubmitInfo                submit_info;    // the wait_stage_mask must stay alive, hence its a member
    VkPipelineStageFlags        submit_wait_stage_mask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

    // synchronize
    VkFence[ MAX_FRAMES ]       submit_fence;
    VkSemaphore                 acquired_semaphore;
    VkSemaphore                 rendered_semaphore;

    // render setup
    Core_Descriptor             descriptor;
    Core_Pipeline               pipeline;

    VkRenderPassBeginInfo       render_pass_bi;
    VkFramebuffer[ MAX_FRAMES ] framebuffers;

    // dynamic state
    VkViewport                  viewport;
    VkRect2D                    scissors;


    // cone segments, hacked into mat4[3][0], which is allways 0 after projection
    uint16_t                    cone_segments = 72;

    // window resize callback result
    bool                        window_resized = false;



    // update projection matrix from member data _fovy, _near, _far
    // and the swapchain extent converted to aspect
    void updateProjection() {
        import dlsl.projection;
        projection = vkPerspective( projection_fovy, cast( float )windowWidth / windowHeight, projection_near, projection_far );
    }


    // multiply projection with trackball (view) matrix and upload to uniform buffer
    void updateWVPM() {
        *wvpm = projection * tbb.worldTransform;

        // prcompute cone segment rotation angle and store in wvpm[3][0]
        //(*wvpm)[3][0] = 2.0f * 3.14159265f / cone_segments;

        vk.flushMappedMemoryRange( wvpm_buffer.mem_range );
    }


    void draw() {

        // the window_resized bool and and the swapchain.create_info.imageExtent
        // were possibly set in the window resize callback
        if( window_resized ) {
            window_resized = false;

            // swapchain might not have the same extent as the window dimension
            // the data we use for projection computation is the glfw window extent at this place
            updateProjection;            // compute projection matrix from new window extent
            updateWVPM;                  // multiplies projection trackball (view) matrix and uploads to uniform buffer

            // notify trackball manipulator about height change, this has effect on panning speed
            tbb.windowHeight( windowHeight );

            // destroy old and recreate new window size dependent resources
            // import triangle : resizeResources;
            this.resizeResources;
        }

        uint32_t next_image_index;
        // acquire next swapchain image
        device.vkAcquireNextImageKHR( swapchain.swapchain, uint64_t.max, acquired_semaphore, VK_NULL_HANDLE, & next_image_index );

        // wait for finished drawing
        device.vkWaitForFences( 1, & submit_fence[ next_image_index ], VK_TRUE, uint64_t.max );
        device.vkResetFences( 1, & submit_fence[ next_image_index ] ).vkAssert;

        // submit command buffer to queue
        submit_info.pCommandBuffers = & cmd_buffers[ next_image_index ];
        graphics_queue.vkQueueSubmit( 1, & submit_info, submit_fence[ next_image_index ] );   // or VK_NULL_HANDLE, fence is only requieed if syncing to CPU for e.g. UBO updates per frame

        // present rendered image
        present_info.pImageIndices = & next_image_index;
        swapchain.present_queue.vkQueuePresentKHR( & present_info );
    }
}



////////////////////////////////////////////
// create window size dependent resources //
////////////////////////////////////////////

void resizeResources( ref App_State app ) {

    //////////////////////////////////////////////////////
    // (re)construct the already parametrized swapchain //
    //////////////////////////////////////////////////////

    /////////////////////////
    // construct swapchain //
    /////////////////////////

    import vdrive.swapchain;

    // Just before we create a new swapcahin we destroy old resources.
    // But we not destroy the Surface
    if(!app.swapchain.is_null ) {
        app.device.vkDeviceWaitIdle;            // wait till device is idle
        app.destroy( app.swapchain, false );    // don't destroy the VkSurfaceKHR
    }


    // Note: to get GPU swapchain capabilities to check for possible image usages
    //VkSurfaceCapabilitiesKHR surface_capabilities;
    //vkGetPhysicalDeviceSurfaceCapabilitiesKHR( swapchain.gpu, swapchain.surface, & surface_capabilities );
    //surface_capabilities.printTypeInfo;

    // We need to know the swapchain image format before we create a render pass
    // to render into that swapcahin image. We don't have to create the surface itself.
    // The renderpass needs to be created only once in contrary to the swapchain,
    // which must be recreated if the window surface size changes.
    // We set all required parameters here to avoid configuration at multiple locations
    // additionally configuration needs to happen only once.

    // list of prefered formats and modes, the first found will be used, othervise the first available not in lists
    VkFormat[4] request_format = [ VK_FORMAT_R8G8B8_UNORM, VK_FORMAT_B8G8R8_UNORM, VK_FORMAT_R8G8B8A8_UNORM, VK_FORMAT_B8G8R8A8_UNORM ];
    VkPresentModeKHR[3] request_mode = [ VK_PRESENT_MODE_IMMEDIATE_KHR, VK_PRESENT_MODE_MAILBOX_KHR, VK_PRESENT_MODE_FIFO_KHR ];



    // We use a predeclared templated Specialization of Core_Swapchain_T to tell the Meta_Swapchain_T
    // which members we want to extract after construction.
    // Core_Swapchain_Queue_Extent can manage up to 4 VkImageViews, 1 Queue (present) and the swapchain extent.
    auto swapchain = Meta_Swapchain_T!Core_Swapchain_Queue_Extent( app )
        .surface( app.swapchain.surface )
        .oldSwapchain( app.swapchain.swapchain )
        .selectSurfaceFormat( request_format )
        .selectPresentMode( request_mode )
        .minImageCount( 2 )
        .imageArrayLayers( 1 )
        .imageUsage( VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT )
        .construct
        .reset( app.swapchain );

    // set the corresponding present info member to the (re)constructed swapchain
    app.present_info.pSwapchains = & app.swapchain.swapchain;



    //////////////////////////////////////////////////
    // create depth image and record its transition //
    //////////////////////////////////////////////////

    import vdrive.image, vdrive.memory;

    // first destroy old image and view
    if(!app.depth_image.is_null )
        app.destroy(  app.depth_image );

    // depth image format is also required for the renderpass
    VkFormat depth_image_format = VK_FORMAT_D32_SFLOAT;

    // prefer getting the depth image into a device local heap
    // first we need to find out if such a heap exist on the current device
    // we do not check the size of the heap, the depth image will probably fit if such heap exists
    // Todo(pp): the assumption above is NOT guaranteed, add additional functions to memory module
    // which consider a minimum heap size for the memory type, heap as well as memory cretaion functions
    // Todo(pp): this should be a member of App_State and figured out only once
    // including the proper memory heap index
    auto depth_image_memory_property = app.memory_properties.hasMemoryHeapType( VK_MEMORY_HEAP_DEVICE_LOCAL_BIT )
        ? VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        : VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT;

    // depth_image_format can be set before this function gets called
    auto depth_image = Meta_Image_T!Core_Image_Memory_View( app )
        .format( depth_image_format )
        .extent( app.windowWidth, app.windowHeight )
        .usage( VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT )
        .sampleCount( app.sample_count )
        .constructImage
        .allocateMemory( depth_image_memory_property )
        .viewAspect( VK_IMAGE_ASPECT_DEPTH_BIT )
        .constructView
        .extractCore( app.depth_image );

    // record transition from VK_IMAGE_LAYOUT_UNDEFINED to VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
    import vdrive.commander;

    // allocate one command buffer
    VkCommandBuffer cmd_buffer_init = app.allocateCommandBuffer( app.cmd_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY );

    // begin command buffer recording
    VkCommandBufferBeginInfo cmd_buffer_bi = { flags : VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT };
    vkBeginCommandBuffer( cmd_buffer_init, & cmd_buffer_bi );

    // record the image transition
    cmd_buffer_init.recordTransition(
        depth_image.image,                              // not using App_State property Core_Image_T app.depth_image ...
        depth_image.image_view_ci.subresourceRange,     // ... but instead func local Meta_Image_T with some more (here) required data.
        VK_IMAGE_LAYOUT_UNDEFINED,
        VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        0,  // no access mask required here
        VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT
    );

    // finish recording
    vkEndCommandBuffer( cmd_buffer_init );

    // submit info stays local in this function scope
    auto submit_info = queueSubmitInfo( cmd_buffer_init );

    // Submit the command buffer, we do not need to wait for the result here.
    // We'll wait till we reset the command pool to create persistent per swapchain command buffers.
    vkQueueSubmit( app.swapchain.present_queue, 1, & submit_info, VK_NULL_HANDLE ).vkAssert;



    ////////////////////////
    // create render pass //
    ////////////////////////

    // With this meta struct we parametrize its member VkRenderPassBeginInfo and construct our render pass.
    import vdrive.renderbuffer;
    app.render_pass_bi = Meta_Render_Pass_T!( 2,2,1,0,1,0,0 )( app )
        .renderPassAttachment_Clear_None(  depth_image_format,    app.sample_count, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL           ).subpassRefDepthStencil
        .renderPassAttachment_Clear_Store( swapchain.imageFormat, app.sample_count, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR ).subpassRefColor( VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL )

        // Note: specify dependencies despite of only one subpass, as suggested by:
        // https://github.com/KhronosGroup/Vulkan-Docs/wiki/Synchronization-Examples#swapchain-image-acquire-and-present
        .addDependency( VK_DEPENDENCY_BY_REGION_BIT )
        .srcDependency( VK_SUBPASS_EXTERNAL, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, 0 )
        .dstDependency( 0                  , VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT )
        .construct
        .beginInfo;



    /////////////////////////
    // create framebuffers //
    /////////////////////////

    import vdrive.renderbuffer;

    // compose render targets into an array
    VkImageView[1] render_targets = [ app.depth_image.view ];
    app.createFramebuffers(
        app.framebuffers,                           // out framebuffers
        app.render_pass_bi.renderPass,              // specify render pass COMPATIBILITY
        app.swapchain.image_extent.width,           // framebuffer width
        app.swapchain.image_extent.height,          // framebuffer height
        render_targets,                             // first ( static ) attachments which will not change ( here only )
        app.swapchain.image_views.data              // next one dynamic attachment ( swapchain ) which changes per command buffer
    );

    // specify the render area extent of our render pass begin info
    app.render_pass_bi.renderAreaExtent( app.swapchain.image_extent );  // specify the render area extent of our render pass begin info



    ///////////////////////////////////////////////
    // define dynamic viewport and scissor state //
    ///////////////////////////////////////////////

    app.viewport = VkViewport( 0, 0, swapchain.imageExtent.width, swapchain.imageExtent.height, 0, 1 );
    app.scissors = VkRect2D( VkOffset2D( 0, 0 ), swapchain.imageExtent );
}