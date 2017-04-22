module triangle;

import derelict.glfw3;
import dlsl.matrix;

import input;
import erupted;
import appstate;

import vdrive.util.util;
import vdrive.util.array;




// create resources and vulkan objects for rendering
auto ref createResources( ref VDrive_State vd, bool recreate = false ) {

    ////////////////////////////////////////////
    // create window size dependent resources //
    ////////////////////////////////////////////



    //////////////////////////////////////////////////
    // create a swapchain for render result display //
    //////////////////////////////////////////////////

    // Note: to get GPU surface capabilities to check for possible image usages
    //VkSurfaceCapabilitiesKHR surface_capabilities;
    //vkGetPhysicalDeviceSurfaceCapabilitiesKHR( surface.gpu, surface.surface, &surface_capabilities );
    //surface_capabilities.printTypeInfo;

    VkFormat[4] request_format = [ VK_FORMAT_R8G8B8_UNORM, VK_FORMAT_B8G8R8_UNORM, VK_FORMAT_R8G8B8A8_UNORM, VK_FORMAT_B8G8R8A8_UNORM ];
    VkPresentModeKHR[3] request_mode = [ VK_PRESENT_MODE_IMMEDIATE_KHR, VK_PRESENT_MODE_MAILBOX_KHR, VK_PRESENT_MODE_FIFO_KHR ];
    //VkPresentModeKHR[2] request_mode = [ VK_PRESENT_MODE_MAILBOX_KHR, VK_PRESENT_MODE_FIFO_KHR ];

    import vdrive.surface;
    vd.surface( vd )
        .selectSurfaceFormat( request_format )
        .selectPresentMode( request_mode )
        .minImageCount( 2 )
        .imageArrayLayers( 1 )
        .imageUsage( VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT )
        .construct;



    ////////////////////////
    // create depth image //
    ////////////////////////

    // prefer getting the depth image into a device local heap
    // first we need to find out if such a heap exist on the current device
    // we do not check the size of the heap, the depth image will probably fit if such heap exists
    // Todo(pp): the assumption above is NOT guaranteed, add additional functions to memory module
    // which consider a minimum heap size for the memory type, heap as well as memory cretaion functions
    import vdrive.memory;
    auto depth_image_memory_property = vd.memory_properties.hasMemoryHeapType( VK_MEMORY_HEAP_DEVICE_LOCAL_BIT )
        ? VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        : VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT;

    vd.depth_image( vd )
        .create( VK_FORMAT_D16_UNORM, vd.surface.imageExtent, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, vd.sample_count )
        .createMemory( depth_image_memory_property )
        .createView( VkImageSubresourceRange( VK_IMAGE_ASPECT_DEPTH_BIT, 0, 1, 0, 1 ));



    //////////////////////////////////////////////
    // required inside and after the next scope //
    //////////////////////////////////////////////

    VkCommandBufferBeginInfo    cmd_buffer_begin_info;
    VkCommandBuffer             cmd_buffer_init;
    Meta_Buffer staging_buffer;
    scope( exit ) if( staging_buffer.isValid )  // if a Vulkan state Pointer was assigned
        staging_buffer.destroyResources;        // destroy the staging buffer at scope exit



    //////////////////////////////////////////////
    // create window size independent resources //
    //////////////////////////////////////////////

    if( !recreate ) {

        //////////////////////////////////
        // create matrix uniform buffer //
        //////////////////////////////////

        import vdrive.memory;
        vd.wvpm_buffer = vd;
        vd.wvpm_buffer.create( VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, 2 * 16 * float.sizeof );
        vd.wvpm_buffer.createMemory( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT );

        // map the uniform buffer memory persistently
        import dlsl.matrix;
        vd.wvpm = cast( mat4* )vd.wvpm_buffer.mapMemory;

        // specify mapped memory range for the matrix uniform buffer
        vd.wvpm_flush.memory    = vd.wvpm_buffer.memory;
        vd.wvpm_flush.size      = vd.wvpm_buffer.memSize;

        // projection matrix is created only once
        import dlsl.projection;
        vd.proj = vkPerspective( 60, cast( float )vd.windowWidth / vd.windowHeight, 0.01, 1000 );
        vd.wvpmUpdate();    // multiplies projection trackball (view) matrix and uploads to uniform buffer



        /////////////////////////////////
        // create fence and semaphores //
        /////////////////////////////////

        import vdrive.synchronize;
        vd.submit_fence[0] = vd.createFence( VK_FENCE_CREATE_SIGNALED_BIT );                // fence to sync CPU and GPU once per frame
        vd.submit_fence[1] = vd.createFence( VK_FENCE_CREATE_SIGNALED_BIT );                // fence to sync CPU and GPU once per frame

        // rendering and presenting semaphores for VkSubmitInfo, VkPresentInfoKHR and vkAcquireNextImageKHR
        vd.swapchain_semaphore = vd.createSemaphore;    // signaled when a new swapchain image is acquired
        vd.frame_end_semaphore = vd.createSemaphore;    // signaled when submitted command buffer(s) complete execution



        ////////////////////////
        // create render pass //
        ////////////////////////

        import vdrive.renderbuffer;
        vd.render_pass( vd )
            .renderPassAttachment_Clear_None(  vd.depth_image.image_create_info.format, vd.sample_count, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL ).subpassRefDepthStencil
            .renderPassAttachment_Clear_Store( vd.surface.imageFormat, vd.sample_count, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR ).subpassRefColor( VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL )

            // Note: specify dependencies despite of only one subpass, as suggested by:
            // https://software.intel.com/en-us/articles/api-without-secrets-introduction-to-vulkan-part-4#
            .addDependencyByRegion
            .srcDependency( VK_SUBPASS_EXTERNAL, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT         , VK_ACCESS_MEMORY_READ_BIT )
            .dstDependency( 0                  , VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT )

            .addDependencyByRegion
            .srcDependency( 0                  , VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT )
            .dstDependency( VK_SUBPASS_EXTERNAL, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT         , VK_ACCESS_MEMORY_READ_BIT )

            .construct;



        ///////////////////////////
        // create descriptor set //
        ///////////////////////////

        import vdrive.descriptor;
        vd.wvpm_descriptor( vd )    // this is the descriptor set for the uniform buffer with the MVP Matrix
            .addLayoutBinding( 0, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, VK_SHADER_STAGE_VERTEX_BIT )
                .addBufferInfo( vd.wvpm_buffer.buffer )
            .construct;



        //////////////////////////////////
        // create pipeline state object //
        //////////////////////////////////

        // declare a vertex structure and use its size in the PSO
        import dlsl.vector;
        struct Vertex {
            vec3 position;  // position
            vec3 color;     // color
        }

        // add shader stages - git repo needs only to keep track of the shader sources,
        // vdrive will compile them into spir-v with glslangValidator (must be in path!)
        import vdrive.pipeline, vdrive.surface, vdrive.shader;
        vd.pipeline( vd )
            .addShaderStageCreateInfo( vd.createPipelineShaderStage( VK_SHADER_STAGE_VERTEX_BIT,   "example/sw_01_triangle/shader/simple.vert" ))
            .addShaderStageCreateInfo( vd.createPipelineShaderStage( VK_SHADER_STAGE_FRAGMENT_BIT, "example/sw_01_triangle/shader/simple.frag" ))
            .addBindingDescription( 0, Vertex.sizeof, VK_VERTEX_INPUT_RATE_VERTEX )     // add vertex binding and attribute descriptions
            .addAttributeDescription( 0, 0, VK_FORMAT_R32G32B32_SFLOAT, 0 )             // ... consecutively and non-interleaved in ...
            .addAttributeDescription( 1, 0, VK_FORMAT_R32G32B32_SFLOAT, vec3.sizeof )   // ... consecutively and non-interleaved in ...
            .inputAssembly( VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST )                       // set the inputAssembly
            .addViewportAndScissors( VkOffset2D( 0, 0 ), vd.surface.imageExtent )       // add viewport and scissor state, necessary even if we use dynamic state
            .cullMode( VK_CULL_MODE_NONE )                                              // set rasterization state -  this cull mode is the default value
            .depthState                                                                 // set depth state - enable depth test with default attributes
            .addColorBlendState( VK_FALSE )                                             // color blend state - append common (default) color blend attachment state
            .addDynamicState( VK_DYNAMIC_STATE_VIEWPORT )                               // add dynamic states viewport
            .addDynamicState( VK_DYNAMIC_STATE_SCISSOR )                                // add dynamic states scissor
            .addDescriptorSetLayout( vd.wvpm_descriptor.descriptor_set_layout )         // describe pipeline layout
            .renderPass( vd.render_pass.render_pass )                                   // describe COMPATIBLE render pass
            .construct                                                                  // construct the Pipleine Layout and Pipleine State Object (PSO)
            .destroyShaderModules;                                                      // shader modules compiled into pipeline, not shared, can be deleted now



        ///////////////////////////////////////////////////////////////////////////
        // create command pool, allocate initial command buffer, begin recording //
        ///////////////////////////////////////////////////////////////////////////

        import vdrive.command;
        vd.cmd_pool = createCommandPool( vd, vd.graphic_queue_family_index );

        // allocate one command buffer, cmd_buffer_init was declared before two scopes
        cmd_buffer_init = vd.allocateCommandBuffer( vd.cmd_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY );

        // begin command buffer recording, cmd_buffer_begin_info was declared before two scopes
        vkBeginCommandBuffer( cmd_buffer_init, &cmd_buffer_begin_info );



        /////////////////////////////////
        // geometry with draw commands //
        /////////////////////////////////

        //struct Vertex { float x, y, z; }
        Vertex[3] triangle = [
            Vertex( vec3(  1, -1, 0 ), vec3( 1, 0, 0 )),
            Vertex( vec3( -1, -1, 0 ), vec3( 0, 1, 0 )),
            Vertex( vec3(  0,  1, 0 ), vec3( 0, 0, 1 ))
        ];

        // prefer getting the vertex data into a device local heap
        // first we need to find out if such a heap exist on the current device
        // we do not check the size of the heap, the triangle will most likely fit if such heap exists
        if( !vd.memory_properties.hasMemoryHeapType( VK_MEMORY_HEAP_DEVICE_LOCAL_BIT )) {

            // edit the internal Meta_Buffer via alias this
            vd.triangle( vd )                                                   // init Meta_Geometry and its Meta_Buffer structs
                .create( VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, triangle.sizeof )   // create the internal VkBuffer object
                .createMemory( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT )            // create the required VkMemory object
                .copyData( triangle );                                          // upload the triangle data

        } else {
            // here we create the staging Meta_Buffer resources and copy the data with a command buffer
            staging_buffer( vd )
                .create( VK_BUFFER_USAGE_TRANSFER_SRC_BIT, triangle.sizeof )    // only purpose of this buffer is to be a transfer source
                .createMemory( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT )
                .copyData( triangle );

            // edit the internal Meta_Buffer via alias this
            vd.triangle( vd )                                                   // init Meta_Geometry and its Meta_Buffer structs
                .create(
                    VK_BUFFER_USAGE_VERTEX_BUFFER_BIT |                         // we want to use the geometry buffer as vertex buffer
                    VK_BUFFER_USAGE_TRANSFER_DST_BIT,                           // and as transfer data (copy) destination
                    triangle.sizeof )                                           // create the internal VkBuffer object
                .createMemory( VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT );           // create the required device local VkMemory object

            // required for the vkCmdCopyBuffer
            VkBufferCopy buffer_copy = {
                srcOffset   : 0,
                dstOffset   : 0,
                size        : triangle.sizeof
            };

            // record the buffer copy, later we will record additional commands
            cmd_buffer_init.vkCmdCopyBuffer( staging_buffer.buffer, vd.triangle.buffer, 1, &buffer_copy );
        }

        // now edit additional members of Meta_Geometry
        import vdrive.geometry;
        vd.triangle
            .vertexCount( 3 )               // set the vertex count
            .addVertexOffset( 0 );          // register the internal buffer as first vertex attribute buffer
    }

    // cmd_buffer_init was allocated and recording began in the scope above
    // in the case of recreating resources we have not visited that scope
    // hence we must allocate the command buffer and begin rendering in else clause as well
    else {
        import vdrive.command;
        // allocate one command buffer, cmd_buffer_init was declared before two scopes
        cmd_buffer_init = vd.allocateCommandBuffer( vd.cmd_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY );

        // begin command buffer recording, cmd_buffer_begin_info was declared before two scopes
        vkBeginCommandBuffer( cmd_buffer_init, &cmd_buffer_begin_info );
    }



    //////////////////////////////////////////////////////
    // create window size dependent resources continued //
    //////////////////////////////////////////////////////



    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // record transition of depth image from VK_IMAGE_LAYOUT_UNDEFINED to VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL //
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    {

        // continue recording into cmd_buffer_init, record the depth image transition
        cmd_buffer_init.recordTransition(
            vd.depth_image.image,
            vd.depth_image.image_view_create_info.subresourceRange,
            VK_IMAGE_LAYOUT_UNDEFINED,
            VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            0,  // no access mask required here
            VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        );

        // finish recording
        vkEndCommandBuffer( cmd_buffer_init );

        // submit info stays local in this function scope
        import vdrive.command : queueSubmitInfo;
        auto submit_info = queueSubmitInfo( cmd_buffer_init );

        // create a temporary fence for the command submit
        import vdrive.synchronize : createFence;
        auto temp_fence = vd.createFence;

        // submit the command buffer with one depth and one color image transitions
        vkQueueSubmit( vd.surface.present_queue, 1, &submit_info, temp_fence ).vkAssert;
        vkWaitForFences( vd.device, 1, &temp_fence, VK_TRUE, uint32_t.max );

        // destroy the temporary fence
        import vdrive.state : destroy;
        vd.destroy( temp_fence );

        // reset the command pool to start recording runtime drawing commands
        vd.device.vkResetCommandPool( vd.cmd_pool, 0 ); // second argument is VkCommandPoolResetFlags
    }



    /////////////////////////
    // create framebuffers //
    /////////////////////////

    import vdrive.renderbuffer;
    VkImageView[1] render_targets = [ vd.depth_image.image_view ];  // compose render targets into an array
    vd.framebuffers( vd )
        .create(                                    // create the vulkan object directly with following params
            vd.render_pass.render_pass,             // specify render pass COMPATIBILITY
            vd.surface.imageExtent,                 // extent of the framebuffer
            render_targets,                         // first ( static ) attachments which will not change ( here only one, our depth buffer )
            vd.surface.present_image_views.data )   // next one dynamic attachment ( swapchain ) which changes per command buffer
        .addClearValue( 1, 0 )                      // first param is the image_view index of the Meta_Framebuffer for clearing, ...
        .addClearValue( 0.3f, 0.3f, 0.3f, 1.0f );   // ... otherwise the clear values would be attached at each resizing / recreating

    // attach one of the framebuffers, the render area and clear values to the render pass begin info
    // Note: attaching the framebuffer also sets the clear values and render area extent into the render pass begin info
    // setting clear values coresponding to framebuffer attachments and framebuffer extent could have happend before, e.g.:
    //      vd.render_pass.clearValues( some_clear_values );
    //      vd.render_pass.begin_info.renderArea = some_render_area;
    // but meta framebuffer(s) has a member for them, hence no need to create and manage extra storage/variables
    vd.render_pass.attachFramebuffer( vd.framebuffers, 0 );



    ///////////////////////////////////////////////
    // define dynamic viewport and scissor state //
    ///////////////////////////////////////////////

    vd.viewport = VkViewport( 0, 0, vd.surface.imageExtent.width, vd.surface.imageExtent.height, 0, 1 );
    vd.scissors = VkRect2D( VkOffset2D( 0, 0 ), vd.surface.imageExtent );



    ////////////////////////////////////
    // create runtime command buffers //
    ////////////////////////////////////

    import vdrive.command;
    // this time cmd_buffers is an Array!VkCommandBuffer, the array itself will be destroyed after this scope
    vd.cmd_buffers = vd.allocateCommandBuffers( vd.cmd_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, vd.surface.present_image_views.length );


    import vdrive.renderbuffer : attachFramebuffer;
    // record command buffer for each swapchain image
    foreach( uint32_t i, ref cmd_buffer; vd.cmd_buffers.data ) {

        // attach one of the framebuffers to the render pass
        vd.render_pass.attachFramebuffer( vd.framebuffers( i ));

        // begin command buffer recording
        cmd_buffer.vkBeginCommandBuffer( &cmd_buffer_begin_info );

        // begin the render_pass
        cmd_buffer.vkCmdBeginRenderPass( &vd.render_pass.begin_info, VK_SUBPASS_CONTENTS_INLINE );

        // bind graphics vd.geom_pipeline
        cmd_buffer.vkCmdBindPipeline( VK_PIPELINE_BIND_POINT_GRAPHICS, vd.pipeline.pipeline );

        // take care of dynamic state
        cmd_buffer.vkCmdSetViewport( 0, 1, &vd.viewport );
        cmd_buffer.vkCmdSetScissor(  0, 1, &vd.scissors );
        cmd_buffer.vkCmdBindDescriptorSets(     // VkCommandBuffer              commandBuffer
            VK_PIPELINE_BIND_POINT_GRAPHICS,    // VkPipelineBindPoint          pipelineBindPoint
            vd.pipeline.pipeline_layout,        // VkPipelineLayout             layout
            0,                                  // uint32_t                     firstSet
            1,                                  // uint32_t                     descriptorSetCount
            &vd.wvpm_descriptor.descriptor_set, // const( VkDescriptorSet )*    pDescriptorSets
            0,                                  // uint32_t                     dynamicOffsetCount
            null                                // const( uint32_t )*           pDynamicOffsets
        );

        // bind vertex buffer, only one attribute stored in this buffer
        cmd_buffer.vkCmdBindVertexBuffers(
            0,                                          // first binding
            vd.triangle.vertex_buffers.length.toUint,   // binding count
            vd.triangle.vertex_buffers.ptr,             // pBuffers to bind
            vd.triangle.vertex_offsets.ptr              // pOffsets into buffers
        );

        // simple draw command, non indexed
        cmd_buffer.vkCmdDraw(
            vd.triangle.vertex_count,                   // vertex count
            1,                                          // instance count
            0,                                          // first vertex
            0                                           // first instance
        );

        // end the render pass
        cmd_buffer.vkCmdEndRenderPass;

        // end command buffer recording
        cmd_buffer.vkEndCommandBuffer;
    }


    // draw submit info for vkQueueSubmit
    with( vd.submit_info ) {
        waitSemaphoreCount      = 1;
        pWaitSemaphores         = &vd.swapchain_semaphore;
        pWaitDstStageMask       = &vd.submit_wait_stage_mask;
        commandBufferCount      = 1;
    //  pCommandBuffers         = &vd.cmd_buffers[ i ];     // set this parameter before submission, choosing cmd_buffers[0/1]
        signalSemaphoreCount    = 1;
        pSignalSemaphores       = &vd.frame_end_semaphore;
    }


    // present info for vkQueuePresentKHR
    with( vd.present_info ) {
        waitSemaphoreCount  = 1;
        pWaitSemaphores     = &vd.frame_end_semaphore;
        swapchainCount      = 1;
        pSwapchains         = &vd.surface.swapchain;
    //  pImageIndices       = &next_image_index;            // set this parameter before presentation, using the acquired next_image_index
    }

    return vd;
}


// destroy resources and vulkan objects for rendering
auto ref destroyResources( ref VDrive_State vd ) {

    import erupted, vdrive;

    vd.device.vkDeviceWaitIdle;

    // surface and swapchain
    vd.surface.destroyResources;

    // memory Resources
    vd.depth_image.destroyResources;
    vd.triangle.destroyResources;
    vd.wvpm_buffer
        .unmapMemory
        .destroyResources;

    // render setup
    vd.render_pass.destroyResources;
    vd.wvpm_descriptor.destroyResources;
    vd.pipeline.destroyResources;
    vd.framebuffers.destroyResources;

    // command and synchronize
    vd.destroy( vd.cmd_pool );
    vd.destroy( vd.submit_fence[0] );
    vd.destroy( vd.submit_fence[1] );
    vd.destroy( vd.swapchain_semaphore );
    vd.destroy( vd.frame_end_semaphore );

    return vd;
}