module vdrive.framebuffer;

import core.stdc.stdio : printf;

import vdrive.util;
import vdrive.state;

import erupted;


void initFramebuffer( ref Vulkan vk, VkImageView[] present_image_views ) {

	// create attachment description
	VkAttachmentDescription[2] attachment_description;
	foreach( ref pass; attachment_description ) {
		pass.samples = VK_SAMPLE_COUNT_1_BIT;
		pass.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
		pass.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
		pass.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
	}

	attachment_description[0].format = vk.present_image_format;
	attachment_description[0].storeOp = VK_ATTACHMENT_STORE_OP_STORE;
	attachment_description[0].initialLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
	attachment_description[0].finalLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

	attachment_description[1].format = vk.depth_image_format;
	attachment_description[1].storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
	attachment_description[1].initialLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
	attachment_description[1].finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

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
	framebufferCreateInfo.attachmentCount = framebuffer_attachments.length;  // must be equal to the attachment count on render pass
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

