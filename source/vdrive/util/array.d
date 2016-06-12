module vdrive.util.array;

public import std.container.array;


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

auto append( T )( Array!T array, T value )  {
	array.insert( value );
}

auto toStringz( T )( T data ) if( is( T == string ) | is( T : char[] )) {
	Array!char result;
	result.length = data.length + 1;
	result[ data.length ] = '\0';
	import core.stdc.string : memcpy;
	memcpy( result.ptr, data.ptr, data.length );	//result.data[ 0 .. data.length ] = data[]; 
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
	size_t pointer_count = 0;		// count '\0'
	foreach( c; data )
		if( c == '\0' )
			++pointer_count;  

	Array!( const( char )* ) pointer_buffer;
	pointer_buffer.length = pointer_count;
	data.toPtrArray( pointer_buffer.data );
	return pointer_buffer;
}