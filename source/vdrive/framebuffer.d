module vdrive.framebuffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;


void initFramebuffer( Array_T )(
	ref Vulkan				vk,
	Array_T					present_image_views,
	VkFormat				present_image_format,
	VkExtent2D				framebuffer_extent,
	VkSampleCountFlagBits	sample_count = VK_SAMPLE_COUNT_4_BIT )
if( is( Array_T == Array!VkImageView ) || is( Array_T : VkImageView[] )) {

	// create attachment description
	VkAttachmentDescription[3] attachment_description; 
	{
		VkAttachmentDescription color_description = {
			samples			: sample_count,
			loadOp			: VK_ATTACHMENT_LOAD_OP_CLEAR,
			stencilLoadOp	: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp	: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			format			: vk.color_image_format,
			storeOp			: VK_ATTACHMENT_STORE_OP_STORE,
			initialLayout	: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
			finalLayout		: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
		};

		VkAttachmentDescription depth_description = {
			samples			: sample_count,
			loadOp			: VK_ATTACHMENT_LOAD_OP_CLEAR,
			stencilLoadOp	: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp	: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			format			: vk.depth_image_format,
			storeOp			: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			initialLayout	: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
			finalLayout		: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		};

		VkAttachmentDescription chain_description = {
			samples			: VK_SAMPLE_COUNT_1_BIT,
			loadOp			: VK_ATTACHMENT_LOAD_OP_CLEAR,
			stencilLoadOp	: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp	: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			format			: present_image_format,
			storeOp			: VK_ATTACHMENT_STORE_OP_STORE,
			initialLayout	: VK_IMAGE_LAYOUT_UNDEFINED,		//VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
			finalLayout		: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,	//VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
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






	// create subpass
	VkSubpassDescription subpass_description = {
		pipelineBindPoint		: VK_PIPELINE_BIND_POINT_GRAPHICS,
		colorAttachmentCount	: 1,
		pColorAttachments		: &color_attachment_reference,
		pResolveAttachments		: &chain_attachment_reference,
		pDepthStencilAttachment	: &depth_attachment_reference,
	};

	VkRenderPassCreateInfo render_pass_create_info = {
		attachmentCount	: cast( uint32_t )attachment_description.length,
		pAttachments	: attachment_description.ptr,
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
		attachmentCount	: cast( uint32_t )framebuffer_attachments.length,  // must be equal to the attachment count on render pass
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

