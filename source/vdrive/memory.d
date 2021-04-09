module vdrive.memory;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.image;
import vdrive.buffer;

import erupted;


nothrow @nogc:


//////////////////////////////
// general memory functions //
//////////////////////////////

/// get the memory properties for a given physical device (gpu)
VkPhysicalDeviceMemoryProperties memoryProperties( VkPhysicalDevice gpu ) {
    VkPhysicalDeviceMemoryProperties memory_properties;
    vkGetPhysicalDeviceMemoryProperties( gpu, & memory_properties );
    return memory_properties;
}

/// get the memory properties of the Vulkan states internal physical device (vk.gpu)
VkPhysicalDeviceMemoryProperties memoryProperties( ref Vulkan vk ) {
    return vk.gpu.memoryProperties;
}


/// memory_type_bits is a bit-field where if bit i is set, it means that the VkMemoryType i
/// of the VkPhysicalDeviceMemoryProperties structure satisfies the memory requirements.
uint32_t memoryTypeIndex(
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
uint32_t memoryHeapIndex(
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
uint32_t hasMemoryHeapType( VkPhysicalDeviceMemoryProperties memory_properties, VkMemoryHeapFlags memory_heap_flags ) {
    return memoryHeapIndex( memory_properties, memory_heap_flags ) < uint32_t.max;
}



/// Query the memory heap size of a given memory heap (index).
VkDeviceSize memoryHeapSize( VkPhysicalDeviceMemoryProperties memory_properties, uint32_t memory_heap_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    vkAssert( memory_heap_index < memory_properties.memoryHeapCount, "Memory Heap Index out of bounds", file, line, func );
    return memory_properties.memoryHeaps[ memory_heap_index ].size;
}



/// Allocate device memory from a given memory type (index).
VkDeviceMemory allocateMemory(
    ref Vulkan      vk,
    VkDeviceSize    allocation_size,
    uint32_t        memory_type_index,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) {

    // construct a memory allocation info from arguments
    VkMemoryAllocateInfo memory_ai = {
        allocationSize  : allocation_size,
        memoryTypeIndex : memory_type_index,
    };

    // allocate device memory
    VkDeviceMemory device_memory;
    vkAllocateMemory( vk.device, & memory_ai, vk.allocator, & device_memory ).vkAssert( "Allocate Memory", file, line, func );

    return device_memory;
}



/// Map allocated memory.
void* mapMemory(
    ref Vulkan          vk,
    VkDeviceMemory      memory,
    VkDeviceSize        offset  = 0,
    VkDeviceSize        size    = VK_WHOLE_SIZE,
    VkMemoryMapFlags    flags   = 0,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    void* mapped_memory;
    vk.device.vkMapMemory( memory, offset, size, flags, & mapped_memory ).vkAssert( "Map Memory", file, line, func );
    return mapped_memory;
}



/// Unmap allocated memory.
ref Vulkan unmapMemory( ref return Vulkan vk, VkDeviceMemory memory ) {
    vk.device.vkUnmapMemory( memory );
    return vk;
}



/// Create a VkMappedMemoryRange and initialize struct.
VkMappedMemoryRange createMappedMemoryRange(
    VkDeviceMemory      memory,
    VkDeviceSize        offset  = 0,
    VkDeviceSize        size    = VK_WHOLE_SIZE,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    VkMappedMemoryRange mapped_memory_range = {
        memory  : memory,
        offset  : offset,
        size    : size,
    };
    return mapped_memory_range;
}



/// Flush a mapped memory range.
ref Vulkan flushMappedMemoryRange(
    ref return Vulkan   vk,
    VkDeviceMemory      memory,
    VkDeviceSize        offset  = 0,
    VkDeviceSize        size    = VK_WHOLE_SIZE,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    auto mapped_memory_range = createMappedMemoryRange( memory, offset, size, file, line, func );
    vk.device.vkFlushMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Flush Mapped Memory Range", file, line, func );
    return vk;
}



/// Flush a mapped memory range.
ref Vulkan flushMappedMemoryRange(
    ref return Vulkan               vk,
    const ref VkMappedMemoryRange   mapped_memory_range,
    string                          file = __FILE__,
    size_t                          line = __LINE__,
    string                          func = __FUNCTION__
    ) {
    vk.device.vkFlushMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Flush Mapped Memory Range", file, line, func );
    return vk;
}



/// Flush multiple mapped memory ranges.
ref Vulkan flushMappedMemoryRanges(
    ref return Vulkan               vk,
    const ref VkMappedMemoryRange[] mapped_memory_ranges,
    string                          file = __FILE__,
    size_t                          line = __LINE__,
    string                          func = __FUNCTION__
    ) {
    vk.device.vkFlushMappedMemoryRanges( mapped_memory_ranges.length.toUint, mapped_memory_ranges.ptr ).vkAssert( "Flush Mapped Memory Ranges", file, line, func );
    return vk;
}



/// Invalidate a mapped memory range.
ref Vulkan invalidateMappedMemoryRange(
    ref return Vulkan   vk,
    VkDeviceMemory      memory,
    VkDeviceSize        size    = VK_WHOLE_SIZE,
    VkDeviceSize        offset  = 0,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    auto mapped_memory_range = createMappedMemoryRange( memory, offset, size, file, line, func );
    vk.device.vkInvalidateMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Flush Mapped Memory Range", file, line, func );
    return vk;
}



/// Invalidate a mapped memory range.
ref Vulkan invalidateMappedMemoryRange(
    ref return Vulkan               vk,
    const ref VkMappedMemoryRange   mapped_memory_range,
    string                          file = __FILE__,
    size_t                          line = __LINE__,
    string                          func = __FUNCTION__
    ) {
    vk.device.vkInvalidateMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Flush Mapped Memory Range", file, line, func );
    return vk;
}



/// Invalidate multiple mapped memory ranges.
ref Vulkan invalidateMappedMemoryRanges(
    ref return Vulkan               vk,
    const ref VkMappedMemoryRange[] mapped_memory_ranges,
    string                          file = __FILE__,
    size_t                          line = __LINE__,
    string                          func = __FUNCTION__
    ) {
    vk.device.vkInvalidateMappedMemoryRanges( mapped_memory_ranges.length.toUint, mapped_memory_ranges.ptr ).vkAssert( "Flush Mapped Memory Ranges", file, line, func );
    return vk;
}



/// Template to detect Meta_Memory, _Buffer, _Image
package template hasMemReqs( T ) {
    enum hasMemReqs = __traits( hasMember, T, "memory_requirements" );
}




///////////////////////////////////////
// Meta_Memory and related functions //
///////////////////////////////////////

struct Meta_Memory {
    nothrow @nogc:
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
    auto ref addRange( META )( ref META meta_resource, VkDeviceSize* io_memory_size = null, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        static if( isDataArrayOrSlice!META ) {
            foreach( ref resource; meta_resource ) {
                addRange( resource, io_memory_size, file, line, func );
            }
        } else static if( hasMemReqs!META ) {
            // confirm that VkMemoryPropertyFlags have been specified with memoryType;
            vkAssert( memory_property_flags > 0, "No memoryType (VkMemoryPropertyFlags) specified.", file, line, func, "Call memoryType( VkMemoryPropertyFlags ) before adding a range." );

            // get the resource dependent memory type index
            // the lower memory type indexes are subsets of the higher type indexes regarding the memory properties
            auto resource_type_index = meta_resource.memoryTypeIndex( memory_property_flags );
            if( memory_type_index < resource_type_index ) memory_type_index = resource_type_index;

            // register the required memory size range, either internally in the meta struct
            // or in the optionally passed in pointer to an external io_memory_size
            if( io_memory_size is null ) {
                meta_resource.device_memory_offset = meta_resource.alignedOffset( device_memory_size );
                device_memory_size = meta_resource.device_memory_offset + meta_resource.requiredMemorySize;
            } else {
                *io_memory_size = meta_resource.alignedOffset( *io_memory_size ) + meta_resource.requiredMemorySize;
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
    auto ref bind( META )( ref META meta_resource, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__, ) {
        static if( isDataArrayOrSlice!META ) {
            vkAssert( device_memory != VK_NULL_HANDLE, "No memory allocated for resources.", file, line, func, "Must call allocate() before bind()ing a buffers or images." );
            foreach( ref resource; meta_resource ) {
                resource.bindMemory( device_memory, resource.device_memory_offset, file, line, func );
            }
        } else static if( hasMemReqs!META ) {
            // confirm that memory for this resource has been allocated
            vkAssert( device_memory != VK_NULL_HANDLE, "No memory allocated for resource.", file, line, func, "Must call allocate() before bind()ing a buffer or image." );
            meta_resource.bindMemory( device_memory, meta_resource.device_memory_offset, file, line, func );
        } else {
            static assert(0);   // types not matching
        }
        return this;
    }


    /// Add ranges, allocate one memory chunk and bind the memory ranges in one go. Ranges are tightly packed
    /// but obey alignment constraints. Method accepts var args of Meta_Buffer, Meta_Image or Slices/Arrays of the same.
    auto ref allocateAndBind( Args... )( ref Args args, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {

        foreach(  ref arg; args )
            addRange( arg, null, file, line, func );

        allocate;

        foreach(  ref arg; args )
            bind( arg, file, line, func );

        return this;
    }


    /// Check if the Vulkan resource VkDeviceMemory is null.
    bool is_null() { return device_memory.is_null_handle; }
}



/// template to mixin common decelerations of Meta_Memory, _Buffer and _Image
package mixin template Memory_Buffer_Image_Common() {

    /// map the underlying memory object and return the mapped memory pointer
    void* mapMemory(
        VkDeviceSize        offset  = 0,
        VkDeviceSize        size    = 0,        // if 0, the device_memory_size will be used
        VkMemoryMapFlags    flags   = 0,        // for future use
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        // if we want to map the memory of an underlying buffer or image,
        // we need to account for the buffer or image offset into its VkDeviceMemory
        static if( is( typeof( this ) == Meta_Memory )) VkDeviceSize combined_offset = offset;
        else                                            VkDeviceSize combined_offset = offset + device_memory_offset;

        // use the passed in size only if it's greater 0, else the internal memory's size
        VkDeviceSize data_size = size > 0 ? size : memSize;
        void* mapped_memory;

        vk.device
            .vkMapMemory( device_memory, combined_offset, data_size, flags, & mapped_memory )
            .vkAssert( "Map Memory", file, line, func );
        return mapped_memory;
    }


    /// map the underlying memory object into mapped_memory param and return reference to the Meta_Struct
    auto ref mapMemory( T )(
        ref T*              mapped_memory,
        VkDeviceSize        offset  = 0,
        VkDeviceSize        size    = 0,        // if 0, the device_memory_size will be used
        VkMemoryMapFlags    flags   = 0,        // for future use
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        mapped_memory = cast( T* )mapMemory( offset, size, flags, file, line, func );
        return this;
    }


    /// map the underlying memory object, copy the provided data into it and return the mapped memory pointer
    void* mapMemory(
        void[]              data,
        VkDeviceSize        offset  = 0,
        VkDeviceSize        size    = 0,        // if 0, the passed in data's size will be used
        VkMemoryMapFlags    flags   = 0,        // for future use
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
        void* mapped_memory = vk.mapMemory( device_memory, combined_offset, data.length, flags, file, line, func );
        mapped_memory[ 0 .. data.length ] = data[];

        // required for the mapped memory flush
        VkDeviceSize data_size = size > 0 ? size : data.length;
        VkMappedMemoryRange mapped_memory_range =
            .createMappedMemoryRange( device_memory, combined_offset, data_size, file, line, func );

        // flush the mapped memory range so that its visible to the device memory space
        vk.device
            .vkFlushMappedMemoryRanges( 1, & mapped_memory_range )
            .vkAssert( "Map Memory", file, line, func );
        return mapped_memory;
    }


    /// map the underlying memory object into mapped_memory param, copy the provided data into it and return reference to the Meta_Struct
    auto ref mapMemory( T )(
        ref T*              mapped_memory,
        void[]              data,
        VkDeviceSize        offset  = 0,
        VkMemoryMapFlags    flags   = 0,        // for future use
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        mapped_memory = cast( T* )mapMemory( data, offset, flags, file, line, func );
        return this;
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
        VkDeviceSize        offset  = 0,
        VkDeviceSize        size    = VK_WHOLE_SIZE,
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
        return .createMappedMemoryRange( device_memory, offset, size, file, line, func );
    }


    /// flush the memory object, either whole size or with offset and size
    /// memory must have been mapped beforehand
    auto ref flushMappedMemoryRange(
        VkDeviceSize        offset  = 0,
        VkDeviceSize        size    = VK_WHOLE_SIZE,
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
        auto mapped_memory_range = createMappedMemoryRange( offset, size, file, line, func );
        vk.device.vkFlushMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Flush Mapped Memory Range", file, line, func );
        return this;
    }


    /// invalidate the memory object, either whole size or with offset and size
    /// memory must have been mapped beforehand
    auto ref invalidateMappedMemoryRange(
        VkDeviceSize        offset  = 0,
        VkDeviceSize        size    = VK_WHOLE_SIZE,
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
        auto mapped_memory_range = createMappedMemoryRange( offset, size, file, line, func );
        vk.device.vkInvalidateMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( "Invalidate Mapped Memory Range", file, line, func );
        return this;
    }


    /// upload data to the VkDeviceMemory object of the corresponding buffer or image through memory mapping
    auto ref copyData(
        void[]              data,
        VkDeviceSize        offset  = 0,
        VkDeviceSize        size    = 0,        // if 0, the passed in data's size will be used
        VkMemoryMapFlags    flags   = 0,        // for future use
        string              file    = __FILE__,
        size_t              line    = __LINE__,
        string              func    = __FUNCTION__
        ) {
        mapMemory( data, offset, size, flags, file, line, func );   // this returns the memory pointer, and not the Meta_Struct
        return unmapMemory;
    }
}


/// template to mixin common memory related decelerations of Meta_Buffer and Meta_Image
mixin template Memory_Member() {
    package:
    VkMemoryRequirements    memory_requirements;    // Todo(pp): remove this member
    VkDeviceMemory          device_memory;
    VkDeviceSize            device_memory_offset;
    bool                    owns_device_memory = false;
    VkDeviceMemory resetMemory() {
        memory_requirements     = VkMemoryRequirements();
        auto   memory           = device_memory;
        device_memory           = VK_NULL_HANDLE;
        device_memory_offset    = 0;
        owns_device_memory      = false;
        return memory;
    }
    public:
    auto memory()           { return device_memory; }
    auto memOffset()        { return device_memory_offset; }
    auto memSize()          { return memory_requirements.size; }
    auto memRequirements()  { return memory_requirements; }


    auto memoryTypeIndex( VkMemoryPropertyFlags memory_property_flags ) {
        auto mem_props = vk.memory_properties;
        return mem_props.memoryTypeIndex( memory_requirements, memory_property_flags );
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

        static import vdrive.buffer, vdrive.image;  // without the static import of vdrive.buffer the isMetaBuffer template cannot be found. DMD bug?
             static if( vdrive.buffer.isMetaBuffer!(typeof( this )))  vk.device.vkBindBufferMemory( buffer, device_memory, 0 ).vkAssert( "Bind Buffer Memory", file, line, func );
        else static if( vdrive.image .isMetaImage!( typeof( this )))  vk.device.vkBindImageMemory(  image,  device_memory, 0 ).vkAssert( "Bind Image Memory" , file, line, func );
        else static assert( 0, "Memory Member can only be mixed into Meta_Memory, Meta_Buffer or Meta_Image_T, but found: " ~ typeof( this ).stringof );
        return this;
    }


    auto ref bindMemory( VkDeviceMemory device_memory, VkDeviceSize memory_offset = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( isValid, "Vulkan state not assigned", file, line, func );       // meta struct must be initialized with a valid vulkan state pointer
        vkAssert( this.device_memory == VK_NULL_HANDLE, "Memory already bound to object: ", file, line, func );

        this.owns_device_memory = false;
        this.device_memory = device_memory;
        this.device_memory_offset = memory_offset;

        import vdrive.buffer;   // ??? Compilation error without this import, isMetaBuffer is unknown, but isMetaImage not ???
        static      if( isMetaBuffer!(typeof( this )))  vk.device.vkBindBufferMemory( buffer, device_memory, memory_offset ).vkAssert( "Bind Buffer Memory", file, line, func );
        else static if( isMetaImage!( typeof( this )))  vk.device.vkBindImageMemory(  image,  device_memory, memory_offset ).vkAssert( "Bind Image Memory" , file, line, func );
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