module vdrive.initializer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.memory;

import erupted;


nothrow @nogc:


bool verbose_init = true;

private template isVkOrGpu( T )         { enum isVkOrGpu        = isVulkan!T || is( T == VkPhysicalDevice ); }
private template isVkOrInstance( T )    { enum isVkOrInstance   = isVulkan!T || is( T == VkInstance ); }

/// compare two zero terminated strings by content
private bool isEqual( string_z a, string_z b ) {
    import core.stdc.string : strcmp;
    return strcmp( a, b ) == 0;
}


////////////////
// Extensions //
////////////////

/// helper function to print listed extension properties
private void printExtensionProperties( Array_T )( VkPhysicalDevice gpu, ref Array_T extension_properties, bool layer_extensions ) {

    // header buffer
    Static_Array!( char, 60 ) header;

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


/// list all available ( layer per ) instance / device extensions, sub-allocates from scratch arena memory
auto listExtensions( ref Vulkan vk, string_z layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    alias Array_T = Block_Array!VkExtensionProperties;
    auto result = Array_T( vk.scratch );
    if( vk.gpu.is_null ) listVulkanProperty!( Array_T, vkEnumerateInstanceExtensionProperties,                 string_z )( result, file, line, func, layer );
    else                 listVulkanProperty!( Array_T, vkEnumerateDeviceExtensionProperties, VkPhysicalDevice, string_z )( result, file, line, func, vk.gpu, layer );
    if( print_info )  vk.gpu.printExtensionProperties( result, layer != null );
    return result;
}

/// list all available ( layer per ) instance / device extensions, sub-allocates from scratch arena memory
auto listExtensions( VkPhysicalDevice gpu, string_z layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    alias Array_T = Dynamic_Array!VkExtensionProperties;
    Array_T result;
    if( gpu.is_null ) listVulkanProperty!( Array_T, vkEnumerateInstanceExtensionProperties,                 string_z )( result, file, line, func, layer );
    else              listVulkanProperty!( Array_T, vkEnumerateDeviceExtensionProperties, VkPhysicalDevice, string_z )( result, file, line, func, gpu, layer );
    if( print_info )  gpu.printExtensionProperties( result, layer != null );
    return result;
}


/// get the version of any available instance / device / layer extension
private uint32_t extensionVersionImpl( VK_OR_GPU )(
    ref VK_OR_GPU   vk_or_gpu,
    string_z        extension,
    string_z        layer = null,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isVkOrGpu!VK_OR_GPU ) {

    uint32_t result = 0;                                                                    // version result
    auto extension_properties = vk_or_gpu.listExtensions( layer, false, file, line, func ); // list all extensions
    foreach( ref props; extension_properties ) {                                            // search for requested extension
        if( isEqual( props.extensionName.ptr, extension )) {
            result = props.specVersion;
            break;
        }
    }
    if( print_info )
        printf( "%s version: %u\n", extension, result );
    return result;
}

alias extensionVersion = extensionVersionImpl!Vulkan;
alias extensionVersion = extensionVersionImpl!VkPhysicalDevice;


/// check if an instance / device / layer extension of any version is available
private bool isExtensionImpl( VK_OR_GPU )(
    ref VK_OR_GPU   vk_or_gpu,
    string_z        extension,
    string_z        layer = null,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isVkOrGpu!VK_OR_GPU ) {

    bool result = vk_or_gpu.extensionVersion( extension, layer, false, file, line, func ) > 0;
    if( print_info )
        printf( "%s available: %u\n", extension, result );
    return result;
}

alias isExtension = isExtensionImpl!Vulkan;
alias isExtension = isExtensionImpl!VkPhysicalDevice;



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
private void printLayerProperties( VK_OR_GPU, Array_T )(
    ref VK_OR_GPU   vk_or_gpu,
    ref Array_T     layer_properties,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isVkOrGpu!VK_OR_GPU ) {

    if( layer_properties.length == 0 ) {
        printf( "\tLayers: None\n" );
    } else {
        static if( isVulkan!VK_OR_GPU ) auto gpu = vk_or_gpu.gpu;
        else                            auto gpu = vk_or_gpu;

        if ( gpu != VK_NULL_HANDLE ) {
            VkPhysicalDeviceProperties gpu_properties;
            gpu.vkGetPhysicalDeviceProperties( & gpu_properties );
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
            vk_or_gpu.listExtensions( property.layerName.ptr, true, file, line, func );
        }
    }
    println;
}


/// list all available instance / device layers
auto listLayers( ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    alias Array_T = Block_Array!VkLayerProperties;
    auto result = Array_T( vk.scratch );
    if( vk.gpu.is_null )    listVulkanProperty!( Array_T, vkEnumerateInstanceLayerProperties,                )( result, file, line, func );
    else                    listVulkanProperty!( Array_T, vkEnumerateDeviceLayerProperties, VkPhysicalDevice )( result, file, line, func, vk.gpu );
    if( print_info )        vk.printLayerProperties( result );
    return result;
}


/// list all available instance / device layers
auto listLayers( VkPhysicalDevice gpu, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    alias Array_T = Dynamic_Array!VkLayerProperties;
    Array_T result;
    if( gpu.is_null )    listVulkanProperty!( Array_T, vkEnumerateInstanceLayerProperties,                )( result, file, line, func );
    else                 listVulkanProperty!( Array_T, vkEnumerateDeviceLayerProperties, VkPhysicalDevice )( result, file, line, func, gpu );
    if( print_info )     gpu.printLayerProperties( result );
    return result;
}


/// get the version of any available instance / device layer
private uint32_t layerVersionImpl( VK_OR_GPU )(
    ref VK_OR_GPU   vk_or_gpu,
    string_z        layer,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isVkOrGpu!VK_OR_GPU ) {

    uint32_t result = 0;                                                        // version result
    auto layer_properties = vk_or_gpu.listLayers( false, file, line, func );    // list all layers
    import core.stdc.string : strcmp;
    foreach( ref props; layer_properties ) {                                    // search for requested layer
        if( strcmp( props.layerName.ptr, layer ) == 0 ) {
            result = props.implementationVersion;
            break;
        }
    }
    if( print_info )
        printf( "%s version: %u\n", layer, result );
    return result;
}

alias layerVersion = layerVersionImpl!Vulkan;
alias layerVersion = layerVersionImpl!VkPhysicalDevice;


/// check if an instance / device layer of any version is available
private bool isLayerImpl( VK_OR_GPU )(
    ref VK_OR_GPU   vk_or_gpu,
    string_z        layer,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isVkOrGpu!VK_OR_GPU ) {

    bool result = vk_or_gpu.layerVersion( layer, false, file, line, func ) > 0;
    if( print_info )
        printf( "%s available: %u\n", layer, result );
    return result;
}

alias isLayer = isLayerImpl!Vulkan;
alias isLayer = isLayerImpl!VkPhysicalDevice;



/////////////////////
// Physical Device //
/////////////////////

/// helper function to print info about available gpu count
private void printGpuCount( uint gpu_count, bool print_info ) {
    pragma( inline, true );
    if( gpu_count == 0 ) {
        import core.stdc.stdio : fprintf, stderr;
        fprintf( stderr, "No gpus found.\n" );
    }
    if( print_info ) {
        println;
        printf( "GPU count: %d\n", gpu_count );
        printf( "============\n" );
    }
}

/// List all physical devices
private auto listPhysicalDevicesImpl( VK_OR_INSTANCE )(
    ref VK_OR_INSTANCE  vk_or_instance,
    bool                print_info = true,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) if( isVkOrInstance!VK_OR_INSTANCE ) {

    // extract instance member and result array type based on template argument
    static if( isVulkan!VK_OR_INSTANCE ) {
        VkInstance instance = vk_or_instance.instance;
        alias Array_T = Block_Array!VkPhysicalDevice;
        Array_T result = Array_T( vk_or_instance.scratch );
    } else {
        VkInstance instance = vk_or_instance;
        alias Array_T = Dynamic_Array!VkPhysicalDevice;
        Array_T result;
    }
    vkAssert( !instance.is_null, "List physical devices: Vulkan.instance must not be VK_NULL_HANDLE!", file, line, func );
    listVulkanProperty!( Array_T, vkEnumeratePhysicalDevices, VkInstance )( result, file, line, func, instance );
    return result;
}

alias listPhysicalDevices = listPhysicalDevicesImpl!Vulkan;
alias listPhysicalDevices = listPhysicalDevicesImpl!VkInstance;


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
        printf( "\tAPI Variant     : %d\n", ver.vkVariant );
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
    foreach( family_index; 0 .. queue_family_property_count ) {
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

private void printQueueFamilyProperties( Array_T )( VkPhysicalDevice gpu, ref Array_T queue_family_properties, VkSurfaceKHR surface ) {
    foreach( i, ref queue; queue_family_properties.data ) {
        println;
        printf( "Queue Family %llu\n", i );
        printf( "\tQueues in Family         : %d\n", queue.queueCount );
        printf( "\tQueue timestampValidBits : %d\n", queue.timestampValidBits );

        if( surface != VK_NULL_HANDLE ) {
            VkBool32 present_supported;
            vkGetPhysicalDeviceSurfaceSupportKHR( gpu, i.toUint32, surface, & present_supported );
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


/// list all available ( layer per ) instance / device extensions, sub-allocates from scratch arena memory
auto listQueues( ref Vulkan vk, bool print_info = true, VkSurfaceKHR surface = VK_NULL_HANDLE, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    alias Array_T = Block_Array!VkQueueFamilyProperties;
    auto result = Array_T( vk.scratch );
    listVulkanProperty!( Array_T, vkGetPhysicalDeviceQueueFamilyProperties, VkPhysicalDevice )( result, file, line, func, vk.gpu );
    if( print_info )  vk.gpu.printQueueFamilyProperties( result, surface );
    return result;
}

/// list all available ( layer per ) instance / device extensions, sub-allocates from scratch arena memory
auto listQueues( VkPhysicalDevice gpu, bool print_info = true, VkSurfaceKHR surface = VK_NULL_HANDLE, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    alias Array_T = Dynamic_Array!VkQueueFamilyProperties;
    Array_T result;
    listVulkanProperty!( Array_T, vkGetPhysicalDeviceQueueFamilyProperties, VkPhysicalDevice )( result, file, line, func, gpu );
    if( print_info )  gpu.printQueueFamilyProperties( result, surface );
    return result;
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

/// get list of Queue_Family structs
/// the struct wraps VkQueueFamilyProperties with its family index and a priority array,
/// with which the count of queues and their priorities can be specified
/// filter functions exist to get queues with certain properties for the resulting list
/// the initDevice function consumes sauch a list to specify queue families and queues to be created
/// Params:
///     vk_or_gpu = reference (templated) to either a VulkanState struct or a VK_PhysicalDevice, determines if scratch space can be used (former case)
///     print_info = optional: if true prints struct content to stdout
///     surface = optional: if passed in the printed info includes whether a queue supports presenting to that surface
/// Returns: list (array) of family_queues
private auto ref listQueueFamiliesImpl( VK_OR_GPU )(
    ref VK_OR_GPU   vk_or_gpu,
    bool            print_info = true,
    VkSurfaceKHR    surface = VK_NULL_HANDLE,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isVkOrGpu!VK_OR_GPU ) {

    // extract gpu member based on template argument
    static if( isVulkan!VK_OR_GPU ) auto gpu = vk_or_gpu.gpu;
    else                            auto gpu = vk_or_gpu;

    // check if gpu is available
    vkAssert( !gpu.is_null, "List Queue Families, gpu must not be VK_NULL_HANDLE!", file, line, func );

    // create result array based on template argument
    static if( isVulkan!VK_OR_GPU )   Block_Array!Queue_Family family_queues = Block_Array!Queue_Family( vk_or_gpu.scratch );
    else                            Dynamic_Array!Queue_Family family_queues;

    // Care must be taken if using scratch space to gather the required information
    // at this point the referenced result family_queues is already part of scratch
    // but it has not sub-allocated memory. We must reserve the required memory before we
    // sub-allocate the required queue family properties, or the former would not have
    // any space to be resized, as the latter is consecutively behind it
    uint32_t queue_family_property_count;
    gpu.vkGetPhysicalDeviceQueueFamilyProperties( & queue_family_property_count, null );

    family_queues.reserve( queue_family_property_count, file, line, func );     // we reserve first as we do not need ...
    family_queues.length(  queue_family_property_count, file, line, func );     //  ... extra space to grow after the requested length

    // now enumerate all the queues
    auto queue_family_properties = vk_or_gpu.listQueues( print_info, surface );

    foreach( family_index, ref family; queue_family_properties.data )
        family_queues[ family_index ] = Queue_Family( family_index.toUint32, family );

    return family_queues;
}

alias listQueueFamilies = listQueueFamiliesImpl!Vulkan;
alias listQueueFamilies = listQueueFamiliesImpl!VkPhysicalDevice;


// filter queues for specific queue flags, sorts and shrinks the passed in array in place
// Todo(pp): create Range interface for arrays and filter lazilly
auto ref filterQueueFlags( Array_T )(
    ref Array_T     family_queues,
    VkQueueFlags    include_queue,
    VkQueueFlags    exclude_queue = 0

    ) if( isDataArrayOrSlice!( Array_T, Queue_Family )) {

    // remove invalid entries by overwriting them with valid ones
    size_t valid_index = 0;
    foreach( i; 0 .. family_queues.length ) {
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

alias filter = filterQueueFlags;


// filter queues for prsent support, sorts and shrinks the passed in array in place
// Todo(pp): create Range interface for arrays and filter lazilly
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

alias filter = filterPresentSupport;




///////////////////////////
// Convenience Functions //
///////////////////////////

/// list all available instance extensions, allocates from heap
auto listInstanceExtensions( bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nInstance Extensions\n===================\n" );
    VkPhysicalDevice vk_null = VK_NULL_HANDLE; return vk_null.listExtensions( null, print_info, file, line, func );
}

/// list all available instance extensions, sub-allocates from scratch
auto listInstanceExtensions( ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    //if ( print_info ) printf( "\nInstance Extensions\n===================\n" );
    auto gpu = vk.gpu;          // temporary store gpu
    vk.gpu = VK_NULL_HANDLE;    // erase vk gpu member, we want Instance extensions
    auto result = vk.listExtensions( null, print_info, file, line, func );
    vk.gpu = gpu;               // restore vk gpu member
    return result;
}

/// list all available per layer instance extensions
auto listInstanceLayerExtensions( string_z layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nInstance Layer Extensions\n=========================\n" );
    VkPhysicalDevice vk_null = VK_NULL_HANDLE; return vk_null.listExtensions( layer, print_info, file, line, func );
}

/// list all available device extensions
auto listDeviceExtensions( VK_OR_GPU )( ref VK_OR_GPU vk_or_gpu, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    //if ( print_info ) printf( "\nPhysical Device Extensions\n==========================\n" );
    return vk_or_gpu.listExtensions( null, print_info, file, line, func );
}

/// list all available layer per device extensions
alias listDeviceLayerExtensions = listExtensions;


// Get the version of an instance extension
auto instanceExtensionVersion( string_z extension, bool print_info, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    VkPhysicalDevice vk_null = VK_NULL_HANDLE; return vk_null.extensionVersion( extension, null, print_info, file, line, func );
}

// Get the version of an instance layer extension
auto instanceLayerExtensionVersion( string_z extension, string_z layer, bool print_info = false, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    VkPhysicalDevice vk_null = VK_NULL_HANDLE; return vk_null.extensionVersion( extension, layer, print_info, file, line, func );
}

// Get the version of a device extension
auto deviceExtensionVersion( VK_OR_GPU )( ref VK_OR_GPU vk_or_gpu, string_z extension, bool print_info, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    return vk_or_gpu.extensionVersion( extension, null, print_info, file, line, func );
}

// Get the version of a device layer extension
alias deviceLayerExtensionVersion = extensionVersion;


/// check if an instance extension of any version is available
auto isInstanceExtension( string_z extension, bool print_info, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    VkPhysicalDevice vk_null = VK_NULL_HANDLE; return vk_null.isExtension( extension, null, print_info, file, line, func );
}

/// check if an instance layer extension of any version is available
auto isInstanceLayerExtension( string_z extension, string_z layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    VkPhysicalDevice vk_null = VK_NULL_HANDLE; return vk_null.isExtension( extension, layer, print_info, file, line, func );
}

/// check if a device extension of any version is available
auto isDeviceExtension( VK_OR_GPU )( ref VK_OR_GPU vk_or_gpu, string_z extension, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    return vk_or_gpu.isExtension( extension, null, print_info, file, line, func );
}

/// check if a device layer extension of any version is available
alias isDeviceLayerExtension = isExtension;


// list all instance layers
auto listInstanceLayers( bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if( print_info ) printf( "\nInstance Layers\n===============\n" );
    VkPhysicalDevice vk_null = VK_NULL_HANDLE; return vk_null.listLayers( print_info, file, line, func );
}

/// check if an instance layer of any version is available
auto isInstanceLayer( string_z layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    VkPhysicalDevice vk_null = VK_NULL_HANDLE; return vk_null.isLayer( layer, print_info, file, line, func );
}



/// initialize a vulkan device
auto initDevice( T )(
    ref Vulkan                  vk,
    Queue_Family[]              queue_families,
    T                           extension_names,
    VkPhysicalDeviceFeatures*   gpu_features = null,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) if( is( T == string ) || is( T == string[] ) || isDataArray!( T, string_z ) || is( T : string_z[] )) {

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
        auto ppExtensionNames = Block_Array!string_z( vk.scratch );
        if( extension_names.length > 0 )
            extension_names.toPtrArray( ppExtensionNames );

    } else static if( is( T == string[] )) {
        auto extension_concat_buffer = Block_Array!char( vk.scratch );
        auto ppExtensionNames = Block_Array!string_z( vk.scratch );
        if( extension_names.length > 0 )
            extension_names.toPtrArray( ppExtensionNames, extension_concat_buffer );

    } else {
        alias ppExtensionNames = extension_names;
    }

    // arrange queue_families into VkdeviceQueueCreateInfos
    auto queue_cis = Block_Array!VkDeviceQueueCreateInfo( vk.scratch, queue_families.length );
    foreach( i, ref queue_family; queue_families ) {
        queue_cis[i].queueFamilyIndex  = queue_family.family_index;
        queue_cis[i].queueCount        = queue_family.queueCount;
        queue_cis[i].pQueuePriorities  = queue_family.priorities;
    }

    VkDeviceCreateInfo device_ci = {
        queueCreateInfoCount    : queue_cis.length.toUint,
        pQueueCreateInfos       : queue_cis.ptr,
        enabledExtensionCount   : ppExtensionNames.length.toUint,
        ppEnabledExtensionNames : ppExtensionNames.ptr,
        enabledLayerCount       : 0,
        ppEnabledLayerNames     : null,
        pEnabledFeatures        : gpu_features,
    };

    // create the device and load all device level Vulkan functions for the device
    vk.gpu.vkCreateDevice( & device_ci, vk.allocator, & vk.device ).vkAssert( "Create Device", file, line, func );
    loadDeviceLevelFunctions( vk.device );

    return vk.device;
}


auto initDevice(
    ref Vulkan                  vk,
    Queue_Family[]              queue_families,
    string                      extension_names = "",
    VkPhysicalDeviceFeatures*   gpu_features = null,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    return initDevice!( string )( vk, queue_families, extension_names, gpu_features, file, line, func );
}

auto initDevice(
    ref Vulkan                  vk,
    Queue_Family[]              queue_families,
    string[]                    extension_names = [],
    VkPhysicalDeviceFeatures*   gpu_features = null,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    return initDevice!( string[] )( vk, queue_families, extension_names, gpu_features, file, line, func );
}

auto initDevice(
    ref Vulkan                  vk,
    Queue_Family[]              queue_families,
    string_z[]            		extension_names,
    VkPhysicalDeviceFeatures*   gpu_features = null,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    return initDevice!( string_z[] )( vk, queue_families, extension_names, gpu_features, file, line, func );
}


VkResult initInstance( T )(
    ref Vulkan          vk,
    T                   extension_names,
    T                   layer_names,
    VkApplicationInfo*  application_info_ptr = null,
    VkValidationFeaturesEXT* validation_features_ptr = null,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) if( is( T == string ) || is( T == string[] ) || isDataArray!( T, string_z ) || is( T : string_z[] )) {

    // Default information about the application, in case none was passed in by the user
    VkApplicationInfo application_info = {
        pEngineName         : "V-Drive",
        engineVersion       : VK_MAKE_API_VERSION( 0, 0, 1, 0 ),
        pApplicationName    : "V-Drive-App",
        applicationVersion  : VK_MAKE_API_VERSION( 0, 0, 1, 0 ),
        apiVersion          : VK_API_VERSION_1_0,
    };

    // if no application info was passed ind we assign the address to the default one
    if( application_info_ptr is null )
        application_info_ptr = & application_info;

    // Pre-process arguments if passed as string or string[] at compile time
    static if( is( T == string )) {
        auto ppExtensionNames = Block_Array!string_z( vk.scratch );
        if( extension_names.length > 0 )
            extension_names.toPtrArray( ppExtensionNames );

        auto ppLayerNames = Block_Array!string_z( vk.scratch );
        if( layer_names.length > 0 )
            layer_names.toPtrArray( ppLayerNames );

    } else static if( is( T == string[] )) {
        auto extension_concat_buffer = Block_Array!char( vk.scratch );
        auto ppExtensionNames = Block_Array!string_z( vk.scratch );
        if( extension_names.length > 0 )
            extension_names.toPtrArray( ppExtensionNames, extension_concat_buffer );

        auto layer_concat_buffer = Block_Array!char( vk.scratch );
        auto ppLayerNames = Block_Array!string_z( vk.scratch );
        if( layer_names.length > 0 )
            layer_names.toPtrArray( ppLayerNames, layer_concat_buffer );

    } else {
        alias ppExtensionNames = extension_names;
        alias ppLayerNames = layer_names;
    }

    // Specify initialization of the vulkan instance
    VkInstanceCreateInfo instance_ci = {
        pNext                   : validation_features_ptr,
        pApplicationInfo        : application_info_ptr,
        enabledExtensionCount   : ppExtensionNames.length.toUint,
        ppEnabledExtensionNames : ppExtensionNames.ptr,
        enabledLayerCount       : ppLayerNames.length.toUint,
        ppEnabledLayerNames     : ppLayerNames.ptr,
    };

    // Create the vulkan instance
    VkResult vkResult = vkCreateInstance( & instance_ci, vk.allocator, & vk.instance ).vkAssert( "Instance Initialization", file, line, func );
    if( vkResult != VK_SUCCESS )
        return vkResult;

    // load all instance based functions from the instance
    loadInstanceLevelFunctions( vk.instance );

    if( verbose_init ) {
        println;
        printf( "Instance initialized\n" );
        printf( "====================\n" );
    }
    return VK_SUCCESS;
}


VkResult initInstance(
    ref Vulkan          vk,
    string              extension_names = "",
    string              layer_names = "",
    VkApplicationInfo*  application_info_ptr = null,
    VkValidationFeaturesEXT* validation_features_ptr = null,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    return initInstance!( string )( vk, extension_names, layer_names, application_info_ptr, validation_features_ptr, file, line, func );
}

VkResult initInstance(
    ref Vulkan          vk,
    string[]            extension_names,
    string[]            layer_names = [],
    VkApplicationInfo*  application_info_ptr = null,
    VkValidationFeaturesEXT* validation_features_ptr = null,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    return initInstance!( string[] )( vk, extension_names, layer_names, application_info_ptr, validation_features_ptr, file, line, func );
}

VkResult initInstance(
    ref Vulkan          vk,
    string_z[]          extension_names,
    string_z[]          layer_names = [],
    VkApplicationInfo*  application_info_ptr = null,
    VkValidationFeaturesEXT* validation_features_ptr = null,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    return initInstance!( string_z[] )( vk, extension_names, layer_names, application_info_ptr, validation_features_ptr, file, line, func );
}



/// a queue requested with Meta_Init.addQueue, resolved to a queue family of the selected gpu when the device is initialized
struct Queue_Request {
    VkQueueFlags    include_flags;      // the queue family must support all of these flags
    VkQueueFlags    exclude_flags;      // the queue family must support none of these flags
    VkSurfaceKHR    present_surface;    // if not VK_NULL_HANDLE the queue family must be able to present to this surface
    float           priority;
    VkQueue*        queue;              // optional, receives the queue after device initialization
    uint32_t*       family_index;       // optional, receives the queue family index after device initialization
    VkQueueFlags    share_preference;   // prefer sharing a queue with requests including any of these flags, e.g. present from the compute queue
}


alias  Meta_Init = Meta_Init_T!();
struct Meta_Init_T(
    int32_t instance_extension_count            = int32_t.max,
    int32_t instance_layer_count                = int32_t.max,
    int32_t enabled_validation_feature_count    = int32_t.max,
    int32_t disabled_validation_feature_count   = int32_t.max,
    int32_t available_gpu_count                 = int32_t.max,
    int32_t device_extension_count              = int32_t.max,
    int32_t queue_request_count                 = int32_t.max,

    ) {

    nothrow @nogc:

    mixin   Vulkan_State_Pointer;  //false;
//  alias   Array_T = Block_Array!string_z;


    /*private*/ D_OR_S_ARRAY!( string_z, instance_extension_count ) instance_extensions;
    /*private*/ D_OR_S_ARRAY!( string_z, instance_layer_count     ) instance_layers;

    private D_OR_S_ARRAY!( VkValidationFeatureEnableEXT,  enabled_validation_feature_count  )  enabled_validation_features;
    private D_OR_S_ARRAY!( VkValidationFeatureDisableEXT, disabled_validation_feature_count ) disabled_validation_features;

    private bool validate_vulkan     = false;
    private bool validation_features = false;

    // device data, gpus are collected after the instance exists, the device is initialized on one of them
    private D_OR_S_ARRAY!( VkPhysicalDevice, available_gpu_count )  available_gpus;     // gpus meeting all device requirements, best fit first
    private bool gpus_collected = false;

    /*private*/ D_OR_S_ARRAY!( string_z, device_extension_count ) device_extensions;

    private D_OR_S_ARRAY!( Queue_Request, queue_request_count ) queue_requests;
    private D_OR_S_ARRAY!( uint32_t,      queue_request_count ) queue_request_families;   // resolved family index per queue request

    private VkPhysicalDeviceFeatures required_features;     // gpus not supporting all of these are not collected
    private VkPhysicalDeviceFeatures requested_features;    // enabled only if the selected gpu supports them
    private VkPhysicalDeviceFeatures enabled_features;      // required and supported requested features, valid after initDevice

    /// include flags of all requests sharing the queue of the (first) present request, valid after initDevice
    /// e.g. VK_QUEUE_COMPUTE_BIT when presenting from the compute queue, 0 when presenting from a dedicated queue
    VkQueueFlags present_queue_flags;

    /*
    this( ref Vulkan vk ) {
        vk_ptr = & vk;

        instance_extensions = Array_T( vk.scratch );
        instance_layers     = Array_T( vk.scratch );

         enabled_validation_features = Block_Array!VkValidationFeatureEnableEXT(  vk.scratch );
        disabled_validation_features = Block_Array!VkValidationFeatureDisableEXT( vk.scratch );

        available_gpus = Block_Array!VkPhysicalDevice( vk.scratch );
    }
    */

    ref Meta_Init_T addInstanceExtension( string_z extension ) return {
        void printWarning( string_z extension ) {
            printf( "WARNING: adding %s extension only enables Vulkan validation.\nThis in turn enables the newest available system,\nwhile %s is prefered over %s and %s.",
                extension, VK_EXT_DEBUG_UTILS_EXTENSION_NAME, VK_EXT_DEBUG_REPORT_EXTENSION_NAME, VK_EXT_DEBUG_MARKER_EXTENSION_NAME );
        }
        // compare content, not pointers, the same name can be stored at different addresses
        if( extension.isEqual( VK_EXT_DEBUG_UTILS_EXTENSION_NAME )
         || extension.isEqual( VK_EXT_DEBUG_REPORT_EXTENSION_NAME )
         || extension.isEqual( VK_EXT_DEBUG_MARKER_EXTENSION_NAME )) {
            printWarning( extension );
            validate_vulkan = true;
        } else if( extension.isEqual( VK_EXT_VALIDATION_FEATURES_EXTENSION_NAME )) {
            validation_features = true;
        } else {
            instance_extensions.append( extension );
        }
        return this;
    }

    ref Meta_Init_T addInstanceExtensions( string_z[] extensions ) return {
        instance_extensions.reserve( extensions.length + 3 );   // we might add up to 3 extensions
        foreach( extension; extensions )
            addInstanceExtension( extension );
        return this;
    }

    ref Meta_Init_T addInstanceLayer( string_z layer ) return {
        instance_layers.append( layer );
        return this;
    }

    ref Meta_Init_T addInstanceLayers( string_z[] layers ) return {
        instance_layers.append( layers );
        return this;
    }


    ref Meta_Init_T validateVulkan( bool validate ) return {
        validate_vulkan = validate;
        return this;
    }


    ref Meta_Init_T enableValidationFeature( VkValidationFeatureEnableEXT validation_feature ) return {
        enabled_validation_features.append( validation_feature );
        return this;
    }

    ref Meta_Init_T enableValidationFeature( VkValidationFeatureDisableEXT validation_feature ) return {
        disabled_validation_features.append( validation_feature );
        return this;
    }

    // Debug Utils Data
    private VkDebugUtilsMessageTypeFlagsEXT         debug_utils_type_flags      = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
                                                                                | VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
                                                                                | VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;

    private VkDebugUtilsMessageSeverityFlagsEXT     debug_utils_severity_flags  = VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT
                                                                                | VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT
                                                                                | VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
                                                                                | VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;

    private PFN_vkDebugUtilsMessengerCallbackEXT    debug_utils_pfn_callback    = null;
    private void*                                   debug_utils_user_data       = null;

    // Debug Utils Setup
    ref Meta_Init_T setDebugUtilsSeverityFlags( VkDebugUtilsMessageSeverityFlagsEXT flags ) return {
        debug_utils_severity_flags = flags;
        return this;
    }

    ref Meta_Init_T setDebugUtilsTypeFlags( VkDebugUtilsMessageTypeFlagsEXT flags ) return {
        debug_utils_type_flags = flags;
        return this;
    }

    ref Meta_Init_T setDebugUtilsCallback( PFN_vkDebugUtilsMessengerCallbackEXT callback, void* user_data ) return {
        debug_utils_pfn_callback = callback;
        debug_utils_user_data = user_data;
        return this;
    }



    // Debug Report Data
    private VkDebugReportFlagsEXT           debug_report_flags          = VK_DEBUG_REPORT_INFORMATION_BIT_EXT
                                                                        | VK_DEBUG_REPORT_WARNING_BIT_EXT
                                                                        | VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT
                                                                        | VK_DEBUG_REPORT_ERROR_BIT_EXT
                                                                        | VK_DEBUG_REPORT_DEBUG_BIT_EXT;

    private PFN_vkDebugReportCallbackEXT    debug_report_pfn_callback   = null;
    private void*                           debug_report_user_data      = null;

    // Debug Report Setup
    ref Meta_Init_T setDebugReportFlags( VkDebugReportFlagsEXT flags ) return {
        debug_report_flags = flags;
        return this;
    }

    ref Meta_Init_T setDebugReportCallback( PFN_vkDebugReportCallbackEXT callback, void* user_data ) return {
        debug_report_pfn_callback = callback;
        debug_report_user_data = user_data;
        return this;
    }



    // Initialize Instance
    VkResult initInstance( bool verbose = false, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return initInstance( null, verbose, file, line, func );
    }

    VkResult initInstance( VkApplicationInfo* application_info_ptr, bool verbose = false, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {

        bool debug_utils_selected  = false;
        bool debug_report_selected = false;

        if( validate_vulkan ) {

            // we prefer using the modern debug utils
            if( VK_EXT_DEBUG_UTILS_EXTENSION_NAME.isInstanceExtension( verbose )) {
                instance_extensions.append( VK_EXT_DEBUG_UTILS_EXTENSION_NAME );
                debug_utils_selected = true;
            }

            // else we use the debug report callback functionality if available
            else if( VK_EXT_DEBUG_REPORT_EXTENSION_NAME.isInstanceExtension( verbose )) {
                instance_extensions.append( VK_EXT_DEBUG_REPORT_EXTENSION_NAME );
                debug_report_selected = true;

                // and also debug marker functionality if available
                if( VK_EXT_DEBUG_MARKER_EXTENSION_NAME.isInstanceExtension( verbose )) {
                    instance_extensions.append( VK_EXT_DEBUG_MARKER_EXTENSION_NAME );
                }
            }
        }


        // enable validation features if available
        VkValidationFeaturesEXT  vk_validation_features;
        VkValidationFeaturesEXT* vk_validation_features_ptr = null;
        if( validation_features ) {
            if( VK_EXT_VALIDATION_FEATURES_EXTENSION_NAME.isInstanceExtension( verbose ) && ( enabled_validation_features.count > 0 || disabled_validation_features.count > 0 )) {
                instance_extensions.append( VK_EXT_VALIDATION_FEATURES_EXTENSION_NAME );
                vk_validation_features_ptr = & vk_validation_features;

                with( vk_validation_features ) {
                    pEnabledValidationFeatures = enabled_validation_features.ptr;
                    pDisabledValidationFeatures = disabled_validation_features.ptr;
                    enabledValidationFeatureCount = enabled_validation_features.count.toUint;
                    disabledValidationFeatureCount = disabled_validation_features.count.toUint;
                }
            } else {
                printf( "WARNING: %s was requested, but is not available and will be skipped.", VK_EXT_VALIDATION_FEATURES_EXTENSION_NAME );
            }
        }


        // check if all of the extensions are available, exit if not
        foreach( extension; instance_extensions.data ) {
            if( !extension.isInstanceExtension( verbose )) {
                printf( "Required extension %s not available. Exiting!\n", extension );
                return VK_ERROR_INITIALIZATION_FAILED;
            }
        }

        // check if all of the layers are available, exit if not
        foreach( layer; instance_layers.data ) {
            if( !layer.isInstanceLayer( verbose )) {
                printf( "Required layers %s not available. Exiting!\n", layer );
                return VK_ERROR_INITIALIZATION_FAILED;
            }
        }

        VkResult vk_result =
            vk.initInstance( instance_extensions.data, instance_layers.data, application_info_ptr, vk_validation_features_ptr )
                .vkAssert( "Meta_Init Instance", file, line, func );

        if( vk_result != VK_SUCCESS )
            return vk_result;

        // Create Debug Messenger or Debug Report
        import vdrive.validator;
        if( debug_utils_selected ) {
            if( debug_utils_pfn_callback is null ) {
                vk_result = createDebugMessenger( vk, debug_utils_severity_flags, debug_utils_type_flags )
                    .vkAssert( "Meta_Init Debug Messenger", file, line, func );
            } else {
                vk_result = createDebugMessenger( vk, debug_utils_severity_flags, debug_utils_type_flags, debug_utils_pfn_callback, debug_utils_user_data )
                    .vkAssert( "Meta_Init Debug Messenger User", file, line, func );
            }
        }

        else if( debug_report_selected ) {
            if( debug_report_pfn_callback is null ) {
                vk_result = createDebugReporter( vk, debug_report_flags )
                    .vkAssert( "Meta_Init Debug Reporter", file, line, func );
            } else {
                vk_result = createDebugReporter( vk, debug_report_flags, debug_report_pfn_callback, debug_report_user_data )
                    .vkAssert( "Meta_Init Debug Reporter User", file, line, func );
            }
        }

        if( vk_result != VK_SUCCESS )
            return vk_result;

    //  instance_extensions.reset;  // we don't need instance extensions any more
    //  vk.scratch.defragment;      // defragment the scratch array, moving instance layers to the front
        return vk_result;
    }



    // Device Setup
    ref Meta_Init_T addDeviceExtension( string_z extension ) return {
        if( !device_extensions.data.containsName( extension ))
            device_extensions.append( extension );
        gpus_collected = false;
        return this;
    }

    ref Meta_Init_T addDeviceExtensions( string_z[] extensions ) return {
        foreach( extension; extensions )
            addDeviceExtension( extension );
        return this;
    }

    /// request a queue with all include_flags and none of the exclude_flags, optionally able to present to a surface
    /// requests which can be satisfied by the same queue family share one queue, e.g. graphics and present
    /// queue and family_index pointers receive their values in initDevice, both are optional
    /// share_preference: if possible share the queue of a request including any of these flags, over sharing any other
    ref Meta_Init_T addQueue(
        VkQueueFlags    include_flags,
        VkQueue*        queue,
        uint32_t*       family_index        = null,
        VkSurfaceKHR    present_surface     = VK_NULL_HANDLE,
        float           priority            = 1.0f,
        VkQueueFlags    exclude_flags       = 0,
        VkQueueFlags    share_preference    = 0

        ) return {
        queue_requests.append( Queue_Request( include_flags, exclude_flags, present_surface, priority, queue, family_index, share_preference ));
        gpus_collected = false;
        return this;
    }

    /// request a queue which can present to surface, has no other flag requirements
    /// prefer_queue: present preferably from the queue of e.g. the VK_QUEUE_COMPUTE_BIT or VK_QUEUE_GRAPHICS_BIT request,
    /// if its family can present, otherwise from any other, query present_queue_flags after initDevice
    ref Meta_Init_T addPresentQueue( VkSurfaceKHR surface, VkQueue* queue, uint32_t* family_index = null, VkQueueFlags prefer_queue = 0 ) return {
        return addQueue( 0, queue, family_index, surface, 1.0f, 0, prefer_queue );
    }

    /// gpus which do not support all of these features are not collected
    ref Meta_Init_T requireFeatures( VkPhysicalDeviceFeatures features ) return {
        required_features = features;
        gpus_collected = false;
        return this;
    }

    /// these features are enabled if the selected gpu supports them, query enabledFeatures after initDevice
    ref Meta_Init_T requestFeatures( VkPhysicalDeviceFeatures features ) return {
        requested_features = features;
        return this;
    }

    /// required features plus the requested features supported by the selected gpu, valid after initDevice
    ref const( VkPhysicalDeviceFeatures ) enabledFeatures() return {
        return enabled_features;
    }


    /// collect all gpus meeting the device extension, feature and queue requirements, discrete gpus first
    /// called implicitly by initDevice, call explicitly to inspect or choose from the result
    uint32_t collectGpus( bool verbose = false, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( !vk.instance.is_null, "Meta_Init collect GPUs, the instance must be initialized first!", file, line, func );

        // a queue presenting to a surface requires the swapchain extension
        foreach( ref request; queue_requests.data ) {
            if( !request.present_surface.is_null ) {
                addDeviceExtension( VK_KHR_SWAPCHAIN_EXTENSION_NAME );
                break;
            }
        }

        available_gpus.clear;
        auto gpus = listPhysicalDevices( vk.instance, false, file, line, func );
        foreach( gpu; gpus.data )
            if( isSuitable( gpu, verbose ))
                available_gpus.append( gpu );

        // insertion sort, stable and the gpu count is tiny
        foreach( i; 1 .. available_gpus.length ) {
            auto gpu = available_gpus[ i ];
            size_t j = i;
            for( ; j > 0 && gpuTypeRank( available_gpus[ j - 1 ] ) > gpuTypeRank( gpu ); --j )
                available_gpus[ j ] = available_gpus[ j - 1 ];
            available_gpus[ j ] = gpu;
        }

        gpus_collected = true;
        return available_gpus.length.toUint;
    }

    /// count of collected gpus, valid after collectGpus or initDevice
    uint32_t availableGpuCount() {
        return available_gpus.length.toUint;
    }

    /// collected gpu at index, best fit first, valid after collectGpus or initDevice
    VkPhysicalDevice availableGpu( size_t index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return available_gpus.opIndex( index, file, line, func );
    }


    // Initialize Device
    /// initialize the device on the collected gpu at gpu_index, assigns vk.gpu and vk.device and fills requested queues
    VkResult initDevice( size_t gpu_index = 0, bool verbose = false, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

        if( !gpus_collected )
            collectGpus( verbose, file, line, func );

        if( gpu_index >= available_gpus.length ) {
            printf( "No GPU meeting the device requirements found at index %llu, %u available. Exiting!\n", cast( ulong )gpu_index, available_gpus.length.toUint );
            return VK_ERROR_INITIALIZATION_FAILED;
        }

        vk.gpu = available_gpus[ gpu_index ];
        resolveQueueFamilies( vk.gpu );   // succeeded already while collecting

        // enable required features and the supported requested ones
        auto available_features = vk.gpu.listFeatures( false );
        enabled_features = required_features;
        auto enabled   = featureFlags( enabled_features );
        auto requested = featureFlags( requested_features );
        auto available = featureFlags( available_features );
        foreach( i; 0 .. enabled.length )
            if( requested[ i ] && available[ i ] )
                enabled[ i ] = VK_TRUE;

        // one queue per distinct family, requests sharing a family share its queue with the highest requested priority
        auto queue_family_properties = vk.gpu.listQueues( false );
        Dynamic_Array!Queue_Family queue_families;
        foreach( r, family_index; queue_request_families.data ) {
            float priority = queue_requests[ r ].priority;
            bool  found    = false;
            foreach( ref queue_family; queue_families.data ) {
                if( queue_family.family_index == family_index ) {
                    if( queue_family.priority( 0 ) < priority )
                        queue_family.priority( 0 ) = priority;
                    found = true;
                    break;
                }
            }
            if( !found ) {
                auto queue_family = queue_families.append( Queue_Family( family_index, queue_family_properties[ family_index ] ));
                queue_family.queueCount = 1;
                queue_family.priority( 0 ) = priority;
            }
        }

        vk.initDevice( queue_families.data, device_extensions.data, & enabled_features, file, line, func );
        if( vk.device.is_null )
            return VK_ERROR_INITIALIZATION_FAILED;

        // hand out the requested queues and family indices
        foreach( r, ref request; queue_requests.data ) {
            if( request.queue !is null )
                vkGetDeviceQueue( vk.device, queue_request_families[ r ], 0, request.queue );
            if( request.family_index !is null )
                *request.family_index = queue_request_families[ r ];
        }

        // gather the flags of all requests sharing the queue of the first present request
        present_queue_flags = 0;
        foreach( p, ref present_request; queue_requests.data ) {
            if( present_request.present_surface.is_null )
                continue;
            foreach( r, ref request; queue_requests.data )
                if( queue_request_families[ r ] == queue_request_families[ p ] )
                    present_queue_flags |= request.include_flags;
            break;
        }

        if( verbose_init ) {
            VkPhysicalDeviceProperties gpu_properties;
            vkGetPhysicalDeviceProperties( vk.gpu, & gpu_properties );
            println;
            printf( "Device initialized on %s\n", gpu_properties.deviceName.ptr );
            printf( "====================\n" );
        }
        return VK_SUCCESS;
    }


    // check device extensions, required features and queue requests of a gpu
    private bool isSuitable( VkPhysicalDevice gpu, bool verbose ) {
        VkPhysicalDeviceProperties gpu_properties;
        vkGetPhysicalDeviceProperties( gpu, & gpu_properties );

        foreach( extension; device_extensions.data ) {
            if( !gpu.isDeviceExtension( extension, false )) {
                if( verbose ) printf( "GPU %s skipped, extension %s not available\n", gpu_properties.deviceName.ptr, extension );
                return false;
            }
        }

        auto available_features = gpu.listFeatures( false );
        auto required  = featureFlags( required_features );
        auto available = featureFlags( available_features );
        foreach( i; 0 .. required.length ) {
            if( required[ i ] && !available[ i ] ) {
                if( verbose ) printf( "GPU %s skipped, a required feature is not available\n", gpu_properties.deviceName.ptr );
                return false;
            }
        }

        if( !resolveQueueFamilies( gpu )) {
            if( verbose ) printf( "GPU %s skipped, requested queues not available\n", gpu_properties.deviceName.ptr );
            return false;
        }

        if( verbose ) printf( "GPU %s meets the device requirements\n", gpu_properties.deviceName.ptr );
        return true;
    }


    // resolve each queue request to a queue family index of gpu, stored in queue_request_families
    // a family which is used by a resolved request or satisfies more of the unresolved requests is preferred,
    // so that requests share families, a family used by a request matching the share_preference is preferred most
    // returns false if any request cannot be satisfied
    private bool resolveQueueFamilies( VkPhysicalDevice gpu ) {
        auto queue_family_properties = gpu.listQueues( false );

        bool satisfies( ref Queue_Request request, uint32_t family_index ) {
            auto flags = queue_family_properties[ family_index ].queueFlags;
            if(( flags & request.include_flags ) != request.include_flags )
                return false;
            if( flags & request.exclude_flags )
                return false;
            if( !request.present_surface.is_null ) {
                VkBool32 present_supported;
                vkGetPhysicalDeviceSurfaceSupportKHR( gpu, family_index, request.present_surface, & present_supported );
                if( !present_supported )
                    return false;
            }
            return true;
        }

        enum uint32_t unresolved = uint32_t.max;
        int request_count = queue_requests.length.toInt;

        queue_request_families.length = queue_requests.length;
        foreach( ref family_index; queue_request_families.data )
            family_index = unresolved;

        // requests with a share_preference are resolved in the second pass, when the requests they prefer are resolved
        foreach( pass; 0 .. 2 ) {
            foreach( r, ref request; queue_requests.data ) {
                if(( request.share_preference != 0 ) != ( pass == 1 ))
                    continue;

                int best_score = -1;
                foreach( f; 0 .. queue_family_properties.length ) {
                    uint32_t family_index = f.toUint32;
                    if( !satisfies( request, family_index ))
                        continue;

                    // sharing with a resolved request outweighs any count of unresolved requests, sharing with a preferred one doubly
                    int score = 0;
                    int share_score = 0;
                    foreach( o, other_family_index; queue_request_families.data ) {
                        if( other_family_index == unresolved ) {
                            if( o != r && satisfies( queue_requests[ o ], family_index ))
                                ++score;
                        } else if( other_family_index == family_index ) {
                            int s = ( queue_requests[ o ].include_flags & request.share_preference ) ? 2 * request_count : request_count;
                            if( share_score < s )
                                share_score = s;
                        }
                    }
                    score += share_score;

                    if( score > best_score ) {
                        best_score = score;
                        queue_request_families[ r ] = family_index;
                    }
                }
                if( best_score < 0 )
                    return false;
            }
        }
        return true;
    }
}


// view a VkPhysicalDeviceFeatures as array of its VkBool32 members
private VkBool32[] featureFlags( return ref VkPhysicalDeviceFeatures features ) {
    return ( cast( VkBool32* )( & features ))[ 0 .. VkPhysicalDeviceFeatures.sizeof / VkBool32.sizeof ];
}

// lower rank is preferred when collecting gpus
private int gpuTypeRank( VkPhysicalDevice gpu ) {
    VkPhysicalDeviceProperties gpu_properties;
    vkGetPhysicalDeviceProperties( gpu, & gpu_properties );
    switch( gpu_properties.deviceType ) {
        case VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU   : return 0;
        case VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU : return 1;
        case VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU    : return 2;
        case VK_PHYSICAL_DEVICE_TYPE_CPU            : return 3;
        default                                     : return 4;
    }
}

// check if a list of zero terminated strings contains name
private bool containsName( string_z[] names, string_z name ) {
    foreach( n; names )
        if( n.isEqual( name ))
            return true;
    return false;
}