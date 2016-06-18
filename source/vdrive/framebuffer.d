module vdrive.framebuffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;


void initFramebuffer( ref Vulkan vk, VkImageView[] present_image_views ) {

	// create attachment description
	VkAttachmentDescription[2] attachment_description; 
	{
		VkAttachmentDescription color_description = {
			samples			: VK_SAMPLE_COUNT_1_BIT,
			loadOp			: VK_ATTACHMENT_LOAD_OP_CLEAR,
			stencilLoadOp	: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp	: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			format			: vk.present_image_format,
			storeOp			: VK_ATTACHMENT_STORE_OP_STORE,
			initialLayout	: VK_IMAGE_LAYOUT_UNDEFINED,		//VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
			finalLayout		: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,	//VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
		};

		VkAttachmentDescription depth_description = {
			samples			: VK_SAMPLE_COUNT_1_BIT,
			loadOp			: VK_ATTACHMENT_LOAD_OP_CLEAR,
			stencilLoadOp	: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp	: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			format			: vk.depth_image_format,
			storeOp			: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			initialLayout	: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
			finalLayout		: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		};

		attachment_description[0] = color_description;
		attachment_description[1] = depth_description;
	}

	VkAttachmentReference color_attachment_reference;
	color_attachment_reference.attachment = 0;
	color_attachment_reference.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

	VkAttachmentReference depth_attachment_reference;
	depth_attachment_reference.attachment = 1;
	depth_attachment_reference.layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;






	// create subpass
	VkSubpassDescription subpass_description;
	subpass_description.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
	subpass_description.colorAttachmentCount = 1;
	subpass_description.pColorAttachments = &color_attachment_reference;
	subpass_description.pDepthStencilAttachment = &depth_attachment_reference;

	VkRenderPassCreateInfo render_pass_create_info = {};
	render_pass_create_info.attachmentCount = 2;
	render_pass_create_info.pAttachments = attachment_description.ptr;
	render_pass_create_info.subpassCount = 1;
	render_pass_create_info.pSubpasses = &subpass_description;

	vkCreateRenderPass( vk.device, &render_pass_create_info, vk.allocator, &vk.render_pass ).vk_enforce;


	// create framebuffer
	VkImageView[2] framebuffer_attachments;
	framebuffer_attachments[1] = vk.depth_image_view;

	VkFramebufferCreateInfo framebufferCreateInfo;
	framebufferCreateInfo.renderPass = vk.render_pass;
	framebufferCreateInfo.attachmentCount = cast( uint32_t )framebuffer_attachments.length;  // must be equal to the attachment count on render pass
	framebufferCreateInfo.pAttachments = framebuffer_attachments.ptr;
	framebufferCreateInfo.width = vk.surface_extent.width;
	framebufferCreateInfo.height = vk.surface_extent.height;
	framebufferCreateInfo.layers = 1;

	// create a framebuffer per swapchain imageView:
	vk.framebuffers.length = vk.present_images.length;
	foreach( i, ref framebuffer; vk.framebuffers.data ) {
	    framebuffer_attachments[0] = present_image_views[ i ];
	    vkCreateFramebuffer( vk.device, &framebufferCreateInfo, vk.allocator, &framebuffer ).vk_enforce;
	}
}

