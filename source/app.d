import std.stdio;
import core.memory;
import derelict.sdl2.sdl;
import derelict.opengl3.gl;
//import m3.m3;
import vmath;
import skeleton;
import manbody;
import core.time;
import core.thread;
import collisiondet;

import allocator.building_blocks.free_list;
import allocator.mallocator;
import std.traits;
import std.conv;
import std.meta;

//Screen dimension constants
const int SCREEN_WIDTH = 1280;
const int SCREEN_HEIGHT = 1024;

SDL_Window* gWindow;

//OpenGL context
SDL_GLContext gContext;

//Render flag
bool gRenderQuad = false;

//Graphics program
GLuint gProgramID = 0;
GLint gVertexPos2DLocation = -1;
GLuint gVBO = 0;
GLuint gIBO = 0;

//skeletons
ManBody man1, man2;

void setupSkelGL()
{
    uint height = SCREEN_HEIGHT;
    uint width = SCREEN_WIDTH;
    uint bitsPerPixel= 24;
    float fov = 90;
    float nearPlane = 1.0f;
    float farPlane = 100.0f;

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    //glDepthFunc(GL_LEQUAL);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    //gluPerspective(fov, cast(float)height / width, nearPlane, farPlane);
    GLMatrix matrix;
    glhPerspectivef2(matrix, fov, cast(float)height / cast(float)width, nearPlane, farPlane);
    debug printf("%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n", matrix[0], matrix[1], matrix[2], matrix[3],  matrix[4], matrix[5], matrix[6], matrix[7],
    matrix[8], matrix[9], matrix[10], matrix[11],  matrix[12], matrix[13], matrix[14], matrix[15],);
    glLoadMatrixf(matrix.ptr);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
}

//Globals
SDL_Joystick*[2] gGameControllers;
//SDL_JoystickID[2] gGameControlerInstanceIDs;

void setupControllers() nothrow @nogc
{
  //SDL_Joystick* returnedController = null;
  
  int numJoys = SDL_NumJoysticks();
  printf( "Number of joysticks connected: %i\n", numJoys);
	
  //Check for joysticks
  if( numJoys < 1 )
    { printf( "Warning: No joysticks connected!\n\n" ); }
  else
  {
    foreach (int ii; 0..numJoys)
    {
      SDL_Joystick* controler = SDL_JoystickOpen(ii);
      if(null == controler)
		printf( "Warning: Unable to open game controller! SDL Error: %s\n", SDL_GetError());
      else
      {
	printf("Name: %s\n", SDL_JoystickNameForIndex(ii));
	printf("\tNumber of Axes: %d\n", SDL_JoystickNumAxes(controler));
	printf("\tNumber of Buttons: %d\n", SDL_JoystickNumButtons(controler));
	printf("\tNumber of Balls: %d\n\n", SDL_JoystickNumBalls(controler));
	if (ii < gGameControllers.length)
	  gGameControllers[ii] = controler;
      }
      //SDL_JoystickClose(controler);
    }
  }
}

void takedownControllers() @nogc
{
  foreach (SDL_Joystick* joy; gGameControllers)
    if (joy)
      SDL_JoystickClose(joy);
}

void attachControler(int id) @nogc
{
	if (id < gGameControllers.length)
	{
		if (gGameControllers[id])
		{
			SDL_JoystickClose(gGameControllers[id]);
		}
		
		SDL_Joystick* controler = SDL_JoystickOpen(id);
		
		if (null == controler)
			{printf( "Warning: Unable to open game controller! SDL Error: %s\n", SDL_GetError());}
		else
		{
			printf("Name: %s\n", SDL_JoystickNameForIndex(id));
			printf("\tNumber of Axes: %d\n", SDL_JoystickNumAxes(controler));
			printf("\tNumber of Buttons: %d\n", SDL_JoystickNumButtons(controler));
			printf("\tNumber of Balls: %d\n\n", SDL_JoystickNumBalls(controler));
			
			if ((id == 1 && gGameControllers[0] == controler) || (id == 0 && gGameControllers[1] == controler))
			{
				printf("Warning: Controler double assignment was attempted.\n");
			}
			else
			{
				gGameControllers[id] = controler;
			}
			
		}
	}
	else
	{
		printf("Warning: New controler is over the length limit of the number of accepted controlers.\n");
	}
}

//Checks that each controler is still atttached
void clearControlers(int id) @nogc
{
	
}

void removeControler(int id) @nogc
{
	if (id < gGameControllers.length)
	{
		if (gGameControllers[id])
		{
			SDL_JoystickClose(gGameControllers[id]);
			gGameControllers[id] = null;
		}
	}
	else
	{
		printf("Warning: Attempted to remove controler index that is over the length limit of the number of accepted controlers.\n");
	}
}


//Skeleton testSkel;
//Animation testAnim, otherAnim;

Skeleton fighterSkeleton;
Animation fighterAnimKick, fighterAnimSquat;

	void loadFighterSkeleton()
	{
		fighterSkeleton = makeSkeletonFile("./blend/skelcap.txt");
		fighterAnimKick = makeAnimationFile(fighterSkeleton, "./blend/LayKick.txt");
		fighterAnimSquat = makeAnimationFile(fighterSkeleton, "./blend/Squat.txt");
	}

void main()
{
	//Main will use the GC in the loading functions
	//This should load the lastest version, this isn't necessary if we fall back on a function
	version(Linux) DerelictSDL2.load("/usr/local/lib/libSDL2.so");
	version(Windows) DerelictSDL2.load();
    DerelictGL.load();
	
	if (SDL_Init( SDL_INIT_VIDEO | SDL_INIT_JOYSTICK ) < 0)
	  {printf("SDL could not initialize! SDL Error: %s\n", SDL_GetError()); return;}
	scope(exit) SDL_Quit();
	
	//SDL_GL_SetAttribute( SDL_GL_CONTEXT_MAJOR_VERSION, 3 );
	//SDL_GL_SetAttribute( SDL_GL_CONTEXT_MINOR_VERSION, 1 );
	//SDL_GL_SetAttribute( SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE );
	SDL_GL_SetAttribute( SDL_GL_CONTEXT_MAJOR_VERSION, 2 );
	SDL_GL_SetAttribute( SDL_GL_CONTEXT_MINOR_VERSION, 1 );
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
	
	//Create window
	gWindow = SDL_CreateWindow("Utarim", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, SCREEN_WIDTH, SCREEN_HEIGHT, SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN );
	if( gWindow == null )
	  {printf( "Window could not be created! SDL Error: %s\n", SDL_GetError()); return;}
	scope(exit) SDL_DestroyWindow(gWindow);
	
	gContext = SDL_GL_CreateContext( gWindow );
	if (!gContext)
	  {printf( "OpenGL context could not be created! SDL Error: %s\n", SDL_GetError() );return;}
	  
	DerelictGL.reload();
	
	//Use Vsync
	//if( SDL_GL_SetSwapInterval( 1 ) < 0 )
	 // { printf( "Warning: Unable to set VSync! SDL Error: %s\n", SDL_GetError() ); }
	//Initialize OpenGL
	//if( !initGL() )
	//  { printf( "Unable to initialize OpenGL!\n" ); return; }
	  
	GLenum error = GL_NO_ERROR;
	
	
	//Skeleto/shaders setup
	setupCube();
	
	ManBody.createShaders();
	man1 = new ManBody();
	man2 = new ManBody();
	
	setupSkelGL();
	
	//TESTS!
	
	loadFighterSkeleton();
	
	//testSkel = makeSkeletonFile("./blend/skelcap.txt");
	//testAnim = makeAnimationFile(testSkel, "./blend/LayKick.txt");
	//otherAnim = makeAnimationFile(testSkel, "./blend/Squat.txt");
	//otherAnim = makeAnimationFile(testSkel, "./blend/animcap.txt");
	writeln("TA: ", fighterAnimKick.frames[0][6].toString());
	
	//int[][2] blah = new int[][](2, 10);
	//auto ging = blah[];
	//writeln(ging[1][4]);
	
	GLMatrix identityMat = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1];
	Sphere3[] testBall = [Sphere3(1.0, Vec3(1.5,1.0,0))];
	writeln("SkeletonBallTest: " ~ (testSkeletonBall(fighterSkeleton, fighterAnimKick, 1.0, identityMat, testBall)? "T":"F") ~'\n');
	
	testBall[] = Sphere3(1.0, Vec3(0,8.5,0));
	writeln("SkeletonBallTest: " ~ (testSkeletonBall(fighterSkeleton, fighterAnimKick, 1.0, identityMat, testBall)? "T":"F") ~ Vec3(0,8.5,0).stringof ~'\n');
	
	testBall[] = Sphere3(1.0, Vec3(0.5,0.5,0));
	writeln("SkeletonBallTest: " ~ (testSkeletonBall(fighterSkeleton, fighterAnimKick, 28.0, identityMat, testBall)? "T":"F") ~'\n');
	
	Pill3 p = Pill3(1, Vec3(0,0,0), Vec3(10, 0, 0));
	Sphere3 s = Sphere3(1, Vec3(5, 0, 0));
	writeln("HullTest: " ~ (hullPointTest(p,s)? "T":"F") ~'\n');
	
	p = Pill3(1, Vec3(100,0,0), Vec3(110, 0, 0));
	s = Sphere3(1, Vec3(105, 0, 0));
	writeln("HullTest: " ~ (hullPointTest(p,s)? "T":"F") ~'\n');
	
	p = Pill3(1, Vec3(100,0,0), Vec3(110, 0, 0));
	s = Sphere3(1, Vec3(115, 0, 0));
	writeln("HullTest: " ~ (hullPointTest(p,s)? "T":"F") ~'\n');
	
	p = Pill3(1, Vec3(0,0,0), Vec3(1, 0, 0));
	s = Sphere3(1, Vec3(0, 0, 0));
	writeln("HullTest: " ~ (hullPointTest(p,s)? "T":"F") ~'\n');
	
	p = Pill3(1, Vec3(0,0,0), Vec3(1, 0, 0));
	s = Sphere3(1, Vec3(0, 1, 0));
	writeln("HullTest: " ~ (hullPointTest(p,s)? "T":"F") ~'\n');
	
	p = Pill3(1, Vec3(0,0,0), Vec3(1, 0, 0));
	s = Sphere3(1, Vec3(-1, 1, -1));
	writeln("HullTest: " ~ (hullPointTest(p,s)? "T":"F") ~'\n');
	
	p = Pill3(1, Vec3(0,0,0), Vec3(1, 0, 0));
	s = Sphere3(1, Vec3(-2, 0, 0.1));
	writeln("HullTest: " ~ (hullPointTest(p,s)? "T":"F") ~'\n');
	
	//Initialize Projection Matrix
	glMatrixMode( GL_PROJECTION ); //glLoadIdentity();
	//Check for error
	error = glGetError();
	if( error != GL_NO_ERROR )
	{ //printf( "Error initializing OpenGL! %s\n", gluErrorString( error ) );
	return; }
	//Initialize Modelview Matrix
	glMatrixMode( GL_MODELVIEW );
	glLoadIdentity();
	
	if( error != GL_NO_ERROR )
	{ //printf( "Error initializing OpenGL! %s\n", gluErrorString( error ) );
	return; }
	
	//Initialize clear color
	glClearColor( 0.0f, 0.0f, 0.0f, 1.0f );
	
	Quat qt1 = rotationQuat(TAU*0.25, 0, 0, 1);
	Quat inter_Quat1 = qt1*(qt1.conj()*qt1).pow(0.0);
	writeln("Q1: ", inter_Quat1.toString());
	inter_Quat1 = qt1*(qt1.conj()*qt1).pow(0.5);
	writeln("Q2: ", inter_Quat1.toString());
	inter_Quat1 = qt1*(qt1.conj()*qt1).pow(1.0);
	writeln("Q3: ", inter_Quat1.toString());
	
      
        //Collects all garbage and suspends the GC
        GC.collect();
        
        GC.disable();
        
        //This is where everything that avoids using the GC and exceptions goes while running.
        realtime();
}


void realtime() @nogc
{
	//The images
       
        SDL_Surface* screenSurface;
        SDL_Surface* helloWorld;
        SDL_Renderer* gRenderer;
	//Main loop flag
	bool quit = false;
	//Event handler
	SDL_Event e;
	
	//Gets keyboard input
	const Uint8* currentKeyStates = SDL_GetKeyboardState(null);
	uint initTime = SDL_GetTicks();
	
	setupControllers();
	scope(exit)
	  takedownControllers();
	  
	setupGame();
	
	TickDuration lastTime = TickDuration.currSystemTick();
	TickDuration firstTime = lastTime;
	TickDuration newTime;
	TickDuration dt;
	long nanoFrameDuration = 1000000000/60;
	printf("microFrameDuration: %i \n", nanoFrameDuration);
      
	//While application is running
	while( !quit )
	{
	  //SDL_SetRenderDrawColor(gRenderer, 0x00, 0x00, 0x00, 0xFF);
	  SDL_JoystickUpdate();
	  //Handle events on queue
	  while( SDL_PollEvent( &e ) != 0 )
	  {
	    //User requests quit
	    if( e.type == SDL_QUIT )
	      quit = true;
	    else if( e.type == SDL_KEYDOWN )
	    {
	      switch (e.key.keysym.sym)
	      {
// 		case SDLK_UP:
// 		glColor4f(1.0f, 0.8f, 0.0f, 1.0f);
// 		break;
		//SDL_FillRect( screenSurface, null, SDL_MapRGB( screenSurface.format, 0xFF, 0xF0, 0x00 ) );
		
		case SDLK_ESCAPE:
		quit = true;
		break;
		
		default:
		//SDL_SetRenderDrawColor(gRenderer, 0x00, 0x00, 0x00, 0xFF);
		//glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
		//Apply the image
		//SDL_BlitSurface( helloWorld, null, screenSurface, null);
	      }
	    }
		else if (e.type == SDL_JOYDEVICEREMOVED)
		{
			SDL_JoystickID controler_instance = e.jdevice.which;
			printf("CONTROLER INSTANCE #%i DISCONNECTED!\n", controler_instance);
			
			//SDL_GameController* disconected_control = SDL_GameControllerFromInstanceID(controler_instance);
			SDL_JoystickID[gGameControllers.length] gGameControlerInstanceIDs;
			foreach (int index, SDL_JoystickID inst; gGameControlerInstanceIDs)
			{
				gGameControlerInstanceIDs[index] = SDL_JoystickInstanceID(gGameControllers[index]);
				if (gGameControlerInstanceIDs[index] == controler_instance)
				{
					removeControler(index);
				}
			}
			
			printf("Number of joysticks connected: %i\n", SDL_NumJoysticks());
			
		}
		else if (e.type == SDL_JOYDEVICEADDED)
		{
			printf("CONTROLER DEVICE #%i CONNECTED!\n", e.jdevice.which);
			attachControler(e.jdevice.which);
			printf("Number of joysticks connected: %i\n", SDL_NumJoysticks());
		}
	    
	  }
	  
	  setButtons(0, 0);
	  setButtons(1, 1);
	  
	  gameUpdate();
	  
	  //Clear color buffer
	  glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	  glMatrixMode(GL_MODELVIEW);
	  
	  //mProgram.useFixed();
	  glUseProgram(0);
	  
	  //Setup Lighting
	  glEnable(GL_LIGHTING);
	  
	  const static float[] ambientLight = [0.2f, 0.2f, 0.2f, 1.0f];
	  const static float[] diffuseLight = [0.8f, 0.8f, 0.8f, 1.0f];
	  const static float[] positionLight = [0.0f, 0.0f, 0.0f, 1.0f];
	  
	  glLightfv(GL_LIGHT0, GL_AMBIENT, ambientLight.ptr);
	  glLightfv(GL_LIGHT0, GL_DIFFUSE, diffuseLight.ptr);
	  glLightfv(GL_LIGHT0, GL_POSITION, positionLight.ptr);
	  
	  glEnable(GL_LIGHT0);
	  
	  glColorMaterial ( GL_FRONT, GL_DIFFUSE);
	  glEnable (GL_COLOR_MATERIAL);
	  
	  renderFighters();
	  //mProgram.use();
	  // ManBody.useShaderProgram();
	  // glPushMatrix();
	    // glTranslatef(0.0,0.0,-15.0);
	    // man1.update(dt.length / cast(double)TickDuration.ticksPerSec);
	    // man1.render();
	    // man2.update(0.03);
	    // glTranslatef(5.0f, 1.0f, -2.0f);
	    // man2.render();
	    // glTranslatef(-5.0f, -1.0f, 2.0f);
	    // glUseProgram(0);
	    // glPushMatrix();
	      // glTranslatef(0.0, 0.0, 8.0);
	      // double tickVal = (lastTime.length-firstTime.length)*(10.0/cast(double)TickDuration.ticksPerSec);
	      // glRotatef(tickVal, 0.0f, 1.0f, 0.0f);
	      // if (P1.ci.buttons[0])
		// drawSkeletonMesh(fighterSkeleton, fighterAnimKick, tickVal, true);
	      // else
		// drawSkeletonMesh(fighterSkeleton, fighterAnimSquat, tickVal, true);
	      // //printf("TV: %f\n", tickVal);
	    // glPopMatrix();
	    
	  // glPopMatrix();
	  
	  SDL_GL_SwapWindow( gWindow );
	  
	  //Time update
	  newTime = TickDuration.currSystemTick();
	  dt = newTime - lastTime;
	  //printf("dt: %i \n", dt.usecs);
	  
	  
	  //Slows down framerate if time passes too quickly
	  //Thread.sleep(dur!("nsecs")(nanoFrameDuration - dt.nsecs));
	  
	  //This is a basic loop that waits and holds the CPU until the time is ready for a new frame, ideally this shoudl be changes to a sleep() function
	  while (dt.nsecs < nanoFrameDuration)
	  {
		
		newTime = TickDuration.currSystemTick();
		dt = newTime - lastTime;
	  }
	  
	  lastTime = newTime;
	}

        //Prints on safe exit
        printf("Exit time: %u\n", SDL_GetTicks() - initTime);
	printf("Well done.\n");
}


struct Gamestate
{
	
}

greal arenaHalfwidth = 500.0;

Fighter P1;
Fighter P2;
Fighter[2] Players;
const size_t FighterSize = __traits(classInstanceSize, Fighter);
void[FighterSize*2] FighterData;

void setupGame() @nogc
{
  //P1 = make!Fighter(makeState!Idle(-5.0, 0.0), fighterSkeleton);
  //P2 = make!Fighter(makeState!Idle(5.0, 0.0), fighterSkeleton);
  P1 = emplace!Fighter(FighterData[0..FighterSize], makeState!Idle(-5.0, 0.0), fighterSkeleton);
  P2 = emplace!Fighter(FighterData[FighterSize..$], makeState!Idle(5.0, 0.0), fighterSkeleton);
  Players[0] = P1;
  Players[1] = P2;
}

void renderFighters() @nogc
{
	glPushMatrix();
		glTranslatef(0.0, -2.0, -15.0);
		P1.render();
		P2.render();
	glPopMatrix();
}

void collisions(Fighter first, Fighter second) @nogc
{
  
}

void gameUpdate() @nogc
{
  P1.createUpdate();
  P2.createUpdate();
  collisions(P1, P2);
  P1.swapUpdate();
  P2.swapUpdate();
}

struct ControlInput
{
  enum VerticalDir {neutral = 0, up = 1, down = -1};
  VerticalDir vertDir;
  enum HorizontalDir {neutral = 0, left = -1, right = 1};
  HorizontalDir horiDir;
  
  bool[4] buttons;
  
  // void copyInput(ref ControlInput inp)
  // {
	// vertDir = inp.vertDir;
	// horiDir = inp.horiDir;
	
	// foreach(int ii, bool button; inp.buttons)
	// {
		// buttons[ii] = button;
	// }
  // }
}

void setButtons(int playerNum, int controlNum) @nogc
{
  if (gGameControllers[controlNum])
  {
	with (Players[playerNum])
	{
		pi = ci;
	}
  
    with(Players[playerNum].ci)
    {
      int numButtons = SDL_JoystickNumButtons(gGameControllers[controlNum]);
      foreach (int ii, ref bool button; buttons)
		if (ii < numButtons)
			button = 0 != SDL_JoystickGetButton(gGameControllers[controlNum], ii);
		
		ubyte dir = SDL_JoystickGetHat(gGameControllers[controlNum], 0);
		 
		if (dir == SDL_HAT_LEFTUP)
			{vertDir = VerticalDir.up; horiDir = HorizontalDir.left;}
		else if (dir == SDL_HAT_UP)
			{vertDir = VerticalDir.up; horiDir = HorizontalDir.neutral;}
		else if (dir == SDL_HAT_RIGHTUP)
			{vertDir = VerticalDir.up; horiDir = HorizontalDir.right;}
		else if (dir == SDL_HAT_LEFT)
			{vertDir = VerticalDir.neutral; horiDir = HorizontalDir.left;}
		else if (dir == SDL_HAT_CENTERED)
			{vertDir = VerticalDir.neutral; horiDir = HorizontalDir.neutral;}
		else if (dir == SDL_HAT_RIGHT)
			{vertDir = VerticalDir.neutral; horiDir = HorizontalDir.right;}
		else if (dir == SDL_HAT_LEFTDOWN)
			{vertDir = VerticalDir.down; horiDir = HorizontalDir.left;}
		else if (dir == SDL_HAT_DOWN)
			{vertDir = VerticalDir.down; horiDir = HorizontalDir.neutral;}
		else if (dir == SDL_HAT_RIGHTDOWN)
			{vertDir = VerticalDir.down; horiDir = HorizontalDir.right;}
    }
  }
}


class Fighter
{
	@nogc
	{
		this(State s, Skeleton sk)
		{
		  state = s;
		  skel = sk;
		  assert(s);
		}
		
		~this()
		{
		  //state should never be null
		  assert(state);
		  breakState(state);
		
		  if(tempState)
			breakState(tempState);
		}
	  
	//   class Tech
	//   {
	//     State createUpdate(){return State(0, 0, new Idle());}
	//     void update(State s) {}
	//   }
	  
	  void createUpdate()
	  {
		if (tempState) breakState(tempState);
		tempState = state.makeUpdate(this);
	  }
	  
	  void swapUpdate()
	  {
		//state should never be null
		assert(state);
		if (tempState)
		{
		  breakState(state);
		  state = tempState;
		  tempState = null;
		}
	  }
	  
	  void render()
	  {
		//Render quad
		if( gRenderQuad )
		{
		  const greal hsize = 8.0f/2.0f;
		  glPushMatrix();
			glScalef(0.05f, 0.05f, 0.05f);
			glTranslatef(cast(float)x, cast(float)y, -20.0f);
			glBegin( GL_QUADS );
			glColor4f(ci.buttons[0] ? 1.0f : 0.2f, 0.0f, 0.0f, 1.0f);
			glVertex2f( -hsize, -hsize );
			glColor4f(ci.buttons[1] ? 1.0f : 0.2f, 0.0f, 0.0f, 1.0f);
			glVertex2f( hsize, -hsize );
			glColor4f(ci.buttons[2] ? 1.0f : 0.2f, 0.0f, 0.0f, 1.0f);
			glVertex2f( hsize, hsize );
			glColor4f(ci.buttons[3] ? 1.0f : 0.2f, 0.0f, 0.0f, 1.0f);
			glVertex2f( -hsize, hsize );
			glEnd();
		  glPopMatrix();
		}
		else
		{
			glPushMatrix();
				glTranslatef(cast(float)x, cast(float)y, 0.0f);
				glRotatef(90.0, 0.0, 1.0, 0.0);
				drawFighter(state);
			glPopMatrix();
		}
		 
		 
	  }
	  
	  void drawFighter(State s)
		{
			s.animateState(this);
		}
	}
  public ControlInput ci;
  public ControlInput pi; //Previous input
  protected State state;
  protected State tempState;
  public Skeleton skel;
  public greal halfWidth = 50.0;
  alias state this;
  
}


alias StateList = AliasSeq!(Idle, Step, Duck);

pure size_t maxStateSizeCalc()
{
	size_t maximum = 0;
	
	foreach (sym;  StateList)
	{
		size_t cSize = __traits(classInstanceSize, sym);
		if (cSize > maximum)
			maximum = cSize;
	}
	
	return maximum;
}

pure size_t mimStateSizeCalc()
{
	size_t minimum = size_t.max;
	
	foreach (sym;  StateList)
	{
		size_t cSize = __traits(classInstanceSize, sym);
		if (cSize > minimum)
			minimum = cSize;
	}
	
	return minimum;
}

const size_t minStateSize = maxStateSizeCalc(); //__traits(classInstanceSize, Idle); //SizeOf!(Idle);
const size_t maxStateSize = mimStateSizeCalc(); //__traits(classInstanceSize, Duck); //SizeOf!(Duck);
FreeList!(Mallocator, minStateSize, maxStateSize) stateFreeList;



@nogc
auto makeState(T, Args...)(auto ref Args args) if (is(T : State))
{
  //enum size_t SIZE = SizeOf!(T);
  auto mem = stateFreeList.allocate(__traits(classInstanceSize, T));
  
  return emplace!(T)(mem, args);
}

//(state.classinfo.init.length)

@nogc
void breakState(State state)
{
  if (state)
  {
    static if (__traits(hasMember, State, "__dtor"))
	      state.__dtor();
    stateFreeList.deallocate((cast(ubyte*)state)[0..(state.classinfo.init.length)]);
    state = null;
  }
}

abstract class State
{
  this(greal X, greal Y) @nogc
  {x = X; y = Y;}
  
  //~this() @nogc;
  
  //public greal x, y;
  public Vec3 pos;
  // public alias x = pos.x;
  // public alias y = pos.y;
  
  	@property @nogc {
		vreal x(vreal V) 
		{return pos.x = V;}
		vreal x() const 
		{return pos.x;}
		
		vreal y(vreal V) 
		{return pos.y = V;}
		vreal y() const 
		{return pos.y;}
		
		vreal z(vreal V) 
		{return pos.z = V;}
		vreal z() const 
		{return pos.z;}
	}
	
	static Vec3 movePosition(ref Fighter parent, greal nx, greal ny)
	{	
		greal x, y;
		
		if (nx + parent.halfWidth > arenaHalfwidth)
			x = arenaHalfwidth - parent.halfWidth;
		else if (nx - parent.halfWidth < -arenaHalfwidth)
			x = -arenaHalfwidth + parent.halfWidth;
		else
			x = nx;
			
		if (ny < 0)
			y = 0;
		else
			y = ny;
			
		return Vec3(x,y,0);
	}
	
	void animateState(Fighter parent) @nogc
	{
		drawSkeletonMesh(parent.skel, fighterAnimSquat, 1, true);
	}
  
  State makeUpdate(Fighter parent) @nogc;
}

abstract class AnimatedState : State
{
	Animation* anim;
	int timeFrame = 0;
	
	this(greal x, greal y, int time = 0) @nogc
	{super(x,y); timeFrame = time;}
	
	Animation* getAnim() @nogc
	{
		return anim;
	}
	
	// void animateState(Fighter f) @nogc
	// {
		// drawSkeletonMesh(f.skel, getAnim(), 0.0, true);
	// }
	
	override void animateState(Fighter parent) @nogc
	{
		drawSkeletonMesh(parent.skel, *getAnim(), timeFrame, true);
	}
}

class Idle : AnimatedState
{
	// int timeFrame = 0;
	
  this(greal x, greal y, int time = 0) @nogc
  {super(x,y,time); anim = &fighterAnimKick;}
  
  //~this() @nogc {}
  
  override State makeUpdate(Fighter parent) @nogc
  {
    //debug printf("Idle\n");
    if (parent.ci.buttons[0])
      return makeState!Duck(x,y);
    else if (parent.ci.horiDir != ControlInput.HorizontalDir.neutral)
		return makeState!Idle(x+parent.ci.horiDir*0.1 ,y, (timeFrame+1 > anim.frameNos.length)? 0: timeFrame+1);
	else
      return makeState!Idle(x,y, (timeFrame+1 > anim.frameNos.length)? 0: timeFrame+1);
  }
}

class Step : State
{
   this(greal x, greal y) @nogc
  {super(x,y);}

	override State makeUpdate(Fighter parent) @nogc
  {
	x = x + parent.ci.horiDir;
	y = y + parent.ci.vertDir;
		
	return makeState!Step(x,y);
  }
}

class Duck : AnimatedState
{
  this(greal x, greal y, int time = 0) @nogc
  {super(x,y,time); anim = &fighterAnimSquat;}
  
  override State makeUpdate(Fighter parent) @nogc
  {
    //debug printf("Duck\n");
    if (parent.ci.buttons[1])
      return makeState!Idle(x,y);
    else
      return makeState!Duck(x,y, timeFrame+1);
  }
  
  double[10] weights;
}