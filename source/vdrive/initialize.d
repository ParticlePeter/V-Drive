module vdrive.initialize;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.memory;

import erupted;


nothrow @nogc:


bool verbose_init = true;

private template isVkOrGpu( T )         { enum isVkOrGpu        = is( T == Vulkan ) || is( T == VkPhysicalDevice ); }
private template isVkOrInstance( T )    { enum isVkOrInstance   = is( T == Vulkan ) || is( T == VkInstance ); }


////////////////
// Extensions //
////////////////

/// helper function to print listed extension properties
private void printExtensionProperties( Array_T )( VkPhysicalDevice gpu, ref Array_T extension_properties, bool layer_extensions ) {

    // header buffer
    SArray!( char, 60 ) header;

    // header text
    gpu.is_null
        ? header.append( "\nInstance" )
        : header.append(   "\nDevice" );
    if( layer_extensions )
        header.append( " Layer" );
    header.append( " Extensions\n" );

    // header underline
    size_t header_length = header.length;
    header.length = 2 * header_length - 2;
    header[ header_length .. $ ] = '=';
    header.append( "\n\0" );

    // print header
    printf( header.ptr );

    // print extension info
    if( extension_properties.length == 0 )
        printf( "\tExtension: None\n" );
    else
        foreach( ref properties; extension_properties )
            printf( "\t%s, version: %d\n", properties.extensionName.ptr, properties.specVersion );

    println;
}




// All of this _Result based stuff is overcomplicated crap!
// There should be only one base function and various convenience functions.
// This base function takes and any kind of resizing array, including an Arena, for which it creates a Block

/// Result type to list extensions using Vulkan_State scratch memory
alias List_Extensions_Result = Scratch_Result!VkExtensionProperties;



/// list all available ( layer per ) instance / device extensions, using scratch memory
auto ref listExtensions( Result_T )(
    ref Result_T    result,
    const( char )*  layer,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = result.vk.gpu;
    else                                    auto gpu = result.query;

    // Enumerate Instance or Device extensions
    if( gpu.is_null )   listVulkanProperty!( Result_T.Array_T, vkEnumerateInstanceExtensionProperties,                 const( char )* )( result.array, file, line, func, layer );
    else                listVulkanProperty!( Result_T.Array_T, vkEnumerateDeviceExtensionProperties, VkPhysicalDevice, const( char )* )( result.array, file, line, func, gpu, layer );
    if( print_info ) gpu.printExtensionProperties( result.array, layer != null );
    return result.array;
}


/// list all available ( layer per ) instance / device extensions, sub-allocates from scratch arena memory
auto listExtensions( ref Vulkan vk, const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    alias Array_T = Block_Array!VkExtensionProperties;
    auto result = Array_T( vk.scratch );
    if( vk.gpu.is_null ) listVulkanProperty!( Array_T, vkEnumerateInstanceExtensionProperties,                 const( char )* )( result, file, line, func, layer );
    else                 listVulkanProperty!( Array_T, vkEnumerateDeviceExtensionProperties, VkPhysicalDevice, const( char )* )( result, file, line, func, vk.gpu, layer );
    if( print_info )  vk.gpu.printExtensionProperties( result, layer != null );
    return result;
}


/// list all available ( layer per ) instance / device extensions, allocates heap memory
auto listExtensions( VkPhysicalDevice gpu, const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto result = Dynamic_Result!( VkExtensionProperties, VkPhysicalDevice )( gpu );
    listExtensions!( typeof( result ))( result, layer, print_info, file, line, func );
    return result.array.release;
}



/// get the version of any available instance / device / layer extension
auto extensionVersion( String_T, VK_OR_GPU )(
    String_T            extension,
    ref VK_OR_GPU       vk_or_gpu,
    const( char )*      layer = null,
    bool                print_info = true,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) if( isStringT!String_T && isVkOrGpu!VK_OR_GPU ) {

    static if( isVulkan!VK_OR_GPU ) auto query_result = Scratch_Result!( VkExtensionProperties )( vk_or_gpu );
    else                            auto query_result = Dynamic_Result!( VkExtensionProperties, VK_OR_GPU )( vk_or_gpu );

    uint32_t result = 0;                                                // version result
    listExtensions( query_result, layer, false, file, line, func );     // list all extensions
    foreach( ref properties; query_result.array ) {                     // search for requested extension
        static if( is( String_T : const( char )* )) {
            import core.stdc.string : strcmp;
            if( strcmp( properties.extensionName.ptr, extension )) {
                result = properties.specVersion;
                break;
            }
        } else {
            import core.stdc.string : strncmp, strlen;
            if( extension.length == properties.extensionName.ptr.strlen
            &&  strncmp( properties.extensionName.ptr, extension.ptr, extension.length ) == 0 ) {
                result = properties.specVersion;
                break;
            }
        }
    }
    //pragma( msg, String_T.stringof );
    if( print_info ) {
        static if( is( String_T : const( char )* )) {
            printf( "%s version: %u\n", layer, result );
        } else {
            // Todo(pp): why is this here evaluated in the case of  T : const( char )* ?????
            //auto layer_z = layer.toStringz;
            //printf( "%s version: %u\n", layer_z.ptr, result );
        }
    }

    return result;
}

/// check if an instance / device / layer extension of any version is available
auto isExtension( String_T, VK_OR_GPU )(
    String_T            extension,
    ref VK_OR_GPU       vk_or_gpu,
    const( char )*      layer = null,
    bool                print_info = true,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) if( isStringT!String_T && isVkOrGpu!VK_OR_GPU ) {

    auto result = extensionVersion!( String_T, VK_OR_GPU )( extension, vk_or_gpu, layer, false, file, line, func ) > 0;

    if( print_info ) {
        static if( is( String_T : const( char )* )) {
            printf( "%s available: %u\n", extension, result );
        } else {
            // if we have passed Vulkan_State instead of just the VkPhysicalDevice, we can use the scratch array to sub-allocate string z conversion
            static if( isVulkan!VK_OR_GPU ) auto extension_z = Block_Array!char( vk_or_gpu.scratch );
            else                            auto extension_z = Dynamic_Array!char();    // allocates
            extension.toStringz( extension_z );
            printf( "%s available: %u\n", extension_z.ptr, result );
        }
    }
    return result;
}



unittest {
    string surfaceString = "VK_KHR_surface";
    printf( "Version: %d\n", "VK_KHR_surface".instance_extension_version );
    printf( "Version: %d\n", surfaceString.instance_extension_version );

    char[64] surface = "VK_KHR_surface";
    printf( "Version: %d\n", ( & surface[0] ).instance_extension_version );
    printf( "Version: %d\n", surface.ptr.instance_extension_version );
    printf( "Version: %d\n", surface[].instance_extension_version );
    printf( "Version: %d\n", surface.instance_extension_version );
}



////////////
// Layers //
////////////

/// helper function to print listed layer properties, drills down into extension properties of each layer
private void printLayerProperties( Array_T, VK_OR_GPU )(
    ref Array_T     layer_properties,
    ref VK_OR_GPU   vk_or_gpu,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isVkOrGpu!VK_OR_GPU ) {

    if( layer_properties.length == 0 ) {
        printf( "\tLayers: None\n" );
    } else {
        static if( isVulkan!VK_OR_GPU ) {
            auto gpu = vk_or_gpu.gpu;
            auto result = Scratch_Result!( VkExtensionProperties )( vk_or_gpu );
        } else {
            auto gpu = vk_or_gpu;
            auto result = Dynamic_Result!( VkExtensionProperties, VK_OR_GPU )( gpu );
        }

        if ( gpu != VK_NULL_HANDLE ) {
            VkPhysicalDeviceProperties gpu_properties;
            vkGetPhysicalDeviceProperties( gpu, & gpu_properties );
            println;
            printf( "Layers of: %s\n", gpu_properties.deviceName.ptr );
            import core.stdc.string : strlen;
            auto underline_length = 11 + strlen( gpu_properties.deviceName.ptr );
            printRepeat!VK_MAX_PHYSICAL_DEVICE_NAME_SIZE( '=', underline_length );
            println;
        }
        foreach( ref property; layer_properties ) {
            printf( "%s:\n", property.layerName.ptr );
            printf( "\tVersion: %d\n", property.implementationVersion );
            auto ver = property.specVersion;
            printf( "\tSpec Version: %d.%d.%d\n", ver.vkMajor, ver.vkMinor, ver.vkPatch );
            printf( "\tDescription: %s\n", property.description.ptr );

            // drill into layer extensions
            //gpu.listExtensions( property.layerName.ptr, true );
            listExtensions!( typeof( result ))( result, property.layerName.ptr, true, file, line, func );
        }
    }
    println;
}



/// Result type to list layers using Vulkan_State scratch memory
alias List_Layers_Result = Scratch_Result!VkLayerProperties;



/// list all available instance / device layers
auto ref listLayers( Result_T )(
    ref Result_T    layer_properties,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = layer_properties.vk.gpu;
    else                                    auto gpu = layer_properties.query;

    // Enumerate Instance or Device layers
    if( gpu.is_null )   listVulkanProperty!( Result_T.Array_T, vkEnumerateInstanceLayerProperties,                )( layer_properties, file, line, func );
    else                listVulkanProperty!( Result_T.Array_T, vkEnumerateDeviceLayerProperties, VkPhysicalDevice )( layer_properties, file, line, func, gpu );

    if( print_info ) {
        // if we received a Scratch_Result, we should pass on its Vulkan_State with scratch array, otherwise just the gpu
        static if( isScratchResult!Result_T )   printLayerProperties( layer_properties, layer_properties.vk );
        else                                    printLayerProperties( layer_properties, gpu );
    }
    return layer_properties.array;
}



auto listLayers( VkPhysicalDevice gpu, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto result = Dynamic_Result!( VkLayerProperties, VkPhysicalDevice )( gpu );
    listLayers!( typeof( result ))( result, print_info, file, line, func );
    if( print_info )
        printLayerProperties( result, gpu );
    return result;
}



auto listLayers( ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    alias Array_T = Block_Array!VkLayerProperties;
    auto result = Array_T( vk.scratch );

    // Enumerate Instance or Device layers
    if( vk.gpu.is_null ) listVulkanProperty!( Array_T, vkEnumerateInstanceLayerProperties,                )( result, file, line, func );
    else                 listVulkanProperty!( Array_T, vkEnumerateDeviceLayerProperties, VkPhysicalDevice )( result, file, line, func, vk.gpu );

    if( print_info ) printLayerProperties( result, vk );
    return result;
}



/// get the version of any available instance / device layer
auto layerVersion( String_T, VK_OR_GPU )(
    String_T        layer,
    ref VK_OR_GPU   vk_or_gpu,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isStringT!String_T && isVkOrGpu!VK_OR_GPU ) {

    static if( isVulkan!VK_OR_GPU ) auto query_result = Scratch_Result!( VkLayerProperties )( vk_or_gpu );
    else                            auto query_result = Dynamic_Result!( VkLayerProperties, VK_OR_GPU )( vk_or_gpu );

    uint32_t result = 0;                                    // version result
    listLayers( query_result, false, file, line, func );    // list all layers
    foreach( ref properties; query_result.array ) {         // search for requested layer
        static if( is( String_T : const( char )* )) {
            import core.stdc.string : strcmp;
            if( strcmp( properties.layerName.ptr, layer ) == 0 ) {
                result = properties.implementationVersion;
                break;
            }
        } else {
            import core.stdc.string : strncmp, strlen;
            if( layer.length == properties.layerName.ptr.strlen && strncmp( properties.layerName.ptr, layer.ptr, layer.length ) == 0 ) {
                result = properties.implementationVersion;
                break;
            }
        }
    }

    if( print_info ) {
        static if( is( String_T : const( char )* )) {
            printf( "%s version: %u\n", layer, result );
        } else {
            auto layer_z = layer.toStringz;
            printf( "%s version: %u\n", layer_z.ptr, result );
        }
    }

    return result;
}

/// check if an instance / device layer of any version is available
auto isLayer( String_T, VK_OR_GPU )(
    String_T        layer,
    ref VK_OR_GPU   vk_or_gpu,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isStringT!String_T && isVkOrGpu!VK_OR_GPU ) {

    auto result = layerVersion( layer, vk_or_gpu, false, file, line, func ) > 0;

    if( print_info ) {
        static if( is( String_T : const( char )* )) {
            printf( "%s available: %u\n", layer, result );
        } else {
            // if we have passed Vulkan_State instead of just the VkPhysicalDevice, we can use the scratch array to sub-allocate string z conversion
            static if( isVulkan!VK_OR_GPU ) auto layer_z = Block_Array!char( vk_or_gpu.scratch );
            else                            auto layer_z = Dynamic_Array!char();    // allocates
            layer.toStringz( layer_z );
            printf( "%s available: %u\n", layer_z.ptr, result );
        }
    }

    return result;
}



/////////////////////
// Physical Device //
/////////////////////

/// Result type to list Physical Devices (GPUs) using Vulkan_State scratch memory
alias listPhysicalDevicesResult = Scratch_Result!VkPhysicalDevice;



auto ref listPhysicalDevices( Result_T )(
    ref Result_T    result,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    static if( isScratchResult!Result_T )   auto instance = result.vk.instance;
    else                                    auto instance = result.query;

    vkAssert( !instance.is_null, "List physical devices: Vulkan.instance must not be VK_NULL_HANDLE!", file, line, func );
    listVulkanProperty!( Result_T.Array_T, vkEnumeratePhysicalDevices, VkInstance )( result.array, file, line, func, instance );

    if( result.array.length == 0 ) {
        import core.stdc.stdio : fprintf, stderr;
        fprintf( stderr, "No gpus found.\n" );
    }

    if( print_info ) {
        println;
        printf( "GPU count: %d\n", result.array.length );
        printf( "============\n" );
    }
    return result.array;
}

//alias listPhysicalDevices = listPhysicalDevices_T!Vulkan;
//alias listPhysicalDevices = listPhysicalDevices_T!VkInstance;


auto listPhysicalDevices( VkInstance instance, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto result = Dynamic_Result!( VkPhysicalDevice, VkInstance )( instance );
    listPhysicalDevices( result, print_info, file, line, func );
    return result.array.release;
}


// flags to determine if and which gpu properties should be printed
enum GPU_Info_Flags { none = 0, name, properties, limits = 4, sparse_properties = 8 };



// returns gpu properties and can also print the properties, limits and sparse properties
// the passed in Result_Type (Scratch or Dynamic) is only for string z conversion purpose
auto listProperties(
    VkPhysicalDevice    gpu,
    GPU_Info_Flags      gpu_info,
    Arena_Array*        arena,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {

    VkPhysicalDeviceProperties gpu_properties;
    vkGetPhysicalDeviceProperties( gpu, & gpu_properties );

    if( gpu_info == GPU_Info_Flags.none ) return gpu_properties;

    printf( "%s\n", gpu_properties.deviceName.ptr );
    import core.stdc.string : strlen;
    auto underline_length = strlen( gpu_properties.deviceName.ptr );
    printRepeat!VK_MAX_PHYSICAL_DEVICE_NAME_SIZE( '=', underline_length );
    println;

    if( gpu_info & GPU_Info_Flags.properties ) {
        auto ver = gpu_properties.apiVersion;
        printf( "\tAPI Version     : %d.%d.%d\n", ver.vkMajor, ver.vkMinor, ver.vkPatch );
        printf( "\tDriver Version  : %d\n", gpu_properties.driverVersion );
        printf( "\tVendor ID       : %d\n", gpu_properties.vendorID );
        printf( "\tDevice ID       : %d\n", gpu_properties.deviceID );

        // if an Arena_Array was passed in we can suballocate from it for the string_z conversion, else we allocate
        if( arena !is null ) {
            auto device_type_z = Block_Array!char( *arena );
            gpu_properties.deviceType.toStringz( device_type_z );       // suballocates from arena
            printf( "\tGPU type        : %s\n", device_type_z.ptr );
        } else {
            auto device_type_z = gpu_properties.deviceType.toStringz;   // allocates and returns a dynamic array
            printf( "\tGPU type        : %s\n", device_type_z.ptr );
        }
        println;
    }

    if( gpu_info & GPU_Info_Flags.limits ) {
        gpu_properties.limits.printTypeInfo;
    }

    if( gpu_info & GPU_Info_Flags.sparse_properties ) {
        gpu_properties.sparseProperties.printTypeInfo;
    }

    return gpu_properties;
}

auto listProperties( VkPhysicalDevice gpu, GPU_Info_Flags gpu_info = GPU_Info_Flags.none, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    return listProperties( gpu, gpu_info, null, file, line, func );    // in this case we return the VkPhysicalDeviceProperties, the array is only for string z conversion when printing
}

auto listProperties( VkPhysicalDevice gpu, GPU_Info_Flags gpu_info, ref Arena_Array arena, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    return listProperties( gpu, gpu_info, & arena, file, line, func );    // in this case we return the VkPhysicalDeviceProperties, the array is only for string z conversion when printing
}

// returns the physical device features of a certain physical device
auto listFeatures( VkPhysicalDevice gpu, bool print_info = true ) {
    VkPhysicalDeviceFeatures features;
    vkGetPhysicalDeviceFeatures( gpu, & features );
    if( print_info )  printTypeInfo( features );
    return features;
}

// returns gpu memory properties
auto listMemoryProperties( VkPhysicalDevice gpu, bool print_info = true ) {
    VkPhysicalDeviceMemoryProperties memory_properties = gpu.memoryProperties;
    if( print_info )  printTypeInfo( memory_properties );
    return memory_properties;
}


// returns if the physical device does support presentations
auto presentSupport( ref VkPhysicalDevice gpu, VkSurfaceKHR surface, bool print_info = true ) {
    uint32_t queue_family_property_count;
    vkGetPhysicalDeviceQueueFamilyProperties( gpu, & queue_family_property_count, null );
    VkBool32 present_supported;
    foreach( family_index; 0..queue_family_property_count ) {
        vkGetPhysicalDeviceSurfaceSupportKHR( gpu, family_index, surface, & present_supported );
        if( present_supported ) {
            return true;
        }
    }
    return false;
}

////////////
// Queues //
////////////

alias listQueuesResult = Scratch_Result!VkQueueFamilyProperties;


/// list all available queue families and their queue count
auto ref listQueues( Result_T )(
    ref Result_T    queue_family_properties,
    bool            print_info = true,
    VkSurfaceKHR    surface = VK_NULL_HANDLE,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = queue_family_properties.vk.gpu;
    else                                    auto gpu = queue_family_properties.query;

    // Enumerate Queues
    listVulkanProperty!( Result_T.Array_T, vkGetPhysicalDeviceQueueFamilyProperties, VkPhysicalDevice )( queue_family_properties, file, line, func, gpu );

    // log the info
    if( print_info ) {
        foreach( q, ref queue; queue_family_properties.data ) {
            println;
            printf( "Queue Family %lu\n", cast( int )q );
            printf( "\tQueues in Family         : %d\n", queue.queueCount );
            printf( "\tQueue timestampValidBits : %d\n", queue.timestampValidBits );

            if( surface != VK_NULL_HANDLE ) {
                VkBool32 present_supported;
                vkGetPhysicalDeviceSurfaceSupportKHR( gpu, q.toUint, surface, & present_supported );
                printf( "\tPresentation supported   : %d\n", present_supported );
            }

            if( queue.queueFlags & VK_QUEUE_GRAPHICS_BIT )
                printf( "\tVK_QUEUE_GRAPHICS_BIT\n" );

            if( queue.queueFlags & VK_QUEUE_COMPUTE_BIT )
                printf( "\tVK_QUEUE_COMPUTE_BIT\n" );

            if( queue.queueFlags & VK_QUEUE_TRANSFER_BIT )
                printf( "\tVK_QUEUE_TRANSFER_BIT\n" );

            if( queue.queueFlags & VK_QUEUE_SPARSE_BINDING_BIT )
                printf( "\tVK_QUEUE_SPARSE_BINDING_BIT\n" );
        }
    }

    return queue_family_properties;
}



auto listQueues( VkPhysicalDevice gpu, bool print_info = true, VkSurfaceKHR surface = VK_NULL_HANDLE, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto result = Dynamic_Result!( VkQueueFamilyProperties, VkPhysicalDevice )( gpu );
    listQueues!( typeof( result ))( result, print_info, surface, file, line, func );
    return result.array.release;
}



// Wraps a VkQueueFamilyProperties
// adds a family index and a Static_Array!float priorities
struct Queue_Family_T( uint Capacity, Size_T = uint ) {

    private uint32_t index;
    private VkQueueFamilyProperties queue_family_properties;
    private SArray!( float, Capacity, Size_T ) queue_priorities;

    // get a copy of the family index
    auto family_index() { return index; }

    // get a read only reference to the wrapped VkQueueFamilyProperties
    ref const( VkQueueFamilyProperties ) vkQueueFamilyProperties() {
        return queue_family_properties;
    }

    // VkQueueFamilyProperties can be reached
    alias vkQueueFamilyProperties this;

    // query the count of queues available in the wrapped VkQueueFamilyProperties
    uint32_t maxQueueCount() {
        return queue_family_properties.queueCount;
    }

    // query the currently requested queue count
    uint32_t queueCount() {
        return queue_priorities.length.toUint;
    }

    void queueCount( uint32_t count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {
        vkAssert( count <= maxQueueCount, "More queues requested than available!", file, line, func );
        queue_priorities.length = count;
        import std.math : isNaN;
        foreach( ref priority; queue_priorities ) if( priority.isNaN ) priority = 0.0f;
    }

    // get a pointer to the priorities array
    float * priorities() {
        return queue_priorities.ptr;
    }

    // getter and setter for a specific priority at a specific index
    ref float priority( uint32_t queue_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {
        vkAssert( queue_index < queue_priorities.length, "Index out of bounds of requested priorities!", file, line, func );
        return queue_priorities[ queue_index ];
    }

    // set all priorities and implicitly the requested queue count
    void priorities( float[] values, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {
        vkAssert( values.length <= maxQueueCount, "More priorities specified than available queues!", file, line, func );
        queue_priorities.append( values );
    }

    // get a string representation of the data
    auto toString() {
        import core.stdc.stdio : sprintf;
        char[256] buffer;
        sprintf(  buffer.ptr,
            "\n\tfamilyIndex: %u, maxQueueCount: %u, queueCount: %u, queue_priorities: Todo(pp)",
            family_index, maxQueueCount, queueCount//, queue_priorities[]
        );
        return buffer;
    }
}

alias  Queue_Family = Queue_Family_T!4;     // Todo(pp): Queue_Family is used excessively, but it should always be Queue_Family_T!4. Fix this!

alias listQueueFamiliesResult = Scratch_Result!Queue_Family;
alias listQueueFamiliesResult_T( uint Capacity ) = Scratch_Result!( Queue_Family_T!Capacity );     // enables us to pass in a max count for the families as template argument

/// get list of Queue_Family structs
/// the struct wraps VkQueueFamilyProperties with its family index
/// and a priority array, with which the count of queues an their priorities can be specified
/// filter functions exist to get queues with certain properties for the Result_T family_queues.array
/// the initDevice function consumes an array of these structs to specify queue families and queues to be created
/// Params:
///     gpu = reference to a VulkanState struct
///     print_info = optional: if true prints struct content to stdout
///     surface = optional: if passed in the printed info includes whether a queue supports presenting to that surface
/// Returns: Array embedded in Result_T family_queues
auto ref listQueueFamilies( Result_T )(
    ref Result_T    family_queues,
    bool            print_info = true,
    VkSurfaceKHR    surface = VK_NULL_HANDLE,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = family_queues.vk.gpu;
    else                                    auto gpu = family_queues.query;

    vkAssert( !gpu.is_null, "List Queue Families, gpu must not be VK_NULL_HANDLE!", file, line, func );

    // Care must be taken if using scratch space to gather the required information
    // at this point the referenced result family_queues is already part of scratch
    // but it has not sub-allocated memory. We must reserve the required memory before we
    // sub-allocate the required queue family properties, or the former would not have
    // any space to be resized, as the latter is consecutively behind it
    uint32_t queue_family_property_count;
    vkGetPhysicalDeviceQueueFamilyProperties( gpu, & queue_family_property_count, null );

    family_queues.reserve( queue_family_property_count, file, line, func );     // we reserve first as we do not need...
    family_queues.length(  queue_family_property_count, file, line, func );     // ... extra space to grow after the requested length

    // now enumerate all the queues
    static if( isScratchResult!Result_T ) {
        auto queue_family_properties = listQueuesResult ( family_queues.vk );
        listQueues( queue_family_properties, print_info, surface );
    } else {
        auto queue_family_properties = listQueues( gpu, print_info, surface );
    }

    foreach( family_index, ref family; queue_family_properties.data ) {
        family_queues[ family_index ] = Queue_Family( cast( uint32_t )family_index, family );
    }
    return family_queues.array;//.release;
}



auto listQueueFamilies( VkPhysicalDevice gpu, bool print_info = true, VkSurfaceKHR surface = VK_NULL_HANDLE, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto result = Dynamic_Result!( Queue_Family, VkPhysicalDevice )( gpu );
    listQueueFamilies!( typeof( result ))( result, print_info, surface, file, line, func );
    return result.array.release;
}


/*
auto listQueueFamilies_T( size_t max_queues_per_family )( VkPhysicalDevice gpu, bool print_info = true, VkSurfaceKHR surface = VK_NULL_HANDLE ) {
    auto queue_family_properties = listQueues( gpu, print_info, surface );   // get Array of VkQueueFamilyProperties
    auto family_queues = sizedArray!( Queue_Family_T!max_queues_per_family )( queue_family_properties.length );
    foreach( family_index, ref family; queue_family_properties.data ) {
        family_queues[ family_index ] = Queue_Family( cast( uint32_t )family_index, family );
    }
    return family_queues;//.release;
}
alias listQueueFamilies = listQueueFamilies_T!64;
*/

alias filter = filterQueueFlags;
auto ref filterQueueFlags( Array_T )(
    ref Array_T     family_queues,
    VkQueueFlags    include_queue,
    VkQueueFlags    exclude_queue = 0

    ) if( isDataArrayOrSlice!( Array_T, Queue_Family )) {

    // remove invalid entries by overwriting them with valid ones
    size_t valid_index = 0;
    foreach( i; 0..family_queues.length ) {
        if(( family_queues[ i ].queueFlags & include_queue ) && !( family_queues[ i ].queueFlags & exclude_queue )) {
            if( valid_index < i ) {     // no need to replace if the current loop index equals the valid index
                family_queues[ valid_index ] = family_queues[ i ];
            }
            ++valid_index;
        }
    }
    // shrink the array to the amount of valid entries
    family_queues.length = valid_index;
    return family_queues;
}


alias filter = filterPresentSupport;
auto ref filterPresentSupport( Array_T )(
    ref Array_T         family_queues,
    VkPhysicalDevice    gpu,
    VkSurfaceKHR        surface

    ) if( isDataArrayOrSlice!( Array_T, Queue_Family )) {

    // remove invalid entries by overwriting them with valid ones
    size_t valid_index = 0;
    VkBool32 present_supported;

    foreach( i, ref family_queue; family_queues ) {
        vkGetPhysicalDeviceSurfaceSupportKHR( gpu, family_queue.family_index, surface, & present_supported );
        if( present_supported ) {
            if( valid_index < i ) {     // no need to replace if the current loop index equals the valid index
                family_queues[ valid_index ] = family_queue;
            }
            ++valid_index;
        }
    }
    // shrink the array to the amount of valid entries
    family_queues.length = valid_index;
    return family_queues;
}




///////////////////////////
// Convenience Functions //
///////////////////////////

/// list all available instance extensions
auto listExtensions( bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nInstance Extensions\n===================\n" );
    return listExtensions( VK_NULL_HANDLE, null, print_info, file, line, func );
}

/// list all available per layer instance extensions
auto listExtensions( const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nInstance Layer Extensions\n=========================\n" );
    return listExtensions( VK_NULL_HANDLE, layer, print_info, file, line, func );
}

/// list all available device extensions
auto listExtensions( VkPhysicalDevice gpu, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nPhysical Device Extensions\n==========================\n" );
    return listExtensions( gpu, null, print_info, file, line, func );
}

/// list all available layer per device extensions
auto listDeviceLayerExtensions( VkPhysicalDevice gpu, const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nPhysical Device Layer Extensions\n================================\n" );
    return listExtensions( gpu, layer, print_info, file, line, func );
}


// Get the version of an instance layer extension
auto extensionVersion( String_T )( String_T extension, const( char )* layer, bool print_info = false, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return extensionVersion!( String_T, VkPhysicalDevice )( extension, vkNull, layer, print_info, file, line, func );
}

// Get the version of an instance extension
auto extensionVersion( String_T )( String_T extension, bool print_info, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return extensionVersion!( String_T, VkPhysicalDevice )( extension, vkNull, null, print_info, file, line, func );
}

/// check if an instance layer extension of any version is available
auto isExtension( String_T )( String_T extension, const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return isExtension( extension, vkNull, layer, print_info, file, line, func );
}

/// check if an instance extension of any version is available
auto isExtension( String_T )( String_T extension, bool print_info, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return isExtension!( String_T, VkPhysicalDevice )( extension, vkNull, null, print_info, file, line, func );
}

/// check if a device extension of any version is available
auto isExtension( String_T )( String_T extension, VkPhysicalDevice gpu, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    return isExtension!( String_T, VkPhysicalDevice )( extension, gpu, null, print_info, file, line, func );
}

// list all instance layers
auto listLayers( bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if( print_info ) printf( "\nInstance Layers\n===============\n" );
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return listLayers( vkNull, print_info, file, line, func );
}

/// check if an instance layer of any version is available
auto isLayer( String_T )( String_T layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return isLayer( layer, vkNull, print_info, file, line, func );
}



/////////////////////////////////////////////
// Convenience Functions Vulkan State base //
/////////////////////////////////////////////

/// list all available instance or device extensions, depends on whteher gpu is set in Vulkan State
auto ref listExtensions( Result_T )( ref Result_T result, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {
    return listExtensions( result, null, print_info, file, line, func );
}

/// list all available instance or device layer extensions, depends on whteher gpu is set in Vulkan State
auto listExtensions( ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    return listExtensions( vk, null, print_info, file, line, func );
}

// Get the version of an instance extension
auto extensionVersion( String_T )( String_T extension, ref Vulkan vk, bool print_info, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    return extensionVersion( extension, vk, null, print_info, file, line, func );
}

/// check if a device extension of any version is available, depends on whteher gpu is set in Vulkan State
auto isExtension( String_T )( String_T extension, ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    return isExtension!( String_T, Vulkan )( extension, vk, null, print_info, file, line, func );
}
/*
// list all instance layers
auto listLayers( ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if( print_info ) printf( "\nInstance Layers\n===============\n" );
    return listLayers!Vulkan( vk, print_info, file, line, func );
}
*/
/// check if an instance layer of any version is available
auto isLayer( String_T )( String_T layer, ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    return isLayer!( String_T, Vulkan )( layer, vk, print_info, file, line, func );
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
