/*
* Vulkan Example - Basic non-indexed triangle rendering
*
* Note:
*   This is a "pedal to the metal" example to show off how to get Vulkan up an displaying something
*   It strongly relies on the concepts and abstractions of the V-Drive api
*   However, in these example only basic features are used, heavier once will be introduced in later examples
*
* Example Structure:
*   appstate    : the struct VDrive_State holds the state of the application, vulkan non- and related data
*   triangle    : initializes all the required Vulkan non- and related data
*   main        : this module has the render loop and polls glfw events
*
* Common Structure ( to all examples, can be overridden on per example basis ):
*   initialize  : initialize glfw, window, vulkan instance, device and queue(s)
*   input       : setup glfw callbacks
*
* Navigation and keys:
*   LMB + mouse move    : orbit around camera target
*   MMB + mouse move    : pan the camera, speed is dependent on camera to target distance
*   RMB + mouse u/d     : fast dolly ( camera move towards its target )
*   RMB + mouse r/l     : slow dolly
*   ALT + KP Enter      : toggle fullscreen
*   Home Key            : return to initial camera state
*   Escape              : exit example
*
* Build and Run:
*   library and examples work only on x64 architecture due to dlang VK_NULL_HANDLE issue
*   dub run vdrive:triangle --arch x86_64
*
* Copyright (C) 2017 by Peter Particle, inspired by Sascha Willems Vulkan examples - www.saschawillems.de
*
* This code is licensed under the MIT license (MIT) (http://opensource.org/licenses/MIT)
*/

module main;

import erupted;
import vdrive;

import core.stdc.stdio : printf, sprintf;

int main() {

    printf( "\n" );

    verbose = true;

    // load global level functions 
    DerelictErupted.load();

    listExtensions;
    listLayers;




/*
    // first load all global level instance functions
    loadGlobalLevelFunctions( cast( typeof( vkGetInstanceProcAddr ))
        glfwGetInstanceProcAddress( null, "vkGetInstanceProcAddr" ));


    // get some useful info from the instance

    //"VK_LAYER_LUNARG_standard_validation".isLayer;


    // get vulkan extensions which are required by glfw
    uint32_t extension_count;
    auto glfw_required_extensions = glfwGetRequiredInstanceExtensions( &extension_count );


    // we know that glfw requires only two extensions
    // however we create storage for more of them, as we will add some extensions our self
    const( char )*[8] extensions;
    extensions[ 0..extension_count ] = glfw_required_extensions[ 0..extension_count ];


    debug {
        // we would like to use the debug report callback functionality
        extensions[ extension_count ] = "VK_EXT_debug_report";
        ++extension_count;

        // and report standard validation issues
        const( char )*[1] layers = [ "VK_LAYER_LUNARG_standard_validation" ];
    } else {
        const( char )*[0] layers;
    }


    // check if all of the extensions are available, exit if not
    foreach( extension; extensions[ 0..extension_count ] ) {
        if( !extension.isExtension( false )) {
            printf( "Required extension %s not available. Exiting!\n", extension );
            return VK_ERROR_INITIALIZATION_FAILED;
        }
    }


    // check if all of the layers are available, exit if not
    foreach( layer; layers ) {
        if( !layer.isLayer( false )) {
            printf( "Required layers %s not available. Exiting!\n", layer );
            return VK_ERROR_INITIALIZATION_FAILED;
        }
    }
*/

    // initialize the vulkan instance, pass the correct slice into the extension array
    //vk.initInstance( extensions[ 0..extension_count ], layers );

    Vulkan vk;
    vk.initInstance;

    // check if any device supporting vulkan is available
    uint32_t device_count;
    vk.instance.vkEnumeratePhysicalDevices( & device_count, null ).vkAssert( "Ennumerate Physical Devices" );

    printf( "Found %d physical devices supporting Vulka\n\n", device_count );

    if( device_count == 0 ) {
        printf( "\nPress enter to exit!!!\n" );
        char input;
        import std.stdio : readf;
        readf( "%s", & input );
    }


    // enumerate gpus
    auto gpus = vk.instance.listPhysicalDevices( false );


    // get some useful info from the physical devices
    foreach( ref gpu; gpus ) {
        //gpu.listProperties;
        //gpu.listProperties( GPU_Info.properties );
        //gpu.listProperties( GPU_Info.limits );
        //gpu.listProperties( GPU_Info.sparse_properties );
        gpu.listProperties( GPU_Info.properties | GPU_Info.limits | GPU_Info.sparse_properties );
        gpu.listFeatures;
        gpu.listLayers;
        gpu.listExtensions;
        //printf( "Present supported: %u\n", gpu.presentSupport( vk.surface ));

        listQueueFamilies( gpu /*, false, vk.surface.surface*/ );
    }

/*
    // set the desired gpu into the state object
    // Todo(pp): find a suitable "best fit" gpu
    // - gpu must support the VK_KHR_swapchain extension
    bool presentation_supported = false;
    foreach( ref gpu; gpus ) {
        if( gpu.presentSupport( vk.surface.surface )) {
            presentation_supported = true;
            vk.gpu = gpu;
            break;
        }
    }
    
    // Presentation capability is required for this example, terminate if not available
    if( !presentation_supported ) {
        // Todo(pp): print to error stream 
        printf( "No GPU with presentation capability detected. Terminating!" );
        vk.destroyInstance;
        return VK_ERROR_INITIALIZATION_FAILED;
    }

    // if presentation is supported on that gpu the gpu extension VK_KHR_swapchain must be available 
    const( char )*[1] deviceExtensions = [ "VK_KHR_swapchain" ];
*/
/+
    // Todo(pp): the filtering bellow is not lazy and also allocates, change both to lazy range based
    auto queue_families = listQueueFamilies( vk.gpu /*, false, vk.surface.surface*/ );   // last param is optional and only for printing
    auto graphic_queues = queue_families
        .filterQueueFlags( VK_QUEUE_GRAPHICS_BIT );                  // .filterQueueFlags( include, exclude ) 
//        .filterPresentSupport( vk.gpu, vk.surface.surface );        // .filterPresentSupport( gpu, surface )


    // treat the case of combined graphics and presentation queue first
    if( graphic_queues.length > 0 ) {
        Queue_Family[1] filtered_queues = graphic_queues.front;
        filtered_queues[0].queueCount = 1;
        filtered_queues[0].priority( 0 ) = 1;

        // initialize the logical device
        vk.initDevice( filtered_queues/*, deviceExtensions, layers*/ );

        // get graphics queue
        VkQueue vk_queue;
        vk.device.vkGetDeviceQueue( filtered_queues[0].family_index, 0, &vk_queue );
        //vk.device.vkGetDeviceQueue( filtered_queues[0].family_index, 0, &vk.surface.present_queue );

        // store queue family index, required for command pool creation
        //vk.graphic_queue_family_index = filtered_queues[0].family_index;


    }+/ 
/*
    else {
        graphic_queues = queue_families.filterQueueFlags( VK_QUEUE_GRAPHICS_BIT );  // .filterQueueFlags( include, exclude )

        // a graphics queue is required for the example, terminate if not available
        if( graphic_queues.length == 0 ) {
            // Todo(pp): print to error stream
            printf( "No queue with VK_QUEUE_GRAPHICS_BIT found. Terminating!" );
            vk.destroyInstance;
            return VK_ERROR_INITIALIZATION_FAILED;
        }

        // We know that the gpu has presentation support and can present to the surface
        // take the first available presentation queue
        Queue_Family[2] filtered_queues = [
            graphic_queues.front,
            queue_families.filterPresentSupport( vk.gpu, vk.surface.surface ).front // .filterPresentSupport( gpu, surface
        ];

        // initialize the logical device
        vk.initDevice( filtered_queues, deviceExtensions, layers );

        // get device queues
        vk.device.vkGetDeviceQueue( filtered_queues[0].family_index, 0, &vk.graphic_queue );
        vk.device.vkGetDeviceQueue( filtered_queues[1].family_index, 0, &vk.surface.present_queue );

        // store queue family index, required for command pool creation
        // family_index of presentation queue seems not to be required later on
        vk.graphic_queue_family_index = filtered_queues[0].family_index;
    }
*/


    printf( "\nPress enter to exit!!!\n" );

    char input;
    import std.stdio : readf;
    readf( "%s", & input );

//    vk.device.vkDeviceWaitIdle;
//    vk.destroyDevice;

//  debug vk.destroy( vk.debugReportCallback );
    vk.destroyInstance;

    return 0;
}
