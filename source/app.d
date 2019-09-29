import std.stdio: writeln, printf;
import core.memory;
import derelict.sdl2.sdl;
import derelict.opengl3.gl;

import vmath;
import skeleton;
import manbody;
import core.time;

import allocator.building_blocks.free_list;
import allocator.mallocator;
import std.traits;
import std.conv;
import std.meta;


//Screen dimension constants
const int SCREEN_WIDTH = 1280;
const int SCREEN_HEIGHT = 960;

//Ideal frame timing
const long FRAME_RATE = 60;

const size_t NoPlayers = 2;

SDL_Window* gWindow;

//OpenGL context
SDL_GLContext gContext;

//Render flag
bool gRenderQuad = false;
int syncType; //0 = No Sync, 1 = Vsync, -1 = Adaptive Sync

const int NOSYNC = 0;
const int VSYNC = 1;
const int ASYNC = -1;

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
SDL_Joystick*[NoPlayers] gGameControllers;
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

//General index type
alias GenIndex = short;

//Specific index types
alias SkeletonIndex = GenIndex;
alias AnimationIndex = GenIndex;
alias StateIndex = GenIndex;

SkeletonIndex fighterSkeleton;
AnimationIndex fighterAnimKick, fighterAnimSquat;

Skeleton[1] skeletons;
Animation[4] animations;

const size_t totalOfStoredFrames = 10;


struct GameFrame
{
	ubyte[maxStateSerializationSize][NoPlayers] fStates;
	InputSerialization[NoPlayers] fInputs;
}

struct GameFrameQueue
{
	byte currentFrameIndex;
	byte noStored;
	ubyte[maxStateSerializationSize][NoPlayers][totalOfStoredFrames] frameState;
	InputSerialization[NoPlayers][totalOfStoredFrames] frameInput;
	
	this(bool filler) @nogc
	{
		fullReset();
	}
	
	void insertFrame(ref Fighter[NoPlayers] fighters) @nogc
	{
		if (noStored < totalOfStoredFrames)
			noStored++;
		
		foreach(ii, fighter; fighters)
		{
			fighter.state.serializeState(frameState[currentFrameIndex][ii]);
			frameInput[currentFrameIndex][ii] = serializeControlInput(fighter.ci);
		}
		
		currentFrameIndex = (currentFrameIndex + 1) % totalOfStoredFrames;
	}
	

	void retriveMinusNthFrame(uint nn, ref GameFrame gf) @nogc
	{
		//assert(0 < nn && nn <= noStored);
		
		size_t index = (currentFrameIndex - nn) %  totalOfStoredFrames;
		
		gf.fStates[0] = frameState[index][0];
		gf.fStates[1] = frameState[index][1];
		
		gf.fInputs[0] = frameInput[index][0];
		gf.fInputs[1] = frameInput[index][1];
	}
	
	InputSerialization retriveMinusNthInputForPlayer(uint nn, size_t pNo) @nogc
	{
		//assert(0 < nn && nn <= noStored);
		
		size_t index = (currentFrameIndex - nn) %  totalOfStoredFrames;
		
		return frameInput[index][pNo];
	}
	
	//Reduces the noStored to 0, without overwirting elements unnecessarily
	void softReset() @nogc
	{
		noStored = 0;
	}
	
	void fullReset() @nogc
	{
		Idle example = makeState!Idle();
		
		foreach (frame; frameState)
		{
			example.serializeState(frame[0]);
			example.serializeState(frame[1]);
		}
		
		currentFrameIndex = 0;
		noStored = 0;
	}
}

debug
void dynamicPrint(string st) @nogc
{
	if (st.length < 1080)
	{
		char[1080] bufferU;
		bufferU[0..(st.length)] = cast(char[])(st);
		bufferU[st.length] = '\0';
		printf("%s\n", bufferU.ptr);
	}
	else
	{
		printf("String too long!");
	}
}


void loadFighterSkeleton()
{
	skeletons[0] = makeSkeletonFile("./blend/skelcap.txt");
	fighterSkeleton = 0;
	
	animations[0] = makeAnimationFile(skeletons[fighterSkeleton], "./blend/LayKick.txt");
	fighterAnimKick = 0;
	animations[1] = makeAnimationFile(skeletons[fighterSkeleton], "./blend/Squat.txt");
	fighterAnimSquat = 1;
}

void main()
{
	//Main will use the GC in the loading functions
	//This should load the lastest version, this isn't necessary if we fall back on a function
	version(Linux) DerelictSDL2.load("/usr/local/lib/libSDL2.so");
	version(Windows) DerelictSDL2.load();
    DerelictGL.load();//DerelictGL.reload() must be called after an OpenGL context is created
	
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
	
	syncType = ASYNC;
	//Use AdaptiveSync, else use Vsync
	if (SDL_GL_SetSwapInterval( ASYNC ) < 0 )
	{
		syncType = VSYNC;
		printf( "Warning: Unable to set AdaptiveSync! Attempting to set Vsync. SDL Error: %s\n", SDL_GetError() );
	
		if( SDL_GL_SetSwapInterval( VSYNC ) < 0 )
		{
			syncType = NOSYNC;
			printf( "Warning: Unable to set VSync! Using no screen sync. SDL Error: %s\n", SDL_GetError() );
		}
	}
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
	
	debug
	{
		//testSkel = makeSkeletonFile("./blend/skelcap.txt");
		//testAnim = makeAnimationFile(testSkel, "./blend/LayKick.txt");
		//otherAnim = makeAnimationFile(testSkel, "./blend/Squat.txt");
		//otherAnim = makeAnimationFile(testSkel, "./blend/animcap.txt");
		writeln("TA: ", animations[fighterAnimKick].frames[0][6].toString());
		
		//int[][2] blah = new int[][](2, 10);
		//auto ging = blah[];
		//writeln(ging[1][4]);
		
		GLMatrix identityMat = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1];
		Sphere3[] testBall = [Sphere3(1.0, Vec3(1.5,1.0,0))];
		writeln("SkeletonBallTest: " ~ (testSkeletonBall(skeletons[fighterSkeleton], animations[fighterAnimKick], 1.0, identityMat, testBall)? "T":"F") ~'\n');
		
		testBall[] = Sphere3(1.0, Vec3(0,8.5,0));
		writeln("SkeletonBallTest: " ~ (testSkeletonBall(skeletons[fighterSkeleton], animations[fighterAnimKick], 1.0, identityMat, testBall)? "T":"F") ~ Vec3(0,8.5,0).stringof ~'\n');
		
		testBall[] = Sphere3(1.0, Vec3(0.5,0.5,0));
		writeln("SkeletonBallTest: " ~ (testSkeletonBall(skeletons[fighterSkeleton], animations[fighterAnimKick], 28.0, identityMat, testBall)? "T":"F") ~'\n');
		
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
		
		// auto listener = new TcpSocket();
		// assert(listener.isAlive);
		// listener.blocking = false;
		// listener.bind(new InternetAddress(4444));
		// listener.listen(10);
		// printf("Listening on port %d.", 4444);
	}
	
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
	
	debug
	{
		Quat qt1 = rotationQuat(TAU*0.25, 0, 0, 1);
		Quat inter_Quat1 = qt1*(qt1.conj()*qt1).pow(0.0);
		writeln("Q1: ", inter_Quat1.toString());
		inter_Quat1 = qt1*(qt1.conj()*qt1).pow(0.5);
		writeln("Q2: ", inter_Quat1.toString());
		inter_Quat1 = qt1*(qt1.conj()*qt1).pow(1.0);
		writeln("Q3: ", inter_Quat1.toString());
		
		ubyte[Animation.sizeof+size_t.sizeof] testAnimBuff;
		serialize!(Animation)(animations[fighterAnimKick], testAnimBuff);
		writeln("TestAnimation Serialization:\n", testAnimBuff);
		
		alias TestType = Duck;
		
		alias serialClasses = AliasSeq!(TestType, Erase!(Object, BaseClassesTuple!(TestType)));
		
		foreach (TT; serialClasses)
		{
			char[] bufferU = (fullyQualifiedName!(TT) ~ '\0').dup;
			printf("%s\n", bufferU.ptr);
		}
		
		TestType testState = makeState!TestType(4.0, 20.0, HorizontalDir.right);
		ubyte[maxStateSerializationSize] testBuff, secondTestBuff;
		serializeSupers!(TestType)(testState, testBuff);
		writeln("TestState Serialization:\n", testBuff);
		State testPolyState = testState;
		testPolyState.serializeState(testBuff);
		writeln("TestPolyState Serialization:\n", testBuff);
		State deState = deserializeState(testBuff);
		deState.serializeState(secondTestBuff);
		writeln("TestState De-serialization:\n", secondTestBuff);
	}
	
      
        //Collects all garbage and suspends the GC
        GC.collect();
        
        GC.disable();
        
        //This is where everything that avoids using the GC and exceptions goes while running.
        realtime();
}

//Winsock helper functions
@nogc
{
	ushort MAKEWORD(ubyte lo, ubyte hi)
	{
		ubyte[2] array = [lo, hi];
		ushort[] retArr = cast(ushort[])array;
		return retArr[0];
	}

	ubyte LOBYTE(ushort data)
	{
		ushort* sPtr = &data;
		ubyte* bPtr = cast(ubyte*)(sPtr);
		return *bPtr;
	}

	ubyte HIBYTE(ushort data)
	{
		ushort* sPtr = &data;
		ubyte* bPtr = cast(ubyte*)(sPtr);
		return *(bPtr+1);
	}
}


void realtime() @nogc
{
	//Main loop flag
	bool quit = false;
	//Event handler
	SDL_Event e;
	//Is the game paused?
	bool paused = false;
	
	alias Side = bool;
	
	const Side LEFT = false;
	const Side RIGHT = true;
	
	Side playerSide = LEFT;
	
	void toggleSide() @nogc
	{
		playerSide = !playerSide;
	}
	
	//Gets keyboard input
	const Uint8* currentKeyStates = SDL_GetKeyboardState(null);
	uint initTime = SDL_GetTicks();
	
	alias FrameNo = ushort;
	FrameNo frameCounter = 0;
	
	void resetFrameCounter() @nogc
	{
		frameCounter = 0;
	}
	
	setupControllers();
	scope(exit)
	  takedownControllers();
	  
	setupGame();
	
	GameFrameQueue gfq = GameFrameQueue(true);
	
	//Initialize networking status variables;
	const int UNUSED = -1;
	const int SUCCESS = 0;
	const int FAILURE = 1;
	
	int networkStartSuccess = UNUSED;
	int networkConnectSuccess = UNUSED;//Default state
	
	
	bool NetworkingCurrentlyEnabled = false;
	bool currentFrameReceived = false;
	
	version (Windows)
	{
		import core.sys.windows.winsock2;

		WSADATA wsaData;
		SOCKET ss;
		char[32] sendIPString;
		SOCKADDR_IN receiveAddr;
		ushort port = 5998;
		
		SOCKET opposingSocket;
		SOCKADDR recievedSenderAddr;
		int receivedSenderSize = SOCKADDR.sizeof;
		ushort opposingPort = 49970;
		
		//Default connection
		uint defConnectionIP = inet_addr("127.0.0.1");
			
	
		int startNetworking() @nogc
		{
			// Initialize Winsock version 2.2
			if ((WSAStartup(MAKEWORD(2,2), &wsaData)) != 0)
			{
			  printf("WSAStartup failed with error %ld\n", WSAGetLastError());

			  return FAILURE;
			}

			printf("Winsock DLL found!\n");
			printf("The current status is: %s.\n", wsaData.szSystemStatus.ptr);
		   
			if (LOBYTE(wsaData.wVersion) != 2 || HIBYTE(wsaData.wVersion) != 2 )
			{
				//Tell the user that we could not find a usable WinSock DLL
				printf("The DLL does not support Winsock version %u.%u!\n",
							LOBYTE(wsaData.wVersion),HIBYTE(wsaData.wVersion));
				// When your application is finished call WSACleanup
				if (WSACleanup() == SOCKET_ERROR)
					printf("WSACleanup failed with error %d\n", WSAGetLastError());
				else
					printf("Closed Winsock.\n\n");
				
				return FAILURE;
			}

			printf("The DLL supports Winsock version %u.%u!\n", LOBYTE(wsaData.wVersion),
					HIBYTE(wsaData.wVersion));
			printf("The highest version this DLL can support is: %u.%u\n", LOBYTE(wsaData.wHighVersion),
					HIBYTE(wsaData.wHighVersion));
					
			//Bind UDP socket here.
			ss = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
			
			if (ss == INVALID_SOCKET)
			{
			  printf("Server: Error occured in socket(), error code: %ld\n", WSAGetLastError());
			  
			if (WSACleanup() == SOCKET_ERROR)
				printf("WSACleanup failed with error %d\n", WSAGetLastError());
			else
				printf("Closed Winsock.\n\n");
		  
			  return FAILURE;
			}
			
			printf("Server: New socket is OK!\n");
			
			const uint BLOCKING_SOCKET = 0;
			const uint NON_BLOCKING_SOCKET = 1;
			
			//Socket set to be non-blocking
			uint iMode = BLOCKING_SOCKET;//One means not-blocking, why this isn't already defined as a constant I have no idea
			int iResult = ioctlsocket(ss, FIONBIO, &iMode);
			if (iResult == SOCKET_ERROR)
			{
				printf("ioctlsocket failed with error: %ld\n", iResult);
				
				if (WSACleanup() == SOCKET_ERROR)
					printf("WSACleanup failed with error %d\n", WSAGetLastError());
				else
					printf("Closed Winsock.\n\n");
					
				if(closesocket(ss) == SOCKET_ERROR)
					printf("Server: Cannot close \\Server\\ socket. Error code: %ld\n", WSAGetLastError());
				else
					printf("Server: Closing \\Server\\ socket...\n");
			}
			
			
			// The IPv4 family
			receiveAddr.sin_family = AF_INET;
			// host-to-network byte order
			receiveAddr.sin_port = htons(port);
			// Listen on all interface, host-to-network byte order
			receiveAddr.sin_addr.s_addr = htonl(INADDR_ANY);
			
			if (bind(ss, cast(SOCKADDR *)&receiveAddr, receiveAddr.sizeof) == SOCKET_ERROR)
			{
				printf("Server: bind() failed! Error code: %ld.\n", WSAGetLastError());
				
				if (WSACleanup() == SOCKET_ERROR)
					printf("WSACleanup failed with error %d\n", WSAGetLastError());
				else
					printf("Closed Winsock.\n\n");
					
				if(closesocket(ss) == SOCKET_ERROR)
					printf("Server: Cannot close \\Server\\ socket. Error code: %ld\n", WSAGetLastError());
				else
					printf("Server: Closing \\Server\\ socket...\n");
				
				return FAILURE;
			}
			
			printf("Socket bound to port: %i\n", port);
			
			return SUCCESS;
		}
		
		int setSocketTimeoutValue(SOCKET sock, uint timeoutValue) @nogc
		{
			if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, cast(const(void)*) &timeoutValue, timeoutValue.sizeof) == SOCKET_ERROR)
			{
				printf("setsockopt failed with error: %d\n", WSAGetLastError());
				
				return FAILURE;
			}
			
			return SUCCESS;
		}
		 
		
		//Accepts a null terminated string
		int setupConnection(const char[] opponentIPstring) @nogc
		{
			if (networkStartSuccess != SUCCESS)
			{
				printf("Network procedures failed to initialize, so networking is not available.\n");
				return FAILURE;
			}
			
			if (opponentIPstring[0] == '\0' || opponentIPstring[0] == '\n')
			{
				//Returns UNUSED so that networking can be disabled when an 'empty' string is passed in.
				printf("Networking set to self.\n");
			}
			
			SOCKADDR_IN sendAddr;
		
			// The IPv4 family
			sendAddr.sin_family = AF_INET;
			// host-to-network byte order
			sendAddr.sin_port = htons(port);
			// Listen on all interface, host-to-network byte order
			if (opponentIPstring[0] == '\0' || opponentIPstring[0] == '\n')
			{
				sendAddr.sin_addr.s_addr = defConnectionIP;
			}
			else
			{
				defConnectionIP = inet_addr(opponentIPstring.ptr);
				sendAddr.sin_addr.s_addr = defConnectionIP;
			}
			
			ubyte[16] sendBuff = cast(ubyte[16]) "Hello, how are u";//[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1];
			
			if  (SOCKET_ERROR == sendto(ss, cast(void*)sendBuff.ptr, sendBuff.sizeof, 0,
					cast(SOCKADDR *) &sendAddr, sendAddr.sizeof))
			{
				printf("sendto failed with error: %d\n", WSAGetLastError());
				return FAILURE;
			}
			
			//Sets timeout value for Server Socket to 10 seconds
			setSocketTimeoutValue(ss, 10000);
			
			ubyte[512] msgBuffer;
			
			//passing in .length-1 is important, as it allows space for the null terminator
			int msgLength = recvfrom(ss, cast(void*)msgBuffer.ptr, cast(int)msgBuffer.length - 1, 0, &recievedSenderAddr, &receivedSenderSize);
		 
			if (msgLength == SOCKET_ERROR)
			{
				printf("Server: recvfrom() failed! No Hello! Error code: %ld.\n", WSAGetLastError());
				return FAILURE;
			}
			
			msgBuffer[msgBuffer.length-1] = '\0';
				
			printf("Message: %s\n", cast(char*)msgBuffer.ptr);
			
			char[5] hello = ['H', 'e', 'l', 'l', 'o'];
			
			if (msgBuffer[0..5] !=  hello)
			{
				printf("Handshake failed. Opponent did not say Hello!\n");
				return FAILURE;
			}
			
			with ((cast(sockaddr_in)recievedSenderAddr).sin_addr.S_un.S_un_b)
			{
				sendBuff[0] = 'A';
				sendBuff[1] = 'l';
				sendBuff[2] = 'o';
				sendBuff[3] = 'h';
				sendBuff[4] = 'a';
				sendBuff[5] = s_b1;
				sendBuff[6] = s_b2;
				sendBuff[7] = s_b3;
				sendBuff[8] = s_b4;
			}

			sendto(ss, cast(void*)sendBuff.ptr, sendBuff.sizeof, 0,
				&recievedSenderAddr, receivedSenderSize);
			
			//Set opposing port no.
			(cast(SOCKADDR_IN)recievedSenderAddr).sin_port =  htons(opposingPort);
			
			with ((cast(sockaddr_in)recievedSenderAddr).sin_addr.S_un.S_un_b)
			{			
				printf("Opponent IP set to : %i.%i.%i.%i\n", s_b1, s_b2, s_b3, s_b4);
			}
			
			msgLength = recvfrom(ss, cast(void*)msgBuffer.ptr, cast(int)msgBuffer.length - 1, 0, &recievedSenderAddr, &receivedSenderSize);
		 
			if (msgLength == SOCKET_ERROR)
			{
				printf("Server: recvfrom() failed! No Aloha! Error code: %ld.\n", WSAGetLastError());
				return FAILURE;
			}
			
			msgBuffer[msgBuffer.length-1] = '\0';
			
			char[5] aloha = ['A', 'l', 'o', 'h', 'a'];
			
			if (msgBuffer[0..5] !=  aloha)
			{
				printf("Handshake failed. Opponent did not say Aloha!\n");
				return FAILURE;
			}
			
			SOCKADDR_IN connectedRecvAddr;
			
			// The IPv4 family
			connectedRecvAddr.sin_family = AF_INET;
			// host-to-network byte order
			connectedRecvAddr.sin_port = htons(port);
			// Listen on all interface, host-to-network byte order
			connectedRecvAddr.sin_addr.S_un.S_un_b.s_b1 = msgBuffer[5];
			connectedRecvAddr.sin_addr.S_un.S_un_b.s_b2 = msgBuffer[6];
			connectedRecvAddr.sin_addr.S_un.S_un_b.s_b3 = msgBuffer[7];
			connectedRecvAddr.sin_addr.S_un.S_un_b.s_b4 = msgBuffer[8];
			
			with ((cast(sockaddr_in)connectedRecvAddr).sin_addr.S_un.S_un_b)
			{			
				printf("Connected receiving IP set to : %i.%i.%i.%i\n", s_b1, s_b2, s_b3, s_b4);
			}
			
			//Setup new connected Socket
			
			//First remove old socket
			if (networkConnectSuccess == SUCCESS)
			{
				if(closesocket(opposingSocket) == SOCKET_ERROR)
				{
					printf("Server: Cannot close \\Opponent\\ socket. Error code: %ld\n", WSAGetLastError());
					return FAILURE;
				}
				else
					printf("Server: Closing \\Opponent\\ socket...\n");
			}
			
			opposingSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
			
			if (opposingSocket == INVALID_SOCKET)
			{
			  printf("Server: Error occured in socket() for OpposingSocket, error code: %ld\n", WSAGetLastError());
			  
			  return FAILURE;
			}
			
			//We have to bind() anyway because of how Winsock works
			if (bind(opposingSocket, cast(SOCKADDR *) &connectedRecvAddr,  connectedRecvAddr.sizeof) == SOCKET_ERROR)
			{
				printf("Bind failed! Error code: %ld.\n", WSAGetLastError());
			
				if(closesocket(opposingSocket) == SOCKET_ERROR)
					printf("Server: Cannot close \\Opponent\\ socket. Error code: %ld\n", WSAGetLastError());
				else
					printf("Server: Closing \\Opponent\\ socket...\n");
					
				return FAILURE;
			}
			
			if (connect(opposingSocket, &recievedSenderAddr, receivedSenderSize) == SOCKET_ERROR)
			{
				printf("Connect failed! Error code: %ld.\n", WSAGetLastError());
				
				if(closesocket(opposingSocket) == SOCKET_ERROR)
					printf("Server: Cannot close \\Opponent\\ socket. Error code: %ld\n", WSAGetLastError());
				else
					printf("Server: Closing \\Opponent\\ socket...\n");
					
				return FAILURE;
			}
			
			//Sets timeout value to 0.1 seconds
			setSocketTimeoutValue(opposingSocket, 1000);
			
			printf("Server: New opposing socket is OK!\n");
			
			NetworkingCurrentlyEnabled = true;
			printf("Networking enabled!\n");
			
			resetFrameCounter();
			
			return SUCCESS;
		}
		
		int toggleNetworking() @nogc
		{
			NetworkingCurrentlyEnabled = !NetworkingCurrentlyEnabled;
			
			if (NetworkingCurrentlyEnabled)
				printf("Networking enabled!\n");
			else
				printf("Networking disabled!\n");
				
			
		
			if (networkConnectSuccess == SUCCESS)
				return SUCCESS;
				
			printf("Network connection has not been established!\n");
			
			return FAILURE;
		}
		
		const size_t inputWindowLength = 3;
		const size_t bufferSize = 3 + inputWindowLength*InputSerialization.sizeof;
		
		int performNetworkSyncSend() @nogc
		{
			if (networkConnectSuccess == SUCCESS && NetworkingCurrentlyEnabled)
			{
				ubyte[bufferSize] sendMsgBuffer;
				/*
				[0] = 'c'
				[1] = lower timestamp
				[2] = upper timestamp
				[3] = control inputs 0
				[4] = control inputs 1
				[5] = control inputs 2
				*/
				
				size_t pIndex = cast(size_t) playerSide;
				
				
				
				//Signal character
				sendMsgBuffer[0] = 'c';
				
				//Frame specific timestamp
				FrameNo[1] frameCountTemp = frameCounter;
				sendMsgBuffer[1..3] = cast(ubyte[2]) frameCountTemp;
				version(BigEndian)
				{
					reverse(sendMsgBuffer[1..3]);
				}
				
				with (Players[pIndex])
				{
					sendMsgBuffer[3] = serializeControlInput(ci);
					sendMsgBuffer[4] = gfq.retriveMinusNthInputForPlayer(1, pIndex);
					sendMsgBuffer[5] = gfq.retriveMinusNthInputForPlayer(2, pIndex);
				}

				
				if (send(opposingSocket, cast(void*)sendMsgBuffer.ptr, sendMsgBuffer.sizeof, 0) == SOCKET_ERROR)
				{
					printf("Sending failed! Error code: %ld.\n", WSAGetLastError());
				}
			}
		
			return SUCCESS;
		}
		
		int performNetworkSyncRecv() @nogc
		{
			if (networkConnectSuccess == SUCCESS && NetworkingCurrentlyEnabled)
			{
				SOCKADDR msgSenderAdr;
				int msgSenderAdrSize = msgSenderAdr.sizeof;
				
				ubyte[bufferSize] rcvMsgBuffer;
				
				size_t oIndex = cast(size_t) !playerSide;
				
				//Receive input
				while (!currentFrameReceived)
				{
					int msgLength = recv(opposingSocket, cast(void*)rcvMsgBuffer.ptr, cast(int)rcvMsgBuffer.length, 0);
					
					if (msgLength == SOCKET_ERROR)
					{
						printf("Network connection issues...\n");
						return FAILURE;
					}
					
					if (rcvMsgBuffer[0] == 'c')
					{
						version(BigEndian)
						{
							reverse(rcvMsgBuffer[1..3]);
						}
						FrameNo[1] rcvFrameCounter  = cast(FrameNo[1]) rcvMsgBuffer[1..3];
						FrameNo rcvFrameNo = rcvFrameCounter[0];
						
						if (rcvFrameNo == frameCounter)
						{
							deserializeControlInput(rcvMsgBuffer[3], Players[oIndex].ci);
							currentFrameReceived = true;
							break;
						}
						else if (rcvFrameNo > frameCounter)
						{
							int frameDiff = rcvFrameNo - frameCounter;
							
							if (frameDiff == 1)
							{
								deserializeControlInput(rcvMsgBuffer[4], Players[oIndex].ci);
								currentFrameReceived = true;
								break;
							}
						}
					}
					
				}
			}
			
			return SUCCESS;
		}
		
		void closeNetworking() @nogc
		{
			if (networkStartSuccess == SUCCESS)
			{
				if(closesocket(ss) == SOCKET_ERROR)
					printf("Server: Cannot close \\Server\\ socket. Error code: %ld\n", WSAGetLastError());
				else
					printf("Server: Closing \\Server\\ socket...\n");
					
				if (networkConnectSuccess == SUCCESS)
				{
					if(closesocket(opposingSocket) == SOCKET_ERROR)
						printf("Server: Cannot close \\Opponent\\ socket. Error code: %ld\n", WSAGetLastError());
					else
						printf("Server: Closing \\Opponent\\ socket...\n");
				}
			
				// When your application is finished call WSACleanup
				if (WSACleanup() == SOCKET_ERROR)
					printf("WSACleanup failed with error %d\n", WSAGetLastError());
				else
					printf("Closed Winsock.\n\n");
			}
		}
	}
	
	//Setup networking
	networkStartSuccess = startNetworking();
	//networkConnectSuccess = setupConnection("127.0.0.1");
	
	//Return value 0 means success
	scope (exit)
		closeNetworking();
	

	
	if (syncType == VSYNC)
	{
		SDL_GL_SwapWindow( gWindow );
	}
	
	TickDuration lastTime = TickDuration.currSystemTick();
	TickDuration firstTime = lastTime;
	TickDuration newTime;
	TickDuration dt;
	
	const long nanoFrameDuration = 1000000000/FRAME_RATE;
	printf("microFrameDuration: %i \n", nanoFrameDuration);
      
	//While application is running
	while( !quit )
	{
		//Networking currently changes the time that inpout events occur, allowing enough of a default delay so that the inputs can be transferred over the course of a frame
	  if (NetworkingCurrentlyEnabled)
	  {
		//Time update
		  newTime = TickDuration.currSystemTick();
		  dt = newTime - lastTime;
	  
		SDL_JoystickUpdate();
		
		if (playerSide == LEFT)
		{
		  setButtons(0, 0);
		  setButtons(1, 1);
		}
		else
		{
		setButtons(0, 1);
		setButtons(1, 0);
		}
		
		if (networkConnectSuccess == SUCCESS)
		{
		  const int noOfReRecvs = 3;
		  performNetworkSyncSend();
		  currentFrameReceived = false;
		  
		  //Sets timeout value to 0.001 seconds
		  setSocketTimeoutValue(opposingSocket, 1);
		  
		  for (int ii = 0; ii < noOfReRecvs - 1; ++ii)
		  {
			  //Slows down framerate if time passes too quickly
			  version (Windows)
			  {
				import core.sys.windows.winbase : Sleep;
				Sleep((nanoFrameDuration/1000000)/noOfReRecvs);//NOTE: Account for the extra time used for recv!
			  }
			  
			  performNetworkSyncSend();
			  if (performNetworkSyncRecv() == FAILURE)
				printf("Mini-sync failed.\n");
		  }
		  
		  //Sets timeout value to 0.1 seconds
		  setSocketTimeoutValue(opposingSocket, 1000);
		  
		  //Slows down framerate if time passes too quickly
		  version (Windows)
		  {
			import core.sys.windows.winbase : Sleep;
			Sleep((nanoFrameDuration/1000000)/noOfReRecvs);
		  }
		  
		  if (performNetworkSyncRecv() == FAILURE)
				printf("Major-sync failed.\n");
		}
		else
		{
			version (Windows)
			{
				import core.sys.windows.winbase : Sleep;
				Sleep((nanoFrameDuration/1000000));
			}
		}
		  
		//BUSY WAIT SECTION
		while (dt.nsecs < nanoFrameDuration)
		{

		newTime = TickDuration.currSystemTick();
		dt = newTime - lastTime;
		}

		lastTime = newTime;
	  }
	
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
			
			
			//Recieve command input from the console
			case SDLK_c:
			printf("Enter connection IP:\n");
			
			import core.stdc.stdio;
			
			char[32] inputBuffer;
			fgets(inputBuffer.ptr, 32, stdin);
			SDL_PumpEvents();
			//SDL_FlushEvents(0, uint.max);
			networkConnectSuccess = setupConnection(inputBuffer);
			break;
			
			case SDLK_j:
			playerSide = LEFT;
			printf("Player One assigned to the LEFT!\n");
			break;
			
			case SDLK_k:
			playerSide = RIGHT;
			printf("Player One assigned to the RIGHT!\n");
			break;
			
			//Enabled/disables Network data based gameplay
			case SDLK_n:
			toggleNetworking();
			break;
			
			//Pauses/Unpauses game when 'P' is pressed. This should prevent frame advancement, but continue rendering.
			case SDLK_p:
			paused = !paused;
			
			if (paused)
				printf("Game Paused!\n");
			else
				printf("Game Unpaused!\n");
			break;
			
			debug
			{
				/*
				saveState() saves the game state to a buffer
				restoreState() loads the game from that buffer
				
				writeSave() writes the buffer to a file
				readSave() loads the file to the buffer used by save/restoreState
				*/
				case SDLK_q:
				saveState();
				break;
				
				case SDLK_a:
				restoreState();
				break;
				
				case SDLK_w:
				writeSave();
				break;
				
				case SDLK_s:
				readSave();
				break;
			}
			
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
			
			paused = true;
			printf("Game Paused!\n");
			
		}
		else if (e.type == SDL_JOYDEVICEADDED)
		{
			printf("CONTROLER DEVICE #%i CONNECTED!\n", e.jdevice.which);
			attachControler(e.jdevice.which);
			printf("Number of joysticks connected: %i\n", SDL_NumJoysticks());
		}
	    
	  }
	  
	  //Input updating occurs right before the game update if networking is not occuring
		if (NetworkingCurrentlyEnabled == false)
		{
			SDL_JoystickUpdate();
		
			if (playerSide == LEFT)
			{
			  setButtons(0, 0);
			  setButtons(1, 1);
			}
			else
			{
			setButtons(0, 1);
			setButtons(1, 0);
			}
		}
	  
	  if (!paused)
		gameUpdate();
		
		void drawGraphics() @nogc
		{
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
		  
		  SDL_GL_SwapWindow( gWindow );
		}
	  
	  drawGraphics();
	  
	  //Increase frame counter after frame is displayed
	  frameCounter++;
	  
	  gfq.insertFrame(Players);
	  
	  
	  if (NetworkingCurrentlyEnabled == false)
	  {
		//Time update
		  newTime = TickDuration.currSystemTick();
		  dt = newTime - lastTime;
	  
		  version (Windows)
		  {
			import core.sys.windows.winbase : Sleep;
			Sleep((nanoFrameDuration/1000000));
		  }
		  
		  //This is a basic loop that waits and holds the CPU until the time is ready for a new frame, ideally this should be changed to a sleep() function
		  //This section should be timed to see how close it comes to taking zero time 
		  //BUSY WAIT SECTION
		  while (dt.nsecs < nanoFrameDuration)
		  {
			
			newTime = TickDuration.currSystemTick();
			dt = newTime - lastTime;
		  }
		  
		  lastTime = newTime;
	  }
	}
	

	//Prints on safe exit
	printf("Exit time: %u\n", SDL_GetTicks() - initTime);
	printf("Well done.\n");
}


struct Gamestate
{
	
}

greal arenaHalfwidth = 10.0;

Fighter P1;
Fighter P2;
Fighter[NoPlayers] Players;
const size_t FighterSize = __traits(classInstanceSize, Fighter);
void[FighterSize*NoPlayers] FighterData;

debug
@nogc
{
	import core.stdc.stdio;

	ubyte[maxStateSerializationSize][NoPlayers] serial;//For serialization testing
	InputSerialization[NoPlayers] serialInputs; //Stores input values;
	const char* saveLocation = "./saves/savestate.save";
	
	size_t getStateSizeFromIndex(StateIndex stateindexNo)
	{
		switch (stateindexNo)
		{
			foreach (ii, TT; StateList)
			{
				case ii:
				return __traits(getPointerBitmap, TT)[0];
			}
			
			default:
			printf("Incoherent state!\n");
			return 0;
		}
	}
	
	void saveState()
	{
		serialInputs[0] = serializeControlInput(P1.ci);
		serialInputs[1] = serializeControlInput(P2.ci);
		P1.state.serializeState(serial[0]);
		P2.state.serializeState(serial[1]);
		
		printf("State stored!\n");
	}
	
	void restoreState()
	{
		deserializeControlInput(serialInputs[0], P1.ci);
		deserializeControlInput(serialInputs[1], P2.ci);
		State storedState1 = deserializeState(serial[0]);
		State storedState2 = deserializeState(serial[1]);
		P1.restoreState(storedState1);
		P2.restoreState(storedState2);
		
		printf("State REstored!\n");
	}
	
	void writeState(FILE* fp, in ubyte[] stateBuffer)
	{
		StateIndex[] stateInd = cast(StateIndex[])(stateBuffer[0..StateIndex.sizeof]);
		
		size_t state_size = getStateSizeFromIndex(stateInd[0]);
		
		printf("stateNo: %i\nstate_size: %d\n", stateInd[0], state_size);
		
		fwrite(stateBuffer.ptr, 1, state_size, fp);
	}
	
	void writeSave()
	{
		FILE* fp;
		
		fp = fopen(saveLocation, "w+");
		//fputs("save stuff here hey\n", fp);
		
		fwrite(serialInputs.ptr, InputSerialization.sizeof, 2, fp);
		writeState(fp, serial[0]);
		writeState(fp, serial[1]);
		
		fclose(fp);
		
		printf("State saved to file!\n");
	}
	
	void readState(FILE* fp, ubyte[] stateBuffer)
	{
		//First read in the state index from the file into the initial bytes of the buffer
		fread(stateBuffer.ptr, 1, StateIndex.sizeof, fp);
		
		//This should then work, given the index (though nothing else yet) is in the buffer
		StateIndex[] stateInd = cast(StateIndex[])(stateBuffer[0..StateIndex.sizeof]);
		
		size_t state_size = getStateSizeFromIndex(stateInd[0]);
		
		//Read in the rest of the state, now we know its size
		fread(stateBuffer.ptr+StateIndex.sizeof, 1, state_size-StateIndex.sizeof, fp);
	}
	
	void readSave()
	{
		FILE* fp;
		
		fp = fopen(saveLocation, "r");
		
		if (fp)
		{
			fread(serialInputs.ptr, ubyte.sizeof, 2, fp);
			readState(fp, serial[0]);
			readState(fp, serial[1]);
			
			fclose(fp);
			
			printf("Save loaded from file!\n");
		}
		else
		{
			printf("No save file exists!");
		}
	}
}

void setupGame() @nogc
{
  //P1 = make!Fighter(makeState!Idle(-5.0, 0.0), fighterSkeleton);
  //P2 = make!Fighter(makeState!Idle(5.0, 0.0), fighterSkeleton);
  P1 = emplace!Fighter(FighterData[0..FighterSize], makeState!Idle(-5.0, 0.0, HorizontalDir.right), skeletons[fighterSkeleton]);
  P2 = emplace!Fighter(FighterData[FighterSize..$], makeState!Idle(5.0, 0.0, HorizontalDir.left), skeletons[fighterSkeleton]);
  Players[0] = P1;
  Players[1] = P2;
  
  debug{saveState();}
}

void renderFighters() @nogc
{
	glPushMatrix();
		glTranslatef(0.0, -2.0, -15.0);
		P1.render();
		P2.render();
	glPopMatrix();
}

void collisions(State agent, State patient) @nogc
{
	if (agent.extended)
	{
		if (patient.parry)
		{
		}
		else if (agent.attack)
		{
		}
	}
	else if (agent.parry)
	{
	}
	else //Neutral case
	{
		//Handle possible blocking
	}
}


void gameUpdate() @nogc
{
  //Perform state copying before this point in order to preserve a set of frame snapshots
  P1.createUpdate();
  P2.createUpdate();
  P1.swapUpdate();
  P2.swapUpdate();
  collisions(P1, P2); //Creates new update set to swap
}

enum VerticalDir {neutral = 0, up = 1, down = -1};
enum HorizontalDir {neutral = 0, left = -1, right = 1};

struct ControlInput
{
  
  VerticalDir vertDir;
  HorizontalDir horiDir;
  
  bool[4] buttons;
}

alias InputSerialization = ubyte;

InputSerialization serializeControlInput(ref ControlInput cInput) @nogc
{
	with (cInput)
	{
		ubyte vir = cast(ubyte)((cast(int)(vertDir))+1);
		ubyte hor = cast(ubyte)(((cast(int)(horiDir))+1) << 2);
		ubyte[4] bs = [(cast(ubyte)buttons[0]) << 4, (cast(ubyte)buttons[1]) << 5, (cast(ubyte)buttons[2]) << 6, (cast(ubyte)buttons[3]) << 7];
		return vir | hor | bs[0] | bs[1] | bs[2] | bs[3];
	}
}

void deserializeControlInput(InputSerialization inByte, ref ControlInput cInputOut) @nogc
{
	with (cInputOut)
	{
		vertDir = cast(VerticalDir)		((cast(int)	(inByte & 0b00000011)) - 1);
		horiDir = cast(HorizontalDir)	((cast(int)((inByte & 0b00001100) >>> 2)) - 1);
		buttons[0] = cast(bool)			(			(inByte & 0b00010000) >>> 4);
		buttons[1] = cast(bool)			(			(inByte & 0b00100000) >>> 5);
		buttons[2] = cast(bool)			(			(inByte & 0b01000000) >>> 6);
		buttons[3] = cast(bool)			(			(inByte & 0b10000000) >>> 7);
	}
}


void setButtons(int playerNum, int controlNum) @nogc
{
	with (Players[playerNum])
	{
		//Causes the past values to take on those which were in current.
		pi = ci;
	}

  if (gGameControllers[controlNum])
  {
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
  else
  {
	with(Players[playerNum].ci)
	{
		foreach (int ii, ref bool button; buttons)
			button = 0;
		
		vertDir = VerticalDir.neutral;
		horiDir = HorizontalDir.neutral;
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
	  
	  void restoreState(State nState)
	  {
		assert(state);
		breakState(state);
		state = nState;
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

		glPushMatrix();
			glTranslatef(cast(float)x, cast(float)y, 0.0f);
			glRotatef(90.0*state.facing, 0.0, 1.0, 0.0);
			drawFighter(state);
		glPopMatrix();

		 
		 
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
  public greal halfWidth = 1.0;
  alias state this;
  
}

//This should list all non-abstract subclasses of State
alias StateList = AliasSeq!(Idle, Step, Duck, Kick);

pure size_t maxStateSizeCalc()
{
	size_t maximum = 0;
	
	foreach (sym;  StateList)
	{
		size_t cSize = __traits(getPointerBitmap, sym)[0]; //__traits(classInstanceSize, sym);
		if (cSize > maximum)
			maximum = cSize;
	}
	
	return maximum;
}

pure size_t minStateSizeCalc()
{
	size_t minimum = size_t.max;
	
	foreach (sym;  StateList)
	{
		size_t cSize = __traits(getPointerBitmap, sym)[0]; //__traits(classInstanceSize, sym);
		if (cSize < minimum)
			minimum = cSize;
	}
	
	return minimum;
}

const size_t minStateSize = minStateSizeCalc(); //__traits(classInstanceSize, Idle); //SizeOf!(Idle);
const size_t maxStateSize = maxStateSizeCalc(); //__traits(classInstanceSize, Duck); //SizeOf!(Duck);
FreeList!(Mallocator, minStateSize, maxStateSize) stateFreeList;


//IMPORTANT: States should only consist of members that can be copied over and are independent of the actual frame. i.e. Variables that can be copied by value or references to things that will never change.


@nogc
auto makeState(T, Args...)(auto ref Args args) if (is(T : State))
{
	import std.algorithm.iteration;
	//Makes sure that the each State subclass is added to the state list. Otherwise memory corruption could occur.
	static if (!__traits(isAbstractClass, T))
		static assert(staticIndexOf!(T, StateList) != -1);//-1 is returned by staticIndexOf if the element is not in the list

  //enum size_t SIZE = SizeOf!(T);
  auto mem = stateFreeList.allocate(__traits(classInstanceSize, T));
  
  return emplace!(T)(mem, args);
}

//(state.classinfo.init.length)

//Destroys a state created by either makeState or deserializeState
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

@nogc
void transferState(S1, S2)(S1 agent, S2 patient) 
{
	transferTensions(agent, patient);
	
	static if (is(S1 : AnimatedState) && is(S2 : AnimatedState))
	{
		patient.toBlendIndex = agent.anim;
	}
}

@nogc
void transferTensions(State agent, State patient)
{
	patient.tensionList = agent.tensionList;
}

//dynamicType = staticIndexOf!(typeof(this), StateList);
@nogc
size_t serializationHeaderSize(T)()
{
	//Must return the sizeof the information added by the Identity mixin
	return StateIndex.sizeof;
}

const size_t maxStateSerializationSize = maxStateSize+StateIndex.sizeof;

@nogc
size_t serializationSize(T)()
{
	return __traits(getPointerBitmap, T)[0] + serializationHeaderSize!(T)();
}

/**
This section contains three tiers of serialization function.

Serialize: Serializes an individual subclass, either a struct or one 'level' of a class's hierarchy
serializeSupers: Takes a class instance with a known type and serializes it, including all of the data in its parent classes
serializeState: Serializes an instance of a State polymorphically, adding a header consisting of a type index

The 'deserialize' functions correspond to the serialization ones.

deserializeState: implicitly requires a buffer of size maxStateSerializationSize to be passed to it.

**/


@nogc
size_t serialize(T)(ref T instance, ubyte[] output)
{	
	size_t offset = 0;

	foreach (ref field; instance.tupleof)
	{
		//The 'me' array consists of a single element corresponding to the individual field that has been cast
		typeof(field)[] me = cast(typeof(field)[])output[offset..offset+field.sizeof];
		me[0] = field;
		version(BigEndian)
		{
			reverse(output[offset..offset+field.sizeof]);
		}
		offset += field.sizeof;
	}
	
	return offset;
}

@nogc
void serializeSupers(TT)(ref TT instance, ubyte[] output)
{	
	StateIndex[] head = cast(StateIndex[])output[0..StateIndex.sizeof];
	head[0] = staticIndexOf!(TT, StateList);
	
	size_t offset = StateIndex.sizeof;
	
	alias serClasses = Reverse!(AliasSeq!(TT, Erase!(Object, BaseClassesTuple!(TT))));
	
	foreach(CC; serClasses)
	{
		CC tempCC = cast(CC)(instance);
		offset += serialize!(CC)(tempCC, output[offset..+__traits(getPointerBitmap, TT)[0]]);
	}
}

//serializeState(ubyte[] input) is a virtual function within the state class

@nogc
size_t deserialize(T)(ref T instance, ubyte[] input)
{	
	size_t offset = 0;
	
	foreach (ref field; instance.tupleof)
	{
		typeof(field)[] me = cast(typeof(field)[])input[offset..offset+field.sizeof];
		version(BigEndian)
		{
			reverse(input[offset..offset+field.sizeof]);
		}
		field = me[0];
		offset += field.sizeof;
	}
	
	return offset;
}

void deserializeSupers(TT)(ref TT instance, ubyte[] input)
{
	size_t offset = 0;
	
	alias serClasses = Reverse!(AliasSeq!(TT, Erase!(Object, BaseClassesTuple!(TT))));

	foreach (CC; serClasses)
	{
		CC tempCC = cast(CC)(instance);
		offset += deserialize!(CC)(tempCC, input[offset..+__traits(getPointerBitmap, TT)[0]]);
	}
}

//Takes a buffer of size maxStateSerializationSize, containing a header and state information produced by serializeState
State deserializeState(ref ubyte[maxStateSerializationSize] input) @nogc
{
	StateIndex[] hdr = (cast(StateIndex[])(input[0..StateIndex.sizeof]));
	
	switch (hdr[0])
	{
		foreach(ii, TT; StateList)
		{
			case ii:
			auto stt = makeState!(TT)();
			deserializeSupers!(TT)(stt, input[serializationHeaderSize!(TT)()..serializationSize!(TT)()]);
			return stt;
		}
		
		default:
		return null;
	}
}

struct BufferedState
{
	StateIndex si;
}

abstract class State
{
  this() @nogc
  {}

  this(greal X, greal Y, HorizontalDir faceDirection) @nogc
  {x = X; y = Y; facing = faceDirection;}
  

  //Construct bools
  // bool animatedState = false;
  // bool attackState = false;
  // //Use the .offset property in order to store the pointer offset for each individual State and cast this to the AttackSubstate
  // bool defenceState = false;
  
	int index() @nogc {return 0;} 
	bool parry() @nogc {return false;}
	bool attack() @nogc {return false;}
	bool extended() @nogc {return false;}
	bool blocking() @nogc {return false;}
	
	int[5] tensionList;

  
  //~this() @nogc;
  
  //public greal x, y;
  public Vec2 pos;
  public HorizontalDir facing;
  // public alias x = pos.x;
  // public alias y = pos.y;
  
  BufferedState buffState;
  
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
		{return 0;}
		vreal z() const 
		{return 0;}
	}
	
	static Vec3 movePosition(ref Fighter parent, greal nx, greal ny) @nogc
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
		drawSkeletonMesh(parent.skel, animations[fighterAnimSquat], 1, true);
	}
	
	//Function must take a buffer of size at least maxStateSerializationSize.
	void serializeState(ubyte[] buffer) @nogc;
  
    State makeUpdate(Fighter parent) @nogc;
	
	State createNewState(S, Args...)(auto ref Args args) @nogc
	{	
		S ss = makeState!(S)(args);
		transferState(this, ss);
		return ss;
	}
}

abstract class AnimatedState : State
{
	AnimationIndex anim;
	AnimationIndex toBlendIndex = 0;
	//Animation* toBlendAnim = null;
	Animation* toBlendAnim() @nogc
	{
		return null; //&animations[toBlendIndex];
	}
	
	int timeFrame = 0;
	int timeFrame2 = 0;
	int ivalue;
	
	this() @nogc
	{}
	
	this(greal x, greal y, HorizontalDir facing, int time = 0, int time2 = 0, int interpolationValue = 0) @nogc
	{super(x,y, facing); timeFrame = time; timeFrame2 = time2; ivalue = interpolationValue;}
	
	Animation* getAnim() @nogc
	{
		return &animations[anim];
	}
	
	// void animateState(Fighter f) @nogc
	// {
		// drawSkeletonMesh(f.skel, getAnim(), 0.0, true);
	// }
	
	override void animateState(Fighter parent) @nogc
	{
		if (toBlendAnim == null)
			drawSkeletonMesh(parent.skel, *getAnim(), timeFrame, true);  
		else
			drawSkeletonMeshInterpolated(parent.skel, *getAnim(), *toBlendAnim, timeFrame, timeFrame2, ivalue, true);
	}
}


struct AttackSubstate
{
	struct AttackSphere
	{
		greal x, y, radius;
		bool active = false;
	}
	
	ref AttackSphere[10] attacks();
}

mixin template AttackMix()
{
	AttackSubstate attacks;
	
	bool attack() {return true;}
	
	 //bool attackState = true;
}

mixin template serializableState()
{
  auto retThis()
  {
	return this;
  }

  override void serializeState(ubyte[] buffer) @nogc
  {
	serializeSupers!(typeof(retThis()))(this, buffer);
  }
}

class Idle : AnimatedState
{
	// int timeFrame = 0;
  this() @nogc
  {}
  
  this(greal x, greal y, HorizontalDir facing, int time = 0) @nogc
  {super(x,y, facing, time); anim = fighterAnimKick;}
  
  //~this() @nogc {}
  
  override State makeUpdate(Fighter parent) @nogc
  {
	with (parent.ci)
	{
		//debug printf("Idle\n");
		if (buttons[0])
		  return makeState!Duck(x,y, facing);
		else if (horiDir != HorizontalDir.neutral)
		{
			//movePosition(parent, x+parent.ci.horiDir*0.1, y);
		
			return makeState!Idle(movePosition(parent, x+horiDir*(VerticalDir.down == vertDir ? 0.04 : 0.1), y).x, y, facing, (timeFrame+1 > getAnim().frameNos.length)? 0: timeFrame+1);
		}
		else
		  //return makeState!Idle(x,y, facing, (timeFrame+1 > getAnim().frameNos.length)? 0: timeFrame+1);
		  return createNewState!(Idle)(x,y, facing, (timeFrame+1 > getAnim().frameNos.length)? 0: timeFrame+1);
	}
  }
  
  mixin serializableState;
}

class Step : State
{
	this() @nogc
	{}
	
   this(greal x, greal y, HorizontalDir facing) @nogc
  {super(x,y, facing);}

	override State makeUpdate(Fighter parent) @nogc
  {
	x = x + parent.ci.horiDir;
	y = y + parent.ci.vertDir;
		
	return makeState!Step(x,y, facing);
  }
  
  mixin serializableState;
}

class Duck : AnimatedState
{
  this() @nogc
  {}
  
  this(greal x, greal y, HorizontalDir facing, int time = 0) @nogc
  {super(x,y, facing, time); anim = fighterAnimSquat;}
  
  override State makeUpdate(Fighter parent) @nogc
  {
    //debug printf("Duck\n");
    if (parent.ci.buttons[1])
      return makeState!Idle(x,y, facing);
    else
      return makeState!Duck(x,y, facing, timeFrame+1);
  }
  
  mixin serializableState;
}

class Kick : AnimatedState
{
	// int timeFrame = 0;
  this() @nogc
  {}
	
  this(greal x, greal y, HorizontalDir facing, int time = 0) @nogc
  {super(x,y, facing, time); anim = fighterAnimKick;}
  
  //~this() @nogc {}
  
  override State makeUpdate(Fighter parent) @nogc
  {
    //debug printf("Idle\n");
    if (parent.ci.buttons[0])
      return makeState!Duck(x,y, facing);
    else if (parent.ci.horiDir != HorizontalDir.neutral)
	{
		//movePosition(parent, x+parent.ci.horiDir*0.1, y);
	
		return makeState!Idle(movePosition(parent, x+parent.ci.horiDir*0.1, y).x, y, facing, (timeFrame+1 > getAnim().frameNos.length)? 0: timeFrame+1);
	}
	else
      return makeState!Idle(x,y, facing, (timeFrame+1 > getAnim().frameNos.length)? 0: timeFrame+1);
  }
  
  bool attackState = true;
  mixin AttackMix;
  mixin serializableState;
}