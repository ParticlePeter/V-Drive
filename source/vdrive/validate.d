module vdrive.validate;

import erupted;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;


nothrow @nogc:


// debug report function called by the VK_EXT_debug_utils mechanism
extern( System ) VkBool32 debug_messenger(
    VkDebugUtilsMessageSeverityFlagBitsEXT          message_severity,
    VkDebugUtilsMessageTypeFlagsEXT                 message_type,
    const VkDebugUtilsMessengerCallbackDataEXT*     callback_data,
    void*                                           user_data,

    ) nothrow @nogc {

    auto scratch = cast( Arena_Array* )user_data;
    auto stringz = Block_Array!char( *scratch );

    println;
    printf( "Debug Messenger Arguments\n" );
    printf( "-------------------------\n" );
    printf( "Message Severity   : %s\n", message_severity.toStringz( stringz ).ptr );
    printf( "Message Type       : %s\n", toStringz( cast( VkDebugUtilsMessageTypeFlagBitsEXT )message_type, stringz ).ptr );

    println;
    printf( "Callback Data\n" );
    printf( "-------------\n" );
    printf( "Message Id Name    : %s\n", callback_data.pMessageIdName );
    printf( "Valid Usage ID     : %i\n", callback_data.messageIdNumber );
    //const( char )*          pMessage;     // last being printed

    printf( "Queue Label Count  : %u\n", callback_data.queueLabelCount );
    //VkDebugUtilsLabelEXT*   pQueueLabels;


    printf( "CmdBuf Label Count : %u\n", callback_data.cmdBufLabelCount );
    //VkDebugUtilsLabelEXT*   pCmdBufLabels;


    foreach( i, ref object; callback_data.pObjects[ 0 .. callback_data.objectCount ] ) {
        println;
        printf( "\tObject %llu\n", i );
        printf( "\tObject Type        : %s\n",   object.objectType.toStringz( stringz ).ptr );
        printf( "\tObject Handle      : %llu\n", object.objectHandle );
        printf( "\tObject Name        : %s\n",   object.pObjectName );
    }

    println;
    printf( "Message\n" );
    printf( "-------\n" );
    printf( callback_data.pMessage );
    printf( "\n\n\n" );

    return VK_FALSE;
}



void createDebugMessenger(
    ref Vulkan                              vk,
    VkDebugUtilsMessageSeverityFlagsEXT     message_severity,
    VkDebugUtilsMessageTypeFlagsEXT         message_type,
    string                                  file = __FILE__,
    size_t                                  line = __LINE__,
    string                                  func = __FUNCTION__

    ) {

    createDebugMessenger( vk, message_severity, message_type, & debug_messenger, & vk.scratch, file, line, func );
}



void createDebugMessenger(
    ref Vulkan                              vk,
    VkDebugUtilsMessageSeverityFlagsEXT     message_severity,
    VkDebugUtilsMessageTypeFlagsEXT         message_type,
    PFN_vkDebugUtilsMessengerCallbackEXT    pfn_user_callback,
    void*                                   user_data,
    string                                  file = __FILE__,
    size_t                                  line = __LINE__,
    string                                  func = __FUNCTION__

    ) {

    VkDebugUtilsMessengerCreateInfoEXT messenger_ci = {
        messageSeverity : message_severity,
        messageType     : message_type,
        pfnUserCallback : pfn_user_callback,
        pUserData       : user_data,
    };
    vkCreateDebugUtilsMessengerEXT( vk.instance, & messenger_ci, vk.allocator, & vk.debug_utils_messenger )
        .vkAssert( "Debug Utils Messenger Callback", file, line, func );
}



// debug report function called by the VK_EXT_debug_report mechanism
extern( System ) VkBool32 debug_report(
    VkDebugReportFlagsEXT       flags,
    VkDebugReportObjectTypeEXT  objectType,
    uint64_t                    object,
    size_t                      location,
    int32_t                     messageCode,
    const( char )*              pLayerPrefix,
    const( char )*              pMessage,
    void*                       pUserData

    ) nothrow @nogc {

    auto scratch = cast( Arena_Array* )pUserData;
    auto stringz = Block_Array!char( *scratch );

    printf( "Report Flags : %s\n", toStringz( cast( VkDebugReportFlagBitsEXT )flags, stringz ).ptr );
    printf( "Object Type  : %s\n", toStringz( objectType, stringz ).ptr );
    printf( "Object       : %llu\n", object );
    printf( "Message Code : %i\n", messageCode );
    printf( "Layer Prefix : %s\n", pLayerPrefix );
    printf( "Message      : %s\n\n", pMessage );

    return VK_FALSE;
}



void setDebugName(
    ref Vulkan      vk,
    VkObjectType    object_type,
    uint64_t        object_handle,
    const( char )*  object_name,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) {
    VkDebugUtilsObjectNameInfoEXT debug_utils_object_name_info = {
        objectType      : object_type,
        objectHandle    : object_handle,
        pObjectName     : object_name,
    };

    vk.device.vkSetDebugUtilsObjectNameEXT( & debug_utils_object_name_info ).vkAssert( "Debug Name", file, line, func, object_name );
}


void setDebugName( T )(
    ref Vulkan      vk,
    const ref T     handle,
    const( char )*  object_name,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) {
    setDebugName( vk, handle.objectType, handle.toUint64, object_name, file, line, func );
}




/*
VkObjectType objectType( ref VkUnknown                          handle ) { return VK_OBJECT_TYPE_UNKNOWN; }                 // for obvious reasons
VkObjectType objectType( ref VkDeferredOperationKHR             handle ) { return VK_OBJECT_TYPE_DEFERRED_OPERATION_KHR; }  // currently part of experimental platform (!) and can be defined only by end user
*/
VkObjectType objectType( const ref VkInstance                       handle ) { return VK_OBJECT_TYPE_INSTANCE; }
VkObjectType objectType( const ref VkPhysicalDevice                 handle ) { return VK_OBJECT_TYPE_PHYSICAL_DEVICE; }
VkObjectType objectType( const ref VkDevice                         handle ) { return VK_OBJECT_TYPE_DEVICE; }
VkObjectType objectType( const ref VkQueue                          handle ) { return VK_OBJECT_TYPE_QUEUE; }
VkObjectType objectType( const ref VkSemaphore                      handle ) { return VK_OBJECT_TYPE_SEMAPHORE; }
VkObjectType objectType( const ref VkCommandBuffer                  handle ) { return VK_OBJECT_TYPE_COMMAND_BUFFER; }
VkObjectType objectType( const ref VkFence                          handle ) { return VK_OBJECT_TYPE_FENCE; }
VkObjectType objectType( const ref VkDeviceMemory                   handle ) { return VK_OBJECT_TYPE_DEVICE_MEMORY; }
VkObjectType objectType( const ref VkBuffer                         handle ) { return VK_OBJECT_TYPE_BUFFER; }
VkObjectType objectType( const ref VkImage                          handle ) { return VK_OBJECT_TYPE_IMAGE; }
VkObjectType objectType( const ref VkEvent                          handle ) { return VK_OBJECT_TYPE_EVENT; }
VkObjectType objectType( const ref VkQueryPool                      handle ) { return VK_OBJECT_TYPE_QUERY_POOL; }
VkObjectType objectType( const ref VkBufferView                     handle ) { return VK_OBJECT_TYPE_BUFFER_VIEW; }
VkObjectType objectType( const ref VkImageView                      handle ) { return VK_OBJECT_TYPE_IMAGE_VIEW; }
VkObjectType objectType( const ref VkShaderModule                   handle ) { return VK_OBJECT_TYPE_SHADER_MODULE; }
VkObjectType objectType( const ref VkPipelineCache                  handle ) { return VK_OBJECT_TYPE_PIPELINE_CACHE; }
VkObjectType objectType( const ref VkPipelineLayout                 handle ) { return VK_OBJECT_TYPE_PIPELINE_LAYOUT; }
VkObjectType objectType( const ref VkRenderPass                     handle ) { return VK_OBJECT_TYPE_RENDER_PASS; }
VkObjectType objectType( const ref VkPipeline                       handle ) { return VK_OBJECT_TYPE_PIPELINE; }
VkObjectType objectType( const ref VkDescriptorSetLayout            handle ) { return VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT; }
VkObjectType objectType( const ref VkSampler                        handle ) { return VK_OBJECT_TYPE_SAMPLER; }
VkObjectType objectType( const ref VkDescriptorPool                 handle ) { return VK_OBJECT_TYPE_DESCRIPTOR_POOL; }
VkObjectType objectType( const ref VkDescriptorSet                  handle ) { return VK_OBJECT_TYPE_DESCRIPTOR_SET; }
VkObjectType objectType( const ref VkFramebuffer                    handle ) { return VK_OBJECT_TYPE_FRAMEBUFFER; }
VkObjectType objectType( const ref VkCommandPool                    handle ) { return VK_OBJECT_TYPE_COMMAND_POOL; }
VkObjectType objectType( const ref VkSamplerYcbcrConversion         handle ) { return VK_OBJECT_TYPE_SAMPLER_YCBCR_CONVERSION; }
VkObjectType objectType( const ref VkDescriptorUpdateTemplate       handle ) { return VK_OBJECT_TYPE_DESCRIPTOR_UPDATE_TEMPLATE; }
VkObjectType objectType( const ref VkSurfaceKHR                     handle ) { return VK_OBJECT_TYPE_SURFACE_KHR; }
VkObjectType objectType( const ref VkSwapchainKHR                   handle ) { return VK_OBJECT_TYPE_SWAPCHAIN_KHR; }
VkObjectType objectType( const ref VkDisplayKHR                     handle ) { return VK_OBJECT_TYPE_DISPLAY_KHR; }
VkObjectType objectType( const ref VkDisplayModeKHR                 handle ) { return VK_OBJECT_TYPE_DISPLAY_MODE_KHR; }
VkObjectType objectType( const ref VkDebugReportCallbackEXT         handle ) { return VK_OBJECT_TYPE_DEBUG_REPORT_CALLBACK_EXT; }
VkObjectType objectType( const ref VkDebugUtilsMessengerEXT         handle ) { return VK_OBJECT_TYPE_DEBUG_UTILS_MESSENGER_EXT; }
VkObjectType objectType( const ref VkAccelerationStructureKHR       handle ) { return VK_OBJECT_TYPE_ACCELERATION_STRUCTURE_KHR; }
VkObjectType objectType( const ref VkValidationCacheEXT             handle ) { return VK_OBJECT_TYPE_VALIDATION_CACHE_EXT; }
VkObjectType objectType( const ref VkPerformanceConfigurationINTEL  handle ) { return VK_OBJECT_TYPE_PERFORMANCE_CONFIGURATION_INTEL; }
VkObjectType objectType( const ref VkIndirectCommandsLayoutNV       handle ) { return VK_OBJECT_TYPE_INDIRECT_COMMANDS_LAYOUT_NV; }
