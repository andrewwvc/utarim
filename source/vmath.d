module vmath;

private
{
	import std.stdio;
	import std.string;
	import std.math;
	import std.traits;
	import std.conv;
}

const float TAU = 2.0*PI;

alias float greal;
alias greal vreal;
alias greal[16] GLMatrix;

struct Vec2
{
	vreal[2] values = 0;

    // vreal x=0;
    // vreal y=0;
	
	@property @nogc {
		vreal x(vreal V) 
		{return values[0] = V;}
		vreal x() const 
		{return values[0];}
		
		vreal y(vreal V) 
		{return values[1] = V;}
		vreal y() const 
		{return values[1];}
	}
	
	this(vreal X, vreal Y) @nogc
		{x=X; y=Y;}
		
	this(const ref Vec3 v3) @nogc
		{x=v3.x; y=v3.y;}

    @property string toString() const
    {
        return stringof;
    }
	
	
	@property string stringof() const
    {
        return format("V[%f, %f]", x, y);
    }
    
    @nogc
    Vec2 opUnary(string op)()  if (op == "-") { return Vec2(-x, -y); }
    
    @nogc
    Vec2 opBinary(string op)(Vec2 rhs) if (op == "+")
    {return Vec2(x+rhs.x, y+rhs.y);}

    @nogc
    Vec2 opBinary(string op)(Vec2 rhs) if (op == "-")
    {return Vec2(x-rhs.x, y-rhs.y);}

    @nogc
    Vec2 mult(vreal mul)
    {
        return Vec2(x*mul, y*mul);
    }

    @nogc
    Vec2 div(vreal den)
    {
        return mult(1/den);
    }

    @nogc
    vreal dot(Vec2 rhs)
    {
        return x*rhs.x +y*rhs.y;
    }

    @nogc
    vreal lengthSqr()
    {
        return x*x+y*y;
    }

    @nogc
    vreal length()
    {
        return sqrt(lengthSqr());
    }

    @nogc
    vreal norm()
    {
        return length();
    }

    //Returns the normalised unit Vector
    @nogc
    Vec2 normalize()
    {
        vreal normInv = 1/length();
        return Vec2(x*normInv, y*normInv);
    }

    @nogc
    auto opBinary(string op)(vreal mul)
    {
        static if (op == "*")
            return mult(mul);
    }
}

struct Vec3
{
	vreal[3] values = 0;

    // vreal x=0;
    // vreal y=0;
    // vreal z=0;
	
	@property @nogc {
		vreal x(vreal V) 
		{return values[0] = V;}
		vreal x() const 
		{return values[0];}
		
		vreal y(vreal V) 
		{return values[1] = V;}
		vreal y() const 
		{return values[1];}
		
		vreal z(vreal V) 
		{return values[2] = V;}
		vreal z() const 
		{return values[2];}
	}
	
	this(vreal X, vreal Y, vreal Z) @nogc
		{x=X; y=Y; z=Z;}
		
	this(const ref Vec2 v2) @nogc
		{x=v2.x; y=v2.y; z=0;}

    @property string toString() const
    {
        return stringof;
    }
	
	
	@property string stringof() const
    {
        return format("V[%f, %f, %f]", x, y, z);
    }
    
    @nogc
    Vec3 opUnary(string op)()  if (op == "-") { return Vec3(-x, -y, -z); }
    
    @nogc
    Vec3 opBinary(string op)(Vec3 rhs) if (op == "+")
    {return Vec3(x+rhs.x, y+rhs.y, z+rhs.z);}

    @nogc
    Vec3 opBinary(string op)(Vec3 rhs) if (op == "-")
    {return Vec3(x-rhs.x, y-rhs.y, z-rhs.z);}

    @nogc
    Vec3 cross(Vec3 rhs)
    {
        return Vec3(y*rhs.z - z*rhs.y,
                    z*rhs.x - x*rhs.z,
                    x*rhs.y - y*rhs.x);
    }

    @nogc
    Vec3 mult(vreal mul)
    {
        return Vec3(x*mul, y*mul, z*mul);
    }

    @nogc
    Vec3 opBinary(string op)(Quat rhs) if (op == "*")
    {
        Quat t = Quat(0,x, y, z);
        t = rhs*t*rhs.conj();
        return Vec3(t.i, t.j, t.k);
    }

    @nogc
    Vec3 div(vreal den)
    {
        return mult(1/den);
    }

    @nogc
    vreal dot(Vec3 rhs)
    {
        return x*rhs.x +y*rhs.y +z*rhs.z;
    }

    @nogc
    vreal lengthSqr()
    {
        return x*x+y*y+z*z;
    }

    @nogc
    vreal length()
    {
        return sqrt(lengthSqr());
    }

    @nogc
    vreal norm()
    {
        return length();
    }

    //Returns the normalised unit Vector
    @nogc
    Vec3 normalize()
    {
        vreal normInv = 1/length();
        return Vec3(x*normInv, y*normInv, z*normInv);
    }

    @nogc
    auto opBinary(string op)(vreal mul)
    {
        static if (op == "*")
            return mult(mul);
    }
}

struct Quat
{
    public vreal w=0.0;
    public vreal i=0.0;
    public vreal j=0.0;
    public vreal k=0.0;

    @nogc
    this(vreal W, vreal I, vreal J, vreal K)
    {
        w=W;
        i=I;
        j=J;
        k=K;
    }

    @nogc
    this(Vec3 v)
    {
        w=0;
        i=v.x;
        j=v.y;
        k=v.z;
    }

    @property string toString() const
    {
        return stringof;
    }
	
	@property string stringof() const
	{
		return format("Q[%f, %f, %f, %f]", w, i, j, k);
    }

    @nogc
    Quat opUnary(string op)() if (op == "-") { return Quat(-w,-i,-j,-k); }
    
    @nogc
    Quat opBinary(string op)(Quat rhs) if (op == "*")
    {
        return Quat(w*rhs.w-i*rhs.i-j*rhs.j-k*rhs.k,
                     w*rhs.i+i*rhs.w+j*rhs.k-k*rhs.j,
                     w*rhs.j+j*rhs.w+k*rhs.i-i*rhs.k,
                     w*rhs.k+k*rhs.w+i*rhs.j-j*rhs.i);
    }

    @nogc
    Quat opBinary(string op)(Quat rhs) if (op == "/")
    {
        return this*conj(rhs);
    }

    @nogc
    Quat opBinary(string op)(Quat rhs) if (op == "+")
    {return Quat(w+rhs.w,
                     i+rhs.i,
                     j+rhs.j,
                     k+rhs.k);}

    @nogc
    Quat opBinary(string op)(Quat rhs) if (op == "-")
    {return Quat(w-rhs.w,
                     i-rhs.i,
                     j-rhs.j,
                     k-rhs.k);}

    @nogc                 
    vreal normSqr()
    {
        return w*w+i*i+j*j+k*k;
    }

    @nogc
    vreal norm()
    {
        return sqrt(normSqr());
    }

    //Returns the normalised unit Quaternion
    @nogc
    Quat normalize()
    {
        greal normInv = 1/norm();
        return Quat(w*normInv, i*normInv, j*normInv, k*normInv);
    }

    //The Quaternion conjugate
    @nogc
    Quat conj()
    {
        return Quat(w,-i,-j,-k);
    }

    @nogc
    auto opBinary(string op)(real val)
    {
        static if (op == "*")
            return Quat(w*val, i*val, j*val, k*val);
        else static if (op == "+" || op == "-")
            return mixin("Quat(w"~op~"val, i, j, k)");
    }

    @nogc
    auto opBinaryRight(string op)(real val)
    {
        static if (op == "+" || op == "*")
            return  mixin("this"~op~"val");
    }

    //This only works for unit quaternions!
    @nogc
    Quat pow(vreal val)
    {
        vreal vecabs = i*i+j*j+k*k;
        vreal a,b,c;

        if (vecabs != 0)
        {
            vecabs = 1/sqrt(vecabs);
            a = i*vecabs;
            b = j*vecabs;
            c = k*vecabs;
        }
        else
        {
            return Quat(1,0,0,0);
        }

        creal theta = expi(acos(w)*val);
        return Quat(theta.re, theta.im*a, theta.im*b, theta.im*c);
    }
    
    @nogc
    GLMatrix quatToMat(Vec3 offset)
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
      
      return 
      [1-jj2-kk2, ij2+wk2,  ki2-wj2,  0,//b.vOffset.i,
      ij2-wk2,  1-ii2-kk2,  jk2+wi2,  0,//b.vOffset.j,
      ki2+wj2,  jk2-wi2,  1-ii2-jj2,  0,//b.vOffset.z,
      offset.x,  offset.y,  offset.z,  1];
    }
}

//NOTE: x^2+y^2+z^2 must equal 1
@nogc
Quat rotationQuat(vreal theta, vreal x, vreal y, vreal z)
{
    return Quat(cos(theta/2), x*sin(theta/2), y*sin(theta/2), z*sin(theta/2));
}

@nogc
Quat rotationQuat(vreal theta, Vec3 vec)
{
    return rotationQuat(theta, vec.x, vec.y, vec.z);
}

@nogc
vreal dotProduct(ref Quat q1, ref Quat q2)
{
  return (q1.w * q2.w) + (q1.i * q2.i) + (q1.j * q2.j) + (q1.k * q2.k);
}

@nogc
Quat lerp(ref Quat q1, ref Quat q2, vreal interp)
{
  return q1*(1.0- interp) + q2*interp;
}

// @nogc
// Quat slerp(ref Quat q1, ref Quat q2, vreal interp, vreal threshold = 0.95f /*Value should be between 0.0 and 1.0*/)
// {
  // vreal cosine = dotProduct(q1, q2);
  
  // if (cosine < 0.0f)
  // {
    // q1.w *= -1.0f;
    // q1.i *= -1.0f;
    // q1.j *= -1.0f;
    // q1.k *= -1.0f;
    // cosine *= -1.0f;
  // }
  
  // if (cosine <= threshold) // spherical interpolation
  // {
    // const vreal theta = acos(cosine);
    // const vreal invsintheta = 1.0/(sin(theta));
    // const vreal scale = sin(theta * (1.0f-interp)) * invsintheta;
    // const vreal invscale = sin(theta * interp) * invsintheta;
    // return ((q1*scale) + (q2*invscale));
  // }
  // else // linear interpolation
  // {
    // return lerp(q1,q2,interp);
  // }
// }

//Modified from https://en.wikipedia.org/wiki/Slerp
@nogc
Quat slerp(Quat v0, Quat v1, vreal t)
{
    // Only unit quaternions are valid rotations.
    // Normalize to avoid undefined behavior.
    v0.normalize();
    v1.normalize();

    // Compute the cosine of the angle between the two vectors.
    vreal dot = v0.dotProduct(v1);

    // If the dot product is negative, slerp won't take
    // the shorter path. Note that v1 and -v1 are equivalent when
    // the negation is applied to all four components. Fix by 
    // reversing one quaternion.
    if (dot < 0.0f) {
        v1 = -v1;
        dot = -dot;
    }  

    const vreal DOT_THRESHOLD = 0.9995;
    if (dot > DOT_THRESHOLD) {
        // If the inputs are too close for comfort, linearly interpolate
        // and normalize the result.

        Quat result = v0 + t*(v1 - v0);
        //result.normalize();
        return result.normalize();
    }

    // Since dot is in range [0, DOT_THRESHOLD], acos is safe
    vreal theta_0 = acos(dot);        // theta_0 = angle between input vectors
    vreal theta = theta_0*t;          // theta = angle between v0 and result
    vreal sin_theta = sin(theta);     // compute this value only once
    vreal sin_theta_0 = sin(theta_0); // compute this value only once

    vreal s0 = cos(theta) - dot * sin_theta / sin_theta_0;  // == sin(theta_0 - theta) / sin(theta_0)
    vreal s1 = sin_theta / sin_theta_0;

    return (s0 * v0) + (s1 * v1);
}

unittest
{
    Quat q1 = Quat(0.0, 0.0, 1.0, 0.0);
	Quat qt = Quat(0.0, 1.0, 0.0, 0.0);
	Quat q2 = q1*qt;
	writeln(q2);
	q2 = qt*q1;
	writeln(q2);
	qt = q1+2*q1;
	writeln(qt);
	Vec3 v1 = Vec3(2,2,2)*qt;
	writeln(v1);

	vreal theta = TAU;
	Quat point = Quat(0, 0, 0, 1);
	Quat rot = Quat(cos(theta/2), sin(theta/2), 0, 0);
	Quat result = rot*point*rot.conj;
	writeln(result);
}

Vec3 transformVec3(in ref GLMatrix mat, in ref Vec3 invec) @nogc
{	
	return Vec3(mat[0]*invec.x + mat[4]*invec.y + mat[8]*invec.z + mat[12],
		mat[1]*invec.x + mat[5]*invec.y + mat[9]*invec.z + mat[13],
		mat[2]*invec.x + mat[6]*invec.y + mat[10]*invec.z + mat[14]);
}

void matrixMultiply(ref GLMatrix lMat, ref GLMatrix rMat, ref GLMatrix outMat) @nogc
{
	for(int ii=0; ii<16; ii+=4)
	{
		for (int jj=0; jj<4; ++jj)
			outMat[ii+jj] = lMat[jj+0]*rMat[ii+0] + lMat[jj+4]*rMat[ii+1] + lMat[jj+8]*rMat[ii+2] + lMat[jj+12]*rMat[ii+3];
	}
}

struct Pill3
{
	vreal radius;
	Vec3 start;
	Vec3 end;
}

struct Sphere3
{
	vreal radius;
	Vec3 point;
}

//Returns true of a collision between a pill and a sphere in 3D space
bool hullPointTest(ref Pill3 pill, ref Sphere3 sphere) @nogc
{
	vreal dist = pill.radius + sphere.radius;
	//printf("dist: %f\n", dist);
	
	Vec3 modPillEnd = pill.end - pill.start;
	//printf("modPillEnd: %s\n", modPillEnd.toString());
	Vec3 modPoint = sphere.point - pill.start;
	//printf("modPoint: %s\n", modPoint.toString());
	vreal modPillLength = modPillEnd.length();
	//printf("modPillLength: %f\n", modPillLength);
	vreal cosPoint = modPillEnd.dot(modPoint)/modPillLength;
	//printf("cosPoint: %f\n", cosPoint);
	if (cosPoint >= modPillLength)
	{
		//printf("(modPillEnd - modPoint): %s\n", (modPillEnd - modPoint).toString());
		return (modPillEnd - modPoint).length <= dist; //end cap
	}
	else if (cosPoint <= 0.0)
	{
		//printf("modPoint.length: %f\n", modPoint.length);
		return modPoint.length <= dist; //start cap
	}
	else //midsection
	{
		Vec3 modPillMid = modPillEnd*(cosPoint/modPillLength);//modPillEnd/cos, provides the projection of
		//printf("modPillMid: %s\n", modPillMid.toString());
		Vec3 distVec = modPoint - modPillMid;
		return distVec.length < dist;
	}
}

//Returns true of a collision between a pill and a sphere in 2D space
bool shellPointTest(ref Pill3 pill, ref Sphere3 sphere)@nogc
{
	vreal dist = pill.radius + sphere.radius;
	
	Vec2 modPillEnd = Vec2(pill.end) - Vec2(pill.start);
	
	Vec2 modPoint = Vec2(sphere.point) - Vec2(pill.start);
	
	vreal modPillLength = modPillEnd.length();
	
	vreal cosPoint = modPillEnd.dot(modPoint)/modPillLength;
	
	if (cosPoint >= modPillLength)
	{
		return (modPillEnd - modPoint).length <= dist; //end cap
	}
	else if (cosPoint <= 0.0)
	{
		return modPoint.length <= dist; //start cap
	}
	else
	{
		Vec2 modPillMid = modPillEnd*(cosPoint/modPillLength);//modPillEnd/cos, provides the projection of
		
		Vec2 distVec = modPoint - modPillMid;
		return distVec.length < dist;
	}
}


//matrix will receive the calculated perspective matrix.
//You would have to upload to your shader
// or use glLoadMatrixf if you aren't using shaders.
void glhPerspectivef2(ref GLMatrix matrix, greal fovyInDegrees, greal aspectRatio,
                      greal znear, greal zfar) @nogc
{
    greal ymax, xmax;
    greal temp, temp2, temp3, temp4;
    ymax = znear * tan(fovyInDegrees * PI / 360.0);
    //ymin = -ymax;
    //xmin = -ymax * aspectRatio;
    xmax = ymax * aspectRatio;
    glhFrustumf2(matrix, -xmax, xmax, -ymax, ymax, znear, zfar);
}

void glhFrustumf2(ref GLMatrix matrix, greal left, greal right, greal bottom, greal top,
                  greal znear, greal zfar) @nogc
{
    greal temp, temp2, temp3, temp4;
    temp = 2.0 * znear;
    temp2 = right - left;
    temp3 = top - bottom;
    temp4 = zfar - znear;
    matrix[0] = temp / temp2;
    matrix[1] = 0.0;
    matrix[2] = 0.0;
    matrix[3] = 0.0;
    matrix[4] = 0.0;
    matrix[5] = temp / temp3;
    matrix[6] = 0.0;
    matrix[7] = 0.0;
    matrix[8] = (right + left) / temp2;
    matrix[9] = (top + bottom) / temp3;
    matrix[10] = (-zfar - znear) / temp4;
    matrix[11] = -1.0;
    matrix[12] = 0.0;
    matrix[13] = 0.0;
    matrix[14] = (-temp * zfar) / temp4;
    matrix[15] = 0.0;
}