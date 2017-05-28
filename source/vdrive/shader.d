module vdrive.shader;

import erupted;

import vdrive.util;
import vdrive.state;

import core.stdc.stdio : printf;





/// create a VkShaderModule from either a vulkan acceptable glsl text file or binary spir-v file
/// glsl text file is only acceptable if glslangValidator is somewhere in the system path
/// the text file will then be compiled into spir-v binary and loaded
/// detection of spir-v is based on .spv extension
/// if the entered path is not a .spv file the procedure will convert the path, attach .spv
/// and check if this file exists. If it does it will be used
/// Params:
///     vk = reference to a VulkanState struct
///     path = the path to glsl or spir-v file
/// Returns: VkShaderModule
auto createShaderModule(
    ref Vulkan  vk,
    string      path,
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) {
    import std.file : exists;
    import std.path : extension;
    string ext = path.extension;
    if( ext != ".spv" ) {

        // convert to std.container.array!char
        auto path_z = path.toStringz;                           // this adds '\0' as last value and must be compensated in index calculations
        path_z[ $ - ext.length - 1 ] = '_';                     // substitute the . of .ext with _ to _ext

        // append new extension .spv
        string spv = ".spv";                                    // string with extension for memcpy
        path_z.length = path_z.length + spv.length;				// resize the path_z array with the length of the new extension
        path_z[ $-1 ] = '\0';                                   // set the last value to a terminating character
        import core.stdc.string : memcpy;                       // import and use memcopy to copy into the char array
        memcpy( &path_z.data[ $ - spv.length - 1 ], spv.ptr, spv.length );

        string spir_path = path_z.data.idup;                    // create string from the char array

        // assert that either the original or the newly composed path exist
        bool path_exists = path.exists;                         // check if the original file exists
        bool spir_up_to_date = spir_path.exists;                // check if the spir file exists, if not we will compile it
        vkAssert( path_exists || spir_up_to_date,
            "Neither path to glsl code nor path to corresponding spv exist: ",
            file, line, func, path_z.ptr );

        if( path_exists && spir_up_to_date ) {                  // if both files exists, check if the spir-v is up to date with the glsl source
            import std.file : getTimes;                         // need to get the modification times of the files
            import std.datetime : SysTime;                      // stored in comparable SysTimes
            SysTime access_time, glsl_mod_time, spir_mod_time;  // access times are irrelevant
            spir_path.getTimes( access_time, spir_mod_time );   // get spir-v file times (.spv)
            path.getTimes( access_time, glsl_mod_time );        // get glsl file times
            spir_up_to_date = glsl_mod_time < spir_mod_time;    // set the spir_up_to_date value if glsl is newer than spir-v
        }

        if( !spir_up_to_date ) { // not using 'else', as spir_up_to_date might have changed in the if clause above
            import std.process : execute;                       // use process execute to call glslangValidator
            string[6] compile_glsl_args = [ "glslangValidator", "-V", "-w", "-o", spir_path, path ];
            auto compile_glsl = compile_glsl_args.execute;      // store in status struct
            printf( compile_glsl.output.ptr );                  // print output
        }
        path = spir_path;                                       // create string from the composed char array
    }

    // assert that the passed in or freshly compiled spir-v file exist
    auto path_z = path.toStringz;
    vkAssert( path.exists,
        "Path to Spir-V does not exist: ",
        file, line, func, path_z.ptr );

    import std.stdio : File;
    auto shader_file = File( path );
    auto read_buffer = sizedArray!char( cast( size_t )shader_file.size );
    auto code = shader_file.rawRead( read_buffer.data );

    VkShaderModuleCreateInfo shader_module_create_info = {
        codeSize    : cast( uint32_t  )code.length,
        pCode       : cast( uint32_t* )code.ptr,
    };

    VkShaderModule shader_module;
    vk.device.vkCreateShaderModule( &shader_module_create_info, vk.allocator, &shader_module ).vkAssert( "Shader Module", file, line, func );

    return shader_module;
}


/// create a VkPipelineShaderStageCreateInfo acceptable for a pipeline state object (PSO)
/// Params:
///     vk = reference to a VulkanState struct
///     shader_stage = enum to specify the shader stage
///     shader_module = the VkShaderModule to be converted
///     shader_entry_point = optionally set a different name for your "main" entry point,
///                         this is also required if the passed in shader_module has
///                         multiple entry points ( e.g. shader stages )
///     specialization_info = optionally set a VkSpecializationInfo for the shader module
/// Returns: VkPipelineShaderStageCreateInfo
auto createPipelineShaderStage(
    ref Vulkan                      vk,
    VkShaderStageFlagBits           shader_stage,
    VkShaderModule                  shader_module,
    const( VkSpecializationInfo )*  specialization_info = null,
    const( char )*                  shader_entry_point = "main"
    ) {
    VkPipelineShaderStageCreateInfo shader_stage_create_info = {
        stage               : shader_stage,
        _module             : shader_module,
        pName               : shader_entry_point,        // shader entry point function name
        pSpecializationInfo : specialization_info,
    };

    return shader_stage_create_info;
}


/// create a VkPipelineShaderStageCreateInfo acceptable for a pipeline state opbject (PSO)
/// takes a path to a vulkan acceptable glsl text file or spir-v binary file conveniently
/// instead of a VkShaderModule. Detection of spir-v is based on .spv extension
/// Params:
///     vk = reference to a VulkanState struct
///     shader_stage = enum to specify the shader stage
///     shader_path = path to glsl text or spir-v binary
///     shader_entry_point = optionally set a different name for your "main" entry point,
///                         this is also required if the passed in shader_module has
///                         multiple entry points ( e.g. shader stages )
///     specialization_info = optionally set a VkSpecializationInfo for the shader module
/// Returns: VkPipelineShaderStageCreateInfo
auto createPipelineShaderStage(
    ref Vulkan vk,
    VkShaderStageFlagBits shader_stage,
    string shader_path,
    const( VkSpecializationInfo )* specialization_info = null,
    const( char )* shader_entry_point = "main"
    ) {
    return createPipelineShaderStage(
        vk, shader_stage, vk.createShaderModule( shader_path ), specialization_info, shader_entry_point
    );
}


import vdrive.util;
union  MapEntry32 {
    uint32_t u = 0;
    int32_t  i;
    float    f;
    this( uint32_t u ) { this.u = u; }
    this( int32_t  i ) { this.i = i; }
    this( float    f ) { this.f = f; }

    static MapEntry32 max() { return MapEntry32( uint32_t.max ); }
}


struct Meta_SC( uint32_t specialization_count ) {
    alias sc_count = specialization_count;
    VkSpecializationInfo specialization_info;

    D_OR_S_ARRAY!( sc_count, VkSpecializationMapEntry ) specialization_map_entries;
    D_OR_S_ARRAY!( sc_count, MapEntry32 )               specialization_data;

    void reset() {
       specialization_map_entries.clear;
       specialization_data.clear; 
    }
}


alias Meta_Specialization = Meta_SC!( uint32_t.max );

private template isMetaSC( T )  {  enum isMetaSC = is( typeof( isMetaSCImpl( T.init ))); }
private void isMetaSCImpl( uint sc_count )( Meta_SC!( sc_count ) meta ) {}


// add a simple 4 specialization constant map entry of type uint32_t, int32_t or float
// VkSpecializationMapEntry offset is deduced from constants added so far and size is 4 bytes
auto ref addMapEntry( META_SC )(
    ref META_SC     meta,
    MapEntry32      data = MapEntry32.max,
    uint32_t        constantID = uint32_t.max
    ) if(  isMetaSC!META_SC ) {

    if( constantID == uint32_t.max )
        constantID = meta.specialization_map_entries.length
            ? meta.specialization_map_entries[ $-1 ].constantID + 1 : 0;

    return meta.addMapEntry(
        VkSpecializationMapEntry(
            constantID,
            ( meta.specialization_data.length * MapEntry32.sizeof ).toUint,
            MapEntry32.sizeof ),
        data );
}

// add custom VkSpecializationMapEntry describing more advanced layot in terms of offset and size
// data for the constants can than be passed into construct function
// a simple map entry can still be supplied, but then it should be supplied with each call
// to this particular meta struct, and no data be specified with construct function
auto ref addMapEntry( META_SC )(
    ref META_SC                 meta,
    VkSpecializationMapEntry    specialization_map_entry,
    MapEntry32                  map_entry = MapEntry32.max
    ) if( isMetaSC!META_SC ) {

    meta.specialization_map_entries.append( specialization_map_entry );
    if( map_entry.u < uint32_t.max ) meta.specialization_data.append( map_entry );
    return meta;
}

// construct the specialization constants with either internal data
// or optionally with external data passed in as void[] array
auto ref construct( META_SC )(
    ref META_SC     meta,
    void[]          specialization_constants = []
    ) if(  isMetaSC!META_SC ) {

    uint32_t data_size  = ( specialization_constants == []
        ? meta.specialization_data.length * MapEntry32.sizeof
        : specialization_constants.length ).toUint;

    const( void )* p_data = specialization_constants == []
        ? meta.specialization_data.ptr
        : specialization_constants.ptr;

    with( meta.specialization_info ) {
        mapEntryCount   = meta.specialization_map_entries.length.toUint;
        pMapEntries     = meta.specialization_map_entries.ptr;
        dataSize        = data_size;
        pData           = p_data;
    }
}