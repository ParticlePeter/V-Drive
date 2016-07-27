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


alias toUint = toUint32_t;
uint32_t toUint32_t( T )( T value ) if( __traits( isScalar, T )) { 
	return cast( uint32_t )value;
}

alias toInt = toInt32_t;
uint32_t toInt32_t( T )( T value ) if( __traits( isScalar, T )) { 
	return cast( int32_t )value;
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


mixin template Dispatch_To_Inner_Struct( alias inner_struct ) {
	auto opDispatch( string member, Args... )( Args args ) /*pure nothrow*/ {
		static if( args.length == 0 ) {
			static if( __traits( compiles, __traits( getMember, vk, member ))) {
				return __traits( getMember, vk, member );
			} else {
				return __traits( getMember, inner_struct, member );
			}
		} else static if( args.length == 1 )  { 
			__traits( getMember, inner_struct, member ) = args[0];
		} else {
			foreach( arg; args ) writeln( arg );
			assert( 0, "Only one optional argument allowed for dispatching to inner struct: " ~ inner_struct.stringof );
		}
	}
}


// helper template for skipping members
template skipper( string target ) { enum shouldSkip( string s ) = ( s == target ); }

// function which creates to inner struct forwarding functions	
auto Forward_To_Inner_Struct( outer, inner, string path, ignore... )() {
	// import helper template from std.meta to decide if member is found in ignore list
	import std.meta : anySatisfy;
	string result;
	foreach( member; __traits( allMembers, inner )) {
		// https://forum.dlang.org/post/hucredzrhbbjzcesjqbg@forum.dlang.org
		enum skip = anySatisfy!( skipper!( member ).shouldSkip, ignore );		// evaluate if member is in ignore list
		static if( !skip && member != "sType" && member != "pNext" && member != "flags" ) {		// skip, also these
			import vdrive.util.string : snakeCaseCT;							// convertor from camel to snake case
			enum member_snake = member.snakeCaseCT;								// convert to snake case
			//enum result = "\n"												// enum string wich will be mixed in
			result ~= "\n"
				~ "/// forward member " ~ member ~ " of inner " ~ inner.stringof ~ " as function to " ~ outer.stringof ~ "\n"
				~ "/// Params:\n"
				~ "/// \tmeta = reference to a " ~ outer.stringof ~ " struct\n"
				~ "/// \t" ~ member_snake ~ " = the value forwarded to the inner struct\n"
				~ "/// Returns: the passed in Meta_Structure for function chaining\n"
				~ "auto ref " ~ member ~ "( ref " ~ outer.stringof ~ " meta, "
				~ typeof( __traits( getMember,  inner, member )).stringof ~ " " ~ member_snake ~ " ) {\n"
				~ "\t" ~ path ~ "." ~ member ~ " = " ~ member_snake ~ ";\n\treturn meta;\n}\n";
			//pragma( msg, result );
			//mixin( result );
		}
	} return result;
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