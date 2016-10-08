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
			printf( compile_glsl.output.ptr );		// print output
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
auto createSetLayout(
	ref Vulkan 			vk,
	uint32_t			binding,
	VkDescriptorType	descriptorType,
	uint32_t			descriptorCount,
	VkShaderStageFlags	stageFlags,
	const(VkSampler)*	pImmutableSamplers = null ) {

	const VkDescriptorSetLayoutBinding[1] set_layout_bindings = [ 
		VkDescriptorSetLayoutBinding( binding, descriptorType, descriptorCount, stageFlags, pImmutableSamplers ) 
	];
	return vk.createSetLayout( set_layout_bindings );
}

/// create a VkDescriptorSetLayout from several VkDescriptorSetLayoutBinding(s)
auto createSetLayout( ref Vulkan vk, const VkDescriptorSetLayoutBinding[] set_layout_bindings ) {

	VkDescriptorSetLayoutCreateInfo descriptor_set_layout_create_info = {
		bindingCount	: set_layout_bindings.length.toUint,
		pBindings		: set_layout_bindings.ptr,
	};

	VkDescriptorSetLayout descriptor_set_layout;
	vkCreateDescriptorSetLayout( vk.device, &descriptor_set_layout_create_info, vk.allocator, &descriptor_set_layout ).vkEnforce;
	return descriptor_set_layout;
}


/// create a VkDescriptorSetLayout from several VkDescriptorSetLayoutBinding(s)
auto allocateSet( ref Vulkan vk, VkDescriptorPool descriptor_pool, VkDescriptorSetLayout set_layout ) {

	VkDescriptorSetAllocateInfo descriptor_allocate_info = {
		descriptorPool		: descriptor_pool,
		descriptorSetCount	: 1,
		pSetLayouts			: &set_layout,
	};

	VkDescriptorSet descriptor_set;
	vkAllocateDescriptorSets( vk.device, &descriptor_allocate_info, &descriptor_set ).vkEnforce;
	return descriptor_set;
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

	Array!VkDescriptorSetLayoutBinding	set_layout_bindings;

	void destroyResources() {
		vk.device.vkDestroyDescriptorSetLayout( set_layout, vk.allocator );
	}

}


auto ref initDescriptor(
	ref Meta_Descriptor meta,
	VkDescriptorPool	descriptor_pool,
	uint32_t			binding,
	VkDescriptorType	descriptorType,
	uint32_t			descriptorCount,
	VkShaderStageFlags	stageFlags,
	const(VkSampler)*	pImmutableSamplers = null ) {

	assert( meta.isValid );		// assert the meta struct was initialized with vulkan state struct
	meta.set_layout = meta.createSetLayout( binding, descriptorType, descriptorCount, stageFlags, pImmutableSamplers );
	meta.set = meta.allocateSet( descriptor_pool, meta.set_layout );
	return meta;
}

alias create = initDescriptor;


auto createDescriptor(
	ref Vulkan 			vk,
	VkDescriptorPool	descriptor_pool,
	uint32_t			binding,
	VkDescriptorType	descriptorType,
	uint32_t			descriptorCount,
	VkShaderStageFlags	stageFlags,
	const(VkSampler)*	pImmutableSamplers = null ) {

	Meta_Descriptor meta = vk;
	return meta.initDescriptor( 
		descriptor_pool, binding, descriptorType, descriptorCount, stageFlags, pImmutableSamplers );
}


auto ref addLayoutBinding( ref Meta_Descriptor meta, VkDescriptorSetLayoutBinding set_layout_binding ) {
	meta.set_layout_bindings.append( set_layout_binding );
	return meta;
}


auto ref addLayoutBinding(
	ref Meta_Descriptor meta,
	uint32_t			binding,
	VkDescriptorType	descriptorType,
	uint32_t			descriptorCount,
	VkShaderStageFlags	stageFlags,
	const(VkSampler)*	pImmutableSamplers = null ) {

	return meta.addLayoutBinding(
		VkDescriptorSetLayoutBinding( binding, descriptorType, descriptorCount, stageFlags, pImmutableSamplers
	));
}


auto ref construct( ref Meta_Descriptor meta, VkDescriptorPool descriptor_pool ) {
	meta.set_layout = meta.createSetLayout( meta.set_layout_bindings.data );
	meta.set = meta.allocateSet( descriptor_pool, meta.set_layout );
	return meta;
}





