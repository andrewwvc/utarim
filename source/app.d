import std.stdio;
import core.memory;
import derelict.sdl2.sdl;
import derelict.opengl3.gl;
import m3.m3;

import allocator.building_blocks.free_list;
import allocator.mallocator;
import std.traits;

//Screen dimension constants
const int SCREEN_WIDTH = 640;
const int SCREEN_HEIGHT = 640;

SDL_Window* gWindow;

//OpenGL context
SDL_GLContext gContext;

//Render flag
bool gRenderQuad = true;

//Graphics program
GLuint gProgramID = 0;
GLint gVertexPos2DLocation = -1;
GLuint gVBO = 0;
GLuint gIBO = 0;

alias greal = float;

//Globals
SDL_Joystick*[2] gGameControllers;

void setupControllers() nothrow @nogc
{
  //SDL_Joystick* returnedController = null;
  
  int numJoys = SDL_NumJoysticks();
  printf( "Number of joysticks connected: %i\n", numJoys);
	
  //Check for joysticks
  if( SDL_NumJoysticks() < 1 )
    { printf( "Warning: No joysticks connected!\n\n" ); }
  else
  {
    foreach (int ii; 0..SDL_NumJoysticks())
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




void main()
{
	//Main will use the GC in the loading functions
	//This should load the lastest version, this isn't necessary if we fall back on a function
	DerelictSDL2.load("/usr/local/lib/libSDL2.so");
        DerelictGL.load();
	
	if (SDL_Init( SDL_INIT_VIDEO | SDL_INIT_JOYSTICK ) < 0)
	  {printf("SDL could not initialize! SDL Error: %s\n", SDL_GetError()); return;}
	scope(exit) SDL_Quit();
	
	//SDL_GL_SetAttribute( SDL_GL_CONTEXT_MAJOR_VERSION, 3 );
	//SDL_GL_SetAttribute( SDL_GL_CONTEXT_MINOR_VERSION, 1 );
	//SDL_GL_SetAttribute( SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE );
	SDL_GL_SetAttribute( SDL_GL_CONTEXT_MAJOR_VERSION, 2 );
	SDL_GL_SetAttribute( SDL_GL_CONTEXT_MINOR_VERSION, 1 );
	
	//Create window
	gWindow = SDL_CreateWindow( "SDL Tutorial", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, SCREEN_WIDTH, SCREEN_HEIGHT, SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN );
	if( gWindow == null )
	  {printf( "Window could not be created! SDL Error: %s\n", SDL_GetError()); return;}
	scope(exit) SDL_DestroyWindow(gWindow);
	
	gContext = SDL_GL_CreateContext( gWindow );
	if (!gContext)
	  {printf( "OpenGL context could not be created! SDL Error: %s\n", SDL_GetError() );return;}
	  
	DerelictGL.reload();
	
	//Use Vsync
	if( SDL_GL_SetSwapInterval( 1 ) < 0 )
	  { printf( "Warning: Unable to set VSync! SDL Error: %s\n", SDL_GetError() ); }
	//Initialize OpenGL
	//if( !initGL() )
	//  { printf( "Unable to initialize OpenGL!\n" ); return; }
	  
	GLenum error = GL_NO_ERROR;
	//Initialize Projection Matrix
	glMatrixMode( GL_PROJECTION ); glLoadIdentity();
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
	
	FreeList!(Mallocator, 2, 200) lista;
	lista.allocate(3);
	lista.allocate(3);
	
      
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
	    
	  }
	  
// 	  if( currentKeyStates[ SDL_SCANCODE_DOWN ] )
// 	    glColor4f(0.0f, 0.8f, 0.8f, 1.0f);
// 	  else if(currentKeyStates[SDL_SCANCODE_UP])
// 	  {
// 	  	glColor4f(1.0f, 0.8f, 0.0f, 1.0f);
// 	  }
	  
	  setButtons(0, 0);
	  setButtons(1, 1);
	  
	  gameUpdate();
	  //Clear color buffer
	  glClear( GL_COLOR_BUFFER_BIT );
	  
	  renderFighters();
	  
	  SDL_GL_SwapWindow( gWindow );
	}

        //Prints on safe exit
        printf("Exit time: %u\n", SDL_GetTicks() - initTime);
	printf("Well done.\n");
}

Fighter P1;
Fighter P2;
Fighter[2] Players;

void setupGame() @nogc
{
  P1 = make!Fighter(makeState!Idle(-10.0, 0.0));
  P2 = make!Fighter(makeState!Idle(10.0, 0.0));
  Players[0] = P1;
  Players[1] = P2;
}

void renderFighters() @nogc
{
  P1.render();
  P2.render();
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
  enum vertDir {up, down, neutral};
  enum horiDir {left, right, neutral};
  bool[4] buttons;
}

void setButtons(int playerNum, int controlNum) @nogc
{
  if (gGameControllers[controlNum])
  {
    with(Players[playerNum].ci)
    {
      int numButtons = SDL_JoystickNumButtons(gGameControllers[controlNum]);
      foreach (int ii, ref bool button; buttons)
	if (ii < numButtons)
	  button = 0 != SDL_JoystickGetButton(gGameControllers[controlNum], ii);
    }
  }
}

struct hittri
{
  
}

class Fighter
{
    this(State s) @nogc
    {
      state = s;
      assert(s);
    }
    
    ~this()  @nogc
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
  
  void createUpdate() @nogc
  {
    if (tempState) breakState(tempState);
    tempState = state.makeUpdate(this);
  }
  void swapUpdate() @nogc
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
  
  void render() @nogc
  {
    //Render quad
    if( gRenderQuad )
    {
      const greal hsize = 8.0f/2.0f;
      glPushMatrix();
      glScalef(0.05f, 0.05f, 0.05f);
      glTranslatef(cast(float)x, cast(float)y, 0.0f);
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
	  
  }
  
  public ControlInput ci;
  public ControlInput pi; //Previous input
  protected State state;
  protected State tempState;
  alias state this;
}



const size_t minStateSize = SizeOf!(Idle);
const size_t maxStateSize = SizeOf!(Duck);
FreeList!(Mallocator, minStateSize, maxStateSize) stateFreeList;



@nogc
auto makeState(T, Args...)(auto ref Args args) if (is(T : State))
{
  //enum size_t SIZE = SizeOf!(T);
  auto mem = stateFreeList.allocate(SizeOf!(T));
  
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
  this(greal x, greal y) @nogc
  {this.x = x, this.y = y;}
  
  //~this() @nogc;
  
  public greal x, y;
  
  State makeUpdate(Fighter parent) @nogc;
}

class Idle : State
{
  this(greal x, greal y) @nogc
  {super(x,y);}
  
  //~this() @nogc {}
  
  override State makeUpdate(Fighter parent) @nogc
  {
    debug printf("Idle\n");
    if (parent.ci.buttons[0])
      return makeState!Duck(x,y);
    else
      return makeState!Idle(x,y);
  }
}

class Duck : State
{
  this(greal x, greal y) @nogc
  {super(x,y);}
  
  override State makeUpdate(Fighter parent) @nogc
  {
    debug printf("Duck\n");
    if (parent.ci.buttons[1])
      return makeState!Idle(x,y);
    else
      return makeState!Duck(x,y);
  }
  
  double[10] weights;
}