module vdrive.memory;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.buffer;

import erupted;



//////////////////////////////
// general memory functions //
//////////////////////////////

/// memory_type_bits is a bit-field where if bit i is set, it means that the VkMemoryType i
/// of the VkPhysicalDeviceMemoryProperties structure satisfies the memory requirements.
auto memoryTypeIndex(
    const ref VkPhysicalDeviceMemoryProperties  memory_properties,
    const ref VkMemoryRequirements              memory_requirements,
    VkMemoryPropertyFlags                       memory_property_flags

    ) {

    uint32_t memory_type_bits = memory_requirements.memoryTypeBits;
    uint32_t memory_type_index;
    foreach( i; 0u .. memory_properties.memoryTypeCount ) {
        VkMemoryType memory_type = memory_properties.memoryTypes[i];
        if( memory_type_bits & 1 ) {
            if( ( memory_type.propertyFlags & memory_property_flags ) == memory_property_flags ) {
                memory_type_index = i;
                break;
            }
        }
        memory_type_bits = memory_type_bits >> 1;
    }

    return memory_type_index;
}



/// Search the memory heap (index) which satisfies given memory heap flags.
/// An minimum heap index can be optionally specified. Returns uint32_t.max if heap not found.
auto memoryHeapIndex(
    VkPhysicalDeviceMemoryProperties    memory_properties,
    VkMemoryHeapFlags                   memory_heap_flags,
    uint32_t                            min_memory_heap_index = 0,
    string                              file = __FILE__,
    size_t                              line = __LINE__,
    string                              func = __FUNCTION__

    ) {

    vkAssert( min_memory_heap_index < memory_properties.memoryHeapCount, "First Memory Heap Index out of bounds", file, line, func );
    foreach( i; min_memory_heap_index .. memory_properties.memoryHeapCount ) {
        if(( memory_properties.memoryHeaps[i].flags & memory_heap_flags ) == memory_heap_flags ) {
            return i.toUint;
        }
    } return uint32_t.max;
}



/// Query if a memory heap is available that satisfies given memory heap flags.
auto hasMemoryHeapType( VkPhysicalDeviceMemoryProperties memory_properties, VkMemoryHeapFlags memory_heap_flags ) {
    return memoryHeapIndex( memory_properties, memory_heap_flags ) < uint32_t.max;
}



/// Query the memory heap size of a given memory heap (index).
auto memoryHeapSize( VkPhysicalDeviceMemoryProperties memory_properties, uint32_t memory_heap_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    vkAssert( memory_heap_index < memory_properties.memoryHeapCount, "Memory Heap Index out of bounds", file, line, func );
    return memory_properties.memoryHeaps[ memory_heap_index ].size;
}



/// Allocate device memory from a given memory type (index).
auto allocateMemory(
    ref Vulkan      vk,
    VkDeviceSize    allocation_size,
    uint32_t        memory_type_index,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) {

    // construct a memory allocation info from arguments
    VkMemoryAllocateInfo memory_allocate_info = {
        allocationSize  : allocation_size,
        memoryTypeIndex : memory_type_index,
    };

    // allocate device memory
    VkDeviceMemory device_memory;
    vkAllocateMemory( vk.device, & memory_allocate_info, vk.allocator, & device_memory ).vkAssert( "Allocate Memory", file, line, func );

    return device_memory;
}



/// Map allocated memory.
auto mapMemory(
    ref Vulkan          vk,
    VkDeviceMemory      memory,
    VkDeviceSize        size,
    VkDeviceSize        offset  = 0,
//  VkMemoryMapFlags    flags   = 0,        // for future use
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    VkMemoryMapFlags flags;
    void* mapped_memory;
    vk.device.vkMapMemory( memory, offset, size, flags, & mapped_memory ).vkAssert( "Map Memory", file, line, func );
    return mapped_memory;
}



/// Unmap allocated memory.
void unmapMemory( ref Vulkan vk, VkDeviceMemory memory ) {
    vk.device.vkUnmapMemory( memory );
}



/// Create a VkMappedMemoryRange and initialize struct.
auto createMappedMemoryRange(
    ref Vulkan          vk,
    VkDeviceMemory      memory,
    VkDeviceSize        size    = VK_WHOLE_SIZE,
    VkDeviceSize        offset  = 0,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    VkMappedMemoryRange mapped_memory_range = {
        memory  : memory,
        size    : size,
        offset  : offset,
    };
    return mapped_memory_range;
}



/// Flush a mapped memory range.
void flushMappedMemoryRange( ref Vulkan vk, VkMappedMemoryRange mapped_memory_range, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    vk.device.vkFlushMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Flush Mapped Memory Range", file, line, func );
}



/// Flush multiple mapped memory ranges.
void flushMappedMemoryRanges( ref Vulkan vk, VkMappedMemoryRange[] mapped_memory_ranges, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    vk.device.vkFlushMappedMemoryRanges( mapped_memory_ranges.length.toUint, mapped_memory_ranges.ptr ).vkAssert( "Flush Mapped Memory Ranges", file, line, func );
}



/// Invalidate a mapped memory range.
void invalidateMappedMemoryRange( ref Vulkan vk, VkMappedMemoryRange mapped_memory_range, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    vk.device.vkInvalidateMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Flush Mapped Memory Range", file, line, func );
}



/// Invalidate multiple mapped memory ranges.
void invalidateMappedMemoryRanges( ref Vulkan vk, VkMappedMemoryRange[] mapped_memory_ranges, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    vk.device.vkInvalidateMappedMemoryRanges( mapped_memory_ranges.length.toUint, mapped_memory_ranges.ptr ).vkAssert( "Flush Mapped Memory Ranges", file, line, func );
}



/// Template to detect Meta_Memory, _Buffer, _Image
private template hasMemReqs( T ) {
    enum hasMemReqs = __traits( hasMember, T, "memory_requirements" );
}



/// Mixin template for common decelerations of Meta_Memory, _Buffer, _Image
package mixin template Memory_Buffer_Image_Common() {

    /// map the underlying memory object and return the mapped memory pointer
    auto mapMemory(
        VkDeviceSize        size    = 0,        // if 0, the device_memory_size will be used
        VkDeviceSize        offset  = 0,
    //  VkMemoryMapFlags    flags   = 0,        // for future use
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__

        ) {

        // if we want to map the memory of an underlying buffer or image,
        // we need to account for the buffer or image offset into its VkDeviceMemory
        static if( is( typeof( this ) == Meta_Memory )) VkDeviceSize combined_offset = offset;
        else                                            VkDeviceSize combined_offset = offset + device_memory_offset;
        if( size == 0 ) size = memSize;    // use the attached memory size in this case
        void* mapped_memory;
        vk.device
            .vkMapMemory( device_memory, combined_offset, size, 0, & mapped_memory )
            .vkAssert( "Map Memory", file, line, func );
        return mapped_memory;
    }


    /// map the underlying memory object, copy the provided data into it and return the mapped memory pointer
    auto mapMemory(
        void[]              data,
        VkDeviceSize        offset  = 0,
    //  VkMemoryMapFlags    flags   = 0,        // for future use
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        // if we want to map the memory of an underlying buffer or image,
        // we need to account for the buffer or image offset into its VkDeviceMemory
        static if( is( typeof( this ) == Meta_Memory )) VkDeviceSize combined_offset = offset;
        else                                            VkDeviceSize combined_offset = offset + device_memory_offset;

        // the same combined_offset logic is applied in the function bellow, so we must pass
        // the original offset to not apply the Meta_Buffer or Meta_Image.device_memory_offset twice
        auto mapped_memory = vk.mapMemory( device_memory, data.length, combined_offset, file, line, func );
        mapped_memory[ 0 .. data.length ] = data[];

        // required for the mapped memory flush
        VkMappedMemoryRange mapped_memory_range =
            vk.createMappedMemoryRange( device_memory, data.length, combined_offset, file, line, func );

        // flush the mapped memory range so that its visible to the device memory space
        vk.device
            .vkFlushMappedMemoryRanges( 1, & mapped_memory_range )
            .vkAssert( "Map Memory", file, line, func );
        return mapped_memory;
    }


    /// unmap map the underlying memory object
    auto ref unmapMemory() {
        vk.device.vkUnmapMemory( device_memory );
        return this;
    }


    /// create a mapped memory range with given size and offset for the (backing) memory object
    /// the offset into the buffer or image backing VkMemory will be added to the passed in offset
    /// and the size will be determined from buffer/image.memSize in case of VK_WHOLE_SIZE
    auto createMappedMemoryRange(
        VkDeviceSize        size    = VK_WHOLE_SIZE,
        VkDeviceSize        offset  = 0,
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        // if we want to create a mapped memory range for the memory of an underlying buffer or image,
        // we need to account for the buffer or image offset into its VkDeviceMemory
        static if( !is( typeof( this ) == Meta_Memory )) {
            offset += memOffset;
            if( size == VK_WHOLE_SIZE ) {
                size = memSize;
            }
        }
        return vk.createMappedMemoryRange( device_memory, size, offset, file, line, func );
    }


    /// flush the memory object, either whole size or with offset and size
    /// memory must have been mapped beforehand
    auto ref flushMappedMemoryRange(
        VkDeviceSize        size    = VK_WHOLE_SIZE,
        VkDeviceSize        offset  = 0,
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
        auto mapped_memory_range = this.createMappedMemoryRange( size, offset, file, line, func );
        vk.device.vkFlushMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Flush Mapped Memory Range", file, line, func );
        return this;
    }


    /// invalidate the memory object, either whole size or with offset and size
    /// memory must have been mapped beforehand
    auto ref invalidateMappedMemoryRange(
        VkDeviceSize        size    = VK_WHOLE_SIZE,
        VkDeviceSize        offset  = 0,
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
        auto mapped_memory_range = createMappedMemoryRange( size, offset, file, line, func );
        vk.device.vkInvalidateMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Invalidate Mapped Memory Range", file, line, func );
        return this;
    }


    /// upload data to the VkDeviceMemory object of the corresponding buffer or image through memory mapping
    auto ref copyData(
        void[]              data,
        VkDeviceSize        offset  = 0,
    //  VkMemoryMapFlags    flags   = 0,        // for future use
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        mapMemory( data, offset, file, line, func );   // this returns the memory pointer, and not the Meta_Struct
        return unmapMemory;
    }
}




///////////////////////////////////////
// Meta_Memory and related functions //
///////////////////////////////////////

struct Meta_Memory {
    mixin                   Vulkan_State_Pointer;
    private:
    VkDeviceMemory          device_memory;
    VkDeviceSize            device_memory_size      = 0;
    VkMemoryPropertyFlags   memory_property_flags   = 0;
    uint32_t                memory_type_index       = 0;
    version( DEBUG_NAME )   string name;

    public:

    auto memory()           { return device_memory; }
    auto memSize()          { return device_memory_size; }
    auto memPropertyFlags() { return memory_property_flags; }
    auto memTypeIndex()     { return memory_type_index; }

    mixin                   Memory_Buffer_Image_Common;

    // bulk destroy the resources belonging to this meta struct
    void destroyResources() {
        vk.destroyHandle( device_memory );
        device_memory_size      = 0;
        memory_property_flags   = 0;
        memory_type_index       = 0;
    }


    /// Raw allocate function passing in a known memory_type_index (which encodes VkMemoryPropertyFlags and VkMemoryHeapFlags)
    /// and an allocation size
    auto ref allocate( uint32_t memory_type_index, VkDeviceSize allocation_size, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );     // assert that meta struct is initialized with a valid vulkan state pointer
        this.device_memory = vk.allocateMemory( allocation_size, memory_type_index, file, line, func );
        this.device_memory_size = allocation_size;
        this.memory_type_index = memory_type_index;
        return this;
    }


    /// Parametrize a future allocations VkMemoryPropertyFlags
    auto ref memoryType( VkMemoryPropertyFlags property_flags ) {
        memory_property_flags = property_flags;
        return this;
    }


    /// Specify a minimum Memory Type index (the lower the index the higher performance the memory is)
    auto ref minMemoryTypeIndex( uint32_t minimum_index ) {
        /// Here we use a trick, we set a memory type with the lowest index
        /// but set the (same or higher) index manually, the index can be only increased but not decreased
        if( memory_property_flags == 0 )
            memory_property_flags = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
        memory_type_index = minimum_index;
        return this;
    }


    /// Register one multiple memory ranges for one future allocation derived from Meta_Buffer, Meta_Image or Array/Slice of the two.
    /// Memory Offsets including alignment are stored in the corresponding Meta structs. Can be called multiple times with any of the above types.
    auto ref addRange( META )( ref META meta_resource, VkDeviceSize* out_memory_size = null, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        static if( isDataArrayOrSlice!META ) {
            foreach( ref resource; meta_resources ) {
                addRange( resource, memory_size, file, line, func );
            }
        } else static if( hasMemReqs!META ) {
            // confirm that VkMemoryPropertyFlags have been specified with memoryType;
            vkAssert( memory_property_flags > 0, "No memoryType (VkMemoryPropertyFlags) specified.", file, line, func, "Call memoryType( VkMemoryPropertyFlags ) before adding a range." );

            // get the resource dependent memory type index
            // the lower memory type indexes are subsets of the higher type indexes regarding the memory properties
            auto resource_type_index = meta_resource.memoryTypeIndex( memory_property_flags );
            if( memory_type_index < resource_type_index ) memory_type_index = resource_type_index;

            // register the required memory size range, either internally in the meta struct
            // or in the optionally passed in pointer to an external out_memory_size
            if( out_memory_size is null ) {
                meta_resource.device_memory_offset = meta_resource.alignedOffset( device_memory_size );
                device_memory_size = meta_resource.device_memory_offset + meta_resource.requiredMemorySize;
            } else {
                *out_memory_size = meta_resource.alignedOffset( *out_memory_size ) + meta_resource.requiredMemorySize;
            }
        } else {
            static assert(0);   // types not matching
        }

        return this;
    }


    /// Allocate one memory object for all registered memory ranges in one go.
    auto ref allocate( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );     // meta struct must be initialized with a valid vulkan state pointer
        vkAssert( device_memory_size > 0, "Must call addRange() at least once before calling allocate()", file, line, func );
        device_memory = vk.allocateMemory( device_memory_size, memory_type_index );
        return this;
    }


    /// Bind the corresponding range of allocated memory to its client Meta_Buffer(s) or Meta_Image(s). The memory object and and its range is stored in each Meta struct.
    auto ref bind( META )( ref META meta_resource, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__, ) if( hasMemReqs!META ) {
        static if( isDataArrayOrSlice!META ) {
            vkAssert( device_memory != VK_NULL_HANDLE, "No memory allocated for resources.", file, line, func, "Must call allocate() before bind()ing a buffers or images." );
            foreach( ref resource; meta_resources ) {
                resource.bindMemory( device_memory, resource.device_memory_offset, file, line, func );
            }
        } else static if( hasMemReqs!META ) {
            // confirm that memory for this resource has been allocated
            vkAssert( device_memory != VK_NULL_HANDLE, "No memory allocated for resource.", file, line, func, "Must call allocate() before bind()ing a buffer or image." );
            meta_resource.bindMemory( device_memory, meta_resource.device_memory_offset, file, line, func );
        }
        return this;
    }


    /// Add ranges, allocate one memory chunk and bind the memory ranges in one go. Ranges are tightly packed
    /// but obey alignment constraints. Method accepts var args of Meta_Buffer, Meta_Image or Slices/Arrays of the same.
    auto ref allocateAndBind( Args... )( ref Args args, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

        static foreach( arg; args )
            addRange( arg, null, file, line, func );

        allocate;

        foreach( ref arg; args )
            bind( arg, file, line, func );

        return this;
    }
}


deprecated( "Use member method Meta_Memory.allocate instead" ) {
    auto ref initMemory(
        ref Meta_Memory         meta,
        uint32_t                memory_type_index,
        VkDeviceSize            allocation_size,
        string                  file = __FILE__,
        size_t                  line = __LINE__,
        string                  func = __FUNCTION__
        ) {
        vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );     // assert that meta struct is initialized with a valid vulkan state pointer
        meta.device_memory = allocateMemory( meta, allocation_size, memory_type_index, file, line, func );
        meta.device_memory_size = allocation_size;
        meta.memory_type_index = memory_type_index;
        return meta;
    }

    auto createMemory( ref Vulkan vk, uint32_t memory_type_index, VkDeviceSize allocation_size ) {
        Meta_Memory meta = vk;
        meta.allocate( memory_type_index, allocation_size );
        return meta;
    }
}



///////////////////////////////////////////////////////////
// Meta_Buffer and Meta_Image related template functions //
///////////////////////////////////////////////////////////

mixin template Memory_Member() {
    package:
    VkMemoryRequirements    memory_requirements;
    VkDeviceMemory          device_memory;
    VkDeviceSize            device_memory_offset;
    bool                    owns_device_memory = false;
    VkDeviceMemory resetMemoryMember() {
        memory_requirements     = VkMemoryRequirements();
        auto   memory           = device_memory;
        device_memory           = VK_NULL_HANDLE;
        device_memory_offset    = 0;
        owns_device_memory      = false;
        return memory;
    }
    public:
    auto memory()           { return device_memory; }
    auto memSize()          { return memory_requirements.size; }
    auto memOffset()        { return device_memory_offset; }
    auto memRequirements()  { return memory_requirements; }


    auto memoryTypeIndex( VkMemoryPropertyFlags memory_property_flags ) {
        return vk.memory_properties.memoryTypeIndex( memory_requirements, memory_property_flags );
    }


    auto requiredMemorySize() {
        return memory_requirements.size;
    }


    auto alignedOffset( VkDeviceSize device_memory_offset ) {
        if( device_memory_offset % memory_requirements.alignment > 0 ) {
            auto alignment = memory_requirements.alignment;
            device_memory_offset = ( device_memory_offset / alignment + 1 ) * alignment;
        }
        return device_memory_offset;
    }


    /// allocate and bind a VkDeviceMemory object to the VkBuffer/VkImage (which must have been created beforehand) in the meta struct
    /// the memory properties of the underlying VkPhysicalDevicethe are used and the resulting memory object is stored
    /// The memory object is allocated of the size required by the buffer, another function overload will exist with an argument
    /// for an existing memory object where the buffer is supposed to sub-allocate its memory from
    /// the Meta_Buffer struct is returned for function chaining
    auto ref allocateMemory( VkMemoryPropertyFlags memory_property_flags, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );     // meta struct must be initialized with a valid vulkan state pointer

        if( device_memory != VK_NULL_HANDLE && owns_device_memory )             // if device memory is owned and was created already ...
            vk.destroyHandle( device_memory );                                  // ... we destroy it here

        owns_device_memory = true;                                              // using this method the resource always owns the memory
        device_memory = vk.allocateMemory( memory_requirements.size, memoryTypeIndex( memory_property_flags ));

        static      if( is( typeof( this ) == Meta_Buffer ))        vk.device.vkBindBufferMemory( buffer, device_memory, 0 ).vkAssert( "Bind Buffer Memory", file, line, func );
        else static if( isMetaImage!( typeof( this )))   vk.device.vkBindImageMemory(  image,  device_memory, 0 ).vkAssert( "Bind Image Memory" , file, line, func );
        else static assert( 0, "Memory Member can only be mixed into Meta_Memory, Meta_Buffer or Meta_Image_T" );
        return this;
    }


    auto ref bindMemory( VkDeviceMemory device_memory, VkDeviceSize memory_offset = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
        vkAssert( this.device_memory == VK_NULL_HANDLE, "Memory can be bound only once, rebinding is not allowed", file, line, func );

        this.owns_device_memory = false;
        this.device_memory = device_memory;
        this.device_memory_offset = memory_offset;

        static      if( is( typeof( this ) == Meta_Buffer ))  device.vkBindBufferMemory( buffer, device_memory, memory_offset ).vkAssert( "Bind Buffer Memory", file, line, func );
        else static if( is( typeof( this ) == Meta_Image  ))  device.vkBindImageMemory(  image,  device_memory, memory_offset ).vkAssert( "Bind Image Memory" , file, line, func );
        return this;
    }
}



/////////////////////////////
// general image functions //
/////////////////////////////

/// query the properties of a certain image format
auto imageFormatProperties(
    ref Vulkan          vk,
    VkFormat            format,
    VkImageType         type,
    VkImageTiling       tiling,
    VkImageUsageFlags   usage,
    VkImageCreateFlags  flags = 0,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) {

    VkImageFormatProperties image_format_properties;
    vk.gpu.vkGetPhysicalDeviceImageFormatProperties(
        format, type, tiling, usage, flags, & image_format_properties ).vkAssert( "Image Format Properties", file, line, func );
    return image_format_properties;
}



//////////////////////////////////////
// Meta_Image and related functions //
//////////////////////////////////////

mixin template IView_Memeber( uint view_count ) if( view_count > 0 ) {

    alias vc = view_count;

    VkImageViewCreateInfo   image_view_ci = {
        viewType            : VK_IMAGE_VIEW_TYPE_MAX_ENUM,
        format              : VK_FORMAT_MAX_ENUM,
        subresourceRange    : {
            aspectMask          : VK_IMAGE_ASPECT_COLOR_BIT,
            levelCount          : 1,
            layerCount          : 1
        }
    };

    static if( vc == 1 ) {

        VkImageView         image_view;


        /// Construct the image from specified data. If format or type was not specified, the corresponding image format and/or type will be used.
        auto ref constructView( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

            // assert validity
            assureValidView( file, line, func );

            // construct the image view
            vkCreateImageView( vk.device, & image_view_ci, vk.allocator, & image_view ).vkAssert( "Construct image view", file, line, func );
            return this;
        }


        /// Destroy the image view
        void destroyImageView() {
            if( image_view != VK_NULL_HANDLE )
                vk.destroyHandle( image_view );
        }


        /// get image view and reset it to VK_NULL_HANDLE such that a new, different view can be created
        auto resetImageView() {
            auto result = image_view;
            image_view  = VK_NULL_HANDLE;
            initImageViewCreateInfo;
            return result;
        }
    }

    else {

        VkImageView[vc]     image_view;


        /// Construct the image from specified data. If format or type was not specified, the corresponding image format and/or type will be used.
        auto ref constructView( uint32_t view_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

            // assert validity
            assureValidView( file, line, func );

            // construct the image view
            vk.device.vkCreateImageView( & image_view_ci, vk.allocator, & image_view[ view_index ] ).vkAssert( "Construct image view", file, line, func );
            return this;
        }


        /// Destroy the image views
        void destroyImageView() {
            foreach( ref view; image_view )
                if( view != VK_NULL_HANDLE )
                    vk.destroyHandle( view );
        } alias destroyImageViews = destroyImageView;


        /// get one image view and reset it to VK_NULL_HANDLE such that a new, different view can be created at thta index
        auto resetImageView( uint index ) {
            auto result = image_view[ index ];
            image_view[ index ] = VK_NULL_HANDLE;
            return result;
        }


        /// get all image views and reset them to VK_NULL_HANDLE such that a new, different views can be created
        auto resetImageView() {
            auto result = image_view;
            foreach( ref view; image_view )
                view = VK_NULL_HANDLE;
            initImageViewCreateInfo;
            return result;
        } alias resetImageViews = resetImageView;
    }


    private void assureValidView( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );

        // Check validity only if embedding struct has memory member and is backing an actual image (e.g. Meta_IView_T does not)
        static if( hasMemReqs!( typeof( this ))) {

            // check if memory was bound to the image
            vkAssert( image != VK_NULL_HANDLE, "No image constructed.", file, line, func, "First construct the underlying image before creating an image view for the image." );

            // check if memory was bound to the image
            vkAssert( device_memory != VK_NULL_HANDLE, "No memory bound to image.", file, line, func, "First allocate and bind memory to the underlying image before creating an image view for the image." );

            // assign the valid image to the image_view_ci.image member
            image_view_ci.image = image;

            // check if view type was specified
            if( image_view_ci.viewType == VK_IMAGE_VIEW_TYPE_MAX_ENUM )
                image_view_ci.viewType = cast( VkImageViewType )image_ci.imageType;

            // check if view format was specified
            if( image_view_ci.format == VK_FORMAT_MAX_ENUM )
                image_view_ci.format = image_ci.format;
        }
    }


    /// Initialize image view create info to useful defaults
    void initImageViewCreateInfo() {
        image_view_ci = VkImageViewCreateInfo.init;
        image_view_ci.viewType  = VK_IMAGE_VIEW_TYPE_MAX_ENUM;
        image_view_ci.format    = VK_FORMAT_MAX_ENUM;
        image_view_ci.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        image_view_ci.subresourceRange.levelCount = 1;
        image_view_ci.subresourceRange.layerCount = 1;
    }


    /// Override image view type. If not specified, the image type will be used.
    auto ref viewType( VkImageViewType view_type ) {
        image_view_ci.viewType = view_type;
        return this;
    }


    /// Override image view format. If not specified, the image format will be used.
    auto ref viewFormat( VkFormat view_format ) {
        image_view_ci.format = view_format;
        return this;
    }


    /// Specify image view subresource aspect mask.
    auto ref viewAspect( VkImageAspectFlags subresource_aspect_mask ) {
        image_view_ci.subresourceRange.aspectMask = subresource_aspect_mask;
        return this;
    }


    /// Specify image view subresource base mip level and level count.
    auto ref viewMipLevels( uint32_t base_mip_level, uint32_t mip_level_count ) {
        image_view_ci.subresourceRange.baseMipLevel = base_mip_level;
        image_view_ci.subresourceRange.levelCount   = mip_level_count;
        return this;
    }


    /// Specify image view subresource base array layer and array layer count.
    auto ref viewArrayLayers( uint32_t base_array_layer, uint32_t array_layer_count ) {
        image_view_ci.subresourceRange.baseArrayLayer   = base_array_layer;
        image_view_ci.subresourceRange.layerCount       = array_layer_count;
        return this;
    }


    /// Specify image view subresource range.
    auto ref subresourceRange( VkImageAspectFlags subresource_aspect_mask, uint32_t base_mip_level, uint32_t mip_level_count, uint32_t base_array_layer, uint32_t array_layer_count ) {
        image_view_ci.subresourceRange.aspectMask       = subresource_aspect_mask;
        image_view_ci.subresourceRange.baseMipLevel     = base_mip_level;
        image_view_ci.subresourceRange.levelCount       = mip_level_count;
        image_view_ci.subresourceRange.baseArrayLayer   = base_array_layer;
        image_view_ci.subresourceRange.layerCount       = array_layer_count;
        return this;
    }


    /// Specify image view subresource range.
    auto ref subresourceRange( VkImageSubresourceRange subresource_range ) {
        image_view_ci.subresourceRange = subresource_range;
        return this;
    }


    /// image_view_ci subrescourceRange shortcut
    auto const ref subresourceRange() {
        return image_view_ci.subresourceRange;
    }


    /// Specify component mapping.
    auto ref components( VkComponentSwizzle r, VkComponentSwizzle g, VkComponentSwizzle b, VkComponentSwizzle a ) {
        image_view_ci.components.r = r;
        image_view_ci.components.g = g;
        image_view_ci.components.b = b;
        image_view_ci.components.a = a;
        return this;
    }


    /// Specify component mapping.
    auto ref components( VkComponentMapping component_mapping ) {
        image_view_ci.components = component_mapping;
        return this;
    }
}
alias   Meta_Image                      = Meta_Image_T!(0, 0);
alias   Meta_Image_View                 = Meta_Image_T!(1, 0);
alias   Meta_Image_Sampler              = Meta_Image_T!(1, 1);
alias   Meta_Image_View_Sampler         = Meta_Image_T!(1, 1);
alias   Meta_Image_View_T( uint c )     = Meta_Image_T!(c, 0);
alias   Meta_Image_Sampler_T( uint c )  = Meta_Image_T!(1, c);

/// Struct to capture image and memory creation as well as binding.
/// The struct can travel through several methods and can be filled with necessary data.
/// first thing after creation of this struct must be the assignment of the address of a
/// valid vulkan state struct. VkImageView(s) and VkSampler(s) are statically optional.
struct  Meta_Image_T( uint view_count, uint sampler_count ) {
    alias                   vc = view_count;
    alias                   sc = sampler_count;
    mixin                   Vulkan_State_Pointer;
    VkImage                 image           = VK_NULL_HANDLE;
    VkImageCreateInfo       image_ci        = { mipLevels : 1, arrayLayers : 1, samples : VK_SAMPLE_COUNT_1_BIT };
    mixin                   Memory_Member;
    mixin                   Memory_Buffer_Image_Common;
    static if( vc > 0 )     mixin  IView_Memeber!vc;
    static if( sc > 0 ) {
        import vdrive.descriptor : Sampler_Member;
        mixin  Sampler_Member!sc;
    }

    version( DEBUG_NAME )   string name;


    /// bulk destroy the resources belonging to this meta struct
    void destroyResources( bool destroy_sampler = true ) {
        vk.destroyHandle( image );
        if( owns_device_memory )    vk.destroyHandle( device_memory );
        static if( vc > 0 )         destroyImageView;
        static if( sc > 0 )         if( destroy_sampler ) destroySampler;
        resetMemoryMember;
    }


    /// reset all internal data and return wrapped Vulkan objects
    /// VkImage as well as optional VkImageView(s) and VkSampler(s)
    auto reset() {
        Core_Image_T!( vc, sc ) result;
        result.image = resetImage;
        static if( vc > 0 ) result.image_view   = resetImageView;
        static if( sc > 0 ) result.sampler      = resetSampler;
        return result;
    }


    /// extract core descriptor elements VkDescriptorPool, VkDescriptorSet and VkDescriptorSetLayout
    /// without resetting the internal data structures
    auto extractCore() {
        Core_Image_T!( vc, sc ) result;
        result.image = image;
        static if( vc > 0 ) result.image_view   = image_view;
        static if( sc > 0 ) result.sampler      = sampler;
        return result;
    }


    //////////////////////
    // VkImage specific //
    //////////////////////


    /// reset all internal data and return wrapped Vulkan objects
    /// VkImage as well as optional VkImageView(s) and VkSampler(s)
    auto resetImage() {
        VkImage result = image;
        image = VK_NULL_HANDLE;
        initImageCreateInfo;
        return result;
    }


    /// Initialize image create info to useful defaults
    void initImageCreateInfo() {
        image_ci = VkImageCreateInfo.init;
        image_ci.mipLevels      = 1;
        image_ci.arrayLayers    = 1;
        image_ci.samples        = VK_SAMPLE_COUNT_1_BIT;
    }


    /// image_ci extent shortcut
    auto const ref extent() {
        return image_ci.extent;
    }


    /// specify format of image
    auto ref format( VkFormat format ) {
        image_ci.format = format;
        return this;
    }


    /// Specify image type and extent. For 2D type omit depth extent argument, for 1D type omit height extent argument.
    auto ref extent( uint32_t width, uint32_t height = 0, uint32_t depth = 0 ) {
        image_ci.imageType  = height == 0 ? VK_IMAGE_TYPE_1D : depth == 0 ? VK_IMAGE_TYPE_2D : VK_IMAGE_TYPE_3D;
        image_ci.extent     = VkExtent3D( width, height == 0 ? 1 : height, depth == 0 ? 1 : depth );
        return this;
    }


    /// Specify 2D image type and extent.
    auto ref extent( VkExtent2D extent, VkImageType image_type = VK_IMAGE_TYPE_2D ) {
        image_ci.imageType  = image_type;
        image_ci.extent     = VkExtent3D( extent.width, extent.height, 1 );
        return this;
    }


    /// Specify 3D image type and extent.
    auto ref extent( VkExtent3D extent, VkImageType image_type = VK_IMAGE_TYPE_3D ) {
        image_ci.imageType  = image_type;
        image_ci.extent     = extent;
        return this;
    }


    /// Specify image usage.
    auto ref usage( VkImageUsageFlags usage ) {
        image_ci.usage = usage;
        return this;
    }


    /// Add image usage. The added usage will be or-ed with the existing one.
    auto ref addUsage( VkImageUsageFlags usage ) {
        image_ci.usage |= usage;
        return this;
    }


    /// Specify mipmap levels.
    auto ref mipLevels( uint32_t levels ) {
        image_ci.mipLevels = levels;
        return this;
    }


    /// Specify array layers.
    auto ref arrayLayers( uint32_t layers ) {
        image_ci.arrayLayers = layers;
        return this;
    }


    /// Specify sample count, this function is aliased more descriptively to sampleCount.
    auto ref samples( VkSampleCountFlagBits samples ) {
        image_ci.samples = samples;
        return this;
    }
    alias sampleCount = samples;


    /// Specify image tiling.
    auto ref tiling( VkImageTiling tiling ) {
        image_ci.tiling = tiling;
        return this;
    }


    /// Specify the sharing queue families and implicitly the sharing mode, which defaults to VK_SHARING_MODE_EXCLUSIVE.
    auto ref sharingQueueFamilies( uint32_t[] sharing_family_queue_indices ) {
        image_ci.sharingMode            = VK_SHARING_MODE_CONCURRENT;
        image_ci.queueFamilyIndexCount  = sharing_family_queue_indices.length.toUint;
        image_ci.pQueueFamilyIndices    = sharing_family_queue_indices.ptr;
    }


    /// Specify the initial image layout. Can only be VK_IMAGE_LAYOUT_UNDEFINED or VK_IMAGE_LAYOUT_PREINITIALIZED.
    auto ref initialLayout( VkImageLayout layout,  string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {
        vkAssert( layout == VK_IMAGE_LAYOUT_UNDEFINED || VK_IMAGE_LAYOUT_PREINITIALIZED,
            "Initial image layout must be either VK_IMAGE_LAYOUT_UNDEFINED or VK_IMAGE_LAYOUT_PREINITIALIZED.", file, line, func );
        image_ci.initialLayout = layout;
        return this;
    }


    /// Construct the image from specified data.
    auto ref constructImage( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        // assert that meta struct is initialized with a valid vulkan state pointer
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );

        // assert that 3D format is not combined with array layers if(!A != !B)
        vkAssert( image_ci.imageType == VK_IMAGE_TYPE_3D ? image_ci.arrayLayers == 1 : true,
            "Length of sharing_family_queue_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)",
            file, line, func );

        // assert that sharing_family_queue_indices is not 1
        vkAssert( image_ci.queueFamilyIndexCount != 1,
            "Length of sharing_family_queue_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)",
            file, line, func );

        vk.device.vkCreateImage( & image_ci, allocator, & image ).vkAssert( "Construct Image", file, line, func );
        vk.device.vkGetImageMemoryRequirements( image, & memory_requirements );

        return this;
    }


    /// Convenience function exists if we have 0 image view and 0 sampler or 1 image view and 0 or 1 sampler
    static if(( vc == 0 && sc == 1 ) || ( vc == 1 && sc <= 1 )) {
        /// Construct the Image, and possibly ImageView and Sampler from specified data.
        auto ref construct( VkMemoryPropertyFlags memory_property_flags, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
            constructImage( file, line, func );
            allocateMemory( memory_property_flags );
            static if( vc == 1 )    constructView( file, line, func );
            static if( sc == 1 )    constructSampler( file, line, func );
            return this;
        }
    }
}


/// private template to identify Meta_Image_T
private template isMetaImage( T ) { enum isMetaImage = is( typeof( isMetaImageImpl( T.init ))); }
private void isMetaImageImpl( uint view_count, uint sampler_count )( Meta_Image_T!( view_count, sampler_count ) ivs ) {}


deprecated( "Use member methods to edit and Meta_Image_Sampler_T.construct instead" ) {
    /// init a simple VkImage with one level and one layer, sharing_family_queue_indices controls the sharing mode
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref initImage(
        ref Meta_Image          meta,
        VkFormat                format,
        uint32_t                width,
        uint32_t                height,
        VkImageUsageFlags       usage,
        VkSampleCountFlagBits   samples = VK_SAMPLE_COUNT_1_BIT,
        VkImageTiling           tiling = VK_IMAGE_TILING_OPTIMAL,
        VkImageLayout           initial_layout = VK_IMAGE_LAYOUT_UNDEFINED,
        uint32_t[]              sharing_family_queue_indices = [],
        VkImageCreateFlags      flags   = 0,
        string                  file    = __FILE__,
        size_t                  line    = __LINE__,
        string                  func    = __FUNCTION__

        ) {

        return meta.create(
            format, width, height, 0, 1, 1, usage, samples,
            tiling, initial_layout, sharing_family_queue_indices, flags,
            file, line, func );
    }


    /// init a VkImage, sharing_family_queue_indices controls the sharing mode
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref initImage(
        ref Meta_Image          meta,
        VkFormat                format,
        uint32_t                width,
        uint32_t                height,
        uint32_t                depth,
        uint32_t                mip_levels,
        uint32_t                array_layers,
        VkImageUsageFlags       usage,
        VkSampleCountFlagBits   samples = VK_SAMPLE_COUNT_1_BIT,
        VkImageTiling           tiling  = VK_IMAGE_TILING_OPTIMAL,
        VkImageLayout           initial_layout = VK_IMAGE_LAYOUT_UNDEFINED,
        uint32_t[]              sharing_family_queue_indices = [],
        VkImageCreateFlags      flags   = 0,
        string                  file    = __FILE__,
        size_t                  line    = __LINE__,
        string                  func    = __FUNCTION__

        ) {

        vkAssert( sharing_family_queue_indices.length != 1,
            "Length of sharing_family_queue_indices must either be 0 (VK_SHARING_MODE_EXCLUSIVE) or greater 1 (VK_SHARING_MODE_CONCURRENT)",
            file, line, func );

        VkImageCreateInfo image_ci = {
            flags                   : flags,
            imageType               : height == 0 ? VK_IMAGE_TYPE_1D : depth == 0 ? VK_IMAGE_TYPE_2D : VK_IMAGE_TYPE_3D,
            format                  : format,
            extent                  : { width, height == 0 ? 1 : height, depth == 0 ? 1 : depth },
            mipLevels               : mip_levels,
            arrayLayers             : array_layers,
            samples                 : samples,
            tiling                  : tiling,
            usage                   : usage,
            sharingMode             : sharing_family_queue_indices.length > 1 ? VK_SHARING_MODE_CONCURRENT : VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount   : sharing_family_queue_indices.length.toUint,
            pQueueFamilyIndices     : sharing_family_queue_indices.length > 1 ? sharing_family_queue_indices.ptr : null,
            initialLayout           : initial_layout,
        };

        return meta.create( image_ci, file, line, func );
    }


    /// init a VkImage, general create image function, gets a VkImageCreateInfo as argument
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref initImage(
        ref Meta_Image              meta,
        const ref VkImageCreateInfo image_ci,
        string                      file = __FILE__,
        size_t                      line = __LINE__,
        string                      func = __FUNCTION__
        ) {
        vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );     // meta struct must be initialized with a valid vulkan state pointer

        if( meta.image != VK_NULL_HANDLE )                      // if an VkImage was created with this meta struct already
            meta.destroyHandle( meta.image );                         // destroy it first

        meta.image_ci = image_ci;
        meta.device.vkCreateImage( & meta.image_ci, meta.allocator, & meta.image ).vkAssert( "Init Image", file, line, func );
        meta.device.vkGetImageMemoryRequirements( meta.image, & meta.memory_requirements );
        return meta;
    }

    alias create = initImage;
}



deprecated( "Use member methods to edit and Meta_Image_Sampler_T.constructView instead" ) {

    /// create a VkImageView which closely corresponds to the underlying VkImage type
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref createView( ref Meta_Image_View meta, VkImageAspectFlags subrecource_aspect_mask = VK_IMAGE_ASPECT_COLOR_BIT ) {
        VkImageSubresourceRange subresource_range = {
            aspectMask      : subrecource_aspect_mask,
            baseMipLevel    : cast( uint32_t )0,
            levelCount      : meta.image_ci.mipLevels,
            baseArrayLayer  : cast( uint32_t )0,
            layerCount      : meta.image_ci.arrayLayers, };
        return meta.createView( subresource_range );
    }

    /// create a VkImageView which closely corresponds to the underlying VkImage type
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref createView( ref Meta_Image_View meta, VkImageSubresourceRange subresource_range ) {
        return meta.createView( subresource_range, cast( VkImageViewType )meta.image_ci.imageType, meta.image_ci.format );
    }

    /// create a VkImageView with choosing an image view type and format for the underlying VkImage, component mapping is identity
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref createView( ref Meta_Image_View meta, VkImageSubresourceRange subresource_range, VkImageViewType view_type, VkFormat view_format ) {
        return meta.createView( subresource_range, view_type, view_format, VkComponentMapping(
            VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY ));
    }

    /// create a VkImageView with choosing an image view type, format and VkComponentMapping for the underlying VkImage
    /// store vulkan data in argument Meta_Image container, return container for chaining
    auto ref createView(
        ref Meta_Image_View     meta,
        VkImageSubresourceRange subresource_range,
        VkImageViewType         view_type,
        VkFormat                view_format,
        VkComponentMapping      component_mapping,
        string                  file = __FILE__,
        size_t                  line = __LINE__,
        string                  func = __FUNCTION__
        ) {
        if( meta.image_view != VK_NULL_HANDLE )
            meta.destroyHandle( meta.image_view );
        with( meta.image_view_ci ) {
            image               = meta.image;
            viewType            = view_type;
            format              = view_format;
            subresourceRange    = subresource_range;
            components          = component_mapping;
        }
        meta.device.vkCreateImageView( & meta.image_view_ci, meta.allocator, & meta.image_view ).vkAssert( "Create View", file, line, func );
        return meta;
    }
}



alias  Meta_IView = Meta_IView_T!1;
struct Meta_IView_T( uint32_t view_count ) {
    mixin Vulkan_State_Pointer;
    mixin IView_Memeber!view_count;
    alias construct = constructView;


    ///
    auto ref setImage( ref Meta_Image meta_image ) {
        // assign the valid image to the image_view_ci.image member
        image_view_ci.image = meta_image.image;

        // check if view type was specified
        if( image_view_ci.viewType == VK_IMAGE_VIEW_TYPE_MAX_ENUM )
            image_view_ci.viewType = cast( VkImageViewType )meta_image.image_ci.imageType;

        // check if view format was specified
        if( image_view_ci.format == VK_FORMAT_MAX_ENUM )
            image_view_ci.format = meta_image.image_ci.format;

        return this;
    }


    auto ref setImage( VkImage image ) {
        // assign the valid image to the image_view_ci.image member
        image_view_ci.image = image;
        return this;
    }
}




// TODO(pp): create functions for VkImageSubresourceRange, VkBufferImageCopy and conversion functions between them


/// records a VkImage transition command in argument command buffer
void recordTransition(
    VkCommandBuffer         cmd_buffer,
    VkImage                 image,
    VkImageSubresourceRange subresource_range,
    VkImageLayout           old_layout,
    VkImageLayout           new_layout,
    VkAccessFlags           src_accsess_mask,
    VkAccessFlags           dst_accsess_mask,
    VkPipelineStageFlags    src_stage_mask = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
    VkPipelineStageFlags    dst_stage_mask = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
    VkDependencyFlags       dependency_flags = 0,
    ) nothrow {
    VkImageMemoryBarrier layout_transition_barrier = {
        srcAccessMask       : src_accsess_mask,
        dstAccessMask       : dst_accsess_mask,
        oldLayout           : old_layout,
        newLayout           : new_layout,
        srcQueueFamilyIndex : VK_QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex : VK_QUEUE_FAMILY_IGNORED,
        image               : image,
        subresourceRange    : subresource_range,
    };

    // Todo(pp): consider using these cases

/*  switch (old_image_layout) {
        case VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL:
            image_memory_barrier.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            break;

        case VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL:
            image_memory_barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            break;

        case VK_IMAGE_LAYOUT_PREINITIALIZED:
            image_memory_barrier.srcAccessMask = VK_ACCESS_HOST_WRITE_BIT;
            break;

        default:
            break;
    }

    switch (new_image_layout) {
        case VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            break;

        case VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            break;

        case VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            break;

        case VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            break;

        case VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL:
            image_memory_barrier.dstAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
            break;

        default:
            break;
    }
*/
    cmd_buffer.vkCmdPipelineBarrier(
        src_stage_mask, dst_stage_mask, dependency_flags,
        0, null, 0, null, 1, & layout_transition_barrier
    );
}



////////////////////////
// Meta_Image_Sampler //
////////////////////////

/// Pack Meta_Image with some count of samplers for ease of use
alias  Meta_Image_Sampler = Meta_Image_Sampler_T!1;
struct Meta_Image_Sampler_T( uint32_t sampler_count ) {
    Meta_Image meta_image;
    alias meta_image this;
    static assert( sampler_count > 0 );
    static if( sampler_count == 1 )     VkSampler                   sampler;
    else                                VkSampler[ sampler_count ]  sampler;

    // bulk destroy the resources belonging to this meta struct
    void destroyResources( bool destroy_sampler = true ) {
        meta_image.destroyResources;
        if( destroy_sampler ) {
            static  if(  sampler_count == 1 )   { if( sampler != VK_NULL_HANDLE ) vk.destroy( sampler ); }
            else    foreach( ref s; sampler )   { if( s       != VK_NULL_HANDLE ) vk.destroy( s ); }
        }
    }
}




bool is_null( Meta_Memory meta ) { return meta.memory.is_null_handle; }
bool is_null( Meta_Buffer meta ) { return meta.buffer.is_null_handle; }
bool is_null( Meta_Image  meta ) { return meta.image .is_null_handle; }

bool is_constructed( Meta_Memory meta ) { return !meta.is_null; }
bool is_constructed( Meta_Buffer meta ) { return !meta.is_null; }
bool is_constructed( Meta_Image  meta ) { return !meta.is_null; }



// checking format support
//VkFormatProperties format_properties;
//vk.gpu.vkGetPhysicalDeviceFormatProperties( VK_FORMAT_B8G8R8A8_UNORM, & format_properties );
//format_properties.printTypeInfo;

// checking image format support (additional capabilities)
//VkImageFormatProperties image_format_properties;
//vk.gpu.vkGetPhysicalDeviceImageFormatProperties(
//  VK_FORMAT_B8G8R8A8_UNORM,
//  VK_IMAGE_TYPE_2D,
//  VK_IMAGE_TILING_OPTIMAL,
//  VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
//  0,
//  & image_format_properties).vkAssert;
//image_format_properties.printTypeInfo;
