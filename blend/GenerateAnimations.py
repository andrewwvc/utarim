import bpy
import os
import mathutils

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
acts = bpy.data.actions

def boneTailMatrix(pb):
    return pb.matrix*mathutils.Matrix.Translation(mathutils.Vector((0, pb.length, 0)))

def relToParent(pb):
    #return mathutils.Matrix()
    return boneTailMatrix(pb.parent).inverted()*pb.matrix

def relativeMatrix(pb):
    par = pb.parent
    if par is None:
        return pose_bone.matrix
    else:
        return relToParent(pb)
    
def storePoseBones(pbs):
    return [pb.matrix.copy() for pb in pbs]
        


for action in acts:
    f = open(os.path.join(basedir, action.name) + ".txt", 'w', encoding='utf-8')
    f.write(str(len(armature.pose.bones))+'\n')
    
    frame_position_set = set()
    armature.animation_data.action = action
    for fcu in action.fcurves:
        for kf in fcu.keyframe_points:
            frame_position_set.add(int(kf.co[0]))
    frame_list = list(frame_position_set)
    frame_list.sort()
    frameTotal = len(frame_list)
    f.write(str(frameTotal)+'\n')
    
    for frame in frame_list:
        scene.frame_set(frame)
        f.write(str(frame)+'[\n')
        for pose_bone in pose_bones:
            f.write(str(list(pose_bones).index(pose_bone))+'\n')
            relQuat = relativeMatrix(pose_bone).to_quaternion()
            f.write('['+str(relQuat.w) +', '+ str(relQuat.x) +', '+ str(relQuat.y) +', '+ str(relQuat.z)+']\n')
        f.write(']\n')
    
    f.close()


currentPoseVal = storePoseBones(pose_bones)