module triangle;

import bindbc.glfw;

import dlsl.matrix;

import input;
import erupted;
import appstate;

import vdrive.util.util;
import vdrive.util.array;




////////////////////////////////////////////////////////////////////
// create window size independent resources once before draw loop //
////////////////////////////////////////////////////////////////////

void createResources( ref App_State app, bool recreate = false ) {

    /////////////////////////////////
    // create fence and semaphores //
    /////////////////////////////////

    import vdrive.synchronizer;
    app.submit_fence[0] = app.createFence( VK_FENCE_CREATE_SIGNALED_BIT );          // fence to sync CPU and GPU once per frame
    app.submit_fence[1] = app.createFence( VK_FENCE_CREATE_SIGNALED_BIT );          // fence to sync CPU and GPU once per frame

    // rendering and presenting semaphores for VkSubmitInfo, VkPresentInfoKHR and vkAcquireNextImageKHR
    app.acquired_semaphore = app.createSemaphore;   // signaled when a new swapchain image is acquired
    app.rendered_semaphore = app.createSemaphore;   // signaled when submitted command buffer(s) complete execution



    /////////////////////////////////////
    // configure submit and present infos
    /////////////////////////////////////

    // draw submit info for vkQueueSubmit
    with( app.submit_info ) {
        waitSemaphoreCount      = 1;
        pWaitSemaphores         = & app.acquired_semaphore;
        pWaitDstStageMask       = & app.submit_wait_stage_mask; // configured before entering createResources func
        commandBufferCount      = 1;
    //  pCommandBuffers         = & app.cmd_buffers[ i ];       // set before submission, choosing cmd_buffers[0/1]
        signalSemaphoreCount    = 1;
        pSignalSemaphores       = & app.rendered_semaphore;
    }

    // present info for vkQueuePresentKHR
    with( app.present_info ) {
        waitSemaphoreCount      = 1;
        pWaitSemaphores         = & app.rendered_semaphore;
        swapchainCount          = 1;
    //  pSwapchains             = & app.swapchain.swapchain;    // set after (re)creating swapchain
    //  pImageIndices           = & next_image_index;           // set before presenting, using the acquired next_image_index
    }



    //////////////////////////////////
    // create matrix uniform buffer //
    //////////////////////////////////

    import vdrive.buffer;
    auto wvpm_buffer = Meta_Buffer_T!( App_State.Ubo_Buffer )( app )
        .usage( VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT )
        .bufferSize( 16 * float.sizeof )   // mat4.sizeof
        .construct( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT )
        .mapMemory( app.wvpm )
        .reset( app.wvpm_buffer );

    // update projection matrix from member data _fovy, _near, _far and aspect of
    // the swapchain extent, initialized once, resized by the input.windowSizeCallback
    // however we can set _fovy, _near, _far to desired values before calling updateProjection
    app.updateProjection;

    // multiply projection with trackball (view) matrix and upload to uniform buffer
    app.updateWVPM;



    ///////////////////////////
    // create descriptor set //
    ///////////////////////////

    import vdrive.descriptor;

    {   // allocates and frees when leaving scope
        app.descriptor = Meta_Descriptor( app )
            .addUniformBufferBinding( 0, VK_SHADER_STAGE_VERTEX_BIT )
            .addBufferInfo( app.wvpm_buffer.buffer )
            .construct
            .reset;
    }




    ///////////////////////////////////////////////////////
    // create window size dependent resources first time //
    ///////////////////////////////////////////////////////

    // this creates, among others, a render pass which is needed for PSO construction
    app.resizeResources;



    ////////////////////////////////////////////////////////////////
    // create command pool, we might need now to move data on GPU //
    ////////////////////////////////////////////////////////////////

    import vdrive.commander;
    app.cmd_pool = app.createCommandPool( app.graphics_queue_family_index );



    /////////////////////////////////
    // geometry with draw commands //
    /////////////////////////////////

    // declare a vertex structure and use its size in the PSO
    import dlsl.vector;
    struct Vertex {
        vec3 position;  // position
        vec3 color;     // color
    }

    //struct Vertex { float x, y, z; }
    Vertex[3] triangle = [
        Vertex( vec3(  1, -1, 0 ), vec3( 1, 0, 0 )),
        Vertex( vec3( -1, -1, 0 ), vec3( 0, 1, 0 )),
        Vertex( vec3(  0,  1, 0 ), vec3( 0, 0, 1 ))
    ];

    import vdrive.memory, vdrive.buffer;

    // prefer getting the vertex data into a device local heap
    // first we need to find out if such a heap exist on the current device
    // we do not check the size of the heap, the triangle will most likely fit if such heap exists
    if( !app.memory_properties.hasMemoryHeapType( VK_MEMORY_HEAP_DEVICE_LOCAL_BIT )) {

        // edit the internal Meta_Buffer via alias this
       app.geometry = Meta_Buffer_Memory( app )                     // init Meta_Geometry and its Meta_Buffer structs
            .usage( VK_BUFFER_USAGE_VERTEX_BUFFER_BIT )             // we want to use the geometry buffer as vertex buffer
            .bufferSize( triangle.sizeof )                          // specify the required buffer size
            .construct( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT )       // create the internal VkBuffer object and required HOST_VISIBLE VkMemory
            .copyData( triangle )                                   // copy the data to our buffer, this internally maps and unmaps the buffer
            .reset;

    } else {
        // Here we create the staging Meta_Buffer resources and copy the data with a command buffer.
        // The final call staging_buffer.copyData uses a VkMappedMemoryRange to copy the data into the buffer.
        // Physical devices have a VkPhysicalDeviceLimits::nonCoherentAtomSize, which we must obey.
        // When our data fits into this (multiple of) nonCoherentAtoSize limit we can soleyly use that data object (triangle).
        // as argument to the copyData call without specifying an offset and a size.
        // But e.g. our triangle size ( 0x48 / 72 bytes ) does not obey NVidia GPU GeForce 1080 limit ( 0x40 / 64 bytes ).
        // We can pass in a corresponding (padded) data object or override the size, in particual, as the spec states, with VK_WHOLE_SIZE.
        auto staging_buffer = Meta_Buffer( app )                    // begin parametrizing the temporary staging Meta_Buffer
            .usage( VK_BUFFER_USAGE_TRANSFER_SRC_BIT )              // only purpose of this buffer is to be a transfer source
            .bufferSize( triangle.sizeof )                          // specify the required buffer size
            .construct( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT )       // create the internal VkBuffer object and required HOST_VISIBLE VkMemory
            .copyData( triangle, 0, VK_WHOLE_SIZE );                // copy the data to our buffer, this internally maps and unmaps the buffer
                                                                    // this usually works with the data size, but in some scenarios we need to pass in some other size
        // edit the internal Meta_Buffer via alias this
        app.geometry = Meta_Buffer_Memory( app )                    // init Meta_Geometry and its Meta_Buffer structs
            .usage( VK_BUFFER_USAGE_VERTEX_BUFFER_BIT               // we want to use the geometry buffer as vertex buffer
                  | VK_BUFFER_USAGE_TRANSFER_DST_BIT )              // and as transfer data (copy) destination
            .bufferSize( triangle.sizeof )                          // specify the required buffer size
            .construct( VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT )       // create the internal VkBuffer object and required device local VkMemory
            .reset;

        // allocate one command buffer
        VkCommandBuffer cmd_buffer = app.allocateCommandBuffer( app.cmd_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY );

        // begin command buffer recording, cmd_buffer_bi was declared before two scopes
        VkCommandBufferBeginInfo cmd_buffer_bi = { flags : VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT };
        vkBeginCommandBuffer( cmd_buffer, & cmd_buffer_bi );

        // required for the vkCmdCopyBuffer
        VkBufferCopy buffer_copy = {
            srcOffset   : 0,
            dstOffset   : 0,
            size        : triangle.sizeof
        };

        // record the buffer copy
        cmd_buffer.vkCmdCopyBuffer( staging_buffer.buffer, app.geometry.buffer, 1, & buffer_copy );

        // finish recording
        cmd_buffer.vkEndCommandBuffer;

        // submit the command buffer, combines parametrizing a VkSubmitInfo and the submission
        app.graphics_queue.queueSubmit( cmd_buffer );

        // destroy staging buffer
        app.graphics_queue.vkQueueWaitIdle;     // equivalent using a fence per Spec v1.0.48
        staging_buffer.destroyResources;        // destroy the temporary staging resources
    }



    ////////////////////////////////////////
    // create pipeline state object (PSO) //
    ////////////////////////////////////////

    // add shader stages - git repo needs only to keep track of the shader sources,
    // vdrive will compile them into spir-v with glslangValidator (must be in path!)
    import vdrive.pipeline, vdrive.shader;
    app.pipeline = Meta_Graphics( app )
        .addShaderStageCreateInfo( app.createPipelineShaderStage( "example/sw_01_triangle/shader/simple.vert" ))    // deduce shader stage from file extension
        .addShaderStageCreateInfo( app.createPipelineShaderStage( "example/sw_01_triangle/shader/simple.frag" ))    // deduce shader stage from file extension
        .addBindingDescription( 0, Vertex.sizeof, VK_VERTEX_INPUT_RATE_VERTEX )     // add vertex binding and attribute descriptions
        .addAttributeDescription( 0, 0, VK_FORMAT_R32G32B32_SFLOAT, 0 )             // ... interleaved in position ...
        .addAttributeDescription( 1, 0, VK_FORMAT_R32G32B32_SFLOAT, vec3.sizeof )   // ... interleaved in color ...
        .inputAssembly( VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST )                       // set the inputAssembly
        .addViewportAndScissors( VkOffset2D( 0, 0 ), app.swapchain.image_extent )   // add viewport and scissor state, necessary even if we use dynamic state
        .cullMode( VK_CULL_MODE_NONE )                                              // set rasterization state -  this cull mode is the default value
        .depthState                                                                 // set depth state - enable depth test with default attributes
        .addColorBlendState( VK_FALSE )                                             // color blend state - append common (default) color blend attachment state
        .addDynamicState( VK_DYNAMIC_STATE_VIEWPORT )                               // add dynamic states viewport
        .addDynamicState( VK_DYNAMIC_STATE_SCISSOR )                                // add dynamic states scissor
        .addDescriptorSetLayout( app.descriptor.descriptor_set_layout )             // describe pipeline layout
        .renderPass( app.render_pass_bi.renderPass )                                // describe COMPATIBLE render pass
        .construct                                                                  // construct the Pipleine Layout and Pipleine State Object (PSO)
        .destroyShaderModules
        .reset;                                                                     // shader modules compiled into pipeline, not shared, can be deleted now



    /////////////////////////////////////////////////////////////
    // create draw loop command buffers with resized resources //
    /////////////////////////////////////////////////////////////

    // reset the command pool to start recording drawing commands
    app.graphics_queue.vkQueueWaitIdle;                 // equivalent using a fence per Spec v1.0.48
    app.device.vkResetCommandPool( app.cmd_pool, 0 );   // second argument is VkCommandPoolResetFlags

    // this time cmd_buffers is an DArray!VkCommandBuffer, the array itself will be destroyed after this scope
    app.allocateCommandBuffers( app.cmd_pool, app.cmd_buffers[ 0 .. app.swapchain.image_count ] );

    // define clear values
    import vdrive.renderbuffer;
    VkClearValue[ 2 ] clear_values;
    clear_values
        .set( 0, 1.0f )                      // set depth clear value
        .set( 1, 0.0f, 0.0f, 0.0f, 1.0f );   // set color clear value

    // record command buffer for each swapchain image
    foreach( i, ref cmd_buffer; app.cmd_buffers[ 0 .. app.swapchain.image_count ] ) {

        // attach clear values and one of the framebuffers to the render pass
        app.render_pass_bi.clearValues( clear_values );
        app.render_pass_bi.framebuffer = app.framebuffers[ i ];

        // begin command buffer recording
        VkCommandBufferBeginInfo cmd_buffer_bi;
        cmd_buffer.vkBeginCommandBuffer( & cmd_buffer_bi );

        // begin the render_pass
        cmd_buffer.vkCmdBeginRenderPass( & app.render_pass_bi, VK_SUBPASS_CONTENTS_INLINE );

        // bind graphics app.geom_pipeline
        cmd_buffer.vkCmdBindPipeline( VK_PIPELINE_BIND_POINT_GRAPHICS, app.pipeline.pipeline );

        // take care of dynamic state
        cmd_buffer.vkCmdSetViewport( 0, 1, & app.viewport );
        cmd_buffer.vkCmdSetScissor(  0, 1, & app.scissors );
        cmd_buffer.vkCmdBindDescriptorSets(             // VkCommandBuffer              commandBuffer
            VK_PIPELINE_BIND_POINT_GRAPHICS,            // VkPipelineBindPoint          pipelineBindPoint
            app.pipeline.pipeline_layout,               // VkPipelineLayout             layout
            0,                                          // uint32_t                     firstSet
            1,                                          // uint32_t                     descriptorSetCount
            & app.descriptor.descriptor_set,            // const( VkDescriptorSet )*    pDescriptorSets
            0,                                          // uint32_t                     dynamicOffsetCount
            null                                        // const( uint32_t )*           pDynamicOffsets
        );

        // bind vertex buffer, only one attribute stored in this buffer
        VkDeviceSize offset = 0;
        cmd_buffer.vkCmdBindVertexBuffers(
            0,                                          // first binding
            1,                                          // binding count
            & app.geometry.buffer,                      // pBuffers to bind
            & offset                                    // pOffsets into buffers
        );

        // simple draw command, non indexed
        cmd_buffer.vkCmdDraw(
            3,                                          // vertex count
            1,                                          // instance count
            0,                                          // first vertex
            0                                           // first instance
        );

        // end the render pass
        cmd_buffer.vkCmdEndRenderPass;

        // end command buffer recording
        cmd_buffer.vkEndCommandBuffer;
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
    // which members we want to extract for bookkeeping after construction.
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
        app.destroy( app.depth_image );

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

    // first we create a new temporary command pool
    // our draw commands created in createResources from the main command pool.
    // we do not want to allocate new command buffers from that pool on resize,
    // as we would have to reset it and recreate the commands every time.
    // We also mark all its command buffers as short lived through the passed in flag.
    VkCommandPool tmp_cmd_pool = app.createCommandPool(
        app.graphics_queue_family_index, VK_COMMAND_POOL_CREATE_TRANSIENT_BIT );

    // allocate one command buffer
    VkCommandBuffer cmd_buffer_init = app.allocateCommandBuffer( tmp_cmd_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY );

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
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
        VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,     // this has been caught by the recent validation layers of vulkan spec v1.0.57
    );

    // finish recording
    vkEndCommandBuffer( cmd_buffer_init );

    // submit info stays local in this function scope
    auto submit_info = queueSubmitInfo( cmd_buffer_init );

    // Submit the command buffer.
    vkQueueSubmit( app.graphics_queue, 1, & submit_info, VK_NULL_HANDLE ).vkAssert;

    // destroy the temp command pool and its only buffer
    import vdrive.state : destroy;
    app.graphics_queue.vkQueueWaitIdle;
    app.destroy( tmp_cmd_pool );




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



// destroy resources and vulkan objects for rendering
void destroyResources( ref App_State app ) {

    import erupted, vdrive;

    app.device.vkDeviceWaitIdle;

    // surface, swapchain and present image views
    app.destroy( app.swapchain );

    // memory Resources
    app.destroy( app.geometry );
    app.destroy( app.depth_image );
    app.destroy( app.wvpm_buffer );

    // render setup
    foreach( ref f; app.framebuffers )  app.destroy( f );
    app.destroy( app.render_pass_bi.renderPass );
    app.destroy( app.descriptor );
    app.destroy( app.pipeline );

    // command and synchronize
    foreach( ref f; app.submit_fence )  app.destroy( f );
    app.destroy( app.cmd_pool );
    app.destroy( app.acquired_semaphore );
    app.destroy( app.rendered_semaphore );
}