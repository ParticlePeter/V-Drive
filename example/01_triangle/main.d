//module main;

import erupted;
import derelict.glfw3;
import dlsl.projection;

import std.stdio;

import vdrive.state;
import vdrive.surface;
import vdrive.util.info;
import vdrive.util.util;
import vdrive.util.array;

import appstruct;

import input;
import images;
import buffers;
import commands;
import pipelines;
import initialize;
import renderpasses;





int main() {

	printf( "\n" );

	auto vd = initVulkan( 1600, 900 );				// initialize instance and (physical) device
	vd.sample_count = VK_SAMPLE_COUNT_1_BIT;		// this will be used for multi sampled images, framebuffer attachment and resolving and pipeline multisample state
	//vd.gpu.listProperties( GPU_Info.properties );	// list few gpu stats (API Version)
	vd.setupSurface;								// setup swapchain for surface display
	vd.createImages( vd.sample_count );				// create required images
	vd.createBuffers;								// create required buffers and map uniform buffer persistently
	vd.initTrackball;								// initialize the navigation trackball
	vd.createRenderPasses( vd.sample_count );		// create required renderpasses
	vd.createFramebuffers;							// create framebuffers
	vd.createDescriptorSets;						// create descriptor sets
	vd.createPipelines( vd.sample_count );			// create the pipelines
	vd.createFenceAndCommandPool;					// create the frame fence and command pool
	vd.transitionImages;							// transition the layout of some images
	vd.createCommands;								// create the command buffers

	// projection is created here, as it might be necessary to manipulate at runtime
	vd.proj = vkPerspective( 60, cast( float )vd.surface.imageExtent.width / vd.surface.imageExtent.height, 0.01, 1000 );
	vd.wvpmUpdate();					// multiplies projection trackball (view) matrix and uploads to uniform buffer

	//import core.thread;
	//thread_detachThis();

	import core.stdc.stdio;
	char[32] title;
	uint frame_count;
	double last_time = glfwGetTime();
	while( !glfwWindowShouldClose( vd.window )) {

		// compute fps
		++frame_count;
		double delta_time = glfwGetTime() - last_time;

		if( delta_time >= 1.0 ) {
			sprintf( title.ptr, "Vulkan Erupted, FPS: %.2f", frame_count / delta_time );	// frames per second
			//sprintf( title.ptr, "Vulkan Erupted, FPS: %.2f", 1000.0 / frame_count );		// milli seconds per frame
			glfwSetWindowTitle( vd.window, title.ptr );
			last_time += delta_time;
			frame_count = 0;
		}

		// draw
		vd.draw();
		glfwSwapBuffers( vd.window );
		glfwPollEvents();
		if( vd.tb.dirty )
			vd.wvpmUpdate;


	}


	// drain work
	vd.device.vkDeviceWaitIdle;
	vd.destroyResources;

	printf( "\n" );
	return 0;
}



// Steps:
// Render lucien into draw and geom image
// - Add geom image to draw and framebuffers
// - render lucien into draw and geom image
// Set Data from one Scanline into Vertex Buffer
// - create shader storage buffer of length 3 floats * n
// - add storage for one atomic counter (delay)
// - create renderpass
//   - read from geometry pass image
//   - write into storage buffer
// Render Points ontop of the geometry
// render lucien triangles
// create graphic vd.geom_pipeline to render points
// render points from buffer ontop of lucien
