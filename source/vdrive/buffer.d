module vdrive.buffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.memory;

import erupted;



///////////////////////////////
// VkBuffer and VkBufferView //
///////////////////////////////



/// create a VkBuffer
/// Params:
///     vk      = reference to a VulkanState struct
///     size    = size of the buffer
///     usage   = usage of the buffer
///     queue_familly_indices = optional queu family indices, if length > 1
///                             sets sharingMode to VK_SHARING_MODE_CONCURRENT,
///                             specifies queueFamilyIndexCount and
///                             sets the pQueueFamilyIndices pointer
///     flags   = optional create flags of the buffer
/// Returns: VkBuffer
VkBuffer createBuffer(
    ref Vulkan              vk,
    VkDeviceSize            size,
    VkBufferUsageFlags      usage,
    const uint32_t[]        sharing_queue_family_indices = [],
    VkBufferCreateFlags     flags   = 0,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__

    ) {

    vkAssert( sharing_queue_family_indices.length != 1,
        "Length of sharing_queue_family_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)",
        file, line, func );

    VkBufferCreateInfo buffer_ci = {
        flags   : flags,
        size    : size,
        usage   : usage,
    };

    if( sharing_queue_family_indices.length > 1 ) {
        buffer_ci.sharingMode           = VK_SHARING_MODE_CONCURRENT;
        buffer_ci.queueFamilyIndexCount = sharing_queue_family_indices.length.toUint;
        buffer_ci.pQueueFamilyIndices   = sharing_queue_family_indices.ptr;
    }

    VkBuffer buffer;
    vk.device.vkCreateBuffer( & buffer_ci, vk.allocator, & buffer ).vkAssert( null, file, line, func );
    return buffer;
}


/// create a VkBuffer
/// Params:
///     vk      = reference to a VulkanState struct
///     flags   = create flags of the view
///     size    = size of the buffer
///     usage   = usage of the buffer
///     queue_familly_indices = optional queu family indices, if length > 1
///                             sets sharingMode to VK_SHARING_MODE_CONCURRENT,
///                             specifies queueFamilyIndexCount and
///                             sets the pQueueFamilyIndices pointer
/// Returns: VkBuffer
VkBuffer createBuffer(
    ref Vulkan              vk,
    VkBufferCreateFlags     flags,
    VkDeviceSize            size,
    VkBufferUsageFlags      usage,
    const uint32_t[]        queue_familly_indices = [],
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    return vk.createBuffer( size, usage, queue_familly_indices, flags );
}



/// create a VkBufferView which can be exclusively used as a descriptor
/// Params:
///     vk = reference to a VulkanState struct
///     buffer = for which the view will be created
///     format = of the view
///     offset = optional offset into the original buffer
///     range  = optional range of the view (starting at offset), VK_WHOLE_SIZE if not specified
///     flags  = create flags of the view
/// Returns: VkBufferView
VkBufferView createBufferView(
    ref Vulkan              vk,
    VkBuffer                buffer,
    VkFormat                format,
    VkDeviceSize            offset  = 0,
    VkDeviceSize            range   = VK_WHOLE_SIZE,
    VkBufferViewCreateFlags flags   = 0,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__

    ) {

    VkBufferViewCreateInfo buffer_view_ci = {
        flags   : flags,
        buffer  : buffer,
        format  : format,
        offset  : offset,
        range   : range,
    };

    VkBufferView buffer_view;
    vk.device.vkCreateBufferView( & buffer_view_ci, vk.allocator, & buffer_view ).vkAssert( null, file, line, func );
    return buffer_view;
}


/// create a VkBufferView which can be exclusively used as a descriptor
/// Params:
///     vk = reference to a VulkanState struct
///     flags  = create flags of the view
///     buffer = for which the view will be created
///     format = of the view
///     offset = optional offset into the original buffer
///     range  = optional range of the view (starting at offset), VK_WHOLE_SIZE if not specified
/// Returns: VkBufferView
VkBufferView createBufferView(
    ref Vulkan              vk,
    VkBuffer                buffer,
    VkBufferViewCreateFlags flags,
    VkFormat                format,
    VkDeviceSize            offset  = 0,
    VkDeviceSize            range   = VK_WHOLE_SIZE,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    return vk.createBufferView( buffer, format, offset, range, flags, file, line, func );
}



/////////////////////////////////
// Core_Buffer and Meta_Buffer //
/////////////////////////////////

alias BMC = Buffer_Member_Copy;
enum Buffer_Member_Copy : uint32_t {
    None        = 0,
    Memory      = 1,
    Offset      = 2,
    Size        = 4,
    Ptr         = 8,
    Mem_Range   = 16,
};


alias   Core_Buffer             = Core_Buffer_T!( 0 );
alias   Core_Buffer_View        = Core_Buffer_T!( 1 );
alias   Core_Buffer_Memory      = Core_Buffer_T!( 0, BMC.Memory );
alias   Core_Buffer_Memory_View = Core_Buffer_T!( 1, BMC.Memory );

alias   Core_Buffer_Memory_View_T( uint mc = 0 )    = Core_Buffer_T!(  1, BMC.Memory | mc );
alias   Core_Buffer_Memory_T( uint vc, uint mc = 0) = Core_Buffer_T!( vc, BMC.Memory | mc );

/// Wraps the essential Vulkan objects created with the editing procedure
/// of Meta_Image_T, all other internal structures are obsolete
/// after construction so that the Meta_Image_Sampler_T can be reused
/// after being reset.
struct  Core_Buffer_T( uint32_t view_count, uint32_t member_copies = BMC.None ) {
    alias vc = view_count;
    alias mc = member_copies;

    VkBuffer buffer;

         static if( vc == 1 )               VkBufferView                view;
    else static if( vc  > 1 )               VkBufferView[ vc ]          view;

    static if( mc & BMC.Mem_Range ) {
                                            VkMappedMemoryRange         mem_range;
        static if( mc & BMC.Memory )        ref VkDeviceMemory          memory() { return mem_range.memory; }
        static if( mc & BMC.Offset )        VkDeviceSize                offset() { return mem_range.offset; }
        static if( mc & BMC.Size )          VkDeviceSize                size()   { return mem_range.size; }
    } else {
        static if( mc & BMC.Memory )        VkDeviceMemory              memory;
        static if( mc & BMC.Offset )        VkDeviceSize                offset;
        static if( mc & BMC.Size )          VkDeviceSize                size;
    }

    static if( mc & BMC.Ptr )               void*                       ptr;

    /// Check if all Vulkan resources are null, not available for multi buffer view.
         static if( vc == 0 )               bool                        is_null() { return buffer.is_null_handle; }
    else static if( vc == 1 )               bool                        is_null() { return buffer.is_null_handle && view.is_null_handle; }
}


/// Bulk destroy the resources belonging to this meta struct.
void destroy( CORE )( ref Vulkan vk, ref CORE core ) if( isCoreBuffer!CORE ) {
    vk.destroyHandle( core.buffer );

         static if( core.vc == 1 )  { if( core.view != VK_NULL_HANDLE ) vk.destroyHandle( core.view ); }
    else static if( core.vc  > 1 )  { foreach( ref v; core.view )  if( v != VK_NULL_HANDLE ) vk.destroyHandle( v ); }

    static if( CORE.mc & BMC.Memory )   vk.destroyHandle( core.memory );
    static if( CORE.mc & BMC.Ptr )      core.ptr = null;
}


/// Private template to identify Core_Image_T .
private template isCoreBuffer( T ) { enum isCoreBuffer = is( typeof( isCoreBufferImpl( T.init ))); }
private void isCoreBufferImpl( uint32_t view_count, uint32_t member_copies )( Core_Buffer_T!( view_count, member_copies ) cb ) {}



alias   Meta_Buffer             = Meta_Buffer_T!( 0 );
alias   Meta_Buffer_View        = Meta_Buffer_T!( 1 );
alias   Meta_Buffer_Memory      = Meta_Buffer_T!( 0, BMC.Memory );
alias   Meta_Buffer_Memory_View = Meta_Buffer_T!( 1, BMC.Memory );
alias   Meta_Buffer_T( T )      = Meta_Buffer_T!( T.vc, T.mc );

/// struct to capture buffer and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct
/// Here we have a distinction between bufferSize, which is the (requested) size of the VkBuffer
/// and memSeize, which is the size of the memory range attached to the VkBuffer
/// They might differ based on memory granularity and alignment, but both should be safe for memory mapping
struct Meta_Buffer_T( uint32_t view_count, uint32_t member_copies = BMC.None ) {
    alias   vc = view_count;
    alias   mc = member_copies;
    mixin   Vulkan_State_Pointer;
    mixin   Memory_Member;
    mixin   Memory_Buffer_Image_Common;
    mixin   Buffer_Member!1;
    static if( vc > 0 ) {
        mixin  BView_Member!vc      bview_member;   // named mixin template to resolve overloaded functions
        alias  view = buffer_view;
        static if( vc > 1 ) alias   views = buffer_view;
    }

    version( DEBUG_NAME )   string  name;


    /// bulk destroy the resources belonging to this meta struct
    void destroyResources() {
        vk.destroyHandle( buffer );
        if( owns_device_memory )    vk.destroyHandle( device_memory );
        static if( vc > 0 )         destroyView;
        resetMemory;
    }


    /// reset all internal data and return wrapped Vulkan objects
    /// VkBuffer as well as optional VkBufferView(s)
    /// in a new matching Core_Buffer_T
    auto reset() {
        Core_Buffer_T!( vc, mc ) out_core;
        reset( out_core );
        return out_core;
    }


    /// reset all internal data and return wrapped Vulkan objects
    /// VkBuffer as well as optional VkBufferView(s)
    /// in the passed in ref Core_Buffer_T
    auto ref reset( ref Core_Buffer_T!( vc, mc ) out_core ) {
                                            out_core.buffer     = resetBuffer;
        static if( vc > 0 )                 out_core.view       = resetView;
        static if( mc & BMC.Mem_Range )     out_core.mem_range  = createMappedMemoryRange;  // VkMappedMemoryRange has all the properties listed next line.
        else {
            static if( mc & BMC.Offset )    out_core.offset     = device_memory_offset;
            static if( mc & BMC.Memory )    out_core.memory     = resetMemory;
            static if( mc & BMC.Size )      out_core.size       = bufferSize;
        }
        return this;
    }


    /// extract core descriptor elements VkDescriptorPool, VkDescriptorSet and VkDescriptorSetLayout
    /// without resetting the internal data structures
    auto extractCore() {
        Core_Buffer_T!( vc, mc )            out_core;
                                            out_core.buffer     = buffer;
        static if( vc > 0 )                 out_core.view       = buffer_view;
        static if( mc & BMC.Mem_Range )     out_core.mem_range  = createMappedMemoryRange;  // VkMappedMemoryRange has all the properties listed next line.
        else {
            static if( mc & BMC.Offset )    out_core.offset     = device_memory_offset;
            static if( mc & BMC.Memory )    out_core.memory     = resetMemory;
            static if( mc & BMC.Size )      out_core.size       = bufferSize;
        }
        return out_core;
    }


    /// conditionally extract core descriptor elements VkDescriptorPool, VkDescriptorSet and VkDescriptorSetLayout
    /// without resetting the internal data structures. Takes a ref to the Core struct, and extracts the data only
    /// if it is not a VK_NULL_HANDLE. Returns ref to this for additional function chaining.
    auto ref extractCore( ref Core_Buffer_T!( vc, mc ) out_core, bool overwrite_valid_handles = true ) {

                                if(      !buffer.is_null_handle && ( overwrite_valid_handles || out_core.buffer.is_null_handle ))  out_core.buffer  = buffer;
        static if( vc == 1 )    if( !buffer_view.is_null_handle && ( overwrite_valid_handles ||   out_core.view.is_null_handle ))  out_core.view    = buffer_view;

        // now handle arrays of views
        static if( vc > 1 )
            foreach( i; 0 .. vc )
                if(!buffer_view[i].is_null_handle && ( overwrite_valid_handles || out_core.view[i].is_null_handle ))
                    out_core.view[i] = buffer_view[i];

        static if( mc & BMC.Mem_Range )     out_core.mem_range  = createMappedMemoryRange;  // VkMappedMemoryRange has all the properties listed next line.
        else {
            static if( mc & BMC.Offset )    out_core.offset     = device_memory_offset;
            static if( mc & BMC.Memory )    out_core.memory     = resetMemory;
            static if( mc & BMC.Size )      out_core.size       = bufferSize;
        }

        return this;
    }


    /// Overload and hide constructView from BView_Member template, so that we do not need to and cannot pass in a VkBuffer to create the view from, as this Meta_Struct is supposed to use its own VkBuffer for that.
    static if( vc == 1 ) {

        /// Construct buffer view using this Meta_Buffer's buffer. This overloads and hides the constructView from BView_Member template.
        auto ref constructView( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

            // check if the buffer has been constructed already (not a VK_NULL_HANDLE).
            vkAssert( !buffer.is_null_handle, "No buffer constructed.", file, line, func, "First construct the underlying buffer before creating a buffer view for it." );

            // check if memory was bound to the buffer
            vkAssert( !device_memory.is_null_handle, "No memory bound to buffer.", file, line, func, "First allocate and bind memory to the underlying buffer before creating an buffer view for it." );

            // assign the buffer to the buffer view ci and create the view
            buffer_view_ci.buffer = buffer;
            vk.device.vkCreateBufferView( & buffer_view_ci, vk.allocator, & buffer_view ).vkAssert( null, file, line, func );
            return this;
        }
    }

    else static if( vc > 1 ) {

        /// Construct a buffer view using this Meta_Buffer's buffer.
        auto ref constructView( uint32_t view_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

            // check if the buffer has been constructed already (not a VK_NULL_HANDLE).
            vkAssert( !buffer.is_null_handle, "No buffer constructed.", file, line, func, "First construct the underlying buffer before creating a buffer view for it." );

            // check if memory was bound to the buffer
            vkAssert( !device_memory.is_null_handle, "No memory bound to buffer.", file, line, func, "First allocate and bind memory to the underlying buffer before creating an buffer view for it." );

            // assign the buffer to the buffer view ci and create the view
            buffer_view_ci.buffer = buffer;
            vk.device.vkCreateBufferView( & buffer_view_ci, vk.allocator, & buffer_view[ view_index ] ).vkAssert( null, file, line, func );
            return this;
        }
    }


    /// Convenience function exists if we have 0 or 1 buffer view(s)
    static if( vc <= 1 ) {
        /// Construct the Buffer, and possibly BufferView(s) from specified data.
        auto ref construct( VkMemoryPropertyFlags memory_property_flags, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
            constructBuffer( file, line, func );
            allocateMemory( memory_property_flags );
            static if( vc == 1 ) constructView( file, line, func );
            return this;
        }
    }


    /// Check if all Vulkan resources are null, not available for multi buffer view.
         static if( vc == 0 ) alias is_null = is_buffer_null;
    else static if( vc == 1 ) bool  is_null() { return is_buffer_null && is_view_null; }

}


/// package template to identify Meta_Buffer_T
package template isMetaBuffer( T ) { enum isMetaBuffer = is( typeof( isMetaBufferImpl( T.init ))); }
private void isMetaBufferImpl( uint32_t view_count, uint32_t member_copies )( Meta_Buffer_T!( view_count, member_copies ) bv ) {}



/////////////////////////////////////////////////////
// Meta_BView simple instantiation of BView_Member //
/////////////////////////////////////////////////////

alias  Meta_BView = Meta_BView_T!1;
/// Meta struct to configure and construct a VkImageView.
/// Must be initialized with a Vulkan state struct.
struct Meta_BView_T( uint32_t view_count ) {
    mixin Vulkan_State_Pointer;
    mixin BView_Member!view_count;
    alias construct = constructView;
    alias is_null   = is_view_null;
}



////////////////////////////////////////////////////
// Buffer_Member and BView_Member mixin templates //
////////////////////////////////////////////////////

/// template to mixin VkBuffer construction related members and methods
mixin template Buffer_Member( uint32_t buffer_count ) if( buffer_count > 0 ) {

    alias bc = buffer_count;

    VkBufferCreateInfo      buffer_ci;


    static if( bc == 1 ) {

        VkBuffer                buffer;

        VkDeviceSize            bufferSize()    { return buffer_ci.size; }

        /// Construct the buffer from passed in data.
        auto ref constructBuffer( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
            // assert that meta struct is initialized with a valid vulkan state pointer
            vkAssert( isValid, "Vulkan state not assigned", file, line, func );

            // construct the image buffer
            vk.device.vkCreateBuffer( & buffer_ci, vk.allocator, & buffer ).vkAssert( null, file, line, func );

            // if this template is embedded in some Meta_Buffer, we must retrieve the memory requirements here
            static if( hasMemReqs!( typeof( this )))
                vk.device.vkGetBufferMemoryRequirements( buffer, & memory_requirements );

            return this;
        }


        /// Destroy the buffer
        void destroyBuffer() {
            if( buffer != VK_NULL_HANDLE )
                vk.destroyHandle( buffer );
        }


        /// get buffer and reset it to VK_NULL_HANDLE such that a new, different buffer can be created
        auto resetBuffer() {
            auto result = buffer;
            buffer = VK_NULL_HANDLE;
            return result;
        }


        /// check if the handle is a null handle. This does not check the validity of the handle, only its value.
        bool is_buffer_null()           { return buffer.is_null_handle; }

    } else {

        VkBuffer[bc]                    buffer;
        private VkDeviceSize[bc]        buffer_size;
        VkDeviceSize                    bufferSize( uint32_t buffer_index )     { return buffer_size[ buffer_index ]; }

        /// Construct the buffer from passed in data.
        auto ref constructBuffer( uint32_t buffer_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
            // assert that meta struct is initialized with a valid vulkan state pointer
            vkAssert( isValid, "Vulkan state not assigned", file, line, func );

            // construct the image buffer and capture the buffer size from the buffer create info (we have only one ci for multiple buffers).
            vk.device.vkCreateBuffer( & buffer_ci, vk.allocator, & buffer[ buffer_index ] ).vkAssert( null, file, line, func );
            buffer_size[ buffer_index ] = buffer_ci.size;

            return this;
        }


        /// Destroy the buffer
        void destroyBuffer() {
            foreach( ref buf; buffer )
                if( buf != VK_NULL_HANDLE )
                    vk.destroyHandle( buf );
        } alias destroyBuffers = destroyBuffer;


        /// get one buffer and reset it to VK_NULL_HANDLE such that a new, different buffer can be created at that index
        auto resetBuffer( uint32_t buffer_index ) {
            auto result = buffer[ buffer_index ];
            buffer[ buffer_index ] = VK_NULL_HANDLE;
            return result;
        }


        /// get all buffer and reset them to VK_NULL_HANDLE such that a new, different buffers can be created
        auto resetBuffer() {
            auto result = buffer;
            foreach( ref buf; buffer )
                buf = VK_NULL_HANDLE;
            return result;
        } alias resetBuffers = resetBuffer;


        /// check if the handle is a null handle. This does not check the validity of the handle, only its value.
        bool is_buffer_null( uint32_t buffer_index )  { return buffer[ buffer_index ].is_null_handle; }
    }


    /// Initialize buffer view create info to useful defaults
    void initBufferCreateInfo() {
        buffer_ci = VkBufferCreateInfo.init;
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
    auto ref bufferSize( VkDeviceSize buffer_size ) {
        buffer_ci.size = buffer_size;
        return this;
    }


    /// Specify the sharing queue families and implicitly the sharing mode, which defaults to VK_SHARING_MODE_EXCLUSIVE.
    /// Specify the sharing queue families and implicitly the sharing mode, which defaults to VK_SHARING_MODE_EXCLUSIVE.
    auto ref sharingQueueFamilies( uint32_t[] sharing_queue_family_indices, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( sharing_queue_family_indices.length != 1,
            "Length of sharing_queue_family_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)", file, line, func );
        buffer_ci.sharingMode           = sharing_queue_family_indices.length > 1 ? VK_SHARING_MODE_CONCURRENT : VK_SHARING_MODE_EXCLUSIVE;
        buffer_ci.queueFamilyIndexCount = sharing_queue_family_indices.length.toUint;
        buffer_ci.pQueueFamilyIndices   = sharing_queue_family_indices.ptr;
    }
}



/// template to mixin VkBufferView construction related members and methods
mixin template BView_Member( uint32_t view_count ) if( view_count > 0 ) {

    alias vc = view_count;

    VkBufferViewCreateInfo   buffer_view_ci = { range : VK_WHOLE_SIZE };


    static if( vc == 1 ) {

        VkBufferView         buffer_view;


        /// Construct the buffer view for a passed in VkBuffer.
        auto ref constructView( VkBuffer buffer, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

            // assert that meta struct is initialized with a valid vulkan state pointer
            vkAssert( isValid, "Vulkan state not assigned", file, line, func );

            // assert that the passed in buffer is not a null handle
            vkAssert( !buffer.is_null_handle, "Specified VkBuffer is null", file, line, func );

            // assign the buffer to the buffer view ci and create the view
            buffer_view_ci.buffer = buffer;
            vk.device.vkCreateBufferView( & buffer_view_ci, vk.allocator, & buffer_view ).vkAssert( null, file, line, func );
            return this;
        }


        /// Destroy the buffer view
        void destroyView() {
            if( buffer_view != VK_NULL_HANDLE )
                vk.destroyHandle( buffer_view );
        }


        /// get buffer view and reset it to VK_NULL_HANDLE such that a new, different view can be created
        auto resetView() {
            auto result = buffer_view;
            buffer_view = VK_NULL_HANDLE;
            return result;
        }


        /// check if the handle is a null handle, or constructed. This does not check the validity of the handle, only its value.
        bool is_view_null() { return buffer_view.is_null_handle; }
    }

    else static if( vc > 1 ) {

        VkBufferView[vc]     buffer_view;


        /// Construct the buffer view for a passed in VkBuffer.
        auto ref constructView( VkBuffer buffer, uint32_t view_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
            // assert that meta struct is initialized with a valid vulkan state pointer
            vkAssert( isValid, "Vulkan state not assigned", file, line, func );

            // assert that the passed in buffer is not a null handle
            vkAssert( !buffer.is_null_handle, "Specified VkBuffer is null", file, line, func );

            // assign the buffer to the buffer view ci and create the view
            buffer_view_ci.buffer = buffer;
            vk.device.vkCreateBufferView( & buffer_view_ci, vk.allocator, & buffer_view[ view_index ] ).vkAssert( null, file, line, func );
            return this;
        }


        /// Destroy the buffer views
        void destroyView() {
            foreach( ref view; buffer_view )
                if( view != VK_NULL_HANDLE )
                    vk.destroyHandle( view );
        } alias destroyViews = destroyView;


        /// get one buffer view and reset it to VK_NULL_HANDLE such that a new, different view can be created at that index
        auto resetView( uint32_t view_index ) {
            auto result = buffer_view[ view_index ];
            buffer_view[ view_index ] = VK_NULL_HANDLE;
            return result;
        }


        /// get all buffer views and reset them to VK_NULL_HANDLE such that a new, different views can be created
        auto resetView() {
            auto result = buffer_view;
            foreach( ref view; buffer_view )
                view = VK_NULL_HANDLE;
            return result;
        } alias resetViews = resetView;


        /// check if the handle is a null handle. This does not check the validity of the handle, only its value.
        bool is_view_null( uint32_t view_index )  { return buffer_view[ view_index ].is_null_handle; }
    }


    /// Initialize buffer view create info to useful defaults.
    void initBufferViewCreateInfo() {
        buffer_view_ci = VkBufferViewCreateInfo.init;
        buffer_view_ci.range = VK_WHOLE_SIZE;
    }


    /// Specify buffer view create flags.
    auto ref viewFlags( VkBufferViewCreateFlags view_flags ) {
        buffer_view_ci.flags = view_flags;
        return this;
    }


    /// Specify buffer view format.
    auto ref viewFormat( VkFormat view_format ) {
        buffer_view_ci.format = view_format;
        return this;
    }


    /// Specify buffer view offset and range.
    auto viewOffsetRange( VkDeviceSize offset, VkDeviceSize range ) {
        buffer_view_ci.offset = offset;
        buffer_view_ci.range  = range;
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
        uint32_t[]          sharing_queue_family_indices = [],
        string              file = __FILE__,
        size_t              line = __LINE__,
        string              func = __FUNCTION__
        ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );

        // buffer create info from arguments
        meta.buffer_ci.size                  = size; // size in Bytes
        meta.buffer_ci.usage                 = usage;
        meta.buffer_ci.sharingMode           = sharing_queue_family_indices == [] ? VK_SHARING_MODE_EXCLUSIVE : VK_SHARING_MODE_CONCURRENT;
        meta.buffer_ci.queueFamilyIndexCount = sharing_queue_family_indices.length.toUint;
        meta.buffer_ci.pQueueFamilyIndices   = sharing_queue_family_indices.ptr;

        meta.device.vkCreateBuffer( & meta.buffer_ci, meta.allocator, & meta.buffer ).vkAssert( "Init Buffer", file, line, func );
        meta.device.vkGetBufferMemoryRequirements( meta.buffer, & meta.memory_requirements );

        return meta;
    }

    //alias create = initBuffer;


    /// create a VkBuffer object, this function or initBuffer (or its alias create) must be called first, further operations require the buffer
    /// the resulting buffer and its create info are stored in the Meta_Buffer struct
    /// the Meta_Buffer struct is returned for function chaining
    auto createBuffer( ref Vulkan vk, VkBufferUsageFlags usage, VkDeviceSize size, uint32_t[] sharing_queue_family_indices = [] ) {
        Meta_Buffer meta = vk;
        meta.initBuffer( usage, size, sharing_queue_family_indices );
        return meta;
    }
}



