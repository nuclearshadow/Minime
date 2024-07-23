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

    const factor = 0.3;
    const renderTarget = rl.loadRenderTexture(width * factor, height * factor);

    const shader = rl.loadShader("resources/shaders/lighting.vs", "resources/shaders/lighting.fs");
    defer rl.unloadShader(shader);

    const shader_loc_vector_view: usize = @intFromEnum(rl.ShaderLocationIndex.shader_loc_vector_view);
    shader.locs[shader_loc_vector_view] = rl.getShaderLocation(shader, "viewPos");

    const ambientLoc: i32 = rl.getShaderLocation(shader, "ambient");
    rl.setShaderValue(shader, ambientLoc, &[_]f32{ 0.1, 0.1, 0.5, 1.0 }, .shader_uniform_vec4);

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

        const dt = rl.getFrameTime();

        rlights.updateLightValues(shader, light);
        const cameraPos: [3]f32 = .{ camera.position.x, camera.position.y, camera.position.z };
        rl.setShaderValue(shader, shader.locs[shader_loc_vector_view], &cameraPos, .shader_uniform_vec3);

        const camSpeed = 5;
        var camMove = rl.Vector3.zero();
        if (rl.isKeyDown(.key_a)) camMove.y -= camSpeed * dt;
        if (rl.isKeyDown(.key_d)) camMove.y += camSpeed * dt;
        if (rl.isKeyDown(.key_w)) camMove.z += camSpeed * dt;
        if (rl.isKeyDown(.key_s)) camMove.z -= camSpeed * dt;
        camMove.x = rl.getMouseWheelMove() * camSpeed * dt;
        rl.updateCameraPro(&camera, camMove, rl.Vector3.zero(), 0);

        rl.beginDrawing();
        rl.beginTextureMode(renderTarget);
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
        rl.endTextureMode();
        const sourceRect = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = width * factor,
            .height = -height * factor,
        };
        const destRect = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = width,
            .height = height,
        };
        rl.drawTexturePro(renderTarget.texture, sourceRect, destRect, .{ .x = 0, .y = 0 }, 0, rl.Color.white);
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

    const nose           = landmarkToVector3(getLandmark(landmarks, .nose));
    const leftEyeInner   = landmarkToVector3(getLandmark(landmarks, .left_eye_inner));
    const leftEye        = landmarkToVector3(getLandmark(landmarks, .left_eye));
    const leftEyeOuter   = landmarkToVector3(getLandmark(landmarks, .left_eye_outer));
    const rightEyeInner  = landmarkToVector3(getLandmark(landmarks, .right_eye_inner));
    const rightEye       = landmarkToVector3(getLandmark(landmarks, .right_eye));
    const rightEyeOuter  = landmarkToVector3(getLandmark(landmarks, .right_eye_outer));
    const leftEar        = landmarkToVector3(getLandmark(landmarks, .left_ear));
    const rightEar       = landmarkToVector3(getLandmark(landmarks, .right_ear));
    const mouthLeft      = landmarkToVector3(getLandmark(landmarks, .mouth_left));
    const mouthRight     = landmarkToVector3(getLandmark(landmarks, .mouth_right));
    const leftShoulder   = landmarkToVector3(getLandmark(landmarks, .left_shoulder));
    const rightShoulder  = landmarkToVector3(getLandmark(landmarks, .right_shoulder));
    const leftElbow      = landmarkToVector3(getLandmark(landmarks, .left_elbow));
    const rightElbow     = landmarkToVector3(getLandmark(landmarks, .right_elbow));
    const leftWrist      = landmarkToVector3(getLandmark(landmarks, .left_wrist));
    const rightWrist     = landmarkToVector3(getLandmark(landmarks, .right_wrist));
    const leftPinky      = landmarkToVector3(getLandmark(landmarks, .left_pinky));
    const rightPinky     = landmarkToVector3(getLandmark(landmarks, .right_pinky));
    const leftIndex      = landmarkToVector3(getLandmark(landmarks, .left_index));
    const rightIndex     = landmarkToVector3(getLandmark(landmarks, .right_index));
    const leftThumb      = landmarkToVector3(getLandmark(landmarks, .left_thumb));
    const rightThumb     = landmarkToVector3(getLandmark(landmarks, .right_thumb));
    const leftHip        = landmarkToVector3(getLandmark(landmarks, .left_hip));
    const rightHip       = landmarkToVector3(getLandmark(landmarks, .right_hip));
    const leftKnee       = landmarkToVector3(getLandmark(landmarks, .left_knee));
    const rightKnee      = landmarkToVector3(getLandmark(landmarks, .right_knee));
    const leftAnkle      = landmarkToVector3(getLandmark(landmarks, .left_ankle));
    const rightAnkle     = landmarkToVector3(getLandmark(landmarks, .right_ankle));
    const leftHeel       = landmarkToVector3(getLandmark(landmarks, .left_heel));
    const rightHeel      = landmarkToVector3(getLandmark(landmarks, .right_heel));
    const leftFootIndex  = landmarkToVector3(getLandmark(landmarks, .left_foot_index));
    const rightFootIndex = landmarkToVector3(getLandmark(landmarks, .right_foot_index));
    
    _ = nose;
    _ = leftEyeInner;
    _ = leftEye;
    _ = leftEyeOuter;
    _ = rightEyeInner;
    _ = rightEye;
    _ = rightEyeOuter;
    _ = leftEar;
    _ = rightEar;
    _ = leftPinky;
    _ = rightPinky;
    _ = leftIndex;
    _ = rightIndex;
    _ = leftThumb;
    _ = rightThumb;
    _ = leftKnee;
    _ = rightKnee;
    _ = leftAnkle;
    _ = rightAnkle;
    _ = leftHeel;
    _ = rightHeel;
    _ = leftFootIndex;
    _ = rightFootIndex;

    const shouldersMid = leftShoulder.lerp(rightShoulder, 0.5);
    const hipsMid = leftHip.lerp(rightHip, 0.5);
    const localUp = shouldersMid.subtract(hipsMid).normalize();
    
    const shouldersLeft = leftShoulder.subtract(rightShoulder).normalize();
    const shoulderForward = shouldersLeft.crossProduct(localUp).normalize();
    const shouldersUp = shoulderForward.crossProduct(shouldersLeft).normalize();
    
    const hipsLeft = leftHip.subtract(rightHip).normalize();
    const hipsForward = hipsLeft.crossProduct(localUp).normalize();
    const hipsUp = hipsForward.crossProduct(hipsLeft).normalize();

    const hipsPos = getBone(pose, .hips).translation;
    rl.drawLine3D(hipsPos, hipsPos.add(hipsLeft).scale(5), rl.Color.red);
    rl.drawLine3D(hipsPos, hipsPos.add(hipsForward).scale(5), rl.Color.blue);
    rl.drawLine3D(hipsPos, hipsPos.add(hipsUp).scale(5), rl.Color.green);

    
    { // head and neck
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
        const forward = left.crossProduct(up).normalize();

        var rot = rotationFromUpForawrd(up, forward).toEuler();
        rot.x *= 2; // exaggerate pitch since it appears to be too little
        getBone(pose, .head).rotation = rl.Quaternion.fromEuler(rot.x, rot.y, rot.z);
        getBone(pose, .neck).rotation = rotationFromUpForawrd(localUp, shoulderForward);
    }
    { // right arm
        const up = rightElbow.subtract(rightShoulder).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, 90.0 * math.rad_per_deg);
        
        getBone(pose, .right_arm).rotation = rotationFromUpForawrd(up, forward);
    }
    { // right fore-arm and hand
        const up = rightWrist.subtract(rightElbow).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, 90.0 * math.rad_per_deg);

        const rotation = rotationFromUpForawrd(up, forward);
        getBone(pose, .right_fore_arm).rotation = rotation;
        getBone(pose, .right_hand).rotation = rotation;
    }
    { // left arm
        const up = leftElbow.subtract(leftShoulder).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, -90.0 * math.rad_per_deg);

        getBone(pose, .left_arm).rotation = rotationFromUpForawrd(up, forward);
    }
    { // left fore-arm and hand
        const up = leftWrist.subtract(leftElbow).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, -90.0 * math.rad_per_deg);

        const rotation = rotationFromUpForawrd(up, forward);
        getBone(pose, .left_fore_arm).rotation = rotation;
        getBone(pose, .left_hand).rotation = rotation;
    }
    { // hips and spine
        getBone(pose, .hips  ).rotation = rotationFromUpForawrd(
            hipsUp.lerp(shouldersUp, 0.0 ), 
            hipsForward.lerp(shoulderForward, 0.0 ));
        getBone(pose, .spine ).rotation = rotationFromUpForawrd(
            hipsUp.lerp(shouldersUp, 0.33), 
            hipsForward.lerp(shoulderForward, 0.33));
        getBone(pose, .spine1).rotation = rotationFromUpForawrd(
            hipsUp.lerp(shouldersUp, 0.66), 
            hipsForward.lerp(shoulderForward, 0.66));
        getBone(pose, .spine2).rotation = rotationFromUpForawrd(
            hipsUp.lerp(shouldersUp, 1.0 ), 
            hipsForward.lerp(shoulderForward, 0.0 ));
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
