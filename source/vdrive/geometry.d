module vdrive.geometry;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;


import erupted;


// stub for geometry managmenet

auto createTriangleBuffer( ref Vulkan vk ) {

	// Works! But avoid dependency for now
	//import dlsl.vector;
	//vec4[3] triangle = [ vec4( -1.0f, -1.0f, 0, 1.0f ), vec4(  1.0f, -1.0f, 0, 1.0f ), vec4(  0.0f,  1.0f, 0, 1.0f ) ];

	struct Vertex { float x, y, z, w; }
	Vertex[3] triangle = [ Vertex( -1.0f, -1.0f, 0, 1.0f ), Vertex(  1.0f, -1.0f, 0, 1.0f ), Vertex(  0.0f,  1.0f, 0, 1.0f ) ];
	import vdrive.buffer;
	Meta_Buffer meta_buffer = vk;
	meta_buffer.createBuffer( VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, triangle.sizeof );
	meta_buffer.bindMemory( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT );
	meta_buffer.bufferData( triangle );

	return meta_buffer;


}

