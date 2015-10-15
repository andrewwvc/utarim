import bpy
import os

# export to blend file location
basedir = os.path.dirname(bpy.data.filepath)

if not basedir:
    raise Exception("Blend file is not saved")

# Get the armature (this technique assumes it is selected)
armature = bpy.context.active_object
 
# Get bone and pose bone data
bones = armature.data.bones
pose_bones = armature.pose.bones

scene = bpy.context.scene
armature = bpy.context.active_object

f = open(os.path.join(basedir, "animcap") + ".txt", 'w', encoding='utf-8')
 
# Loop through every frame in the scene and get bone pose at each one
for frame in range(scene.frame_end + 1):
    scene.frame_set(frame)
    f.write(str(frame)+'[\n')
    for pose_bone in armature.pose.bones:
        f.write(pose_bone.name)
        f.write('['+str(pose_bone.matrix.to_quaternion().w) +', '+ str(pose_bone.matrix.to_quaternion().x) +', '+ str(pose_bone.matrix.to_quaternion().y) +', '+ str(pose_bone.matrix.to_quaternion().z)+']')
    f.write(']\n')

#for bone in bones:
    
f.close()