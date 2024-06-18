const std = @import("std");
const math = std.math;
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

const LandmarkIndex = enum(usize) {
    nose = 0,
    left_eye_inner,
    left_eye,
    left_eye_outer,
    right_eye_inner,
    right_eye,
    right_eye_outer,
    left_ear,
    right_ear,
    mouth_left,
    mouth_right,
    left_shoulder,
    right_shoulder,
    left_elbow,
    right_elbow,
    left_wrist,
    right_wrist,
    left_pinky,
    right_pinky,
    left_index,
    right_index,
    left_thumb,
    right_thumb,
    left_hip,
    right_hip,
    left_knee,
    right_knee,
    left_ankle,
    right_ankle,
    left_heel,
    right_heel,
    left_foot_index,
    right_foot_index,
};

fn getLandmark(landmarks: []const Landmark, index: LandmarkIndex) Landmark {
    return landmarks[@intFromEnum(index)];
}

fn landmarkToVector3(landmark: Landmark) rl.Vector3 {
    return .{
        .x = landmark.x,
        .y = landmark.y,
        .z = landmark.z,
    };
}

fn convertLandmarksCoordinateSpace(landmarks: []Landmark) void {
    for (landmarks) |*landmark| {
        landmark.y *= -1;
        landmark.z *= -1;
    }
}

const BoneIndex = enum(usize) {
    hips = 0,
    spine,
    spine1,
    spine2,
    neck,
    head,
    left_arm,
    left_fore_arm,
    left_hand,
    right_arm,
    right_fore_arm,
    right_hand,
    left_up_leg,
    left_leg,
    left_foot,
    left_toe_base,
    right_up_leg,
    right_leg,
    right_foot,
    right_toe_base,
};

fn getBone(bones: []rl.Transform, index: BoneIndex) *rl.Transform {
    return &bones[@intFromEnum(index)];
}

const xAxis = rl.Vector3{ .x = 1, .y = 0, .z = 0 };
const yAxis = rl.Vector3{ .x = 0, .y = 1, .z = 0 };
const zAxis = rl.Vector3{ .x = 0, .y = 0, .z = 1 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const width = 800;
    const height = 600;
    rl.initWindow(width, height, "Minime: Model Renderer");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    const monitor = rl.getCurrentMonitor();
    const monitorWidth = rl.getMonitorWidth(monitor);
    const monitorHeight = rl.getMonitorHeight(monitor);
    rl.setWindowPosition(@divTrunc(monitorWidth, 2), @divTrunc(monitorHeight, 2) - @divTrunc(height, 2));

    var camera = rl.Camera{
        .position = .{ .x = 0, .y = 5, .z = 15 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45,
        .projection = .camera_perspective,
    };

    const shader = rl.loadShader("resources/shaders/lighting.vs", "resources/shaders/lighting.fs");
    defer rl.unloadShader(shader);

    const shader_loc_vector_view: usize = @intFromEnum(rl.ShaderLocationIndex.shader_loc_vector_view);
    shader.locs[shader_loc_vector_view] = rl.getShaderLocation(shader, "viewPos");

    const ambientLoc: i32 = rl.getShaderLocation(shader, "ambient");
    rl.setShaderValue(shader, ambientLoc, &[_]f32{ 0.1, 0.1, 0.1, 1.0 }, .shader_uniform_vec4);

    const light = rlights.Light.create(.light_directional, rl.Vector3{ .x = 0, .y = 5, .z = 15 }, rl.Vector3.zero(), rl.Color.white, shader);

    const modelPath = "resources/3d_models/avatar_rigged.glb";

    var model = rl.loadModel(modelPath);
    defer model.unload();

    for (model.materials, 0..@intCast(model.materialCount)) |*material, _| {
        material.shader = shader;
    }

    const anims = (try rl.loadModelAnimations(modelPath));
    for (anims) |anim| {
        std.debug.print("{s}\n", .{anim.name});
    }

    var anim = anims[0];

    var inputBuffer: [1024 * 6]u8 = undefined;
    var stdin = std.io.getStdIn();
    while (!rl.windowShouldClose()) {
        const n = try stdin.read(&inputBuffer);
        const input = inputBuffer[0..n];
        const parsed = try json.parseFromSlice([]Landmark, alloc, input, .{});
        defer parsed.deinit();
        const landmarks = parsed.value;
        convertLandmarksCoordinateSpace(landmarks);

        rlights.updateLightValues(shader, light);
        const cameraPos: [3]f32 = .{ camera.position.x, camera.position.y, camera.position.z };
        rl.setShaderValue(shader, shader.locs[shader_loc_vector_view], &cameraPos, .shader_uniform_vec3);

        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);

        rl.updateModelAnimation(model, anim, 0);

        camera.begin();
        transformBonesFromLandmarks(anim.framePoses[0][0..@intCast(anim.boneCount)], landmarks);

        model.drawEx(rl.Vector3.zero(), rl.Vector3{ .x = 1, .y = 0, .z = 0 }, 0, rl.Vector3{ .x = 1, .y = 1, .z = 1 }, rl.Color.white);
        for (anim.framePoses[0], 0..@intCast(anim.boneCount)) |transform, _| {
            rl.drawSphere(transform.translation, 0.1, rl.Color.red);
            // var tAxis: rl.Vector3 = undefined;
            // var tAngle: f32 = undefined;
            // transform.rotation.toAxisAngle(&tAxis, &tAngle);
            // rl.drawLine3D(transform.translation, transform.translation.add(tAxis.scale(5.0)), rl.Color.blue);
        }

        camera.end();
        // for (landmarks) |landmark| {
        //     const center = rl.Vector2{
        //         .x = landmark.x * @as(f32, @floatFromInt(width)),
        //         .y = landmark.y * @as(f32, @floatFromInt(height)),
        //     };
        //     rl.drawCircleV(center, 10, rl.Color.red);
        // }

        rl.endDrawing();
    }
}

fn transformBonesFromLandmarks(bones: []rl.Transform, landmarks: []const Landmark) void {
    const mouthLeft = landmarkToVector3(getLandmark(landmarks, .mouth_left));
    const mouthRight = landmarkToVector3(getLandmark(landmarks, .mouth_right));
    const mouthMid = rl.Vector3.lerp(mouthLeft, mouthRight, 0.5);
    const eyesMid = rl.Vector3.lerp(
        landmarkToVector3(getLandmark(landmarks, .left_eye_outer)),
        landmarkToVector3(getLandmark(landmarks, .right_eye_outer)),
        0.5,
    );
    const earsMid = rl.Vector3.lerp(
        landmarkToVector3(getLandmark(landmarks, .left_ear)),
        landmarkToVector3(getLandmark(landmarks, .right_ear)),
        0.5,
    );
    const up = eyesMid.lerp(earsMid, 0.3).subtract(mouthMid).normalize();
    const left = mouthLeft.subtract(mouthRight).normalize();
    var forward = left.crossProduct(up).normalize();
    const headPos = getBone(bones, .head).translation;
    rl.drawLine3D(headPos, headPos.add(up.scale(5.0)), rl.Color.purple);
    rl.drawLine3D(headPos, headPos.add(left.scale(5.0)), rl.Color.green);
    rl.drawLine3D(headPos, headPos.add(forward.scale(5.0)), rl.Color.red);

    var leftXYProj = left;
    leftXYProj.z = 0;
    const roll: f32 = math.sign(leftXYProj.y) * leftXYProj.angle(xAxis);
    const yaw: f32 = -math.sign(left.z) * left.angle(leftXYProj);
    const tempForawrd = zAxis.rotateByQuaternion(rl.Quaternion.fromEuler(0, yaw, roll));
    const pitch: f32 = -math.sign(forward.rotateByQuaternion(rl.Quaternion.fromEuler(0, 0, roll)).y) * forward.angle(tempForawrd);
    getBone(bones, .head).rotation = rl.Quaternion.fromEuler(pitch * 2, yaw, roll);
}
