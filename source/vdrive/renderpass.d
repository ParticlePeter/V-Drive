module vdrive.renderpass;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;



///////////////////////////////////////
// Meta_Subpass and Meta_Renderpass //
///////////////////////////////////////


/// struct to collect
private struct Meta_Subpass {
	VkSubpassDescriptionFlags	flags;
	VkPipelineBindPoint			pipeline_bind_point = VK_PIPELINE_BIND_POINT_GRAPHICS;
	Array!VkAttachmentReference	input_reference;
	Array!VkAttachmentReference	color_reference;
	Array!VkAttachmentReference	resolve_reference;
	Array!VkAttachmentReference	preserve_reference;
	VkAttachmentReference		depth_stencil_reference; //= VK_ATTACHMENT_UNUSED;
}


struct Meta_Renderpass {
	mixin							Vulkan_State_Pointer;
	ref VkRenderPass				render_pass() { return begin_info.renderPass; }
	VkRenderPassBeginInfo			begin_info;		// the actual renderpass is stored in a member of this struct
	Array!VkAttachmentDescription	attachment_descriptions;
	Array!Meta_Subpass				subpasses;
	private Meta_Subpass*			subpass;
	Array!VkSubpassDependency		subpass_dependencies;

	//mixin Dispatch_To_Inner_Struct!begin_info;	// Does not work because it has precedence over UFCS
	
	void destroyResources() {
		vk.device.vkDestroyRenderPass( render_pass, vk.allocator );
	}
}



auto ref renderPassAttachment(
	ref Meta_Renderpass	meta,
	VkFormat				image_format,
	VkSampleCountFlagBits	sample_count,
	VkAttachmentLoadOp		load_op,
	VkAttachmentStoreOp		store_op,
	VkAttachmentLoadOp		stencil_load_op,
	VkAttachmentStoreOp		stencil_store_op,
	VkImageLayout			initial_layout,
	VkImageLayout			final_layout	= VK_IMAGE_LAYOUT_MAX_ENUM ) {

	VkAttachmentDescription attachment_description = {
		format			: image_format,
		samples			: sample_count,
		loadOp			: load_op,
		storeOp			: store_op,
		stencilLoadOp	: stencil_load_op,
		stencilStoreOp	: stencil_store_op,
		initialLayout	: initial_layout,
		finalLayout		: final_layout,
	};

	meta.attachment_descriptions.append( attachment_description );
	return meta;
}


auto ref renderPassAttachment(
	ref Meta_Renderpass	meta,
	VkFormat				image_format,
	VkSampleCountFlagBits	sample_count,
	VkAttachmentLoadOp		load_op,
	VkAttachmentStoreOp		store_op,
	VkImageLayout			initial_layout,
	VkImageLayout			final_layout	= VK_IMAGE_LAYOUT_MAX_ENUM ) {

	return renderPassAttachment( meta, image_format, sample_count, load_op, store_op,
		VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
};


auto ref renderPassAttachImpl( alias load_op, alias store_op )(
	ref Meta_Renderpass		meta,
	VkFormat				image_format,
	VkSampleCountFlagBits	sample_count,
	VkImageLayout			initial_layout,
	VkImageLayout			final_layout	= VK_IMAGE_LAYOUT_MAX_ENUM ) {

	return renderPassAttachment( meta, image_format, sample_count, load_op, store_op,
		VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, final_layout );
};


alias renderPassAttachment_Load_None	= renderPassAttachImpl!( VK_ATTACHMENT_LOAD_OP_LOAD, VK_ATTACHMENT_STORE_OP_DONT_CARE );
alias renderPassAttachment_Load_Store	= renderPassAttachImpl!( VK_ATTACHMENT_LOAD_OP_LOAD, VK_ATTACHMENT_STORE_OP_STORE );
alias renderPassAttachment_Clear_None	= renderPassAttachImpl!( VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_DONT_CARE );
alias renderPassAttachment_Clear_Store	= renderPassAttachImpl!( VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE );
alias renderPassAttachment_None_None	= renderPassAttachImpl!( VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE );
alias renderPassAttachment_None_Store	= renderPassAttachImpl!( VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_STORE );


// cannot use subpassReference as function overload as aliases bellow cannot be set for function overloads with different args
auto ref firstSubpassReference( string reference )( ref Meta_Renderpass meta, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) {
	assert( meta.attachment_descriptions.length > 0 );
	return subpassReference!reference( meta, toUint( meta.attachment_descriptions.length - 1 ), render_layout );
}

alias subpassRefInput			= firstSubpassReference!( "input" );
alias subpassRefColor			= firstSubpassReference!( "color" );
alias subpassRefResolve			= firstSubpassReference!( "resolve" );
alias subpassRefPreserve		= firstSubpassReference!( "preserve" );
alias subpassRefDepthStencil	= firstSubpassReference!( "depth_stencil" );


auto ref subpassReference( string reference )( ref Meta_Renderpass meta, uint32_t attachment_index, VkImageLayout render_layout = VK_IMAGE_LAYOUT_MAX_ENUM ) {

	if( meta.subpasses.length == 0 )
		meta.appendSubpass;

	VkAttachmentReference attachment_reference = {
		attachment	: ( meta.attachment_descriptions.length - 1 ).toUint,
		layout		: render_layout == VK_IMAGE_LAYOUT_MAX_ENUM ? meta.attachment_descriptions[$-1].initialLayout : render_layout,
	};

	// if attachment_descriptions[$-1].finalLayout is VK_IMAGE_LAYOUT_MAX_ENUM this means it is supposed to be the same as render_layout
	if( meta.attachment_descriptions[$-1].finalLayout == VK_IMAGE_LAYOUT_MAX_ENUM )
		meta.attachment_descriptions[$-1].finalLayout = attachment_reference.layout;

		 static if( reference == "input" ) 			meta.subpass.input_reference.insert( attachment_reference );
	else static if( reference == "color" ) 			meta.subpass.color_reference.insert( attachment_reference );
	else static if( reference == "resolve" ) 		meta.subpass.resolve_reference.insert( attachment_reference );
	else static if( reference == "preserve" ) 		meta.subpass.preserve_reference.insert( attachment_reference );
	else static if( reference == "depth_stencil" ) 	meta.subpass.depth_stencil_reference = attachment_reference;

	return meta;
}

alias subpassRefInput			= subpassReference!( "input" );
alias subpassRefColor			= subpassReference!( "color" );
alias subpassRefResolve			= subpassReference!( "resolve" );
alias subpassRefPreserve		= subpassReference!( "preserve" );
alias subpassRefDepthStencil	= subpassReference!( "depth_stencil" );




private auto ref mayAliasOrBindPoint( alias value )( ref Meta_Renderpass meta, size_t index = size_t.max )
if( is( typeof( value ) == VkPipelineBindPoint ) || is( typeof( value ) == VkAttachmentDescriptionFlagBits ))
{
	assert( meta.subpasses.length > 0 );
	if( index == size_t.max ) {
		static if( is( typeof( value ) == VkPipelineBindPoint ))	meta.subpasses[ $-1 ].pipeline_bind_point = value;
		else static if( is( typeof( value ) == VkAttachmentDescriptionFlagBits ))	meta.subpasses[ $-1 ].flags = value;
	} else {
		assert( index < meta.subpasses.length );
		static if( is( typeof( value ) == VkPipelineBindPoint ))	meta.subpasses[ $-1 ].pipeline_bind_point = value;
		else static if( is( typeof( value ) == VkAttachmentDescriptionFlagBits ))	meta.subpasses[ $-1 ].flags = value;
	}
	return meta;
}

// Per Spec v1.0.21 p.118 valid usage of a VkSubpassDescription: "pipelineBindPoint must be VK_PIPELINE_BIND_POINT_GRAPHICS", hence bellow obsolete 
//auto ref graphicBindPoint( ref Meta_Renderpass meta, size_t index = size_t.max ) { return mayAliasOrBindPoint!VK_PIPELINE_BIND_POINT_GRAPHICS( meta, index ); }	// for sake of completeness
//auto ref computeBindPoint( ref Meta_Renderpass meta, size_t index = size_t.max ) { return mayAliasOrBindPoint!VK_PIPELINE_BIND_POINT_COMPUTE(  meta, index ); }
auto ref mayAlias( ref Meta_Renderpass meta, size_t index = size_t.max ) { return mayAliasOrBindPoint!VK_ATTACHMENT_DESCRIPTION_MAY_ALIAS_BIT( meta, index ); }



///	append a Meta_Subpass to the subpasses array of Meta_Renderpass
/// consecutive subpass related function calls will create resources for this Meta_Structure if no index is specified
///	Params:
///		meta = reference to a Meta_Renderpass struct
///	Returns: the passed in Meta_Structure for function chaining 
auto ref appendSubpass( ref Meta_Renderpass meta ) {
	meta.subpasses.length = meta.subpasses.length + 1;
	meta.subpass = &meta.subpasses[ $-1 ];
	return meta; 
}


///	set clear values into the render pass begin info
/// usage of either this function or attachFramebuffer(s) is required to set clear values for the later used VkRenderPassBeginInfo
///	Params:
///		meta = reference to a Meta_Renderpass struct
///		clear_values = will be set into the meta render pass VkRenderPassBeginInfo. Storage must be managed outside
///	Returns: the passed in Meta_Structure for function chaining
auto ref clearValues( Array_T )( ref Meta_Renderpass meta, Array_T clear_values )
if( is( Array_T == Array!VkClearValue ) || is( Array_T : VkClearValue[] )) {
	meta.begin_info.pClearValues = clear_values.ptr;
	meta.begin_info.clearValueCount = clear_values.length.toUint;
	return meta;
}

// TODO(pp): not having a depth attachment does not work. Fix it!

///	construct a VkRenderPass from specified resources of Meta_Renderpass structure and store it there as well
///	Params:
///		meta = reference to a Meta_Renderpass struct
///	Returns: the passed in Meta_Structure for function chaining 
auto ref construct( ref Meta_Renderpass meta ) {
	// assert that meta struct is initialized with a valid vulkan state pointer
	assert( meta.isValid );

	// extract VkSubpassDescription from Meta_Subpass
	auto subpass_descriptions = sizedArray!VkSubpassDescription( meta.subpasses.length );
	foreach( i, ref subpass; meta.subpasses.data ) {

		// assert that resolve references length is less or equal to color references length
		// do nothing if resolve references length is 0, but if reference length is strictly less then color reference length
		// fill resolve reference length with VkAttachmentReference( VK_ATTACHMENT_UNUSED, layout arbitrary ) 
		assert( subpass.resolve_reference.length <= subpass.color_reference.length );
		if( subpass.resolve_reference.length > 0 && subpass.resolve_reference.length < subpass.color_reference.length ) {
			//subpass.resolve_reference.reserve( subpass.color_reference.length );
			//foreach( j; subpass.resolve_reference.length .. subpass.color_reference.length )
			//	subpass.resolve_reference.append( VkAttachmentReference( VK_ATTACHMENT_UNUSED, VK_IMAGE_LAYOUT_UNDEFINED ));
			auto old_length = subpass.resolve_reference.length;
			subpass.resolve_reference.length = subpass.color_reference.length;
			subpass.resolve_reference[ old_length .. subpass.resolve_reference.length ] = VkAttachmentReference( VK_ATTACHMENT_UNUSED, VK_IMAGE_LAYOUT_UNDEFINED );
		}

		// fill the current VkSubpassDescription with data from coresponding Meta_Subpass
		subpass_descriptions[i].pipelineBindPoint		=  subpass.pipeline_bind_point;
		subpass_descriptions[i].inputAttachmentCount	=  subpass.input_reference.length.toUint;
		subpass_descriptions[i].pInputAttachments		=  subpass.input_reference.ptr;
		subpass_descriptions[i].colorAttachmentCount	=  subpass.color_reference.length.toUint;
		subpass_descriptions[i].pColorAttachments		=  subpass.color_reference.ptr;
		subpass_descriptions[i].pResolveAttachments		=  subpass.resolve_reference.ptr;
		subpass_descriptions[i].pDepthStencilAttachment	= &subpass.depth_stencil_reference;
	}


	// use the new Array!VkSubpassDescription to create the VkRenderPass
	VkRenderPassCreateInfo render_pass_create_info = {
		attachmentCount	: meta.attachment_descriptions.length.toUint,
		pAttachments	: meta.attachment_descriptions.ptr,
		subpassCount	: subpass_descriptions.length.toUint,
		pSubpasses		: subpass_descriptions.ptr,
		dependencyCount	: meta.subpass_dependencies.length.toUint,
		pDependencies	: meta.subpass_dependencies.ptr,
	};

	vkCreateRenderPass( meta.device, &render_pass_create_info, meta.allocator, &meta.begin_info.renderPass ).vkEnforce;
	return meta;
}




//////////////////////
// Meta_Framebuffer //
//////////////////////

/// aggregate to manage one framebuffer and the related resources aka render area and clear values of the attachments
struct Meta_Framebuffer {
	mixin 					Vulkan_State_Pointer;
	VkFramebuffer			framebuffer;
	VkRect2D				render_area;
	Array!VkClearValue		clear_values;	// coresponds to Meta_Renderpass.attachment_Descriptions

	void destroyResources() {
		vk.device.vkDestroyFramebuffer( framebuffer, vk.allocator );
	}
}


/// aggregate to manage multiple framebuffers sharing same frambuffer resources aka render area and clear values of the attachments 
struct Meta_Framebuffers {
	mixin 					Vulkan_State_Pointer;
	Array!VkFramebuffer		framebuffers;
	VkRect2D				render_area;
	Array!VkClearValue		clear_values;	// coresponds to Meta_Renderpass.attachment_Descriptions

	void destroyResources() {
		foreach( framebuffer; framebuffers ) vk.device.vkDestroyFramebuffer( framebuffer, vk.allocator );
	}
}



/// Set or append an attachment specific clear value, several overloads exist
/// The last argument is an optional attachment index:
///		if it is not provided the clear value gets appended
///		else if the clear value array is too short it is expanded, new entries filled with default values
///		and the passed in clear value is set at the specified index
/// Three overloads exist, each with first param of Meta_Framebuffer and an additional optional attachment index:
///		1.: 4 (+1) parameters each of type float, int32_t or uint32_t to set color clear values (at specified index)
///		2.: 2 (+1) parameters, float and uint32_t specifying depth and stencil (at specified index)
///		3.: 1 (+1) parameter of type VkClearValue setting directly the Vulkan clear value (at specified index)
///	Params:
///		meta = reference to a Meta_Framebuffer or Meta_Framebuffers struct
///		args = Arguments as described above
///	Returns: the passed in Meta_Structure for function chaining 
auto ref clearValue( META_FB, Args... )( ref META_FB meta, Args args )
if(( is( META_FB == Meta_Framebuffer ) || is( META_FB == Meta_Framebuffers )) && Args.length > 0 && Args.length < 6 ) {

	// clear values [r, g, b, a] and optional array index
	static if( Args.length > 3 && is( Args[0] == Args[1] ) && is( Args[0] == Args[2] ) && is( Args[0] == Args[3] )) {
		VkClearValue clear_value;
		Args[0][4] clear_data = [ args[0], args[1], args[2], args[3] ]; 
				static if( is( Args[0] == float ))		clear_value.color.float32	= clear_data;
		else	static if( is( Args[0] == int32_t ))	clear_value.color.int32		= clear_data;
		else	static if( is( Args[0] == uint32_t ))	clear_value.color.uint32	= clear_data;

		return clearValue( meta, clear_value, args[4..$] );		// last argument yields zero or one argument which is the index 
	}

	// clear values depth and stencil and optional index, first arg must not be VkClearValue
	else static if( Args.length > 1 && is( Args[0] == float ) && is( Args[1] : uint32_t )) {
		VkClearValue clear_value = { depthStencil : VkClearDepthStencilValue( args[0], args[1].toUint ) };
		return clearValue( meta, clear_value, args[2..$] );
	}

	// direct clear value struct, implemented logic for setting, extending and/or appending
	else static if( is( Args[0] == VkClearValue )) {
		static if( Args.length == 2 && is( args[1] : size_t )) {
			size_t index = args[1];
			if( meta.clear_values.length <= index )
				meta.clear_values.length  = index + 1;
			meta.clear_values[ index ] = args[0];
		} else {
			meta.clear_values.append( args[0] );
		}
		return meta;
	}

	else {	// should not reach here
		pragma( msg, "\n" );
		pragma( msg, META_FB );
		foreach( Arg; Args )	pragma( msg, Arg );
		static assert( 0 );
	} 
}

///	set the render area offset seperate from the extent
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
///	for Vulkan itself this parameter is just an optimazation hint and must be properly set as scissor paramerter of VkPipelineViewportStateCreateInfo
///	Params:
///		meta   = reference to a Meta_Framebuffer or Meta_Framebuffers
///		offset = the offset of the render area
///	Returns: the passed in Meta_Structure for function chaining 
auto ref renderAreaOffset( META_FB )( ref META_FB meta, VkOffset2D offset ) if( is( META_FB == Meta_Framebuffer ) || is( META_FB == Meta_Framebuffers )) {
	meta.render_area.offset = offset;
	return meta;
}

///	set the render area extent seperate from the extent
/// the render area is passed into a VkRenderPassBeginInfo when the appropriate attachFramebuffer (see bellow) overload is called
///	for Vulkan itself this parameter is just an optimazation hint and must be properly set as scissor paramerter of VkPipelineViewportStateCreateInfo
///	Params:
///		meta   = reference to a Meta_Framebuffer or Meta_Framebuffers
///		extent = the extent of the render area
///	Returns: the passed in Meta_Structure for function chaining
auto ref renderAreaExtent( META_FB )( ref META_FB meta, VkExtent2D extent ) if( is( META_FB == Meta_Framebuffer ) || is( META_FB == Meta_Framebuffers )) {
	meta.render_area.extent = extent;
	return meta;
}



//////////////////////////////////////////////////
// connect Meta_Framebuffer to Meta_Renderpass //
//////////////////////////////////////////////////

///	set members of a Meta_Renderpass.VkRenderPassBeginInfo with the coresponding members of a Meta_Framebuffer structure
/// this should be called once if the framebuffer related members of the VkRenderPassBeginInfo are not changing later on
/// or before vkCmdBeginRenderPass to switch frambuffer, render area (hint, see renderAreaOffset/Extent) and clear values
///	Params:
///		meta_renderpass = reference to a Meta_Renderpass structure holding the VkRenderPassBeginInfo
///		meta_framebuffer = the Meta_Framebuffer structure whose frambuffer and resources will be attached
///	Returns: the passed in Meta_Structure for function chaining
auto ref attachFramebuffer( ref Meta_Renderpass meta_renderpass, ref Meta_Framebuffer meta_framebuffer ) {
	meta_renderpass.begin_info.framebuffer = meta_framebuffer.framebuffer;
	meta_renderpass.begin_info.renderArea = meta_framebuffer.render_area;
	meta_renderpass.begin_info.pClearValues = meta_framebuffer.clear_values.ptr;
	meta_renderpass.begin_info.clearValueCount = meta_framebuffer.clear_values.length.toUint;
	return meta_renderpass;
}

///	set members of a Meta_Renderpass.VkRenderPassBeginInfo with the coresponding members of a Meta_Framebuffers structure
/// this should be called once if the framebuffer related members of the VkRenderPassBeginInfo are not changing later on
/// or before vkCmdBeginRenderPass to switch frambuffer, render area (hint, see renderAreaOffset/Extent) and clear values
///	Params:
///		meta_renderpass  = reference to a Meta_Renderpass structure holding the VkRenderPassBeginInfo
///		meta_framebuffers = reference to the Meta_Framebuffer structure whose frambuffer and resources will be attached
///		framebuffer_index = the index to select a frambuffer from the member framebuffer array
///	Returns: the passed in Meta_Structure for function chaining
auto ref attachFramebuffer( ref Meta_Renderpass meta_renderpass, ref Meta_Framebuffers meta_framebuffers, size_t framebuffer_index ) {
	meta_renderpass.begin_info.framebuffer = meta_framebuffers.framebuffers[ framebuffer_index ];
	meta_renderpass.begin_info.renderArea = meta_framebuffers.render_area;
	meta_renderpass.begin_info.pClearValues = meta_framebuffers.clear_values.ptr;
	meta_renderpass.begin_info.clearValueCount = meta_framebuffers.clear_values.length.toUint;
	return meta_renderpass;
}

///	set framebuffer member of a Meta_Renderpass.VkRenderPassBeginInfo with a freambuffer not changing its framebuffer related resources
///	Params:
///		meta_renderpass = reference to a Meta_Renderpass structure holding the VkRenderPassBeginInfo
///		framebuffer      = the VkFramebuffer to attach to VkRenderPassBeginInfo
///	Returns: the passed in Meta_Structure for function chaining
auto ref attachFramebuffer( ref Meta_Renderpass meta_renderpass, VkFramebuffer framebuffer ) {
	meta_renderpass.begin_info.framebuffer = framebuffer;
	return meta_renderpass;
}


///	initialize the VkFramebuffer and store them in the meta structure
///	Params:
///		meta				= reference to a Meta_Framebuffer or Meta_Framebuffers
///		render_pass			= required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
///		framebuffer_extent	= the extent of the frambuffer, this is not(!) the render area
///		image_views			= these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
///	Returns: the passed in Meta_Structure for function chaining
auto ref initFramebuffer( ref Meta_Framebuffer meta, VkRenderPass render_pass, VkExtent2D framebuffer_extent, VkImageView[] image_views ) {
	// assert that meta struct is initialized with a valid vulkan state pointer
	assert( meta.isValid );

	// the framebuffer_extent is not(!) the render_area, but rather a specification of how big the framebuffer is
	// the render area specifies a renderable window into this frambuffer
	// this window must alos be set as scissors in the VkPipeline
	// here, if no render area was specified use the full framebuffer extent
	if( meta.render_area.extent.width == 0 || meta.render_area.extent.height == 0 )
		meta.renderAreaExtent( framebuffer_extent );

	VkFramebufferCreateInfo framebuffer_create_info = {
		renderPass		: render_pass,					// this defines render pass COMPATIBILITY	
		attachmentCount	: image_views.length.toUint,	// must be equal to the attachment count on render pass
		pAttachments	: image_views.ptr,
		width			: framebuffer_extent.width,
		height			: framebuffer_extent.height,
		layers			: 1,
	};

	// create the VkFramebuffer
	vkCreateFramebuffer( meta.device, &framebuffer_create_info, meta.allocator, &meta.framebuffer ).vkEnforce;

	return meta;
}


///	initialize the VkFramebuffer and store them in the meta structure
///	Params:
///		meta				= reference to a Meta_Framebuffer or Meta_Framebuffers
///		meta_renderpass	= the render_pass member is required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses,
///								additionally framebuffer[0], clear_values and extent are set into the VkRenderPassBeginInfo member  
///		framebuffer_extent	= the extent of the render area
///		image_views	= these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
///	Returns: the passed in Meta_Structure for function chaining
auto ref initFramebuffer( ref Meta_Framebuffer meta, ref Meta_Renderpass meta_renderpass, VkExtent2D framebuffer_extent, VkImageView[] image_views ) {
	meta.initFramebuffer( meta_renderpass.begin_info.renderPass, framebuffer_extent, image_views );
	meta_renderpass.attachFramebuffer( meta );
	return meta;
}

alias create = initFramebuffer;


auto createFramebuffer( ref Vulkan vk, VkRenderPass render_pass, VkExtent2D framebuffer_extent, VkImageView[] image_views ) {
	Meta_Framebuffer meta = vk;
	return meta.initFramebuffer( render_pass, framebuffer_extent, image_views );
}


auto createFramebuffer( ref Vulkan vk, ref Meta_Renderpass meta_renderpass, VkExtent2D framebuffer_extent, VkImageView[] image_views ) {
	Meta_Framebuffer meta = vk;
	return meta.initFramebuffer( meta_renderpass, framebuffer_extent, image_views );
}


///	initialize the VkFramebuffer(s) and store them in the meta structure
///	Params:
///		meta				= reference to a Meta_Framebuffer or Meta_Framebuffers
///		render_pass			= required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses
///		framebuffer_extent	= the extent of the frambuffer, this is not(!) the render area
///		first_image_views	= these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
///		dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length] 
///		last_image views	= these will be attached to each of the VkFramebuffer(s) attachments first_image_views.length + 1 .. last_image_view_length + 1 
///	Returns: the passed in Meta_Structure for function chaining
auto ref initFramebuffers(
	ref Meta_Framebuffers	meta,
	VkRenderPass			render_pass,
	VkExtent2D				framebuffer_extent,
	VkImageView[]			first_image_views,
	VkImageView[]			dynamic_image_views,
	VkImageView[]			last_image_views = [] ) {

	// assert that meta struct is initialized with a valid vulkan state pointer
	assert( meta.isValid );

	// the framebuffer_extent is not(!) the render_area, but rather a specification of how big the framebuffer is
	// the render area specifies a renderable window into this frambuffer
	// this window must alos be set as scissors in the VkPipeline
	// here, if no render area was specified use the full framebuffer extent
	if( meta.render_area.extent.width == 0 || meta.render_area.extent.height == 0 )
		meta.renderAreaExtent( framebuffer_extent );

	// copy the first image views, add another image for the dynamic image views and then the last image views
	// the dynamic image view will be filled with one of the dynamic_image_viewes in the framebuffer create loop
	auto image_views = sizedArray!VkImageView( first_image_views.length + 1 + last_image_views.length );
	foreach( i, image_view; first_image_views )
		image_views[ i ] = image_view;
	foreach( i, image_view; last_image_views )
		image_views[ first_image_views.length + 1 + i ] = image_view;

	VkFramebufferCreateInfo framebuffer_create_info = {
		renderPass		: render_pass,						// this defines render pass COMPATIBILITY	
		attachmentCount	: image_views.length.toUint,		// must be equal to the attachment count on render pass
		pAttachments	: image_views.ptr,
		width			: framebuffer_extent.width,
		height			: framebuffer_extent.height,
		layers			: 1,
	};

	// create a framebuffer per dynamic_image_view (e.g. for each swapchain image view)
	meta.framebuffers.length = dynamic_image_views.length;
	foreach( i, ref framebuffer; meta.framebuffers.data ) {
		image_views[ first_image_views.length ] = dynamic_image_views[ i ];
		vkCreateFramebuffer( meta.device, &framebuffer_create_info, meta.allocator, &framebuffer ).vkEnforce;
	}

	return meta;
}


///	initialize the VkFramebuffer(s) and store them in the meta structure
///	Params:
///		meta				= reference to a Meta_Framebuffer or Meta_Framebuffers
///		meta_renderpass	= the render_pass member is required for VkFramebufferCreateInfo to specify COMPATIBLE renderpasses,
///								additionally framebuffer[0], clear_values and extent are set into the VkRenderPassBeginInfo member  
///		extent				= the extent of the render area
///		first_image_views	= these will be attached to each of the VkFramebuffer(s) attachments 0 .. first_image_views.length
///		dynamic_image_views = the count of these specifies the count if VkFramebuffers(s), dynamic_imag_views[i] will be attached to framebuffer[i] attachment[first_image_views.length] 
///	Returns: the passed in Meta_Structure for function chaining
auto ref initFramebuffers( 
	ref Meta_Framebuffers	meta,
	ref Meta_Renderpass		meta_renderpass,
	VkExtent2D				framebuffer_extent,
	VkImageView[]			first_image_views,
	VkImageView[]			dynamic_image_views,
	VkImageView[]			last_image_views = [] ) {
	meta.initFramebuffers( meta_renderpass.begin_info.renderPass, framebuffer_extent, first_image_views, dynamic_image_views );
	meta_renderpass.attachFramebuffer( meta, 0 );
	return meta;
}

alias create = initFramebuffers;



auto createFramebuffers(
	ref Vulkan		vk,
	VkRenderPass	render_pass,
	VkExtent2D		framebuffer_extent,
	VkImageView[]	first_image_views,
	VkImageView[]	dynamic_image_views,
	VkImageView[]	last_image_views = [] ) {
	Meta_Framebuffers meta = vk;
	return meta.create( render_pass, framebuffer_extent, first_image_views, dynamic_image_views, last_image_views );
}


auto createFramebuffers(
	ref Vulkan				vk,
	ref Meta_Renderpass	meta_renderpass,
	VkExtent2D				framebuffer_extent,
	VkImageView[]			first_image_views,
	VkImageView[]			dynamic_image_views,
	VkImageView[]			last_image_views = [] ) {
	Meta_Framebuffers meta = vk;
	return meta.create( meta_renderpass, framebuffer_extent, first_image_views, dynamic_image_views );
}



// code reference not using Meta_Renderpass
/*
	// create attachment description
	VkAttachmentDescription[3] attachment_description; 
	{
		VkAttachmentDescription color_description = {
			format			: vk.color_image_format,
			samples			: sample_count,
			loadOp			: VK_ATTACHMENT_LOAD_OP_CLEAR,
			storeOp			: VK_ATTACHMENT_STORE_OP_STORE,
			stencilLoadOp	: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp	: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			initialLayout	: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
			finalLayout		: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
		};

		VkAttachmentDescription depth_description = {
			format			: vk.depth_image_format,
			samples			: sample_count,
			loadOp			: VK_ATTACHMENT_LOAD_OP_CLEAR,
			storeOp			: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			stencilLoadOp	: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp	: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			initialLayout	: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
			finalLayout		: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		};

		VkAttachmentDescription chain_description = {
			format			: present_image_format,
			samples			: VK_SAMPLE_COUNT_1_BIT,
			loadOp			: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			storeOp			: VK_ATTACHMENT_STORE_OP_STORE,
			stencilLoadOp	: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp	: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			initialLayout	: VK_IMAGE_LAYOUT_UNDEFINED,
			finalLayout		: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
		};

		attachment_description[0] = color_description;
		attachment_description[1] = depth_description;
		attachment_description[2] = chain_description;
	}

	VkAttachmentReference color_attachment_reference;
	color_attachment_reference.attachment = 0;
	color_attachment_reference.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

	VkAttachmentReference depth_attachment_reference;
	depth_attachment_reference.attachment = 1;
	depth_attachment_reference.layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

	VkAttachmentReference chain_attachment_reference;
	chain_attachment_reference.attachment = 2;
	chain_attachment_reference.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

	// create subpass description
	VkSubpassDescription subpass_description = {
		pipelineBindPoint		: VK_PIPELINE_BIND_POINT_GRAPHICS,
		colorAttachmentCount	: 1,
		pColorAttachments		: &color_attachment_reference,
		pResolveAttachments		: &chain_attachment_reference,
		pDepthStencilAttachment	: &depth_attachment_reference,
	};

	// renderpass create info
	VkRenderPassCreateInfo render_pass_create_info = {
		attachmentCount	: cast( uint32_t )attachment_description.length,
		pAttachments	: attachment_description.ptr,
		subpassCount	: 1,
		pSubpasses		: &subpass_description,
	};
*/

