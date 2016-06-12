module vdrive.shader;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;


auto createShaderModule( ref Vulkan vk, string path ) {

	import std.stdio : File;
	auto file = File( path ) ;
	auto read_buffer = sizedArray!char( cast( size_t )file.size );
	//read_buffer.length = cast( size_t )file.size;
	auto code = file.rawRead( read_buffer.data );

	VkShaderModuleCreateInfo shader_module_create_info = {
		codeSize	: cast( uint32_t  )code.length,
		pCode		: cast( uint32_t* )code.ptr,
	};

	VkShaderModule shader_module;
	vk.device.vkCreateShaderModule( &shader_module_create_info, null, &shader_module ).vk_enforce;

	return shader_module;
}

auto createPipelineShaderStageCreateInfo(
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



auto createPipelineShaderStageCreateInfo(
	ref Vulkan vk,
	VkShaderStageFlagBits shader_stage,
	string spirv_path,
	const( VkSpecializationInfo )* specialization_info = null,
	const( char )* shader_entry_point = "main" ) {

	return createPipelineShaderStageCreateInfo(
		vk, shader_stage, vk.createShaderModule( spirv_path ), specialization_info, shader_entry_point
	);
}


struct Shader_Uniform {
    VkBuffer		buffer;
    VkDeviceMemory	memory;
};



