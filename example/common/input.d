//module input;

import dlsl.trackball;
import bindbc.glfw;

import appstate;


void registerCallbacks( GLFWwindow* window, void* user_pointer = null ) {
    glfwSetWindowUserPointer( window, user_pointer );
    glfwSetWindowSizeCallback( window, &windowSizeCallback );
    glfwSetMouseButtonCallback( window, &mouseButtonCallback );
    glfwSetCursorPosCallback( window, &cursorPosCallback );
    glfwSetKeyCallback( window, &keyCallback );
}


struct TrackballButton {
    Trackball tbb;
    alias tbb this;
    ubyte button;
}


auto ref initTrackball(
    ref     App_State app,
    float   perspective_fovy    = 60,
    float   window_height       = 1080,
    float   cam_pos_x           =  3,
    float   cam_pos_y           =  3,
    float   cam_pos_z           = -6,
    float   cam_target_x        =  0,
    float   cam_target_y        =  0,
    float   cam_target_z        =  0,
    ) {
    home_pos_x = cam_pos_x;
    home_pos_y = cam_pos_y;
    home_pos_z = cam_pos_z;
    home_trg_x = cam_target_x;
    home_trg_y = cam_target_y;
    home_trg_z = cam_target_z;

    app.tbb.camHome;
    app.tbb.perspectiveFovyWindowHeight( perspective_fovy, window_height );
    app.window.registerCallbacks( &app );
    return app;
}



/// private utility to get and access VDrive_State from GLFWwindow user data
private App_State * getApp( GLFWwindow * window ) nothrow {
    return cast( App_State* )window.glfwGetWindowUserPointer;
}



/// Callback Function for capturing window resize events
extern( C ) void windowSizeCallback( GLFWwindow * window, int w, int h ) nothrow {
    // the extent might change at swapchain creation when the specified extent is not usable
    auto app = window.getApp;
    app.swapchainExtent( w, h );
    app.window_resized = true;
}


/// Callback Function for capturing mouse motion events
extern( C ) void cursorPosCallback( GLFWwindow * window, double x, double y ) nothrow {
    auto app = window.getApp;
    switch( app.tbb.button ) {
        case 1  : app.tbb.orbit( x, y ); app.updateWVPM; break;
        case 2  : app.tbb.xform( x, y ); app.updateWVPM; break;
        case 4  : app.tbb.dolly( x, y ); app.updateWVPM; break;
        case 5  : app.tbb.scale( x, y ); app.updateWVPM; break;
        default : break;
    }
}


/// Callback Function for capturing mouse motion events
extern( C ) void mouseButtonCallback( GLFWwindow * window, int key, int val, int mod ) nothrow {
    auto app = window.getApp;
    // compute mouse button bittfield flags
    switch( key ) {
        case 0  : app.tbb.button += 2 * val - 1; break;
        case 1  : app.tbb.button += 8 * val - 4; break;
        case 2  : app.tbb.button += 4 * val - 2; break;
        default : app.tbb.button  = 0;
    }

    if( app.tbb.button == 0 ) return;

    // set trackball reference if any mouse button is pressed
    double xpos, ypos;
    glfwGetCursorPos( window, &xpos, &ypos );
    app.tbb.reference( xpos, ypos );
}


/// Callback Function for capturing mouse wheel events
extern( C ) void scrollCallback( GLFWwindow * window, double x, double y ) nothrow {

}


/// Callback Function for capturing keyboard events
extern( C ) void keyCallback( GLFWwindow * window, int key, int scancode, int val, int mod ) nothrow {
    auto app = window.getApp;
    if( val != GLFW_PRESS ) return;
    switch( key ) {
        case GLFW_KEY_ESCAPE    : glfwSetWindowShouldClose( window, GLFW_TRUE ); break;
        case GLFW_KEY_HOME      : app.tbb.camHome; break;
        case GLFW_KEY_KP_ENTER  : if( mod == GLFW_MOD_ALT ) window.toggleFullscreen; break;
        default                 : break;
    }
}


private:
float home_pos_x, home_pos_y, home_pos_z;   // camera home position, defined when initializing the trackball
float home_trg_x, home_trg_y, home_trg_z;   // camera home target, same as above

bool fb_fullscreen = false;                 // keep track if we are in fullscreen mode
int win_x, win_y, win_w, win_h;             // remember position and size of window when switching to fullscreen mode

// set camera back to its initial state
void camHome( ref TrackballButton tbb ) nothrow @nogc {
    tbb.lookAt( home_pos_x, home_pos_y, home_pos_z, home_trg_x, home_trg_y, home_trg_z );
}

// toggle fullscreen state of window
void toggleFullscreen( GLFWwindow * window ) nothrow @nogc {
    if( fb_fullscreen ) {
        fb_fullscreen = false;
        glfwSetWindowMonitor( window, null, win_x, win_y, win_w, win_h, GLFW_DONT_CARE );
    } else {
        fb_fullscreen = true;
        glfwGetWindowPos(  window, &win_x, &win_y );
        glfwGetWindowSize( window, &win_w, &win_h );
        auto monitor = glfwGetPrimaryMonitor();
        auto vidmode = glfwGetVideoMode( monitor );
        glfwSetWindowMonitor( window, glfwGetPrimaryMonitor(), 0, 0, vidmode.width, vidmode.height, vidmode.refreshRate );
    }
}