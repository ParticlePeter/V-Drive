module vdrive.state;

import core.stdc.stdio : printf;
import std.string : fromStringz;

import erupted;

import vdrive.util;

// Todo(pp): enable
//nothrow @nogc:

bool verbose = true;


mixin template Vulkan_State_Pointer() {
    private Vulkan*         vk_ptr;
    alias                   vk this;

    nothrow @nogc:
    this( ref Vulkan vk )               { vk_ptr = & vk; }
    ref Vulkan vk()                     { return * vk_ptr; }
    void vk( ref Vulkan vk )            { vk_ptr = & vk; }
    auto ref opCall( ref Vulkan vk )    { vk_ptr = & vk; return this; }
    bool isValid()                      { return vk_ptr !is null; }
}


// Todo(pp): rename to Vulkan_State, rename as well occurrences of: ///     vk = reference to a VulkanState struct
struct Vulkan {
    const( VkAllocationCallbacks )*     allocator = null;
    VkInstance                          instance = VK_NULL_HANDLE;
    VkDevice                            device = VK_NULL_HANDLE;
    VkPhysicalDevice                    gpu = VK_NULL_HANDLE;
    VkPhysicalDeviceMemoryProperties    memory_properties;

    VkDebugReportCallbackEXT            debug_report_callback = VK_NULL_HANDLE;
    VkDebugUtilsMessengerEXT            debug_utils_messenger = VK_NULL_HANDLE;

    import vdrive.util.array;
    Arena_Array                         scratch;
}

template isVulkan( T ) { enum isVulkan = is( T == Vulkan ); }


struct Scratch_Result( Result_T ) {
    private Vulkan* vk_ptr;
    alias           array this;
    alias           Array_T = Block_Array!Result_T;


    nothrow @nogc:
    Array_T         array;
    @disable        this();
    @disable        this( this );

    ref Vulkan vk()         { return * vk_ptr; }
    bool isValid()          { return vk_ptr !is null; }

    this( ref Vulkan vk, size_t count = 0 )   {
        vk_ptr = & vk;
        array = Array_T( vk.scratch );
        if( count > 0 ) {
            array.reserve( count );
            array.length(  count, true );
        }
    }
}

template isScratchResult( T ) { enum isScratchResult = is( typeof( isScratchResultImpl( T.init ))); }
private void isScratchResultImpl( R )( Scratch_Result!R result ) {}


void initInstance( T )(
    ref Vulkan          vk,
    T                   extension_names,
    T                   layer_names,
    VkApplicationInfo*  application_info_ptr = null,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) if( is( T == string ) || is( T == string[] ) || isDataArray!( T, stringz ) || is( T : const( char* )[] )) {

    // Default information about the application, in case none was passed in by the user
    VkApplicationInfo application_info = {
        pEngineName         : "V-Drive",
        engineVersion       : VK_MAKE_VERSION( 0, 1, 0 ),
        pApplicationName    : "V-Drive-App",
        applicationVersion  : VK_MAKE_VERSION( 0, 1, 0 ),
        apiVersion          : VK_API_VERSION_1_0,
    };

    // if no application info was passed ind we assign the address to the default one
    if( application_info_ptr is null )
        application_info_ptr = & application_info;

    // Pre-process arguments if passed as string or string[] at compile time
    static if( is( T == string )) {
        auto ppExtensionNames = Block_Array!stringz( vk.scratch );
        if( extension_names.length > 0 )
            extension_names.toPtrArray( ppExtensionNames );

        auto ppLayerNames = Block_Array!stringz( vk.scratch );
        if( layer_names.length > 0 )
            layer_names.toPtrArray( ppLayerNames );

    } else static if( is( T == string[] )) {
        auto extension_concat_buffer = Block_Array!char( vk.scratch );
        auto ppExtensionNames = Block_Array!stringz( vk.scratch );
        if( extension_names.length > 0 )
            extension_names.toPtrArray( ppExtensionNames, extension_concat_buffer );

        auto layer_concat_buffer = Block_Array!char( vk.scratch );
        auto ppLayerNames = Block_Array!stringz( vk.scratch );
        if( layer_names.length > 0 )
            layer_names.toPtrArray( ppLayerNames, layer_concat_buffer );

    } else {
        alias ppExtensionNames = extension_names;
        alias ppLayerNames = layer_names;
    }

    // Specify initialization of the vulkan instance
    VkInstanceCreateInfo instance_create_info = {
        pApplicationInfo        : application_info_ptr,
        enabledExtensionCount   : cast( uint32_t )ppExtensionNames.length,
        ppEnabledExtensionNames : ppExtensionNames.ptr,
        enabledLayerCount       : cast( uint32_t )ppLayerNames.length,
        ppEnabledLayerNames     : ppLayerNames.ptr,
    };

    // Create the vulkan instance
    vkCreateInstance( &instance_create_info, vk.allocator, &vk.instance ).vkAssert( "Instance Initialization", file, line, func );

    // load all functions from the instance - useful for prototyping
    loadInstanceLevelFunctions( vk.instance );

    if( verbose ) {
        println;
        printf( "Instance initialized\n" );
        printf( "====================\n" );
    }
}


void initInstance(
    ref Vulkan          vk,
    string              extension_names = "",
    string              layer_names = "",
    VkApplicationInfo*  application_info_ptr = null,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    initInstance!( string )( vk, extension_names, layer_names, application_info_ptr, file, line, func );
}

void initInstance(
    ref Vulkan          vk,
    string[]            extension_names,
    string[]            layer_names = [],
    VkApplicationInfo*  application_info_ptr = null,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    initInstance!( string[] )( vk, extension_names, layer_names, application_info_ptr, file, line, func );
}

void initInstance(
    ref Vulkan          vk,
    const( char* )[]    extension_names,
    const( char* )[]    layer_names = [],
    VkApplicationInfo*  application_info_ptr = null,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    initInstance!( const( char* )[] )( vk, extension_names, layer_names, application_info_ptr, file, line, func );
}

void destroyInstance( ref Vulkan vk ) {
    vkDestroyInstance( vk.instance, vk.allocator );
}



auto initDevice( T )(
    ref Vulkan                  vk,
    Queue_Family[]              queue_families,
    T                           extension_names,
    T                           layer_names,
    VkPhysicalDeviceFeatures*   gpu_features = null,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) if( is( T == string ) || is( T == string[] ) || isDataArray!( T, stringz ) || is( T : const( char* )[] )) {

    // check if Vulkan state has a gpu set properly
    vkAssert( vk.gpu != VK_NULL_HANDLE,
        "Physical Device is VK_NULL_HANDLE! Set a valid Physical Devise as Vulkan.gpu", file, line, func
    );

    // check if any queue family was passed into function
    vkAssert( queue_families.length > 0,
        "Zero family queues specified! Need at least one family queue!", file, line, func
    );


    // Pre-process arguments if passed as string or string[] at compile time
    static if( is( T == string )) {
        auto ppExtensionNames = Block_Array!stringz( vk.scratch );
        if( extension_names.length > 0 )
            extension_names.toPtrArray( ppExtensionNames );

        auto ppLayerNames = Block_Array!stringz( vk.scratch );
        if( layer_names.length > 0 )
            layer_names.toPtrArray( ppLayerNames );

    } else static if( is( T == string[] )) {
        auto extension_concat_buffer = Block_Array!char( vk.scratch );
        auto ppExtensionNames = Block_Array!stringz( vk.scratch );
        if( layer_names.length > 0 )
            extension_names.toPtrArray( ppExtensionNames, extension_concat_buffer );

        auto layer_concat_buffer = Block_Array!char( vk.scratch );
        auto ppLayerNames = Block_Array!stringz( vk.scratch );
        if( layer_names.length > 0 )
            layer_names.toPtrArray( ppLayerNames, layer_concat_buffer );

    } else {

        alias ppExtensionNames = extension_names;
        alias ppLayerNames = layer_names;

    }

    // arrange queue_families into VkdeviceQueueCreateInfos
    auto queue_create_infos = Scratch_Result!VkDeviceQueueCreateInfo( vk, queue_families.length );
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
        pEnabledFeatures        : gpu_features,
    };

    // create the device and load all device level Vulkan functions for the device
    vk.gpu.vkCreateDevice( &device_create_info, null, &vk.device ).vkAssert( "Create Device, file, line, func" );
    loadDeviceLevelFunctions( vk.device );

    // get and store the memory properties of the current gpu
    // Todo(pp): the memory properties print uints instaed of enum flags, fix this
    vk.memory_properties = vk.gpu.listMemoryProperties( false );

    return vk.device;
}


auto initDevice(
    ref Vulkan                  vk,
    Queue_Family[]              queue_families,
    string                      extension_names = "",
    string                      layer_names = "",
    VkPhysicalDeviceFeatures*   gpu_features = null,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    return initDevice!( string )( vk, queue_families, extension_names, layer_names, gpu_features, file, line, func );
}

auto initDevice(
    ref Vulkan                  vk,
    Queue_Family[]              queue_families,
    string[]                    extension_names = [],
    string[]                    layer_names = [],
    VkPhysicalDeviceFeatures*   gpu_features = null,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    return initDevice!( string[] )( vk, queue_families, extension_names, layer_names, gpu_features, file, line, func );
}

auto initDevice(
    ref Vulkan                  vk,
    Queue_Family[]              queue_families,
    const( char* )[]            extension_names,
    const( char* )[]            layer_names,
    VkPhysicalDeviceFeatures*   gpu_features = null,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    return initDevice!( const( char* )[] )( vk, queue_families, extension_names, layer_names, gpu_features, file, line, func );
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


template is_dispatch_handle( T ) {
    static if(
        is( T == VkInstance )
    ||  is( T == VkPhysicalDevice )
    ||  is( T == VkDevice )
    ||  is( T == VkQueue )
    ||  is( T == VkCommandBuffer )) {
        enum bool is_dispatch_handle = true;
    } else {
        enum bool is_dispatch_handle = false;
    }
}


template is_non_dispatch_handle( T ) {
    static if(
        is( T == VkSemaphore )
    ||  is( T == VkFence )
    ||  is( T == VkDeviceMemory )
    ||  is( T == VkBuffer )
    ||  is( T == VkImage )
    ||  is( T == VkEvent )
    ||  is( T == VkQueryPool )
    ||  is( T == VkBufferView )
    ||  is( T == VkImageView )
    ||  is( T == VkShaderModule )
    ||  is( T == VkPipelineCache )
    ||  is( T == VkPipelineLayout )
    ||  is( T == VkRenderPass )
    ||  is( T == VkPipeline )
    ||  is( T == VkDescriptorSetLayout )
    ||  is( T == VkSampler )
    ||  is( T == VkDescriptorPool )
    ||  is( T == VkDescriptorSet )
    ||  is( T == VkFramebuffer )
    ||  is( T == VkCommandPool )
    ||  is( T == VkSurfaceKHR )
    ||  is( T == VkSwapchainKHR )
    ||  is( T == VkDisplayKHR )
    ||  is( T == VkDisplayModeKHR )
    ||  is( T == VkDescriptorUpdateTemplateKHR )
    ||  is( T == VkDebugReportCallbackEXT )
    ||  is( T == VkObjectTableNVX )
    ||  is( T == VkIndirectCommandsLayoutNVX )
    ) {
        enum bool is_non_dispatch_handle = true;
    } else {
        enum bool is_non_dispatch_handle = false;
    }
}


alias is_null = is_null_handle;
bool is_null_handle( T )( T handle ) if( is_non_dispatch_handle!T ) {
    return handle == VK_NULL_HANDLE;
}


mixin template Is_Null(             alias handle ) { bool is_null()         { return handle == VK_NULL_HANDLE; }}
mixin template Is_Constructed(      alias handle ) { bool is_constructed()  { return handle != VK_NULL_HANDLE; }}
mixin template Is_Null_Constructed( alias handle ) {
    bool is_null()         { return handle == VK_NULL_HANDLE; }
    bool is_constructed()  { return handle != VK_NULL_HANDLE; }
}
