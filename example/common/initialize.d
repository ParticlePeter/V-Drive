//module initialize;

import erupted;
import bindbc.glfw;

import core.stdc.stdio : printf;

import vdrive.state;
import vdrive.swapchain;
import vdrive.initializer;
import vdrive.util.info;
import vdrive.util.util;
import vdrive.util.array;


import appstate;


// mixin vulkan related glfw functions
// with this approach the erupted types can be used as params for the functions
mixin( bindGLFW_Vulkan );


// Todo(pp): if initialization fails an error should be returned
// program termination would than happen gracefully in module main
// pass Vulkan struct as reference parameter into this function
VkResult initVulkan(
    ref App_State               app,
    uint32_t                    win_w = 1600,
    uint32_t                    win_h = 900,
    VkPhysicalDeviceFeatures*   features = null,
    bool                        validate_vulkan = true,
    bool                        verbose = false

    ) {

    // Initialize GLFW3 and Vulkan related glfw functions
    version( Windows )
        loadGLFW( "external/lib/glfw3_x64.dll" );           // load the lib in this repo
    else
        loadGLFW();                                         // load default system lib othervise, must be 64 bit
    loadGLFW_Vulkan;                                        // load vulkan specific glfw function pointers
    glfwInit();                                             // initialize glfw


    // set glfw window attributes and store it in the App_State appstate
    glfwWindowHint( GLFW_CLIENT_API, GLFW_NO_API );
    app.window = glfwCreateWindow( win_w, win_h, "Vulkan Erupted", null, null );


    // first load all global level instance functions

    // glwf3 way
    //loadGlobalLevelFunctions( cast( PFN_vkGetInstanceProcAddr )
    //glfwGetInstanceProcAddress( null, "vkGetInstanceProcAddr" ));

    // ErupteD way
    import erupted.vulkan_lib_loader;
    loadGlobalLevelFunctions;


    // get some useful info from the instance
    //listExtensions;
    //listLayers;
    //"VK_LAYER_LUNARG_standard_validation".isLayer;


    // get vulkan extensions which are required by glfw
    uint32_t extension_count;
    auto glfw_required_extensions = glfwGetRequiredInstanceExtensions( & extension_count );

    // initialize Vulkan Instance
    auto meta_init = Meta_Init( app );  // we will require some setup date for later use
    VkResult result = meta_init
        .validateVulkan( validate_vulkan )
        .addInstanceExtensions( glfw_required_extensions[ 0 .. extension_count ] )
        .addInstanceLayer( "VK_LAYER_KHRONOS_validation" )
        .setDebugUtilsSeverityFlags( 0
            | VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT
            | VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
        //  | VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT
        //  | VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT
        )
        .setDebugUtilsTypeFlags( 0
            | VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT
            | VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
            | VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
        )
        .initInstance;

    // create the window VkSurfaceKHR with the instance, surface is stored in the state object
    import vdrive.swapchain;
    glfwCreateWindowSurface( app.instance, app.window, app.allocator, & app.swapchain.surface ).vkAssert;
    app.swapchain.image_extent = VkExtent2D( win_w, win_h );     // Set the desired swapchain extent, this might change at swapchain creation


    // initialize the device on the best fitting gpu which can render and present to the surface
    // graphics and present requests share a queue if one family supports both, VK_KHR_swapchain is added implicitly
    if( features !is null )
        meta_init.requireFeatures( * features );       // gpus without these features are skipped

    result = meta_init
        .addQueue( VK_QUEUE_GRAPHICS_BIT, & app.graphics_queue, & app.graphics_queue_family_index )
        .addPresentQueue( app.swapchain.surface, & app.swapchain.present_queue )
        .initDevice( 0, verbose );

    if( result != VK_SUCCESS ) {
        printf( "No GPU with graphics and presentation capability detected. Terminating!" );
        app.destroyInstance;
        return result;
    }

    return VK_SUCCESS;
}



void destroyVulkan( ref App_State app ) {

    app.device.vkDeviceWaitIdle;
    app.destroyDevice;

    if(!app.debug_report_callback.is_null )
        app.destroy( app.debug_report_callback );

    if(!app.debug_utils_messenger.is_null )
        app.destroy( app.debug_utils_messenger );

    app.destroyInstance;

    glfwDestroyWindow( app.window );
    glfwTerminate();
}
