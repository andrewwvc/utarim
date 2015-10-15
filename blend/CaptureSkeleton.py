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

def boneTailMatrix(pb):
    return pb.matrix*mathutils.Matrix.Translation(mathutils.Vector((0, pb.length, 0)))

def relToParent(pb):
    #return mathutils.Matrix()
    return boneTailMatrix(pb.parent).inverted()*pb.matrix

f = open(os.path.join(basedir, "skelcap") + ".txt", 'w', encoding='utf-8')

f.write(str(len(armature.pose.bones))+'\n')

# Loop through every post bone and colwrite the data from each one
for pose_bone in pose_bones:
    f.write(pose_bone.name+'\n')
    f.write(str(pose_bone.length)+'\n')
    par = pose_bone.parent
    
    if par is None:
        f.write('-1\n')
        relMatrix = pose_bone.matrix
        offsetVec = relMatrix.translation
    else:
        f.write(str(list(pose_bones).index(par))+'\n')
        relMatrix = relToParent(pose_bone)
        #offsetVec = relMatrix.translation
        offsetVec = mathutils.Vector((0.0, 0.0, 0.0))
    #write offset NOTE: Currently assumes no offset for child bones
    f.write(str(offsetVec.x)+'\n'+str(offsetVec.y)+'\n'+str(offsetVec.z)+'\n')
    f.write('['+str(pose_bone.matrix.to_quaternion().w) +', '+ str(pose_bone.matrix.to_quaternion().x) +', '+ str(pose_bone.matrix.to_quaternion().y) +', '+ str(pose_bone.matrix.to_quaternion().z)+']\n')
    f.write('<\n')
    for bone in pose_bone.children:
        f.write(str(list(pose_bones).index(bone))+'\n')
    f.write('>\n')

#for bone in bones:
    
f.close()