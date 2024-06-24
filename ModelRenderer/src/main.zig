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

        camera.begin();

        const pose = anim.framePoses[0][0..@intCast(anim.boneCount)];
        const bindPose = model.bindPose[0..@intCast(anim.boneCount)];
        const bones = anim.bones[0..@intCast(anim.boneCount)];
        rotateBonesFromLandmarks(pose, landmarks);
        snapBonesToParent(pose, bones, bindPose);
        rl.updateModelAnimation(model, anim, 0);

        model.drawEx(rl.Vector3.zero(), .{ .x = 1, .y = 0, .z = 0 }, 0, .{ .x = 1, .y = 1, .z = 1 }, rl.Color.white);
        for (anim.framePoses[0], 0..@intCast(anim.boneCount)) |transform, _| {
            rl.drawSphere(transform.translation, 0.1, rl.Color.red);
        }

        camera.end();

        rl.endDrawing();
    }
}

// The direction of bones at 0 rotation is up (+y)
// Quaternion.fromEuler rotation order is ZYX i.e. roll yaw pitch (relative to self)
fn rotateBonesFromLandmarks(pose: []rl.Transform, landmarks: []const Landmark) void {
    // _ = landmarks;
    // for (pose) |*bone| {
    //     bone.rotation = rl.Quaternion.fromEuler(0, 0, 90 * math.rad_per_deg);
    // }

    { // head
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
        const headPos = getBone(pose, .head).translation;
        rl.drawLine3D(headPos, headPos.add(up.scale(5.0)), rl.Color.purple);
        rl.drawLine3D(headPos, headPos.add(left.scale(5.0)), rl.Color.green);
        rl.drawLine3D(headPos, headPos.add(forward.scale(5.0)), rl.Color.red);
        var rot = rotationFromUpForawrd(up, forward).toEuler();
        rot.x *= 2; // exaggerate pitch since it appears to be too little
        getBone(pose, .head).rotation = rl.Quaternion.fromEuler(rot.x, rot.y, rot.z);
    }
    { // right arm
        const shoulder = landmarkToVector3(getLandmark(landmarks, .right_shoulder));
        const elbow = landmarkToVector3(getLandmark(landmarks, .right_elbow));
        const up = elbow.subtract(shoulder).normalize();
        var upXYProj = up;
        upXYProj.z = 0;
        const forward = upXYProj.rotateByAxisAngle(zAxis, 90 * math.rad_per_deg).normalize();
        const left = up.crossProduct(forward).normalize();
        const armPos = getBone(pose, .right_arm).translation;
        rl.drawLine3D(armPos, armPos.add(up.scale(5.0)), rl.Color.purple);
        rl.drawLine3D(armPos, armPos.add(left.scale(5.0)), rl.Color.green);
        rl.drawLine3D(armPos, armPos.add(forward.scale(5.0)), rl.Color.red);
        getBone(pose, .right_arm).rotation = rotationFromUpForawrd(up, forward);
    }
    { // right fore-arm and hand
        const elbow = landmarkToVector3(getLandmark(landmarks, .right_elbow));
        const wrist = landmarkToVector3(getLandmark(landmarks, .right_wrist));
        const up = wrist.subtract(elbow).normalize();
        var upXYProj = up;
        upXYProj.z = 0;
        const forward = upXYProj.rotateByAxisAngle(zAxis, 90 * math.rad_per_deg).normalize();
        const left = up.crossProduct(forward).normalize();
        const armPos = getBone(pose, .right_fore_arm).translation;
        rl.drawLine3D(armPos, armPos.add(up.scale(5.0)), rl.Color.purple);
        rl.drawLine3D(armPos, armPos.add(left.scale(5.0)), rl.Color.green);
        rl.drawLine3D(armPos, armPos.add(forward.scale(5.0)), rl.Color.red);
        const rotation = rotationFromUpForawrd(up, forward);
        getBone(pose, .right_fore_arm).rotation = rotation;
        getBone(pose, .right_hand).rotation = rotation;
    }
    { // left arm
        const shoulder = landmarkToVector3(getLandmark(landmarks, .left_shoulder));
        const elbow = landmarkToVector3(getLandmark(landmarks, .left_elbow));
        const up = elbow.subtract(shoulder).normalize();
        var upXYProj = up;
        upXYProj.z = 0;
        const forward = upXYProj.rotateByAxisAngle(zAxis, -90 * math.rad_per_deg).normalize();
        const left = up.crossProduct(forward).normalize();
        const armPos = getBone(pose, .left_arm).translation;
        rl.drawLine3D(armPos, armPos.add(up.scale(5.0)), rl.Color.purple);
        rl.drawLine3D(armPos, armPos.add(left.scale(5.0)), rl.Color.green);
        rl.drawLine3D(armPos, armPos.add(forward.scale(5.0)), rl.Color.red);
        getBone(pose, .left_arm).rotation = rotationFromUpForawrd(up, forward);
    }
    { // left fore-arm and hand
        const elbow = landmarkToVector3(getLandmark(landmarks, .left_elbow));
        const wrist = landmarkToVector3(getLandmark(landmarks, .left_wrist));
        const up = wrist.subtract(elbow).normalize();
        var upXYProj = up;
        upXYProj.z = 0;
        const forward = upXYProj.rotateByAxisAngle(zAxis, -90 * math.rad_per_deg).normalize();
        const left = up.crossProduct(forward).normalize();
        const armPos = getBone(pose, .left_fore_arm).translation;
        rl.drawLine3D(armPos, armPos.add(up.scale(5.0)), rl.Color.purple);
        rl.drawLine3D(armPos, armPos.add(left.scale(5.0)), rl.Color.green);
        rl.drawLine3D(armPos, armPos.add(forward.scale(5.0)), rl.Color.red);
        const rotation = rotationFromUpForawrd(up, forward);
        getBone(pose, .left_fore_arm).rotation = rotation;
        getBone(pose, .left_hand).rotation = rotation;
    }
}

fn snapBonesToParent(pose: []rl.Transform, bones: []const rl.BoneInfo, bindPose: []rl.Transform) void {
    std.debug.assert(pose.len == bones.len and pose.len == bindPose.len);
    for (pose, bones, bindPose) |*bone, info, originalBone| {
        if (info.parent < 0) continue;
        const parent = pose[@intCast(info.parent)];
        const originalParent = bindPose[@intCast(info.parent)];
        const offset = originalBone.translation.subtract(originalParent.translation);
        var rotOpposite = originalParent.rotation;
        rotOpposite.x *= -1;
        rotOpposite.y *= -1;
        rotOpposite.z *= -1;
        const offsetRotated = offset.rotateByQuaternion(rotOpposite).rotateByQuaternion(parent.rotation);
        bone.translation = parent.translation.add(offsetRotated);
        rl.drawLine3D(parent.translation, bone.translation, rl.Color.magenta);
    }
}

// my own really weird implementation
fn rotationFromForawrdLeft(forward: rl.Vector3, left: rl.Vector3) rl.Quaternion {
    var leftXYProj = left;
    leftXYProj.z = 0;
    const roll: f32 = math.sign(leftXYProj.y) * leftXYProj.angle(xAxis);
    const yaw: f32 = -math.sign(left.z) * left.angle(leftXYProj);
    const tempForawrd = zAxis.rotateByQuaternion(rl.Quaternion.fromEuler(0, yaw, roll));
    const pitch: f32 = -math.sign(forward.rotateByQuaternion(rl.Quaternion.fromEuler(0, 0, roll)).y) * forward.angle(tempForawrd);
    return rl.Quaternion.fromEuler(pitch, yaw, roll);
}

// ChatGPT suggested matrix bs
fn rotationFromUpForawrd(up_: rl.Vector3, forward_: rl.Vector3) rl.Quaternion {
    var up = up_.normalize();
    const forward = forward_.normalize();
    const right = up.crossProduct(forward);
    up = forward.crossProduct(right);
    const rotationMatrix: rl.Matrix = .{
        .m0 = right.x, .m4 = up.x, .m8  = forward.x, .m12 = 0.0,
        .m1 = right.y, .m5 = up.y, .m9  = forward.y, .m13 = 0.0,
        .m2 = right.z, .m6 = up.z, .m10 = forward.z, .m14 = 0.0,
        .m3 = 0.0,     .m7 = 0.0,  .m11 = 0.0,       .m15 = 1.0,
    };
    return rl.Quaternion.fromMatrix(rotationMatrix);
}
