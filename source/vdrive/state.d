module vdrive.state;

import std.array : replicate;
//import std.stdio : writeln, writefln, stderr;
import core.stdc.stdio : printf;
import std.string : fromStringz;

import erupted;

import vdrive.util;

// Todo(pp): enable
//nothrow @nogc:

bool verbose = false;


mixin template Vulkan_State_Pointer() {
    private Vulkan*         vk_ptr;
    alias                   vk this;

    nothrow:
    this( ref Vulkan vk )               { vk_ptr = &vk; }
    ref Vulkan vk()                     { return * vk_ptr; }
    void vk( ref Vulkan vk )            { vk_ptr = &vk; }
    auto ref opCall( ref Vulkan vk )    { vk_ptr = &vk; return this; }
    bool isValid()                      { return vk_ptr !is null; }
}


struct Vulkan {
    const( VkAllocationCallbacks )*     allocator = null;
    VkInstance                          instance = VK_NULL_HANDLE;
    VkDevice                            device = VK_NULL_HANDLE;
    VkPhysicalDevice                    gpu = VK_NULL_HANDLE;
    VkPhysicalDeviceMemoryProperties    memory_properties;
}


void initInstance( T )( ref Vulkan vk, T extensionNames, T layerNames )
if( is( T == string ) | is( T == string[] ) | is( T == Array!( const( char )* )) | is( T : const( char* )[] )) {

    // Information about the application
    VkApplicationInfo application_info = {
        pEngineName         : "V-Drive",
        engineVersion       : VK_MAKE_VERSION( 0, 1, 0 ),
        pApplicationName    : "V-Drive-App",
        applicationVersion  : VK_MAKE_VERSION( 0, 1, 0 ),
        apiVersion          : VK_API_VERSION_1_0,
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
        pApplicationInfo        : &application_info,
        enabledExtensionCount   : cast( uint32_t )ppExtensionNames.length,
        ppEnabledExtensionNames : ppExtensionNames.ptr,
        enabledLayerCount       : cast( uint32_t )ppLayerNames.length,
        ppEnabledLayerNames     : ppLayerNames.ptr,
    };

    // Create the vulkan instance
    vkCreateInstance( &instance_create_info, null, &vk.instance ).vkAssert;

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
        queue_create_infos[i].queueFamilyIndex  = queue_family.family_index;
        queue_create_infos[i].queueCount        = queue_family.queueCount;
        queue_create_infos[i].pQueuePriorities  = queue_family.priorities;
    }

    VkDeviceCreateInfo device_create_info = {
        queueCreateInfoCount    : cast( uint32_t )queue_create_infos.length,
        pQueueCreateInfos       : queue_create_infos.ptr,
        enabledExtensionCount   : cast( uint32_t )ppExtensionNames.length,
        ppEnabledExtensionNames : ppExtensionNames.ptr,
        enabledLayerCount       : cast( uint32_t )ppLayerNames.length,
        ppEnabledLayerNames     : ppLayerNames.ptr,
        pEnabledFeatures        : gpuFeatures,
    };

    // create the device and load all device level Vulkan functions for the device
    vk.gpu.vkCreateDevice( &device_create_info, null, &vk.device ).vkAssert;
    loadDeviceLevelFunctions( vk.device );

    // get and store the memory properties of the current gpu
    // Todo(pp): the memory properties print uints instaed of enum flags, fix this
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


nothrow @nogc:

void destroyDevice( ref Vulkan vk ) {
    destroyDevice( vk.device, vk.allocator );
    vk.device = VK_NULL_HANDLE;
}


void destroyDevice( VkDevice device, const( VkAllocationCallbacks )* allocator = null ) {
    //vkDeviceWaitIdle( device );
    vkDestroyDevice( device, allocator );
}


// overloads forward to specific vkDestroy(Handle) functions
void destroy( ref Vulkan vk, ref VkSemaphore            handle )    { vkDestroySemaphore(           vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkFence                handle )    { vkDestroyFence(               vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkDeviceMemory         handle )    { vkFreeMemory(                 vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkBuffer               handle )    { vkDestroyBuffer(              vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkImage                handle )    { vkDestroyImage(               vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkEvent                handle )    { vkDestroyEvent(               vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkQueryPool            handle )    { vkDestroyQueryPool(           vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkBufferView           handle )    { vkDestroyBufferView(          vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkImageView            handle )    { vkDestroyImageView(           vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkShaderModule         handle )    { vkDestroyShaderModule(        vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkPipelineCache        handle )    { vkDestroyPipelineCache(       vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkPipelineLayout       handle )    { vkDestroyPipelineLayout(      vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkRenderPass           handle )    { vkDestroyRenderPass(          vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkPipeline             handle )    { vkDestroyPipeline(            vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkDescriptorSetLayout  handle )    { vkDestroyDescriptorSetLayout( vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkSampler              handle )    { vkDestroySampler(             vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkDescriptorPool       handle )    { vkDestroyDescriptorPool(      vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkFramebuffer          handle )    { vkDestroyFramebuffer(         vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkCommandPool          handle )    { vkDestroyCommandPool(         vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }

// extension specific destroy functions
void destroy( ref Vulkan vk, ref VkSurfaceKHR           handle )    { vkDestroySurfaceKHR(        vk.instance, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroy( ref Vulkan vk, ref VkSwapchainKHR         handle )    { vkDestroySwapchainKHR(        vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
//VkDisplayKHR
//VkDisplayModeKHR
//VkDescriptorUpdateTemplateKHR
void destroy( ref Vulkan vk, ref VkDebugReportCallbackEXT handle )  { vkDestroyDebugReportCallbackEXT( vk.instance, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
//VkObjectTableNVX
//VkIndirectCommandsLayoutNVX


template isDispatchHandle( T ... ) if( T.length == 1 ) {
    static if(
        is( typeof( T[0] ) == VkInstance )
    ||  is( typeof( T[0] ) == VkPhysicalDevice )
    ||  is( typeof( T[0] ) == VkDevice )
    ||  is( typeof( T[0] ) == VkQueue )
    ||  is( typeof( T[0] ) == VkCommandBuffer )) {
        enum bool isDispatchHandle = true;
    } else {
        enum bool isDispatchHandle = false;
    }
}


template isNonDispatchHandle( T ... ) if( T.length == 1 ) {
    static if(
        is( typeof( T[0] ) == VkSemaphore )
    ||  is( typeof( T[0] ) == VkFence )
    ||  is( typeof( T[0] ) == VkDeviceMemory )
    ||  is( typeof( T[0] ) == VkBuffer )
    ||  is( typeof( T[0] ) == VkImage )
    ||  is( typeof( T[0] ) == VkEvent )
    ||  is( typeof( T[0] ) == VkQueryPool )
    ||  is( typeof( T[0] ) == VkBufferView )
    ||  is( typeof( T[0] ) == VkImageView )
    ||  is( typeof( T[0] ) == VkShaderModule )
    ||  is( typeof( T[0] ) == VkPipelineCache )
    ||  is( typeof( T[0] ) == VkPipelineLayout )
    ||  is( typeof( T[0] ) == VkRenderPass )
    ||  is( typeof( T[0] ) == VkPipeline )
    ||  is( typeof( T[0] ) == VkDescriptorSetLayout )
    ||  is( typeof( T[0] ) == VkSampler )
    ||  is( typeof( T[0] ) == VkDescriptorPool )
    ||  is( typeof( T[0] ) == VkDescriptorSet )
    ||  is( typeof( T[0] ) == VkFramebuffer )
    ||  is( typeof( T[0] ) == VkCommandPool )
    ||  is( typeof( T[0] ) == VkSurfaceKHR )
    ||  is( typeof( T[0] ) == VkSwapchainKHR )
    ||  is( typeof( T[0] ) == VkDisplayKHR )
    ||  is( typeof( T[0] ) == VkDisplayModeKHR )
    ||  is( typeof( T[0] ) == VkDescriptorUpdateTemplateKHR )
    ||  is( typeof( T[0] ) == VkDebugReportCallbackEXT )
    ||  is( typeof( T[0] ) == VkObjectTableNVX )
    ||  is( typeof( T[0] ) == VkIndirectCommandsLayoutNVX )) {
        enum bool isNonDispatchHandle = true;
    } else {
        enum bool isNonDispatchHandle = false;
    }
}