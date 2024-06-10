import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import cv2
import ctypes
import struct

import raylibpy as rl

cap = cv2.VideoCapture(0) 

model_path = './models/face_landmarker.task'

BaseOptions = mp.tasks.BaseOptions
FaceLandmarker = mp.tasks.vision.FaceLandmarker
FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
FaceLandmarkerResult = mp.tasks.vision.FaceLandmarkerResult
VisionRunningMode = mp.tasks.vision.RunningMode


result = None
output_image = None
def display_result(_result: FaceLandmarkerResult, _output_image: mp.Image, timestamp_ms: int):
    global result
    global output_image
    result = _result
    output_image = _output_image

options = FaceLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=model_path),
    running_mode=VisionRunningMode.LIVE_STREAM,
    result_callback=display_result)
landmarker = FaceLandmarker.create_from_options(options)

WIDTH = 800
HEIGHT = 600

camera = rl.Camera3D(
    position=rl.Vector3(0.5, 0.5, -1),
    target=rl.Vector3(0.5, 0.5, 0),
    up=rl.Vector3(0, 1, 0),
    fovy=1,
    projection=rl.CAMERA_ORTHOGRAPHIC
)

rl.init_window(WIDTH, HEIGHT, "Virtual Avatar")
rl.set_trace_log_level(rl.LOG_WARNING)

blur_shader = rl.load_shader(None, 'shaders/blur.fs')

render_width_loc = rl.get_shader_location(blur_shader, 'renderWidth')
render_height_loc = rl.get_shader_location(blur_shader, 'renderHeight')

rl.set_shader_value(blur_shader, render_width_loc, struct.pack("i", WIDTH) , rl.SHADER_UNIFORM_INT)
rl.set_shader_value(blur_shader, render_height_loc, struct.pack("i", HEIGHT) , rl.SHADER_UNIFORM_INT)

texture = None

rl.set_target_fps(60)

while not rl.window_should_close():
    ret, frame = cap.read()
    frame_height, frame_width, channels = frame.shape
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
    landmarker.detect_async(mp_image, int(rl.get_time() * 1000))

    display = output_image.numpy_view() if output_image else frame_rgb
    data_ptr = display.ctypes.data_as(ctypes.c_void_p)

    image = rl.Image(
        data=ctypes.cast(data_ptr, ctypes.c_void_p),
        width=frame_width,
        height=frame_height,
        mipmaps=1,
        format_=rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8,
    )
    # rl.unload_image(image) should not be called because it segfaults since the underlying C function tries to free memory allocated by python, let python garbage collect that memory
    
    if texture:
        rl.unload_texture(texture)
    texture = rl.load_texture_from_image(image)


    rl.begin_drawing()

    rl.clear_background(rl.BLACK)

    rl.begin_shader_mode(blur_shader)
    rl.draw_texture_pro(texture, 
        rl.Rectangle(0, 0, frame_width, frame_height), 
        rl.Rectangle(0, 0, WIDTH, HEIGHT), 
        rl.Vector2(0, 0), 
        0, rl.WHITE)
    rl.end_shader_mode()

    # rl.begin_mode3d(camera)
    if result:
        landmarks = result.face_landmarks[0] if len(result.face_landmarks) > 0 else []
        for landmark in landmarks:
            # position = rl.Vector3(1-landmark.x, 1-landmark.y, landmark.z)
            position = rl.Vector2((landmark.x) * WIDTH, (landmark.y) * HEIGHT)
            rl.draw_circle_v(position, 3, rl.RED)
    # rl.end_mode3d()

    rl.end_drawing()

rl.close_window()

landmarker.close()

cap.release() 
cv2.destroyAllWindows() 
