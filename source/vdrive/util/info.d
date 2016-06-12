module vdrive.util.info;

import std.exception : enforce;

import vdrive.util.util;
import vdrive.util.array;

import erupted;

// TODO(pp): get rid of the GC with @nogc, remove to!string requirement
// TODO(pp): extract function for listing available enums of possible enums
void printStructInfo( T, size_t buffer_size = 256 )(
	T info,
	bool printStructName = true,
	string indent = "",
	size_t max_type_length = 0,
	size_t max_name_length = 0
	) if( is( T == struct )) /*@nogc nothrow*/ {

	// struct name
	import std.conv : to;
	import std.array : replicate;
	import core.stdc.stdio : printf;
	//import core.stdc.string : strncpy, memset;
			//if( strncmp( properties.layerName.ptr, layer.ptr, layer.length ) == 0 ) {
			//	return properties.implementationVersion;

	char[ buffer_size ] buffer = void;

	if ( printStructName ) {
		buffer[ 0..T.stringof.length ] = T.stringof;	//strncpy( buffer.ptr, T.stringof.ptr, T.stringof.length );
		buffer[ T.stringof.length ] = '\0';
		printf( "%s\n", buffer.ptr );
		buffer[ 0..T.stringof.length ] = '=';			//memset( buffer.ptr, '=', T.stringof.length );
		printf( "%s\n", buffer.ptr );
	}

	// indent the buffer and store a pointer posistion;
	auto buffer_ind = buffer.ptr;
	buffer_ind[ 0 ] = '\t';						buffer_ind += 1;
	buffer_ind[ 0 .. indent.length ] = indent;	buffer_ind += indent.length;

	// need this template as non aliased types are shorter than aliased, but aliased are printed later
	immutable string[8] integral_alias_types = [ "uint64_t", "uint32_t", "uint16_t", "uint8_t", "int64_t", "int32_t", "int16_t", "int8_t" ]; 
	size_t alias_type_length( T )( T ) {
		static      if( is( T == uint16_t ) || is( T == uint32_t ) || is( T == uint64_t )) return 8;
		else static if( is( T ==  int16_t ) || is( T ==  int32_t ) || is( T ==  int64_t ) || is( T ==  ubyte )) return 7;
		else static if( is( T ==  int8_t )) return 6;
		else return T.stringof.length;
	}

	// max struct attribute string max_name_length
	size_t max( size_t a, size_t b ) { return a < b ? b : a; }
	foreach( member_name; __traits( allMembers, T )) {
		alias member = printInfoHelper!( __traits( getMember, T, member_name ));
		static if( is( member )) {
			max_name_length = max( max_name_length, member_name.stringof.length );
			max_type_length = max( max_type_length, alias_type_length( __traits( getMember, info, member_name )));
		}
	}
	max_type_length += 2;		// space to member name


	// pretty print attributes
	import std.string : leftJustify;
	import std.traits : isFloatingPoint, isPointer;

	void print( char* buffer_ptr, string type, string name = "", string data = "", string assign = " : ", string line = "\n" ) {
		buffer_ptr[ 0 .. max_type_length ] = type.leftJustify( max_type_length, ' ' );	buffer_ptr += max_type_length;
		buffer_ptr[ 0 .. max_name_length ] = name.leftJustify( max_name_length, ' ' );	buffer_ptr += max_name_length;
		buffer_ptr[ 0 .. assign.length ] = assign;										buffer_ptr += assign.length;
		buffer_ptr[ 0 .. data.length ] = data;											buffer_ptr += data.length;
		buffer_ptr[ 0 .. line.length ] = line;
		buffer_ptr[ line.length ] = '\0';
		printf( "%s", buffer.ptr ); 
	}

	foreach( member_name; __traits( allMembers, T )) {
		alias member = printInfoHelper!( __traits( getMember, T, member_name ));
		static if( is( member )) {
			auto  member_data = __traits( getMember, info, member_name );
			alias member_type = typeof( member_data );

			auto buffer_ptr = buffer_ind;
			buffer_ptr[ 0 ] = '\0';
			//printf( "%s", buffer.ptr );

			static if( is( member_type == enum )) {

				buffer_ptr[ 0 .. member_type.stringof.length ] = member_type.stringof;
				buffer_ptr[ member_type.stringof.length ] = '\0';
				import core.stdc.string : strstr;
				import std.traits : EnumMembers;
				bool assigned = false;
				int32_t last_used_value = int32_t.max;
				if( strstr( buffer_ptr, "Flag" ) == null ) {
					foreach( enum_member; EnumMembers!member_type ) {
						// need to filter multiply assigned enum values _BEGIN_RANGE, _END_RANGE (_RANGE_SIZE only with string compare, avoiding!)
						// these are not API constructs but just implementor help
						if( member_data == enum_member && enum_member != last_used_value ) {
							print( buffer_ptr, member_type.stringof, member_name, enum_member.to!string );
							last_used_value = enum_member;
						}	
					}
				} else {
					foreach( enum_member; EnumMembers!member_type ) {
						auto enum_member_string = enum_member.to!string;
						// need to filter the enum bellow _MAX_ENUM, as they are not API constructs but just implementor help
						if( member_data & enum_member && member_data != 0x7FFFFFFF ) {
							if ( !assigned ) {
								assigned = true;
								print( buffer_ptr, member_type.stringof, member_name, enum_member.to!string );	
							} else {
								print( buffer_ptr, "", "", enum_member.to!string, " | " );
							}
						}
					}
					// if nothing was assigned, the enum would be skipped, hence print it with artificial NONE flag 
					if( !assigned ) print( buffer_ptr, member_type.stringof, member_name, "NONE" );
				}
			}

			else static if( member_type!isPointer ) {}

			else static if( is( member_type == struct )) {
				print( buffer_ptr, member_type.stringof, "", "", "" );
				member_data.printStructInfo( false, "\t", max_type_length, max_name_length );
			}

			else static if( is( member_type : B[n], B, size_t n )) {
				static if( is( B == struct )) {
					foreach( item; member_data ) {
						item.printStructInfo( false, "\t", max_type_length, max_name_length );
					}
				}
			}



			else print( buffer_ptr, member_type.stringof, member_name, member_data.to!string );

			/*
			else static if( is( member_type == uint64_t ))	print( buffer_ptr, "uint64_t", member_name, member_data.to!string );
			else static if( is( member_type == uint32_t ))	print( buffer_ptr, "uint32_t", member_name, member_data.to!string );
			else static if( is( member_type == uint16_t ))	print( buffer_ptr, "uint16_t", member_name, member_data.to!string );
			else static if( is( member_type ==  uint8_t ))	print( buffer_ptr,  "uint8_t", member_name, member_data.to!string );
			else static if( is( member_type ==  int64_t ))	print( buffer_ptr,  "int64_t", member_name, member_data.to!string );
			else static if( is( member_type ==  int32_t ))	print( buffer_ptr,  "int32_t", member_name, member_data.to!string );
			else static if( is( member_type ==  int16_t ))	print( buffer_ptr,  "int16_t", member_name, member_data.to!string );
			else static if( is( member_type ==   int8_t ))	print( buffer_ptr,   "int8_t", member_name, member_data.to!string );
			
			else static if( isFloatingPoint!member_type )	print( buffer_ptr, member_type.stringof, member_name, member_data.to!string );
			else static if( isPointer!member_type )			print( buffer_ptr, member_type.stringof, member_name, member_data.to!string );
				//if( member_data is null )	print( buffer_ptr, member_type.stringof, member_name, "null" );
				//else						print( buffer_ptr, member_type.stringof, member_name, member_data );

			else static if( is( member_type : B[n], B, size_t n )) {
				// arrays (strings)
				static if( is( B : char )) {
					printf( "%s : %s\n", leftJustify( member_name, max_name_length, ' ' ).toStringz, member_data );
				} else static if( is( B : uint32_t ) || is( B : uint64_t )) {
					printf( "%s : [ %u", leftJustify( member_name, max_name_length, ' ' ).toStringz, member_data[0]);
					foreach( v; 1..n )  printf( ", %u", member_data[v] );
					printf( " ]\n" );
				} else static if( is( B :  int32_t ) || is( B :  int64_t )) {
					printf( "%s : [ %d", leftJustify( member_name, max_name_length, ' ' ).toStringz, member_data[0]);
					foreach( v; 1..n )  printf( ", %d", member_data[v] );
					printf( " ]\n" );
				} else static if( isFloatingPoint!B ) {
					printf( "%s : [ %f", leftJustify( member_name, max_name_length, ' ' ).toStringz, member_data[0]);
					foreach( v; 1..n )  printf( ", %f", member_data[v] );
					printf( " ]\n" );
				} else {	// printf numeric arrays
					printf( "%s : %s\n", leftJustify( member_name, max_name_length, ' ' ).toStringz, typeof( member_data ).stringof.toStringz );
				}
			} else {
				printf( "%s : %s\n", leftJustify( member_name, max_name_length, ' ' ).toStringz, typeof( member_data ).stringof.toStringz );
			}
			*/ 					
		}
	}
	//printf("\n");
}

// From D Cookbok p. 216
// use this to get and evalueate the member data
// __traits( getMember, info, member ));
private alias printInfoHelper( alias T ) = T;
private void inspect( T )( T info, string before = "" ) {
	import std.algorithm;
	import std.stdio;

	foreach( member_name; __traits( allMembers, T )) {
		alias member = printInfoHelper!( __traits( getMember, T, member_name ));
		//write( typeof( member ).stringof, " is enum: ", is( typeof( member ) == enum ));
		//write( "            : " );
		static if( is( member )) {
			// inspect types
			string specifically;
			static if( is( member == struct ))  specifically = "struct";
			else static if( is( member == class ))  specifically = "class";
			else static if( is( typeof( member ) == enum  ))  specifically = "enum";

			writeln( before, member_name, " is a type ( ", specifically, " )");
			inspect!member( before ~ "\t");

		} else static if( is( typeof( member ) == function )) {
			// inspect functions
			writeln( beforme, member_name, " is a function typed ", typeof( member ).stringof );
		} else {
			// inspect the rest
			static if( member.stringof.startsWith( "module " ))
				writeln( before, member_name, " is a module" );

			else static if( is( typeof( member ) == enum )) {
				import std.traits : EnumMembers;
				writeln( before, member_name, " is a variable typed ", typeof( member ).stringof, " with values:" );
				//auto memberValue = __traits( getMember, info, member );
				foreach( enum_member; EnumMembers!( typeof( member ))) {
					//if( memberValue & enum_member )
						writeln( before, "\t", enum_member, " = ", cast( uint )enum_member );
				}
			}
			else static if( is( typeof( member.init ))) {
				writeln( before, member_name, " is a variable typed ", typeof( member ).stringof );
				//auto sqrts = [ EnumMembers!Sqrts ];
				//assert(sqrts == [ Sqrts.one, Sqrts.two, Sqrts.three ]);
			}


			else
				writeln( before, member_name, " is likely a template" );

		}
	}
}



import std.array : replicate;
import std.stdio;
import std.string : fromStringz;


////////////////
// Extensions //
////////////////

/// list all available ( layer per ) instance / device extensions
auto listExtensions( VkPhysicalDevice gpu, char* layer, bool printInfo = true ) {

	VkResult vkResult;
	uint32_t extension_property_count;
	Array!VkExtensionProperties extension_properties;

	if( gpu == VK_NULL_HANDLE ) {		// list_instance_extensions
		do {
			vkEnumerateInstanceExtensionProperties( layer, &extension_property_count, null ).vk_enforce;
			if( extension_property_count == 0 )  break;
			extension_properties.length = extension_property_count;
			vkResult = vkEnumerateInstanceExtensionProperties( layer, &extension_property_count, extension_properties.ptr );
		} while( vkResult == VK_INCOMPLETE );

	} else {				// list_gpu_extensions
		do {
			vkEnumerateDeviceExtensionProperties( gpu, layer, &extension_property_count, null ).vk_enforce;
			if( extension_property_count == 0 )  break;
			extension_properties.length = extension_property_count;
			vkResult = vkEnumerateDeviceExtensionProperties( gpu, layer, &extension_property_count, extension_properties.ptr );
		}	while( vkResult == VK_INCOMPLETE );
	}

	if( printInfo ) {
		if(	extension_properties.length == 0 )  {
			writeln( "\tExtension: None" );

		} else {
			foreach( ref properties; extension_properties ) {
				//printf( "\tExtension: %s, version: %d", properties.extensionName, properties.specVersion );
				writefln( "\tExtension: %s, version: %s", 
					properties.extensionName.ptr.fromStringz, 
					properties.specVersion );
			}
		}	
		writeln;
	}
	return extension_properties;
}

/// get the version of any available instance / device / layer extension
auto extensionVersion( T )( T extension, VkPhysicalDevice gpu, char* layer = null, bool printInfo = true ) if( is( T == string )| is( T : const( char* )) | is( T : char[] )) {
	uint32_t result = 0;
	auto extension_properties = listExtensions( gpu, layer, false );
	foreach( ref properties; extension_properties ) {
		static if( is( T : const( char* ))) {
			import core.stdc.string : strcmp;
			if( strcmp( properties.extensionName.ptr, extension )) {
				result = properties.specVersion;
				break;
			}
		} else {
			import core.stdc.string : strncmp;
			if( extension.length == properties.extensionName.ptr.strlen && strncmp( properties.extensionName.ptr, extension.ptr, extension.length ) == 0 ) {
				result = properties.specVersion;
				break;
			}
		}
	}

	if( printInfo ) {
		static if( is( T : const( char* )))	{
			printf( "%s version: %u\n", layer, result );
		} else {
			auto layer_strz = layer.toStringz;
			printf( "%s version: %u\n", layer_strz.ptr, result );
		}
	}

	return result;
}

/// check if an instance / device / layer extension of any version is available
auto isExtension( T )( T extension, VkPhysicalDevice gpu = VK_NULL_HANDLE, char* layer = null, bool printInfo = true )
if( is( T == string )| is( T : const( char* )) | is( T : char[] )) {

	auto result = extension.extensionVersion( gpu, layer, false ) > 0;
	if( printInfo ) {
		static if( is( T : const( char* )))	{
			printf( "%s available: %u\n", extension, result );
		} else {
			auto layer_strz = extension.toStringz;
			printf( "%s available: %u\n", layer_strz.ptr, result );
		}
	}
	return result;
}

unittest {
	string surfaceString = "VK_KHR_surface";
	printf( "Version: %d\n", "VK_KHR_surface".instance_extension_version );
	printf( "Version: %d\n", surfaceString.instance_extension_version );
	
	char[64] surface = "VK_KHR_surface";
	printf( "Version: %d\n", ( & surface[0] ).instance_extension_version );
	printf( "Version: %d\n", surface.ptr.instance_extension_version );
	printf( "Version: %d\n", surface[].instance_extension_version );
	printf( "Version: %d\n", surface.instance_extension_version );
}


////////////
// Layers //
////////////

/// list all available instance / device layers
auto listLayers( VkPhysicalDevice gpu, bool printInfo = true  ) {

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

	VkResult vkResult;
	uint32_t layer_property_count;
	Array!VkLayerProperties layer_properties;

	if( gpu == VK_NULL_HANDLE ) {		// list_instance_layers
		do {
			vkEnumerateInstanceLayerProperties( &layer_property_count, null ).vk_enforce;
			if( layer_property_count == 0 )  break;
			layer_properties.length = layer_property_count;
			vkResult = vkEnumerateInstanceLayerProperties( &layer_property_count, layer_properties.ptr );
		} while( vkResult == VK_INCOMPLETE );

	} else {				// list_device_layers
		do {
			vkEnumerateDeviceLayerProperties( gpu, &layer_property_count, null ).vk_enforce;
			if( layer_property_count == 0 )  break;
			layer_properties.length = layer_property_count;
			vkResult = vkEnumerateDeviceLayerProperties( gpu, &layer_property_count, layer_properties.ptr );
		}	while( vkResult == VK_INCOMPLETE );
	}

	if( printInfo ) {
		if(	layer_properties.length == 0 )  {
			writeln( "\tLayers: None" );

		} else {
			if ( gpu != VK_NULL_HANDLE ) {
				VkPhysicalDeviceProperties gpu_properties;
				vkGetPhysicalDeviceProperties( gpu, &gpu_properties );
				writeln;
				writeln( "Layers of GPU: ", gpu_properties.deviceName.ptr.fromStringz );
				writeln( replicate( "=", 15 + gpu_properties.deviceName.ptr.fromStringz.length ));
			}
			foreach( ref property; layer_properties ) {
				writefln( "%s:", property.layerName.ptr.fromStringz );
				writefln( "\tVersion: %s", property.implementationVersion );
				auto ver = property.specVersion;
				writefln( "\tSpec Version: %s.%s.%s ", ver.vkMajor, ver.vkMinor, ver.vkPatch );
				writefln( "\tDescription: %s", property.description.ptr.fromStringz );
				gpu.listExtensions( property.layerName.ptr, true );	// drill into extensions
			}
		}	
		writeln;
	}
	return layer_properties;
}


/// get the version of any available instance / device layer
auto layerVersion( T )( T layer, VkPhysicalDevice gpu = null, bool printInfo = true )
if( is( T == string ) | is( T : const( char* )) | is( T : char[] )) {

	uint32_t result = 0;									// version result
	auto layer_properties = listLayers( gpu, false );		// list all layers
	foreach( ref properties; layer_properties ) {			// search for requested layer
		static if( is( T : const( char* ))) {
			import core.stdc.string : strcmp;
			if( strcmp( properties.layerName.ptr, layer ) == 0 ) {
				result = properties.implementationVersion;
				break;
			}
		} else {
			import core.stdc.string : strncmp, strlen;
			if( layer.length == properties.layerName.ptr.strlen && strncmp( properties.layerName.ptr, layer.ptr, layer.length ) == 0 ) {
				result = properties.implementationVersion;
				break;
			}
		}
	}

	if( printInfo ) {
		static if( is( T : const( char* )))	{
			printf( "%s version: %u\n", layer, result );
		} else {
			auto layer_strz = layer.toStringz;
			printf( "%s version: %u\n", layer_strz.ptr, result );
		}
	}

	return result;
}

/// check if an instance / device layer of any version is available
auto isLayer( T )( T layer, VkPhysicalDevice gpu, bool printInfo = true )
if( is( T == string )| is( T : const( char* )) | is( T : char[] )) {

	auto result = layer.layerVersion( gpu, false ) > 0;
	if( printInfo ) {
		static if( is( T : const( char* )))	{
			printf( "%s available: %u\n", layer, result );
		} else {
			auto layer_strz = layer.toStringz;
			printf( "%s available: %u\n", layer_strz.ptr, result );
		}
	}
	return result;
}



/////////////////////
// Physical Device //
/////////////////////
auto listPhysicalDevices( VkInstance instance, bool printInfo = true ) {
	uint32_t gpus_count;
	vkEnumeratePhysicalDevices( instance, &gpus_count, null ).vk_enforce;

	if( gpus_count == 0 ) {
		stderr.writeln("No gpus found.");
	}

	auto gpus = sizedArray!VkPhysicalDevice( gpus_count );
	vkEnumeratePhysicalDevices( instance, &gpus_count, gpus.ptr ).vk_enforce;

	if( printInfo ) {
		writeln;
		writeln( "GPU count: ", gpus_count ); 
		writeln( "============" );
	}
	return gpus;
}

// returns gpu properties and can also print the properties, limits and sparse properties  
enum GPU_Info { none = 0, properties, limits, sparse_properties = 4 };
auto listProperties( VkPhysicalDevice gpu, GPU_Info gpu_info = GPU_Info.none ) {

	VkPhysicalDeviceProperties gpu_properties;
	vkGetPhysicalDeviceProperties( gpu, &gpu_properties );

	writeln;
	writeln( gpu_properties.deviceName.ptr.fromStringz );
	writeln( replicate( "=", gpu_properties.deviceName.ptr.fromStringz.length ));

	if( gpu_info & GPU_Info.properties ) {
		auto ver = gpu_properties.apiVersion;
		writefln("\tAPI Version     : %s.%s.%s", ver.vkMajor, ver.vkMinor, ver.vkPatch );
		writeln( "\tDriver Version  : ", gpu_properties.driverVersion );
		writeln( "\tVendor ID       : ", gpu_properties.vendorID );
		writeln( "\tDevice ID       : ", gpu_properties.deviceID );
		writeln( "\tGPU type        : ", gpu_properties.deviceType );
	}

	if( gpu_info & GPU_Info.limits ) {
		writeln;
		gpu_properties.limits.printStructInfo;
	}
	
	if( gpu_info & GPU_Info.sparse_properties ) {
		writeln;
		gpu_properties.sparseProperties.printStructInfo;
	}

	return gpu_properties;
}

// returns the physical device features of a certain physical device
auto listFeatures( VkPhysicalDevice gpu, bool printInfo = true ) {
	VkPhysicalDeviceFeatures features;
	vkGetPhysicalDeviceFeatures( gpu, &features );
	if( printInfo )
		printStructInfo( features );
	return features;
}

// returns gpu memory properties
auto listMemoryProperties( VkPhysicalDevice gpu, bool printInfo = true ) {
	VkPhysicalDeviceMemoryProperties memory_properties;
	vkGetPhysicalDeviceMemoryProperties( gpu, &memory_properties );
	if( printInfo )
		printStructInfo( memory_properties );
	return memory_properties;
}


// returns if the physical device does support presentations
auto presentSupport( VkPhysicalDevice gpu, VkSurfaceKHR surface ) {
	
	uint32_t queue_family_property_count;
	vkGetPhysicalDeviceQueueFamilyProperties( gpu, &queue_family_property_count, null );

	VkBool32 present_supported;
	foreach( family_index; 0 .. queue_family_property_count ) {
		vkGetPhysicalDeviceSurfaceSupportKHR( gpu, family_index, surface, &present_supported );
		if( present_supported ) {
			return true;
		}
	}
	return false;
}

////////////
// Queues //
////////////
auto listQueues( VkPhysicalDevice gpu, bool printInfo = true ) {

	uint32_t queue_family_property_count;
	Array!VkQueueFamilyProperties queue_family_properties;

	vkGetPhysicalDeviceQueueFamilyProperties( gpu, &queue_family_property_count, null );
	assert( queue_family_property_count >= 1 );

	queue_family_properties.length = queue_family_property_count;
	vkGetPhysicalDeviceQueueFamilyProperties( gpu, &queue_family_property_count, queue_family_properties.ptr );
	assert( queue_family_property_count >= 1 );

	if( printInfo ) { 
		foreach( q, ref queue; queue_family_properties.data ) {
			writeln;
			writeln("Queue Family ", q );
			writeln("\tQueues in Family         : ", queue.queueCount );
			writeln("\tQueue timestampValidBits : ", queue.timestampValidBits );

			if( queue.queueFlags & VK_QUEUE_GRAPHICS_BIT )
				writeln("\tVK_QUEUE_GRAPHICS_BIT" );

			if( queue.queueFlags & VK_QUEUE_COMPUTE_BIT )
				writeln("\tVK_QUEUE_COMPUTE_BIT" );

			if( queue.queueFlags & VK_QUEUE_TRANSFER_BIT )
				writeln("\tVK_QUEUE_TRANSFER_BIT" );

			if( queue.queueFlags & VK_QUEUE_SPARSE_BINDING_BIT )
				writeln("\tVK_QUEUE_SPARSE_BINDING_BIT" );
		}
	}

	return queue_family_properties; 	
}

// Wraps a VkQueueFamilyProperties
// adds a family index and a Array!float priorities array 
struct Queue_Family {
	private uint32_t index;
	//private VkPhysicalDevice gpu;
	private VkQueueFamilyProperties queue_family_properties;
	private Array!float	queue_priorities;

	// get a copy of the family index
	auto family_index() { return index; }

	// get a readonly reference to the wrapped VkQueueFamilyProperties 
	ref const( VkQueueFamilyProperties ) vk_queue_family_properties() {
		return queue_family_properties;
	}

	// VkQueueFamilyProperties can be reached
	alias vk_queue_family_properties this;

/*	// return a copy of the internal physical device;
	VkPhysicalDevice vk_physical_device() {
		return gpu;
	}
*/
	// query the count of queues available in the wrapped VkQueueFamilyProperties 
	uint32_t maxQueueCount() { 
		return queue_family_properties.queueCount;
	}

	// query the currently requested queue count
	uint32_t queueCount() {
		return cast( uint32_t )queue_priorities.length; 
	}

	void queueCount( uint32_t count ) {
		enforce( count <= maxQueueCount, "More queues requested than available!" ); 
		queue_priorities.length = count;
		import std.math : isNaN;
		foreach( ref priority; queue_priorities )
			if( priority.isNaN )
				priority = 0.0f;
	}

	// get a pointer to the priorities array
	float * priorities() {
		return queue_priorities.ptr;
	}

	// getter and setter for a specific priority of at a specific index
	ref float priority( uint32_t queue_index ) {
		enforce( queue_index < queue_priorities.length, "Index out of bounds of requested priorities!" );
		return queue_priorities[ queue_index ];
	}

	// set all priorities and implicitly the requested queue count
	void priorities( float[] values ) {
		enforce( values.length <= maxQueueCount, "More priorities specified than available queues!" );
		queue_priorities = Array!float( values );
	}

	// set all priorities and implicitly the requested queue count
	void priorities( Array!float values ) {
		enforce( values.length <= maxQueueCount, "More priorities specified than available queues!" );
		queue_priorities = values;
	}

	// get a string representation of the data
	auto toString() {
		char[256] buffer;
		import std.format : sformat;
		return sformat( buffer, 
			"\n\tfamilyIndex: %s, maxQueueCount: %s, queueCount: %s, queue_priorities: %s",
			family_index, maxQueueCount, queueCount, queue_priorities[] );
	}
}

auto listQueueFamilies( VkPhysicalDevice gpu, bool printInfo = true ) {
	auto queue_family_properties = listQueues( gpu, printInfo );
	Array!Queue_Family family_queues;
	foreach( family_index, ref family; queue_family_properties.data ) {
		family_queues.insert( Queue_Family( cast( uint32_t )family_index, /*gpu,*/ family ));
		//family_queues[$-1].queue_family_properties = family;
		//family_queues[$-1].gpu = gpu;
	}
	return family_queues;	
}

//auto listQueueFamilies( const ref Vulkan vk, bool printInfo = true ) {
//	return listQueueFamilies( vk.gpu, printInfo );
//}

auto filter_queue_flags(
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
}

auto filterPresentSupport( Array!Queue_Family family_queues, VkPhysicalDevice gpu, VkSurfaceKHR surface ) {
	
	VkBool32 present_supported;
	Array!Queue_Family filtered_queues;
	foreach( ref family_queue; family_queues ) {
		vkGetPhysicalDeviceSurfaceSupportKHR( gpu, family_queue.family_index, surface, &present_supported );
		if( present_supported ) {
			filtered_queues.insert( family_queue );
		}
	}
	return filtered_queues;
}

//auto filterPresentSupport( Array!Queue_Family family_queues, const ref Vulkan vk ) {
//	return filterPresentSupport( vk.gpu, vk.surface );
//}

unittest {

	// Testing string of terminated strings toPtrArray buffer
	string strings = "test\0t1\0TEST2\0T3\0";
	const( char )*[8] stringPtr;
	auto stringPoi = strings.toPtrArray( stringPtr );
	printf( "Count: %d\n%s %s %s\n", stringPtr.length, stringPtr[0], stringPtr[2], stringPtr[1] );
	printf( "Count: %d\n%s %s %s\n", stringPoi.length, stringPoi[0], stringPoi[2], stringPoi[1] );

	// Testing array of strings to string of terminated strings toPtrArray
	auto array_of_strings = [ "test", "t1", "TEST2" ];
	Array!char pointer_buffer;
	auto String = array_of_strings.toPtrArray( pointer_buffer );
	printf( "%s\n%s\n%s\n", String[0], String[2], String[1] );
	foreach( s; String ) writeln( * ( cast( ubyte * )s ) );
	writeln( cast( ubyte[] )pointer_buffer.data() );

}




///////////////////////////
// Convenience Functions //
///////////////////////////

/// list all available instance extensions
auto listExtensions( bool printInfo = true ) {
	if ( printInfo ) {
		writeln;
		writeln( "Instance Extensions" );
		writeln( "===================" );
	}
	return listExtensions( VK_NULL_HANDLE, null, printInfo );
}

/// list all available per layere instance extensions
auto listExtensions( char* layer, bool printInfo = true ) {
	if ( printInfo ) {
		writeln;
		writeln( "Instance Layere Extensions" );
		writeln( "==========================" );
	}
	return listExtensions( VK_NULL_HANDLE, layer, printInfo );	
}

/// list all available device extensions
auto listExtensions( VkPhysicalDevice gpu, bool printInfo = true ) {
	if ( printInfo ) {
		writeln;
		writeln( "Physical Device Extensions" );
		writeln( "==========================" );
	}
	return listExtensions( gpu, null, printInfo );
}

/// list all available layer per device extensions
auto list_device_layer_extensions( VkPhysicalDevice gpu, char* layer, bool printInfo = true ) {
	if ( printInfo ) {
		writeln;
		writeln( "Physical Device Layer Extensions" );
		writeln( "================================" );
	}
	return listExtensions( gpu, layer, printInfo );	
}


// Get the version of a instance layer extension
auto extensionVersion( T )( T extension, char* layer, bool printInfo = false ) if( is( T == string )| is( T : const( char* )) | is( T : char[] )) {
	return extensionVersion( extension, VK_NULL_HANDLE, layer, printInfo );
}

// Get the version of a instance extension
auto extensionVersion( T )( T extension, bool printInfo ) if( is( T == string )| is( T : const( char* )) | is( T : char[] )) {
	return extensionVersion( extension, VK_NULL_HANDLE, null, printInfo );
}

/// check if an instance layer extension of any version is available
auto isExtension( T )( T extension, char* layer, bool printInfo = true )
if( is( T == string )| is( T : const( char* )) | is( T : char[] )) {
	return extension.isExtension( VK_NULL_HANDLE, layer, printInfo );
}

/// check if an instance extension of any version is available
auto isExtension( T )( T extension, bool printInfo )
if( is( T == string )| is( T : const( char* )) | is( T : char[] )) {
	return extension.isExtension( VK_NULL_HANDLE, null, printInfo );
}

// list all instance layers
auto listLayers( bool printInfo = true ) {
	if( printInfo ) {
		writeln;
		writeln( "Instance Layers" );
		writeln( "===============" );
	}
	return listLayers( VK_NULL_HANDLE, printInfo );
}

/// check if an instance layer of any version is available
auto isLayer( T )( T layer, bool printInfo = true )
if( is( T == string )| is( T : const( char* )) | is( T : char[] )) {
	return layer.isLayer( VK_NULL_HANDLE, printInfo );
}
