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
///     shader_path = the path to glsl or spir-v file
/// Returns: VkShaderModule
auto createShaderModule(
    ref Vulkan  vk,
    string      shader_path,            // Todo(pp): turn this into a const( char )*
    string      file = __FILE__,
    size_t      line = __LINE__,
    string      func = __FUNCTION__
    ) {
    import std.file : exists;
    import std.path : extension;
    string ext = shader_path.extension;         // get extension of path argument, must compile non .spv extension files
    auto shader_path_z = shader_path.toStringz; // convert to std.container.array!char, this adds '\0' as last value and must be compensated in index calculations

    if( ext != ".spv" ) {

        shader_path_z[ $ - ext.length - 1 ] = '_';                  // substitute the . of .ext with _ to _ext

        // append new extension .spv
        string spv = ".spv";                                        // string with extension for memcpy, spv.length = 4
        shader_path_z.length = shader_path_z.length + spv.length;   // resize the shader_path_z array with the length of the new extension
        shader_path_z[ $-1 ] = '\0';                                // set the last value to a terminating character, required for propper vkAssert
        import core.stdc.string : memcpy;                           // import and use memcopy to copy into the char array
        memcpy( &shader_path_z.data[ $ - 5 ], spv.ptr, 4 );         // copy the .spv extension at [ $ - spv.length - "\0".length ] = [ $ - 4 - 1 ]
        string spir_path = shader_path_z.data[ 0 .. $-1 ].idup;     // create string from the char array

        // assert that either the original or the newly composed path exist
        bool glsl_path_exists = shader_path.exists;                 // check if the original file, which must be a glsl file, exists
        bool spir_up_to_date = spir_path.exists;                    // check if the spir file exists, if not we will compile it
        vkAssert( glsl_path_exists || spir_up_to_date,
            "Neither path to glsl code nor path to corresponding spv exist: ",
            file, line, func, shader_path_z.ptr );

        if( glsl_path_exists && spir_up_to_date ) {                 // if both files exists, check if the spir-v is up to date with the glsl source
            import std.file : getTimes;                             // need to get the modification times of the files
            import std.datetime : SysTime;                          // stored in comparable SysTimes
            SysTime access_time, glsl_mod_time, spir_mod_time;      // access times are irrelevant
            spir_path.getTimes( access_time, spir_mod_time );       // get spir-v file times (.spv)
            shader_path.getTimes( access_time, glsl_mod_time );     // get glsl file times
            spir_up_to_date = glsl_mod_time < spir_mod_time;        // set the spir_up_to_date value if glsl is newer than spir-v
        }

        if( !spir_up_to_date ) { // not using 'else', as spir_up_to_date might have changed in the if clause above
            import std.process : execute;                           // use process execute to call glslangValidator
            string[6] compile_glsl_args = [ "glslangValidator", "-V", "-w", "-o", spir_path, shader_path ];
            auto compile_glsl = compile_glsl_args.execute;          // store in status struct
            vkAssert( compile_glsl.status == 0,                     // assert that compilation went right, othervise include compilation error into assert message
                "SPIR-V is not generated for failed compile or link : ",
                file, line, func, compile_glsl.output.ptr
            );
            auto output_z = compile_glsl.output.toStringz;
            printf( "Compiled: %s", output_z.ptr );                 // print output to signal that a shader has been (re)compiled
        }
        shader_path = spir_path;                                    // overwrite the string path parameter with the composed char array back into
    }

    // assert that the passed in or freshly compiled spir-v file exist
    vkAssert( shader_path.exists,
        "Path to Spir-V does not exist: ",
        file, line, func, shader_path_z.ptr );

    import std.stdio : File;
    auto shader_file = File( shader_path );
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
    ref Vulkan                      vk,
    VkShaderStageFlagBits           shader_stage,
    string                          shader_path,
    const( VkSpecializationInfo )*  specialization_info = null,
    const( char )*                  shader_entry_point = "main",
    string                          file = __FILE__,
    size_t                          line = __LINE__,
    string                          func = __FUNCTION__
    ) {
    return createPipelineShaderStage(
        vk, shader_stage, vk.createShaderModule( shader_path, file, line, func ), specialization_info, shader_entry_point
    );
}


/// create a VkPipelineShaderStageCreateInfo acceptable for a pipeline state opbject (PSO)
/// takes a path to a vulkan acceptable glsl text file or spir-v binary file conveniently
/// instead of a VkShaderModule. Detection of spir-v is based on .spv extension
/// the shader stage is deduced from passed in file extension
/// file extension must be one of the default shader stage extensions expected by glsLangvalidator
/// Params:
///     vk = reference to a VulkanState struct
///     shader_path = path to glsl text or spir-v binary
///     shader_entry_point = optionally set a different name for your "main" entry point,
///                         this is also required if the passed in shader_module has
///                         multiple entry points ( e.g. shader stages )
///     specialization_info = optionally set a VkSpecializationInfo for the shader module
/// Returns: VkPipelineShaderStageCreateInfo
auto createPipelineShaderStage(
    ref Vulkan                      vk,
    string                          shader_path,
    const( VkSpecializationInfo )*  specialization_info = null,
    const( char )*                  shader_entry_point = "main",
    string                          file = __FILE__,
    size_t                          line = __LINE__,
    string                          func = __FUNCTION__
    ) {
    import std.path : extension;
    string ext = shader_path.extension;        // get extension of path argument
    vkAssert( ext != ".spv",
        "This overload of createPiplineShaderStage cannot be used with binary Spir-V, as the shader stage cannot be deduced",
        file, line, func );

    // deduce the pipeline shader stage from file extension
    VkShaderStageFlagBits shader_stage = VK_SHADER_STAGE_ALL;
    switch( ext ) {
        case ".vert" : shader_stage = VK_SHADER_STAGE_VERTEX_BIT; break;
        case ".tesc" : shader_stage = VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT; break;
        case ".tese" : shader_stage = VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT; break;
        case ".geom" : shader_stage = VK_SHADER_STAGE_GEOMETRY_BIT; break;
        case ".frag" : shader_stage = VK_SHADER_STAGE_FRAGMENT_BIT; break;
        case ".comp" : shader_stage = VK_SHADER_STAGE_COMPUTE_BIT; break;
        default :
        char[128] buffer;
        buffer[ 0 .. ext.length ] = ext;                                            // the following message is exactly 80 characters long including new line at start and \0 at end
        buffer[ ext.length .. ext.length + 80 ] = "
               Accepted Extensions  : .vert, .tesc, .tese, .geom, .frag, .comp\0";  // new line character is automatically added at the beginning of this message
        vkAssert( false, "Unknown Extension    : ", file, line, func, buffer.ptr );
    }
    return createPipelineShaderStage(
        vk, shader_stage, vk.createShaderModule( shader_path, file, line, func ), specialization_info, shader_entry_point
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



alias Meta_Specialization = Meta_Specialization_T!( int32_t.max );


// Todo(pp): This struct currently works only in conjunction with MapEntry32
// to be able to use it with any specialization data structure, of witch
// the size is unknown in advance (each entry can have a different size) we need to:
// - change the type of specialization_data member to byte
// - change the first addMapEntry overloads first argument to a template argument
// - compute its size in bytes and append the bytes to our byte array
struct Meta_Specialization_T( int32_t specialization_count ) {
    alias sz_count = specialization_count;
    VkSpecializationInfo specialization_info;

    D_OR_S_ARRAY!( sz_count, VkSpecializationMapEntry ) specialization_map_entries;
    D_OR_S_ARRAY!( sz_count, MapEntry32 )               specialization_data;

    void reset() {
       specialization_map_entries.clear;
       specialization_data.clear;
    }


    // add a simple 4 specialization constant map entry of type uint32_t, int32_t or float
    // VkSpecializationMapEntry offset is deduced from constants added so far and size is 4 bytes
    auto ref addMapEntry( MapEntry32 data = MapEntry32.max, uint32_t constantID = uint32_t.max ) {

        if( constantID == uint32_t.max )
            constantID = specialization_map_entries.length
                ? specialization_map_entries[ $-1 ].constantID + 1 : 0;

        return addMapEntry( VkSpecializationMapEntry(
            constantID, toUint( specialization_data.length * MapEntry32.sizeof ), MapEntry32.sizeof ), data );
    }


    // add custom VkSpecializationMapEntry describing more advanced layout in terms of offset and size
    // data for the constants can than be passed into construct function
    // a simple map entry can still be supplied, but then it should be supplied with each call
    // to this particular meta struct, and no data be specified with construct function
    auto ref addMapEntry( VkSpecializationMapEntry specialization_map_entry, MapEntry32 map_entry = MapEntry32.max ) {
        specialization_map_entries.append( specialization_map_entry );
        if( map_entry.u < uint32_t.max ) specialization_data.append( map_entry );
        return this;
    }


    // construct the specialization constants with either internal data
    // or optionally with external data passed in as void[] array
    auto ref construct() {
        with( specialization_info ) {
            mapEntryCount   = specialization_map_entries.length.toUint;
            pMapEntries     = specialization_map_entries.ptr;
            dataSize        = toUint( specialization_data.length * MapEntry32.sizeof );
            pData           = specialization_data.ptr;
        } return this;
    }


    // construct the specialization constants with either internal data
    // or optionally with external data passed in as void[] array
    auto ref construct( void[] specialization_constants ) {
        with( specialization_info ) {
            mapEntryCount   = specialization_map_entries.length.toUint;
            pMapEntries     = specialization_map_entries.ptr;
            dataSize        = specialization_constants.length.toUint;
            pData           = specialization_constants.ptr;
        } return this;
    }
}
