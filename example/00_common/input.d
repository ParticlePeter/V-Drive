//module input;

import dlsl.vector;
import dlsl.trackball;
import derelict.glfw3.glfw3;

import appstruct;

private VDriveState* vd;

void registerCallbacks( GLFWwindow* window, void* user_pointer = null ) {
	vd = cast( VDriveState* )user_pointer;
	glfwSetWindowUserPointer( window, user_pointer );
	glfwSetWindowSizeCallback( window, &windowSizeCallback );
	glfwSetMouseButtonCallback( window, &mouseButtonCallback );
	glfwSetCursorPosCallback( window, &cursorPosCallback );
	//glfwSetScrollCallback( window, &scrollCallback );
	glfwSetKeyCallback( window, &keyCallback );	
}


struct TrackballButton {
	Trackball tb;
	alias tb this;
	ubyte button;
}


auto ref initTrackball( ref VDriveState vd ) {
	vd.tb.lookAt( 6, 3, -6 );
	vd.tb.height_and_focus_from_fovy( 480, 60 );
	vd.tb.xformVelocity = 12;
	vd.tb.dollyVelocity = 12;
	registerCallbacks( vd.window, &vd );
}


/// Callback Function for capturing window resize events
extern( C ) void windowSizeCallback( GLFWwindow * window, int w, int h ) nothrow  {
	vd.window_resized = true;
}


/// Callback Function for capturing mouse motion events
extern( C ) void cursorPosCallback( GLFWwindow * window, double x, double y ) nothrow  {
	if( vd.tb.button == 0 ) return;
	switch( vd.tb.button )  {
		case 1	: vd.tb.orbit( x, y ); break;
		case 2	: vd.tb.xform( x, y ); break;
		case 4	: vd.tb.dolly( x, y ); break;
		default	: break;
	}
}


/// Callback Function for capturing mouse motion events
extern( C ) void mouseButtonCallback( GLFWwindow * window, int key, int val, int mod ) nothrow  {
	// compute mouse button bittfield flags
	switch( key )  {
		case 0	: vd.tb.button += 2 * val - 1; break;
		case 1	: vd.tb.button += 8 * val - 4; break;
		case 2	: vd.tb.button += 4 * val - 2; break;
		default	: vd.tb.button  = 0;
	}

	if( vd.tb.button == 0 ) return;

	// set trackball reference if any mouse button is pressed
	double xpos, ypos;
	glfwGetCursorPos( window, &xpos, &ypos );
	vd.tb.reference( xpos, ypos );
}


/// Callback Function for capturing mouse wheel events
extern( C ) void scrollCallback( GLFWwindow * window, double x, double y ) nothrow  {

}


/// Callback Function for capturing keyboard events
extern( C ) void keyCallback( GLFWwindow * window, int key, int scancode, int val, int mod ) nothrow  {
	if( val != GLFW_PRESS ) return;
	switch( key ) {
		case GLFW_KEY_ESCAPE: glfwSetWindowShouldClose( window, GLFW_TRUE ); break;
		case GLFW_KEY_SPACE	: vd.tb.lookAt( vec3( 0, 0, 10 )); break;
		default				: break;
	}
}


