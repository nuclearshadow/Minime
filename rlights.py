"""
/**********************************************************************************************
*
*   raylib.lights - Some useful functions to deal with lights data
*
*   CONFIGURATION:
*
*   #define RLIGHTS_IMPLEMENTATION
*       Generates the implementation of the library into the included file.
*       If not defined, the library is in header only mode and can be included in other headers 
*       or source files without problems. But only ONE file should hold the implementation.
*
*   LICENSE: zlib/libpng
*
*   Copyright (c) 2017-2023 Victor Fisac (@victorfisac) and Ramon Santamaria (@raysan5)
*
*   This software is provided "as-is", without any express or implied warranty. In no event
*   will the authors be held liable for any damages arising from the use of this software.
*
*   Permission is granted to anyone to use this software for any purpose, including commercial
*   applications, and to alter it and redistribute it freely, subject to the following restrictions:
*
*     1. The origin of this software must not be misrepresented; you must not claim that you
*     wrote the original software. If you use this software in a product, an acknowledgment
*     in the product documentation would be appreciated but is not required.
*
*     2. Altered source versions must be plainly marked as such, and must not be misrepresented
*     as being the original software.
*
*     3. This notice may not be removed or altered from any source distribution.
*
**********************************************************************************************/
"""
import raylibpy as rl
import struct

#----------------------------------------------------------------------------------
# Defines and Macros
#----------------------------------------------------------------------------------
MAX_LIGHTS = 4         # Max dynamic lights supported by shader

#----------------------------------------------------------------------------------
# Types and Structures Definition
#----------------------------------------------------------------------------------

# Light data
class Light:
    def __init__(
        self,
        type: int = None,
        enabled: bool = None,
        position: rl.Vector3 = None,
        target: rl.Vector3 = None,
        color: rl.Color = None,
        attenuation: float = None,
        enabledLoc: int = None,
        typeLoc: int = None,
        positionLoc: int = None,
        targetLoc: int = None,
        colorLoc: int = None,
        attenuationLoc: int = None,
    ):
        self.type = type or 0
        self.enabled = enabled or True
        self.position = position or rl.Vector3(0, 0, 0)
        self.target = target or rl.Vector3(0, 0, 0)
        self.color = color or rl.WHITE
        self.attenuation = attenuation or 0
        self.enabledLoc = enabledLoc or -1
        self.typeLoc = typeLoc or -1
        self.positionLoc = positionLoc or -1
        self.targetLoc = targetLoc or -1
        self.colorLoc = colorLoc or -1
        self.attenuationLoc = attenuationLoc or -1

# Light type
LIGHT_DIRECTIONAL = 0
LIGHT_POINT = 1

#----------------------------------------------------------------------------------
# Module Functions Declaration
#----------------------------------------------------------------------------------
# Light CreateLight(int type, rl.Vector3 position, rl.Vector3 target, Color color, rl.Shader shader);   // Create a light and get shader locations
# void UpdateLightValues(rl.Shader shader, Light light);         // Send light properties to shader

"""
/***********************************************************************************
*
*   RLIGHTS IMPLEMENTATION
*
************************************************************************************/
"""

lightsCount = 0    # Current amount of created lights

# Create a light and get shader locations
def create_light(type: int, position: rl.Vector3, target: rl.Vector3, color: rl.Color, shader: rl.Shader) -> Light:
    global lightsCount
    light = Light()

    if lightsCount < MAX_LIGHTS:
        light.enabled = True
        light.type = type
        light.position = position
        light.target = target
        light.color = color

        # NOTE: Lighting shader naming must be the provided ones
        light.enabledLoc = rl.get_shader_location(shader, ("lights[%i].enabled" % lightsCount))
        light.typeLoc = rl.get_shader_location(shader, ("lights[%i].type" % lightsCount))
        light.positionLoc = rl.get_shader_location(shader, ("lights[%i].position" % lightsCount))
        light.targetLoc = rl.get_shader_location(shader, ("lights[%i].target" % lightsCount))
        light.colorLoc = rl.get_shader_location(shader, ("lights[%i].color" % lightsCount))

        update_light_values(shader, light)
        
        lightsCount += 1

    return light

# Send light properties to shader
# NOTE: Light shader locations should be available 
def update_light_values(shader: rl.Shader , light: Light):
    # Send to shader light enabled state and type
    rl.set_shader_value(shader, light.enabledLoc, struct.pack("i", light.enabled), rl.SHADER_UNIFORM_INT)
    rl.set_shader_value(shader, light.typeLoc, struct.pack("i", light.type), rl.SHADER_UNIFORM_INT)

    # Send to shader light position values
    position = struct.pack("fff", light.position.x, light.position.y, light.position.z)
    rl.set_shader_value(shader, light.positionLoc, position, rl.SHADER_UNIFORM_VEC3)

    # Send to shader light target position values
    target = struct.pack("fff", light.target.x, light.target.y, light.target.z)
    rl.set_shader_value(shader, light.targetLoc, target, rl.SHADER_UNIFORM_VEC3)

    # Send to shader light color values
    color = struct.pack("ffff", float(light.color.r)/float(255), float(light.color.g)/float(255), 
                       float(light.color.b)/float(255), float(light.color.a)/float(255))
    rl.set_shader_value(shader, light.colorLoc, color, rl.SHADER_UNIFORM_VEC4)
