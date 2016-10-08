module vdrive.geometry;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.memory;

import erupted;


mixin template Meta_Geometry_Alias_This() {
	this( ref Vulkan vk )	{	meta_geometry.meta_buffer.vk = vk;  }
	alias						meta_geometry this;
	Meta_Geometry				meta_geometry;
}


private alias RecordCommands = void function( VkCommandBuffer command_buffer, ref Meta_Geometry meta_geometry );

struct Meta_Geometry {
	this( ref Vulkan vk )	{  this.meta_buffer.vk = vk;  }
	alias							meta_buffer this;
	Meta_Buffer						meta_buffer;

	uint32_t						index_count;
	uint32_t						vertex_count;

	VkDeviceSize					index_offset;
	Array!VkDeviceSize				vertex_offsets;
	Array!VkBuffer					vertex_buffers;

	RecordCommands					recordCommands;

	void recordDrawCommands( VkCommandBuffer command_buffer ) {
		recordCommands( command_buffer, this );
	}	
}
