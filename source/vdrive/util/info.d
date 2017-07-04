module vdrive.util.info;

import core.stdc.stdio : printf;
import std.exception : enforce;

import vdrive.util.util;
import vdrive.util.array;

import erupted;


// print new line
void println() @nogc nothrow { printf( "\n" ); }


// print char n count
void printRepeat( size_t MAX_CHAR_COUNT )( char c, size_t count ) @nogc nothrow {
	char[ MAX_CHAR_COUNT ] repeat;
	repeat[] = c;
	if( MAX_CHAR_COUNT < count ) count = MAX_CHAR_COUNT;
	printf( "%.*s", count, repeat.ptr );	
}


// TODO(pp): get rid of the GC with @nogc, remove to!string requirement
// TODO(pp): extract function for listing available enums of possible enums
void printTypeInfo( T, size_t buffer_size = 256 )(
	T 		info,
	bool	printStructName = true,
	string	indent = "",
	size_t	max_type_length = 0,
	size_t	max_name_length = 0,
	bool	newline = true ) if( is( T == struct ) || is( T == union )) /*@nogc nothrow*/ {

	// struct name
	import std.conv : to;
	//import std.array : replicate;
	
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

	// indent the buffer and store a pointer position;
	auto buffer_indent = buffer.ptr;
	buffer_indent[ 0 ] = '\t';						buffer_indent += 1;
	buffer_indent[ 0 .. indent.length ] = indent;	buffer_indent += indent.length;

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
		//static if( is( member )) {
			max_name_length = max( max_name_length, member_name.stringof.length );
			max_type_length = max( max_type_length, alias_type_length( __traits( getMember, info, member_name )));
		//}
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
		//static if( is( member )) {
			auto  member_data = __traits( getMember, info, member_name );
			alias member_type = typeof( member_data );

			auto buffer_ptr = buffer_indent;
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

			//else static if( member_type!isPointer ) {}

			else static if( is( member_type == struct ) || is( member_type == union )) {
				print( buffer_ptr, member_type.stringof, "", "", "" );
				member_data.printTypeInfo( false, "\t", max_type_length, max_name_length, false );
			}

			else static if( is( member_type : B[n], B, size_t n )) {
				static if( is( B == struct ) || is( B == union )) {
					foreach( item; member_data ) {
						item.printTypeInfo( false, "\t", max_type_length, max_name_length, false );
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
		//}
	}
	if( newline ) println;
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




//nothrow:

////////////////
// Extensions //
////////////////

/// list all available ( layer per ) instance / device extensions
auto listExtensions(
	VkPhysicalDevice	gpu,
	const( char )*		layer,
	bool				printInfo = true,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {
	// Enumerate Instance or Device extensions
	auto extension_properties = gpu == VK_NULL_HANDLE ?
		listVulkanProperty!( VkExtensionProperties, vkEnumerateInstanceExtensionProperties, const( char )* )( file, line, func, layer ) :
		listVulkanProperty!( VkExtensionProperties, vkEnumerateDeviceExtensionProperties, VkPhysicalDevice, const( char )* )( file, line, func, gpu, layer );

	if( printInfo ) {
		if(	extension_properties.length == 0 )  {
			printf( "\tExtension: None\n" );

		} else {
			foreach( ref properties; extension_properties ) {
				printf( "\t%s, version: %d\n", properties.extensionName.ptr, properties.specVersion );
			}
		}	
		println;
	}
	return extension_properties;
}

/// get the version of any available instance / device / layer extension
auto extensionVersion( T )( T extension, VkPhysicalDevice gpu, const( char )* layer = null, bool printInfo = true ) if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {
	uint32_t result = 0;
	auto extension_properties = listExtensions( gpu, layer, false );
	foreach( ref properties; extension_properties ) {
		static if( is( T : const( char )* )) {
			import core.stdc.string : strcmp;
			if( strcmp( properties.extensionName.ptr, extension )) {
				result = properties.specVersion;
				break;
			}
		} else {
			import core.stdc.string : strncmp, strlen;
			if( extension.length == properties.extensionName.ptr.strlen
			&&  strncmp( properties.extensionName.ptr, extension.ptr, extension.length ) == 0 ) {
				result = properties.specVersion;
				break;
			}
		}
	}
	//pragma( msg, T.stringof );
	if( printInfo ) {
		static if( is( T : const( char )* ))	{
			printf( "%s version: %u\n", layer, result );
		} else {
			// Todo(pp): why is this here evaluated in the case of  T : const( char )* ?????
			//auto layer_z = layer.toStringz;
			//printf( "%s version: %u\n", layer_z.ptr, result );
		}
	}

	return result;
}

/// check if an instance / device / layer extension of any version is available
auto isExtension( T )( T extension, VkPhysicalDevice gpu = VK_NULL_HANDLE, const( char )* layer = null, bool printInfo = true )
if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {

	auto result = extension.extensionVersion( gpu, layer, false ) > 0;
	if( printInfo ) {
		static if( is( T : const( char )* ))	{
			printf( "%s available: %u\n", extension, result );
		} else {
			auto extension_z = extension.toStringz;
			printf( "%s available: %u\n", extension_z.ptr, result );
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
auto listLayers(
	VkPhysicalDevice	gpu,
	bool				printInfo = true,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {

	// Enumerate Instance or Device layers
	auto layer_properties = gpu == VK_NULL_HANDLE ?
		listVulkanProperty!( VkLayerProperties, vkEnumerateInstanceLayerProperties )( file, line, func ) :
		listVulkanProperty!( VkLayerProperties, vkEnumerateDeviceLayerProperties, VkPhysicalDevice )( file, line, func, gpu );

	if( printInfo ) {
		if(	layer_properties.length == 0 )  {
			printf( "\tLayers: None\n" );

		} else {
			if ( gpu != VK_NULL_HANDLE ) {
				VkPhysicalDeviceProperties gpu_properties;
				vkGetPhysicalDeviceProperties( gpu, &gpu_properties );
				println;
				printf( "Layers of: %s\n", gpu_properties.deviceName.ptr );
				import core.stdc.string : strlen;
				auto underline_length = 11 + strlen( gpu_properties.deviceName.ptr );
				printRepeat!VK_MAX_PHYSICAL_DEVICE_NAME_SIZE( '=', underline_length );
				println;
			}
			foreach( ref property; layer_properties ) {
				printf( "%s:\n", property.layerName.ptr );
				printf( "\tVersion: %d\n", property.implementationVersion );
				auto ver = property.specVersion;
				printf( "\tSpec Version: %d.%d.%d\n", ver.vkMajor, ver.vkMinor, ver.vkPatch );
				printf( "\tDescription: %s\n", property.description.ptr );
				gpu.listExtensions( property.layerName.ptr, true );	// drill into extensions
			}
		}	
		println;
	}
	return layer_properties;
}


/// get the version of any available instance / device layer
auto layerVersion( T )( T layer, VkPhysicalDevice gpu = null, bool printInfo = true )
if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {

	uint32_t result = 0;									// version result
	auto layer_properties = listLayers( gpu, false );		// list all layers
	foreach( ref properties; layer_properties ) {			// search for requested layer
		static if( is( T : const( char )* )) {
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
		static if( is( T : const( char )* ))	{
			printf( "%s version: %u\n", layer, result );
		} else {
			auto layer_z = layer.toStringz;
			printf( "%s version: %u\n", layer_z.ptr, result );
		}
	}

	return result;
}

/// check if an instance / device layer of any version is available
auto isLayer( T )( T layer, VkPhysicalDevice gpu, bool printInfo = true )
if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {

	auto result = layer.layerVersion( gpu, false ) > 0;
	if( printInfo ) {
		static if( is( T : const( char )* ))	{
			printf( "%s available: %u\n", layer, result );
		} else {
			auto layer_z = layer.toStringz;
			printf( "%s available: %u\n", layer_z.ptr, result );
		}
	}
	return result;
}



/////////////////////
// Physical Device //
/////////////////////
auto listPhysicalDevices(
	VkInstance	instance,
	bool		printInfo = true,
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) {
	auto gpus = listVulkanProperty!( VkPhysicalDevice, vkEnumeratePhysicalDevices, VkInstance )( file, line, func, instance );

	if( gpus.length == 0 ) {
		import core.stdc.stdio : fprintf, stderr;
		fprintf( stderr, "No gpus found.\n" );
	}

	if( printInfo ) {
		println;
		printf( "GPU count: %d\n", gpus.length ); 
		printf( "============\n" );
	}
	return gpus;
}

// returns gpu properties and can also print the properties, limits and sparse properties  
enum GPU_Info { none = 0, name, properties, limits = 4, sparse_properties = 8 };
auto listProperties( VkPhysicalDevice gpu, GPU_Info gpu_info = GPU_Info.none ) {

	VkPhysicalDeviceProperties gpu_properties;
	vkGetPhysicalDeviceProperties( gpu, &gpu_properties );

	if( gpu_info == GPU_Info.none ) return gpu_properties;

	printf( "%s\n", gpu_properties.deviceName.ptr );
	import core.stdc.string : strlen;
	auto underline_length = strlen( gpu_properties.deviceName.ptr );
	printRepeat!VK_MAX_PHYSICAL_DEVICE_NAME_SIZE( '=', underline_length );
	println;

	if( gpu_info & GPU_Info.properties ) {
		auto ver = gpu_properties.apiVersion;
		auto device_type_z = gpu_properties.deviceType.toStringz;
		printf( "\tAPI Version     : %d.%d.%d\n", ver.vkMajor, ver.vkMinor, ver.vkPatch );
		printf( "\tDriver Version  : %d\n", gpu_properties.driverVersion );
		printf( "\tVendor ID       : %d\n", gpu_properties.vendorID );
		printf( "\tDevice ID       : %d\n", gpu_properties.deviceID );
		printf( "\tGPU type        : %s\n", device_type_z.ptr );
		println;
	}

	if( gpu_info & GPU_Info.limits ) {
		gpu_properties.limits.printTypeInfo;
	}
	
	if( gpu_info & GPU_Info.sparse_properties ) {
		gpu_properties.sparseProperties.printTypeInfo;
	}

	return gpu_properties;
}

// returns the physical device features of a certain physical device
auto listFeatures( VkPhysicalDevice gpu, bool printInfo = true ) {
	VkPhysicalDeviceFeatures features;
	vkGetPhysicalDeviceFeatures( gpu, &features );
	if( printInfo )
		printTypeInfo( features );
	return features;
}

// returns gpu memory properties
auto listMemoryProperties( VkPhysicalDevice gpu, bool printInfo = true ) {
	VkPhysicalDeviceMemoryProperties memory_properties;
	vkGetPhysicalDeviceMemoryProperties( gpu, &memory_properties );
	if( printInfo )
		printTypeInfo( memory_properties );
	return memory_properties;
}


// returns if the physical device does support presentations
auto presentSupport( VkPhysicalDevice gpu, VkSurfaceKHR surface ) {
	
	uint32_t queue_family_property_count;
	vkGetPhysicalDeviceQueueFamilyProperties( gpu, &queue_family_property_count, null );

	// the following two code lines exist only to silence a validation layer warning
	// queue_family_properties is not used, however it is expected to call
	// vkGetPhysicalDeviceQueueFamilyProperties twice, one with null pointer and the second with memory pointer
	auto queue_family_properties = sizedArray!VkQueueFamilyProperties( queue_family_property_count );
	vkGetPhysicalDeviceQueueFamilyProperties( gpu, &queue_family_property_count, queue_family_properties.ptr );

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
auto listQueues( VkPhysicalDevice gpu, bool printInfo = true, VkSurfaceKHR surface = VK_NULL_HANDLE ) {

	uint32_t queue_family_property_count;
	vkGetPhysicalDeviceQueueFamilyProperties( gpu, &queue_family_property_count, null );
	assert( queue_family_property_count >= 1 );

	auto queue_family_properties = sizedArray!VkQueueFamilyProperties( queue_family_property_count );
	vkGetPhysicalDeviceQueueFamilyProperties( gpu, &queue_family_property_count, queue_family_properties.ptr );
	assert( queue_family_property_count >= 1 );

	if( printInfo ) { 
		foreach( q, ref queue; queue_family_properties.data ) {
			println;
			printf( "Queue Family %d\n", q );
			printf( "\tQueues in Family         : %d\n", queue.queueCount );
			printf( "\tQueue timestampValidBits : %d\n", queue.timestampValidBits );

			if( surface != VK_NULL_HANDLE ) {
				VkBool32 present_supported;
				vkGetPhysicalDeviceSurfaceSupportKHR( gpu, q.toUint, surface, &present_supported );
				printf( "\tPresentation supported   : %d\n", present_supported );
			}
			
			if( queue.queueFlags & VK_QUEUE_GRAPHICS_BIT )
				printf( "\tVK_QUEUE_GRAPHICS_BIT\n" );

			if( queue.queueFlags & VK_QUEUE_COMPUTE_BIT )
				printf( "\tVK_QUEUE_COMPUTE_BIT\n" );

			if( queue.queueFlags & VK_QUEUE_TRANSFER_BIT )
				printf( "\tVK_QUEUE_TRANSFER_BIT\n" );

			if( queue.queueFlags & VK_QUEUE_SPARSE_BINDING_BIT )
				printf( "\tVK_QUEUE_SPARSE_BINDING_BIT\n" );
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

	// get a read only reference to the wrapped VkQueueFamilyProperties 
	ref const( VkQueueFamilyProperties ) vkQueueFamilyProperties() {
		return queue_family_properties;
	}

	// VkQueueFamilyProperties can be reached
	alias vkQueueFamilyProperties this;

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

/// get list of Queue_Family structs
/// the struct wraps VkQueueFamilyProperties with its family index
/// moreover with a priority array the count of queues an their priorities can be specified
/// filter functions exist to get queues with certain properties exist for this Array!Queue_Families
/// the initDevice function consumes an array of these structs to specify queue families and queues to be created
///	Params:
///		gpu = reference to a VulkanState struct
///		printInfo = optional: if true prints struct content to stdout
///		surface = optional: if passed in the printed info includes whether a queue supports presenting to that surface
///	Returns: Array!Queue_Family 
auto listQueueFamilies( VkPhysicalDevice gpu, bool printInfo = true, VkSurfaceKHR surface = VK_NULL_HANDLE ) {
	auto queue_family_properties = listQueues( gpu, printInfo, surface );	// get Array!VkQueueFamilyProperties
	auto family_queues = sizedArray!Queue_Family( queue_family_properties.length );
	foreach( family_index, ref family; queue_family_properties.data ) {
		family_queues[ family_index ] = Queue_Family( cast( uint32_t )family_index, family );
	}
	return family_queues;	
}

alias filter = filterQueueFlags;
auto filterQueueFlags( Array_T )( Array_T family_queues, VkQueueFlags include_queue, VkQueueFlags exclude_queue = 0 )
if( is( Array_T == Array!Queue_Family ) || is( Array_T : Queue_Family[] )) {

	Array!Queue_Family filtered_queues;
	foreach( ref family_queue; family_queues ) {
		if(( family_queue.queueFlags & include_queue ) && !( family_queue.queueFlags & exclude_queue )) {
			filtered_queues.insert( family_queue );
		}
	}
	return filtered_queues;

}

alias filter = filterPresentSupport;
auto filterPresentSupport( Array_T )( Array_T family_queues, VkPhysicalDevice gpu, VkSurfaceKHR surface ) 
if( is( Array_T == Array!Queue_Family ) || is( Array_T : Queue_Family[] )) {

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




///////////////////////////
// Convenience Functions //
///////////////////////////

/// list all available instance extensions
auto listExtensions( bool printInfo = true ) {
	if ( printInfo ) {
		println;
		printf( "Instance Extensions\n" );
		printf( "===================\n" );
	}
	return listExtensions( VK_NULL_HANDLE, null, printInfo );
}

/// list all available per layer instance extensions
auto listExtensions( const( char )* layer, bool printInfo = true ) {
	if ( printInfo ) {
		println;
		printf( "Instance Layer Extensions\n" );
		printf( "=========================\n" );
	}
	return listExtensions( VK_NULL_HANDLE, layer, printInfo );	
}

/// list all available device extensions
auto listExtensions( VkPhysicalDevice gpu, bool printInfo = true ) {
	if ( printInfo ) {
		println;
		printf( "Physical Device Extensions\n" );
		printf( "==========================\n" );
	}
	return listExtensions( gpu, null, printInfo );
}

/// list all available layer per device extensions
auto listDeviceLayerExtensions( VkPhysicalDevice gpu, const( char )* layer, bool printInfo = true ) {
	if ( printInfo ) {
		println;
		printf( "Physical Device Layer Extensions\n" );
		printf( "================================\n" );
	}
	return listExtensions( gpu, layer, printInfo );	
}


// Get the version of a instance layer extension
auto extensionVersion( T )( T extension, const( char )* layer, bool printInfo = false ) if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {
	return extensionVersion( extension, VK_NULL_HANDLE, layer, printInfo );
}

// Get the version of a instance extension
auto extensionVersion( T )( T extension, bool printInfo ) if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {
	return extensionVersion( extension, VK_NULL_HANDLE, null, printInfo );
}

/// check if an instance layer extension of any version is available
auto isExtension( T )( T extension, const( char )* layer, bool printInfo = true )
if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {
	return extension.isExtension( VK_NULL_HANDLE, layer, printInfo );
}

/// check if an instance extension of any version is available
auto isExtension( T )( T extension, bool printInfo )
if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {
	return extension.isExtension( VK_NULL_HANDLE, null, printInfo );
}

/// check if a device extension of any version is available
auto isExtension( T )( T extension, VkPhysicalDevice gpu, bool printInfo = true )
if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {
	return extension.isExtension( gpu, null, printInfo );
}

// list all instance layers
auto listLayers( bool printInfo = true ) {
	if( printInfo ) {
		println;
		printf( "Instance Layers\n" );
		printf( "===============\n" );
	}
	return listLayers( VK_NULL_HANDLE, printInfo );
}

/// check if an instance layer of any version is available
auto isLayer( T )( T layer, bool printInfo = true )
if( is( T == string ) || is( T : const( char )* ) || is( T : char[] )) {
	return layer.isLayer( VK_NULL_HANDLE, printInfo );
}
