import math
import ctypes
import struct
import copy

import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

import cv2

import raylibpy as rl

from rlights import *

# face_model_path = 'resources/ai_models/face_landmarker.task'
pose_model_path = 'resources/ai_models/pose_landmarker_lite.task'

BaseOptions = mp.tasks.BaseOptions

# FaceLandmarker = mp.tasks.vision.FaceLandmarker
# FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
# FaceLandmarkerResult = mp.tasks.vision.FaceLandmarkerResult
# VisionRunningMode = mp.tasks.vision.RunningMode

PoseLandmarker = mp.tasks.vision.PoseLandmarker
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
PoseLandmarkerResult = mp.tasks.vision.PoseLandmarkerResult
VisionRunningMode = mp.tasks.vision.RunningMode

WIDTH = 1240
HEIGHT = 720


result = None
def get_landmarker_result(_result: PoseLandmarkerResult, output_image: mp.Image, timestamp_ms: int):
    global result
    result = _result

texture = None
def draw_numpy_image(image, dest: rl.Rectangle):
    global texture
    image_height, image_width, _ = image.shape
    data_ptr = image.ctypes.data_as(ctypes.c_void_p)

    image = rl.Image(
            data=ctypes.cast(data_ptr, ctypes.c_void_p),
            width=image_width,
            height=image_height,
            mipmaps=1,
            format_=rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8,
        )
    # rl.unload_image(image) should not be called because it segfaults since the underlying C function tries to free memory allocated by python, let python garbage collect that memory
    
    if texture: rl.unload_texture(texture)
    texture = rl.load_texture_from_image(image)

    rl.draw_texture_pro(texture, 
        rl.Rectangle(0, 0, image_width, image_height), 
        dest, 
        rl.Vector2(0, 0), 
        0, rl.WHITE)


def normal_to_dest(pos: rl.Vector2, dest: rl.Rectangle) -> rl.Vector2:
    return rl.Vector2(
        x = dest.x + pos.x * dest.width,
        y = dest.y + pos.y * dest.height,
    )

def draw_pose_landmarks(landmarks: list, dest: rl.Rectangle):
    NOSE = 0
    LEFT_EYE_INNER = 1
    LEFT_EYE = 2
    LEFT_EYE_OUTER = 3
    RIGHT_EYE_INNER = 4
    RIGHT_EYE = 5
    RIGHT_EYE_OUTER = 6
    LEFT_EAR = 7
    RIGHT_EAR = 8
    MOUTH_LEFT = 9
    MOUTH_RIGHT = 10
    LEFT_SHOULDER = 11
    RIGHT_SHOULDER = 12
    LEFT_ELBOW = 13
    RIGHT_ELBOW = 14
    LEFT_WRIST = 15
    RIGHT_WRIST = 16
    LEFT_PINKY = 17
    RIGHT_PINKY = 18
    LEFT_INDEX = 19
    RIGHT_INDEX = 20
    LEFT_THUMB = 21
    RIGHT_THUMB = 22
    LEFT_HIP = 23
    RIGHT_HIP = 24
    LEFT_KNEE = 25
    RIGHT_KNEE = 26
    LEFT_ANKLE = 27
    RIGHT_ANKLE = 28
    LEFT_HEEL = 29
    RIGHT_HEEL = 30
    LEFT_FOOT_INDEX = 31
    RIGHT_FOOT_INDEX = 32

    LANDMARK_RADIUS = 5
    LANDMARK_COLOR = rl.RED

    LINE_THICK = 2
    LINE_COLOR = rl.WHITE

    rl.draw_line_ex(
        normal_to_dest(landmarks[MOUTH_LEFT], dest),
        normal_to_dest(landmarks[MOUTH_RIGHT], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_EYE_INNER], dest),
        normal_to_dest(landmarks[LEFT_EYE_OUTER], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_EYE_INNER], dest),
        normal_to_dest(landmarks[RIGHT_EYE_OUTER], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_SHOULDER], dest),
        normal_to_dest(landmarks[RIGHT_SHOULDER], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_SHOULDER], dest),
        normal_to_dest(landmarks[RIGHT_SHOULDER], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_SHOULDER], dest),
        normal_to_dest(landmarks[LEFT_ELBOW], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_SHOULDER], dest),
        normal_to_dest(landmarks[RIGHT_ELBOW], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_ELBOW], dest),
        normal_to_dest(landmarks[LEFT_WRIST], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_ELBOW], dest),
        normal_to_dest(landmarks[RIGHT_WRIST], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_WRIST], dest),
        normal_to_dest(landmarks[LEFT_THUMB], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_WRIST], dest),
        normal_to_dest(landmarks[RIGHT_THUMB], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_WRIST], dest),
        normal_to_dest(landmarks[LEFT_INDEX], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_WRIST], dest),
        normal_to_dest(landmarks[RIGHT_INDEX], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_WRIST], dest),
        normal_to_dest(landmarks[LEFT_PINKY], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_WRIST], dest),
        normal_to_dest(landmarks[RIGHT_PINKY], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_INDEX], dest),
        normal_to_dest(landmarks[LEFT_PINKY], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_INDEX], dest),
        normal_to_dest(landmarks[RIGHT_PINKY], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_SHOULDER], dest),
        normal_to_dest(landmarks[LEFT_HIP], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_SHOULDER], dest),
        normal_to_dest(landmarks[RIGHT_HIP], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_HIP], dest),
        normal_to_dest(landmarks[RIGHT_HIP], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_HIP], dest),
        normal_to_dest(landmarks[LEFT_KNEE], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_HIP], dest),
        normal_to_dest(landmarks[RIGHT_KNEE], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_KNEE], dest),
        normal_to_dest(landmarks[LEFT_ANKLE], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_KNEE], dest),
        normal_to_dest(landmarks[RIGHT_ANKLE], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_ANKLE], dest),
        normal_to_dest(landmarks[LEFT_FOOT_INDEX], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_ANKLE], dest),
        normal_to_dest(landmarks[RIGHT_FOOT_INDEX], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_ANKLE], dest),
        normal_to_dest(landmarks[LEFT_HEEL], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_ANKLE], dest),
        normal_to_dest(landmarks[RIGHT_HEEL], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[LEFT_FOOT_INDEX], dest),
        normal_to_dest(landmarks[LEFT_HEEL], dest),
        LINE_THICK, LINE_COLOR
    )
    rl.draw_line_ex(
        normal_to_dest(landmarks[RIGHT_FOOT_INDEX], dest),
        normal_to_dest(landmarks[RIGHT_HEEL], dest),
        LINE_THICK, LINE_COLOR
    )

    for landmark in landmarks:
        position = rl.Vector2(landmark.x, landmark.y)
        rl.draw_circle_v(normal_to_dest(position, dest), LANDMARK_RADIUS, LANDMARK_COLOR)


frame_counter = 0
def draw_avatar(target: rl.RenderTexture, model: rl.Model, anim: rl.ModelAnimation, shader: rl.Shader, dest: rl.Rectangle):
    global frame_counter
    # Hardcoded values specifically for the avatar model
    iota = -1
    HIPS = (iota := iota + 1)
    SPINE = (iota := iota + 1)
    SPINE1 = (iota := iota + 1)
    SPINE2 = (iota := iota + 1)
    NECK = (iota := iota + 1)
    HEAD = (iota := iota + 1)
    LEFT_ARM = (iota := iota + 1)
    LEFT_FORE_ARM = (iota := iota + 1)
    LEFT_HAND = (iota := iota + 1)
    RIGHT_ARM = (iota := iota + 1)
    RIGHT_FORE_ARM = (iota := iota + 1)
    RIGHT_HAND = (iota := iota + 1)
    LEFT_UP_LEG = (iota := iota + 1)
    LEFT_LEG = (iota := iota + 1)
    LEFT_FOOT = (iota := iota + 1)
    LEFT_TOE_BASE = (iota := iota + 1)
    RIGHT_UP_LEG = (iota := iota + 1)
    RIGHT_LEG = (iota := iota + 1)
    RIGHT_FOOT = (iota := iota + 1)
    RIGHT_TOE_BASE = (iota := iota + 1)

    camera = rl.Camera3D(
        position=rl.Vector3(0, 5, 15),
        target=rl.Vector3(0, 0, 0),
        up=rl.Vector3(0, 1, 0),
        fovy=45,
        projection=rl.CAMERA_PERSPECTIVE
    )
    
    cameraPos = struct.pack("fff", camera.position.x, camera.position.y, camera.position.z)
    rl.set_shader_value(shader, shader.locs[rl.SHADER_LOC_VECTOR_VIEW], cameraPos, rl.SHADER_UNIFORM_VEC3)

    mouse = rl.get_mouse_position()
    
    # anim.frame_poses[0][0].translation.x = (mouse.x - WIDTH/2) * 0.1
    
    rl.update_model_animation(model, anim, 5)
    frame_counter = (frame_counter + 1) % anim.frame_count
    
    rl.begin_texture_mode(target)
    rl.clear_background(rl.RAYWHITE)
    
    rl.begin_mode3d(camera)
    rl.draw_model_ex(model, rl.Vector3(0, 0, 0), rl.Vector3(1, 0, 0), 0, rl.Vector3(1, 1, 1), rl.WHITE)

    for i in range(anim.bone_count):
        rl.draw_sphere(anim.frame_poses[0][i].translation, 0.2, rl.RED)
    rl.end_mode3d()
    
    rl.end_texture_mode()

    rl.draw_texture_pro(target.texture, 
        rl.Rectangle(0, 0, target.texture.width, -target.texture.height),
        dest, rl.Vector2(0, 0), 0, rl.WHITE
    )

def main():
    cap = cv2.VideoCapture(0)

    options = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=pose_model_path),
        running_mode=VisionRunningMode.LIVE_STREAM,
        result_callback=get_landmarker_result)

    landmarker = PoseLandmarker.create_from_options(options)

    rl.init_window(WIDTH, HEIGHT, "Minime")
    rl.set_target_fps(60)

    blur_shader = rl.load_shader(None, 'resources/shaders/blur.fs')

    render_width_loc = rl.get_shader_location(blur_shader, 'renderWidth')
    render_height_loc = rl.get_shader_location(blur_shader, 'renderHeight')

    rl.set_shader_value(blur_shader, render_width_loc, struct.pack("i", WIDTH) , rl.SHADER_UNIFORM_INT)
    rl.set_shader_value(blur_shader, render_height_loc, struct.pack("i", HEIGHT) , rl.SHADER_UNIFORM_INT)

    lighting_shader = rl.load_shader('resources/shaders/lighting.vs', 'resources/shaders/lighting.fs')

    lighting_shader.locs[rl.SHADER_LOC_VECTOR_VIEW] = rl.get_shader_location(lighting_shader, "viewPos")
    
    ambientLoc = rl.get_shader_location(lighting_shader, "ambient")
    rl.set_shader_value(lighting_shader, ambientLoc,  struct.pack("ffff", 0.1, 0.1, 0.1, 1.0), rl.SHADER_UNIFORM_VEC4)

    light = create_light(LIGHT_DIRECTIONAL, rl.Vector3(0, 5, 10), rl.Vector3(0, 0, 0), rl.WHITE, lighting_shader)

    avatar_model_path = 'resources/3d_models/avatar_rigged.glb'
    model = rl.load_model(avatar_model_path)
    for i in range(model.material_count):
        model.materials[i].shader = lighting_shader
    
    # anim = rl.ModelAnimation(model.bone_count, 1, model.bones, ctypes.cast(ctypes.pointer(model.bind_pose), rl.TransformPtrPtr), b"Anim")
    anim_count = 1
    anim = rl.load_model_animations(avatar_model_path, anim_count)[0]
    for i in range(anim.frame_count):
        print(f'Frame {i}:')
        print(anim.frame_poses[i])
        for j in range(anim.bone_count):
            print(f'    Bone {j}')
            print(f'     Translation: {anim.frame_poses[i][j].translation}')
            print(f'     Rotation:    {anim.frame_poses[i][j].rotation}')
            print(f'     Scale:       {anim.frame_poses[i][j].scale}')

    for i in range(model.bone_count):
        print(f'    Bone {i}')
        print(f'     Translation: {model.bind_pose[i].translation}')
        print(f'     Rotation:    {model.bind_pose[i].rotation}')
        print(f'     Scale:       {model.bind_pose[i].scale}')
    # exit()
    
    blur_cam = True

    FACTOR = 200
    render_texture = rl.load_render_texture(3 * FACTOR, 2 * FACTOR)

    while not rl.window_should_close():
        ret, frame = cap.read()
        frame_height, frame_width, _ = frame.shape
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
        landmarker.detect_async(mp_image, int(rl.get_time() * 1000))
        
        if rl.is_key_pressed(rl.KEY_B): blur_cam = not blur_cam

        rl.begin_drawing()

        rl.clear_background(rl.Color(18, 18, 18, 255))

        w = WIDTH/2
        cap_h = (frame_height/frame_width) * w
        dest = rl.Rectangle(0, HEIGHT/2 - cap_h/2, w, cap_h)

        if blur_cam: rl.begin_shader_mode(blur_shader)
        rl.set_trace_log_level(rl.LOG_WARNING)
        draw_numpy_image(frame_rgb, dest)
        rl.set_trace_log_level(rl.LOG_ALL)
        if blur_cam: rl.end_shader_mode()

        if result and len(result.pose_landmarks) > 0:
            draw_pose_landmarks(result.pose_landmarks[0], dest)

        aspect = render_texture.texture.height / render_texture.texture.width
        mv_h = w * aspect

        # update_light_values(lighting_shader, light) # not necessary since we don't need to update the light
        draw_avatar(render_texture, model, anim, lighting_shader, rl.Rectangle(WIDTH/2, HEIGHT/2 - mv_h/2, w, mv_h))

        rl.end_drawing()

    rl.unload_render_texture(render_texture)
    rl.close_window()

    landmarker.close()

    cap.release() 
    cv2.destroyAllWindows() 


if __name__ == '__main__':
    main()
