module vdrive.initialize;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.memory;

import erupted;


nothrow @nogc:


bool verbose_init = true;


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
    auto queue_cis = Scratch_Result!VkDeviceQueueCreateInfo( vk, queue_families.length );
    foreach( i, ref queue_family; queue_families ) {
        queue_cis[i].queueFamilyIndex  = queue_family.family_index;
        queue_cis[i].queueCount        = queue_family.queueCount;
        queue_cis[i].pQueuePriorities  = queue_family.priorities;
    }

    VkDeviceCreateInfo device_ci = {
        queueCreateInfoCount    : cast( uint32_t )queue_cis.length,
        pQueueCreateInfos       : queue_cis.ptr,
        enabledExtensionCount   : cast( uint32_t )ppExtensionNames.length,
        ppEnabledExtensionNames : ppExtensionNames.ptr,
        enabledLayerCount       : cast( uint32_t )ppLayerNames.length,
        ppEnabledLayerNames     : ppLayerNames.ptr,
        pEnabledFeatures        : gpu_features,
    };

    // create the device and load all device level Vulkan functions for the device
    vk.gpu.vkCreateDevice( & device_ci, null, & vk.device ).vkAssert( "Create Device, file, line, func" );
    loadDeviceLevelFunctions( vk.device );

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
    stringz[]            		extension_names,
    stringz[]            		layer_names,
    VkPhysicalDeviceFeatures*   gpu_features = null,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    return initDevice!( const( char* )[] )( vk, queue_families, extension_names, layer_names, gpu_features, file, line, func );
}


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
    VkInstanceCreateInfo instance_ci = {
        pApplicationInfo        : application_info_ptr,
        enabledExtensionCount   : cast( uint32_t )ppExtensionNames.length,
        ppEnabledExtensionNames : ppExtensionNames.ptr,
        enabledLayerCount       : cast( uint32_t )ppLayerNames.length,
        ppEnabledLayerNames     : ppLayerNames.ptr,
    };

    // Create the vulkan instance
    vkCreateInstance( & instance_ci, vk.allocator, & vk.instance ).vkAssert( "Instance Initialization", file, line, func );

    // load all instance based functions from the instance
    loadInstanceLevelFunctions( vk.instance );

    if( verbose_init ) {
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
