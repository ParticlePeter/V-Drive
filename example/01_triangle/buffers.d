module buffers;

import erupted;
import derelict.glfw3;

import std.stdio;

import vdrive.state;
import vdrive.memory;
import vdrive.util.util;

import appstruct;



auto ref createBuffers( ref VDriveState vd ) {

	//////////////////////////////////
	// create matrix uniform buffer //
	//////////////////////////////////

	vd.wvpm_buffer = vd;
	vd.wvpm_buffer.create( VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, 16 * float.sizeof );
	vd.wvpm_buffer.createMemory( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT );

	// map the uniform buffer memory persistently
	void* mapped_memory;
	vd.device.vkMapMemory( vd.wvpm_buffer.device_memory, 0, vd.wvpm_buffer.size, 0, &mapped_memory ).vkEnforce;
	import dlsl.matrix;
	vd.wvpm = cast( mat4* )mapped_memory;

	// specify mapped memory range
	vd.wvpm_flush.memory	= vd.wvpm_buffer.device_memory;
	vd.wvpm_flush.size		= vd.wvpm_buffer.size;


	/////////////////////////////////////////////////////////////////
	// geometry with draw commands in module related Meta_Drawable //
	/////////////////////////////////////////////////////////////////

	import geometry.triangle;
	vd.triangle = geometry.triangle.createGeometry( vd );

	//import geometry.lucien;
	//vd.lucien = geometry.lucien.createGeometry( vd );
}
