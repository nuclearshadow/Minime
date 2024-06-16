const std = @import("std");
const json = std.json;

const rl = @import("raylib");
const rlights = @import("rlights.zig");

const Landmark = struct {
    x: f32,
    y: f32,
    z: f32,
    visibility: f32,
    presence: f32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const width = 800;
    const height = 600;
    rl.initWindow(width, height, "Minime: Model Renderer");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var camera = rl.Camera{
        .position = .{ .x = 0, .y = 5, .z = 15 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45,
        .projection = .camera_perspective,
    };

    const shader = rl.loadShader("resources/shaders/lighting.vs", "resources/shaders/lighting.fs");
    defer rl.unloadShader(shader);

    // const shader_loc_vector_view: usize = @intFromEnum(rl.ShaderLocationIndex.shader_loc_vector_view);
    const view_loc = rl.getShaderLocation(shader, "viewPos");
    std.debug.print("{}\n", .{view_loc});

    const ambient_loc: i32 = rl.getShaderLocation(shader, "ambient");
    std.debug.print("{}\n", .{ambient_loc});
    rl.setShaderValue(shader, ambient_loc, &[_]f32{ 0.1, 0.1, 0.1, 1.0 }, .shader_uniform_vec4);

    const light = rlights.Light.create(.light_directional, rl.Vector3{ .x = 0, .y = 5, .z = 15 }, rl.Vector3.zero(), rl.Color.white, shader);
    std.debug.print("{any}\n", .{light});

    const model_path = "resources/3d_models/avatar_rigged.glb";

    var model = rl.loadModel(model_path);
    defer model.unload();

    for (model.materials, 0..@intCast(model.materialCount)) |*material, _| {
        material.shader = shader;
    }

    const anims = (try rl.loadModelAnimations(model_path));
    for (anims) |anim| {
        std.debug.print("{s}\n", .{anim.name});
    }

    const anim = anims[0];

    var frame_counter: c_int = 0;

    var input_buffer: [1024 * 6]u8 = undefined;
    var stdin = std.io.getStdIn();
    while (!rl.windowShouldClose()) {
        const n = try stdin.read(&input_buffer);
        const input = input_buffer[0..n];
        const parsed = try json.parseFromSlice([]Landmark, alloc, input, .{});
        defer parsed.deinit();

        rlights.updateLightValues(shader, light);
        const cameraPos: [3]f32 = .{ camera.position.x, camera.position.y, camera.position.z };
        rl.setShaderValue(shader, view_loc, &cameraPos, .shader_uniform_vec3);

        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);

        const mouse = rl.getMousePosition();

        var rot = anim.framePoses[0][5].rotation;
        rot.x = (mouse.y - width / 2) * 0.001;
        rot.y = (mouse.x - width / 2) * 0.001;
        anim.framePoses[0][5].rotation = rot.normalize();

        rl.updateModelAnimation(model, anim, 0);
        // rl.updateModelAnimation(model, anim, frameCounter);
        frame_counter = @mod(frame_counter + 1, anim.frameCount);

        camera.begin();

        model.drawEx(rl.Vector3.zero(), rl.Vector3{ .x = 1, .y = 0, .z = 0 }, 0, rl.Vector3{ .x = 1, .y = 1, .z = 1 }, rl.Color.white);
        for (anim.framePoses[0], 0..@intCast(anim.boneCount)) |transform, _| {
            rl.drawSphere(transform.translation, 0.1, rl.Color.red);
        }

        camera.end();

        for (parsed.value) |landmark| {
            const center = rl.Vector2{
                .x = landmark.x * @as(f32, @floatFromInt(width)),
                .y = landmark.y * @as(f32, @floatFromInt(height)),
            };
            rl.drawCircleV(center, 10, rl.Color.red);
        }

        rl.endDrawing();
    }
}
