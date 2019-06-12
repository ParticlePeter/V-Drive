module vdrive.memory;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

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
        vk.destroy( device_memory );
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
    private:
    VkMemoryRequirements    memory_requirements;
    VkDeviceMemory          device_memory;
    VkDeviceSize            device_memory_offset;
    bool                    owns_device_memory = false;
    void resetMemoryMember()    {
        memory_requirements     = VkMemoryRequirements();
        device_memory           = VK_NULL_HANDLE;
        device_memory_offset    = 0;
        owns_device_memory      = false;
    }
    public:
    auto memory()           { return device_memory; }
    auto memSize()          { return memory_requirements.size; }
    auto memOffset()        { return device_memory_offset; }
    auto memRequirements()  { return memory_requirements; }
auto memoryTypeIndex( ref Meta_Buffer meta, VkMemoryPropertyFlags memory_property_flags ) {             // can't be a template function as another overload exists already (general function)
    return memoryTypeIndex( meta.memory_properties, meta.memory_requirements, memory_property_flags );
}


auto memoryTypeIndex( ref Meta_Image meta, VkMemoryPropertyFlags memory_property_flags ) {              // can't be a template function as another overload exists already (general function)
    return memoryTypeIndex( meta.memory_properties, meta.memory_requirements, memory_property_flags );
}


auto requiredMemorySize( META )( ref META meta ) if( hasMemReqs!META ) {
    return meta.memory_requirements.size;
}


auto alignedOffset( META )( ref META meta, VkDeviceSize device_memory_offset ) if( hasMemReqs!META ) {
    if( device_memory_offset % meta.memory_requirements.alignment > 0 ) {
        auto alignment = meta.memory_requirements.alignment;
        device_memory_offset = ( device_memory_offset / alignment + 1 ) * alignment;
    }
    return device_memory_offset;
}


/// allocate and bind a VkDeviceMemory object to the VkBuffer/VkImage (which must have been created beforehand) in the meta struct
/// the memory properties of the underlying VkPhysicalDevicethe are used and the resulting memory object is stored
/// The memory object is allocated of the size required by the buffer, another function overload will exist with an argument
/// for an existing memory object where the buffer is supposed to suballocate its memory from
/// the Meta_Buffer struct is returned for function chaining
auto ref createMemoryImpl( META )(
    ref META                meta,
    VkMemoryPropertyFlags   memory_property_flags,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) if( hasMemReqs!META ) {
    vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
    if( meta.device_memory != VK_NULL_HANDLE )                  // if device memory is owned and was created already
        meta.destroy( meta.device_memory );                     // we destroy it here
    meta.owns_device_memory = true;
    meta.device_memory = allocateMemory( meta, meta.memory_requirements.size, meta.memoryTypeIndex( memory_property_flags ));
    static if( is( META == Meta_Buffer ))   meta.device.vkBindBufferMemory( meta.buffer, meta.device_memory, 0 ).vkAssert( "Bind Buffer Memory", file, line, func );
    else                                    meta.device.vkBindImageMemory(  meta.image,  meta.device_memory, 0 ).vkAssert( "Bind Image Memory" , file, line, func );
    return meta;
}


auto ref bindMemoryImpl( META )(
    ref META        meta,
    VkDeviceMemory  device_memory,
    VkDeviceSize    device_memory_offset = 0,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( hasMemReqs!META ) {
    vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
    vkAssert( meta.device_memory == VK_NULL_HANDLE, "Memory can be bound only once, rebinding is not allowed", file, line, func );
    meta.owns_device_memory = false;
    meta.device_memory = device_memory;
    meta.device_memory_offset = device_memory_offset;
    static if( is( META == Meta_Buffer ))   meta.device.vkBindBufferMemory( meta.buffer, device_memory, device_memory_offset ).vkAssert( "Bind Buffer Memory", file, line, func );
    else                                    meta.device.vkBindImageMemory(  meta.image,  device_memory, device_memory_offset ).vkAssert( "Bind Image Memory" , file, line, func );
    return meta;
}


// alias buffer this (in e.g. Meta_Goemetry) does not work with the Impl functions above
// but it does work with the aliases for that functions bellow
alias createMemory = createMemoryImpl!Meta_Buffer;
alias createMemory = createMemoryImpl!Meta_Image;
alias bindMemory = bindMemoryImpl!Meta_Buffer;
alias bindMemory = bindMemoryImpl!Meta_Image;



/// map the underlying memory object and return the mapped memory pointer
auto mapMemory( META )(
    ref META            meta,
    VkDeviceSize        size    = 0,        // if 0, the meta.device_memory_size will be used
    VkDeviceSize        offset  = 0,
//  VkMemoryMapFlags    flags   = 0,        // for future use
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) if( hasMemReqs!META || is( META == Meta_Memory )) {
    // if we want to map the memory of an underlying buffer or image,
    // we need to account for the buffer or image offset into its VkDeviceMemory
    static if( is( META == Meta_Memory ))   VkDeviceSize combined_offset = offset;
    else                                    VkDeviceSize combined_offset = offset + meta.device_memory_offset;
    if( size == 0 ) size = meta.memSize;    // use the attached memory size in this case
    void* mapped_memory;
    meta.device
        .vkMapMemory( meta.device_memory, combined_offset, size, 0, &mapped_memory )
        .vkAssert( "Map Memory", file, line, func );
    return mapped_memory;
}


/// map the underlying memory object, copy the provided data into it and return the mapped memory pointer
auto mapMemory( META )(
    ref META            meta,
    void[]              data,
    VkDeviceSize        offset  = 0,
//  VkMemoryMapFlags    flags   = 0,        // for future use
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) if( hasMemReqs!META || is( META == Meta_Memory )) {
    // if we want to map the memory of an underlying buffer or image,
    // we need to account for the buffer or image offset into its VkDeviceMemory
    static if( is( META == Meta_Memory ))   VkDeviceSize combined_offset = offset;
    else                                    VkDeviceSize combined_offset = offset + meta.device_memory_offset;

    // the same combined_offset logic is applied in the function bellow, so we must pass
    // the original offset to not apply the Meta_Buffer or Meta_Image.device_memory_offset twice
    auto mapped_memory = meta.mapMemory( meta.device_memory, data.length, combined_offset, file, line, func );
    mapped_memory[ 0 .. data.length ] = data[];

    // required for the mapped memory flush
    VkMappedMemoryRange mapped_memory_range =
        meta.createMappedMemoryRange( meta.device_memory, data.length, combined_offset, file, line, func );

    // flush the mapped memory range so that its visible to the device memory space
    meta.device
        .vkFlushMappedMemoryRanges( 1, &mapped_memory_range )
        .vkAssert( "Map Memory", file, line, func );
    return mapped_memory;
}


/// unmap map the underlying memory object
auto ref unmapMemory( META )( ref META meta ) if( hasMemReqs!META || is( META == Meta_Memory )) {
    meta.device.vkUnmapMemory( meta.device_memory );
    return meta;
}


/// create a mapped memory range with given size and offset for the (backing) memory object
/// the offset into the buffer or image backing VkMemory will be added to the passed in offset
/// and the size will be determined from buffer/image.memSize in case of VK_WHOLE_SIZE
auto createMappedMemoryRange( META )(
    ref META            meta,
    VkDeviceSize        size    = VK_WHOLE_SIZE,
    VkDeviceSize        offset  = 0,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) if( hasMemReqs!META || is( META == Meta_Memory )) {
    // if we want to create a mapped memory range for the memory of an underlying buffer or image,
    // we need to account for the buffer or image offset into its VkDeviceMemory
    static if( hasMemReqs!META  ) {
        offset += meta.memOffset;
        if( size == VK_WHOLE_SIZE ) {
            size = meta.memSize;
        }
    }
    return meta.createMappedMemoryRange( meta.device_memory, size, offset, file, line, func );
}


/// flush the memory object, either whole size or with offset and size
/// memory must have been mapped beforehand
auto ref flushMappedMemoryRange( META )(
    ref META            meta,
    VkDeviceSize        size    = VK_WHOLE_SIZE,
    VkDeviceSize        offset  = 0,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) if( hasMemReqs!META || is( META == Meta_Memory )) {
    vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
    auto mapped_memory_range = meta.createMappedMemoryRange( size, offset );
    meta.device.vkFlushMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Flush Mapped Memory Range", file, line, func );
    return meta;
}


/// invalidate the memory object, either whole size or with offset and size
/// memory must have been mapped beforehand
auto ref invalidateMappedMemoryRange( META )(
    ref META            meta,
    VkDeviceSize        size    = VK_WHOLE_SIZE,
    VkDeviceSize        offset  = 0,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) if( hasMemReqs!META || is( META == Meta_Memory )) {
    vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
    auto mapped_memory_range = meta.createMappedMemoryRange( size, offset );
    meta.device.vkInvalidateMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Invalidate Mapped Memory Range", file, line, func );
    return meta;
}



/// upload data to the VkDeviceMemory object of the coresponding buffer or image through memory mapping
auto ref copyData( META )(
    ref META            meta,
    void[]              data,
    VkDeviceSize        offset  = 0,
//  VkMemoryMapFlags    flags   = 0,        // for future use
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) if( hasMemReqs!META || is( META == Meta_Memory )) {
    meta.mapMemory( data, offset, file, line, func );   // this returns the memory pointer, and not the Meta_Struct
    return meta.unmapMemory;
}



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
    VkBufferCreateInfo      buffer_create_info;
    VkDeviceSize            bufferSize() { return buffer_create_info.size; }
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

}


/// initialize a VkBuffer object, this function or createBuffer must be called first, further operations require the buffer
/// the resulting buffer and its create info are stored in the Meta_Buffer struct
/// the Meta_Buffer struct is returned for function chaining
auto ref initBuffer(
    ref Meta_Buffer     meta,
    VkBufferUsageFlags  usage,
    VkDeviceSize        size,
    VkSharingMode       sharing_mode = VK_SHARING_MODE_EXCLUSIVE,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
    // assert that meta struct is initialized with a valid vulkan state pointer
    vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );

    // buffer create info from arguments
    meta.buffer_create_info.size        = size; // size in Bytes
    meta.buffer_create_info.usage       = usage;
    meta.buffer_create_info.sharingMode = sharing_mode;

    meta.device.vkCreateBuffer( &meta.buffer_create_info, meta.allocator, &meta.buffer ).vkAssert( "Init Buffer", file, line, func );
    meta.device.vkGetBufferMemoryRequirements( meta.buffer, &meta.memory_requirements );

    return meta;
}

alias create = initBuffer;


/// create a VkBuffer object, this function or initBuffer (or its alias create) must be called first, further operations require the buffer
/// the resulting buffer and its create info are stored in the Meta_Buffer struct
/// the Meta_Buffer struct is returned for function chaining
auto createBuffer( ref Vulkan vk, VkBufferUsageFlags usage, VkDeviceSize size, VkSharingMode sharing_mode = VK_SHARING_MODE_EXCLUSIVE ) {
    Meta_Buffer meta = vk;
    meta.create( usage, size, sharing_mode );
    return meta;
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

/// struct to capture image and memory creation as well as binding
/// the struct can travel through several methods and can be filled with necessary data
/// first thing after creation of this struct must be the assignment of the address of a valid vulkan state struct
struct Meta_Image {
    mixin                   Vulkan_State_Pointer;
    VkImage                 image = VK_NULL_HANDLE;
    VkImageCreateInfo       image_create_info;
    VkImageView             image_view = VK_NULL_HANDLE;
    VkImageViewCreateInfo   image_view_create_info;
    mixin                   Memory_Member;
    mixin                   Memory_Buffer_Image_Common;
    version( DEBUG_NAME )   string name;

    // get internal image view and reset it to VK_NULL_HANDLE
    // such that a new, different view can be created
    auto resetView() {
        auto result = image_view;
        image_view = VK_NULL_HANDLE;
        return result;
    }

    // image_create_info extent shortcut
    auto const ref extent() {
        return image_create_info.extent;
    }

    // image_view_create_info subrescourceRange shortcut
    auto const ref subresourceRange() {
        return image_view_create_info.subresourceRange;
    }

    // bulk destroy the resources belonging to this meta struct
    void destroyResources() {
        vk.destroy( image );
        if( owns_device_memory )                            vk.destroy( device_memory );
        if( image_view != VK_NULL_HANDLE )                  vk.destroy( image_view );
        resetMemoryMember;
    }
}



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

    VkImageCreateInfo image_create_info = {
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

    return meta.create( image_create_info, file, line, func );
}


/// init a VkImage, general create image function, gets a VkImageCreateInfo as argument
/// store vulkan data in argument Meta_Image container, return container for chaining
auto ref initImage(
    ref Meta_Image              meta,
    const ref VkImageCreateInfo image_create_info,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    vkAssert( meta.isValid, "Vulkan state not assigned", file, line, func );     // meta struct must be initialized with a valid vulkan state pointer

    if( meta.image != VK_NULL_HANDLE )                      // if an VkImage was created with this meta struct already
        meta.destroy( meta.image );                         // destroy it first

    meta.image_create_info = image_create_info;
    meta.device.vkCreateImage( &meta.image_create_info, meta.allocator, &meta.image ).vkAssert( "Init Image", file, line, func );
    meta.device.vkGetImageMemoryRequirements( meta.image, &meta.memory_requirements );
    return meta;
}

alias create = initImage;

// Todo(pp): add chained functions to edit the meta.image_create_info and finalize with construct(), see module pipeline



/*
/// init a simple VkImage with one level and one layer, sharing_family_queue_indices controls the sharing mode
/// store vulkan data in argument Meta_Image container, return container for chaining
auto createImage(
    ref Vulkan              vk,
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
    Meta_Image meta = vk;
    meta.create(    // depth = 0 signals that we want an VK_IMAGE_TYPE_2D
        format, width, height, 0, 1, 1, usage, samples,
        tiling, initial_layout, sharing_family_queue_indices, flags,
        file, line, func );
    return meta;
}


/// init a VkImage, sharing_family_queue_indices controls the sharing mode
/// store vulkan data in argument Meta_Image container, return container for chaining
auto createImage(
    ref Vulkan              vk,
    VkFormat                format,
    uint32_t                width,
    uint32_t                height,
    uint32_t                depth,
    uint32_t                mip_levels,
    uint32_t                array_layers,
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
    Meta_Image meta = vk;
    meta.create(    // height = 0 signals we want an VK_IMAGE_TYPE_1D, else depth = 0 signals we want an VK_IMAGE_TYPE_2D, else VK_IMAGE_TYPE_3D
        format, width, height, depth, mip_levels, array_layers, usage, samples,
        tiling, initial_layout, sharing_family_queue_indices, flags,
        file, line, func );
    return meta;
}


/// create a VkImage, general init image function, gets a VkImageCreateInfo as argument
/// store vulkan data in argument Meta_Image container, return container for chaining
auto createImage(
    ref Vulkan                  vk,
    const ref VkImageCreateInfo image_create_info,
    string                      file = __FILE__,
    size_t                      line = __LINE__,
    string                      func = __FUNCTION__
    ) {
    Meta_Image meta = vk;
    meta.create( image_create_info, file, line, func );
    return meta;
}
*/

// TODO(pp): assert that valid memory was bound already to the VkBuffer or VkImage

/// create a VkImageView which closely corresponds to the underlying VkImage type
/// store vulkan data in argument Meta_Image container, return container for chaining
auto ref createView( ref Meta_Image meta, VkImageAspectFlags subrecource_aspect_mask = VK_IMAGE_ASPECT_COLOR_BIT ) {
    VkImageSubresourceRange subresource_range = {
        aspectMask      : subrecource_aspect_mask,
        baseMipLevel    : cast( uint32_t )0,
        levelCount      : meta.image_create_info.mipLevels,
        baseArrayLayer  : cast( uint32_t )0,
        layerCount      : meta.image_create_info.arrayLayers, };
    return meta.createView( subresource_range );
}

/// create a VkImageView which closely coresponds to the underlying VkImage type
/// store vulkan data in argument Meta_Image container, return container for chaining
auto ref createView( ref Meta_Image meta, VkImageSubresourceRange subresource_range ) {
    return meta.createView( subresource_range, cast( VkImageViewType )meta.image_create_info.imageType, meta.image_create_info.format );
}

/// create a VkImageView with choosing an image view type and format for the underlying VkImage, component mapping is identity
/// store vulkan data in argument Meta_Image container, return container for chaining
auto ref createView( ref Meta_Image meta, VkImageSubresourceRange subresource_range, VkImageViewType view_type, VkFormat view_format ) {
    return meta.createView( subresource_range, view_type, view_format, VkComponentMapping(
        VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY ));
}

/// create a VkImageView with choosing an image view type, format and VkComponentMapping for the underlying VkImage
/// store vulkan data in argument Meta_Image container, return container for chaining
auto ref createView(
    ref Meta_Image          meta,
    VkImageSubresourceRange subresource_range,
    VkImageViewType         view_type,
    VkFormat                view_format,
    VkComponentMapping      component_mapping,
    string                  file = __FILE__,
    size_t                  line = __LINE__,
    string                  func = __FUNCTION__
    ) {
    if( meta.image_view != VK_NULL_HANDLE )
        meta.destroy( meta.image_view );
    with( meta.image_view_create_info ) {
        image               = meta.image;
        viewType            = view_type;
        format              = view_format;
        subresourceRange    = subresource_range;
        components          = component_mapping;
    }
    meta.device.vkCreateImageView( &meta.image_view_create_info, meta.allocator, &meta.image_view ).vkAssert( "Create View", file, line, func );
    return meta;
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
