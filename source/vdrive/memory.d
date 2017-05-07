module vdrive.memory;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;



//////////////////////////////
// general memory functions //
//////////////////////////////

// memory_type_bits is a bitfield where if bit i is set, it means that the VkMemoryType i
// of the VkPhysicalDeviceMemoryProperties structure satisfies the memory requirements
auto memoryTypeIndex(
    VkPhysicalDeviceMemoryProperties    memory_properties,
    VkMemoryRequirements                memory_requirements,
    VkMemoryPropertyFlags               memory_property_flags
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


auto memoryHeapIndex(
    VkPhysicalDeviceMemoryProperties    memory_properties,
    VkMemoryHeapFlags                   memory_heap_flags,
    uint32_t                            first_memory_heap_index = 0
    ) {
    vkAssert( first_memory_heap_index < memory_properties.memoryHeapCount );
    foreach( i; first_memory_heap_index .. memory_properties.memoryHeapCount ) {
        if(( memory_properties.memoryHeaps[i].flags & memory_heap_flags ) == memory_heap_flags ) {
            return i.toUint;
        }
    } return uint32_t.max;
}


auto hasMemoryHeapType(
    VkPhysicalDeviceMemoryProperties    memory_properties,
    VkMemoryHeapFlags                   memory_heap_flags
    ) {
    return memoryHeapIndex( memory_properties, memory_heap_flags ) < uint32_t.max;
}


auto memoryHeapSize(
    VkPhysicalDeviceMemoryProperties    memory_properties,
    uint32_t                            memory_heap_index
    ) {
    vkAssert( memory_heap_index < memory_properties.memoryHeapCount );
    return memory_properties.memoryHeaps[ memory_heap_index ].size;
}


auto allocateMemory( ref Vulkan vk, VkDeviceSize allocation_size, uint32_t memory_type_index ) {
    // construct a memory allocation info from arguments
    VkMemoryAllocateInfo memory_allocate_info = {
        allocationSize  : allocation_size,
        memoryTypeIndex : memory_type_index,
    };

    // allocate device memory
    VkDeviceMemory device_memory;
    vkAllocateMemory( vk.device, &memory_allocate_info, vk.allocator, &device_memory ).vkAssert;

    return device_memory;
}


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
    vk.device.vkMapMemory( memory, offset, size, flags, &mapped_memory ).vkAssert( file, line, func );
    return mapped_memory;
}


void unmapMemory( ref Vulkan vk, VkDeviceMemory memory ) {
    vk.device.vkUnmapMemory( memory );
}


auto createMappedMemoryRange(
    ref Vulkan          vk,
    VkDeviceMemory      memory,
    VkDeviceSize        size    = 0,
    VkDeviceSize        offset  = 0,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) {
    VkMappedMemoryRange mapped_memory_range = {
        memory  : memory,
        size    : size > 0 ? size : VK_WHOLE_SIZE,
        offset  : offset,
    };
    return mapped_memory_range;
}


void flushMappedMemoryRange(
    ref Vulkan              vk,
    VkMappedMemoryRange     mapped_memory_range,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    vk.device.vkFlushMappedMemoryRanges( 1, & mapped_memory_range ).vkAssert( file, line, func );
}


void flushMappedMemoryRanges(
    ref Vulkan              vk,
    VkMappedMemoryRange[]   mapped_memory_ranges,
    string                  file    = __FILE__,
    size_t                  line    = __LINE__,
    string                  func    = __FUNCTION__
    ) {
    vk.device.vkFlushMappedMemoryRanges( mapped_memory_ranges.length.toUint, mapped_memory_ranges.ptr ).vkAssert( file, line, func );
}


///////////////////////////////////////
// Meta_Memory and related functions //
///////////////////////////////////////

struct Meta_Memory {
    mixin                   Vulkan_State_Pointer;
    private:
    VkDeviceMemory          device_memory;
    VkDeviceSize            device_memory_size = 0;
    VkMemoryPropertyFlags   memory_property_flags = 0;
    uint32_t                memory_type_index;

    public:
    auto memory()           { return device_memory; }
    auto memSize()          { return device_memory_size; }
    auto memPropertyFlags() { return memory_property_flags; }
    auto memTypeIndex()     { return memory_type_index; }

    // bulk destroy the resources belonging to this meta struct
    void destroyResources() {
        vk.destroy( device_memory );
    }
}


auto ref initMemory(
    ref Meta_Memory         meta,
    uint32_t                memory_type_index,
    VkDeviceSize            allocation_size
    ) {
    vkAssert( meta.isValid, "Vulkan state not assigned" );     // assert that meta struct is initialized with a valid vulkan state pointer
    meta.device_memory = allocateMemory( meta, allocation_size, memory_type_index );
    meta.device_memory_size = allocation_size;
    meta.memory_type_index = memory_type_index;
    return meta;
}

alias create = initMemory;



auto createMemory( ref Vulkan vk, uint32_t memory_type_index, VkDeviceSize allocation_size ) {
    Meta_Memory meta = vk;
    meta.create( memory_type_index, allocation_size );
    return meta;
}



auto ref memoryType( ref Meta_Memory meta, VkMemoryPropertyFlags memory_property_flags ) {
    meta.memory_property_flags = memory_property_flags;
    return meta;
}


/// Here we use a trick, we set a very memory type with the lowest index
/// but set the (same or higher) index manually, the index can be only increased but not decreased
auto ref memoryTypeIndex( ref Meta_Memory meta, uint32_t minimum_index ) {
    if( meta.memory_property_flags == 0 ) meta.memory_property_flags = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
    meta.memory_type_index = minimum_index;
    return meta;
}


auto ref addRange( META )( ref Meta_Memory meta, ref META meta_resource ) if( hasMemReqs!META ) {
    // confirm that VkMemoryPropertyFlags have been specified with memoryType;
    vkAssert( meta.memory_property_flags > 0, "Call memoryType( VkMemoryPropertyFlags ) before adding a range" );

    // get the resource dependent memory type index
    // the lower memory type indices are subsets of the higher type indices regarding the memory properties
    auto resource_type_index = meta_resource.memoryTypeIndex( meta.memory_property_flags );
    if( meta.memory_type_index < resource_type_index ) meta.memory_type_index = resource_type_index;

    // register the require memory size range
    meta_resource.device_memory_offset = meta_resource.alignedOffset( meta.device_memory_size );
    meta.device_memory_size = meta_resource.device_memory_offset + meta_resource.requiredMemorySize;

    return meta;
}


auto ref addRanges( META )( ref Meta_Memory meta, META[] meta_resource ) if( hasMemReqs!META ) {
    foreach( ref resource; meta_resources ) meta.addRange( resource );
    return meta;
}


auto ref allocate( ref Meta_Memory meta ) {
    vkAssert( meta.isValid, "Vulkan state not assigned" );     // meta struct must be initialized with a valid vulkan state pointer
    vkAssert( meta.device_memory_size > 0, "Must call addRange() at least onece before calling allocate()" );
    meta.device_memory = allocateMemory( meta, meta.device_memory_size, meta.memory_type_index );
    return meta;
}


auto ref bind( META )( ref Meta_Memory meta, ref META meta_resource ) if( hasMemReqs!META ) {
    vkAssert( meta.device_memory != VK_NULL_HANDLE, "Must allocate() before bind()ing a buffer or image" );        // meta struct must be initialized with a valid vulkan state pointer
    meta_resource.bindMemory( meta.device_memory, meta_resource.device_memory_offset );
    return meta;
}


auto ref bind( META )( ref Meta_Memory meta, META[] meta_resource ) if( hasMemReqs!META ) {
    foreach( ref resource; meta_resources ) meta.bind( resource );
    return meta;
}



// Todo(pp): this and the one bellow should become one function with varargs of
// Meta_Buffer, Meta_Image, slices of them and slices of pointers to them
auto ref initMemoryImpl( META_BUFFER_OR_IMAGE )(
    ref Meta_Memory         meta,
    VkMemoryPropertyFlags   memory_property_flags,
    META_BUFFER_OR_IMAGE[]  meta_buffers_or_images,
    ) if( is( META_BUFFER_OR_IMAGE == Meta_Buffer ) || is( META_BUFFER_OR_IMAGE == Meta_Buffer* )
      ||  is( META_BUFFER_OR_IMAGE == Meta_Image  ) || is( META_BUFFER_OR_IMAGE == Meta_Image*  )) {

    import std.traits : isPointer;
    meta.memory_property_flags = memory_property_flags;

    foreach( ref mboi; meta_buffers_or_images )
        static if( isPointer!META_BUFFER_OR_IMAGE ) meta.addRange( *mboi );
        else                                        meta.addRange(  mboi );

    meta.allocate;

    foreach( ref mboi; meta_buffers_or_images )
        static if( isPointer!META_BUFFER_OR_IMAGE ) meta.bind( *mboi );
        else                                        meta.bind(  mboi );

    return meta;
}


// alias buffer this (in e.g. Meta_Goemetry) does not work with the Impl functions above
// but it does work with the aliases for that functions bellow
alias initMemory = initMemoryImpl!( Meta_Image );
alias initMemory = initMemoryImpl!( Meta_Image* );
alias initMemory = initMemoryImpl!( Meta_Buffer );
alias initMemory = initMemoryImpl!( Meta_Buffer* );


// Todo(pp): this and the one above should become one function with varargs of
// Meta_Buffer, Meta_Image, slices of them and slices of pointers to them
auto ref initMemoryImpl( META_BUFFER, META_IMAGE )(
    ref Meta_Memory         meta,
    VkMemoryPropertyFlags   memory_property_flags,
    META_BUFFER[]           meta_buffers,
    META_IMAGE[]            meta_images
    ) if(( is( META_BUFFER == Meta_Buffer ) || is( META_BUFFER == Meta_Buffer* ))
      && ( is( META_IMAGE  == Meta_Image  ) || is( META_IMAGE  == Meta_Image*  ))) {

    import std.traits : isPointer;
    meta.memory_property_flags = memory_property_flags;

    foreach( ref mb; meta_buffers )
        static if( isPointer!META_BUFFER )  meta.addRange( *mb );
        else                                meta.addRange(  mb );
    foreach( ref mi; meta_images )
        static if( isPointer!META_IMAGE )   meta.addRange( *mi );
        else                                meta.addRange(  mi );

    meta.allocate;

    foreach( ref mb; meta_buffers )
        static if( isPointer!META_BUFFER )  meta.bind( *mb );
        else                                meta.bind(  mb );
    foreach( ref mi; meta_images )
        static if( isPointer!META_IMAGE )   meta.bind( *mi );
        else                                meta.bind(  mi );

    return meta;
}


// alias buffer this (in e.g. Meta_Goemetry) does not work with the Impl functions above
// but it does work with the aliases for that functions bellow
alias initMemory = initMemoryImpl!( Meta_Buffer , Meta_Image  );
alias initMemory = initMemoryImpl!( Meta_Buffer , Meta_Image* );
alias initMemory = initMemoryImpl!( Meta_Buffer*, Meta_Image  );
alias initMemory = initMemoryImpl!( Meta_Buffer*, Meta_Image* );



///////////////////////////////////////////////////////////
// Meta_Buffer and Meta_Image related template functions //
///////////////////////////////////////////////////////////

mixin template Memory_Member() {
    private:
    VkMemoryRequirements    memory_requirements;
    VkDeviceMemory          device_memory;
    VkDeviceSize            device_memory_offset;
    bool                    owns_device_memory = false;
    public:
    auto memory()           { return device_memory; }
    auto memSize()          { return memory_requirements.size; }
    auto memOffset()        { return device_memory_offset; }
    auto memRequirements()  { return memory_requirements; }
}

private template hasMemReqs( T ) {
    enum hasMemReqs = __traits( hasMember, T, "memory_requirements" );
}


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
    static if( is( META == Meta_Buffer ))   meta.device.vkBindBufferMemory( meta.buffer, meta.device_memory, 0 ).vkAssert( null, file, line, func );
    else                                    meta.device.vkBindImageMemory(  meta.image,  meta.device_memory, 0 ).vkAssert( null, file, line, func );
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
    static if( is( META == Meta_Buffer ))   meta.device.vkBindBufferMemory( meta.buffer, device_memory, device_memory_offset ).vkAssert( null, file, line, func );
    else                                    meta.device.vkBindImageMemory(  meta.image,  device_memory, device_memory_offset ).vkAssert( null, file, line, func );
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
        .vkAssert( file, line, func );
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
    //VkMappedMemoryRange mapped_memory_range = {
    //    memory  : meta.device_memory,
    //    offset  : combined_offset,
    //    size    : data.length,
    //};

    VkMappedMemoryRange mapped_memory_range =
        meta.createMappedMemoryRange( meta.device_memory, data.length, combined_offset, file, line, func );



    // flush the mapped memory range so that its visible to the device memory space
    meta.device
        .vkFlushMappedMemoryRanges( 1, &mapped_memory_range )
        .vkAssert( file, line, func );
    return mapped_memory;
}


/// unmap map the underlying memory object
auto ref unmapMemory( META )( ref META meta ) if( hasMemReqs!META || is( META == Meta_Memory )) {
    meta.device.vkUnmapMemory( meta.device_memory );
    return meta;
}


auto createMappedMemoryRange( META )(
    ref META            meta,
    VkDeviceSize        size    = 0,
    VkDeviceSize        offset  = 0,
    string              file    = __FILE__,
    size_t              line    = __LINE__,
    string              func    = __FUNCTION__
    ) if( hasMemReqs!META || is( META == Meta_Memory )) {
    return meta.createMappedMemoryRange( meta.device_memory, size, offset, file, line, func );
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

    // bulk destroy the resources belonging to this meta struct
    void destroyResources() {
        vk.destroy( buffer );
        if( owns_device_memory )
            vk.destroy( device_memory );
    }
    debug string name;
}


/// initialize a VkBuffer object, this function or createBuffer must be called first, further operations require the buffer
/// the resulting buffer and its create info are stored in the Meta_Buffer struct
/// the Meta_Buffer struct is returned for function chaining
auto ref initBuffer( ref Meta_Buffer meta, VkBufferUsageFlags usage, VkDeviceSize size, VkSharingMode sharing_mode = VK_SHARING_MODE_EXCLUSIVE ) {

    // assert that meta struct is initialized with a valid vulkan state pointer
    assert( meta.isValid );

    // buffer create info from arguments
    meta.buffer_create_info.size        = size; // size in Bytes
    meta.buffer_create_info.usage       = usage;
    meta.buffer_create_info.sharingMode = sharing_mode;

    meta.device.vkCreateBuffer( &meta.buffer_create_info, meta.allocator, &meta.buffer ).vkAssert;
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

    auto resetView() {
        auto result = image_view;
        image_view = VK_NULL_HANDLE;
        return result;
    }

    // bulk destroy the resources belonging to this meta struct
    void destroyResources() {
        vk.destroy( image );
        if( image_view != VK_NULL_HANDLE )
            vk.destroy( image_view );
        if( owns_device_memory )
            vk.destroy( device_memory );
    }
    debug string name;
}



//////////////////////////////////////
// Meta_Image and related functions //
//////////////////////////////////////

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
    meta.device.vkCreateImage( &meta.image_create_info, meta.allocator, &meta.image ).vkAssert;
    meta.device.vkGetImageMemoryRequirements( meta.image, &meta.memory_requirements );
    return meta;
}

alias create = initImage;

// Todo(pp): add chained functions to edit the meta.image_create_info and finalize with construct(), see module pipeline




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
auto ref createView( ref Meta_Image meta, VkImageSubresourceRange subresource_range, VkImageViewType view_type, VkFormat view_format, VkComponentMapping component_mapping ) {
    if( meta.image_view != VK_NULL_HANDLE )
        meta.destroy( meta.image_view );
    with( meta.image_view_create_info ) {
        image               = meta.image;
        viewType            = view_type;
        format              = view_format;
        subresourceRange    = subresource_range;
        components          = component_mapping;
    }
    meta.device.vkCreateImageView( &meta.image_view_create_info, meta.allocator, &meta.image_view ).vkAssert;
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
    VkDependencyFlags       dependency_flags = 0, ) {

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
        0, null, 0, null, 1, &layout_transition_barrier
    );
}



// checking format support
//VkFormatProperties format_properties;
//vk.gpu.vkGetPhysicalDeviceFormatProperties( VK_FORMAT_B8G8R8A8_UNORM, &format_properties );
//format_properties.printTypeInfo;

// checking image format support (additional capabilities)
//VkImageFormatProperties image_format_properties;
//vk.gpu.vkGetPhysicalDeviceImageFormatProperties(
//  VK_FORMAT_B8G8R8A8_UNORM,
//  VK_IMAGE_TYPE_2D,
//  VK_IMAGE_TILING_OPTIMAL,
//  VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
//  0,
//  &image_format_properties).vkAssert;
//image_format_properties.printTypeInfo;
