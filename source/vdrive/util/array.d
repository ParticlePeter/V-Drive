module vdrive.util.array;


enum debug_alloc = false;
enum debug_arena = true;


import core.stdc.stdlib : malloc, free;
import core.stdc.string : memcpy;
import core.stdc.stdio  : printf;

import vdrive.util.util : Log_Info, vkAssert;


nothrow @nogc:


/// Dynamic Array, non-copyable to avoid unnecessary data duplication
struct Dynamic_Array( T, ST = uint ) {
    nothrow @nogc:
    alias   Val_T   = T;
    alias   Size_T  = ST;
    private Val_T*  Data        = null;
    private Size_T  Count       = 0;
    private Size_T  Capacity    = 0;
    private bool    Owns_Memory = true;

    // constructor with borrowed memory
    this( void[] borrowed ) {
        Data = cast( Val_T* )( borrowed.ptr );
        Capacity = cast( Size_T )( borrowed.length / T.sizeof );
        Owns_Memory = false;
    }


    // convenience constructor, initializes array with data
    this( Val_T[] stuff, void[] borrowed = [] ) {
        if( borrowed != [] ) {
            Data = cast( Val_T* )( borrowed.ptr );
            Capacity = cast( Size_T )( borrowed.length / T.sizeof );
            Owns_Memory = false;
        }
        append( stuff );
    }


    // convenience constructor, possibly sets capacity and initializes array with count of init values
    this( Size_T count, Size_T capacity = 0, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        if( count <= capacity )
            reserve( capacity, file, line, func );
        length( count, true, file, line, func );  // initialize elements
    }


    // cannot be called from outside, used to move data (release, dup)
    private this( Val_T* data, Size_T count, Size_T capacity ) {
        Data        = data;
        Count       = count;
        Capacity    = capacity;
    }


    // free data on destruction
    ~this() {
        if( Owns_Memory == true ) {
            free( Data );
        }
    }


    // disable copying
    @disable this( this );


    // properties
    alias   data this;
    Val_T[] data()              { return Data[ 0 .. Count ]; }  // borrowed references, don't store resulting slice!
    Size_T  opDollar()  const   { return Count; }
    Size_T  capacity()  const   { return Capacity; }
    bool    empty()     const   { return Count == 0; }
    void    clear()     { Count = 0; }

    inout( Val_T )* ptr()       inout { return Data; }
    inout( Size_T ) length()    inout { return Count; }


    // reset internal state
    void reset( void[] borrowed = [] ) {
        if( Owns_Memory && Data !is null ) {
            free( Data );
            Data = null;
        }

        if( borrowed == [] ) {
            Owns_Memory = true;
            Capacity = 0;
            Data = null;
        } else {
            Owns_Memory = false;
            Capacity = cast( Size_T )( borrowed.length );
            Data = cast( Val_T* )( borrowed.ptr );
        }

        Count = 0;
    }


    // reset internal state
    void reset( Val_T[] stuff, void[] borrowed = [] ) {
        reset( borrowed );
        length = stuff.length;
        data[ 0 .. stuff.length ] = stuff[];
    }


    // set desired length, resulting capacity might become larger than count
    void length( size_t count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        if( count > Capacity )
            reserve( growCapacity( count ), file, line, func );
        Count = cast( Size_T )count;

        static if( debug_arena ) if( Max_Count < Count ) Max_Count = Count;
    }


    // set desired length and if data should be initialized with default value, resulting capacity might become larger than count
    void length( size_t count, bool initialize, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        if( initialize ) { Val_T t; length( count, t, file, line, func ); }
        else                        length( count, file, line, func );
    }


    // set desired length, resulting capacity might become larger than count and initialize each element
    void length( size_t count, ref Val_T initial, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        auto old_count = Count;
        length( count, file, line, func );
        foreach( ref d; data[ old_count .. count ] ) {
            d = initial;
        }
    }


    // index access
    ref inout( Val_T ) opIndex( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout {
        vkAssert( i < Count, file, line, func, "Array out of bounds!" );
        return Data[ i ];
    }


    // Empty_Array opIndex can't return a reference but the array interface must be able to return
    // an element pointer. Hence we use this work around for empty arrays to silently retun a null pointer
    inout( Val_T )* ptr_at( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout { return & opIndex(  i, file, line, func ); }
    inout( Val_T )* ptr_back( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout { return & opIndex( length - 1, file, line, func ); }


    // convenience first and last element access
    ref inout( Val_T ) front()  inout   { return Data[ 0 ]; }
    ref inout( Val_T ) back()   inout   { return Data[ Count - 1 ]; }


    // disable concatenation
    @disable void opBinary( string op : "~" )( Val_T   t ) {}
    @disable void opBinary( string op : "~" )( Val_T[] t ) {}


    // customize appending single element
    void opOpAssign( string op : "~" )( Val_T stuff ) {
        return append( stuff );
    }


    // customize appending slice of elements
    void opOpAssign( string op: "~" )( Val_T[] stuff ) {
        return append( stuff );
    }


    // append single element, return the appended element for further manipulation
    Val_T* append( S )( S stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( is( S : Val_T )) {
        if( Capacity == Count )
            reserve( growCapacity( Count + 1 ), file, line, func );
        Data[ Count ] = stuff;
        Count += 1;
        return & Data[ Count - 1 ];
    }


    // append slice of elements, return the append result for further manipulation
    Val_T[] append( S )( S[] stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( is( S : T )) {
        if( Capacity < Count + cast( Size_T )( stuff.length ))
            reserve( growCapacity( Count + stuff.length ), file, line, func );
        auto start = Count;
        Count += stuff.length;
        Data[ start .. Count ] = stuff[];
        return Data[ start .. Count ];
    }


    // move data out of struct without copying the struct itself, works in tandem with private constructor
    Dynamic_Array release() {
        Val_T* data = Data;
        Data = null;
        return Dynamic_Array( data, Count, Capacity );
    }


    // duplicate the struct
    Dynamic_Array dup( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        if( Data is null )
            return Dynamic_Array();
        T* new_data = cast( T* )malloc( Capacity * T.sizeof );
        static if( debug_alloc ) printf( "\n--------\nmalloc : %s : %u, %s\n--------\n\n", file, line, func.file.ptr, file, line, func.line, file, line, func.func.ptr );

        memcpy( new_data, Data, Capacity * T.sizeof );
        return Dynamic_Array( new_data, Count, Capacity );
    }


    // compute new capacity
    private size_t growCapacity( size_t count ) {
        size_t capacity = Capacity > 0 ? ( Capacity + Capacity / 2 ) : 8;
        return capacity > count ? capacity : count;
    }


    // reserve memory
    void reserve( size_t capacity, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        if( capacity <= Capacity ) return;
        T* new_data = cast( T* )malloc( capacity * T.sizeof );          // mGui::MemAlloc( ... );
        static if( debug_alloc )
            printf( "\n--------\nmalloc : %s : %u, %s\n--------\n\n", file, line, func.file.ptr, file, line, func.line, file, line, func.func.ptr );

        if( Data !is null ) {
            memcpy( new_data, Data, Count * T.sizeof );
            if( Owns_Memory ) {
                free( Data );                                           // mGui::MemFree( Data );
            } else {
                Owns_Memory = true;
            }
        }
        Data = new_data;
        Capacity = cast( Size_T )capacity;

        static if( debug_arena ) if( Max_Capacity < Capacity ) Max_Capacity = Capacity;
    }


    static if( debug_arena ) {
        private   Size_T  Max_Count       = 0;
        private   Size_T  Max_Capacity    = 0;

        Size_T max_count()      { return Max_Count; }
        Size_T max_capacity()   { return Max_Capacity; }
    }
}

alias DArray = Dynamic_Array;



// structure defines a memory block of the source array specified by Offset and Count in bytes
// it can be single linked or bidirectional, linking to its previous or next block
// The size of the block is the Capacity of the borrowing array
struct Block_Link( ST = uint /*, bool bidirectional = false*/ ) {
    alias                   Size_T  = ST;
    //static if( bidirectional ) private BLink* Prev = null;
    private BLink!Size_T*   Prev    = null;
    private BLink!Size_T*   Next    = null;
    private Size_T          Offset  = 0;
    private Size_T          Size    = 0;
}

alias BLink = Block_Link;


struct Arena_Array_T( ST = uint ) {   //, bool biderectional = false ) {
    nothrow @nogc:
    alias                       Size_T = ST;
    DArray!( ubyte, Size_T )    Source;
    alias                       Source this;
    alias                       BLink_T = BLink!Size_T;
    private BLink_T*            Head = null;
    private BLink_T*            Tail = null;
    //Block_Link                  List = { Offset : Size_T.max };


    private void attach( BLink_T* link, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        if( Head is null ) {
            vkAssert( Tail is null, file, line, func, "If Head is null, Tail must be null as well!" );
            //vkAssert( List.Prev is null, file, line, func, "If Next of the linked list is null, Prev must be null as well!" );
            Head = link;        // if no blocks were registered so far
            Tail = link;        // attach this block link as head and as tail

            //List.Next = List.Prev = link;
            //link.Next = link.Prev = & List;

        } else {
            link.Prev = Tail;
            Tail.Next = link;
            Tail = link;

            //link.Prev = List.
        }

        link.Offset = length;

        static if( debug_arena ) {
            ++Num_Links;
            if( Max_Links < Num_Links ) Max_Links = Num_Links;
        }
    }


    private void detach( BLink_T* link, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        /*
        vkAssert( Head !is null, file, line, func, "No Block_Array registered!" );
        BLink_T* prev = null;
        BLink_T* curr = Head;

        // search the passed in link in the linked list
        while( link !is curr ) {
            vkAssert( curr.Next !is null, file, line, func, "Borrowed link not found in linked list!" );
            prev = curr;
            curr = curr.Next;
        }

        // arriving here link == current, now we let prev.Next point to curr.Next
        if( prev is null )      Head = link.Next;           // -> found link is the first in the list -> link.next becomes first in list
        else                    prev.Next = link.Next;      // -> othervise link had a predcessor (prev) -> prev.Next points to link.Next
        if( link is Tail )      Tail = prev;                // -> if link was at the end -> Tail becomes its predcessor (prev), which might be null
        link.Next = null;                                   // remove invalid reference, which would be reachable outside this function
        */

        if( link is Head )      Head = link.Next;
        else                    link.Prev.Next = link.Next;
        if( link is Tail )      Tail = link.Prev;
        else                    link.Next.Prev = link.Prev;

        // adjust the length of the source array
        if( Tail is null )      Source.length( 0, file, line, func );
        else                    Source.length( Tail.Offset + Tail.Size, file, line, func );

        static if( debug_arena ) {
            --Num_Links;
        }
    }


    private void replace( BLink_T* old_link, BLink_T* new_link, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( Head !is null, file, line, func, "No Block_Array registered!" );

        if( Head is old_link ) {
            Head =  new_link;
            Tail =  new_link;
            return;
        }

        BLink_T* curr = Head;

        // search the passed in link in the linked list
        while( old_link !is curr.Next ) {
            vkAssert( curr.Next !is null, file, line, func, "Borrowed link not found in linked list!" );
            curr = curr.Next;
        }

        curr.Next = new_link;

    }

    // disable copying
    @disable this( this );


    // disable default constructor
    //@disable this();



    static if( debug_arena ) {
        private Size_T Num_Links = 0;   Size_T num_links() { return Num_Links; }
        private Size_T Max_Links = 0;   Size_T max_links() { return Max_Links; }


        void printLinkInfo() {
            uint link_index = 0;
            auto link = Head;
            while( link !is null ) {
                link = link.Next;
                link_index++;
            }
        }
    }
}

alias Arena_Array = Arena_Array_T!();
alias AArray = Arena_Array;



/// Dynamic Array, non-copyable to avoid unnecessary data duplication
struct Block_Array( T, ST = uint ) {
    nothrow @nogc:
    alias                   Val_T   = T;
    alias                   Size_T  = ST;
    alias                   Arena_T = Arena_Array_T!Size_T;
    alias                   BLink_T = BLink!Size_T;

    private BLink_T         Link;
    private Arena_T*        Arena   = null;
    private Size_T          Count   = 0;
    private Size_T          Capacity() const { return Link.Size / Val_T.sizeof; }

    Arena_T*                arena() { return Arena; }

    // properties
    alias   data        this;
    Val_T[] data()      { return ptr()[ 0 .. Count ]; }       // borrowed references, don't store resulting slice!
    void    clear()     { Count = 0; }
    bool    empty()     const { return Count == 0; }
    Size_T  capacity()  const { return Capacity(); }
    Size_T  opDollar()  const { return Count; }
    //Size_T  length()  const { return Count; }

    inout( Val_T )*  ptr()      inout { return cast( inout( Val_T )* )( Arena.ptr + Link.Offset ); }
    inout( Size_T ) length()    inout { return Count; }


    // we are sub-allocating from the arena array, we must make sure that we have enough room for this allocation
    // if we don't have then assert ... for now. Later we can try to move the data to some internal chunk or to the back of the arena array
    void length( size_t count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        if( count > Capacity )
            reserve( growCapacity( count ), file, line, func );
        vkAssert( count * T.sizeof <= Link.Size, file, line, func, "Borrowed Link has not enough size!" );
        Count = cast( Size_T )count;
    }


    // set desired length and if data should be initialized with default value, resulting capacity might become larger than count
    void length( size_t count, bool initialize, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        if( initialize ) { T t; length( count, t, file, line, func ); }
        else                    length( count,    file, line, func );
    }


    // set desired length, resulting capacity might become larger than count and initialize each element
    void length( size_t count, ref T initial, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        auto old_count = Count;
        length( count, file, line, func );
        foreach( ref d; data[ old_count .. count ] ) {
            d = initial;
        }
    }


    // index access
    ref inout( Val_T ) opIndex( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout {
    //ref T opIndex( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( i < Count, file, line, func, "Array out of bounds!" );
        return ptr()[ i ];
    }


    // Empty_Array opIndex can't return a reference but the array interface must be able to return
    // an element pointer. Hence we use this work around for empty arrays to silently retun a null pointer
    inout( Val_T )* ptr_at( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout  { return & opIndex( i, file, line, func ); }
    inout( Val_T )* ptr_back( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout { return & opIndex( length - 1, file, line, func ); }



    // convenience first and last element access
    ref T front()   { return ptr()[ 0 ]; }
    ref T back()    { return ptr()[ Count - 1 ]; }


    // disable concatenation
    @disable void opBinary( string op : "~" )( T   t ) {}
    @disable void opBinary( string op : "~" )( T[] t ) {}


    // customize appending single element
    void opOpAssign( string op : "~" )( T stuff ) {
        return append( stuff );
    }


    // customize appending slice of elements
    void opOpAssign( string op: "~" )( T[] stuff ) {
        return append( stuff );
    }


    // append single element, return the address of the appended element for further manipulation. We cannot return a reference to the resulting array entry!
    Val_T* append( S )( S stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( is( S : T )) {
        if( Capacity <= Count )
            reserve( growCapacity( Count + 1 ), file, line, func );
        Count += 1;
        data[ Count - 1 ] = stuff;
        return & data[ Count - 1 ];
    }


    // append slice of elements, return the append result for further manipulation
    Val_T[] append( S )( S[] stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( is( S : T )) {

        // we prepare the following vars in case of appending this to this
        auto stuff_length = stuff.length;

        // stuff might be part of the memory range of the Arena array
        // if we reallocate the memory of the array the stuff slice is points to garbage
        // in this case we must recreate the slice based on its relative offset of
        // the Arena's array data pointer before the reallocation
        auto stuff_ptr  = cast( size_t )stuff.ptr;
        auto stuff_end  = stuff_ptr + S.sizeof * stuff.length;
        auto source_ptr = cast( size_t )Arena.ptr;

        // figure out if the stuff is within the mem range of Arena and store the offset in stuff_ptr
        if( source_ptr <= stuff_ptr && stuff_end <= ( source_ptr + Arena.length ))
            stuff_ptr = stuff_ptr - source_ptr;

        auto old_count = Count;                     // cache the Count member, next operatin will update it
        length( Count + stuff.length, file, line, func );   // extend length possibly reserving memory

        // if stuff_ptr != stuff.ptr we know that we need to patch the stuff slice with stuff_ptr as offset
        if( stuff_ptr != cast( size_t )stuff.ptr )
            stuff = ( cast( S* )( cast( size_t )Arena.ptr + stuff_ptr ))[ 0 .. stuff.length ];

        ptr[ old_count .. Count ] = stuff;          // copy stuff
        return data[ old_count .. Count ];          // return slice with copied data
    }


    // compute new capacity
    private size_t growCapacity( size_t count ) {
        size_t capacity = Capacity > 0 ? ( Capacity + Capacity / 2 ) : 8;
        return capacity > count ? capacity : count;
    }


    // reserve memory
    void reserve( size_t capacity, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        if( capacity <= Capacity ) return;                              // return if we have more capacity than requested
        Size_T new_block_size = cast( Size_T )( capacity * T.sizeof );  // compute new block size

        // if our Link is at the end of the linked Link list, simply resize the length of the borrowing array, this might re-allocate
        if( Link.Next is null ) {
            Arena.length( Link.Offset + new_block_size, file, line, func );
            Link.Size = new_block_size;
        }

        // else check if there is some space left to the next Link ... for now!
        else {
            if( Link.Offset + new_block_size <= Link.Next.Offset ) {
                Link.Size = new_block_size;
            }   // Todo(pp): else figure out if there is enough room in between blocks, if so move data there, else move to the back
        }
    }


    // reset internal state
    void reset( T[] stuff = [], string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        reset( Arena, stuff, file, line, func );
    }

    // reset internal state
    void reset( ref Arena_T arena, T[] stuff = [], string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        reset( & arena, stuff, file, line, func );
    }

    // reset internal state
    void reset( Arena_T* arena, T[] stuff = [], string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        length( 0, file, line, func );
        Arena.detach( & Link );
        Arena = arena;
        Arena.attach( & Link );
        if( stuff.length > 0 ) append( stuff );
    }




    // duplicate the struct
    Block_Array dup( Arena_T* arena = null ) {
        auto duplicate = Block_Array( arena !is null ? *arena : *Arena, data );
        return duplicate;
        //T* new_data = cast( T* )malloc( Capacity * T.sizeof );
        //memcpy( new_data, Data, Capacity * T.sizeof );
        //return Block_Array( new_data, Count, Capacity );
    }


    // disable copying
    @disable this( this );
    //this( this ) {
    //    printf( "Postblit!\n" );
    //}


    // disable default constructor
    @disable this();


    // must have an array to borrow from
    this( ref Arena_T arena, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        Arena = & arena;
        Arena.attach( & Link );
    }


    // convenience constructors
    this( ref Arena_T arena, T   stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) { this( arena ); append( stuff ); }
    this( ref Arena_T arena, T[] stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) { this( arena ); append( stuff ); }


    // cannot be called from outside
    private this( Arena_T* arena, BLink_T* link, Size_T count ) {
        Arena           = arena;
        Link.Prev       = link.Prev;
        Link.Next       = link.Next;
        Link.Offset     = link.Offset;
        Link.Size       = link.Size;
        Count           = count;

        if( Link.Prev !is null )
            Link.Prev.Next = & Link;

        if( Link.Next !is null )
            Link.Next.Prev = & Link;

        /*
        // mark for not being detached from Arena
        link.Offset = link.Size = Size_T.max;

        // replace link in linked link list
        Arena.replace( link, & Link );
        */
    }


    Block_Array release() {
        return Block_Array( Arena, & Link, Count );
    }



    // free data on destruction
    ~this() {
        if( Link.Offset != Size_T.max && Link.Size != Size_T.max )
            Arena.detach( & Link );
    }
}

alias BArray = Block_Array;




/// Static array mimicking a dynamic one. Data ends up on stack, and can not be reallocated
/// the array has still a capacity and length of how many elements are in use
struct Static_Array( T, uint Capacity, ST = uint ) {
    nothrow @nogc:
    alias   Val_T   = T;
    alias   Size_T  = ST;
    private Val_T[ Capacity ]   Data;
    private Size_T Count        = 0;


    // borrowed references, don't store resulting slice!
    alias   data this;
    Val_T[] data()      { return Data[ 0 .. Count ]; }


    // set desired length, which must not be greater then the array capacity
    void length( size_t count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( count <= Capacity, file, line, func, "Memory not sufficient to set requested length!" );
        Count = cast( Size_T )count;
    }


    // properties
    Size_T  opDollar()  { return Count; }
    Size_T  capacity()  { return Capacity; }
    bool    empty()     { return Count == 0; }
    void    clear()     { Count = 0; }

    inout( Val_T )* ptr()       inout { return Count == 0 ? null : Data.ptr; }
    inout( Size_T ) length()    inout { return Count; }


    // index access
    ref inout( Val_T ) opIndex( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout {
        vkAssert( i < Count, "Array out of bounds!", file, line, func );
        return Data[ i ];
    }


    // Empty_Array opIndex can't return a reference but the array interface must be able to return
    // an element pointer. Hence we use this work around for empty arrays to silently retun a null pointer
    inout( Val_T )* ptr_at( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout  { return & opIndex( i, file, line, func ); }
    inout( Val_T )* ptr_back( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout { return & opIndex( length - 1, file, line, func ); }


    // convenience first and last element access
    inout @property ref inout( Val_T ) front()  { return Data[ 0 ]; }
    inout @property ref inout( Val_T ) back()   { return Data[ Count - 1 ]; }


    // disable concatenation
    @disable void opBinary( string op : "~" )( Val_T   stuff ) {}
    @disable void opBinary( string op : "~" )( Val_T[] stuff ) {}


    // customize appending single element
    void opOpAssign( string op : "~" )( Val_T stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return append( stuff, file, line, func );
    }


    // customize appending slice of elements
    void opOpAssign( string op: "~" )( Val_T[] stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        return append( stuff, file, line, func );
    }


    // append single element, return the appended element for further manipulation
    Val_T* append( S )( S stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( is( S : Val_T )) {
        vkAssert( Count < Capacity, file, line, func, "Memory not sufficient to append additional data!" );
        Data[ Count ] = stuff;
        Count += 1;
        return & Data[ $ - 1 ];
    }


    // append slice of elements, return the append result for further manipulation
    Val_T[] append( S )( S[] stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( is( S : Val_T )) {
        vkAssert( Count + stuff.length <= Capacity, file, line, func, "Memory not sufficient to append additional data!" );
        auto start = Count;
        Count += stuff.length;
        Data[ start .. Count ] = stuff[];
        return Data[ start .. Count ];
    }


    // micking Dynamic_Array.release, no
    Static_Array release() {
        auto result = this;
        length = 0;
        return result;
    }


    // convenience constructors
    this( Val_T   stuff ) { append( stuff ); }
    this( Val_T[] stuff ) { append( stuff ); }
}

alias SArray = Static_Array;



/// empty array has no data but functions same as Dynamic and static Arrays
/// it is useful in place where no data is required in meta structs
/// but when (dummy) methods are required for static validation
private struct Empty_Array( T, ST = uint ) {
    nothrow @nogc:
    alias   Val_T   = T;
    alias   Size_T  = ST;
    //T[] data() { return null[0..0]; }

    // set length, which must always be 1
    void length( size_t count, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
        vkAssert( count == 0, file, line, func, "One_Array.length can be set only to 0!" );
    }


    // properties
//  Size_T  length()    const { return 0; }
    Size_T  capacity()  const { return 0; }
//  Size_T  opDollar()  const { return 0; }
    bool    empty()     const { return true; }
//  Val_T*  ptr()       { return null; }
    void    clear()     {}


    inout( Val_T )* ptr()       inout { return null; }
    inout( Size_T ) length()    inout { return 0; }


    inout( Val_T ) opIndex( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout {
        vkAssert( false, file, line, func, "Empty_Array has no data!" );
        return T();
    }


    // Empty_Array opIndex can't return a reference but the array interface must be able to return
    // an element pointer. Hence we use this work around for empty arrays to silently retun a null pointer
    inout( Val_T )* ptr_at( size_t i, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout  { return null; }
    inout( Val_T )* ptr_back( string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) inout { return null; }

    //auto opSlice( size_t i, size_t j ) { return T[];}
    //inout @property inout( T ) front() { vkAssert( false, "Empty_Struct has no data!"; return T(); }
    //inout @property inout( T ) back()  { vkAssert( false, "Empty_Struct has no data!"; return T(); }


    // assert on single element append
    void append( S )( S stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( is( S : Val_T )) {
        vkAssert( false, file, line, func, "Empty_Array has no memory, no data can be appended or set!" );
    }


    // assert on multi element append
    void append( S )( S[] stuff, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) if( is( S : Val_T )) {
        vkAssert( false, file, line, func, "Empty_Array has no memory, no data can be appended or set!" );
    }
}

alias EArray = Empty_Array;



/// sized array overload forwarding to D_OR_S_ARRAY template
auto sizedArray( int max_length, T, ST = uint )( size_t length ) {
    alias   Size_T = ST;
    D_OR_S_ARRAY!( T, max_length ) array;
    static if( max_length > 0 )
        array.length = cast( Size_T )length;
    return array;
}






private void isDynamicArrayImpl(           T, ST )( Dynamic_Array!(      T, ST ) array ) {}
private void isArenaArrayImpl(             T, ST )( Arena_Array!(        T, ST ) array ) {}
private void isBlockArrayImpl(             T, ST )( Block_Array!(        T, ST ) array ) {}
private void isEmptyArrayImpl(             T, ST )( Empty_Array!(        T, ST ) array ) {}
private void isStaticArrayImpl( T, uint size, ST )( Static_Array!( T, size, ST ) array ) {}

template isDynamicArray(    A ) { enum isDynamicArray = is( typeof( isDynamicArrayImpl( A.init ))); }
template isArenaArray(      A ) { enum isArenaArray   = is( typeof( isArenaArrayImpl(   A.init ))); }
template isBlockArray(      A ) { enum isBlockArray   = is( typeof( isBlockArrayImpl(   A.init ))); }
template isEmptyArray(      A ) { enum isEmptyArray   = is( typeof( isEmptyArrayImpl(   A.init ))); }
template isStaticArray(     A ) { enum isStaticArray  = is( typeof( isStaticArrayImpl(  A.init ))); }

template isDataArray(       A ) { enum isDataArray    = isDynamicArray!A || isStaticArray!A || isBlockArray!A; }
template isSomeArray(       A ) { enum isSomeArray    = isDataArray!A || isEmptyArray!A; }


template isDynamicArray( A, E ) { enum isDynamicArray = isDynamicArray!A && is( A.Val_T == E ); }
template isArenaArray(   A, E ) { enum isArenaArray   = isArenaArray!A   && is( A.Val_T == E ); }
template isBlockArray(   A, E ) { enum isBlockArray   = isBlockArray!A   && is( A.Val_T == E ); }
template isEmptyArray(   A, E ) { enum isEmptyArray   = isEmptyArray!A   && is( A.Val_T == E ); }
template isStaticArray(  A, E ) { enum isStaticArray  = isStaticArray!A  && is( A.Val_T == E ); }

template isDataArray(    A, E ) { enum isDataArray    = isDataArray!A    && is( A.Val_T == E ); }
template isSomeArray(    A, E ) { enum isSomeArray    = isSomeArray!A    && is( A.Val_T == E ); }

import std.traits : isArray;
template isDataArrayOrSlice( A )    { enum isDataArrayOrSlice = isDataArray!( A )    || isArray!A; }
template isDataArrayOrSlice( A, E ) { enum isDataArrayOrSlice = isDataArray!( A, E ) || is( A : E[] ); }








/// template that creates a Dynamic, Static (mimicking dynamic), Empty, or DLang Static Array
template D_OR_S_ARRAY( T, int count, ST = uint ) {
    alias   Size_T  = ST;
    //pragma( msg, "File: ", __FILE__, " Line: ", __LINE__ );
         static if( count == int.max )  alias D_OR_S_ARRAY = DArray!( T, Size_T );              // resize-able, non-copyable array
    else static if( count == int.min )  alias D_OR_S_ARRAY = BArray!( T, Size_T );              // resize-able, non-copyable array, suballocating from memory arena
//  else static if( count == -1 )       alias D_OR_S_ARRAY = OArray!( T, Size_T );              // array with one element
    else static if( count >   0 )       alias D_OR_S_ARRAY = SArray!( T, count, Size_T );       // static array mimicking resize-able array
    else static if( count <   0 )       alias D_OR_S_ARRAY = T[ - count ];                      // static array
    else                                alias D_OR_S_ARRAY = EArray!( T, Size_T );              // array with no element/memory
}



auto sizedArray( T )( size_t size, string file = __FILE__, size_t line = __LINE__, string func = __FUNCTION__ ) {
    DArray!T array;
    T initial = T.init;
    array.length( size, initial, file, line, func );
    return array;
}
