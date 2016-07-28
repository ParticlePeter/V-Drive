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


struct Meta_Geometry {
	this( ref Vulkan vk )			{  this.meta_buffer.vk = vk;  }
	alias									meta_buffer this;
	Meta_Buffer								meta_buffer;

	Array!VkVertexInputBindingDescription	binding_descriptions;
	Array!VkVertexInputAttributeDescription	attribute_descriptions;

	VkPipelineVertexInputStateCreateInfo	vertex_input_create_info;
	VkPipelineInputAssemblyStateCreateInfo	input_assembly_create_info;

	uint32_t								index_count;
	uint32_t								vertex_count;

	VkDeviceSize							index_offset;
	Array!VkDeviceSize						vertex_offsets;
	Array!VkBuffer							vertex_buffers;	
}


auto ref initGeometry( ref Vulkan vk ) {
	return Meta_Geometry( vk );
}


