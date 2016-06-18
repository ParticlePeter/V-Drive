#version 400
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable

layout( std140, binding = 0 ) uniform uboViewer {
	mat4 WVPM;
};

layout( location = 0 ) in vec4 inPosition;

void main() {
	gl_Position = WVPM * inPosition;
}