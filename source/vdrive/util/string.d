module vdrive.util.string;

import vdrive.util.util;
import vdrive.util.array;

import std.uni;
import std.algorithm;
import std.regex;

import core.stdc.stdio  : printf;
import core.stdc.string : memcpy;

alias stringz = const( char )*;



nothrow @nogc:


auto toEnum( E, S )( S val ) if( is( E == enum )) {
    import std.traits : EnumMembers;
    foreach( i, e; __traits( allMembers, E ))
        if( val == e )
            return EnumMembers!E[i];
    return E.init;  //EnumMembers!E[0];
}


auto ref toStringz( E, Array_T )(
    E                   val,
    ref Array_T         result,
    bool                append_data = false,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) if( is( E == enum ) && isCharArray!Array_T ) {

    import std.traits : EnumMembers;
    foreach( i, e; EnumMembers!E )
        if( val == e )
            return toStringz( __traits( allMembers, E )[i], result, append_data, file, line, func );
    return E.stringof.toStringz( result, append_data, file, line, func );
}



auto ref toStringz( S, Array_T )(
    S                   value,
    ref Array_T         result,
    bool                append_data = false,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) if(( is( S == string ) || is( S : char[] )) && isCharArray!Array_T ) {

    auto start_length = append_data ? result.length : 0;
    result.length( start_length + value.length + 1, file, line, func );
    result[ $ - 1 ] = '\0';
    memcpy( result.ptr + start_length, value.ptr, value.length );    //result.value[ 0 .. value.length ] = value[];
    return result;
}


auto toStringz( S )(
    S                   value,
    bool                append_data = false,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) if( is( S == enum ) || is( S == string ) || is( S : char[] )) {

    DArray!char result;
    value.toStringz( result, append_data, file, line, func );
    return result.release;
}



/// convert string slice into DArray!stringz slice
/// Todo(pp): might be broken, test it!
/// Params:
///     in_data = slice of strings
///     terminator = optional final character in the concatenated buffer
/// Returns: DArray!stringz, array of pointers into a stringz array
auto toPtrArray()(
    string[]            in_data,
    char                terminator = '\?',
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) {

    DArray!char concat_buffer;                                                  // Todo(pp): this shouldn't work and needs testing
    return in_data.toPtrArray( concat_buffer, terminator, file, line, func );      // concat_buffer should be destroyed when leaving this func
}



/// copy all strings of a string slice into reference argument out_concat_buffer
/// terminating each string with a '\0' character
/// original content of out_concat_buffer is kept, the array is resized appropriately
/// another dynamic array with stringz pointer into the out_concat_buffer is returned
/// Params:
///     in_data = slice of strings
///     out_concat_buffer = reference to buffer for the string copy and '\0' per string append
///     terminator = optional final character in the concatenated buffer
/// Returns: DArray!stringz, array of pointers into the out_concat_buffer stringz array
auto toPtrArray( Array_T )(
    string[]            in_data,
    ref Array_T         out_concat_buffer,
    char                terminator = '\?',
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) if( isCharArray!Array_T ) {

    DArray!stringz pointer_buffer;
    in_data.toPtrArray( pointer_buffer, out_concat_buffer, terminator, file, line, func );
    return pointer_buffer;
}



/// append all strings of a string slice into reference argument out_concat_buffer
/// terminating each string with a '\0' character
/// original content of out_concat_buffer is kept, the array is resized appropriately
/// pointer into the out_concat_buffer are appended to the reference argument out_pointer_buffer
/// Params:
///     in_data = slice of strings
///     out_concat_buffer = reference to buffer for the string copy and '\0' per string append
///     out_pointer_buffer = reference to pointer buffer where pointer into out_concat_buffer are appended
///     terminator = optional final character in the concatenated buffer
/// Returns: start index of the appended pointer
auto toPtrArray( Array_S, Array_T )(
    string[]            in_data,
    ref Array_S         out_pointer_buffer,
    ref Array_T         out_concat_buffer,
    char                terminator = '\?',
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) if( isDataArray!Array_S && isCharArray!Array_T ) {

    // early exit if in_data is empty
    if( in_data.length == 0 ) return out_pointer_buffer.length;

    size_t new_buffer_length = 0;
    foreach( ref s; in_data )
        new_buffer_length += s.length + 1;

    if( terminator != '\?' ) {
        ++new_buffer_length;
        if( terminator != '\0' ) {
            ++new_buffer_length;
        }
    }

    size_t concat_buffer_start = out_concat_buffer.length;
    out_concat_buffer.length( concat_buffer_start + new_buffer_length, file, line, func );

    size_t pointer_buffer_start = out_pointer_buffer.length;
    out_pointer_buffer.length( pointer_buffer_start + in_data.length, file, line, func );

    in_data.toPtrArray( out_pointer_buffer.data[ pointer_buffer_start .. $ ], out_concat_buffer.data[ concat_buffer_start .. $ ], terminator, file, line, func );
    return pointer_buffer_start;
}



/// copy all strings of a string slice into reference argument out_concat_buffer
/// terminating each string with a '\0' character
/// out_concat_buffer must have sufficient space for the concatenation
/// pointer into the out_concat_buffer are stored into pointer_buffer
/// which also must have sufficient space of count of in_data.length
/// Params:
///     in_data = slice of strings
///     out_concat_buffer = buffer for the string copy and '\0' per string append with sufficient space
///     pointer_buffer = buffer where pointer into out_concat_buffer are stored with sufficient space
///     terminator = optional final character in the concatenated buffer, out_concat_buffer must accommodate it
/// Returns: start index of the appended pointer
void toPtrArray()(
    string[]            in_data,
    stringz[]           pointer_buffer,
    char[]              out_concat_buffer,
    char                terminator = '\?',
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) {

    // early exit if in_data is empty
    if( in_data.length == 0 ) return;

    size_t copy_target_index = 0;
    foreach( i, ref s; in_data ) {
        pointer_buffer[i] = & out_concat_buffer[ copy_target_index ];
        memcpy( cast( void* )pointer_buffer[i], s.ptr, s.length );
        out_concat_buffer[ copy_target_index + s.length ] = '\0';
        copy_target_index += s.length + 1;
    }

    if( terminator != '\?' ) {
        out_concat_buffer[ copy_target_index ] = terminator;
        if( terminator != '\0' ) {
            out_concat_buffer[ copy_target_index + 1 ] = '\0';
        }
    }
}




/// extract all pointers to const(char) strings embedded in a string into const(char) slice argument out_pointer_buffer
/// each substring is expected to be terminated, if the last is not, it will be skipped
/// out_pointer_buffer must have sufficient space for the extraction
/// as no append operation happens in this function it is expected that the out_pointer_buffer holds valid memory
/// Params:
///     in_data = const char strings embedded in one dlang string, e.g. "str1\0str2\0str3\0"
///     out_pointer_buffer = buffer where pointer into in_data string are stored, with sufficient space
/// Returns: slice of out_pointer_buffer with valid pointers
auto toPtrArray()(
    const string        in_data,
    stringz[]           out_pointer_buffer,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) {

    if( in_data.length == 0 )
        return null;

    size_t pointer_count = 1;
    out_pointer_buffer[0] = & in_data[0];

    foreach( i, c; in_data ) {
        if( c == '\0' ) {
            if( i == in_data.length - 1 ) {
                return out_pointer_buffer[ 0..pointer_count ];
            }
            out_pointer_buffer[ pointer_count ] = & in_data[ i + 1 ];
            ++pointer_count;
        }
    }
    printf( "WARNING: last token is not terminated! Skipping\n" );
    return out_pointer_buffer[ 0..pointer_count - 1 ];
}



/// extract all pointers to const(char) strings embedded in a string into const(char) array argument out_pointer_buffer
/// each substring is expected to be terminated, if the last is not, it will be skipped
/// out_pointer_buffer can be a Dynamic_Array, Block_Array or Static_Array (mimicking re-sizable with stack memory)
/// Params:
///     in_data = const char strings embedded in one dlang string, e.g. "str1\0str2\0str3\0"
///     out_pointer_buffer = buffer where pointer into in_data string are stored, with sufficient space
/// Returns: reference to out pointer buffer
auto ref toPtrArray( Array_T )(
    const string        in_data,
    ref Array_T         out_pointer_buffer,
    string              file = __FILE__,
    size_t              line = __LINE__,
    string              func = __FUNCTION__

    ) if( isCharArray!Array_T ) {

    size_t pointer_count = 0;       // count '\0'
    foreach( c; in_data )
        if( c == '\0' )
            ++pointer_count;

    out_pointer_buffer.length( pointer_count, file, line, func );
    in_data.toPtrArray( out_pointer_buffer.data, file, line, func );
    return out_pointer_buffer;
}



/// extract all pointers to const(char) strings embedded in a string into const(char) into a Dynamic_Array
/// each substring is expected to be terminated, if the last is not, it will be skipped
/// Params:
///     in_data = const char strings embedded in one dlang string, e.g. "str1\0str2\0str3\0"
/// Returns: a Dynamic_Array with const char pointer into the in_data string argument
auto toPtrArray()( string in_data, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    DArray!stringz pointer_buffer;
    return in_data.toPtrArray( pointer_buffer, file, line, func );
}





unittest {

    // Testing string of terminated strings toPtrArray buffer
    string strings = "test\0t1\0TEST2\0T3\0";
    stringz[8] stringPtr;
    auto stringPoi = strings.toPtrArray( stringPtr );
    printf( "Count: %d\n%s %s %s\n", stringPtr.length, stringPtr[0], stringPtr[2], stringPtr[1] );
    printf( "Count: %d\n%s %s %s\n", stringPoi.length, stringPoi[0], stringPoi[2], stringPoi[1] );

    // Testing array of strings to string of terminated strings toPtrArray
    auto array_of_strings = [ "test", "t1", "TEST2" ];
    DArray!char pointer_buffer;
    auto String = array_of_strings.toPtrArray( pointer_buffer );
    printf( "%s\n%s\n%s\n", String[0], String[2], String[1] );
    foreach( s; String ) writeln( * ( cast( ubyte * )s ) );
    writeln( cast( ubyte[] )pointer_buffer.data() );
}



template isCharArray( A ) { enum isCharArray = isDataArray!A && is( A.Val_T == char ); }



// not nothrow not @nogc

/**
 * snake_case and camel_case transform
 *
 * Copyright: © 2016 David Monagle
 * License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
 * Authors: David Monagle
 */


/// Transforms the given `input` into snake_case
/// This precomiled regex version does not work at compile time as regex uses malloc
string snakeCase( const string input ) {
    static auto firstCapRE = ctRegex!( `(.)([A-Z][a-z]+)` );
    static auto allCapRE = ctRegex!( `([a-z0-9])([A-Z])`, "g" );

    string output = input.replace( firstCapRE, `$1_$2` );
    output = output.replace( allCapRE, `$1_$2` );

    return output.toLower;
}

unittest {
    assert( "C".snakeCase == "c" );
    assert( "cA".snakeCase == "c_a" );
    assert( "Ca".snakeCase == "ca" );
    assert( "Camel".snakeCase == "camel" );
    assert( "CamelCase".snakeCase == "camel_case" );
    assert( "CamelCamelCase".snakeCase == "camel_camel_case" );
    assert( "Camel2Camel2Case".snakeCase == "camel2_camel2_case" );
    assert( "getHTTPResponseCode".snakeCase == "get_http_response_code" );
    assert( "getHttpResponseCode".snakeCase == "get_http_response_code" );
    assert( "get2HTTPResponseCode".snakeCase == "get2_http_response_code" );
    assert( "HTTPResponseCode".snakeCase == "http_response_code" );
    assert( "HTTPResponseCodeXYZ".snakeCase == "http_response_code_xyz" );
}

/// Transforms the given `input` into snake_case
/// Works at compile time
string snakeCaseCT( const string input ) {
    string firstPass( const string input ) {
        if( input.length < 3 ) return input;

        string output;
        for( auto index = 2; index < input.length; ++index ) {
            output ~= input[index - 2];
            if( input[ index - 1 ].isUpper && input[index].isLower )
                output ~= "_";
        }

        return output ~ input[ $-2..$ ];
    }

    string secondPass(const string input) {
        if( input.length < 2 ) return input;

        string output;
        for( auto index = 1; index < input.length; ++index ) {
            output ~= input[ index - 1 ];
            if (input[ index ].isUpper && ( input[ index - 1 ].isLower || input[ index - 1 ].isNumber ))
                output ~= "_";
        }

        return output ~ input[ $-1..$ ];
    }

    if ( input.length < 2 ) return input.toLower;

    string output = firstPass( input );
    output = secondPass( output );

    return output.toLower;
}


unittest {
    assert( "C".snakeCaseCT == "c" );
    assert( "cA".snakeCaseCT == "c_a" );
    assert( "Ca".snakeCaseCT == "ca" );
    assert( "Camel".snakeCaseCT == "camel" );
    assert( "CamelCase".snakeCaseCT == "camel_case" );
    assert( "CamelCamelCase".snakeCaseCT == "camel_camel_case" );
    assert( "Camel2Camel2Case".snakeCaseCT == "camel2_camel2_case" );
    assert( "getHTTPResponseCode".snakeCaseCT == "get_http_response_code" );
    assert( "get2HTTPResponseCode".snakeCaseCT == "get2_http_response_code" );
    assert( "HTTPResponseCode".snakeCaseCT == "http_response_code" );
    assert( "HTTPResponseCodeXYZ".snakeCaseCT == "http_response_code_xyz" );
}


import std.uni;
import std.algorithm;


/// Returns the camelcased version of the input string.
/// The `upper` parameter specifies whether to uppercase the first character
string camelCase( const string input, bool upper = false, dchar[] separaters = ['_'] ) {
    string output;
    bool upcaseNext = upper;
    foreach( c; input ) {
        if ( !separaters.canFind( c )) {
            if( upcaseNext ) {
                output ~= c.toUpper;
                upcaseNext = false;
            }
            else
                output ~= c.toLower;
        }
        else {
            upcaseNext = true;
        }
    }

    return output;
}

string camelCaseUpper( const string input ) {
    return camelCase( input, true );
}

string camelCaseLower( const string input ) {
    return camelCase( input, false );
}

unittest {
    assert( "c".camelCase == "c" );
    assert( "c".camelCase(true) == "C" );
    assert( "c_a".camelCase == "cA" );
    assert( "ca".camelCase(true) == "Ca" );
    assert( "camel".camelCase(true) == "Camel" );
    assert( "Camel".camelCase(false) == "camel" );
    assert( "camel_case".camelCase(true) == "CamelCase" );
    assert( "camel_camel_case".camelCase(true) == "CamelCamelCase" );
    assert( "caMel_caMel_caSe".camelCase(true) == "CamelCamelCase" );
    assert( "camel2_camel2_case".camelCase(true) == "Camel2Camel2Case" );
    assert( "get_http_response_code".camelCase == "getHttpResponseCode" );
    assert( "get2_http_response_code".camelCase == "get2HttpResponseCode" );
    assert( "http_response_code".camelCase(true) == "HttpResponseCode" );
    assert( "http_response_code_xyz".camelCase(true) == "HttpResponseCodeXyz" );
}
