module vdrive.util.util;

import erupted;
import std.container.array;



alias vkMajor = VK_VERSION_MAJOR;
alias vkMinor = VK_VERSION_MINOR;
alias vkPatch = VK_VERSION_PATCH;



void vkEnforce( VkResult vkResult ) {
	import std.exception : enforce;
	import std.conv : to;
	enforce( vkResult == VK_SUCCESS, vkResult.to!string );
}



auto listVulkanProperty( ReturnType, alias vkFunc, Args... )( Args args ) {

	import vdrive.util.array : ptr;
	Array!ReturnType result;
	VkResult vkResult;
	uint32_t count;

	/*
	* It's possible, though very rare, that the number of
	* instance layers could change. For example, installing something
	* could include new layers that the loader would pick up
	* between the initial query for the count and the
	* request for VkLayerProperties. If that happens,
	* the number of VkLayerProperties could exceed the count
	* previously given. To alert the app to this change
	* vkEnumerateInstanceExtensionProperties will return a VK_INCOMPLETE
	* status.
	* The count parameter will be updated with the number of
	* entries actually loaded into the data pointer.
	*/

	do {
		vkFunc( args, &count, null ).vkEnforce;
		if( count == 0 )  break;
		result.length = count;
		vkResult = vkFunc( args, &count, result.ptr );
	} while( vkResult == VK_INCOMPLETE );

	vkResult.vkEnforce; // check if everything went right

	return result;
}



/+
mixin template listVulkanTemplate( ReturnType, alias vkFunc, Args... ) {

	import vdrive.util.array : ptr;
	import std.container.array;
	Array!ReturnType result;
	VkResult vkResult;
	uint32_t count;

	/*
	* It's possible, though very rare, that the number of
	* instance layers could change. For example, installing something
	* could include new layers that the loader would pick up
	* between the initial query for the count and the
	* request for VkLayerProperties. If that happens,
	* the number of VkLayerProperties could exceed the count
	* previously given. To alert the app to this change
	* vkEnumerateInstanceExtensionProperties will return a VK_INCOMPLETE
	* status.
	* The count parameter will be updated with the number of
	* entries actually loaded into the data pointer.
	*/

	do {
		vkFunc( args, &count, null ).vkEnforce;
		if( count == 0 )  break;
		result.length = count;
		vkResult = vkFunc( args, &count, result.ptr );
	} while( vkResult == VK_INCOMPLETE );

	vkResult.vkEnforce; // check if everything went right

	//return listVulkanTemplate;
}
+/




/*
auto filterVulkanPropertyFlags(
	Array!Queue_Family family_queues, 
	VkQueueFlags include_queue, 
	VkQueueFlags exclude_queue = 0 ) {

	Array!Queue_Family filtered_queues;
	foreach( ref family_queue; family_queues ) {
		if(( family_queue.queueFlags & include_queue ) && !( family_queue.queueFlags & exclude_queue )) {
			filtered_queues.insert( family_queue );
		}
	}
	return filtered_queues;
}*/