module vdrive.util.util;

import erupted;


alias vkMajor = VK_VERSION_MAJOR;
alias vkMinor = VK_VERSION_MINOR;
alias vkPatch = VK_VERSION_PATCH;

alias vk_enforce = vkEnforce;
void vkEnforce( VkResult vkResult ) {
	import std.exception : enforce;
	import std.conv : to;
	enforce( vkResult == VK_SUCCESS, vkResult.to!string );
}
