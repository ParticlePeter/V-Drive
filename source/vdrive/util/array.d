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


void toPtrArray( string[] data, const( char )*[] pointer_buffer, char[] concat_buffer ) {
    size_t copy_target_index = 0;
    foreach( i, ref s; data ) {
        pointer_buffer[i] = & concat_buffer[ copy_target_index ];
        import core.stdc.string : memcpy;
        memcpy( cast( void* )pointer_buffer[i], s.ptr, s.length );
        concat_buffer[ copy_target_index + s.length ] = '\0';
        copy_target_index += s.length + 1;
    }
}


auto toPtrArray( string[] data, ref Array!char concat_buffer ) {
    size_t buffer_length = 0;
    foreach( ref s; data )
        buffer_length += s.length + 1;

    if( concat_buffer.length < buffer_length )
        concat_buffer.length = buffer_length;

    Array!( const( char )* ) pointer_buffer;
    pointer_buffer.length = data.length;
    data.toPtrArray( pointer_buffer.data, concat_buffer.data );

    return pointer_buffer;
}


auto toPtrArray( string[] data ) {
    Array!char concat_buffer;
    return data.toPtrArray( concat_buffer );
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
}