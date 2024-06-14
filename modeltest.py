import raylibpy as rl
import raymath as rm

def main():
    WIDTH = 800
    HEIGHT = 600
    rl.init_window(WIDTH, HEIGHT, "Model animation test")
    rl.set_target_fps(60)

    camera = rl.Camera(
        position = rl.Vector3( x = 0, y = 5, z = 15 ),
        target = rl.Vector3( x = 0, y = 0, z = 0 ),
        up = rl.Vector3( x = 0, y = 1, z = 0 ),
        fovy = 45,
        projection = rl.CAMERA_PERSPECTIVE
    )

    modelPath = "resources/3d_models/avatar_rigged.glb"

    model = rl.load_model(modelPath)
    
    animCount = 0
    anims = rl.load_model_animations(modelPath, animCount)
    for anim in anims:
        print("%s" % anim.name)

    anim = anims[0]

    frameCounter = 0

    while not rl.window_should_close():
        rl.begin_drawing()
        rl.clear_background(rl.RAYWHITE)

        mouse = rl.get_mouse_position()

        rot = anim.frame_poses[0][5].rotation
        rot.x = (mouse.y - WIDTH / 2) * 0.001
        rot.y = (mouse.x - WIDTH / 2) * 0.001
        anim.frame_poses[0][5].rotation = rm.vector4_normalize(rot)
        
        rl.update_model_animation(model, anim, 0)
        # rl.update_model_animation(model, anim, frameCounter)
        frameCounter = (frameCounter + 1) % anim.frame_count

        rl.begin_mode3d(camera)

        rl.draw_model_ex(model, rl.vector3_zero(), rl.Vector3(1, 0, 0), 0, rl.Vector3(1, 1, 1), rl.WHITE)
        for i in range(anim.bone_count):
            rl.draw_sphere(anim.frame_poses[0][i].translation, 0.1, rl.RED)


        rl.end_mode3d()
        
        rl.end_drawing()
    
    model.unload()
    rl.close_window()

if __name__ == '__main__':
    main()
