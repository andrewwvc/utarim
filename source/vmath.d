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
alias greal[16] GlMatrix;


struct Vec3
{
    vreal x=0;
    vreal y=0;
    vreal z=0;

    string toString()
    {
        return format("V[",x,", ",y,", ",z,"]");
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
    Vec3 normalise()
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

    string toString()
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
    Quat normalise()
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


//matrix will receive the calculated perspective matrix.
//You would have to upload to your shader
// or use glLoadMatrixf if you aren't using shaders.
void glhPerspectivef2(ref GlMatrix matrix, greal fovyInDegrees, greal aspectRatio,
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

void glhFrustumf2(ref GlMatrix matrix, greal left, greal right, greal bottom, greal top,
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