module vdrive.buffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.memory;

import erupted;



///////////////////////////////////////
// Meta_Buffer and related functions //
///////////////////////////////////////

/// struct to capture buffer and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct
/// Here we have a distinction between bufferSize, which is the (requested) size of the VkBuffer
/// and memSeize, which is the size of the memory range attached to the VkBuffer
/// They might differ based on memory granularity and alignment, but both should be safe for memory mapping
struct Meta_Buffer {
    mixin                   Vulkan_State_Pointer;
    VkBuffer                buffer;
    VkBufferCreateInfo      buffer_ci;
    VkDeviceSize            bufferSize() { return buffer_ci.size; }
    mixin                   Memory_Member;
    mixin                   Memory_Buffer_Image_Common;
    version( DEBUG_NAME )   string name;


    // bulk destroy the resources belonging to this meta struct
    void destroyResources() {
        vk.destroy( buffer );
        if( owns_device_memory )
            vk.destroy( device_memory );
        resetMemoryMember;
    }


    /// Specify buffer usage
    auto ref usage( VkBufferUsageFlags buffer_usage_flags ) {
        buffer_ci.usage = buffer_usage_flags;
        return this;
    }


    /// Add buffer usage. The added usage will be or-ed with the existing one.
    auto ref addUsage( VkBufferUsageFlags buffer_usage_flags ) {
        buffer_ci.usage |= buffer_usage_flags;
        return this;
    }


    /// Specify buffer size.
    auto ref bufferSize( VkBufferUsageFlags buffer_size ) {
        buffer_ci.size = buffer_size;
        return this;
    }


    /// Specify the sharing queue families and implicitly the sharing mode, which defaults to VK_SHARING_MODE_EXCLUSIVE.
    auto ref sharingQueueFamilyIndices( uint32_t[] sharing_family_queue_indices ) {
        buffer_ci.sharingMode           = VK_SHARING_MODE_CONCURRENT;
        buffer_ci.queueFamilyIndexCount = sharing_family_queue_indices.length.toUint;
        buffer_ci.pQueueFamilyIndices   = sharing_family_queue_indices.ptr;
    }


    /// Construct the Image from specified data.
    auto ref construct( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );

        vk.device.vkCreateBuffer( & buffer_ci, allocator, & buffer ).vkAssert( "Construct Buffer", file, line, func );
        vk.device.vkGetBufferMemoryRequirements( buffer, & memory_requirements );

        return this;
    }


    /// initialize a VkBuffer object, this function or createBuffer must be called first, further operations require the buffer
    /// the resulting buffer and its create info are stored in the Meta_Buffer struct
    /// the Meta_Buffer struct is returned for function chaining
    auto ref construct(
        VkBufferUsageFlags  buffer_usage_flags,
        VkDeviceSize        buffer_size,
        uint32_t[]          sharing_family_queue_indices = [],
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__

        ) {

        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );

        // buffer create info from arguments
        buffer_ci.size                  = buffer_size; // size in Bytes
        buffer_ci.usage                 = buffer_usage_flags;
        buffer_ci.sharingMode           = sharing_family_queue_indices == [] ? VK_SHARING_MODE_EXCLUSIVE : VK_SHARING_MODE_CONCURRENT;
        buffer_ci.queueFamilyIndexCount = sharing_family_queue_indices.length.toUint;
        buffer_ci.pQueueFamilyIndices   = sharing_family_queue_indices.ptr;

        vk.device.vkCreateBuffer( & buffer_ci, allocator, & buffer ).vkAssert( "Construct Buffer", file, line, func );
        vk.device.vkGetBufferMemoryRequirements( buffer, & memory_requirements );

        return this;
    }
}



deprecated( "Use member methods to edit and/or Meta_Buffer.construct instead" ) {

    /// initialize a VkBuffer object, this function or createBuffer must be called first, further operations require the buffer
    /// the resulting buffer and its create info are stored in the Meta_Buffer struct
    /// the Meta_Buffer struct is returned for function chaining
    auto ref initBuffer(
        ref Meta_Buffer     meta,
        VkBufferUsageFlags  usage,
        VkDeviceSize        size,
        uint32_t[]          sharing_family_queue_indices = [],
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__
        ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );

        // buffer create info from arguments
        meta.buffer_ci.size                  = size; // size in Bytes
        meta.buffer_ci.usage                 = usage;
        meta.buffer_ci.sharingMode           = sharing_family_queue_indices == [] ? VK_SHARING_MODE_EXCLUSIVE : VK_SHARING_MODE_CONCURRENT;
        meta.buffer_ci.queueFamilyIndexCount = sharing_family_queue_indices.length.toUint;
        meta.buffer_ci.pQueueFamilyIndices   = sharing_family_queue_indices.ptr;

        meta.device.vkCreateBuffer( & meta.buffer_ci, meta.allocator, & meta.buffer ).vkAssert( "Init Buffer", file, line, func );
        meta.device.vkGetBufferMemoryRequirements( meta.buffer, & meta.memory_requirements );

        return meta;
    }

    //alias create = initBuffer;


    /// create a VkBuffer object, this function or initBuffer (or its alias create) must be called first, further operations require the buffer
    /// the resulting buffer and its create info are stored in the Meta_Buffer struct
    /// the Meta_Buffer struct is returned for function chaining
    auto createBuffer( ref Vulkan vk, VkBufferUsageFlags usage, VkDeviceSize size, uint32_t[] sharing_family_queue_indices = [] ) {
        Meta_Buffer meta = vk;
        meta.construct( usage, size, sharing_family_queue_indices );
        return meta;
    }
}
