module vdrive.shader;

import erupted;

import vdrive.util;
import vdrive.state;

import core.stdc.stdio : printf;





///	create a VkShaderModule from either a vulkan acceptable glsl text file or binary spir-v file
/// glsl text file is only acceptable if glslangValidator is somewhere in the system path
/// the text file will then be compiled into spir-v binary and loaded
/// detection of spir-v is based on .spv extension
///	Params:
///		vk = reference to a VulkanState struct
///		path = the path to glsl or spir-v file
///	Returns: VkShaderModule 
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


///	create a VkPipelineShaderStageCreateInfo acceptable for a pipeline state object (PSO)
///	Params:
///		vk = reference to a VulkanState struct
///		shader_stage = enum to specify the shader stage
///		shader_module = the VkShaderModule to be converted
///		shader_entry_point = optionally set a different name for your "main" entry point,
///							this is also required if the passed in shader_module has 
///							multiple entry points ( e.g. shader stages )
///		specialization_info = optionally set a VkSpecializationInfo for the shader module 
///	Returns: VkPipelineShaderStageCreateInfo 
auto createPipelineShaderStage(
	ref Vulkan vk,
	VkShaderStageFlagBits shader_stage,
	VkShaderModule shader_module,
	const( char )* shader_entry_point = "main",
	const( VkSpecializationInfo )* specialization_info = null ) {

	VkPipelineShaderStageCreateInfo shader_stage_create_info = {
		stage				: shader_stage,
		_module				: shader_module,
		pName				: shader_entry_point,        // shader entry point function name
		pSpecializationInfo	: specialization_info,
	};

	return shader_stage_create_info;
}


///	create a VkPipelineShaderStageCreateInfo acceptable for a pipeline state opbject (PSO)
/// takes a path to a vulkan acceptable glsl text file or spir-v binary file conveniently
/// instead of a VkShaderModule. Detection of spir-v is based on .spv extension 
///	Params:
///		vk = reference to a VulkanState struct
///		shader_stage = enum to specify the shader stage
///		shader_path = path to glsl text or spir-v binary  
///		shader_entry_point = optionally set a different name for your "main" entry point,
///							this is also required if the passed in shader_module has 
///							multiple entry points ( e.g. shader stages )
///		specialization_info = optionally set a VkSpecializationInfo for the shader module 
///	Returns: VkPipelineShaderStageCreateInfo
auto createPipelineShaderStage(
	ref Vulkan vk,
	VkShaderStageFlagBits shader_stage,
	string shader_path,
	const( char )* shader_entry_point = "main",
	const( VkSpecializationInfo )* specialization_info = null ) {

	return createPipelineShaderStage(
		vk, shader_stage, vk.createShaderModule( shader_path ), specialization_info, shader_entry_point
	);
}


///	create a one descriptor type VkDescriptorPool
/// the max_descriptor_sets parameter is by default set to one it has been suggested ( e.g. GDC2016/17 )
/// to use only one huge descriptor set for all shader module  
///	Params:
///		vk = reference to a VulkanState struct
///		descriptor_type = type of each descriptor which can be allocated from pool 
///		descriptor_count = count of the descriptors which can be allocated from pool 
///		max_descriptor_sets = optional ( default = 1 ) max descriptor sets which can be created from the descriptors 
///		create_flags = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
///	Returns: VkDescriptorPool
auto createDescriptorPool(
	ref Vulkan vk,
	VkDescriptorType descriptor_type,				// specifies the only descriptor type which can be allocated from the pool
	uint32_t descriptor_count,						// count of the descriptors of that particular type 
	uint32_t max_descriptor_sets = 1,				// max descriptor sets which can be created from these descriptors
	VkDescriptorPoolCreateFlags create_flags = 0	// only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
	) {
	VkDescriptorPoolSize[1] pool_size_descriptor_counts = [ VkDescriptorPoolSize( descriptor_type, descriptor_count ) ];
	return vk.createDescriptorPool( pool_size_descriptor_counts, max_descriptor_sets, create_flags );
}


///	create a multi descriptor type VkDescriptorPool
/// the max_descriptor_sets parameter is by default set to one it has been suggested ( e.g. GDC2016/17 )
/// to use only one huge descriptor set for all shader module  
///	Params:
///		vk = reference to a VulkanState struct
///		descriptor_pool_sizes = array of VkDescriptorPoolSize each specifying a descriptor type and count 
///		max_descriptor_sets = optional ( default = 1 ) max descriptor sets which can be created from the descriptors 
///		create_flags = optional, only one flag available: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
///	Returns: VkDescriptorPool 
auto createDescriptorPool(
	ref Vulkan vk,
	VkDescriptorPoolSize[] descriptor_pool_sizes,	// array of structs with type and count of descriptor
	uint32_t max_sets,								// max descriptor sets which can be created from these descriptors
	VkDescriptorPoolCreateFlags create_flags = 0	// only one flag possible: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT
	) {
	VkDescriptorPoolCreateInfo pool_create_info = {
		flags			: create_flags, 
		maxSets			: max_sets,
		poolSizeCount	: descriptor_pool_sizes.length.toUint,
		pPoolSizes		: descriptor_pool_sizes.ptr,
	};

	VkDescriptorPool descriptor_pool;
	vk.device.vkCreateDescriptorPool( &pool_create_info, vk.allocator, &descriptor_pool ).vkEnforce;
	return descriptor_pool;
}


///	create VkDescriptorSetLayout from one VkDescriptorSetLayoutBinding
/// parameters are the same as those of a VkDescriptorSetLayoutBinding
/// internally one VkDescriptorSetLayoutBinding is created and passed to vkCreateDescriptorSetLayout 
///	Params:
///		vk = reference to a VulkanState struct
///		binding = binding index of the layout 
///		descriptor_count = count of the descriptors in case of an array of descriptors
///		shader_stage_flags = shader stages where the descriptor can be used
///		immutable_samplers = optional: pointer to ( an array of descriptor_count length ) of immutable samplers
///	Returns: VkDescriptorSetLayout
auto createSetLayout(
	ref Vulkan 			vk,
	uint32_t			binding,
	VkDescriptorType	descriptor_type,
	uint32_t			descriptor_count,
	VkShaderStageFlags	shader_stage_flags,
	const( VkSampler )*	immutable_samplers = null ) {

	const VkDescriptorSetLayoutBinding[1] set_layout_bindings = [ 
		VkDescriptorSetLayoutBinding( binding, descriptor_type, descriptor_count, shader_stage_flags, immutable_samplers ) 
	];
	return vk.createSetLayout( set_layout_bindings );
}

/// create a VkDescriptorSetLayout from several VkDescriptorSetLayoutBinding(s)
///	Params:
///		vk = reference to a VulkanState struct
///		binding = binding index of the layout 
///		descriptor_count = count of the descriptors in case of an array of descriptors
///		shader_stage_flags = shader stages where the descriptor can be used
///		immutable_samplers = optional: pointer to ( an array of descriptor_count length ) of immutable samplers
///	Returns: VkDescriptorSetLayout
auto createSetLayout( ref Vulkan vk, const VkDescriptorSetLayoutBinding[] set_layout_bindings ) {

	VkDescriptorSetLayoutCreateInfo descriptor_set_layout_create_info = {
		bindingCount	: set_layout_bindings.length.toUint,
		pBindings		: set_layout_bindings.ptr,
	};

	VkDescriptorSetLayout descriptor_set_layout;
	vkCreateDescriptorSetLayout( vk.device, &descriptor_set_layout_create_info, vk.allocator, &descriptor_set_layout ).vkEnforce;
	return descriptor_set_layout;
}


/// allocate a VkDescriptorSet from a VkDescriptorPool with given VkDescriptorSetLayout
///	Params:
///		vk = reference to a VulkanState struct
///		descriptor_pool = the pool from which the descriptors of the set will be allocated
///		descriptor_set_layout = the layout for the resulting descriptor set
///	Returns: VkDescriptorSet
auto allocateSet( ref Vulkan vk, VkDescriptorPool descriptor_pool, VkDescriptorSetLayout descriptor_set_layout ) {
	VkDescriptorSetAllocateInfo descriptor_allocate_info = {
		descriptorPool		: descriptor_pool,
		descriptorSetCount	: 1,
		pSetLayouts			: &descriptor_set_layout,
	};

	VkDescriptorSet descriptor_set;
	vkAllocateDescriptorSets( vk.device, &descriptor_allocate_info, &descriptor_set ).vkEnforce;
	return descriptor_set;
}


/// allocate multiple VkDescriptorSet(s) from a VkDescriptorPool with given VkDescriptorSetLayout(s)
///	Params:
///		vk = reference to a VulkanState struct
///		descriptor_pool = the pool from which the descriptors of the set will be allocated
///		descriptor_set_layout = the layout for the resulting descriptor set
///	Returns: std.container.array!VkDescriptorSet
auto allocateSet( ref Vulkan vk, VkDescriptorPool descriptor_pool, VkDescriptorSetLayout[] descriptor_set_layout ) {
	VkDescriptorSetAllocateInfo descriptor_allocate_info = {
		descriptorPool		: descriptor_pool,
		descriptorSetCount	: descriptor_set_layout.length.toUint,
		pSetLayouts			: &descriptor_set_layout,
	};

	auto descriptor_sets = sizedArray!VkDescriptorSet( descriptor_set_layout.length );
	vkAllocateDescriptorSets( vk.device, &descriptor_allocate_info, descriptor_set.ptr ).vkEnforce;
	return descriptor_sets;
}



import vdrive.util.array;

// Todo(pp): Meta_Descriptor should also manage a VkDescriptorPool
// either shared if one is passed in or its own when it
// additionally it should also manage VkImageInfo, VkBufferInfo, VkBufferView and VkWriteDescriptorSet
// on create call, the descriptor set should be initialized with the VkWriteDescriptorSet data
// add the following members to the Meta_Descriptor struct
// 1. array of union of VkImageInfo, VkBufferInfo and VkBufferView
// 2. array of VkWriteDescriptorSet
// use an api similar addDependency(ByRegion) to get to the next descriptor
// than edit the active descriptor 
struct Meta_Descriptor {
	mixin					Vulkan_State_Pointer;
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
	VkDescriptorType	descriptor_type,
	uint32_t			descriptor_count,
	VkShaderStageFlags	shader_stage_flags,
	const(VkSampler)*	immutable_samplers = null ) {

	assert( meta.isValid );		// assert that meta struct is initialized with a valid vulkan state pointer
	meta.set_layout = meta.createSetLayout( binding, descriptor_type, descriptor_count, shader_stage_flags, immutable_samplers );
	meta.set = meta.allocateSet( descriptor_pool, meta.set_layout );
	return meta;
}

alias create = initDescriptor;


auto createDescriptor(
	ref Vulkan 			vk,
	VkDescriptorPool	descriptor_pool,
	uint32_t			binding,
	VkDescriptorType	descriptor_type,
	uint32_t			descriptor_count,
	VkShaderStageFlags	shader_stage_flags,
	const(VkSampler)*	immutable_samplers = null ) {

	Meta_Descriptor meta = vk;
	return meta.initDescriptor( 
		descriptor_pool, binding, descriptor_type, descriptor_count, shader_stage_flags, immutable_samplers );
}


auto ref addLayoutBinding( ref Meta_Descriptor meta, VkDescriptorSetLayoutBinding set_layout_binding ) {
	meta.set_layout_bindings.append( set_layout_binding );
	return meta;
}


auto ref addLayoutBinding(
	ref Meta_Descriptor meta,
	uint32_t			binding,
	VkDescriptorType	descriptor_type,
	uint32_t			descriptor_count,
	VkShaderStageFlags	shader_stage_flags,
	const(VkSampler)*	immutable_samplers = null ) {

	return meta.addLayoutBinding(
		VkDescriptorSetLayoutBinding(
			binding, descriptor_type, descriptor_count, shader_stage_flags, immutable_samplers
	));
}


auto ref construct( ref Meta_Descriptor meta, VkDescriptorPool descriptor_pool ) {
	meta.set_layout = meta.createSetLayout( meta.set_layout_bindings.data );
	meta.set = meta.allocateSet( descriptor_pool, meta.set_layout );
	return meta;
}





