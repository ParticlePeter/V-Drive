module vdrive.shader;

import erupted;

import vdrive.util;
import vdrive.state;

import core.stdc.stdio : printf;






auto createShaderModule( ref Vulkan vk, string path ) {

	import std.path : extension;
	string ext = path.extension;
	if( ext != ".spv" ) {

		// convert to std.container.array!char
		auto array = path.toStringz;					// this adds '\0' as last value and must be compensated in index calculations
		array[ $ - ext.length - 1 ] = '_';				// substitute the . of .ext with _ to _ext

		// append new extension .spv
		string spv = ".spv";							// string with extension for memcpy
		array.length = array.length + spv.length - 1;	// resize the array with the length of the new extension
		array[ $-1 ] = '\0';							// set the last value to a terminating character
		import core.stdc.string : memcpy;				// import and use memcopy to copy into the char array
		memcpy( &array.data[ $ - spv.length ], spv.ptr, spv.length );

		string spir_path = array.data.idup;				// create string from the char array
		
		import std.file : exists;
		bool up_to_date = array.data.exists;			// check if the file exists

		if( up_to_date ) {								// if file exists, check if it is up to date with the glsl source
			import std.file : getTimes;					// need to get the modification times of the files
			import std.datetime : SysTime;				// stored in comparable SysTimes
			SysTime access_time, glsl_mod_time, spir_mod_time;	// access times are irrelevant
			spir_path.getTimes( access_time, spir_mod_time );	// get spir-v file times (.spv)
			path.getTimes( access_time, glsl_mod_time );		// get glsl file times
			up_to_date = glsl_mod_time < spir_mod_time;			// set the up_to_date value if glsl is newer than spir-v
		}

		if( !up_to_date ) {
			import std.process : execute;				// use process execute to call glslangValidator
			string[6] compile_glsl_args = [ "glslangValidator", "-V", "-w", "-o", spir_path, path ];
			auto compile_glsl = compile_glsl_args.execute;		// store in status struct
			printf( compile_glsl.output.toStringz.ptr );		// print output
		}
		path = array.data.idup;							// create string from the composed char array
	}

	import std.stdio : File;
	auto file = File( path );
	auto read_buffer = sizedArray!char( cast( size_t )file.size );
	auto code = file.rawRead( read_buffer.data );

	VkShaderModuleCreateInfo shader_module_create_info = {
		codeSize	: cast( uint32_t  )code.length,
		pCode		: cast( uint32_t* )code.ptr,
	};

	VkShaderModule shader_module;
	vk.device.vkCreateShaderModule( &shader_module_create_info, vk.allocator, &shader_module ).vkEnforce;

	return shader_module;
}

auto createPipelineShaderStage(
	ref Vulkan vk,
	VkShaderStageFlagBits shader_stage,
	VkShaderModule shader_module,
	const( VkSpecializationInfo )* specialization_info = null,
	const( char )* shader_entry_point = "main" ) {

	VkPipelineShaderStageCreateInfo shader_stage_create_info = {
		stage				: shader_stage,
		_module				: shader_module,
		pName				: shader_entry_point,        // shader entry point function name
		pSpecializationInfo	: null,
	};

	return shader_stage_create_info;
}



auto createPipelineShaderStage(
	ref Vulkan vk,
	VkShaderStageFlagBits shader_stage,
	string spirv_path,
	const( VkSpecializationInfo )* specialization_info = null,
	const( char )* shader_entry_point = "main" ) {

	return createPipelineShaderStage(
		vk, shader_stage, vk.createShaderModule( spirv_path ), specialization_info, shader_entry_point
	);
}




/// create a one pool size VkDescriptorPool
auto createDescriptorPool( ref Vulkan vk, VkDescriptorType descriptor_type, uint32_t descriptor_count, uint32_t max_sets ) {
	VkDescriptorPoolSize[1] pool_size_descriptor_counts = [ VkDescriptorPoolSize( descriptor_type, descriptor_count ) ];
	return vk.createDescriptorPool( pool_size_descriptor_counts, max_sets );
}


/// create a VkDescriptorPool from uint32_t[] pool sizes and uint32_t max_sets 
auto createDescriptorPool( ref Vulkan vk, VkDescriptorPoolSize[] descriptor_pool_sizes, uint32_t max_sets ) {

	VkDescriptorPoolCreateInfo pool_create_info = { 
		maxSets			: max_sets,
		poolSizeCount	: descriptor_pool_sizes.length.toUint,
		pPoolSizes		: descriptor_pool_sizes.ptr,
	};

	VkDescriptorPool descriptor_pool;
	vk.device.vkCreateDescriptorPool( &pool_create_info, vk.allocator, &descriptor_pool ).vkEnforce;
	return descriptor_pool;
}



/// create a VkDescriptorSetLayout from one VkDescriptorSetLayoutBinding
auto createDescriptorSetLayout(
	ref Vulkan 			vk,
	uint32_t			binding,
	VkDescriptorType	descriptorType,
	uint32_t			descriptorCount,
	VkShaderStageFlags	stageFlags,
	const(VkSampler)*	pImmutableSamplers = null ) {

	const VkDescriptorSetLayoutBinding[1] set_layout_bindings = [ 
		VkDescriptorSetLayoutBinding( binding, descriptorType, descriptorCount, stageFlags, pImmutableSamplers ) 
	];
	return vk.createDescriptorSetLayout( set_layout_bindings );
}

/// create a VkDescriptorSetLayout from several VkDescriptorSetLayoutBinding(s)
auto createDescriptorSetLayout( ref Vulkan vk, const VkDescriptorSetLayoutBinding[] set_layout_bindings ) {

	VkDescriptorSetLayoutCreateInfo descriptor_set_layout_create_info = {
		bindingCount	: set_layout_bindings.length.toUint,
		pBindings		: set_layout_bindings.ptr,
	};

	VkDescriptorSetLayout descriptor_set_layout;
	vkCreateDescriptorSetLayout( vk.device, &descriptor_set_layout_create_info, vk.allocator, &descriptor_set_layout ).vkEnforce;
	return descriptor_set_layout;
}




import vdrive.util.array;
struct Meta_Descriptor {
	mixin					Vulkan_State_Pointer;

/*	struct Meta_Descriptor_Set_Layout {
		Array!VkDescriptorSetLayoutBinding	set_layout_bindings;
		VkDescriptorSetLayout				set_layout;
	}

	VkDescriptorPool descriptor_pool;
	Array!Meta_Descriptor_Set_Layout	meta_descriptor_set_layouts;
	Array!VkDescriptorSet				descriptor_sets;
*/
	VkDescriptorSetLayout	set_layout;
	VkDescriptorSet			set;

}


auto createMatrixBuffer( ref Vulkan vk, void[] data ) {

	import vdrive.memory;
	Meta_Buffer meta_buffer = vk;
	meta_buffer.createBuffer( VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, data.length );
	meta_buffer.createMemory( VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT );
	meta_buffer.bufferData( data );

	return meta_buffer;
}


auto createMatrixUniform( ref Vulkan vk, VkDescriptorPool descriptor_pool, VkBuffer buffer, VkDeviceSize range, VkDeviceSize offset = 0 ) {

	Meta_Descriptor meta_descriptor = vk;
	meta_descriptor.set_layout = vk.createDescriptorSetLayout( 
		0, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1, VK_SHADER_STAGE_VERTEX_BIT, null );

	VkDescriptorSetAllocateInfo descriptor_allocate_info = {
		descriptorPool		: descriptor_pool,
		descriptorSetCount	: 1,
		pSetLayouts			: &meta_descriptor.set_layout,
	};

	vkAllocateDescriptorSets( vk.device, &descriptor_allocate_info, &meta_descriptor.set );

	// When a set is allocated all values are undefined and all 
	// descriptors are uninitialised. must init all statically used bindings:
	VkDescriptorBufferInfo descriptor_buffer_info = {
		buffer	: buffer,
		offset	: offset,
		range	: range,	// VK_WHOLE_SIZE not working here, Driver Bug?	
	};

	VkWriteDescriptorSet write_descriptor_set = {
		dstSet				: meta_descriptor.set,
		dstBinding			: 0,
		dstArrayElement		: 0,
		descriptorCount		: 1,
		descriptorType		: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
		pImageInfo			: null,
		pBufferInfo			: &descriptor_buffer_info,
		pTexelBufferView	: null,
	};

	vk.device.vkUpdateDescriptorSets( 1, &write_descriptor_set, 0, null );

	return meta_descriptor;
} 









/*
auto ref appendLayoutBinding(
	Meta_Descriptor		meta_descriptor,
	uint32_t			binding,
	VkDescriptorType	descriptorType,
	uint32_t			descriptorCount,
	VkShaderStageFlags	stageFlags,
	const( VkSampler )*	pImmutableSamplers = null ) {

	VkDescriptorSetLayoutBinding set_layout_binding = {
		binding				: binding,
		descriptorType		: descriptorType,
		descriptorCount		: descriptorCount,
		stageFlags			: stageFlags,
		pImmutableSamplers	: pImmutableSamplers,
	};

	meta_descriptor.set_layout_bindings.append( set_layout_binding );
	return meta_descriptor;
}
*/








