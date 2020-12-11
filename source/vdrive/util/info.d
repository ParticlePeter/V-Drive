module vdrive.util.info;

import core.stdc.stdio : printf;
import std.exception : enforce;

import vdrive.util.util;
import vdrive.util.array;
import vdrive.util.string;
import vdrive.state;

import erupted;




// TODO(pp): get rid of the GC with @nogc, remove to!string requirement
// TODO(pp): extract function for listing available enums of possible enums
void printTypeInfo( T, size_t buffer_size = 256 )(
    T       info,
    bool    printStructName = true,
    string  indent = "",
    size_t  max_type_length = 0,
    size_t  max_name_length = 0,
    bool    newline = true ) if( is( T == struct ) || is( T == union )) /*@nogc nothrow*/ {

    // struct name
    import std.conv : to;
    //import std.array : replicate;

    //import core.stdc.string : strncpy, memset;
            //if( strncmp( properties.layerName.ptr, layer.ptr, layer.length ) == 0 ) {
            //  return properties.implementationVersion;

    char[ buffer_size ] buffer = void;

    if ( printStructName ) {
        buffer[ 0 .. T.stringof.length ] = T.stringof;    //    strncpy( buffer.ptr, T.stringof.ptr, T.stringof.length );
        buffer[ T.stringof.length ] = '\0';
        printf( "%s\n", buffer.ptr );
        buffer[ 0 .. T.stringof.length ] = '=';           //    memset( buffer.ptr, '=', T.stringof.length );
        printf( "%s\n", buffer.ptr );
    }

    // indent the buffer and store a pointer position;
    auto buffer_indent = buffer.ptr;
    buffer_indent[ 0 ] = '\t';                      buffer_indent += 1;
    buffer_indent[ 0 .. indent.length ] = indent;   buffer_indent += indent.length;

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
    max_type_length += 2;       // space to member name


    // pretty print attributes
    import std.string : leftJustify;
    import std.traits : isFloatingPoint, isPointer;

    void print( char* buffer_ptr, string type, string name = "", string data = "", string assign = " : ", string line = "\n" ) {
        buffer_ptr[ 0..max_type_length ] = type.leftJustify( max_type_length, ' ' );  buffer_ptr += max_type_length;
        buffer_ptr[ 0..max_name_length ] = name.leftJustify( max_name_length, ' ' );  buffer_ptr += max_name_length;
        buffer_ptr[ 0..assign.length ] = assign;                                      buffer_ptr += assign.length;
        buffer_ptr[ 0..data.length ] = data;                                          buffer_ptr += data.length;
        buffer_ptr[ 0..line.length ] = line;
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

                buffer_ptr[ 0..member_type.stringof.length ] = member_type.stringof;
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
            else static if( is( member_type == uint64_t ))  print( buffer_ptr, "uint64_t", member_name, member_data.to!string );
            else static if( is( member_type == uint32_t ))  print( buffer_ptr, "uint32_t", member_name, member_data.to!string );
            else static if( is( member_type == uint16_t ))  print( buffer_ptr, "uint16_t", member_name, member_data.to!string );
            else static if( is( member_type ==  uint8_t ))  print( buffer_ptr,  "uint8_t", member_name, member_data.to!string );
            else static if( is( member_type ==  int64_t ))  print( buffer_ptr,  "int64_t", member_name, member_data.to!string );
            else static if( is( member_type ==  int32_t ))  print( buffer_ptr,  "int32_t", member_name, member_data.to!string );
            else static if( is( member_type ==  int16_t ))  print( buffer_ptr,  "int16_t", member_name, member_data.to!string );
            else static if( is( member_type ==   int8_t ))  print( buffer_ptr,   "int8_t", member_name, member_data.to!string );

            else static if( isFloatingPoint!member_type )   print( buffer_ptr, member_type.stringof, member_name, member_data.to!string );
            else static if( isPointer!member_type )         print( buffer_ptr, member_type.stringof, member_name, member_data.to!string );
                //if( member_data is null ) print( buffer_ptr, member_type.stringof, member_name, "null" );
                //else                      print( buffer_ptr, member_type.stringof, member_name, member_data );

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
                } else {    // printf numeric arrays
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





// print new line
void println() { printf( "\n" ); }


// print char n count
void printRepeat( size_t MAX_CHAR_COUNT )( char c, size_t count ) {
    char[ MAX_CHAR_COUNT ] repeat;
    repeat[] = c;
    if( MAX_CHAR_COUNT < count ) count = MAX_CHAR_COUNT;
    printf( "%.*s", cast( int )count, repeat.ptr );
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


//nothrow @nogc:

private template isStringT( T )         { enum isStringT        = is( T == string ) || is( T : const( char )* ) || is( T : char[] ); }
private template isVkOrGpu( T )         { enum isVkOrGpu        = is( T == Vulkan ) || is( T == VkPhysicalDevice ); }
private template isVkOrInstance( T )    { enum isVkOrInstance   = is( T == Vulkan ) || is( T == VkInstance ); }





////////////////
// Extensions //
////////////////

/// helper function to print listed extension properties
private void printExtensionProperties( Array_T )( ref Array_T extension_properties ) {
    if( extension_properties.length == 0 )
        printf( "\tExtension: None\n" );
    else
        foreach( ref properties; extension_properties )
            printf( "\t%s, version: %d\n", properties.extensionName.ptr, properties.specVersion );
    println;
}



/// Result type to list extensions using Vulkan_State scratch memory
alias List_Extensions_Result = Scratch_Result!VkExtensionProperties;



/// list all available ( layer per ) instance / device extensions, using scratch memory
auto ref listExtensions( Result_T )(
    ref Result_T    result,
    const( char )*  layer,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = result.vk.gpu;
    else                                    auto gpu = result.query;

    // Enumerate Instance or Device extensions
    if( gpu.is_null )   listVulkanProperty!( Result_T.Array_T, vkEnumerateInstanceExtensionProperties,                 const( char )* )( result.array, file, line, func, layer );
    else                listVulkanProperty!( Result_T.Array_T, vkEnumerateDeviceExtensionProperties, VkPhysicalDevice, const( char )* )( result.array, file, line, func, gpu, layer );

    if( print_info ) printExtensionProperties( result.array );
    return result.array;
}



/// list all available ( layer per ) instance / device extensions, allocates heap memory
auto listExtensions( VkPhysicalDevice gpu, const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto result = Dynamic_Result!( VkExtensionProperties, VkPhysicalDevice )( gpu );
    listExtensions!( typeof( result ))( result, layer, print_info, file, line, func );
    return result.array.release;
}



/// get the version of any available instance / device / layer extension
auto extensionVersion( String_T, VK_OR_GPU )(
    String_T            extension,
    ref VK_OR_GPU       vk_or_gpu,
    const( char )*      layer = null,
    bool                print_info = true,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) if( isStringT!String_T && isVkOrGpu!VK_OR_GPU ) {

    static if( isVulkan!VK_OR_GPU ) auto query_result = Scratch_Result!( VkExtensionProperties )( vk_or_gpu );
    else                            auto query_result = Dynamic_Result!( VkExtensionProperties, VK_OR_GPU )( vk_or_gpu );

    uint32_t result = 0;                                                // version result
    listExtensions( query_result, layer, false, file, line, func );     // list all extensions
    foreach( ref properties; query_result.array ) {                     // search for requested extension
        static if( is( String_T : const( char )* )) {
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
    //pragma( msg, String_T.stringof );
    if( print_info ) {
        static if( is( String_T : const( char )* )) {
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
auto isExtension( String_T, VK_OR_GPU )(
    String_T            extension,
    ref VK_OR_GPU       vk_or_gpu,
    const( char )*      layer = null,
    bool                print_info = true,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) if( isStringT!String_T && isVkOrGpu!VK_OR_GPU ) {

    auto result = extensionVersion!( String_T, VK_OR_GPU )( extension, vk_or_gpu, layer, false, file, line, func ) > 0;

    if( print_info ) {
        static if( is( String_T : const( char )* )) {
            printf( "%s available: %u\n", extension, result );
        } else {
            // if we have passed Vulkan_State instead of just the VkPhysicalDevice, we can use the scratch array to sub-allocate string z conversion
            static if( isVulkan!VK_OR_GPU ) auto extension_z = Block_Array!char( vk_or_gpu.scratch );
            else                            auto extension_z = Dynamic_Array!char();    // allocates
            extension.toStringz( extension_z );
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

/// helper function to print listed layer properties, drills down into extension properties of each layer
private void printLayerProperties( Array_T, VK_OR_GPU )(
    ref Array_T     layer_properties,
    ref VK_OR_GPU   vk_or_gpu,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isVkOrGpu!VK_OR_GPU ) {

    if( layer_properties.length == 0 ) {
        printf( "\tLayers: None\n" );
    } else {
        static if( isVulkan!VK_OR_GPU ) {
            auto gpu = vk_or_gpu.gpu;
            auto result = Scratch_Result!( VkExtensionProperties )( vk_or_gpu );
        } else {
            auto gpu = vk_or_gpu;
            auto result = Dynamic_Result!( VkExtensionProperties, VK_OR_GPU )( gpu );
        }

        if ( gpu != VK_NULL_HANDLE ) {
            VkPhysicalDeviceProperties gpu_properties;
            vkGetPhysicalDeviceProperties( gpu, & gpu_properties );
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

            // drill into layer extensions
            //gpu.listExtensions( property.layerName.ptr, true );
            listExtensions!( typeof( result ))( result, property.layerName.ptr, true, file, line, func );
        }
    }
    println;
}



/// Result type to list layers using Vulkan_State scratch memory
alias List_Layers_Result = Scratch_Result!VkLayerProperties;



/// list all available instance / device layers
auto ref listLayers( Result_T )(
    ref Result_T    layer_properties,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = layer_properties.vk.gpu;
    else                                    auto gpu = layer_properties.query;

    // Enumerate Instance or Device layers
    if( gpu.is_null )   listVulkanProperty!( Result_T.Array_T, vkEnumerateInstanceLayerProperties,                )( layer_properties, file, line, func );
    else                listVulkanProperty!( Result_T.Array_T, vkEnumerateDeviceLayerProperties, VkPhysicalDevice )( layer_properties, file, line, func, gpu );

    if( print_info ) {
        // if we received a Scratch_Result, we should pass on its Vulkan_State with scratch array, otherwise just the gpu
        static if( isScratchResult!Result_T )   printLayerProperties( layer_properties, layer_properties.vk );
        else                                    printLayerProperties( layer_properties, gpu );
    }
    return layer_properties.array;
}



auto listLayers( VkPhysicalDevice gpu, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto layer_properties = Dynamic_Result!( VkLayerProperties, VkPhysicalDevice )( gpu );
    listLayers!( typeof( layer_properties ))( layer_properties, print_info, file, line, func );
    return layer_properties.release;
}



/// get the version of any available instance / device layer
auto layerVersion( String_T, VK_OR_GPU )(
    String_T        layer,
    ref VK_OR_GPU   vk_or_gpu,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isStringT!String_T && isVkOrGpu!VK_OR_GPU ) {

    static if( isVulkan!VK_OR_GPU ) auto query_result = Scratch_Result!( VkLayerProperties )( vk_or_gpu );
    else                            auto query_result = Dynamic_Result!( VkLayerProperties, VK_OR_GPU )( vk_or_gpu );

    uint32_t result = 0;                                    // version result
    listLayers( query_result, false, file, line, func );    // list all layers
    foreach( ref properties; query_result.array ) {         // search for requested layer
        static if( is( String_T : const( char )* )) {
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

    if( print_info ) {
        static if( is( String_T : const( char )* )) {
            printf( "%s version: %u\n", layer, result );
        } else {
            auto layer_z = layer.toStringz;
            printf( "%s version: %u\n", layer_z.ptr, result );
        }
    }

    return result;
}

/// check if an instance / device layer of any version is available
auto isLayer( String_T, VK_OR_GPU )(
    String_T        layer,
    ref VK_OR_GPU   vk_or_gpu,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isStringT!String_T && isVkOrGpu!VK_OR_GPU ) {

    auto result = layerVersion( layer, vk_or_gpu, false, file, line, func ) > 0;

    if( print_info ) {
        static if( is( String_T : const( char )* )) {
            printf( "%s available: %u\n", layer, result );
        } else {
            // if we have passed Vulkan_State instead of just the VkPhysicalDevice, we can use the scratch array to sub-allocate string z conversion
            static if( isVulkan!VK_OR_GPU ) auto layer_z = Block_Array!char( vk_or_gpu.scratch );
            else                            auto layer_z = Dynamic_Array!char();    // allocates
            layer.toStringz( layer_z );
            printf( "%s available: %u\n", layer_z.ptr, result );
        }
    }

    return result;
}



/////////////////////
// Physical Device //
/////////////////////

/// Result type to list Physical Devices (GPUs) using Vulkan_State scratch memory
alias listPhysicalDevicesResult = Scratch_Result!VkPhysicalDevice;



auto ref listPhysicalDevices( Result_T )(
    ref Result_T    result,
    bool            print_info = true,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    static if( isScratchResult!Result_T )   auto instance = result.vk.instance;
    else                                    auto instance = result.query;

    vkAssert( !instance.is_null, "List physical devices: Vulkan.instance must not be VK_NULL_HANDLE!", file, line, func );
    listVulkanProperty!( Result_T.Array_T, vkEnumeratePhysicalDevices, VkInstance )( result.array, file, line, func, instance );

    if( result.array.length == 0 ) {
        import core.stdc.stdio : fprintf, stderr;
        fprintf( stderr, "No gpus found.\n" );
    }

    if( print_info ) {
        println;
        printf( "GPU count: %d\n", result.array.length );
        printf( "============\n" );
    }
    return result.array;
}

//alias listPhysicalDevices = listPhysicalDevices_T!Vulkan;
//alias listPhysicalDevices = listPhysicalDevices_T!VkInstance;


auto listPhysicalDevices( VkInstance instance, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto result = Dynamic_Result!( VkPhysicalDevice, VkInstance )( instance );
    listPhysicalDevices( result, print_info, file, line, func );
    return result.array.release;
}


// flags to determine if and which gpu properties should be printed
enum GPU_Info_Flags { none = 0, name, properties, limits = 4, sparse_properties = 8 };



// returns gpu properties and can also print the properties, limits and sparse properties
// the passed in Result_Type (Scratch or Dynamic) is only for string z conversion purpose
auto listProperties(
    VkPhysicalDevice    gpu,
    GPU_Info_Flags      gpu_info,
    Arena_Array*        arena,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__
    ) {

    VkPhysicalDeviceProperties gpu_properties;
    vkGetPhysicalDeviceProperties( gpu, & gpu_properties );

    if( gpu_info == GPU_Info_Flags.none ) return gpu_properties;

    printf( "%s\n", gpu_properties.deviceName.ptr );
    import core.stdc.string : strlen;
    auto underline_length = strlen( gpu_properties.deviceName.ptr );
    printRepeat!VK_MAX_PHYSICAL_DEVICE_NAME_SIZE( '=', underline_length );
    println;

    if( gpu_info & GPU_Info_Flags.properties ) {
        auto ver = gpu_properties.apiVersion;
        printf( "\tAPI Version     : %d.%d.%d\n", ver.vkMajor, ver.vkMinor, ver.vkPatch );
        printf( "\tDriver Version  : %d\n", gpu_properties.driverVersion );
        printf( "\tVendor ID       : %d\n", gpu_properties.vendorID );
        printf( "\tDevice ID       : %d\n", gpu_properties.deviceID );

        // if an Arena_Array was passed in we can suballocate from it for the string_z conversion, else we allocate
        if( arena !is null ) {
            auto device_type_z = Block_Array!char( *arena );
            gpu_properties.deviceType.toStringz( device_type_z );       // suballocates from arena
            printf( "\tGPU type        : %s\n", device_type_z.ptr );
        } else {
            auto device_type_z = gpu_properties.deviceType.toStringz;   // allocates and returns a dynamic array
            printf( "\tGPU type        : %s\n", device_type_z.ptr );
        }
        println;
    }

    if( gpu_info & GPU_Info_Flags.limits ) {
        gpu_properties.limits.printTypeInfo;
    }

    if( gpu_info & GPU_Info_Flags.sparse_properties ) {
        gpu_properties.sparseProperties.printTypeInfo;
    }

    return gpu_properties;
}

auto listProperties( VkPhysicalDevice gpu, GPU_Info_Flags gpu_info = GPU_Info_Flags.none, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    return listProperties( gpu, gpu_info, null, file, line, func );    // in this case we return the VkPhysicalDeviceProperties, the array is only for string z conversion when printing
}

auto listProperties( VkPhysicalDevice gpu, GPU_Info_Flags gpu_info, ref Arena_Array arena, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    return listProperties( gpu, gpu_info, & arena, file, line, func );    // in this case we return the VkPhysicalDeviceProperties, the array is only for string z conversion when printing
}

// returns the physical device features of a certain physical device
auto listFeatures( VkPhysicalDevice gpu, bool print_info = true ) {
    VkPhysicalDeviceFeatures features;
    vkGetPhysicalDeviceFeatures( gpu, & features );
    if( print_info )
        printTypeInfo( features );
    return features;
}

// returns gpu memory properties
auto listMemoryProperties( VkPhysicalDevice gpu, bool print_info = true ) {
    VkPhysicalDeviceMemoryProperties memory_properties;
    vkGetPhysicalDeviceMemoryProperties( gpu, & memory_properties );
    if( print_info )
        printTypeInfo( memory_properties );
    return memory_properties;
}


// returns if the physical device does support presentations
auto presentSupport( ref VkPhysicalDevice gpu, VkSurfaceKHR surface, bool print_info = true ) {
    uint32_t queue_family_property_count;
    vkGetPhysicalDeviceQueueFamilyProperties( gpu, & queue_family_property_count, null );
    VkBool32 present_supported;
    foreach( family_index; 0..queue_family_property_count ) {
        vkGetPhysicalDeviceSurfaceSupportKHR( gpu, family_index, surface, & present_supported );
        if( present_supported ) {
            return true;
        }
    }
    return false;
}

////////////
// Queues //
////////////

alias listQueuesResult = Scratch_Result!VkQueueFamilyProperties;


/// list all available queue families and their queue count
auto ref listQueues( Result_T )(
    ref Result_T    queue_family_properties,
    bool            print_info = true,
    VkSurfaceKHR    surface = VK_NULL_HANDLE,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__
    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = queue_family_properties.vk.gpu;
    else                                    auto gpu = queue_family_properties.query;

    // Enumerate Queues
    listVulkanProperty!( Result_T.Array_T, vkGetPhysicalDeviceQueueFamilyProperties, VkPhysicalDevice )( queue_family_properties, file, line, func, gpu );

    // log the info
    if( print_info ) {
        foreach( q, ref queue; queue_family_properties.data ) {
            println;
            printf( "Queue Family %lu\n", cast( int )q );
            printf( "\tQueues in Family         : %d\n", queue.queueCount );
            printf( "\tQueue timestampValidBits : %d\n", queue.timestampValidBits );

            if( surface != VK_NULL_HANDLE ) {
                VkBool32 present_supported;
                vkGetPhysicalDeviceSurfaceSupportKHR( gpu, q.toUint, surface, & present_supported );
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



auto listQueues( VkPhysicalDevice gpu, bool print_info = true, VkSurfaceKHR surface = VK_NULL_HANDLE, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto result = Dynamic_Result!( VkQueueFamilyProperties, VkPhysicalDevice )( gpu );
    listQueues!( typeof( result ))( result, print_info, surface, file, line, func );
    return result.array.release;
}



// Wraps a VkQueueFamilyProperties
// adds a family index and a Static_Array!float priorities
struct Queue_Family_T( uint Capacity, Size_T = uint ) {

    private uint32_t index;
    private VkQueueFamilyProperties queue_family_properties;
    private SArray!( float, Capacity, Size_T ) queue_priorities;

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
        return queue_priorities.length.toUint;
    }

    void queueCount( uint32_t count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {
        vkAssert( count <= maxQueueCount, "More queues requested than available!", file, line, func );
        queue_priorities.length = count;
        import std.math : isNaN;
        foreach( ref priority; queue_priorities ) if( priority.isNaN ) priority = 0.0f;
    }

    // get a pointer to the priorities array
    float * priorities() {
        return queue_priorities.ptr;
    }

    // getter and setter for a specific priority at a specific index
    ref float priority( uint32_t queue_index, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {
        vkAssert( queue_index < queue_priorities.length, "Index out of bounds of requested priorities!", file, line, func );
        return queue_priorities[ queue_index ];
    }

    // set all priorities and implicitly the requested queue count
    void priorities( float[] values, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {
        vkAssert( values.length <= maxQueueCount, "More priorities specified than available queues!", file, line, func );
        queue_priorities.append( values );
    }

    // get a string representation of the data
    auto toString() {
        char[256] buffer;
        import std.format : sformat;
        sformat( buffer,
            "\n\tfamilyIndex: %s, maxQueueCount: %s, queueCount: %s, queue_priorities: %s",
            family_index, maxQueueCount, queueCount, queue_priorities[]
        );
        return buffer;
    }
}

alias  Queue_Family = Queue_Family_T!4;     // Todo(pp): Queue_Family is used excessively, but it should always be Queue_Family_T!4. Fix this!

alias listQueueFamiliesResult = Scratch_Result!Queue_Family;
alias listQueueFamiliesResult_T( uint Capacity ) = Scratch_Result!( Queue_Family_T!Capacity );     // enables us to pass in a max count for the families as template argument

/// get list of Queue_Family structs
/// the struct wraps VkQueueFamilyProperties with its family index
/// and a priority array, with which the count of queues an their priorities can be specified
/// filter functions exist to get queues with certain properties for the Result_T family_queues.array
/// the initDevice function consumes an array of these structs to specify queue families and queues to be created
/// Params:
///     gpu = reference to a VulkanState struct
///     print_info = optional: if true prints struct content to stdout
///     surface = optional: if passed in the printed info includes whether a queue supports presenting to that surface
/// Returns: Array embedded in Result_T family_queues
auto ref listQueueFamilies( Result_T )(
    ref Result_T    family_queues,
    bool            print_info = true,
    VkSurfaceKHR    surface = VK_NULL_HANDLE,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__

    ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {

    // extract gpu member based on template argument
    static if( isScratchResult!Result_T )   auto gpu = family_queues.vk.gpu;
    else                                    auto gpu = family_queues.query;

    vkAssert( !gpu.is_null, "List Queue Families, gpu must not be VK_NULL_HANDLE!", file, line, func );

    // Care must be taken if using scratch space to gather the required information
    // at this point the referenced result family_queues is already part of scratch
    // but it has not sub-allocated memory. We must reserve the required memory before we
    // sub-allocate the required queue family properties, or the former would not have
    // any space to be resized, as the latter is consecutively behind it
    uint32_t queue_family_property_count;
    vkGetPhysicalDeviceQueueFamilyProperties( gpu, & queue_family_property_count, null );

    family_queues.reserve( queue_family_property_count, file, line, func );     // we reserve first as we do not need...
    family_queues.length(  queue_family_property_count, file, line, func );     // ... extra space to grow after the requested length

    // now enumerate all the queues
    static if( isScratchResult!Result_T ) {
        auto queue_family_properties = listQueuesResult ( family_queues.vk );
        listQueues( queue_family_properties, print_info, surface );
    } else {
        auto queue_family_properties = listQueues( gpu, print_info, surface );
    }

    foreach( family_index, ref family; queue_family_properties.data ) {
        family_queues[ family_index ] = Queue_Family( cast( uint32_t )family_index, family );
    }
    return family_queues.array;//.release;
}



auto listQueueFamilies( VkPhysicalDevice gpu, bool print_info = true, VkSurfaceKHR surface = VK_NULL_HANDLE, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    auto result = Dynamic_Result!( Queue_Family, VkPhysicalDevice )( gpu );
    listQueueFamilies!( typeof( result ))( result, print_info, surface, file, line, func );
    return result.array.release;
}


/*
auto listQueueFamilies_T( size_t max_queues_per_family )( VkPhysicalDevice gpu, bool print_info = true, VkSurfaceKHR surface = VK_NULL_HANDLE ) {
    auto queue_family_properties = listQueues( gpu, print_info, surface );   // get Array of VkQueueFamilyProperties
    auto family_queues = sizedArray!( Queue_Family_T!max_queues_per_family )( queue_family_properties.length );
    foreach( family_index, ref family; queue_family_properties.data ) {
        family_queues[ family_index ] = Queue_Family( cast( uint32_t )family_index, family );
    }
    return family_queues;//.release;
}
alias listQueueFamilies = listQueueFamilies_T!64;
*/

alias filter = filterQueueFlags;
auto ref filterQueueFlags( Array_T )(
    ref Array_T     family_queues,
    VkQueueFlags    include_queue,
    VkQueueFlags    exclude_queue = 0

    ) if( isDataArrayOrSlice!( Array_T, Queue_Family )) {

    // remove invalid entries by overwriting them with valid ones
    size_t valid_index = 0;
    foreach( i; 0..family_queues.length ) {
        if(( family_queues[ i ].queueFlags & include_queue ) && !( family_queues[ i ].queueFlags & exclude_queue )) {
            if( valid_index < i ) {     // no need to replace if the current loop index equals the valid index
                family_queues[ valid_index ] = family_queues[ i ];
            }
            ++valid_index;
        }
    }
    // shrink the array to the amount of valid entries
    family_queues.length = valid_index;
    return family_queues;
}


alias filter = filterPresentSupport;
auto ref filterPresentSupport( Array_T )(
    ref Array_T         family_queues,
    VkPhysicalDevice    gpu,
    VkSurfaceKHR        surface

    ) if( isDataArrayOrSlice!( Array_T, Queue_Family )) {

    // remove invalid entries by overwriting them with valid ones
    size_t valid_index = 0;
    VkBool32 present_supported;

    foreach( i, ref family_queue; family_queues ) {
        vkGetPhysicalDeviceSurfaceSupportKHR( gpu, family_queue.family_index, surface, & present_supported );
        if( present_supported ) {
            if( valid_index < i ) {     // no need to replace if the current loop index equals the valid index
                family_queues[ valid_index ] = family_queue;
            }
            ++valid_index;
        }
    }
    // shrink the array to the amount of valid entries
    family_queues.length = valid_index;
    return family_queues;
}




///////////////////////////
// Convenience Functions //
///////////////////////////

/// list all available instance extensions
auto listExtensions( bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nInstance Extensions\n===================\n" );
    return listExtensions( VK_NULL_HANDLE, null, print_info, file, line, func );
}

/// list all available per layer instance extensions
auto listExtensions( const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nInstance Layer Extensions\n=========================\n" );
    return listExtensions( VK_NULL_HANDLE, layer, print_info, file, line, func );
}

/// list all available device extensions
auto listExtensions( VkPhysicalDevice gpu, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nPhysical Device Extensions\n==========================\n" );
    return listExtensions( gpu, null, print_info, file, line, func );
}

/// list all available layer per device extensions
auto listDeviceLayerExtensions( VkPhysicalDevice gpu, const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) printf( "\nPhysical Device Layer Extensions\n================================\n" );
    return listExtensions( gpu, layer, print_info, file, line, func );
}


// Get the version of an instance layer extension
auto extensionVersion( String_T )( String_T extension, const( char )* layer, bool print_info = false, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return extensionVersion!( String_T, VkPhysicalDevice )( extension, vkNull, layer, print_info, file, line, func );
}

// Get the version of an instance extension
auto extensionVersion( String_T )( String_T extension, bool print_info, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return extensionVersion!( String_T, VkPhysicalDevice )( extension, vkNull, null, print_info, file, line, func );
}

/// check if an instance layer extension of any version is available
auto isExtension( String_T )( String_T extension, const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return isExtension( extension, vkNull, layer, print_info, file, line, func );
}

/// check if an instance extension of any version is available
auto isExtension( String_T )( String_T extension, bool print_info, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return isExtension!( String_T, VkPhysicalDevice )( extension, vkNull, null, print_info, file, line, func );
}

/// check if a device extension of any version is available
auto isExtension( String_T )( String_T extension, VkPhysicalDevice gpu, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    return isExtension!( String_T, VkPhysicalDevice )( extension, gpu, null, print_info, file, line, func );
}

// list all instance layers
auto listLayers( bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if( print_info ) printf( "\nInstance Layers\n===============\n" );
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return listLayers( vkNull, print_info, file, line, func );
}

/// check if an instance layer of any version is available
auto isLayer( String_T )( String_T layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    VkPhysicalDevice vkNull = VK_NULL_HANDLE; return isLayer( layer, vkNull, print_info, file, line, func );
}



/////////////////////////////////////////////
// Convenience Functions Vulkan State base //
/////////////////////////////////////////////

/// list all available instance or device extensions, depends on whteher gpu is set in Vulkan State
auto ref listExtensions( Result_T )( ref Result_T result, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isScratchResult!Result_T || isDynamicResult!Result_T ) {
    if ( print_info ) {
        // extract gpu member based on template argument
        static if( isScratchResult!Result_T )   auto gpu = result.vk.gpu;
        else                                    auto gpu = result.query;

        if( gpu == VK_NULL_HANDLE ) printf( "\nInstance Extensions\n===================\n" );
        else                        printf( "\nPhysical Device Extensions\n==========================\n" );
    } return listExtensions( result, null, print_info, file, line, func );
}
/*
/// list all available instance or device layer extensions, depends on whteher gpu is set in Vulkan State
auto listExtensions( ref Vulkan vk, const( char )* layer, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if ( print_info ) {
        if( vk.gpu == VK_NULL_HANDLE )  printf( "\nInstance Layer Extensions\n===================\n" );
        else                            printf( "\nPhysical Device Layer Extensions\n================================\n" );
    } return listExtensions!Vulkan( vk, layer, print_info, file, line, func );
}

// Get the version of an instance extension
auto extensionVersion( String_T )( String_T extension, ref Vulkan vk, bool print_info, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    return extensionVersion( extension, vk, null, print_info, file, line, func );
}
*/
/// check if a device extension of any version is available, depends on whteher gpu is set in Vulkan State
auto isExtension( String_T )( String_T extension, ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    return isExtension!( String_T, Vulkan )( extension, vk, null, print_info, file, line, func );
}
/*
// list all instance layers
auto listLayers( ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    if( print_info ) printf( "\nInstance Layers\n===============\n" );
    return listLayers!Vulkan( vk, print_info, file, line, func );
}
*/
/// check if an instance layer of any version is available
auto isLayer( String_T )( String_T layer, ref Vulkan vk, bool print_info = true, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( isStringT!String_T ) {
    return isLayer!( String_T, Vulkan )( layer, vk, print_info, file, line, func );
}
