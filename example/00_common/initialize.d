//module initialize;

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

import images;
import buffers;
import commands;
import pipelines;
import renderpasses;




extern( System ) VkBool32 debugReport(
	VkDebugReportFlagsEXT       flags,
	VkDebugReportObjectTypeEXT  objectType,
	uint64_t                    object,
	size_t                      location,
	int32_t                     messageCode,
	const( char )*              pLayerPrefix,
	const( char )*              pMessage,
	void*                       pUserData) nothrow @nogc
{
	printf( "ObjectType  : %i\nMessage     : %s\n", objectType, pMessage );
	return VK_FALSE;
}


mixin DerelictGLFW3_VulkanBind;



auto initVulkan( uint32_t win_w = 1600, uint32_t win_h = 900 ) {

	// Initialize Vulkan with GLFW3
	DerelictGLFW3.load;
	DerelictGLFW3_loadVulkan();

	glfwInit();
	loadGlobalLevelFunctions( cast( typeof( vkGetInstanceProcAddr ))
		glfwGetInstanceProcAddress( null, "vkGetInstanceProcAddr" ));

	// glfw window specification
	glfwWindowHint( GLFW_CLIENT_API, GLFW_NO_API );
	GLFWwindow* window = glfwCreateWindow( win_w, win_h, "Vulkan Erupted", null, null );

	//listExtensions;
	//listLayers;
	//list_glfw_required_extensions;		// glfw required extensions

	verbose = false;

	// destroy the window and terminate glfw at scope exist
/*	scope( exit ) {
		glfwDestroyWindow( window );
		glfwTerminate();
	}*/

	//"VK_LAYER_LUNARG_standard_validation".isLayer;

	debug	const( char* )[1] layers = [ "VK_LAYER_LUNARG_standard_validation" ];
	else	const( char* )[0] layers;


	// Checking for extensions
	debug	const( char* )[3] extensions = [ "VK_KHR_surface", "VK_KHR_win32_surface", "VK_EXT_debug_report" ];
	else	const( char* )[2] extensions = [ "VK_KHR_surface", "VK_KHR_win32_surface" ];

	foreach( extension; extensions ) {
		if( !extension.isExtension( false )) {
			printf( "Required layer %s not available. Exiting!\n", extension );
			//return 1;
		}
	}

	// Create vdrive vulkan state struct and initialize the instance
	VDriveState vd = window;
	vd.initInstance( extensions, layers );
	//vd.initInstance( "VK_KHR_surface\0VK_KHR_win32_surface\0VK_EXT_debug_report\0", "VK_LAYER_LUNARG_standard_validation\0" );		//string[2] extensions = [ "VK_KHR_surface", "VK_KHR_win32_surface" ];
	//scope( exit ) vd.destroyInstance;		// destroy the instance at scope exist





	// setup debug report callback
	debug {
		VkDebugReportCallbackCreateInfoEXT callbackCreateInfo = {
			flags		: VK_DEBUG_REPORT_ERROR_BIT_EXT | VK_DEBUG_REPORT_WARNING_BIT_EXT | VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT,
			pfnCallback	: &debugReport,
			pUserData	: null,
		};

		vkCreateDebugReportCallbackEXT( vd.instance, &callbackCreateInfo, vd.allocator, &vd.debugReportCallback );
		//scope( exit ) vkDestroyDebugReportCallbackEXT( vd.instance, debugReportCallback, vd.allocator );
	}

	// create the window VkSurfaceKHR with the instance, surface is stored in the state object
	import vdrive.surface;
	glfwCreateWindowSurface( vd.instance, vd.window, vd.allocator, &vd.surface.create_info.surface ).vkEnforce;
	//scope( exit ) meta_surface.destroySurface;
	vd.surface.create_info.imageExtent = VkExtent2D( win_w, win_h );	// Set the desired surface extent, this might change at swapchain creation


	// enumerate gpus
	auto gpus = vd.instance.listPhysicalDevices( false );

	foreach( ref gpu; gpus ) {
		//gpu.listProperties;
		gpu.listProperties( GPU_Info.properties );
		//gpu.listProperties( GPU_Info.limits );
		//gpu.listProperties( GPU_Info.sparse_properties );
		//gpu.listFeatures;
		//gpu.listLayers;
		//gpu.listExtensions;
		//printf( "Present supported: %u\n", gpu.presentSupport( vd.surface ));
	}

	// set the desired gpu into the state object
	// TODO(pp): find a suitable "best fit" gpu

	auto queue_families = listQueueFamilies( gpus[0], false );
	auto compute_queues = queue_families.filterQueueFlags( VK_QUEUE_COMPUTE_BIT, VK_QUEUE_GRAPHICS_BIT );			// filterQueueFlags
	auto graphic_queues = queue_families.filterQueueFlags( VK_QUEUE_GRAPHICS_BIT ).filterPresentSupport( gpus[0], vd.surface.surface );	// filterQueueFlags.filterPresentSupport

	vd.gpu = gpus[0];
	

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


	// enabling shader clip and cull (glsl 4.5) distance is not required if gl_PerVertex is (re)defined
	VkPhysicalDeviceFeatures features;
	auto available_features = vd.gpu.listFeatures( false );
	//features.shaderClipDistance = available_features.shaderClipDistance;
	//features.shaderCullDistance = available_features.shaderCullDistance;
	features.shaderStorageImageExtendedFormats = available_features.shaderStorageImageExtendedFormats;


	// init the logical device
	const( char* )[1] deviceExtensions = [ "VK_KHR_swapchain" ];
	vd.initDevice( filtered_queues, deviceExtensions, layers, &features );
	//scope( exit ) vd.destroyDevice;


	// retrieve graphic and present and compute queus queues
	// for now graphic and present queue are the same, but this might difere on diferent hardeare
	vd.graphic_queue_family_index = vd.surface.present_queue_family_index = graphic_queues.front.family_index;
	//vd.compute_queue_family_index = compute_queues.front.family_index;

	vkGetDeviceQueue( vd.device, vd.surface.present_queue_family_index, 0, &vd.surface.present_queue );
	vkGetDeviceQueue( vd.device, vd.graphic_queue_family_index, 0, &vd.graphic_queue );
	vkGetDeviceQueue( vd.device, vd.graphic_queue_family_index, 0, &vd.compute_queue );
	
	return vd;
}
