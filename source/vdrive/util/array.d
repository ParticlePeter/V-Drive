module vdrive.util.array;

public import std.container.array;


// Todo(pp): write your own nothrow @nogc array similar to std::vector (non ref counted)
// Requirements:
// - optionally use external memory ( not managed - not allocated/freed )
// - optionally move data out of function without destroying and reallocating memory
// - underlying data should be castable

auto sizedArray( T )( size_t length ) {
    Array!T array;
    array.length = length;
    return array;
}

auto ptr( T )( Array!T array )  {
    if( array.length == 0 ) return null;
    return & array.front();
}

auto data( T )( Array!T array )  {
    if( array.length == 0 ) return null;
    return array.ptr[ 0..array.length ];
}

auto ref append( T )( ref Array!T array, T value )  {
    array.insert( value );
    return array.data[ $-1 ];
}

auto toStringz( T )( T data ) if( is( T == enum )) {
    import std.conv : to;
    return data.to!string.toStringz;
}

auto toStringz( T )( T data ) if( is( T == string ) || is( T : char[] )) {
    Array!char result;
    result.length = data.length + 1;
    result[ data.length ] = '\0';
    import core.stdc.string : memcpy;
    memcpy( result.ptr, data.ptr, data.length );    //result.data[ 0 .. data.length ] = data[]; 
    return result;
}


/// convert string slice into Array!const( char )* slice
/// Todo(pp): might be broken, test it!
/// Params:
///     data = slice of strings
///     terminator = optional final character in the concatenated buffer
/// Returns: Array!const( char )*[], array of pointers into a stringz array
auto toPtrArray( string[] data, char terminator = '\?' ) {
    Array!char concat_buffer;                               // Todo(pp): this shouldn't work and needs testing
    return data.toPtrArray( concat_buffer, terminator );    // concat_buffer should be destroyed when leaving this func
}


/// copy all strings of a string slice into reference argument concat_buffer
/// terminating each string with a '\0' character
/// original content of concat_buffer is kept, the array is resized appropriately
/// another dynamic array with const( char )* pointer into the concat_buffer is returned 
/// Params:
///     data = slice of strings
///     concat_buffer = reference to buffer for the string copy and '\0' per string append
///     terminator = optional final character in the concatenated buffer
/// Returns: Array!const( char )*[], array of pointers into the concat_buffer stringz array
auto toPtrArray( string[] data, ref Array!char concat_buffer, char terminator = '\?' ) {
    Array!( const( char )* ) pointer_buffer;
    data.toPtrArray( pointer_buffer, concat_buffer, terminator );
    return pointer_buffer;
}


/// copy all strings of a string slice into reference argument concat_buffer
/// terminating each string with a '\0' character
/// original content of concat_buffer is kept, the array is resized appropriately
/// pointer into the concat_buffer are appended to the reference argument pointer_buffer 
/// Params:
///     data = slice of strings
///     concat_buffer = reference to buffer for the string copy and '\0' per string append
///     pointer_buffer = reference to pointer buffer where pointer into concat_buffer are appended
///     terminator = optional final character in the concatenated buffer
/// Returns: start index of the appended pointer
auto toPtrArray( string[] data, ref Array!( const( char )* ) pointer_buffer, ref Array!char concat_buffer, char terminator = '\?' ) {
    // early exit if data is empty
    if( data.length == 0 ) return pointer_buffer.length;

    size_t new_buffer_length = 0;
    foreach( ref s; data )
        new_buffer_length += s.length + 1;

    if( terminator != '\?' ) {
        ++new_buffer_length;
        if( terminator != '\0' ) {
            ++new_buffer_length;
        }
    }

    size_t concat_buffer_start = concat_buffer.length;
    concat_buffer.length = concat_buffer_start + new_buffer_length;

    size_t pointer_buffer_start = pointer_buffer.length;
    pointer_buffer.length = pointer_buffer_start + data.length;

    data.toPtrArray( pointer_buffer.data[ pointer_buffer_start .. $ ], concat_buffer.data[ concat_buffer_start .. $ ], terminator );
    return pointer_buffer_start;
}


/// copy all strings of a string slice into reference argument concat_buffer
/// terminating each string with a '\0' character
/// concat_buffer must have sufficient space for the concatenation
/// pointer into the concat_buffer are stored into pointer_buffer
/// which also must have sufficient space of count of data.length 
/// Params:
///     data = slice of strings
///     concat_buffer = buffer for the string copy and '\0' per string append with sufficient space
///     pointer_buffer = buffer where pointer into concat_buffer are stored with sufficient space
///     terminator = optional final character in the concatenated buffer, concat_buffer must accommodate it
/// Returns: start index of the appended pointer
void toPtrArray( string[] data, const( char )*[] pointer_buffer, char[] concat_buffer, char terminator = '\?' ) {
    // early exit if data is empty
    if( data.length == 0 ) return;

    size_t copy_target_index = 0;
    foreach( i, ref s; data ) {
        pointer_buffer[i] = & concat_buffer[ copy_target_index ];
        import core.stdc.string : memcpy;
        memcpy( cast( void* )pointer_buffer[i], s.ptr, s.length );
        concat_buffer[ copy_target_index + s.length ] = '\0';
        copy_target_index += s.length + 1;
    }

    if( terminator != '\?' ) {
        concat_buffer[ copy_target_index ] = terminator;
        if( terminator != '\0' ) {
            concat_buffer[ copy_target_index + 1 ] = '\0';
        }
    }
}





auto toPtrArray( string data, const( char )*[] pointer_buffer ) {
    if( data.length == 0 )
        return null;

    size_t pointer_count = 1; 
    pointer_buffer[0] = & data[0];

    foreach( i, c; data ) {
        if( c == '\0' ) {
            if( i == data.length - 1 ) {
                return pointer_buffer[ 0..pointer_count ];
            }
            pointer_buffer[ pointer_count ] = & data[ i + 1 ];
            ++pointer_count;  
        }
    }
    import core.stdc.stdio : printf;
    printf( "WARNING: last token is not terminated! Skipping\n" );
    return pointer_buffer[ 0..pointer_count - 1 ];
}


auto toPtrArray( string data ) {
    size_t pointer_count = 0;       // count '\0'
    foreach( c; data )
        if( c == '\0' )
            ++pointer_count;  

    Array!( const( char )* ) pointer_buffer;
    pointer_buffer.length = pointer_count;
    data.toPtrArray( pointer_buffer.data );
    return pointer_buffer;
}



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



nothrow @nogc:


struct Static_Array( uint size, T ) {
    alias Size_T = typeof( size );
    private T[ size ] m_data;
    private Size_T count = 0;

    alias data this;
    T[] data() { return m_data[ 0 .. count ]; }

    // set desired length, which must not be greater then the array size
    void length( Size_T l, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) {
        import vdrive.util.util : vkAssert;
        vkAssert( count <= size, "Memory not sufficient to set requested length!", file, line, func );
        count = l;
    }

    const Size_T length()   { return count; }
    const Size_T opDollar() { return count; }
    const bool empty()      { return count == 0; }
    Size_T capacity()       { return size; }

    @property T* ptr()  { return count == 0 ? null : m_data.ptr; }

    ref inout( T ) opIndex( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__  ) inout {
        import vdrive.util.util : vkAssert;
        vkAssert( i < size, "Array out of bounds!", file, line, func );
        return m_data[ i ];
    }

    inout @property ref inout( T ) front()  { return m_data[ 0 ]; }
    inout @property ref inout( T ) back()   { return m_data[ count - 1 ]; }

    void append( S )( S stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( is( S : T )) {
        import vdrive.util.util : vkAssert;
        vkAssert( count < size, "Memory not sufficient to append additional data!", file, line, func );
        m_data[ count ] = stuff;
        ++count;
    }

    void clear() { count = 0; }
}

alias SArray = Static_Array;


auto sizedArray( uint max_length, T )( uint length ) {
    SArray!( max_length, T ) array;
    array.length = length;
    return array;
}


template D_OR_S_ARRAY( int count, T ) {
         static if( count == int.max )  alias D_OR_S_ARRAY = Array!T;               // resize-able array
    else static if( count > 0 )         alias D_OR_S_ARRAY = SArray!( count, T );   // static array mimicking resize-able array
    else                                alias D_OR_S_ARRAY = T[ - count ];          // static array
}