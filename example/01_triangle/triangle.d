module geometry.triangle;

import erupted;

import vdrive.util;
import vdrive.state;
import vdrive.memory;
import vdrive.geometry;



// records buffer bind and draw commands
private void recordCommands( VkCommandBuffer command_buffer, ref Meta_Geometry meta_geometry ) {
	// One buffer is used for only one vertex attribute

	// bind vertex buffer, only one attribute stored in this buffer 
	command_buffer.vkCmdBindVertexBuffers(
		0,											// first binding
		meta_geometry.vertex_buffers.length.toUint,	// binding count
		meta_geometry.vertex_buffers.ptr,			// pBuffers to bind
		meta_geometry.vertex_offsets.ptr			// pOffsets into buffers
	);

	// simple draw command, non indexed
	command_buffer.vkCmdDraw(
		meta_geometry.vertex_count,					// vertex count
		1,											// instance count
		0,											// first vertex
		0											// first instance
	);
}


auto ref createGeometry( ref Vulkan vk ) {

	// Works! But avoid dependency for now
	//import dlsl.vector;
	//vec4[3] triangle = [ vec4( -1.0f, -1.0f, 0, 1.0f ), vec4(  1.0f, -1.0f, 0, 1.0f ), vec4(  0.0f,  1.0f, 0, 1.0f ) ];

	struct Vertex { float x, y, z; }
	Vertex[3] triangle = [ Vertex( 1, -1, 0 ), Vertex( -1, -1, 0 ), Vertex( 0, 1, 0 ) ];
	
	// create meta geometry struct with implict meta buffer
	Meta_Geometry meta = vk;

	// edit the meta buffer via alias this
	meta.create( VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, triangle.sizeof );
	meta.createMemory( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT );
	meta.bufferData( triangle );

	// append Meta_Geometry vertex_buffers and vertex_offsets
	meta.vertex_offsets.append = 0;
	meta.vertex_buffers.append = meta.buffer;

	meta.vertex_count = 3;

	meta.recordCommands = &recordCommands;

	debug meta.name = "Buffer_Triangle";

	return meta;
}
