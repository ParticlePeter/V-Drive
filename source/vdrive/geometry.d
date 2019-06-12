module vdrive.geometry;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.buffer;

import erupted;



mixin template Meta_Geometry_Alias_This() {
    this( ref Vulkan vk )   {   meta_geometry.meta_buffer.vk = vk;  }
    alias                       meta_geometry this;
    Meta_Geometry               meta_geometry;
}


private alias RecordCommands = void function( VkCommandBuffer command_buffer, ref Meta_Geometry meta_geometry ) nothrow;

alias  Meta_Geometry = Meta_Geometry_T!();
struct Meta_Geometry_T(
    int32_t vertex_offset_count = int32_t.max,
    int32_t vertex_buffer_count = int32_t.max

    ) {

    this( ref Vulkan vk )   {  this.meta_buffer.vk = vk;  }
    alias                                               meta_buffer this;
    Meta_Buffer                                         meta_buffer;

    VkIndexType                                         index_type = VK_INDEX_TYPE_UINT32;
    uint32_t                                            index_count;
    VkDeviceSize                                        index_offset;

    uint32_t                                            vertex_count;
    D_OR_S_ARRAY!( vertex_offset_count, VkDeviceSize )  vertex_offsets;
    D_OR_S_ARRAY!( vertex_buffer_count, VkBuffer )      vertex_buffers;

    RecordCommands                                      recordCommands;

    void recordDrawCommands( VkCommandBuffer command_buffer ) nothrow {
        recordCommands( command_buffer, this );
    }


    /// get minimal config for internal D_OR_S_ARRAY
    auto static_config() {
        size_t[2] result;
        result[0] = vertex_offsets.length;
        result[1] = vertex_buffers.length;
        return result;
    }
}


auto ref indexType( ref Meta_Geometry meta, VkIndexType index_type ) {
    meta.index_type = index_type;
    return meta;
}


auto ref indexCount( ref Meta_Geometry meta, uint32_t index_count ) {
    meta.index_count = index_count;
    return meta;
}


auto ref indexOffset( ref Meta_Geometry meta, VkDeviceSize index_offset ) {
    meta.index_offset = index_offset;
    return meta;
}


auto ref vertexCount( ref Meta_Geometry meta, uint32_t vertex_count ) {
    meta.vertex_count = vertex_count;
    return meta;
}


auto ref addVertexOffset( ref Meta_Geometry meta, VkDeviceSize vertex_offset ) {
    return meta.addVertexBufferOffset( meta.meta_buffer.buffer, vertex_offset );
}


auto ref addVertexBufferOffset( ref Meta_Geometry meta, VkBuffer vertex_buffer, VkDeviceSize vertex_offset ) {
    meta.vertex_offsets.append( vertex_offset );
    meta.vertex_buffers.append( vertex_buffer );
    return meta;
}


auto ref recordCommandsFunc(
    ref Meta_Geometry   meta,
    RecordCommands      recordCommands,
//  string              file = __FILE__,
//  size_t              line = __LINE__,
//  string              func = __FUNCTION__
    ) {
    if( meta.vertex_offsets.empty )     // vertex_offsets and _buffers must not be empty before recording commands
        meta.addVertexOffset( 0 );      // with this command we simply register the internal buffer with 0 offset to be drawn
    meta.recordCommands = recordCommands;
    return meta;
}
