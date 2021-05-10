module vdrive.state;

import core.stdc.stdio : printf;

import vdrive.util;

import erupted;


nothrow @nogc:


mixin template Vulkan_State_Pointer() {
    nothrow @nogc:
    private Vulkan*         vk_ptr;
    alias                   vk this;

    this( ref Vulkan vk )               { vk_ptr = & vk; }
    ref Vulkan vk()                     { return * vk_ptr; }
    void vk( ref Vulkan vk )            { vk_ptr = & vk; }
    auto ref opCall( ref Vulkan vk )    { vk_ptr = & vk; return this; }
    bool isValid()                      { return vk_ptr !is null; }
}


// Todo(pp): rename to Core_Context, rename as well occurrences of: ///     vk = reference to a VulkanState struct
struct Vulkan {
    nothrow @nogc:
    const( VkAllocationCallbacks )* allocator = null;
    VkInstance                      instance = VK_NULL_HANDLE;
    VkDevice                        device = VK_NULL_HANDLE;
    VkPhysicalDevice                gpu = VK_NULL_HANDLE;

    VkDebugUtilsMessengerEXT        debug_utils_messenger = VK_NULL_HANDLE;
    VkDebugReportCallbackEXT        debug_report_callback = VK_NULL_HANDLE;

    import vdrive.util.array;
    Arena_Array                     scratch;

    // get the memory properties of the this gpu
    // Todo(pp): the memory properties print uints instead of enum flags, fix this
    VkPhysicalDeviceMemoryProperties    memory_properties() {
        vkAssert( !gpu.is_null );
        import vdrive.memory : memoryProperties;
        return gpu.memoryProperties;
    }
}

template isVulkan( T ) { enum isVulkan = is( T == Vulkan ); }


deprecated( "Scratch_Result struct template is not necessary, as we now rely on zero copy RVO." ) {
    /// this struct is not in util.util to avoid dependency on state
    struct Scratch_Result( Result_T ) {
        nothrow @nogc:
        private Vulkan* vk_ptr;
        alias           array this;
        alias           Array_T = Block_Array!Result_T;


        nothrow @nogc:
        Array_T         array;
        @disable        this();
        @disable        this( this );

        ref Vulkan vk()         { return * vk_ptr; }
        bool isValid()          { return vk_ptr !is null; }

        this( ref Vulkan vk, size_t count = 0 ) {
            vk_ptr = & vk;
            array = Array_T( vk.scratch );
            if( count > 0 ) {
                array.reserve( count );         // first reserve
                array.length(  count, true );   // then resize to the same size, to no eagerly over allocate
            }
        }
    }

    template isScratchResult( T ) { enum isScratchResult = is( typeof( isScratchResultImpl( T.init ))); }
    private void isScratchResultImpl( R )( Scratch_Result!R result ) {}
}



void destroyInstance( ref Vulkan vk ) {
    vkDestroyInstance( vk.instance, vk.allocator );
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
void destroyHandle( ref Vulkan vk, ref VkSemaphore            handle )    { vkDestroySemaphore(           vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkFence                handle )    { vkDestroyFence(               vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkDeviceMemory         handle )    { vkFreeMemory(                 vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkBuffer               handle )    { vkDestroyBuffer(              vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkImage                handle )    { vkDestroyImage(               vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkEvent                handle )    { vkDestroyEvent(               vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkQueryPool            handle )    { vkDestroyQueryPool(           vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkBufferView           handle )    { vkDestroyBufferView(          vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkImageView            handle )    { vkDestroyImageView(           vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkShaderModule         handle )    { vkDestroyShaderModule(        vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkPipelineCache        handle )    { vkDestroyPipelineCache(       vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkPipelineLayout       handle )    { vkDestroyPipelineLayout(      vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkRenderPass           handle )    { vkDestroyRenderPass(          vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkPipeline             handle )    { vkDestroyPipeline(            vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkDescriptorSetLayout  handle )    { vkDestroyDescriptorSetLayout( vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkSampler              handle )    { vkDestroySampler(             vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkDescriptorPool       handle )    { vkDestroyDescriptorPool(      vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkFramebuffer          handle )    { vkDestroyFramebuffer(         vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkCommandPool          handle )    { vkDestroyCommandPool(         vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }

// extension specific destroyHandle functions
void destroyHandle( ref Vulkan vk, ref VkSurfaceKHR           handle )    { vkDestroySurfaceKHR(        vk.instance, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkSwapchainKHR         handle )    { vkDestroySwapchainKHR(        vk.device, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
//VkDisplayKHR
//VkDisplayModeKHR
//VkDescriptorUpdateTemplateKHR
void destroyHandle( ref Vulkan vk, ref VkDebugReportCallbackEXT handle )  { vkDestroyDebugReportCallbackEXT( vk.instance, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
void destroyHandle( ref Vulkan vk, ref VkDebugUtilsMessengerEXT handle )  { vkDestroyDebugUtilsMessengerEXT( vk.instance, handle, vk.allocator ); handle = VK_NULL_HANDLE; }
//VkObjectTableNVX
//VkIndirectCommandsLayoutNVX

alias destroy = destroyHandle;

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
    ||  is( T == VkDebugUtilsMessengerEXT )
    ) {
        enum bool is_non_dispatch_handle = true;
    } else {
        enum bool is_non_dispatch_handle = false;
    }
}


template is_handle( T ) { enum bool is_handle = is_dispatch_handle!T || is_non_dispatch_handle!T; }

T resetHandle( T )( ref T handle ) if( is_handle !T ) { T result = handle; handle = VK_NULL_HANDLE; return result; }

alias   is_null = is_null_handle;
bool    is_null_handle( T )( T handle ) if( is_handle!T ) { return handle == VK_NULL_HANDLE; }
