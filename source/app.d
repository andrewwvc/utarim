import std.stdio;
import core.memory;
import derelict.sdl2.sdl;
import derelict.opengl3.gl;
import allocator.building_blocks.free_list;
import m3.m3;


//Screen dimension constants
const int SCREEN_WIDTH = 640;
const int SCREEN_HEIGHT = 480;

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

//Globals
SDL_Joystick* gGameController = null;

void setupControllers() nothrow @nogc
{
  SDL_Joystick* returnedController = null;
  
  printf( "Number of joysticks connected: %i\n", SDL_NumJoysticks() );
	
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
      }
      SDL_JoystickClose(controler);
    }
  }
  
  printf("%i\n", SDL_JoystickEventState(SDL_QUERY));
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

void realtime() nothrow @nogc
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
	gGameController = SDL_JoystickOpen( 0 );
	scope(exit)
	  {if (gGameController) SDL_JoystickClose(gGameController);}
	
      
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
		glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
		//Apply the image
		//SDL_BlitSurface( helloWorld, null, screenSurface, null);
	      }
	    }
	    
	  }
	  
	  if( currentKeyStates[ SDL_SCANCODE_DOWN ] )
	    glColor4f(0.0f, 0.8f, 0.8f, 1.0f);
	  else if(currentKeyStates[SDL_SCANCODE_UP])
	  {
	  	glColor4f(1.0f, 0.8f, 0.0f, 1.0f);
	  }
	  
	  if (gGameController)
	  {
	    if (SDL_JoystickGetButton(gGameController, 0))
	    {
	      //SDL_RestoreWindow(window);
	      //SDL_FillRect( screenSurface, null, SDL_MapRGB( screenSurface.format, 0x88, 0x00, 0xAA ));
	      //SDL_SetRenderDrawColor(gRenderer, 0x88, 0x00, 0xAA, 0xFF);
	      glColor4f(0.55f, 0.0f, 0.7f, 1.0f);
	    }
	    else if (SDL_JoystickGetAxis(gGameController, 0) > 10000)
	    {
	      glColor4f(0.0f, 0.85f, 0.0f, 1.0f);
	      //SDL_SetRenderDrawColor(gRenderer, 0x00, 0xCC, 0x00, 0xFF);
	    }
	    
	  }
	  
	  //Clear color buffer
	  glClear( GL_COLOR_BUFFER_BIT );
	  //Render quad
	  if( gRenderQuad )
	  {
	    glBegin( GL_QUADS );
	    glVertex2f( -0.5f, -0.5f );
	    glVertex2f( 0.5f, -0.5f );
	    glVertex2f( 0.5f, 0.5f );
	    glVertex2f( -0.5f, 0.5f );
	    glEnd();
	  }
	  
	  
	  SDL_GL_SwapWindow( gWindow );
	}

        //Prints on safe exit
        printf("Exit time: %u\n", SDL_GetTicks() - initTime);
	printf("Well done.\n");
}

Fighter P1;
Fighter P2;

void setupGame() @nogc
{
  P1 = make!Fighter(make!Idle(-10.0, 0.0));
}

void collisions(Fighter first, Fighter second)
{
  
}

void gameUpdate() @nogc
{
  
}

struct ControlInput
{
  enum direction {up, down, left, right};
  
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
    
    ~this() @nogc
    {
      //state should never be null
      assert(state);
      destruct(state);
	
      if(tempState)
	destruct(tempState);
    }
  
//   class Tech
//   {
//     State createUpdate(){return State(0, 0, new Idle());}
//     void update(State s) {}
//   }
  
  void createUpdate()
  {
    if (tempState) destruct(tempState);
    tempState = state.createUpdate();
  }
  void swapUpdate()
  {
    //state should never be null
    assert(state);
    if (tempState)
    {
      destruct(state);
      state = tempState;
      tempState = null;
    }
  }

  State state;
  State tempState;
  alias state this;
}

abstract class State
  {
    this(double X, double Y) @nogc
    {x = X, y = Y;}
    
    ~this() @nogc {} 
    
    double x, y;
    
    State createUpdate();//{return new State(0, 0);} //Replace new with preallocated memory.
  }
  
  class Idle : State
  {
    this(double X, double Y) @nogc
    {super(x,y);}
    
    ~this() @nogc {}
    
    override State createUpdate() @nogc
    {return make!Idle(x,y);} //Replace new with preallocated memory.
  }