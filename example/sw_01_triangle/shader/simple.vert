#version 450

layout( std140, binding = 0 ) uniform uboViewer {
    mat4 WVPM;                                  // World View Projection Matrix 
};

layout( location = 0 ) in  vec4 ia_position;    // input assembly/attributes, we passed in two vec3
layout( location = 1 ) in  vec4 ia_color;       // they are filled automatically with 1 at the end to fit a vec4

layout( location = 0 ) out vec4 vs_color;       // vertex shader output vertex color, will be interpolated and rasterized 

out gl_PerVertex {                              // not redifining gl_PerVertex used to create a layer validation error
    vec4 gl_Position;                           // not having clip and cull distance features enabled
};                                              // error seems to have vanished by now, but it does no harm to keep this redefinition

void main() {
    vs_color    = ia_color;
    gl_Position = WVPM * ia_position;
}