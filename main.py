import ctypes
import struct
import subprocess as sp
import json

import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

import cv2

import raylibpy as rl

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

WIDTH = 800
HEIGHT = 600


result = None
def get_landmarker_result(_result: PoseLandmarkerResult, output_image: mp.Image, timestamp_ms: int):
    global result
    if len(_result.pose_landmarks) > 0:
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


def main():
    cap = cv2.VideoCapture(0)

    options = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=pose_model_path),
        running_mode=VisionRunningMode.LIVE_STREAM,
        result_callback=get_landmarker_result)

    landmarker = PoseLandmarker.create_from_options(options)

    build = sp.run(["zig", "build"], cwd="ModelRenderer")
    if build.returncode != 0: return
    proc = sp.Popen("ModelRenderer/zig-out/bin/ModelRenderer", cwd="ModelRenderer", stdin=sp.PIPE)

    rl.init_window(WIDTH, HEIGHT, "Minime: Tracker")
    rl.set_target_fps(60)
    monitor = rl.get_current_monitor()
    monitor_width = rl.get_monitor_width(monitor)
    monitor_height = rl.get_monitor_height(monitor)
    rl.set_window_position(monitor_width/2 - WIDTH, monitor_height/2 - HEIGHT/2)

    blur_shader = rl.load_shader(None, 'resources/shaders/blur.fs')

    render_width_loc = rl.get_shader_location(blur_shader, 'renderWidth')
    render_height_loc = rl.get_shader_location(blur_shader, 'renderHeight')

    rl.set_shader_value(blur_shader, render_width_loc, struct.pack("i", WIDTH) , rl.SHADER_UNIFORM_INT)
    rl.set_shader_value(blur_shader, render_height_loc, struct.pack("i", HEIGHT) , rl.SHADER_UNIFORM_INT)

    show_cam = False
    blur_cam = True

    while not rl.window_should_close():
        ret, frame = cap.read()
        if ret:
            frame_height, frame_width, _ = frame.shape
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
            landmarker.detect_async(mp_image, int(rl.get_time() * 1000))

        if proc.poll() != None or not proc.stdin.writable(): break
        
        if rl.is_key_pressed(rl.KEY_C): show_cam = not show_cam
        if rl.is_key_pressed(rl.KEY_B): blur_cam = not blur_cam

        rl.begin_drawing()

        rl.clear_background(rl.Color(18, 18, 18, 255))

        
        dest = rl.Rectangle(0, 0, WIDTH, HEIGHT)

        if show_cam and ret:
            if blur_cam: rl.begin_shader_mode(blur_shader)
            rl.set_trace_log_level(rl.LOG_WARNING)
            draw_numpy_image(frame_rgb, dest)
            rl.set_trace_log_level(rl.LOG_ALL)
            if blur_cam: rl.end_shader_mode()

        if result and len(result.pose_landmarks) > 0:
            landmarks_json = json.dumps(result.pose_world_landmarks[0], default=lambda o:o.__dict__)
            proc.stdin.write(bytes(landmarks_json, 'UTF-8'))
            try: proc.stdin.flush() 
            except: break
            draw_pose_landmarks(result.pose_landmarks[0], dest)
        
        TEXT_PAD = 10
        TEXT_SIZE = 24
        TEXT_GAP = 5
        rl.draw_rectangle(0, 0, TEXT_PAD*2 + TEXT_SIZE*10, TEXT_PAD*2 + TEXT_SIZE*2 + TEXT_GAP, rl.color_alpha(rl.BLACK, 0.5))
        rl.draw_text("[C]", TEXT_PAD, TEXT_PAD, TEXT_SIZE, rl.GREEN if show_cam else rl.RED)
        rl.draw_text("Show Camera", TEXT_PAD + TEXT_SIZE * 1.5, TEXT_PAD, TEXT_SIZE, rl.WHITE)
        rl.draw_text("[B]", TEXT_PAD, TEXT_SIZE + TEXT_PAD + TEXT_GAP, TEXT_SIZE, rl.GREEN if blur_cam else rl.RED)
        rl.draw_text("Blur Camera", TEXT_PAD + TEXT_SIZE * 1.5, TEXT_SIZE + TEXT_PAD + TEXT_GAP, TEXT_SIZE, rl.WHITE)

        rl.end_drawing()

    rl.close_window()

    proc.kill()

    landmarker.close()

    cap.release() 
    cv2.destroyAllWindows() 


if __name__ == '__main__':
    main()
