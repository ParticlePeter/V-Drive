module vdrive.util.util;

import erupted.types;
import vdrive.util.array;

import core.stdc.stdio : printf;
import core.stdc.string : memcpy;


nothrow @nogc:


// mixin template which creates to inner struct forwarding functions
mixin template Forward_To_Inner_Struct( inner, string path, ignore... ) {

    // helper template for skipping members
    template skipper( string target ) { enum shouldSkip( string s ) = ( s == target ); }

    import std.meta : anySatisfy;
    static foreach( member; __traits( allMembers, inner )) {
    //  enum skip = anySatisfy!( skipper!( member ).shouldSkip, ignore );       // evaluate if member is in ignore list, https://forum.dlang.org/post/hucredzrhbbjzcesjqbg@forum.dlang.org
        static if( !anySatisfy!( skipper!( member ).shouldSkip, ignore ) && member != "sType" && member != "pNext" && member != "flags" ) {     // skip, also these
            //import vdrive.util.string : snakeCaseCT;                          // convertor from camel to snake case
            //enum member_snake = member.snakeCaseCT;                           // convert to snake case
            //enum member_snake = member;
            mixin( "\n" );                                                      // comment this if debugging and formating this template
            mixin( "    /// Forward member " ~ member ~ " of inner " ~ inner.stringof ~ " as setter function to this.\n" );
            mixin( "    /// Params:\n" );
            mixin( "    /// \t" ~ member/*_snake*/ ~ " = the value forwarded to the inner struct\n" );
            mixin( "    /// Returns: ref to this for function chaining\n" );
            mixin( "auto ref " ~ member ~ "( " ~ typeof( __traits( getMember,  inner, member )).stringof ~ " " ~ member ~ " ) { " ~ path ~ "." ~ member ~ " = " ~ member ~ "; return this; }\n\n" );
            mixin( "    /// forward member " ~ member ~ " of inner " ~ inner.stringof ~ " as getter function to this\n" );
            mixin( "    /// Params:\n" );
            mixin( "    /// Returns: copy of " ~ path ~ "." ~ member ~ "\n" );
            mixin( "auto " ~ member ~ "() { return " ~ path ~ "." ~ member ~ "; }\n\n" );
            //pragma( msg, result );
        }
    }
}




enum LOG_CHAR_SIZE = 256;

/// capture __FILE__, __LINE__, __FUNCTION__ into one struct converting it to printf friendly cstrings
struct Log_Info {
    char[LOG_CHAR_SIZE] file;
    char[LOG_CHAR_SIZE] func;
    size_t              line;
    this( string FUNC, string FILE = __FILE__, size_t LINE = __LINE__ ) nothrow @nogc {
        file[ 0 .. FILE.length ] = FILE[];  file[ FILE.length ] = '\0';
        func[ 0 .. FUNC.length ] = FUNC[];  func[ FUNC.length ] = '\0';
        line = LINE;
    }

    ref Log_Info opCall( string FUNC, string FILE = __FILE__, size_t LINE = __LINE__ ) nothrow @nogc {
        file[ 0 .. FILE.length ] = FILE[];  file[ FILE.length ] = '\0';
        func[ 0 .. FUNC.length ] = FUNC[];  func[ FUNC.length ] = '\0';
        line = LINE;
        return this;
    }
}


private Log_Info p_log_info;



ref Log_Info logInfo( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) nothrow @nogc {
    return p_log_info( func, file, line );
}



// Todo(pp): print to stderr
// Todo(pp): print to custom logger



//
// log_info
//

/// check bool condition with optional message
VkResult vkAssert(
    VkResult        vk_result,
    ref Log_Info    log_info,   //    = logInfo,    // System does not work, carries 1 file line func too late.
    const( char )*  msg_end     = null
    ) nothrow @nogc {
    vk_result.vkAssert( null, logInfo, msg_end );
    return vk_result;
}

/// check bool condition
VkResult vkAssert(
    VkResult        vk_result,
    const( char )*  message,
    ref Log_Info    log_info,   //    = logInfo,    // System does not work, carries 1 file line func too late.
    const( char )*  msg_end     = null
    ) nothrow @nogc {
    if( vk_result != VK_SUCCESS ) {
        printf( "\n! ERROR !\n==============\n" );
        printf( "    VkResult : %s\n", vk_result.toCharPtr );
        printHelper( message, logInfo, msg_end );
    }
    assert( vk_result == VK_SUCCESS );
    return vk_result;
}

/// check bool condition with optional message
void vkAssert(
    bool            assert_value,
    ref Log_Info    log_info,   //    = logInfo,    // System does not work, carries 1 file line func too late.
    const( char )*  msg_end     = null
    ) nothrow @nogc {
    assert_value.vkAssert( null, logInfo, msg_end );
}

/// check bool condition
void vkAssert(
    bool            assert_value,
    const( char )*  message,
    ref Log_Info    log_info,   //    = logInfo,
    const( char )*  msg_end     = null
    ) nothrow @nogc {
    if( !assert_value ) {
        printf( "\n! ERROR !\n==============\n" );
        printHelper( message, log_info, msg_end );
    }
    assert( assert_value );
}

/// print helper for log info
void printHelper(
    const( char )*  message,
    ref Log_Info    log_info,
    const( char )*  msg_end
    ) nothrow @nogc {
    printf( "    File     : %s\n",   log_info.file.ptr );
    printf( "    Line     : %llu\n", log_info.line );
    printf( "    Func     : %s\n",   log_info.func.ptr );
    if( message ) {
        printf(  "    Message  : %s", message );
        if( msg_end ) printf( "%s", msg_end );
        printf(  "\n" );
    }
    printf( "==============\n\n" );
}



//
// file, line, func
//

/// check the correctness of a vulkan result with optional message
VkResult vkAssert(
    VkResult        vk_result,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__,
    const( char )*  msg_end = null
    ) nothrow @nogc {
    vk_result.vkAssert( null, file, line, func, msg_end );
    return vk_result;
}

/// check the correctness of a vulkan result with additinal message(s)
VkResult vkAssert(
    VkResult        vk_result,
    const( char )*  message,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__,
    const( char )*  msg_end = null
    ) nothrow @nogc {
    if( vk_result != VK_SUCCESS ) {
        printf( "\n! ERROR !\n==============\n" );
        printf( "    VkResult : %s\n", vk_result.toCharPtr );
        printHelper( message, file, line, func, msg_end );
    }
    assert( vk_result == VK_SUCCESS );
    return vk_result;
}

/// check bool condition with optional message
void vkAssert(
    bool            assert_value,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__,
    const( char )*  msg_end = null
    ) nothrow @nogc {
    assert_value.vkAssert( null, file, line, func, msg_end );
}

/// check bool condition with additional message(s)
void vkAssert(
    bool            assert_value,
    const( char )*  message,
    string          file = __FILE__,
    size_t          line = __LINE__,
    string          func = __FUNCTION__,
    const( char )*  msg_end = null
    ) nothrow @nogc {
    if( !assert_value ) {
        printf( "\n! ERROR !\n==============\n" );
        printHelper( message, file, line, func, msg_end );
    }
    assert( assert_value );
}

/// print helper for vkAssert
private char[256] buffer;
void printHelper(
    const( char )* message,
    string file,
    size_t line,
    string func,
    const( char )* msg_end
    ) nothrow @nogc {
    memcpy( buffer.ptr, file.ptr, file.length );
    buffer[ file.length ] = '\0';

    printf( "    File     : %s\n", buffer.ptr );
    printf( "    Line     : %llu\n", line );

    memcpy( buffer.ptr, func.ptr, func.length );
    buffer[ func.length ] = '\0';

    printf( "    Func     : %s\n", buffer.ptr );
    if( message ) {
        printf(  "    Message  : %s", message );
        if( msg_end ) printf( "%s", msg_end );
        printf(  "\n" );
    }

    printf( "==============\n\n" );
}




const( char )* toCharPtr( VkResult vk_result ) nothrow @nogc {
    switch( vk_result ) {
        case VK_SUCCESS                             : return "VK_SUCCESS";
        case VK_NOT_READY                           : return "VK_NOT_READY";
        case VK_TIMEOUT                             : return "VK_TIMEOUT";
        case VK_EVENT_SET                           : return "VK_EVENT_SET";
        case VK_EVENT_RESET                         : return "VK_EVENT_RESET";
        case VK_INCOMPLETE                          : return "VK_INCOMPLETE";
        case VK_ERROR_OUT_OF_HOST_MEMORY            : return "VK_ERROR_OUT_OF_HOST_MEMORY";
        case VK_ERROR_OUT_OF_DEVICE_MEMORY          : return "VK_ERROR_OUT_OF_DEVICE_MEMORY";
        case VK_ERROR_INITIALIZATION_FAILED         : return "VK_ERROR_INITIALIZATION_FAILED";
        case VK_ERROR_DEVICE_LOST                   : return "VK_ERROR_DEVICE_LOST";
        case VK_ERROR_MEMORY_MAP_FAILED             : return "VK_ERROR_MEMORY_MAP_FAILED";
        case VK_ERROR_LAYER_NOT_PRESENT             : return "VK_ERROR_LAYER_NOT_PRESENT";
        case VK_ERROR_EXTENSION_NOT_PRESENT         : return "VK_ERROR_EXTENSION_NOT_PRESENT";
        case VK_ERROR_FEATURE_NOT_PRESENT           : return "VK_ERROR_FEATURE_NOT_PRESENT";
        case VK_ERROR_INCOMPATIBLE_DRIVER           : return "VK_ERROR_INCOMPATIBLE_DRIVER";
        case VK_ERROR_TOO_MANY_OBJECTS              : return "VK_ERROR_TOO_MANY_OBJECTS";
        case VK_ERROR_FORMAT_NOT_SUPPORTED          : return "VK_ERROR_FORMAT_NOT_SUPPORTED";
        case VK_ERROR_FRAGMENTED_POOL               : return "VK_ERROR_FRAGMENTED_POOL";
        case VK_ERROR_SURFACE_LOST_KHR              : return "VK_ERROR_SURFACE_LOST_KHR";
        case VK_ERROR_NATIVE_WINDOW_IN_USE_KHR      : return "VK_ERROR_NATIVE_WINDOW_IN_USE_KHR";
        case VK_SUBOPTIMAL_KHR                      : return "VK_SUBOPTIMAL_KHR";
        case VK_ERROR_OUT_OF_DATE_KHR               : return "VK_ERROR_OUT_OF_DATE_KHR";
        case VK_ERROR_INCOMPATIBLE_DISPLAY_KHR      : return "VK_ERROR_INCOMPATIBLE_DISPLAY_KHR";
        case VK_ERROR_VALIDATION_FAILED_EXT         : return "VK_ERROR_VALIDATION_FAILED_EXT";
        case VK_ERROR_INVALID_SHADER_NV             : return "VK_ERROR_INVALID_SHADER_NV";
    //  case VK_NV_EXTENSION_1_ERROR                : return "VK_NV_EXTENSION_1_ERROR";
        case VK_ERROR_OUT_OF_POOL_MEMORY_KHR        : return "VK_ERROR_OUT_OF_POOL_MEMORY_KHR";
        case VK_ERROR_INVALID_EXTERNAL_HANDLE_KHR   : return "VK_ERROR_INVALID_EXTERNAL_HANDLE_KHR";
        default                                     : return "UNKNOWN_RESULT";
    }
}



/// general templated function to enumarate any vulkan property
/// see usage in module surface or module util.info
/// this overload uses a static (stack) stack memory, size passed in as template argument, as result
void listVulkanProperty( Result_AT, alias vkFunc, Args... )( ref Result_AT result, string file, size_t line, string func, Args args ) {
    VkResult vk_result;
    uint32_t count;

    // consider two types of function return types
    // 1.) void, e.g. vkGetPhysicalDeviceQueueFamilyProperties
    // 2.) VkResult, e.g. vkEnumerateInstanceLayerProperties

    import std.traits : ReturnType;
    static if( is( ReturnType!vkFunc == void )) {
        vkFunc( args, & count, null );
        vkAssert( count >  0, file, line, func );
        result.length( count, file, line, func );
        vkFunc( args, & count, result.ptr );

    } else {

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
            vkFunc( args, & count, null ).vkAssert( file, line, func );
            if( count == 0 ) break;
            result.length( count, file, line, func );
            vk_result = vkFunc( args, & count, result.ptr );
            vkAssert( vk_result != VK_INCOMPLETE, "VK_INCOMPLETE result detected!", file, line, func ); // check if everything went right
        } while( vk_result == VK_INCOMPLETE );

        vk_result.vkAssert( file, line, func ); // check if everything went right
    }
}



/// general templated function to enumarate any vulkan property
/// see usage in module surface or module util.info
/// this overload uses a static (stack) stack memory, size passed in as template argument, as result
auto listVulkanProperty( int32_t size, Result_T, alias vkFunc, Args... )( string file, size_t line, string func, Args args ) {
    static assert( size > 0, "Size greate zero mandatory" );
    static if( size == int32_t.max )    alias Result_AT = Dynamic_Array!( Result_T );
    else                                alias Result_AT = Static_Array!(  Result_T, size );
    Result_AT result;
    listVulkanProperty!( Result_AT, vkFunc, Args )( result, file, line, func, args );
    return result;
}


/// general templated function to enumarate any vulkan property
/// see usage in module surface or module util.info
auto listVulkanProperty( Result_T, alias vkFunc, Args... )( string file, size_t line, string func, Args args ) {
    alias Result_AT = Dynamic_Array!( Result_T );
    Result_AT result;
    listVulkanProperty!( Result_AT, vkFunc, Args )( result, file, line, func, args );
    return result;
}


/// general templated function to enumarate any vulkan property
/// see usage in module surface or module util.info
/// this overload takes a void[] scratch space as first arg and alloctes if the space is not sufficient
/// if scratch memory is large enough, result will be cast to a Dynamic_Array and returned in that borrowed memory block
//auto listVulkanProperty( Result_T, alias vkFunc, Args... )( void[] scratch, string file, size_t line, string func, Args args ) {
//    alias Result_AT = Dynamic_Array!( Result_T );
//    auto result = Result_AT( scratch );
//    listVulkanProperty!( Result_AT, vkFunc, Args )( result, file, line, func, args );
//    return result;
//}


/// general templated function to enumarate any vulkan property
/// see usage in module surface or module util.info
/// this overload takes a void* scratch space as first arg and does not allocate
/// scratch memory needs to be sufficiently large, result will be cast and returned in this memory
//void listVulkanProperty( Result_T, alias vkFunc, Args... )( ref Result_T result, string file, size_t line, string func, Args args ) {
//    listVulkanProperty!( Result_T.Array_T, vkFunc, Args )( result.array, file, line, func, args );
//}



struct Dynamic_Result( Result_T, QT ) {
    alias   Query_T = QT;
    alias   Array_T = Dynamic_Array!Result_T;
    alias   array this;
    Query_T query;
    Array_T array;
}

template isDynamicResult( T ) { enum isDynamicResult = is( typeof( isDynamicResultImpl( T.init ))); }
private void isDynamicResultImpl( R, Q )( Dynamic_Result!( R, Q ) result ) {}


struct Static_Result( Result_T, QT, uint Capacity ) {
    alias   Query_T = QT;
    alias   Array_T = Static_Array!( Result_T, Capacity );
    alias   array this;
    Query_T query;
    Array_T array;
}

template isStaticResult( T ) { enum isStaticResult = is( typeof( isStaticResultImpl( T.init ))); }
private void isStaticResultImpl( R, Q, uint C )( Static_Result!( R, Q, C ) result ) {}


template isDynamicOrStaticResult( T ) { enum isDynamicOrStaticResult = isDynamicResult!T || isStaticResult!T; }

//auto listVulkanProperty( Result_T, alias vkFunc, Args... )( ref Arena_Array arena, string file, size_t line, string func, Args args ) {
//    alias Result_AT = Block_Array!( Result_T );
//    auto result = Result_AT( arena );
//    VkResult vk_result;
//    uint32_t count;
//
//    /*
//    * instance layers could change. For example, installing something
//    * could include new layers that the loader would pick up
//    * between the initial query for the count and the
//    * request for VkLayerProperties. If that happens,
//    * the number of VkLayerProperties could exceed the count
//    * previously given. To alert the app to this change
//    * vkEnumerateInstanceExtensionProperties will return a VK_INCOMPLETE
//    * status.
//    * The count parameter will be updated with the number of
//    * entries actually loaded into the data pointer.
//    */
//
//    do {
//        vkFunc( args, & count, null ).vkAssert( file, line, func );
//        if( count == 0 )  break;
//        result.length( count, file, line, func );
//        vk_result = vkFunc( args, & count, result.ptr );
//    } while( vk_result == VK_INCOMPLETE );
//
//    vk_result.vkAssert( file, line, func ); // check if everything went right
//
//    return result.release;
//}




nothrow:


alias vkMajor = VK_VERSION_MAJOR;
alias vkMinor = VK_VERSION_MINOR;
alias vkPatch = VK_VERSION_PATCH;

alias toUint = toUint32_t;
uint32_t toUint32_t( T )( T value ) if( __traits( isScalar, T )) {
    return cast( uint32_t )value;
}

alias toInt = toInt32_t;
int32_t toInt32_t( T )( T value ) if( __traits( isScalar, T )) {
    return cast( int32_t )value;
}

alias toUlong = toUint64_t;
uint64_t toUint64_t( T )( T value ) if( __traits( isScalar, T )) {
    return cast( uint64_t )value;
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



//
// Enum utils
//

template EnumMemberCount( E ) if ( is( E == enum )) {
    enum EnumMemberCount = [ __traits(allMembers, E) ].length;
}


uint32_t to_index( E )( E value ) if( is( E == enum )) {
    import std.traits : EnumMembers;
    static foreach( i, enum_member; EnumMembers!E )
        if( layout == enum_member )
            return i;
    return 0;
}


E to_enum( E )( uint32_t index ) if( is( E == enum )) {
    import std.traits : EnumMembers;
    foreach( i, enum_member; EnumMembers!E )
        if( i == index )
            return enum_member;
    return E.init;
}

T aligned( T )( T value, T alignment ) {
    if( value % alignment > 0 ) {
        value = ( value / alignment + 1 ) * alignment;
    }
    return value;
}