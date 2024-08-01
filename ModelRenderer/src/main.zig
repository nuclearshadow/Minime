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
    count,
};

fn getBone(bones: anytype, index: BoneIndex) *(@typeInfo(@TypeOf(bones)).Pointer.child) {
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

    const defaultCamera = rl.Camera{
        .position = .{ .x = 0, .y = 0, .z = 15 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45,
        .projection = .camera_perspective,
    };
    var camera = defaultCamera;

    const targetResFactor = 1;
    const renderTarget = rl.loadRenderTexture(width * targetResFactor, height * targetResFactor);

    const downscaleShader = rl.loadShader(null, "resources/shaders/downscale.fs");
    const dsWidthLoc      = rl.getShaderLocation(downscaleShader, "width");
    const dsHeightLoc     = rl.getShaderLocation(downscaleShader, "height");
    const dsResolutionLoc = rl.getShaderLocation(downscaleShader, "resolution");

    rl.setShaderValue(downscaleShader, dsWidthLoc,  &width,  .shader_uniform_int);
    rl.setShaderValue(downscaleShader, dsHeightLoc, &height, .shader_uniform_int);

    const lightingShader = rl.loadShader("resources/shaders/lighting.vs", "resources/shaders/lighting.fs");
    defer rl.unloadShader(lightingShader);

    const shader_loc_vector_view: usize = @intFromEnum(rl.ShaderLocationIndex.shader_loc_vector_view);
    lightingShader.locs[shader_loc_vector_view] = rl.getShaderLocation(lightingShader, "viewPos");

    const lAmbientLoc: i32 = rl.getShaderLocation(lightingShader, "ambient");
    rl.setShaderValue(lightingShader, lAmbientLoc, &[_]f32{ 0.0, 0.0, 0.5, 1.0 }, .shader_uniform_vec4);

    const light = rlights.Light.create(.light_directional, rl.Vector3{ .x = 0, .y = 5, .z = 15 }, rl.Vector3.zero(), rl.Color.white, lightingShader);

    const modelPath = "resources/3d_models/avatar_rigged.glb";

    var model = rl.loadModel(modelPath);
    defer model.unload();

    for (model.materials, 0..@intCast(model.materialCount)) |*material, _| {
        material.shader = lightingShader;
    }

    const anims = (try rl.loadModelAnimations(modelPath));
    for (anims) |anim| {
        std.debug.print("{s}\n", .{anim.name});
    }

    var anim = anims[0];

    var calculatedRotations: [@intFromEnum(BoneIndex.count)]rl.Quaternion = undefined;

    var positionMode = true;

    var inputBuffer: [1024 * 6]u8 = undefined;
    var stdin = std.io.getStdIn();
    while (!rl.windowShouldClose()) {
        const n = try stdin.read(&inputBuffer);
        const input = inputBuffer[0..n];
        const parsed = try json.parseFromSlice(struct {
            landmarks: []Landmark,
            position: rl.Vector3,
        }, alloc, input, .{});
        defer parsed.deinit();
        
        const landmarks = parsed.value.landmarks;
        
        convertLandmarksCoordinateSpace(landmarks);
        const posZOffset = 0.5;
        var position = parsed.value.position;
        position.y *= -1;
        position.z *= -2.5;
        position.z += posZOffset;
        // BEWARE: Magic numbers

        // Reverse projection??
        const depth = camera.position.z - position.z;
        position.x *= depth / (camera.position.z + posZOffset);
        position.y *= depth / (camera.position.z + posZOffset);

        const dt = rl.getFrameTime();

        rlights.updateLightValues(lightingShader, light);
        const cameraPos: [3]f32 = .{ camera.position.x, camera.position.y, camera.position.z };
        rl.setShaderValue(lightingShader, lightingShader.locs[shader_loc_vector_view], &cameraPos, .shader_uniform_vec3);

        const camSpeed = 5;
        var camMove = rl.Vector3.zero();
        if (rl.isKeyDown(.key_a)) camMove.y -= camSpeed * dt;
        if (rl.isKeyDown(.key_d)) camMove.y += camSpeed * dt;
        if (rl.isKeyDown(.key_w)) camMove.z += camSpeed * dt;
        if (rl.isKeyDown(.key_s)) camMove.z -= camSpeed * dt;
        camMove.x = rl.getMouseWheelMove() * camSpeed * dt;
        rl.updateCameraPro(&camera, camMove, rl.Vector3.zero(), 0);

        if (rl.isKeyPressed(.key_p)) positionMode = !positionMode;
        if (rl.isKeyPressed(.key_r) or positionMode) camera = defaultCamera; // reset the camera

        rl.beginDrawing();
            rl.beginTextureMode(renderTarget);
                rl.clearBackground(rl.Color.ray_white);
                rl.beginMode3D(camera);
                    const pose = anim.framePoses[0][0..@intCast(anim.boneCount)];
                    const bindPose = model.bindPose[0..@intCast(anim.boneCount)];
                    const bones = anim.bones[0..@intCast(anim.boneCount)];
                    rotationsFromLandmarks(&calculatedRotations, landmarks);
                    adjustRotationByVisibility(&calculatedRotations, landmarks, bindPose);
                    applyRotations(pose, &calculatedRotations, dt);
                    snapBonesToParent(pose, bones, bindPose);
                    rl.updateModelAnimation(model, anim, 0);

                    model.drawEx(
                        if (positionMode) position.scale(10) else .{ .x = 0, .y = 0, .z = 0 }, 
                        .{ .x = 1, .y = 0, .z = 0 }, 
                        0, 
                        .{ .x = 1, .y = 1, .z = 1 }, 
                        rl.Color.white);
                    // for (anim.framePoses[0], 0..@intCast(anim.boneCount)) |transform, _| {
                    //     rl.drawSphere(transform.translation, 0.1, rl.Color.red);
                    // }
                rl.endMode3D();
            rl.endTextureMode();
            const sourceRect = rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = width * targetResFactor,
                .height = -height * targetResFactor,
            };
            const destRect = rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = width,
                .height = height,
            };
            const factor = (depth / defaultCamera.position.z) * 0.4;
            const resolution: rl.Vector2 = .{ .x = width * factor, .y = height * factor };
            rl.setShaderValue(downscaleShader, dsResolutionLoc, &resolution, .shader_uniform_vec2);
            rl.beginShaderMode(downscaleShader);
                rl.drawTexturePro(renderTarget.texture, sourceRect, destRect, .{ .x = 0, .y = 0 }, 0, rl.Color.white);
            rl.endShaderMode();
        rl.endDrawing();
    }
}

// The direction of bones at 0 rotation is up (+y)
// Quaternion.fromEuler rotation order is ZYX i.e. roll yaw pitch (relative to self)
fn rotationsFromLandmarks(rotations: []rl.Quaternion, landmarks: []const Landmark) void {
    const mouthLeft      = landmarkToVector3(getLandmark(landmarks, .mouth_left));
    const mouthRight     = landmarkToVector3(getLandmark(landmarks, .mouth_right));
    const leftShoulder   = landmarkToVector3(getLandmark(landmarks, .left_shoulder));
    const rightShoulder  = landmarkToVector3(getLandmark(landmarks, .right_shoulder));
    const leftElbow      = landmarkToVector3(getLandmark(landmarks, .left_elbow));
    const rightElbow     = landmarkToVector3(getLandmark(landmarks, .right_elbow));
    const leftWrist      = landmarkToVector3(getLandmark(landmarks, .left_wrist));
    const rightWrist     = landmarkToVector3(getLandmark(landmarks, .right_wrist));
    const leftIndex      = landmarkToVector3(getLandmark(landmarks, .left_index));
    const rightIndex     = landmarkToVector3(getLandmark(landmarks, .right_index));
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
    
    const shouldersMid = leftShoulder.lerp(rightShoulder, 0.5);
    const hipsMid = leftHip.lerp(rightHip, 0.5);
    const localUp = shouldersMid.subtract(hipsMid).normalize();
    
    const shouldersLeft = leftShoulder.subtract(rightShoulder).normalize();
    const shoulderForward = shouldersLeft.crossProduct(localUp).normalize();
    const shouldersUp = shoulderForward.crossProduct(shouldersLeft).normalize();
    
    const hipsLeft = leftHip.subtract(rightHip).normalize();
    const hipsForward = hipsLeft.crossProduct(localUp).normalize();
    const hipsUp = hipsForward.crossProduct(hipsLeft).normalize();
    
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

        var rot = rotationFromUpForward(up, forward).toEuler();
        rot.x *= 2; // exaggerate pitch since it appears to be too little
        getBone(rotations, .head).* = rl.Quaternion.fromEuler(rot.x, rot.y, rot.z);
        getBone(rotations, .neck).* = rotationFromUpForward(localUp, shoulderForward);
    }
    { // right arm
        const up = rightElbow.subtract(rightShoulder).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, 90.0 * math.rad_per_deg);
        
        getBone(rotations, .right_arm).* = rotationFromUpForward(up, forward);
    }
    { // right fore-arm
        const up = rightWrist.subtract(rightElbow).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, 90.0 * math.rad_per_deg);

        getBone(rotations, .right_fore_arm).* = rotationFromUpForward(up, forward);
    }
    { // right hand
        const up = rightIndex.subtract(rightWrist).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, 90.0 * math.rad_per_deg);

        getBone(rotations, .right_hand).* = rotationFromUpForward(up, forward);
    }
    { // left arm
        const up = leftElbow.subtract(leftShoulder).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, -90.0 * math.rad_per_deg);

        getBone(rotations, .left_arm).* = rotationFromUpForward(up, forward);
    }
    { // left fore-arm
        const up = leftWrist.subtract(leftElbow).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, -90.0 * math.rad_per_deg);

        getBone(rotations, .left_fore_arm).* = rotationFromUpForward(up, forward);
    }
    { // left hand
        const up = leftIndex.subtract(leftWrist).normalize();
        const upProj = shoulderForward.crossProduct(up.crossProduct(shoulderForward)).normalize();
        const forward = upProj.rotateByAxisAngle(shoulderForward, -90.0 * math.rad_per_deg);

        getBone(rotations, .left_hand).* = rotationFromUpForward(up, forward);
    }
    { // hips and spine
        getBone(rotations, .hips).* = rotationFromUpForward(
            hipsUp.lerp(shouldersUp, 0.0 ), 
            hipsForward.lerp(shoulderForward, 0.0 ));
        getBone(rotations, .spine).* = rotationFromUpForward(
            hipsUp.lerp(shouldersUp, 0.33), 
            hipsForward.lerp(shoulderForward, 0.33));
        getBone(rotations, .spine1).* = rotationFromUpForward(
            hipsUp.lerp(shouldersUp, 0.66), 
            hipsForward.lerp(shoulderForward, 0.66));
        getBone(rotations, .spine2).* = rotationFromUpForward(
            hipsUp.lerp(shouldersUp, 1.0 ), 
            hipsForward.lerp(shoulderForward, 0.0 ));
    }
    { // right up leg
        const up = rightKnee.subtract(rightHip).normalize();
        const upProj = hipsLeft.crossProduct(up.crossProduct(hipsLeft)).normalize();
        const forward = upProj.rotateByAxisAngle(hipsLeft, -90.0 * math.rad_per_deg);
        
        getBone(rotations, .right_up_leg).* = rotationFromUpForward(up, forward);
    }
    { // right leg
        const up = rightAnkle.subtract(rightKnee).normalize();
        const upProj = hipsLeft.crossProduct(up.crossProduct(hipsLeft)).normalize();
        const forward = upProj.rotateByAxisAngle(hipsLeft, -90.0 * math.rad_per_deg);
        
        getBone(rotations, .right_leg).* = rotationFromUpForward(up, forward);
    }
    { // right foot
        const up = rightFootIndex.subtract(rightAnkle).normalize();
        const upProj = hipsLeft.crossProduct(up.crossProduct(hipsLeft)).normalize();
        const forward = upProj.rotateByAxisAngle(hipsLeft, -90.0 * math.rad_per_deg);
        
        getBone(rotations, .right_foot).* = rotationFromUpForward(up, forward);
    }
    { // right toe base
        const up = rightFootIndex.subtract(rightHeel).normalize();
        const upProj = hipsLeft.crossProduct(up.crossProduct(hipsLeft)).normalize();
        const forward = upProj.rotateByAxisAngle(hipsLeft, -90.0 * math.rad_per_deg);
        
        getBone(rotations, .right_toe_base).* = rotationFromUpForward(up, forward);
    }
    { // left up leg
        const up = leftKnee.subtract(leftHip).normalize();
        const upProj = hipsLeft.crossProduct(up.crossProduct(hipsLeft)).normalize();
        const forward = upProj.rotateByAxisAngle(hipsLeft, -90.0 * math.rad_per_deg);
        
        getBone(rotations, .left_up_leg).* = rotationFromUpForward(up, forward);
    }
    { // left leg
        const up = leftAnkle.subtract(leftKnee).normalize();
        const upProj = hipsLeft.crossProduct(up.crossProduct(hipsLeft)).normalize();
        const forward = upProj.rotateByAxisAngle(hipsLeft, -90.0 * math.rad_per_deg);
        
        getBone(rotations, .left_leg).* = rotationFromUpForward(up, forward);
    }
    { // left foot
        const up = leftFootIndex.subtract(leftAnkle).normalize();
        const upProj = hipsLeft.crossProduct(up.crossProduct(hipsLeft)).normalize();
        const forward = upProj.rotateByAxisAngle(hipsLeft, -90.0 * math.rad_per_deg);
        
        getBone(rotations, .left_foot).* = rotationFromUpForward(up, forward);
    }
    { // left toe base
        const up = leftFootIndex.subtract(leftHeel).normalize();
        const upProj = hipsLeft.crossProduct(up.crossProduct(hipsLeft)).normalize();
        const forward = upProj.rotateByAxisAngle(hipsLeft, -90.0 * math.rad_per_deg);
        
        getBone(rotations, .left_toe_base).* = rotationFromUpForward(up, forward);
    }
}

fn adjustRotationByVisibility(rotations: []rl.Quaternion, landmarks: []const Landmark, bindPose: []rl.Transform) void {
    const leftUpLeg  = getBone(rotations, .left_up_leg);
    const leftLeg    = getBone(rotations, .left_leg);
    const rightUpLeg = getBone(rotations, .right_up_leg);
    const rightLeg   = getBone(rotations, .right_leg);

    leftUpLeg.*  = lerpRotation(leftUpLeg.*,  getBone(bindPose, .left_up_leg ).rotation, 1 - getLandmark(landmarks, .left_hip  ).visibility).normalize();
    leftLeg.*    = lerpRotation(leftLeg.*,    getBone(bindPose, .left_leg    ).rotation, 1 - getLandmark(landmarks, .left_knee ).visibility).normalize();
    rightUpLeg.* = lerpRotation(rightUpLeg.*, getBone(bindPose, .right_up_leg).rotation, 1 - getLandmark(landmarks, .right_hip ).visibility).normalize();
    rightLeg.*   = lerpRotation(rightLeg.*,   getBone(bindPose, .right_leg   ).rotation, 1 - getLandmark(landmarks, .right_knee).visibility).normalize();
}

fn applyRotations(pose: []rl.Transform, rotations: []rl.Quaternion, dt: f32) void {
    std.debug.assert(pose.len == rotations.len);
    const smoothSpeed = 8;
    for (pose, rotations) |*bone, rotation| {
        bone.rotation = lerpRotation(bone.rotation, rotation, smoothSpeed * dt).normalize();
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
        // rl.drawLine3D(parent.translation, bone.translation, rl.Color.magenta);
    }
}

fn rotationFromUpForward(up_: rl.Vector3, forward_: rl.Vector3) rl.Quaternion {
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

// SlerpNear function from: https://stackoverflow.com/a/65599211/22631034
fn slerp(a: rl.Quaternion, b_: rl.Quaternion, t: f32) rl.Quaternion {
    var b = b_;
    var dotAB: f32 = a.dotProduct(b);

    if (dotAB < 0.0)
    {
        dotAB = -dotAB;
        b = b.negate();
    }

    const theta: f32 = math.acos(dotAB);
    const sinTheta: f32 = math.sin(theta);
    const af: f32 = math.sin((1.0 - t) * theta) / sinTheta;
    const bf: f32 = math.sin(t * theta) / sinTheta;

    return a.scale(af).add(b.scale(bf));
}

// From: https://gist.github.com/shaunlebron/8832585?permalink_comment_id=4341756#gistcomment-4341756
fn shortAngleDist(from: f32, to: f32) f32 {
	const turn = math.pi * 2;
	const deltaAngle = @mod(to - from, turn);
	return @mod(2*deltaAngle, turn) - deltaAngle;
}

fn angleLerp(from: f32, to: f32, fraction: f32) f32 {
	return from + shortAngleDist(from, to)*fraction;
}
// end

fn lerpRotation(a: rl.Quaternion, b: rl.Quaternion, t: f32) rl.Quaternion {
    const aEuler = a.toEuler();
    const bEuler = b.toEuler();
    return rl.Quaternion.fromEuler(
        angleLerp(aEuler.x, bEuler.x, t),
        angleLerp(aEuler.y, bEuler.y, t),
        angleLerp(aEuler.z, bEuler.z, t),
    );
}
