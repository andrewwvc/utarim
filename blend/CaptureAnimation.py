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

#f = open(os.path.join(basedir, "animcap") + ".txt", 'w', encoding='utf-8')
for action in acts:
    f = open(os.path.join(basedir, action.name) + ".txt", 'w', encoding='utf-8')
    armature.animation_data.action = action

    f.write(str(len(armature.pose.bones))+'\n')

    currentPoseVal = storePoseBones(pose_bones)

    scene.frame_set(0)
    frameTotal = 0
    # Loop through every frame in the scene and see how many poses are valid
    for frame in range(scene.frame_end+1):
        scene.frame_set(frame)
        candidatePoseVal = storePoseBones(pose_bones)
        if (currentPoseVal != candidatePoseVal):
            frameTotal += 1
            currentPoseVal = storePoseBones(pose_bones)

    f.write(str(frameTotal)+'\n')

    scene.frame_set(0)
    f.write(str(0)+'[\n')
    #NOTE: Assumes the very first bone is the top of the hierarchy, and uses this to ascertain the relative position from the origin
    topVec = pose_bones[0].location
    f.write('[' + str(topVec.x) + ', ' + str(topVec.y) + ', ' + str(topVec.z) + ']\n')
    for pose_bone in pose_bones:
        f.write(str(list(pose_bones).index(pose_bone))+'\n')
        relQuat = relativeMatrix(pose_bone).to_quaternion()
        f.write('['+str(relQuat.w) +', '+ str(relQuat.x) +', '+ str(relQuat.y) +', '+ str(relQuat.z)+']\n')
        
    f.write(']\n')

    currentPoseVal = storePoseBones(pose_bones)

     
    # Loop through every frame in the scene and get bone pose at each one
    for frame in range(scene.frame_end+1):
        scene.frame_set(frame)
        candidatePoseVal = storePoseBones(pose_bones)
        if (currentPoseVal != candidatePoseVal):
            f.write(str(frame)+'[\n')
            #NOTE: Assumes the very first bone is the top of the hierarchy, and uses this to ascertain the relative position from the origin
            topVec = pose_bones[0].location
            f.write('[' + str(topVec.x) + ', ' + str(topVec.y) + ', ' + str(topVec.z) + ']\n')
            for pose_bone in pose_bones:
                f.write(str(list(pose_bones).index(pose_bone))+'\n')
                relQuat = relativeMatrix(pose_bone).to_quaternion()
                f.write('['+str(relQuat.w) +', '+ str(relQuat.x) +', '+ str(relQuat.y) +', '+ str(relQuat.z)+']\n')
            f.write(']\n')
            currentPoseVal = storePoseBones(pose_bones)

    #for bone in bones:
        
    f.close()

#eval('bpy.context.active_object.' + action.fcurves[0].data_path)