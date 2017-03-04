module vdrive.state;

import std.array : replicate;
//import std.stdio : writeln, writefln, stderr;
import core.stdc.stdio : printf;
import std.string : fromStringz;

import erupted;

import vdrive.util;


//nothrow: //@nogc:

bool verbose = true;


mixin template Vulkan_State_Pointer() {
	private Vulkan*			vk_ptr;
	alias 					vk this;

	this( ref Vulkan vk ) 				{ vk_ptr = &vk; }
	ref Vulkan vk() 					{ return * vk_ptr; }
	void vk( ref Vulkan vk ) 			{ vk_ptr = &vk; }
	auto ref opCall( ref Vulkan vk )	{ vk_ptr = &vk; return this; }
	bool isValid() 						{ return vk_ptr !is null; }
}

struct Vulkan {
	const( VkAllocationCallbacks )*	allocator = null;
	VkInstance			instance = null;
	
	Device_Resource		device_resource;
	alias 				device_resource this;

	VkQueue				graphic_queue = VK_NULL_HANDLE;
	uint32_t			graphic_queue_family_index;

	VkQueue				compute_queue = VK_NULL_HANDLE;
	uint32_t			compute_queue_family_index;
}



private struct Device_Resource {
	
	VkDevice			device = VK_NULL_HANDLE;
	VkPhysicalDevice	gpu = VK_NULL_HANDLE;
	VkPhysicalDeviceMemoryProperties memory_properties;

	// Queues
}



void initInstance( T )( ref Vulkan vk, T extensionNames, T layerNames )
if( is( T == string ) | is( T == string[] ) | is( T == Array!( const( char )* )) | is( T : const( char* )[] )) {

	// Information about the application
	VkApplicationInfo application_info = {
		pEngineName			: "V-Drive",
		engineVersion		: VK_MAKE_VERSION( 0, 1, 0 ),
		pApplicationName	: "V-Drive-App",
		applicationVersion	: VK_MAKE_VERSION( 0, 1, 0 ),
		apiVersion			: VK_API_VERSION_1_0,
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
		println;
		printf( "Instance initialized\n" );
		printf( "====================\n" );
	}
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

void destroyInstance( ref Vulkan vk ) {
	vkDestroyInstance( vk.instance, vk.allocator );
}


auto initDevice( T )( 
	ref Vulkan vk, 
	Queue_Family[] queue_families, 
	T extensionNames,
	T layerNames, 
	VkPhysicalDeviceFeatures* gpuFeatures = null )
if( is( T == string ) | is( T == string[] ) | is( T == Array!( const( char )* )) | is( T : const( char* )[] ) ) {

	// check if Vulkan state has a not VK_NULL_HANDLE
	if( vk.gpu == VK_NULL_HANDLE )  {
		printf( "Physical Device is VK_NULL_HANDLE! Set a valid Physical Devise as Vulkan.gpu\n" );
		return null;
	}

	// check if any queue family was passed into function
	if( queue_families.length == 0 )  {
		printf( "Zero family queues specified! Need at least one family queue!\n" );
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
	// TODO(pp): the memory properties print uints instaed of enum flags, fix this
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


// overloads forward to specific vkDestroy(Handle) functions
void destroy( ref Vulkan vk, VkSemaphore			handle )	{ vkDestroySemaphore(			vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkFence				handle )	{ vkDestroyFence(				vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkDeviceMemory			handle )	{ vkFreeMemory(					vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkBuffer				handle )	{ vkDestroyBuffer(				vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkImage				handle )	{ vkDestroyImage(				vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkEvent				handle )	{ vkDestroyEvent(				vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkQueryPool			handle )	{ vkDestroyQueryPool(			vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkBufferView			handle )	{ vkDestroyBufferView(			vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkImageView			handle )	{ vkDestroyImageView(			vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkShaderModule			handle )	{ vkDestroyShaderModule(		vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkPipelineCache		handle )	{ vkDestroyPipelineCache(		vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkPipelineLayout		handle )	{ vkDestroyPipelineLayout(		vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkRenderPass			handle )	{ vkDestroyRenderPass(			vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkPipeline				handle )	{ vkDestroyPipeline(			vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkDescriptorSetLayout	handle )	{ vkDestroyDescriptorSetLayout(	vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkSampler				handle )	{ vkDestroySampler(				vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkDescriptorPool		handle )	{ vkDestroyDescriptorPool(		vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkFramebuffer			handle )	{ vkDestroyFramebuffer(			vk.device, handle, vk.allocator ); }
void destroy( ref Vulkan vk, VkCommandPool			handle )	{ vkDestroyCommandPool(			vk.device, handle, vk.allocator ); }

// extension specific destroy functions
void destroy( ref Vulkan vk, VkSwapchainKHR			handle )	{ vkDestroySwapchainKHR( 		vk.device, handle, vk.allocator ); }

void destroy( ref Vulkan vk, VkDebugReportCallbackEXT handle )	{ vkDestroyDebugReportCallbackEXT( vk.instance, handle, vk.allocator ); }
