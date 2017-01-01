#version 450


layout( std140, binding = 0 ) uniform uboViewer {
	mat4 WVPM;
};


layout( location = 0 ) in vec4 inPosition;


out gl_PerVertex {
	vec4 gl_Position;
};


void main() {
	gl_Position = WVPM * inPosition;
}