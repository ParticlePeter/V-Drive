module vdrive.util.info;

import core.stdc.stdio : printf;

import vdrive.util.util;
import vdrive.util.array;
import vdrive.util.string;
import vdrive.state;

import erupted;


nothrow @nogc:

// TODO(pp): merge with lbmd.settings to serialize with and without export attributes and to stdout or file
// TODO(pp): extract function for listing available enums of possible enums
void printTypeInfo( T, size_t buffer_size = 256 )(
    ref T   info,
    bool    printStructName = true,
    string  indent = "",
    size_t  max_type_length = 0,
    size_t  max_name_length = 0,
    bool    newline = true ) if( is( T == struct ) || is( T == union )) /*@nogc nothrow*/ {

    // struct name
    import std.conv : to;

    char[ buffer_size ] buffer = void;

    if ( printStructName ) {
        buffer[ 0 .. T.stringof.length ] = T.stringof;
        buffer[ T.stringof.length ] = '\0';
        printf( "%s\n", buffer.ptr );
        buffer[ 0 .. T.stringof.length ] = '=';
        printf( "%s\n", buffer.ptr );
    }

    // indent the buffer and store a pointer position;
    auto buffer_indent = buffer.ptr;
    buffer_indent[ 0 ] = '\t';                      buffer_indent += 1;
    buffer_indent[ 0 .. indent.length ] = indent;   buffer_indent += indent.length;

    // need this template as non aliased types are shorter than aliased, but aliased are printed later
    immutable string[8] integral_alias_types = [ "uint64_t", "uint32_t", "uint16_t", "uint8_t", "int64_t", "int32_t", "int16_t", "int8_t" ];
    size_t alias_type_length( T )( ref T ) {
        static      if( is( T == uint16_t ) || is( T == uint32_t ) || is( T == uint64_t )) return 8;
        else static if( is( T ==  int16_t ) || is( T ==  int32_t ) || is( T ==  int64_t ) || is( T ==  ubyte )) return 7;
        else static if( is( T ==  int8_t )) return 6;
        else return T.stringof.length;
    }

    // max struct attribute string max_name_length
    size_t max( size_t a, size_t b ) { return a < b ? b : a; }
    foreach( member_name; __traits( allMembers, T )) {
        alias member = printInfoHelper!( __traits( getMember, T, member_name ));
        max_name_length = max( max_name_length, member_name.stringof.length );
        max_type_length = max( max_type_length, alias_type_length( __traits( getMember, info, member_name )));
    }
    max_type_length += 2;       // space to member name
    max_name_length &= ~1;


    // pretty print attributes
    import std.traits : isFloatingPoint, isPointer;

    void print( T )( char* buffer_ptr, T data, string name = "", string assign = " : ", string line = "\n" ) {

        import core.stdc.string : memcpy, memset;
        char* leftJustify( char* ptr, string str, size_t num ) {
            buffer_ptr[ 0 .. str.length ] = str;        //  memcpy( ptr,  str.ptr, str.length );
            buffer_ptr[ str.length .. num ] = ' ';      //  memset( ptr + str.length, ' ', num - str.length );
            return  ptr + num;
        }

        string typeAlias( T )() {
                 static if( is( T == uint64_t ))  return integral_alias_types[0];
            else static if( is( T == uint32_t ))  return integral_alias_types[1];
            else static if( is( T == uint16_t ))  return integral_alias_types[2];
            else static if( is( T ==  uint8_t ))  return integral_alias_types[3];
            else static if( is( T ==  int64_t ))  return integral_alias_types[4];
            else static if( is( T ==  int32_t ))  return integral_alias_types[5];
            else static if( is( T ==  int16_t ))  return integral_alias_types[6];
            else static if( is( T ==   int8_t ))  return integral_alias_types[7];
            else return T.stringof;
        }

        buffer_ptr = leftJustify( buffer_ptr, typeAlias!T, max_type_length );
        buffer_ptr = leftJustify( buffer_ptr, name, max_name_length );
        buffer_ptr[ 0 ] = '\0';

             static if( is( T == uint64_t ))  printf( "%s : %llu\n", buffer.ptr, data );
        else static if( is( T == uint32_t ))  printf( "%s : %u\n",   buffer.ptr, data );
        else static if( is( T == uint16_t ))  printf( "%s : %u\n",   buffer.ptr, data );
        else static if( is( T ==  uint8_t ))  printf( "%s : %u\n",   buffer.ptr, data );
        else static if( is( T ==  int64_t ))  printf( "%s : %lli\n", buffer.ptr, data );
        else static if( is( T ==  int32_t ))  printf( "%s : %i\n",   buffer.ptr, data );
        else static if( is( T ==  int16_t ))  printf( "%s : %i\n",   buffer.ptr, data );
        else static if( is( T ==   int8_t ))  printf( "%s : %i\n",   buffer.ptr, data );
        else static if( isFloatingPoint!T )   printf( "%s : %f\n",   buffer.ptr, data );
        else static if( isPointer!T ) {
            if( data is null )  printf( "%s : null\n", buffer.ptr );
            else                printf( "%s : %p\n",   buffer.ptr, data );
        }
    }


    foreach( member_name; __traits( allMembers, T )) {
        alias member = printInfoHelper!( __traits( getMember, T, member_name ));
        auto  member_data = __traits( getMember, info, member_name );
        alias member_type = typeof( member_data );

        auto buffer_ptr = buffer_indent;
        buffer_ptr[ 0 ] = '\0';

        /*
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
                        print( buffer_ptr, member_type.stringof, member_name, "enum_member.to!string" );
                        last_used_value = enum_member;
                    }
                }
            } else {
                foreach( enum_member; EnumMembers!member_type ) {
                    auto enum_member_string = " enum_member.to!string";
                    // need to filter the enum bellow _MAX_ENUM, as they are not API constructs but just implementor help
                    if( member_data & enum_member && member_data != 0x7FFFFFFF ) {
                        if ( !assigned ) {
                            assigned = true;
                            print( buffer_ptr, member_type.stringof, member_name, " enum_member.to!string" );
                        } else {
                            print( buffer_ptr, "", "", " enum_member.to!string", " | " );
                        }
                    }
                }
                // if nothing was assigned, the enum would be skipped, hence print it with artificial NONE flag
                if( !assigned ) print( buffer_ptr, member_type.stringof, member_name, "NONE" );
            }
        }

        //else static if( member_type!isPointer ) {}

        else*/ static if( is( member_type == struct ) || is( member_type == union )) {
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

        else print!member_type( buffer_ptr, member_data, member_name );

        /*
        else static if( is( member_type : B[n], B, size_t n )) {
            // arrays (strings)
            static if( is( B : char )) {
                printf( "%s : %s\n", leftJustify( member_name, max_name_length, ' ' ).toStringz, member_data );
            }
            else static if( is( B : uint32_t ) || is( B : uint64_t )) {
                printf( "%s : [ %u", leftJustify( member_name, max_name_length, ' ' ).toStringz, member_data[0]);
                foreach( v; 1..n )  printf( ", %u", member_data[v] );
                printf( " ]\n" );
            }
            else static if( is( B :  int32_t ) || is( B :  int64_t )) {
                printf( "%s : [ %d", leftJustify( member_name, max_name_length, ' ' ).toStringz, member_data[0]);
                foreach( v; 1..n )  printf( ", %d", member_data[v] );
                printf( " ]\n" );
            }
            else static if( isFloatingPoint!B ) {
                printf( "%s : [ %f", leftJustify( member_name, max_name_length, ' ' ).toStringz, member_data[0]);
                foreach( v; 1..n )  printf( ", %f", member_data[v] );
                printf( " ]\n" );
            }
            else {    // printf numeric arrays
                printf( "%s : %s\n", leftJustify( member_name, max_name_length, ' ' ).toStringz, typeof( member_data ).stringof.toStringz );
            }
        } else {
            printf( "%s : %s\n", leftJustify( member_name, max_name_length, ' ' ).toStringz, typeof( member_data ).stringof.toStringz );
        }
        */

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

