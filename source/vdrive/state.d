module vdrive.state;

import std.array : replicate;
import std.stdio : writeln, writefln, stderr;
import std.string : fromStringz;

import erupted;

//import vdrive.glfw.vulkan_glfw3;
import derelict.glfw3;
import vdrive.util;

/*
mixin DerelictGLFW3_VulkanBind;

// Initialize basic vulkan functions at module import
static this() {

	//DerelictErupted.load();
	//VulkanGLFW3.load;
	DerelictGLFW3.load;
	DerelictGLFW3_loadVulkan();

	glfwInit();
	loadGlobalLevelFunctions( cast( typeof( vkGetInstanceProcAddr ))
		glfwGetInstanceProcAddress( null, "vkGetInstanceProcAddr" ));
}
*/
bool verbose = true;



struct Vulkan {
	const( VkAllocationCallbacks )*	allocator = null;
	VkInstance			instance = null;
	
	Device_Resource		device_resource;
	alias 				device_resource this;

	VkSurfaceKHR		surface;
	VkExtent2D			surface_extent;
	VkSwapchainKHR		swapchain;
	Array!VkImage		present_images;
	VkFormat			present_image_format;
	VkImage				depth_image;
	VkImageView			depth_image_view;
	VkFormat			depth_image_format;

	Array!VkFramebuffer	framebuffers;
	VkRenderPass		render_pass;

	VkQueue				present_queue = VK_NULL_HANDLE;
	alias				graphic_queue = present_queue;

	uint32_t			present_queue_family_index;
	alias				graphic_queue_family_index = present_queue_family_index;

	VkPipelineLayout	pipeline_layout;
	VkPipeline			pipeline;

}


private struct Device_Resource {
	
	VkDevice			device = VK_NULL_HANDLE;
	VkPhysicalDevice	gpu = VK_NULL_HANDLE;
	VkPhysicalDeviceMemoryProperties memory_properties;



	// Queues
}

// TODO(pp): Create Template specialization for const( char* )[]
//const( char* )[2] ext = [ "VK_KHR_surface", "VK_KHR_win32_surface" ]; foreach( e; ext ) printf( "%s\n", e );
void initInstance( T )( ref Vulkan vk, T extensionNames, T layerNames )
if( is( T == string ) | is( T == string[] ) | is( T == Array!( const( char )* )) | is( T : const( char* )[] )) {

	// Information about the application
	VkApplicationInfo application_info = {
		pEngineName			: "V-Drive",
		engineVersion		: VK_MAKE_VERSION( 0, 1, 0 ),
		pApplicationName	: "V-Drive-App",
		applicationVersion	: VK_MAKE_VERSION( 0, 1, 0 ),
		apiVersion			: VK_MAKE_VERSION( 1, 0, 8 ),
	};

	// Preprocess arguments if passed as string or string[] at compile time
	static if( is( T == string )) {
		Array!( const( char )* ) ppExtensionNames;
		ppExtensionNames = extensionNames.toPtrArray;

		Array!( const( char )* ) ppLayerNames;
		if( layerNames.length > 0 )   ppLayerNames = layerNames.toPtrArray;

	} else static if( is( T == string[] )) {
		Array!char extension_concat_buffer;
		Array!( const( char )* ) ppExtensionNames;
		ppExtensionNames = extensionNames.toPtrArray( extension_concat_buffer );

		Array!char layer_concat_buffer;
		Array!( const( char )* ) ppLayerNames;
		if( layerNames.length > 0 )   ppLayerNames = layerNames.toPtrArray( layer_concat_buffer );

	} else {
		alias ppExtensionNames = extensionNames;
		alias ppLayerNames = layerNames;
	}

	// Specify initialization of the vulkan instance
	VkInstanceCreateInfo instance_create_info = {
		pApplicationInfo		: &application_info,
		enabledExtensionCount	: cast( uint32_t )ppExtensionNames.length,
		ppEnabledExtensionNames	: ppExtensionNames.ptr,
		enabledLayerCount		: cast( uint32_t )ppLayerNames.length,
		ppEnabledLayerNames		: ppLayerNames.ptr,
	};

	// Create the vulkan instance
	vkCreateInstance( &instance_create_info, null, &vk.instance ).vkEnforce;

	// load all functions from the instance - useful for prototyping
	loadInstanceLevelFunctions( vk.instance );

	if( verbose ) {
		writeln;
		writeln( "Instance initialized" );
		writeln( "====================" );
	}
/*
	uint32_t gpus_count;
	vkEnumeratePhysicalDevices( vk.instance, &gpus_count, null ).vkEnforce;

	if( gpus_count == 0 ) {
		stderr.writeln("No gpus found.");
	}

	vk.gpus.length = gpus_count;
	vkEnumeratePhysicalDevices( vk.instance, &gpus_count, vk.gpus.ptr ).vkEnforce;

	if( verbose ) {
		writeln;
		writeln( "GPU count: ", gpus_count ); 
		writeln( "============" );
	}
*/
}


void initInstance( ref Vulkan vk, string extensionNames = "", string layerNames = "" ) {
	initInstance!( string )( vk, extensionNames, layerNames );
}

void initInstance( ref Vulkan vk, string[] extensionNames, string[] layerNames = [] ) {
	initInstance!( string[] )( vk, extensionNames, layerNames );
}

void initInstance( ref Vulkan vk, const( char* )[] extensionNames, const( char* )[] layerNames = [] ) {
	initInstance!( const( char* )[] )( vk, extensionNames, layerNames );
}

void destroy_instance( ref Vulkan vk ) {
	vkDestroyInstance( vk.instance, vk.allocator );
}

void destroy_surface( ref Vulkan vk ) {
	vkDestroySurfaceKHR( vk.instance, vk.surface, vk.allocator );
}

// TODO(pp): Create Template specialization for const( char* )[]
//const( char* )[2] ext = [ "VK_KHR_surface", "VK_KHR_win32_surface" ]; foreach( e; ext ) printf( "%s\n", e );
auto initDevice( T )( 
	ref Vulkan vk, 
	Queue_Family[] queue_families, 
	T extensionNames,
	T layerNames, 
	VkPhysicalDeviceFeatures* gpuFeatures = null )
if( is( T == string ) | is( T == string[] ) | is( T == Array!( const( char )* )) | is( T : const( char* )[] ) ) {

	// check if Vulkan state has a not VK_NULL_HANDLE
	if( vk.gpu == VK_NULL_HANDLE )  {
		writeln( "Physical Device is VK_NULL_HANDLE! Set a valid Physical Devise as Vulkan.gpu ");
		return null;
	}

	// check if any queue family was passed into function
	if( queue_families.length == 0 )  {
		writeln( "Zero family queues specified! Need at least one family queue! ");
		return null;
	}


	// Preprocess arguments if passed as string or string[] at compile time
	static if( is( T == string )) {
		Array!( const( char )* ) ppExtensionNames;
		ppExtensionNames = extensionNames.toPtrArray;

		Array!( const( char )* ) ppLayerNames;
		if( layerNames.length > 0 )   ppLayerNames = layerNames.toPtrArray;

	} else static if( is( T == string[] )) {
		Array!char extension_concat_buffer;
		Array!( const( char )* ) ppExtensionNames;
		ppExtensionNames = extensionNames.toPtrArray( extension_concat_buffer );

		Array!char layer_concat_buffer;
		Array!( const( char )* ) ppLayerNames;
		if( layerNames.length > 0 )   ppLayerNames = layerNames.toPtrArray( layer_concat_buffer );

	} else {
		alias ppExtensionNames = extensionNames;
		alias ppLayerNames = layerNames;
	}

	// arange queue_families into VkdeviceQueueCreateInfos
	auto queue_create_infos = sizedArray!VkDeviceQueueCreateInfo( queue_families.length );
	foreach( i, ref queue_family; queue_families ) {
		queue_create_infos[i].queueFamilyIndex	= queue_family.family_index;
		queue_create_infos[i].queueCount		= queue_family.queueCount;
		queue_create_infos[i].pQueuePriorities 	= queue_family.priorities;
	}

	VkDeviceCreateInfo device_create_info = {
		queueCreateInfoCount	: cast( uint32_t )queue_create_infos.length,
		pQueueCreateInfos		: queue_create_infos.ptr,
		enabledExtensionCount	: cast( uint32_t )ppExtensionNames.length,
		ppEnabledExtensionNames	: ppExtensionNames.ptr,
		enabledLayerCount		: cast( uint32_t )ppLayerNames.length,
		ppEnabledLayerNames		: ppLayerNames.ptr,
		pEnabledFeatures		: gpuFeatures,
	};

	// create the device and load all device level Vulkan functions for the device
	vk.gpu.vkCreateDevice( &device_create_info, null, &vk.device ).vkEnforce;
	loadDeviceLevelFunctions( vk.device );

	// get and store the memory properties of the current gpu
	// TODO(pp): the memory properties do not print nicely, fix this
	vk.memory_properties = vk.gpu.listMemoryProperties( false );



	return vk.device;
}


auto initDevice( ref Vulkan vk, Queue_Family[] queue_families, string extensionNames = "", string layerNames = "", VkPhysicalDeviceFeatures* gpuFeatures = null ) {
	return initDevice!( string )( vk, queue_families, extensionNames, layerNames, gpuFeatures );
}


auto initDevice( ref Vulkan vk, Queue_Family[] queue_families, string[] extensionNames, string[] layerNames = [], VkPhysicalDeviceFeatures* gpuFeatures = null ) {
	return initDevice!( string[] )( vk, queue_families, extensionNames, layerNames, gpuFeatures );
}

auto initDevice( ref Vulkan vk, Queue_Family[] queue_families, const( char* )[] extensionNames, const( char* )[] layerNames = [], VkPhysicalDeviceFeatures* gpuFeatures = null ) {
	return initDevice!( const( char* )[] )( vk, queue_families, extensionNames, layerNames, gpuFeatures );
}


void destroyDevice( ref Vulkan vk ) {
	destroyDevice( vk.device, vk.allocator );
	vk.device = VK_NULL_HANDLE;
}


void destroyDevice( VkDevice device, const( VkAllocationCallbacks )* allocator = null ) {
	//vkDeviceWaitIdle( device );
	vkDestroyDevice( device, allocator );
}

