const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    const width = 800;
    const height = 600;
    rl.initWindow(width, height, "Model animation test");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var camera = rl.Camera{
        .position = .{ .x = 0, .y = 5, .z = 15 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45,
        .projection = .camera_perspective,
    };

    const modelPath = "../resources/3d_models/avatar_rigged.glb";

    var model = rl.loadModel(modelPath);
    defer model.unload();

    const anims = (try rl.loadModelAnimations(modelPath));
    for (anims) |anim| {
        std.debug.print("{s}\n", .{anim.name});
    }

    const anim = anims[0];
    std.debug.print("{any}", .{anim});

    // var pose: [19]rl.Transform = undefined;
    // @memcpy(&pose, model.bindPose);
    // var anim = rl.ModelAnimation{
    //     .boneCount = model.boneCount,
    //     .bones = model.bones,
    //     .frameCount = 1,
    //     .framePoses = &pose,
    //     .name = undefined,
    // };
    // @memset(&anim.name, 0);
    // @memcpy(anim.name[0..4], "Anim");

    var frameCounter: c_int = 0;

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);

        const mouse = rl.getMousePosition();

        anim.framePoses[0][0].translation.x = (mouse.x - width / 2) * 0.01;

        rl.updateModelAnimation(model, anim, 0);
        // rl.updateModelAnimation(model, anim, frameCounter);
        frameCounter = @mod(frameCounter + 1, anim.frameCount);

        camera.begin();

        model.drawEx(rl.Vector3.zero(), rl.Vector3{ .x = 1, .y = 0, .z = 0 }, 0, rl.Vector3{ .x = 1, .y = 1, .z = 1 }, rl.Color.white);
        for (anim.framePoses[0], 0..@intCast(anim.boneCount)) |transform, _| {
            rl.drawSphere(transform.translation, 0.1, rl.Color.red);
        }

        camera.end();

        rl.endDrawing();
    }
}
