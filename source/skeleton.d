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
  q.normalize();
}

unittest
{
  Quat q1 = Quat(0.0, 0.0, 0.0, 0.0);
  zeroifyQuat(q1);
  assert(q1.w == 0.0 && q1.i == 0.0 && q1.j == 0.0 && q1.k== 0.0);
  q1 = Quat(1.0, 1.0, 1.0, 1.0); zeroifyQuat(q1);
  assert(q1.w == 1.0 && q1.i == 1.0 && q1.j == 1.0 && q1.k== 1.0);
  q1 = Quat(-1.0, -1.0, -1.0, -1.0); zeroifyQuat(q1);
  assert(q1.w == -1.0 && q1.i == -1.0 && q1.j == -1.0 && q1.k== -1.0);
  q1 = Quat(1.0e-5, 1.0e-5, 1.0e-5, 1.0e-5); zeroifyQuat(q1);
  assert(q1.w == 1.0e-5 && q1.i == 1.0e-5 && q1.j == 1.0e-5 && q1.k== 1.0e-5);
  q1 = Quat(-1.0e-5, -1.0e-5, -1.0e-5, -1.0e-5); zeroifyQuat(q1);
  assert(q1.w == -1.0e-5 && q1.i == -1.0e-5 && q1.j == -1.0e-5 && q1.k== -1.0e-5);
  q1 = Quat(1.0e-7, 1.0e-7, 1.0e-7, 1.0e-7); zeroifyQuat(q1);
  assert(q1.w == 0.0 && q1.i == 0.0 && q1.j == 0.0 && q1.k== 0.0);
  q1 = Quat(-1.0e-7, -1.0e-7, -1.0e-7, -1.0e-7); zeroifyQuat(q1);
  assert(q1.w == 0.0 && q1.i == 0.0 && q1.j == 0.0 && q1.k== 0.0);
}

struct Bone
{
    Quat qRotate;
    Vec3 vOffset;
    //real fHingeAngle, fMin, fMax; //For inverse kinematics
    greal fLength;
	GLfloat[24] boneVolume = cubeVerts;
	GLuint boneVolumeID;
	GLfloat[24] boneNormals;
	GLuint boneNormalID;
    int nJointType;
    int[MAX_BONE_CHILDREN] Child;
    int Parent;
    string sName;

}

struct Skeleton
{
    Bone[] bones;
}

struct Animation
{
  Quat[][] frames;
  Vec3[] framePos;
  int[] frameNos;
}

GLfloat[24] generateBoneVolume(greal fLength)
{
	return [
	    -0.25, 0.5*fLength, 0.25,  0.25, 0.5*fLength, 0.25,   -0.25, -0.5*fLength, 0.25,    0.25, -0.5*fLength, 0.25,
	    -0.25, 0.5*fLength, -0.25,  0.25, 0.5*fLength, -0.25,   -0.25, -0.5*fLength, -0.25,    0.25, -0.5*fLength, -0.25];
}

void setupBoneVolumeBuffer(GLuint* volumeID, GLfloat[24]* boneVolume)
{
  glGenBuffers(1, volumeID);
  glBindBuffer(GL_ARRAY_BUFFER, *volumeID);
  glBufferData(GL_ARRAY_BUFFER, boneVolume.sizeof, cast(void*)boneVolume, GL_STATIC_DRAW);

  // bind with 0, so, switch back to normal pointer operation
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
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
		boneVolume = generateBoneVolume(fLength);
		setupBoneVolumeBuffer(&boneVolumeID, &boneVolume);
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

Animation makeAnimationFile(Skeleton skl, string filename)
{
    Animation animation;
    
    auto handle = File(filename, "r");
    string lineBuffer;
    
    lineBuffer = handle.readln(); //Read in number of bones
    int noBones = parse!(int)(lineBuffer);
    lineBuffer = handle.readln();//Read in number of frames
    int noFrames = parse!(int)(lineBuffer);
    
    animation.frames = new Quat[][](noFrames, noBones);
    animation.frameNos = new int[](noFrames);
    animation.framePos = new Vec3[](noFrames);
    
    int currentFrame = 0;

    while(null != (lineBuffer = handle.readln()))
    {
      //Read frame number
      animation.frameNos[currentFrame] = parse!(int)(lineBuffer);
      
      //Read relative position vector
      lineBuffer = handle.readln();
      auto tempPos = parse!(double[3])(lineBuffer);
      animation.framePos[currentFrame] = Vec3(tempPos[0], tempPos[1], tempPos[2]);
      
      for (int boneNo = 0; boneNo < noBones; ++boneNo)
      {
	//Skips the number lineBuffer
	handle.readln();
	
	lineBuffer = handle.readln();
	auto qArray = parse!(double[4])(lineBuffer);
	{
	  Quat* q = &(animation.frames)[currentFrame][boneNo];
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

// public const static GLfloat[] cubeVerts = [
	    // -0.5, 0.5, 0.5,  0.5, 0.5, 0.5,   -0.5, -0.5, 0.5,    0.5, -0.5, 0.5,
	    // -0.5, 0.5, -0.5,  0.5, 0.5, -0.5,   -0.5, -0.5, -0.5,    0.5, -0.5, -0.5];
		
public const static GLfloat[] cubeVerts = [
	    -0.25, 0.5, 0.25,  0.25, 0.5, 0.25,   -0.25, -0.5, 0.25,    0.25, -0.5, 0.25,
	    -0.25, 0.5, -0.25,  0.25, 0.5, -0.25,   -0.25, -0.5, -0.25,    0.25, -0.5, -0.25];
		
public const static GLfloat invSqrt3 = 1/sqrt(cast(GLfloat)(3.0f));
public const static GLfloat invSqrt2 = 1/sqrt(cast(GLfloat)(2.0f));
		
public const static GLfloat[] cubeNormals = [
	    -invSqrt3, invSqrt3, invSqrt3,  invSqrt3, invSqrt3, invSqrt3,   -invSqrt3, -invSqrt3, invSqrt3,    invSqrt3, -invSqrt3, invSqrt3,
	    -invSqrt3, invSqrt3, -invSqrt3,  invSqrt3, invSqrt3, -invSqrt3,   -invSqrt3, -invSqrt3, -invSqrt3,    invSqrt3, -invSqrt3, -invSqrt3];
		
public const static GLfloat[] cubeNormalsSideways = [
	    -invSqrt2, 0, invSqrt2,  invSqrt2, 0, invSqrt2,   -invSqrt2, 0, invSqrt2,    invSqrt2, 0, invSqrt2,
	    -invSqrt2, 0, -invSqrt2,  invSqrt2, 0, -invSqrt2,   -invSqrt2, 0, -invSqrt2,    invSqrt2, -0, -invSqrt2];


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


void drawSkeletonMesh(ref Skeleton skel, ref Animation anim, real fvalue, bool loop = false) @nogc
{
    void drawBone(int index, Quat[] f, Quat[] g, vreal interpolation, float col) @nogc
    {
        glColor3f(0.0, col, 1.0-col);
        
        glPushMatrix();

	  with (skel.bones[index])
	  {
	      //Generates an interpolation between frames
	      //Quat inter_Quat = f[index]*(f[index].conj()*g[index]).pow(interpolation);
	      Quat inter_Quat = slerp(f[index], g[index], interpolation);
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
		  GLMatrix mat =
		  [1-jj2-kk2, ij2+wk2,  ki2-wj2,  0,//b.vOffset.i,
		  ij2-wk2,  1-ii2-kk2,  jk2+wi2,  0,//b.vOffset.j,
		  ki2+wj2,  jk2-wi2,  1-ii2-jj2,  0,//b.vOffset.z,
		  vOffset.x,  vOffset.y,  vOffset.z,  1];

		  glMultMatrixf(mat.ptr);

		  //glTranslatef(b.vOffset.x, b.vOffset.y, b.vOffset.z);
		  //glRotatef(b.qRotate.w, b.qRotate.i, b.qRotate.j, b.qRotate.k);
		  glTranslatef(0.0, fLength*0.5, 0.0);
		  //glScalef(1.0, fLength, 1.0);
		  glVertexPointer(3, GL_FLOAT, 0, boneVolume.ptr);
		  glNormalPointer(GL_FLOAT, 0, cubeNormals.ptr);
		  glDrawElements(GL_QUADS, cast(uint) indices.length, GL_UNSIGNED_BYTE, cast(const(void)*) indices.ptr);
		  //glScalef(1.0, 1.0/fLength, 1.0); //This will not work with normal based lighting!
		  glTranslatef(0.0, fLength*0.5, 0.0);
	      }


	      foreach(int ii; Child)
	      {
			  if (ii != 0)
			  {
				drawBone(ii, f, g, interpolation, col*0.8);
			  }
	      }
	  }
	  
        glPopMatrix();
    }
    

    glMatrixMode(GL_MODELVIEW);

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_NORMAL_ARRAY);
	
        glVertexPointer(3, GL_FLOAT, 0, cubeVerts.ptr);

        //glIndexPointer();

        glColor3f (0.0, 1.0, 0);
        
        
        with (anim)
        {
			
		  int maxFrame = frameNos[$-1];
		  int minFrame = frameNos[0];
		  //printf("len: %i\n", maxFrame);
		  
		  if (true)
		  {
			real frame;
			real interp = modf(fvalue, frame);
			foreach(int ii, Bone b; skel.bones)
			{
			  if (b.Parent == -1)
			  {
				if (loop)
				{
					uint iframe = cast(uint)(frame);
					drawBone(ii, frames[iframe%$], frames[(iframe+1)%$], interp, 1.0);
				}
				else
				{
					drawBone(ii, frames[cast(uint)(fmin(frame, $-1))], frames[cast(uint)(fmin(frame+1, $-1))], interp, 1.0);
				}
			  }
			}
		  }
		  else
		  {
			//Find frames
			int fseed = 0;
			
			vreal internalVal = (fvalue % (maxFrame-minFrame)) + minFrame;
			if (internalVal >= maxFrame)
			  internalVal = minFrame;
			
			//printf("intVal: %f\n", internalVal);
			while (!(frameNos[fseed] <= internalVal && internalVal < frameNos[fseed+1]))
			  {++fseed;}
			  
			internalVal = (internalVal - frameNos[fseed]) / (frameNos[fseed+1]-frameNos[fseed]);
			
			Vec3 posA = anim.framePos[fseed].mult(1.0-internalVal);
			Vec3 posB = anim.framePos[fseed+1].mult(internalVal);
			Vec3 pos = posA+posB;
			
			glTranslatef(pos.x, pos.y, pos.z);
			  
			  foreach(int ii, Bone b; skel.bones)
			  {
			if (b.Parent == -1)
			{
			  drawBone(ii, frames[fseed], frames[fseed+1], internalVal, 1.0);
			}
			  }
			glTranslatef(-pos.x, -pos.y, -pos.z);
		  }
		}
	
	glDisableClientState(GL_NORMAL_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
}

//fvalue = frame, ivalue = interpolation between anim1 and anim2
void drawSkeletonMeshInterpolated(ref Skeleton skel, ref Animation anim1, ref Animation anim2, real fvalue1, real fvalue2, real ivalue, bool loop = false) @nogc
{
    void drawBone(int index, Quat[] f1, Quat[] g1, Quat[] f2, Quat[] g2, vreal interpolation1, vreal interpolation2, float col) @nogc
    {
        glColor3f(0.0, col, 1.0-col);
        
        glPushMatrix();

	  with (skel.bones[index])
	  {
	      //Generates an interpolation between frames
	      //Quat inter_Quat = f[index]*(f[index].conj()*g[index]).pow(interpolation);
	      Quat inter_Quat1 = slerp(f1[index], g1[index], interpolation1);
		  Quat inter_Quat2 = slerp(f2[index], g2[index], interpolation2);
		  Quat inter_Quat = slerp(inter_Quat1, inter_Quat2, ivalue);
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
			  GLMatrix mat =
			  [1-jj2-kk2, ij2+wk2,  ki2-wj2,  0,//b.vOffset.i,
			  ij2-wk2,  1-ii2-kk2,  jk2+wi2,  0,//b.vOffset.j,
			  ki2+wj2,  jk2-wi2,  1-ii2-jj2,  0,//b.vOffset.z,
			  vOffset.x,  vOffset.y,  vOffset.z,  1];

			  glMultMatrixf(mat.ptr);

			  //glTranslatef(b.vOffset.x, b.vOffset.y, b.vOffset.z);
			  //glRotatef(b.qRotate.w, b.qRotate.i, b.qRotate.j, b.qRotate.k);
			  glTranslatef(0.0, fLength*0.5, 0.0);
			  //glScalef(1.0, fLength, 1.0);
			  glVertexPointer(3, GL_FLOAT, 0, boneVolume.ptr);
			  glNormalPointer(GL_FLOAT, 0, cubeNormals.ptr);
			  glDrawElements(GL_QUADS, cast(uint) indices.length, GL_UNSIGNED_BYTE, cast(const(void)*) indices.ptr);
			  //glScalef(1.0, 1.0/fLength, 1.0); //This will not work with normal based lighting!
			  glTranslatef(0.0, fLength*0.5, 0.0);
	      }


	      foreach(int ii; Child)
	      {
			  if (ii != 0)
			  {
				drawBone(ii, f1, g1, f2, g2, interpolation1, interpolation2, col*0.8);
			  }
	      }
	  }
	  
        glPopMatrix();
    }
    

    glMatrixMode(GL_MODELVIEW);

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_NORMAL_ARRAY);
	
        glVertexPointer(3, GL_FLOAT, 0, cubeVerts.ptr);

        //glIndexPointer();

        glColor3f (0.0, 1.0, 0);
        
        
		  int maxFrame1 = anim1.frameNos[$-1];
		  int minFrame1 = anim1.frameNos[0];
		  int maxFrame2 = anim2.frameNos[$-1];
		  int minFrame2 = anim2.frameNos[0];
		  //printf("len: %i\n", maxFrame);
		  
		  
		  //Correct this code amd get rid of the extra else statement.
		  if (true)
		  {
			real frame1;
			real frame2;
			real interp1 = modf(fvalue1, frame1);
			real interp2 = modf(fvalue2, frame2);
			foreach(int ii, Bone b; skel.bones)
			{
			  if (b.Parent == -1)
			  {
				if (loop)
				{
					uint iframe1 = cast(uint)(frame1);
					uint iframe2 = cast(uint)(frame2);
					drawBone(ii, anim1.frames[iframe1%$], anim1.frames[(iframe1+1)%$], anim2.frames[iframe2%$], anim2.frames[(iframe2+1)%$], interp1, interp2, 1.0);
				}
				else
				{
					drawBone(ii, anim1.frames[cast(uint)(fmin(frame1, $-1))], anim1.frames[cast(uint)(fmin(frame1+1, $-1))], anim2.frames[cast(uint)(fmin(frame2, $-1))], anim2.frames[cast(uint)(fmin(frame2+1, $-1))], interp1, interp2, 1.0);
				}
			  }
			}
		  }
		  else
		  {
			// //Find frames
			// int fseed1 = 0;
			
			// vreal internalVal1 = (fvalue1 % (maxFrame1-minFrame1)) + minFrame1;
			// if (internalVal1 >= maxFrame1)
			  // internalVal1 = minFrame1;
			
			// vreal internalVal2 = (fvalue1 % (maxFrame2-minFrame2)) + minFrame2;
			// if (internalVal2 >= maxFrame2)
			  // internalVal2 = minFrame2;
			
			// //printf("intVal: %f\n", internalVal);
			// while (!(anim1.frameNos[fseed1] <= internalVal1 && internalVal1 < anim1.frameNos[fseed1+1]))
			  // {++fseed1;}
			  
			// while (!(anim2.frameNos[fseed2] <= internalVal2 && internalVal2 < anim2.frameNos[fseed2+1]))
			  // {++fseed2;}
			  
			// internalVal1 = (internalVal1 - anim1.frameNos[fseed1]) / (anim1.frameNos[fseed1+1]-anim1.frameNos[fseed1]);
			// internalVal2 = (internalVal2 - anim2.frameNos[fseed2]) / (anim2.frameNos[fseed2+1]-anim2.frameNos[fseed2]);
			
			// Vec3 posA1 = anim1.framePos[fseed1].mult(1.0-internalVal1);
			// Vec3 posB1 = anim1.framePos[fseed1+1].mult(internalVal1);
			// Vec3 pos1 = posA1+posB1;
			// Vec3 posA2 = anim2.framePos[fseed2].mult(1.0-internalVal2);
			// Vec3 posB2 = anim2.framePos[fseed2+1].mult(internalVal2);
			// Vec3 pos2 = posA2+posB2;
			
			// Vec3 pos = (pos1+pos2)*0.5;
			
			// glTranslatef(pos.x, pos.y, pos.z);
			  
			  // foreach(int ii, Bone b; skel.bones)
			  // {
				// if (b.Parent == -1)
				// {
					// drawBone(ii, anim1.frames[fseed1], anim1.frames1[fseed1+1], anim2.frames[fseed2], anim2.frames[fseed2], internalVal, 1.0);
				// }
			  // }
			// glTranslatef(-pos.x, -pos.y, -pos.z);
		  }
	
	glDisableClientState(GL_NORMAL_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
}


bool testSkeletonBall(ref Skeleton skel, ref Animation anim, real fvalue, ref GLMatrix posMat, ref Sphere3[] balls) @nogc
{
    bool testBone(int index, Quat[] f, Quat[] g, vreal interpolation, ref GLMatrix newMat) @nogc
    {
        //glPushMatrix();

	  with (skel.bones[index])
	  {
	      //Generates an interpolation between frames
	      //Quat inter_Quat = f[index]*(f[index].conj()*g[index]).pow(interpolation);
	      Quat inter_Quat = slerp(f[index], g[index], interpolation);
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
			  GLMatrix mat =
			  [1-jj2-kk2, ij2+wk2,  ki2-wj2,  0,//b.vOffset.i,
			  ij2-wk2,  1-ii2-kk2,  jk2+wi2,  0,//b.vOffset.j,
			  ki2+wj2,  jk2-wi2,  1-ii2-jj2,  0,//b.vOffset.z,
			  vOffset.x,  vOffset.y+fLength,  vOffset.z,  1];
			  
			  GLMatrix outmat=void;
			  matrixMultiply(newMat, mat, outmat);
			  

			  //glMultMatrixf(mat.ptr);

			  // glTranslatef(0.0, fLength*0.5, 0.0);
			  // glScalef(1.0, fLength, 1.0);
			  // glDrawElements(GL_QUADS, cast(uint) indices.length, GL_UNSIGNED_BYTE, cast(const(void)*) indices.ptr);
			  // glScalef(1.0, 1.0/fLength, 1.0); //This will not work with normal based lighting!
			  // glTranslatef(0.0, fLength*0.5, 0.0);
			  auto startV = Vec3(0,0-fLength,0);
			  auto endV = Vec3(0,0,0);
			  
			  auto p3 = Pill3(0.5, transformVec3(outmat, startV), transformVec3(outmat, endV));
			  foreach (Sphere3 b; balls)
			  {
				  if (hullPointTest(p3, b))
					return true;
			  }
	      
			bool areChildrenHit = false;

			  foreach(int ii; Child)
			  {
				  if (ii != 0)
				  {
					 if (testBone(ii, f, g, interpolation, outmat))
						return true;
				  }
			  }
		  
			return false;
		  }
		}
	  
        //glPopMatrix();
    }

        
    with (anim)
    {
        
	  int maxFrame = frameNos[$-1];
	  int minFrame = frameNos[0];

	    real frame;
	    real interp = modf(fvalue, frame);
	    foreach(int ii, Bone b; skel.bones)
	    {
	      if (b.Parent == -1)
	      {
		    if (testBone(ii, frames[cast(uint)(fmin(frame, $-1))], frames[cast(uint)(fmin(frame+1, $-1))], interp, posMat))
				return true;
	      }
	    }
	  
	}
	return false;
} 