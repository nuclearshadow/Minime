/// Zig version of rlights.h from raylib examples

// /**********************************************************************************************
// *
// *   raylib.lights - Some useful functions to deal with lights data
// *
// *   CONFIGURATION:
// *
// *   #define RLIGHTS_IMPLEMENTATION
// *       Generates the implementation of the library i32o the included file.
// *       If not defined, the library is in header only mode and can be included in other headers
// *       or source files without problems. But only ONE file should hold the implementation.
// *
// *   LICENSE: zlib/libpng
// *
// *   Copyright (c) 2017-2023 Victor Fisac (@victorfisac) and Ramon Santamaria (@raysan5)
// *
// *   This software is provided "as-is", without any express or implied warranty. In no event
// *   will the authors be held liable for any damages arising from the use of this software.
// *
// *   Permission is granted to anyone to use this software for any purpose, including commercial
// *   applications, and to alter it and redistribute it freely, subject to the following restrictions:
// *
// *     1. The origin of this software must not be misrepresented; you must not claim that you
// *     wrote the original software. If you use this software in a product, an acknowledgment
// *     in the product documentation would be appreciated but is not required.
// *
// *     2. Altered source versions must be plainly marked as such, and must not be misrepresented
// *     as being the original software.
// *
// *     3. This notice may not be removed or altered from any source distribution.
// *
// **********************************************************************************************/

const rl = @import("raylib");

pub const max_lights = 4; // Max dynamic lights supported by shader

// Light data
pub const Light = struct {
    type: LightType = .light_directional,
    enabled: bool = false,
    position: rl.Vector3 = rl.Vector3{ .x = 0, .y = 0, .z = 0 },
    target: rl.Vector3 = rl.Vector3{ .x = 0, .y = 0, .z = 0 },
    color: rl.Color = rl.Color.black,
    attenuation: f32 = 0,

    // Shader locations
    enabledLoc: i32 = 0,
    typeLoc: i32 = 0,
    positionLoc: i32 = 0,
    targetLoc: i32 = 0,
    colorLoc: i32 = 0,
    attenuationLoc: i32 = 0,

    pub fn create(type_: LightType, position: rl.Vector3, target: rl.Vector3, color: rl.Color, shader: rl.Shader) Light {
        return createLight(type_, position, target, color, shader);
    }
};

// Light type
pub const LightType = enum {
    light_directional,
    light_point,
};

var lights_count: i32 = 0; // Current amount of created lights

// Create a light and get shader locations
pub fn createLight(type_: LightType, position: rl.Vector3, target: rl.Vector3, color: rl.Color, shader: rl.Shader) Light {
    var light = Light{};

    if (lights_count < max_lights) {
        light.enabled = true;
        light.type = type_;
        light.position = position;
        light.target = target;
        light.color = color;

        // NOTE: Lighting shader naming must be the provided ones
        light.enabledLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].enabled", .{lights_count}));
        light.typeLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].type", .{lights_count}));
        light.positionLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].position", .{lights_count}));
        light.targetLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].target", .{lights_count}));
        light.colorLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].color", .{lights_count}));

        updateLightValues(shader, light);

        lights_count += 1;
    }

    return light;
}

// Send light properties to shader
// NOTE: Light shader locations should be available
pub fn updateLightValues(shader: rl.Shader, light: Light) void {
    // Send to shader light enabled state and type
    rl.setShaderValue(shader, light.enabledLoc, &@as(i32, @intFromBool(light.enabled)), .shader_uniform_int);
    rl.setShaderValue(shader, light.typeLoc, &@as(i32, @intFromEnum(light.type)), .shader_uniform_int);

    // Send to shader light position values
    const position: [3]f32 = .{ light.position.x, light.position.y, light.position.z };
    rl.setShaderValue(shader, light.positionLoc, &position, .shader_uniform_vec3);

    // Send to shader light target position values
    const target: [3]f32 = .{ light.target.x, light.target.y, light.target.z };
    rl.setShaderValue(shader, light.targetLoc, &target, .shader_uniform_vec3);

    // Send to shader light color values
    const color: [4]f32 = .{
        @as(f32, @floatFromInt(light.color.r)) / 255.0,
        @as(f32, @floatFromInt(light.color.g)) / 255.0,
        @as(f32, @floatFromInt(light.color.b)) / 255.0,
        @as(f32, @floatFromInt(light.color.a)) / 255.0,
    };
    rl.setShaderValue(shader, light.colorLoc, &color, .shader_uniform_vec4);
}
