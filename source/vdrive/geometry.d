module vdrive.geometry;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;
import vdrive.buffer;

import erupted;


// stub for geometry managmenet

struct Meta_Geometry {
	this( ref Vulkan vk )			{  this.meta_buffer.vk = &vk;  }
	alias 									meta_buffer this;
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


auto ref inputAssembly( ref Meta_Geometry meta, VkPrimitiveTopology primitive_topology, VkBool32 primitive_restart = VK_FALSE ) {
	meta.input_assembly_create_info.topology = primitive_topology;
	meta.input_assembly_create_info.primitiveRestartEnable = primitive_restart;
	return meta;
}

auto ref bindingDescription( ref Meta_Geometry meta, size_t binding, size_t stride, VkVertexInputRate input_rate = VK_VERTEX_INPUT_RATE_VERTEX ) {
	meta.binding_descriptions.append( VkVertexInputBindingDescription( binding.toUint, stride.toUint, input_rate ));
	meta.vertex_input_create_info.pVertexBindingDescriptions = meta.binding_descriptions.ptr;
	meta.vertex_input_create_info.vertexBindingDescriptionCount = meta.binding_descriptions.length.toUint;
	return meta;
}

auto ref attributeDescription( ref Meta_Geometry meta, size_t location, size_t binding, VkFormat format, size_t offset = 0 ) {
	meta.attribute_descriptions.append( VkVertexInputAttributeDescription( location.toUint, binding.toUint, format, offset.toUint ));
	meta.vertex_input_create_info.pVertexAttributeDescriptions = meta.attribute_descriptions.ptr;
	meta.vertex_input_create_info.vertexAttributeDescriptionCount = meta.attribute_descriptions.length.toUint;
	return meta;
}

