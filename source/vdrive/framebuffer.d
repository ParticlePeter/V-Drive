module vdrive.framebuffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;




struct Meta_Framebuffer {
	mixin 							Vulkan_State_Pointer;
	Array!VkAttachmentDescription	attachment_descriptions;
	Array!VkAttachmentReference		attachment_references;
}


auto ref appendAttachInfo(
	ref Meta_Framebuffer	meta,
	VkFormat				image_format,
	VkSampleCountFlagBits	sample_count,
	VkAttachmentLoadOp		load_op,
	VkAttachmentStoreOp		store_op,
	VkAttachmentLoadOp		stencil_load_op,
	VkAttachmentStoreOp		stencil_store_op,
	VkImageLayout			initial_layout,
	VkImageLayout			render_layout	= VK_IMAGE_LAYOUT_MAX_ENUM,
	VkImageLayout			final_layout	= VK_IMAGE_LAYOUT_MAX_ENUM ) {

	VkAttachmentReference attachment_reference = {
		attachment	: meta.attachment_references.length.toUint,
		layout		: render_layout == VK_IMAGE_LAYOUT_MAX_ENUM ? initial_layout : render_layout,
	};

	VkAttachmentDescription attachment_description = {
		format			: image_format,
		samples			: sample_count,
		loadOp			: load_op,
		storeOp			: store_op,
		stencilLoadOp	: stencil_load_op,
		stencilStoreOp	: stencil_store_op,
		initialLayout	: initial_layout,
		finalLayout		: final_layout == VK_IMAGE_LAYOUT_MAX_ENUM ? attachment_reference.layout : final_layout,
	};

	meta.attachment_references.append( attachment_reference );
	meta.attachment_descriptions.append( attachment_description );
	return meta;
}


auto ref appendAttachInfo(
	ref Meta_Framebuffer	meta,
	VkFormat				image_format,
	VkSampleCountFlagBits	sample_count,
	VkAttachmentLoadOp		load_op,
	VkAttachmentStoreOp		store_op,
	VkImageLayout			initial_layout,
	VkImageLayout			render_layout	= VK_IMAGE_LAYOUT_MAX_ENUM,
	VkImageLayout			final_layout	= VK_IMAGE_LAYOUT_MAX_ENUM ) {

	return meta.appendAttachInfo( image_format, sample_count, load_op, store_op,
		VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, render_layout, final_layout );
};


auto ref appendAttachInfoSpecial( alias load_op, alias store_op )(
	ref Meta_Framebuffer	meta,
	VkFormat				image_format,
	VkSampleCountFlagBits	sample_count,
	VkImageLayout			initial_layout,
	VkImageLayout			render_layout	= VK_IMAGE_LAYOUT_MAX_ENUM,
	VkImageLayout			final_layout	= VK_IMAGE_LAYOUT_MAX_ENUM ) {

	return meta.appendAttachInfo( image_format, sample_count, load_op, store_op,
		VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, initial_layout, render_layout, final_layout );
};


alias appendAttachInfo_Load_None	= appendAttachInfoSpecial!( VK_ATTACHMENT_LOAD_OP_LOAD, VK_ATTACHMENT_STORE_OP_DONT_CARE );
alias appendAttachInfo_Load_Store	= appendAttachInfoSpecial!( VK_ATTACHMENT_LOAD_OP_LOAD, VK_ATTACHMENT_STORE_OP_STORE );
alias appendAttachInfo_Clear_None	= appendAttachInfoSpecial!( VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_DONT_CARE );
alias appendAttachInfo_Clear_Store	= appendAttachInfoSpecial!( VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE );
alias appendAttachInfo_None_None	= appendAttachInfoSpecial!( VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE );
alias appendAttachInfo_None_Store	= appendAttachInfoSpecial!( VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_STORE );





void initFramebuffer( Array_T )(
	ref Vulkan				vk,
	Array_T					present_image_views,
	VkFormat				present_image_format,
	VkExtent2D				framebuffer_extent,
	VkSampleCountFlagBits	sample_count = VK_SAMPLE_COUNT_4_BIT )
if( is( Array_T == Array!VkImageView ) || is( Array_T : VkImageView[] )) {

	Meta_Framebuffer meta = &vk;
	meta.appendAttachInfo_Clear_Store( vk.color_image_format, sample_count, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL );
	meta.appendAttachInfo_Clear_None( vk.depth_image_format, sample_count, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL );
	meta.appendAttachInfo_None_Store( present_image_format, VK_SAMPLE_COUNT_1_BIT,
		VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR );

	//writeln( meta.attachment_descriptions.length );
	//writeln( meta.attachment_references.length );

	// create subpass
	VkSubpassDescription subpass_description = {
		pipelineBindPoint		: VK_PIPELINE_BIND_POINT_GRAPHICS,
		colorAttachmentCount	: 1,
		pColorAttachments		: &meta.attachment_references[0],
		pResolveAttachments		: &meta.attachment_references[2],
		pDepthStencilAttachment	: &meta.attachment_references[1],
	};


	// renderpass create info
	VkRenderPassCreateInfo render_pass_create_info = {
		attachmentCount	: meta.attachment_descriptions.length.toUint,
		pAttachments	: meta.attachment_descriptions.ptr,
		subpassCount	: 1,
		pSubpasses		: &subpass_description,
	};

	vkCreateRenderPass( vk.device, &render_pass_create_info, vk.allocator, &vk.render_pass ).vkEnforce;


	// create framebuffer
	VkImageView[3] framebuffer_attachments;
	framebuffer_attachments[0] = vk.color_image_view;
	framebuffer_attachments[1] = vk.depth_image_view;

	VkFramebufferCreateInfo framebufferCreateInfo = {
		renderPass		: vk.render_pass,
		attachmentCount	: framebuffer_attachments.length.toUint,  // must be equal to the attachment count on render pass
		pAttachments	: framebuffer_attachments.ptr,
		width			: framebuffer_extent.width,
		height			: framebuffer_extent.height,
		layers			: 1,
	};

	// create a framebuffer per swapchain imageView:
	vk.framebuffers.length = present_image_views.length;
	foreach( i, ref framebuffer; vk.framebuffers.data ) {
	    framebuffer_attachments[2] = present_image_views[ i ];
	    vkCreateFramebuffer( vk.device, &framebufferCreateInfo, vk.allocator, &framebuffer ).vkEnforce;
	}
}


// code reference not using Meta_Framebuffer
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

