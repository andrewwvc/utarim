import derelict.sdl2.sdl;
import derelict.opengl3.gl;
import vmath;
import std.file;
import std.stdio;
import std.string;
import std.math;
import std.traits;
import std.conv;

const int MAX_BONE_CHILDREN = 8;

@nogc
void zeroifyQuat(ref Quat q, vreal threshold = 1.0e-5)
{
  
  if(abs(q.w) < threshold)
    q.w = 0.0;
  if(abs(q.i) < threshold)
    q.i = 0.0;
  if(abs(q.j) < threshold)
    q.j = 0.0;
  if(abs(q.k) < threshold)
    q.k = 0.0;
}

@nogc
void purifyQuat(ref Quat q)
{
  zeroifyQuat(q);
  q.normalise();
}

unittest
{
  auto q1 = zeroifyQuat(Quat(0.0, 0.0, 0.0, 0.0));
  assert(q1.w == 0.0 && q1.i == 0.0 && q1.j == 0.0 && q1.k== 0.0);
  q1 = zeroifyQuat(Quat(1.0, 1.0, 1.0, 1.0));
  assert(q1.w == 1.0 && q1.i == 1.0 && q1.j == 1.0 && q1.k== 1.0);
  q1 = zeroifyQuat(Quat(-1.0, -1.0, -1.0, -1.0));
  assert(q1.w == -1.0 && q1.i == -1.0 && q1.j == -1.0 && q1.k== -1.0);
  q1 = zeroifyQuat(Quat(1.0e-5, 1.0e-5, 1.0e-5, 1.0e-5));
  assert(q1.w == 1.0e-5 && q1.i == 1.0e-5 && q1.j == 1.0e-5 && q1.k== 1.0e-5);
  q1 = zeroifyQuat(Quat(-1.0e-5, -1.0e-5, -1.0e-5, -1.0e-5));
  assert(q1.w == -1.0e-5 && q1.i == -1.0e-5 && q1.j == -1.0e-5 && q1.k== -1.0e-5);
  q1 = zeroifyQuat(Quat(1.0e-7, 1.0e-7, 1.0e-7, 1.0e-7));
  assert(q1.w == 0.0 && q1.i == 0.0 && q1.j == 0.0 && q1.k== 0.0);
  q1 = zeroifyQuat(Quat(-1.0e-7, -1.0e-7, -1.0e-7, -1.0e-7));
  assert(q1.w == 0.0 && q1.i == 0.0 && q1.j == 0.0 && q1.k== 0.0);
}

struct Bone
{
    Quat qRotate;
    Vec3 vOffset;
    //real fHingeAngle, fMin, fMax; //For inverse kinematics
    greal fLength;
    int nJointType;
    int[MAX_BONE_CHILDREN] Child;
    int Parent;
    string sName;

}

struct Skeleton
{
    Bone[] bones;
}

Skeleton makeSkeletonFile(string filename)
{
    Skeleton skl;
    
    int currentBone = 0;
    string lineBuffer;
    
    try
    {
    auto handle = File(filename, "r");

    lineBuffer = handle.readln();
    int noBones = parse!int(lineBuffer);

    skl.bones = new Bone[noBones];
    
    //while("!!!" != (nameBuffer))
    while(null != (lineBuffer = handle.readln()) && currentBone < noBones)
    {
	with (skl.bones[currentBone])
	{


	    sName = lineBuffer;
	    lineBuffer = handle.readln();
	    debug writeln("lb: ", lineBuffer);
	    fLength = parse!double(lineBuffer);
	    lineBuffer = handle.readln();
	    debug writeln("lb: ", lineBuffer);
	    Parent =  parse!int(lineBuffer);

	    //Parse offset
	    lineBuffer = handle.readln();
	    auto vArray = parse!(double[3])(lineBuffer);
	    vOffset.x = vArray[0];
	    vOffset.y = vArray[1];
	    vOffset.z = vArray[2];
	    
	    //Parse rotation quaternion
	    lineBuffer = handle.readln();
	    auto qArray = parse!(double[4])(lineBuffer);
	    qRotate.w = qArray[0];
	    qRotate.i = qArray[1];
	    qRotate.j = qArray[2];
	    qRotate.k = qArray[3];
	    purifyQuat(qRotate);

	    lineBuffer = handle.readln(); //Reads the line with the '<' character.
	    lineBuffer = handle.readln(); //Reads the first Child value.
	    int childNo = 0;
	    while (lineBuffer[0] != '>')
	    {
		//Children will coninue to be read as long as they do no exceed the maximum permissable number of bone children.
		if (childNo < MAX_BONE_CHILDREN)
		{
		    Child[childNo] = parse!int(lineBuffer);
		    ++childNo;
		}
		else
		    throw new Exception(format("Maximum number of bone children exceeded. File: ", filename, " Bone Number: ", currentBone));

		lineBuffer = handle.readln(); //Advances the input untill a line starting with '>' is read.
	    }

	    ++currentBone;
	}
      }
    }
    catch (Exception e)
    {
      debug writeln("currentBone: ", currentBone, "\nname: ", skl.bones[currentBone].sName, "\nlb: ", lineBuffer);
      throw e;
    }

    return skl;
}

Quat[][] makeAnimationFile(Skeleton skl, string filename)
{
    Quat[][] animation;
    
    auto handle = File(filename, "r");
    string lineBuffer;
    
    lineBuffer = handle.readln();
    int noBones = parse!(int)(lineBuffer);
    lineBuffer = handle.readln();
    int noFrames = parse!(int)(lineBuffer);
    
    animation = new Quat[][](noFrames, noBones);
    
    int currentFrame = 0;

    while(null != (lineBuffer = handle.readln()))
    {
      for (int boneNo = 0; boneNo < noBones; ++boneNo)
      {
	//Skips the number lineBuffer
	handle.readln();
	
	lineBuffer = handle.readln();
	auto qArray = parse!(double[4])(lineBuffer);
	{
	  Quat* q = &animation[currentFrame][boneNo];
	  q.w = qArray[0];
	  q.i = qArray[1];
	  q.j = qArray[2];
	  q.k = qArray[3];
	  purifyQuat(*q);
	}
      }
      
      //Skips the closing square bracket
      lineBuffer = handle.readln();
      if (']' != lineBuffer[0])
	throw new Exception("Closing square bracket misplaced");
	
      ++currentFrame;
    }
    
    return animation;
}

Skeleton makePerson()
{
    Skeleton bob;

    bob.bones =  new Bone[16];

    with(bob.bones[0])
    {
        qRotate = rotationQuat(0,0,0,1);
        vOffset = Vec3(0,3,0);
        fLength = 2;
        Child[0..4] = [1,2,3,6];
        Parent = -1;
        sName = "spine";
    }

    with(bob.bones[1])
    {
        qRotate = rotationQuat(0,0,0,1);
        vOffset = Vec3(0,0,0);
        fLength = 1;
        Parent = 0;
        sName = "head";
    }

    with(bob.bones[2])
    {
        qRotate = rotationQuat(TAU*0.25,0,0,-1);
        vOffset = Vec3(0.5,0,0);
        fLength = 2;
        Child[0] = 4;
        Parent = 0;
        sName = "lsholder";
    }

    with(bob.bones[3])
    {
        qRotate = rotationQuat(TAU*0.25,0,0,1);
        vOffset = Vec3(-0.5,0,0);
        fLength = 2;
        Child[0] = 5;
        Parent = 0;
        sName = "rsholder";
    }

    with(bob.bones[4])
    {
        qRotate = rotationQuat(TAU*0.25,0,0,-1);
        vOffset = Vec3(0,0,0);
        fLength = 2;
        Parent = 2;
        sName = "larm";
    }

    with(bob.bones[5])
    {
        qRotate = rotationQuat(TAU*0.25,0,0,1);
        vOffset = Vec3(0,0,0);
        fLength = 2;
        Parent = 3;
        sName = "rarm";
    }

    with(bob.bones[6])
    {
        qRotate = rotationQuat(TAU*0.5,0,0,1);
        vOffset = Vec3(0,-2,0);
        fLength = 3;
        Child[0..2] = [7,8];
        Parent = 0;
        sName = "pelvis";
    }

    with(bob.bones[7])
    {
        qRotate = rotationQuat(0,0,0,1);
        vOffset = Vec3(1,0,0);
        fLength = 3;
        Child[0] = 9;
        Parent = 6;
        sName = "lthigh";
    }

    with(bob.bones[8])
    {
        qRotate = rotationQuat(0,0,0,1);
        vOffset = Vec3(-1,0,0);
        fLength = 3;
        Child[0] = 10;
        Parent = 6;
        sName = "rthigh";
    }

    with(bob.bones[9])
    {
        qRotate = rotationQuat(0,0,0,1);
        vOffset = Vec3(0,0,0);
        fLength = 3;
        Parent = 7;
        sName = "lleg";
    }

    with(bob.bones[10])
    {
        qRotate = rotationQuat(0,0,0,1);
        vOffset = Vec3(0,0,0);
        fLength = 3;
        Parent = 8;
        sName = "rleg";
    }

    return bob;
}

/*
public static GLfloat[] cubeVerts = [
	    -0.5, -0.5, 0.5,  0.5, -0.5, 0.5,   0.5, 0.5, 0.5,    -0.5, 0.5, 0.5,
	    //-0.5, -0.5, -0.5,  0.5, -0.5, -0.5,   0.5, 0.5, -0.5,    -0.5, 0.5, -0.5,
	    0.5, -0.5, 0.5,   0.5, -0.5, -0.5,  0.5, 0.5, -0.5,   0.5, 0.5, 0.5,
	    0.5, -0.5, -0.5,  -0.5, -0.5, -0.5, -0.5, 0.5, -0.5,  0.5, 0.5, -0.5,
	    -0.5, -0.5, -0.5, -0.5, -0.5, 0.5,   -0.5, 0.5, 0.5,  -0.5, 0.5, -0.5];
*/

public const static GLfloat[] cubeVerts = [
	    -0.5, 0.5, 0.5,  0.5, 0.5, 0.5,   -0.5, -0.5, 0.5,    0.5, -0.5, 0.5,
	    -0.5, 0.5, -0.5,  0.5, 0.5, -0.5,   -0.5, -0.5, -0.5,    0.5, -0.5, -0.5];


const  static GLubyte[] indices = [// 24 of indices
		2,3,1,0,
		3,7,5,1,
		7,6,4,5,
		6,2,0,4,
		0,1,5,4,
		3,2,6,7,

                         /*0,1,2,3,
                         4,5,6,7,
                         //8,9,10,11,
                         12,13,14,15,
                         16,17,18,19,
                         20,21,22,23*/];
                         
GLuint cubeID;
                         
void setupCube()
{
  glGenBuffers(1, &cubeID);
  glBindBuffer(GL_ARRAY_BUFFER, cubeID);
  glBufferData(GL_ARRAY_BUFFER, cubeVerts.sizeof, cast(void*)cubeVerts.ptr, GL_STATIC_DRAW);

  // bind with 0, so, switch back to normal pointer operation
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
}


void drawSkeletonMesh(Skeleton skel, Quat[][] frames, real fvalue, bool loop = false) @nogc
{
    void drawBone(int index, Quat[] f, Quat[] g, real interpolation, float col) @nogc
    {
        glColor3f(0.0, col, 1.0-col);

        with (skel.bones[index])
        {
            //Generates an interpolation between frames
            Quat inter_Quat = f[index]*(f[index].conj()*g[index]).pow(interpolation);
            purifyQuat(inter_Quat);

            with (inter_Quat)
            {
                auto ii2 = 2*i*i;
                auto jj2 = 2*j*j;
                auto kk2 = 2*k*k;
                auto ij2 = 2*i*j;
                auto wk2 = 2*w*k;
                auto ki2 = 2*k*i;
                auto wj2 = 2*w*j;
                auto jk2 = 2*j*k;
                auto wi2 = 2*w*i;
                GlMatrix mat =
                [1-jj2-kk2, ij2+wk2,  ki2-wj2,  0,//b.vOffset.i,
                ij2-wk2,  1-ii2-kk2,  jk2+wi2,  0,//b.vOffset.j,
                ki2+wj2,  jk2-wi2,  1-ii2-jj2,  0,//b.vOffset.z,
                vOffset.x,  vOffset.y,  vOffset.z,  1];

                glMultMatrixf(mat.ptr);

                //glTranslatef(b.vOffset.x, b.vOffset.y, b.vOffset.z);
                //glRotatef(b.qRotate.w, b.qRotate.i, b.qRotate.j, b.qRotate.k);
                glTranslatef(0.0, fLength*0.5, 0.0);
                glScalef(1.0, fLength, 1.0);
                glDrawElements(GL_QUADS, cast(uint) indices.length, GL_UNSIGNED_BYTE, cast(const(void)*) indices.ptr);
                glScalef(1.0, 1.0/fLength, 1.0); //This will not work with normal based lighting!
                glTranslatef(0.0, fLength*0.5, 0.0);
            }


            foreach(int ii; Child)
            {
                if (ii != 0)
                {
                    glPushMatrix();
                        drawBone(ii, f, g, interpolation, col*0.8);
                    glPopMatrix();
                }
            }
        }
    }

    glMatrixMode(GL_MODELVIEW);

	glEnableClientState(GL_VERTEX_ARRAY);
        glVertexPointer(3, GL_FLOAT, 0, cubeVerts.ptr);

        //glIndexPointer();

        glColor3f (0.0, 1.0, 0);

        real frame;
        real interp = modf(fvalue, frame);
        uint iframe = cast(uint)(frame);
        foreach(int ii, Bone b; skel.bones)
        {
	  if (b.Parent == -1)
	  {
	    if (loop)
		drawBone(ii, frames[iframe%frames.length], frames[(iframe+1)%frames.length], interp, 1.0);
	    else
		drawBone(ii, frames[cast(uint)(fmin(frame, frames.length-1))], frames[cast(uint)(fmin(frame+1, frames.length-1))], interp, 1.0);
	  }
	}

	glDisableClientState(GL_VERTEX_ARRAY);
} 
