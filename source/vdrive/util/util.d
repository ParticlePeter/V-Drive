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



auto listVulkanProperty( ReturnType, alias func, Args... )( Args args ) {
	uint32_t count;

			static if( args.length == 1 )	func( args[0], &count, null ).vk_enforce;
	else	static if( args.length == 2 )	func( args[0], args[1], &count, null ).vk_enforce;
	else	static if( args.length == 3 )	func( args[0], args[1], args[2], &count, null ).vk_enforce;

	import vdrive.util.array : ptr, sizedArray;
	auto result = sizedArray!ReturnType( count );

			static if( args.length == 1 )	func( args[0], &count, result.ptr ).vk_enforce;
	else	static if( args.length == 2 )	func( args[0], args[1], &count, result.ptr ).vk_enforce;
	else	static if( args.length == 3 )	func( args[0], args[1], args[2], &count, result.ptr ).vk_enforce;
	return result;
}