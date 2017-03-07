module vdrive.descriptor;

import erupted;

import vdrive.util;
import vdrive.state;

import core.stdc.stdio : printf;



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
///		immutable_samplers = optional, pointer to ( an array of descriptor_count length ) of immutable samplers
///	Returns: VkDescriptorSetLayout
auto createSetLayout(
	ref Vulkan 			vk,
	uint32_t			binding,
	VkDescriptorType	descriptor_type,
	uint32_t			descriptor_count,
	VkShaderStageFlags	shader_stage_flags,
	const( VkSampler )*	immutable_samplers = null,
	) {
	const VkDescriptorSetLayoutBinding[1] descriptor_set_layout_bindings = [ 
		VkDescriptorSetLayoutBinding( binding, descriptor_type, descriptor_count, shader_stage_flags, immutable_samplers ) 
	];
	return vk.createSetLayout( descriptor_set_layout_bindings );
}


///	create VkDescriptorSetLayout from one VkDescriptorSetLayoutBinding
/// parameters are the same as those of a VkDescriptorSetLayoutBinding but missing immutable_samplers
/// instead set_layout_create_flags for the set layout is provided
/// in the case of one layout binding set layout immutable samplers and
/// VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR are mutually exclusive
/// internally one VkDescriptorSetLayoutBinding is created and passed to vkCreateDescriptorSetLayout 
///	Params:
///		vk = reference to a VulkanState struct
///		binding = binding index of the layout 
///		descriptor_count = count of the descriptors in case of an array of descriptors
///		shader_stage_flags = shader stages where the descriptor can be used
///		set_layout_create_flags = only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
///	Returns: VkDescriptorSetLayout
auto createSetLayout(
	ref Vulkan 			vk,
	uint32_t			binding,
	VkDescriptorType	descriptor_type,
	uint32_t			descriptor_count,
	VkShaderStageFlags	shader_stage_flags,
	VkDescriptorSetLayoutCreateFlags set_layout_create_flags
	) {
	const VkDescriptorSetLayoutBinding[1] descriptor_set_layout_bindings = [ 
		VkDescriptorSetLayoutBinding( binding, descriptor_type, descriptor_count, shader_stage_flags, null ) 
	];
	return vk.createSetLayout( descriptor_set_layout_bindings, set_layout_create_flags );
}


/// create a VkDescriptorSetLayout from several VkDescriptorSetLayoutBinding(s)
///	Params:
///		vk = reference to a VulkanState struct
///		descriptor_set_layout_bindings = to specify the multi binding set layout 
///		set_layout_create_flags = only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
///	Returns: VkDescriptorSetLayout
auto createSetLayout(
	ref Vulkan 								vk,
	const VkDescriptorSetLayoutBinding[]	descriptor_set_layout_bindings,
	VkDescriptorSetLayoutCreateFlags 		set_layout_create_flags = 0
	) {
	VkDescriptorSetLayoutCreateInfo descriptor_set_layout_create_info = {
		flags			: set_layout_create_flags,
		bindingCount	: descriptor_set_layout_bindings.length.toUint,
		pBindings		: descriptor_set_layout_bindings.ptr,
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
///		descriptor_sets_layouts = the layouts for the resulting descriptor set
///	Returns: std.container.array!VkDescriptorSet
auto allocateSet( ref Vulkan vk, VkDescriptorPool descriptor_pool, VkDescriptorSetLayout[] descriptor_sets_layouts ) {
	VkDescriptorSetAllocateInfo descriptor_allocate_info = {
		descriptorPool		: descriptor_pool,
		descriptorSetCount	: descriptor_sets_layouts.length.toUint,
		pSetLayouts			: descriptor_sets_layouts.ptr,
	};

	auto descriptor_sets = sizedArray!VkDescriptorSet( descriptor_sets_layouts.length );
	vkAllocateDescriptorSets( vk.device, &descriptor_allocate_info, descriptor_sets.ptr ).vkEnforce;
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
	mixin						Vulkan_State_Pointer;
	private VkDescriptorPool	pool;	// this must not be directly set able other than from module
	auto descriptor_pool()		{ return pool; }	// use getter function to get a copy		
	uint32_t[ VK_DESCRIPTOR_TYPE_RANGE_SIZE ] descriptor_counts;
	VkDescriptorSetLayout		descriptor_set_layout;
	VkDescriptorSet				descriptor_set;

	Array!VkDescriptorSetLayoutBinding	descriptor_set_layout_bindings;	// the set layout bindings of the resulting set
	Array!VkSampler						immutable_samplers;				// slices of this member can be associated with any layout binding

	Array!VkWriteDescriptorSet		  	write_descriptor_sets;			// write descriptor sets in case we want to update the set
	Array!VkDescriptorImageInfo			image_infos;					// slices of these three members ...
	Array!VkDescriptorBufferInfo		buffer_infos;					// ... can be associated with ...
	Array!VkBufferView					texel_buffer_views;				// ... any write_descriptor_set

	void destroyResources() {
		vk.destroy( descriptor_set_layout );
		if( pool != VK_NULL_HANDLE )
			vk.destroy( pool );
	}
}


// add editable layout binding
auto ref addLayoutBinding(
	ref Meta_Descriptor meta,
	uint32_t			binding,
	VkDescriptorType	descriptor_type,
	VkShaderStageFlags	shader_stage_flags ) {

	meta.descriptor_set_layout_bindings.append(
		VkDescriptorSetLayoutBinding(
			binding,
			descriptor_type,
			1,
			shader_stage_flags,
			null
		)
	);

	meta.write_descriptor_sets.length = meta.write_descriptor_sets.length + 1;
	with( meta.write_descriptor_sets[ $-1 ] ) {
		dstSet				= meta.descriptor_set;
		dstBinding			= binding;
	//	dstArrayElement		= 0;	// this is most probably not interesting for initialization
		descriptorCount		= 1;
		descriptorType		= descriptor_type;
	//	pImageInfo			= null;
	//	pBufferInfo			= null;
	//	pTexelBufferView	= null;
	}

	return meta;
}

// to avoid code duplication this template function
private auto ref addDescriptorType(
	DESCRIPTOR_TYPE, 
	alias descriptor_array, 
	alias write_pointer 
	)( 
	ref Meta_Descriptor meta,
	DESCRIPTOR_TYPE descriptor
	) {
	pragma( inline, true ); // this function should be inlined

	// meta.descriptor_array.append( descriptor );
	__traits( getMember, meta, descriptor_array ).append( descriptor );

	auto write_set  = & meta.write_descriptor_sets[ $-1 ];
	auto set_layout = & meta.descriptor_set_layout_bindings[ $-1 ];
	
	// increase the descriptor_count of the current descriptor_type
	++meta.descriptor_counts[ cast( size_t )set_layout.descriptorType ];

	if( __traits( getMember, write_set, write_pointer ) is null ) {
		// write_set.write_pointer 						= & meta.descriptor_array[ $-1 ];
		__traits( getMember, write_set, write_pointer ) = &__traits( getMember, meta, descriptor_array )[ $-1 ];
	} else {
		write_set.descriptorCount  += 1;
		set_layout.descriptorCount += 1;
	}
	return meta;
}


// add descriptor image info 
auto ref addImageInfo(
	ref Meta_Descriptor	meta, 
	VkSampler			sampler,
	VkImageView			image_view,
	VkImageLayout		image_layout ) {

	// Todo(pp): check if compatible to meta.write_descriptor_sets[ $-1 ].descriptor_type;
	// see spec 1.0.42 p. 382, pdf p. 391
	// VK_DESCRIPTOR_TYPE_SAMPLER, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
	// VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
	// VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT

	return addDescriptorType!
		( VkDescriptorImageInfo, "image_infos", "pImageInfo" ) 
		( meta, VkDescriptorImageInfo( sampler, image_view, image_layout ));
}


// add descriptor buffer info 
auto ref addBufferInfo(
	ref Meta_Descriptor	meta, 
	VkBuffer			buffer,
	VkDeviceSize		offset,
	VkDeviceSize		range ) {

	// Todo(pp): check if compatible to meta.write_descriptor_sets[ $-1 ].descriptor_type;
	// see spec 1.0.42 p. 382, pdf p. 391
	// VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
	// VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC

	return addDescriptorType!
		( VkDescriptorBufferInfo, "buffer_infos", "pBufferInfo" ) 
		( meta, VkDescriptorBufferInfo( buffer, offset, range ));
}


// add descriptor texel buffer view 
auto ref addTexelBufferView(
	ref Meta_Descriptor	meta, 
	VkBufferView		buffer_view ) {

	// Todo(pp): check if compatible to meta.write_descriptor_sets[ $-1 ].descriptor_type;
	// see spec 1.0.42 p. 382, pdf p. 391
	// VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER, VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER

	return addDescriptorType!
		( VkBufferView, "texel_buffer_views", "pTexelBufferView" )
		( meta, buffer_view );
}


// add immutable sampler 
auto ref addImmutableSampler(
	ref Meta_Descriptor	meta, 
	VkSampler			sampler ) {

	// Todo(pp): check if compatible to meta.write_descriptor_sets[ $-1 ].descriptor_type;
	meta.immutable_samplers.append( sampler );

	auto set_layout = & meta.descriptor_set_layout_bindings[ $-1 ];

	if( set_layout.pImmutableSamplers is null ) {
		set_layout.pImmutableSamplers = & meta.immutable_samplers[ $-1 ];
		// Note(pp): need to remove the latest write descriptor set
		// immutable samplers are not updated with VkWriteDescriptorSet
		// but hard coded into the VkDescriptorSetLayoutBinding
		meta.write_descriptor_sets.length = meta.write_descriptor_sets.length - 1;
	} else {
		set_layout.descriptorCount += 1;
	}
	return meta;
}


auto ref construct( ref Meta_Descriptor meta, VkDescriptorPoolCreateFlags descriptor_pool_create_flags = 0 ) {
	meta.createSetLayout
		.allocateSet( descriptor_pool_create_flags )
		.updateSet;
	return meta;
}


///		set_layout_create_flags = only one flag available: VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR
///	Returns: VkDescriptorSetLayout
auto ref createSetLayout( ref Meta_Descriptor meta, VkDescriptorSetLayoutCreateFlags set_layout_create_flags = 0 ) {
	meta.descriptor_set_layout = meta.createSetLayout( meta.descriptor_set_layout_bindings.data, set_layout_create_flags );
	return meta;
}


auto ref allocateSet( ref Meta_Descriptor meta, VkDescriptorPoolCreateFlags descriptor_pool_create_flags = 0  ) {

	// Todo(pp): figure out a scenario in which this meta struct could be reused  
	if( meta.descriptor_pool != VK_NULL_HANDLE )
		meta.destroyResources;

	// create an static array of pool VkDescriptorPoolSize
	VkDescriptorPoolSize[ VK_DESCRIPTOR_TYPE_RANGE_SIZE ] descriptor_pool_sizes;

	// use this to edit data at descriptor_pool_sizes[ pool_size_index ]
	// with this approach we are merging used meta.descriptor_counts ( non zero values in at index descriptor_type )
	size_t pool_size_index;
	
	// the iter index descriptor_type corresponds to a certain VkDescriptorType enum
	foreach( descriptor_type, descriptor_count; meta.descriptor_counts ) {
		if( descriptor_count > 0 ) {
			descriptor_pool_sizes[ pool_size_index ].type = cast( VkDescriptorType )descriptor_type;
			descriptor_pool_sizes[ pool_size_index ].descriptorCount = descriptor_count;
			++pool_size_index;
		}
	}

	// create the descriptor pool
	// pool_size_index now represents the count of used pool sizes in descriptor_pool_sizes
	meta.pool = meta.createDescriptorPool( 
		descriptor_pool_sizes[ 0 .. pool_size_index ], 1, descriptor_pool_create_flags );

	// allocate the descriptor_set
	meta.descriptor_set = meta.allocateSet( meta.descriptor_pool, meta.descriptor_set_layout );

	return meta;
}


auto ref allocateSet( ref Meta_Descriptor meta, VkDescriptorPool descriptor_pool ) {
	meta.descriptor_set = meta.allocateSet( descriptor_pool, meta.descriptor_set_layout );
	return meta;
}




auto ref updateSet( ref Meta_Descriptor meta ) {

	// patch all the write_descriptor_sets with the descriptor_set
	foreach( ref write_set; meta.write_descriptor_sets )
		write_set.dstSet = meta.descriptor_set;

	meta.device.vkUpdateDescriptorSets( 
		meta.write_descriptor_sets.length.toUint,
		meta.write_descriptor_sets.ptr, 0, null
	);	// last parameters are copy count and pointer to copies

	return meta;
}



// Note(pp): the functions bellow are meant
// to define the descriptor_set_layout and allocate the descriptor_set 
// but they will not be updated with VkWriteDescriptorSet structs
// the set can be updated in other ways later either with writing or copying from other sets
// or with vkCmdPushDescriptorSetKHR if available ()

// add empty count layout binding
auto ref addLayoutBinding(
	ref Meta_Descriptor meta,
	uint32_t			binding,
	VkDescriptorType	descriptor_type,
	uint32_t			descriptor_count,
	VkShaderStageFlags	shader_stage_flags ) {

	meta.descriptor_set_layout_bindings.append(
		VkDescriptorSetLayoutBinding(
			binding,
			descriptor_type,
			descriptor_count,
			shader_stage_flags,
			null
		)
	);
	return meta;
}

// add one immutable sampler layout binding
auto ref addLayoutBinding(
	ref Meta_Descriptor meta,
	uint32_t			binding,
	VkDescriptorType	descriptor_type,
	const ref VkSampler immutable_sampler,
	VkShaderStageFlags	shader_stage_flags,
	string				file = __FILE__,
	size_t				line = __LINE__,
	string				func = __FUNCTION__
	) {
	return meta.addLayoutBinding( 
		binding,
		descriptor_type,
		( & immutable_sampler )[0..1],
		shader_stage_flags,
		file, line, func
	);
}

// add slice of immutable sampler layout binding
auto ref addLayoutBinding(
	ref Meta_Descriptor meta,
	uint32_t			binding,
	VkDescriptorType	descriptor_type,
	const VkSampler[]	immutable_samplers,
	VkShaderStageFlags	shader_stage_flags,
	string				file = __FILE__,
	size_t				line = __LINE__,
	string				func = __FUNCTION__
	) {
	vkEnforce(
		( descriptor_type == VK_DESCRIPTOR_TYPE_SAMPLER ) ||
		( descriptor_type == VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER ),
		"Immutable samplers must be of descriptor_type VK_DESCRIPTOR_TYPE_SAMPLER or VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER",
		file, line, func
	);

	meta.descriptor_set_layout_bindings.append(
		VkDescriptorSetLayoutBinding(
			binding,
			descriptor_type,
			immutable_samplers.length.toUint,
			shader_stage_flags,
			immutable_samplers.ptr,
		)
	);
	return meta;
}

// add layout binding with VkDescriptorSetLayoutBinding
auto ref addLayoutBinding( ref Meta_Descriptor meta, VkDescriptorSetLayoutBinding set_layout_binding ) {
	meta.descriptor_set_layout_bindings.append( set_layout_binding );
	return meta;
}




