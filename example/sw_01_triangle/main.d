/*
* Vulkan Example - Basic non-indexed triangle rendering
*
* Note:
*   This is a "pedal to the metal" example to show off how to get Vulkan up an displaying something
*   It strongly relies on the concepts and abstractions of the V-Drive api
*   However, in these example only basic features are used, heavier once will be introduced in later examples
*
* Example Structure:
*   appstate    : the struct VDrive_State holds the state of the application, vulkan non- and related data
*   triangle    : initializes all the required Vulkan non- and related data
*   main        : this module has the render loop and polls glfw events
*
* Common Structure ( to all examples, can be overridden on per example basis ):
*   initialize  : initialize glfw, window, vulkan instance, device and queue(s)
*   input       : setup glfw callbacks
*
* Navigation and keys:
*   LMB + mouse move    : orbit around camera target
*   MMB + mouse move    : pan the camera, speed is dependent on camera to target distance
*   RMB + mouse u/d     : fast dolly ( camera move towards its target )
*   RMB + mouse r/l     : slow dolly
*   ALT + KP Enter      : toggle fullscreen
*   Home Key            : return to initial camera state
*   Escape              : exit example
*
* Build and Run:
*   library and examples work only on x64 architecture due to dlang VK_NULL_HANDLE issue
*   dub run vdrive:triangle --arch x86_64
*
* Copyright (C) 2017 by Peter Particle, inspired by Sascha Willems Vulkan examples - www.saschawillems.de
*
* This code is licensed under the MIT license (MIT) (http://opensource.org/licenses/MIT)
*/

module main;

import input;
import appstate;
import triangle;
import initialize;

import derelict.glfw3;

import core.stdc.stdio : printf, sprintf;

int main() {

    printf( "\n" );

    // create the state object
    VDrive_State vd;                                                    // VDrive state struct
    auto vkResult = vd.initVulkan( 1600, 900 );                         // initialize instance and (physical) device
    if( vkResult ) return vkResult;                                     // exit if initialization failed, VK_SUCCESS = 0
    vd.initTrackball( vd.projection_fovy, vd.windowHeight, 0, 0, 4 );   // initialize the trackball with fov(y), win_height, cam_pos(x,y,z)
    vd.createResources;                                                 // create all required vulkan resources


    // vars to compute fps and display in title
    char[32] title;
    uint frame_count;
    double last_time = glfwGetTime();
    while( !glfwWindowShouldClose( vd.window )) {

        // compute fps
        ++frame_count;
        double delta_time = glfwGetTime() - last_time;
        if( delta_time >= 1.0 ) {
            sprintf( title.ptr, "Vulkan Erupted, FPS: %.2f", frame_count / delta_time );    // frames per second
            //sprintf( title.ptr, "Vulkan Erupted, FPS: %.2f", 1000.0 / frame_count );        // milli seconds per frame
            glfwSetWindowTitle( vd.window, title.ptr );
            last_time += delta_time;
            frame_count = 0;
        }

        // draw
        vd.draw();
        glfwSwapBuffers( vd.window );

        // poll events in remaining frame time
        glfwPollEvents();
        if( vd.tb.dirty )
            vd.updateWVPM;
    }

    // drain work and destroy vulkan
    vd.destroyResources;
    vd.destroyVulkan;

    printf( "\n" );
    return 0;
}

