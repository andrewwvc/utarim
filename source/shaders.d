module shaders;

import skeleton;
import derelict.sdl2.sdl;
import derelict.opengl3.gl;
import vmath;
import std.stdio;
import std.string : toStringz;
import std.math;
import std.traits;
import std.conv;

//matrix will receive the calculated perspective matrix.
//You would have to upload to your shader
// or use glLoadMatrixf if you aren't using shaders.
void glhPerspectivef2(ref float[16] matrix, float fovyInDegrees, float aspectRatio,
                      float znear, float zfar) @nogc
{
    float ymax, xmax;
    float temp, temp2, temp3, temp4;
    ymax = znear * tan(fovyInDegrees * PI / 360.0);
    //ymin = -ymax;
    //xmin = -ymax * aspectRatio;
    xmax = ymax * aspectRatio;
    glhFrustumf2(matrix, -xmax, xmax, -ymax, ymax, znear, zfar);
}

void glhFrustumf2(ref float[16] matrix, float left, float right, float bottom, float top,
                  float znear, float zfar) @nogc
{
    float temp, temp2, temp3, temp4;
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

class Shader
{
	protected GLuint shader = 0;

	public ~this()
	{
		glDeleteShader(shader);
	}

// 	public bool loadShaderFromFile(GLenum type, string filename)
// 	{
// 		try
// 		{
// 			shader = glCreateShader(type);
// 			string code = readText(filename);
// 			return loadShader(code);
// 		}
// 		catch (Exception)
// 		{
// 			return false;
// 		}
// 	}

	protected bool loadShader(GLenum type, string code)
	{
		const char* ptr = code.ptr;
		int len = cast(int) code.length;
		
		shader = glCreateShader(type);

		glShaderSource(shader, 1, &ptr, &len);

		glCompileShader(shader);

		return true;
	}
}

class Program
{
	protected GLuint program;

	public this() @nogc
	{
		program = glCreateProgram();
	}

	public ~this() @nogc
	{
		glDeleteProgram(program);
	}

	public void attachShader(Shader shader) @nogc
	{
		glAttachShader(program, shader.shader);
	}

	public void link() @nogc
	{
		glLinkProgram(program);
	}

	public void use() @nogc
	{
		glUseProgram(program);
	}

	static void useFixed() @nogc
	{
		glUseProgram(0);
	}

	public GLint getUniformLocation(string name)
	{
		return glGetUniformLocation(program, toStringz(name));
	}
}

Shader mVertexShader;
Shader mFragmentShader;
Program mProgram; 



class ManBody
{
    const cfloat rotation = cos(TAU/64.0) + 1i*sin(TAU/64.0);

    //Remember to add uniform declerations to shader programs.
    const static auto uniformV = [ ["double", "time", "0", "time += dt", "1f"],
                            ["creal", "rot", "0 - 1i", "(rot *= rotation).re", "1f"]];

    alias ForeachType!(typeof(uniformV)) stringArray;

    static string genMembers()
    {
        string accum = "";

        foreach (stringArray var; uniformV)
        {
            accum ~= ("private " ~ var[0] ~ ' ' ~ var[1] ~ ";"
                ~ "private GLint " ~ var[1]~"Loc;");
        }

        return accum;
    }

    static genInit()
    {
        string accum = "";

        foreach (stringArray var; uniformV)
        {
            accum ~= (var[1]~" = "~var[2]~";");
        }

        return accum;
    }

    static string genSetup()
    {
        string accum = "";

        foreach (stringArray var; uniformV)
        {
            accum ~= (var[1]~"Loc = program.getUniformLocation(\""~var[1]~"\");");
        }

        return accum;
    }

    static string genUpdate()
    {
        string accum = "";

        foreach (stringArray var; uniformV)
        {
            accum ~= ("glUniform"~var[4]~"("~var[1]~"Loc, "~var[3]~" );");
        }

        return accum;
    }
    
    static string genVertexVars()
    {
	string accum = "";

        foreach (stringArray var; uniformV)
        {
            accum ~= ("uniform float "~var[1]~";\n");
        }

        return accum;
    }
    
    static void createShaders()
    {
	  mVertexShader = new Shader();
	  //vertexShader.loadShaderFromFile(GL_VERTEX_SHADER, "shader.vert"); TODO
	  mVertexShader.loadShader(GL_VERTEX_SHADER,
			  genVertexVars()~r"
			  void main()
			  {

			      gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
			      gl_FrontColor = gl_Color * (0.5 + 0.3 * sin(time)+ 0.2 * rot);
			  }"
	  );

	  Shader mFragmentShader = new Shader();
	  //fragmentShader.loadShaderFromFile(GL_FRAGMENT_SHADER, "shader.frag"); TODO
	  mFragmentShader.loadShader(GL_FRAGMENT_SHADER,
			  r"void main()
			  {
			      gl_FragColor = gl_Color;
			  }"
	  );

	  mProgram = new Program();
	  mProgram.attachShader(mVertexShader);
	  mProgram.attachShader(mFragmentShader);
	  mProgram.link();
	  mProgram.use();
    }
// 
	private uint height;
	private uint width;
	private uint bitsPerPixel;
	private float fov;
	private float nearPlane;
	private float farPlane;

	private Program program;
	Skeleton dummy;

    mixin(genMembers());

	public this()
	{
		

	    mixin(genInit());
	    setupShaders();
	    dummy = makePerson();
	}


	private void setupShaders()
	{
		program = mProgram;
		mixin(genSetup());
	}

	
	//NOTE: This function should only be called once, when rendering and in which the appropriate shaders are set up
	public void update(double dt) @nogc
	{
	    mixin(genUpdate());
	}


	public void render() @nogc
	{
	  glMatrixMode(GL_MODELVIEW);
	  glPushMatrix();
	    glRotatef(time*2.0, 0.0, 1.0, 0.0);

	    static Quart[][] frames = [[Quart(1,0,0,0), Quart(1,0,0,0),
	      rotationQuart(TAU*0.25,0,0,-1), rotationQuart(TAU*0.25,0,0,1),
	      rotationQuart(TAU*0.25,0,0,-1), rotationQuart(TAU*0.25,0,0,1),
	      rotationQuart(TAU*0.5,0,0,1),
	      Quart(1,0,0,0), Quart(1,0,0,0), Quart(1,0,0,0), Quart(1,0,0,0)],

	      [ rotationQuart(TAU*0.5,0,1,0) /*Quart(1,0,0,0)*/, Quart(1,0,0,0),
	      rotationQuart(TAU*0 ,0,0,-1), rotationQuart(0,0,0,1),
	      rotationQuart(TAU*0.3,0,0,-1), rotationQuart(TAU*0.2,0,0,1),
	      rotationQuart(TAU/10,-1,0,0)*rotationQuart(TAU*0.4,0,0,1),
	      Quart(1,0,0,0), Quart(1,0,0,0), Quart(1,0,0,0), Quart(1,0,0,0)],

	      [ rotationQuart(TAU*1.0,0,1,0) /*Quart(1,0,0,0)*/, Quart(1,0,0,0),
	      rotationQuart(TAU*0.25,0,0,-1), rotationQuart(TAU*0.25,0,0,1)*rotationQuart(TAU*0.25,0,1,0),
	      rotationQuart(TAU*0.25,0,0,-1), rotationQuart(TAU*0.25,0,0,1),
	      rotationQuart(TAU/10,-1,0,0)*rotationQuart(TAU*0.6,0,0,1),
	      Quart(1,0,0,0), Quart(1,0,0,0), Quart(1,0,0,0), Quart(1,0,0,0)]];

	    //frames[0][5] = frames[0][5].pow(0.99);
	    drawSkeletonMesh(dummy, frames, time*0.5, true);
	  glPopMatrix();
	}
}
