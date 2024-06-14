import raylibpy as rl

def main():
    width = 800
    height = 600
    rl.init_window(width, height, "Model animation test")
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
    print(f"{anim}")

    # var pose: [19]rl.Transform = undefined;
    # @memcpy(&pose, model.bindPose);
    # var anim = rl.ModelAnimation{
    #     .boneCount = model.boneCount,
    #     .bones = model.bones,
    #     .frameCount = 1,
    #     .framePoses = &pose,
    #     .name = undefined,
    # };
    # @memset(&anim.name, 0);
    # @memcpy(anim.name[0..4], "Anim");

    frameCounter = 0

    while not rl.window_should_close():
        rl.begin_drawing()
        rl.clear_background(rl.RAYWHITE)

        mouse = rl.get_mouse_position()

        anim.frame_poses[0][0].translation.x = (mouse.x - width / 2) * 0.01

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
