/+
This file is part of GeoTool, a map viewer/editor for Lego Rock Raiders.
Copyright (C) 2014-2016  sheepandshepherd

GeoTool is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

GeoTool is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GeoTool; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
+/

module main;

import std.stdio : writeln, write, writefln, writef, readln;
import core.thread;
import std.math, std.random;
import std.string, std.conv, std.math, std.file, std.path;
import derelict.util.exception, derelict.util.loader;
import derelict.opengl3.gl3, derelict.glfw3.glfw3;
import derelict.imgui.imgui;
import derelict.devil.il, derelict.devil.ilu, derelict.devil.ilut; // derelict.assimp3.assimp, 
import util.linalg;
import util.texture;
import glamour.shader : Shader;
import glamour.vbo : Buffer;
import glamour.vao : VAO;
import dialog;
import std.algorithm.comparison : clamp, max, min;
import std.algorithm.searching : canFind;

import std.process;

import tile;
import std.typecons : EnumMembers;

import ui;

import core.stdc.stdlib : exit;

import map,biome;

/// Data
static immutable void[] icon = import("geotool.ico");
uint iconHandle; /// OpenGL handle for the icon

/// Globals
debug string versionString = "Debug Beta 2\0";
else string versionString = "Beta 2\0";
string path;
GLFWwindow* window;
vec2d mouse = vec2d(0.0,0.0);
float mouseScroll = 0;
vec2i m = vec2i(0,0);
vec2 mNorm = vec2(0f,0f);
ubyte mb = 0;
vec3i mPanPos = vec3i(0,0,0);
vec3i mPanAmount = vec3i(0,0,0);
bool mouseInUI = false;
Shader terrainShader, texturedRectShader, colorShader;
uint[5] texturedRectShaderIDs = 0;

enum MouseButton : ubyte
{
	left = 1<<1,
	right = 1<<2,
	middle = 1<<3,
}

/// Instructions for main loop
bool showLoadMenu = true;
bool matUpdate = true; // update the MVP matrix this frame?

/// Config stuff, saved to config.cfg
bool wFullscreen = false;
vec2 wPos = vec2(0,0);
string[5] pSurfM, pHighM, pHighI;

ushort screenshotNumber = 0; // start with this number (saves time when searching existing screenshots)

/// loop stuff
bool quit = false;
string[] biomeRemovalQueue = [], dropQueue = [];
double time = 0.0;
double timePrev = 0.0;
double deltaTime = 0.0;
long toMS(double tS) { return cast(long)(tS/1000f); }
long timeMS() @property { return toMS(time); }
long timePrevMS() @property { return toMS(timePrev); }
long deltaTimeMS() @property { return toMS(deltaTime); }

bool[512] pressedLastFrame = false;
bool keyPressed(size_t key)
{
	return UI.io.KeysDown[key] && !pressedLastFrame[key];
}
bool keyHold(size_t key)
{
	return UI.io.KeysDown[key];
}

int width = 1024, height = 768;

void debugLog(S...)(S ss)
{
	string logText = "";
	foreach(s; ss)
	{
		logText~=text(s);
	}
	std.file.append(path~"\\log.txt","\n"~logText);
	std.stdio.writeln(logText);
}

/// GLFW error callback
extern(C) nothrow void errorCB(int error, const(char)* description)
{
	import std.conv;
	try debugLog("GLFW error: ", error, " (", to!string(description),")");
	catch(Exception e)
	{
		
	}
}

/// OpenGL debug context callback, only needed in debug mode
debug extern(System) nothrow void glDebugCB(uint source, uint type, uint id, uint severity, int length, in char* message, void* userParam)
{
	import std.conv;
	if(type == GL_DEBUG_TYPE_PERFORMANCE_ARB || type == GL_DEBUG_TYPE_OTHER_ARB) return;
	try debugLog("GL debug callback: ", message[0..length]);
	catch(Exception e)
	{
		
	}
}

ImVec4 RGBA(ubyte r, ubyte g, ubyte b, ubyte a = 255)
{
	return ImVec4(r/255f, g/255f, b/255f, a/255f);
}

void main(string[] args)
{
	path = thisExePath().dirName();


	// make the debug log
	if(std.file.exists(path~"\\log.txt")) std.file.remove(path~"\\log.txt");
	std.file.write(path~"\\log.txt","Geotool "~versionString~" log: "~std.datetime.Clock.currTime.toISOExtString);

	try{
		DerelictGL3.load();
		DerelictGLFW3.load();
		DerelictImgui.load();
		///DerelictASSIMP3.load();
		DerelictIL.load();
		DerelictILU.load();
		DerelictILUT.load();
		ilInit();
		iluInit();
		ilutInit();
		ilutRenderer(ILUT_OPENGL);
		ilEnable(IL_FILE_OVERWRITE);
		ilEnable(IL_ORIGIN_SET);
		ilOriginFunc(IL_ORIGIN_LOWER_LEFT);
	}
	catch(DerelictException de)
	{
		debugLog("Failed to load Derelict libs: "~de.msg);
		throw new Exception("Failed to load Derelict libs");
	}

	glfwSetErrorCallback(&errorCB);

	if( !glfwInit() )
	{
		debugLog("Failed to initialize GLFW3");
		throw new Exception("Failed to initialize GLFW3");
	}
	
	glfwWindowHint(GLFW_CLIENT_API,GLFW_OPENGL_API);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR,3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR,3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	debug glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, true);

	window = glfwCreateWindow(width, height,"GeoTool",null,null);
	
	if(window is null)
	{
		debugLog("Window creation failed.");
		throw new Exception("Window creation failed.");
	}
	glfwMakeContextCurrent(window);

	debugLog("Created GLFW window.");



	debugLog("Loaded base opengl. Version: "~ text(DerelictGL3.loadedVersion));
	DerelictGL3.reload;
	debugLog("Reloaded opengl. Version: "~ text(DerelictGL3.loadedVersion)~"\n");
	
	glfwMakeContextCurrent(window);
	glfwSwapInterval(2);

	debug
	{
		glDebugMessageCallbackARB(&glDebugCB, null);
		glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS_ARB);
	}
	
	/// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


	cubeVerts[] *= 0.25f;
	foreach(i; 0..(cubeVerts.length/9))
	{
		float[3] temp = cubeVerts[9*i..9*i+3];
		cubeVerts[9*i..9*i+3] = cubeVerts[9*i+3..9*i+6];
		cubeVerts[9*i+3..9*i+6] = temp;
	}
	Buffer vCubeVerts = new Buffer(cubeVerts);
	float[] cubeUVs = cubeVerts.dup;
	foreach(i; 0..(cubeUVs.length/3))
	{
		cubeUVs[i*3+2] = 70f;
	}
	Buffer vCubeUVs = new Buffer(cubeUVs);

	
	/// init internal storage and assets
	with(Tile) // used to be in static constructor
	{
		with(Type)
		{
			// build the wallTex array: used by the mesh update function to assign texture to TerrainMesh
			wallTex[solid] = [5,55,35,25];
			wallTex[hard] = [4,54,34,24];
			wallTex[loose] = [3,53,33,23];
			wallTex[dirt] = [2,52,32,22];
			wallTex[ore] = [40,70,70,70];
			wallTex[crystal] = [20,70,70,70];
			wallTex[recharge] = [67,70,70,70];
			
			groundTex[ground] = 0;
			groundTex[slug] = 30;
			groundTex[rubble] = 10;
			groundTex[path] = 60;
			groundTex[water] = 45;
			groundTex[lava] = 46;
			
			simpleTex = groundTex.dup;
			simpleTex[solid] = 5;
			simpleTex[hard] = 4;
			simpleTex[loose] = 3;
			simpleTex[dirt] = 2;
			simpleTex[ore] = 40;
			simpleTex[crystal] = 20;
			simpleTex[recharge] = 67;
			simpleTex[erosion] = 6;
			//simpleTex[soil] = 0; // doesn't exist in PC version; not sure if I'll leave it in or not   soil:RGBA(190,98,255),
			
			defaultColors = [ solid:RGBA(82,0,140), hard:RGBA(115,28,173), loose:RGBA(148,60,206), dirt:RGBA(173,89,239), water:RGBA(0,44,181), ground:RGBA(41,0,74), path:RGBA(160,160,240), rubble:RGBA(41,41,41), lava:RGBA(255,89,0), erosion:RGBA(148,45,37), slug:RGBA(148,128,37), ore:RGBA(156,65,8), crystal:RGBA(184,255,0), recharge:RGBA(255,255,0), ]; // default colors: will be used as blank texture if not loaded
			colors = defaultColors.dup;
		}
		
		/+crystalValues = [1:1, 3:1, 5:3, 7:3, 
			9:5, 0xb:5, 0xd:11, 0x13:11, 0x11:25, 0x17:25 ];
		oreValues = [ 2:1, 4:1, 6:3, 8:3, 0xa:5,
			0xc:5, 0x10:5, 0xe:11, 0x14:11, 0x12:25, 0x18:25 ];+/
	}

	Map.generateMapImages();

	/// load icon from internal data
	iconHandle = imageDataToGLTexture(IL_ICO,icon);

	texturedRectShader = new Shader("texturedrect",texturedrectsource130);
	texturedRectShaderIDs = [texturedRectShader.get_attrib_location("VertexPosition"), texturedRectShader.get_attrib_location("VertexTexCoord"), texturedRectShader.get_uniform_location("uColor"), texturedRectShader.get_uniform_location("Viewport"), texturedRectShader.get_uniform_location("Texture")];

	terrainShader = new Shader(buildPath(path,"terrain130.glsl"));
	terrainShader.bind;
	float[(EnumMembers!Type).length*3] colors = 0.5f;
	foreach(Type t, ImVec4 c; Tile.colors)
	{
		vec3 color = vec3(c.x, c.y, c.z);
		colors[t*3..t*3+3] = color.vector[0..3];
	}
	terrainShader.uniform3fv("colors",colors);

	colorShader = new Shader(buildPath(path,"color130.glsl"));

	// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	// Required vertex array
	// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	VAO vao = new VAO();
	vao.bind();

	// load external stuff
	/// settings files
	string[] settingsLines;
	if(exists(buildPath(path,"settings.ini")))
	{
		settingsLines = splitLines(std.file.readText(buildPath(path,"settings.ini")));

		// read each line and parse
		foreach(string l; settingsLines)
		{
			if(l.startsWith("pSurfM"))
			{
				savePathString((l.split('='))[1],pSurfM);
			}
			else if(l.startsWith("pHighM"))
			{
				savePathString((l.split('='))[1],pHighM);
			}
			else if(l.startsWith("pHighI"))
			{
				savePathString((l.split('='))[1],pHighI);
			}
			else if(l.startsWith("biome"))
			{
				string[] splitted = (l.split('='))[1].split(',');
				Biome b = Biome.loadFromFile(splitted[0],splitted[1]);
				if(l[5]=='*' && b !is null) Biome.selected = b;
			}
			else if(l.startsWith("hideCeiling"))
			{
				Map.hideCeiling = to!(bool)((l.split('='))[1]);
			}
			else if(l.startsWith("markHidden"))
			{
				Map.markHidden = to!(bool)((l.split('='))[1]);
			}
			else if(l.startsWith("markErosion"))
			{
				Map.markErosion = to!(bool)((l.split('='))[1]);
			}
			else if(l.startsWith("autoLoad"))
			{
				Map.autoLoad = to!(bool)((l.split('='))[1]);
			}
			else if(l.startsWith("autoOverwrite"))
			{
				Map.autoOverwrite = to!(bool)((l.split('='))[1]);
			}
		}
	}
	/// TODO: load the most recent map if it exists, then build/sort


	
	glClearColor(0.0f,0.0f,0.0f,1f);
	glEnable(GL_DEPTH_TEST);
	glDepthMask(GL_TRUE);
	glDepthFunc(GL_LEQUAL); //was LEQUAL -- using LESS to allow highlights to work
	//glClearDepth(1f);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


	extern(C) nothrow static void window_size_callback(GLFWwindow* window, int _width, int _height)
	{
		try
		{
			debugLog("Resizing window to ",_width,"x",_height);
		}
		catch{}
		width = _width;
		height = _height;

		// update GL and matrix
		glViewport(0,0,width,height);
		Map.updateMatrix();
	}
	glfwSetWindowSizeCallback(window,&window_size_callback);

	/// drag+drop input for loading maps! http://www.glfw.org/docs/3.1/input.html#input_drop
	extern(C) nothrow static void drop_callback(GLFWwindow* window, int count, const(char*)* paths)
	{
		const(char*)[] pathsArr = paths[0..count];
		string[] pathsD = new string[count];
		foreach(int i; 0..count)
		{
			// deep-copy (paths will be deleted by GLFW after the event)
			// this will rely on GLFW to provide correct paths without bounds-checking
			int end = 0;
			while(pathsArr[i][end] != '\0')
			{
				end++;
			}

			// add the path to list (which will be evaluated in main next frame)
			if(end > 0)
			{
				// can't use std.string.fromStringz here -- not nothrow
				pathsD[i] = pathsArr[i][0..end].idup;
			}
		}
		// handle nulls and std.file.exists later, when actually checking the list
		dropQueue ~= pathsD;
	}
	glfwSetDropCallback(window,&drop_callback);



	scope(exit)
	{
		// save ini
		saveINI();

		/// release internal resources
		glDeleteTextures(2,Map.mapImages.ptr);

		Map.cleanSortedMeshes();
		Map.cleanMeshes();

		texturedRectShader.unbind();
		texturedRectShader.remove();
		terrainShader.unbind();
		terrainShader.remove();
		colorShader.unbind();
		colorShader.remove();
		vao.unbind();
		vao.remove();

		biomeRemovalQueue = [];
		foreach(string bn, Biome b; Biome.biomes)
		{
			if(b.defaultBiome) continue; // don't bother deleting it, no textures

			biomeRemovalQueue ~= bn;
		}
		if(biomeRemovalQueue.length > 0)
		{
			foreach(string bn; biomeRemovalQueue)
			{
				Biome.biomes[bn].unload();
				Biome.biomes.remove(bn);
			}
			biomeRemovalQueue = null;
		}


		writeln("Destroying GLFW window...");
		glfwDestroyWindow(window);
		writeln("Terminating GLFW...");
		glfwTerminate();

		// exit program
		writeln("end...");
		exit(0); // was Application.exit(); from DGui
	}

	glViewport(0,0,width,height);
	/// Initialize UI
	debugLog("Initializing ImGui...");
	UI.initialize(window, true);
	scope(exit) UI.shutdown();
	debugLog("...done.");

	
	Map.updateMatrix();

	while( !glfwWindowShouldClose(window) )
	{
		// Wait(frames only on event) or Poll(full 60fps)
		glfwPollEvents();
		UI.io = igGetIO();

		/// handle drag-drop list
		if(dropQueue !is null && dropQueue.length > 0)
		{
			/+foreach(uint i, string p; dropQueue)
			{
				writeln("DROPPED: ",p);
				if(std.algorithm.searching.canFind(p,"surf"))
				{
					Map.loadSurfMap(p,dropQueue);
					break;
				}
				else if(std.algorithm.searching.canFind(p,"high"))
				{
					Map.loadHighMap(p,dropQueue);
					break;
				}
			}+/

			Map.load(dropQueue);

			dropQueue = null;
		}


		// biome removal queue - used to schedule deletion
		// deleting immediately crashes if biome's textures are still used in same frame
		if(biomeRemovalQueue.length != 0)
		{
			foreach(string bn; biomeRemovalQueue)
			{
				if(Biome.selected == Biome.biomes[bn])
					Biome.selected == Biome.biomes["default"];
				// release biome textures
				Biome.biomes[bn].unload();
				Biome.biomes.remove(bn);
			}
			biomeRemovalQueue = []; 
		}

		matUpdate = false;
		
		/// handle mouse
		mb = 0;
		if(glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS)
		{
			mb |= MouseButton.left;
		}
		if(glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT) == GLFW_PRESS)
		{
			mb |= MouseButton.right;
		}
		if(glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_MIDDLE) == GLFW_PRESS)
		{
			mb |= MouseButton.middle;
		}
		glfwGetCursorPos(window, &mouse.vector[0], &mouse.vector[1]);
		m = vec2i(cast(int)mouse.x,height-cast(int)mouse.y);

		mNorm = vec2( 2f*cast(float)m.x/cast(float)(width) - 1f, 2f*cast(float)m.y/cast(float)(height) - 1f );


		//mouseInUI = (m.x < 200 || m.x > width-200 || UI.newDialogOpen);
		mouseInUI = igIsMouseHoveringAnyWindow() || UI.newDialogOpen;

		/// handle clicking on the map to reposition view
		if((mb&MouseButton.left) && Map.mapSize != vec2ui(0, 0) && m.x < 200 && m.y > height-200)
		{
			// First, scale click location to map coordinates
			//vec4i bounds;
			vec2 clickPos;
			if(Map.w == Map.h)
			{
				clickPos = vec2( ((mouse.x-2f)/196f)*(Map.w), ((mouse.y-2f)/196f)*(Map.h));
			}
			else if(Map.w > Map.h)
			{
				float ratio = cast(float)Map.h/cast(float)Map.w;
				float thresh = 0.5*(196-(ratio*196));
				clickPos = vec2( ((mouse.x-2f)/196f)*(Map.w), ((mouse.y-2f-thresh)/(ratio*196f))*(Map.h) );
			}
			else if(Map.w < Map.h)
			{
				float ratio = cast(float)Map.w/cast(float)Map.h;
				float thresh = 0.5*(196-(ratio*196));
				clickPos = vec2( ((mouse.x-2f-thresh)/(ratio*196f))*(Map.w), ((mouse.y-2f)/196f)*(Map.h) );
			}
			
			// check if click is actually inside map area (it could be a non-square map):
			if(clickPos.x > 0f && clickPos.y > 0f && clickPos.x < (Map.w) && clickPos.y < (Map.h))
			{
				Map.cameraPos = clickPos;
				matUpdate = true;
			}
		}

		/// moved glfwPollEvents to bottom, hopefully this is correct
		/// todo: clean up the main loop
		
		/// handle controls
		if(keyPressed(GLFW_KEY_ESC))
		{
			glfwSetWindowShouldClose(window, true);
		}
		if(keyPressed(GLFW_KEY_F))
		{
			///debugLog("FPS: ",1/deltaTime,"  mouse: ", m.x,"/",mNorm.x, ",", m.y,"/",mNorm.y);
			UI.showDebug = !UI.showDebug;
		}

		// camera controls. if any are pressed during frame, reload the matrix.
		const float shiftMult = 3f, rateAngle = 0.5f, rateRot = 0.25f, rateZoom = 25f, ratePan = 15f;
		float shiftMod() @property { return (keyHold(GLFW_KEY_LEFT_SHIFT)||keyHold(GLFW_KEY_RIGHT_SHIFT))?shiftMult:1f; }
		if(keyHold(GLFW_KEY_UP)){Map.cameraAngle = std.algorithm.min(1f,Map.cameraAngle+(shiftMod*deltaTime*rateAngle));matUpdate = true;}
		else if(keyHold(GLFW_KEY_DOWN)){Map.cameraAngle = std.algorithm.max(0.1f,Map.cameraAngle-(shiftMod*deltaTime*rateAngle));matUpdate = true;}

		if(keyHold(GLFW_KEY_RIGHT)){ Map.cameraRot = Map.normalize(Map.cameraRot+(shiftMod*deltaTime*rateRot),1f);matUpdate = true; }
		else if(keyHold(GLFW_KEY_LEFT)){ Map.cameraRot = Map.normalize(Map.cameraRot-(shiftMod*deltaTime*rateRot),1f);matUpdate = true; }
		
		vec2 panVector = vec2(0f,0f);
		float camRotRadians = Map.cameraRot * std.math.PI * 2f;
		if(keyHold(GLFW_KEY_W)){ panVector += (vec2(0f,-1f));matUpdate = true; }
		if(keyHold(GLFW_KEY_S)){ panVector += (vec2(0f,1f));matUpdate = true; }
		if(keyHold(GLFW_KEY_A)){ panVector += (vec2(-1f,0f));matUpdate = true; }
		if(keyHold(GLFW_KEY_D)){ panVector += (vec2(1f,0f));matUpdate = true; }
		if(matUpdate)
		{
			panVector = vec2(panVector.x*cos(camRotRadians) - panVector.y*sin(camRotRadians), panVector.y*cos(camRotRadians) + panVector.x*sin(camRotRadians));
			panVector.normalize();
			panVector *= (shiftMod*deltaTime*ratePan);
			Map.cameraPos = vec2(clamp(Map.cameraPos.x+panVector.x,0f,cast(float)Map.w),clamp(Map.cameraPos.y+panVector.y,0f,cast(float)Map.h));
		}


		if(keyHold(GLFW_KEY_KP_ADD)||keyHold(GLFW_KEY_PAGEUP)){ Map.cameraZoom = std.algorithm.max(1.5f,Map.cameraZoom-(shiftMod*deltaTime*rateZoom)); matUpdate = true; }
		else if(keyHold(GLFW_KEY_KP_SUBTRACT)||keyHold(GLFW_KEY_PAGEDOWN)){ Map.cameraZoom = std.algorithm.min(25f,Map.cameraZoom+(shiftMod*deltaTime*rateZoom)); matUpdate = true; }

		/// scroll with mousewheel:
		if(!mouseInUI && (mouseScroll < -float.epsilon || mouseScroll > float.epsilon))
		{
			Map.cameraZoom = std.algorithm.clamp(Map.cameraZoom+(mouseScroll*shiftMod*deltaTime*rateZoom),1.5f,25f);
			matUpdate = true;
		}


		if(keyPressed(GLFW_KEY_HOME)){ Map.cameraPos = vec2(Map.w/2f,Map.h/2f); Map.cameraAngle = 0.8f; Map.cameraRot = 0f; Map.cameraZoom = 10f; matUpdate = true; }
		if(keyPressed(GLFW_KEY_F5) || keyPressed(GLFW_KEY_P))
		{
			uint tempImage = ilGenImage();
			ilBindImage(tempImage);
			ilutGLScreen();
			ilSaveImage(toStringz(buildPath(path,"screenshot"~getScreenshotNumber().text~".jpg")));
			ilDeleteImage(tempImage);
		}
		if(keyPressed(GLFW_KEY_M))
		{
			// print matrices
			writeln("MOUSE: ", m.x," /",mNorm.x, "  ,  ", m.y," /",mNorm.y);
			writeln();
			//writeln(Map.VP.inverse.as_string);
			writeln(Map.pR.normal, " ", Map.pL.normal, " ", Map.pT.normal, " ", Map.pB.normal);
			writeln();
			writeln(Map.f00," ",Map.f01," ",Map.f10," ",Map.f11," ");
			//writeln(Map.iVP.as_string);
		}

		if(matUpdate){ Map.updateMatrix(); matUpdate = false; }

		/++ RAYCASTING
		 + SLOW! TODO: figure out how to do view-frustum culling so less tiles get tested
		 + TODO: OL should get a separate raycast that identifies object instead of position.
		 + + + + + +/

		Map.highlights = null;
		float intersectDistance = float.nan; ///intersects = [];///.length = 0; // FIXME: is this the correct way to recycle an array?
		//vec4 mClient = vec4(mNorm.x, mNorm.y, -1f, 1f);
		vec4 ray = Map.iP * vec4(mNorm.x, mNorm.y, -1f, 1f);
		ray = Map.iV*vec4(ray.x, ray.y, -1f, 0f);
		ray = vec4(vec3(ray).normalized,0f);


		vec4 point = Map.iVP * vec4(mNorm.x, mNorm.y, -1f, 1f);
		point.w = 1f/point.w;
		point.x *= point.w;
		point.y *= point.w;
		point.z *= point.w;

		//point = vec4(vec3(Map.viewerPos.x,Map.viewerPos.y,-Map.viewerPos.z)+0.1f*vec3(ray),1f);

		//vec3 dir = vec3(Map.iVP * vec4(mNorm.x, mNorm.y, 1f, 1f));
		vec4 dir = Map.iVP * vec4(mNorm.x, mNorm.y, 1f, 1f);
		dir.w = 1f/dir.w;
		dir.x *= dir.w;
		dir.y *= dir.w;
		dir.z *= dir.w;
		dir -= point;
		dir.normalize();

		/+++++++++++++++++++if(Map.cull)
		{
			uint[4] blocked;
			foreach(uint x; 0..Map.w) foreach(uint y; 0..Map.h)
			{
				//if(Biome.selected.textures.get(texID,uint.max) == uint.max) continue;
				Map.TerrainMesh t = Map.meshes[x+Map.w*y];
				
				vec3 center = vec3(x+0.5f,y+0.5f,0f);
				center.z = Map.heightAtPos(center.x,center.y);

				if(Map.pR.distance(center) < 0f){blocked[0]++;}
				if(Map.pL.distance(center) < 0f){blocked[1]++;}
				if(Map.pT.distance(center) < 0f){blocked[2]++;}
				if(Map.pB.distance(center) < 0f){blocked[3]++;}

				foreach(uint i; 0..(t.verts.length/3))
				{
					int code = intersect(vec3(point.x, point.y, point.z),vec3(dir),t.verts[3*i..3*i+3], &inter);
					if(code == 1)
					{
						intersects ~= vec4(inter.x, inter.y, inter.z, (vec3(point) - inter).length_squared);
					}
				}
			}
			
			UI.debugMessage = "R"~text(blocked[0])~" L"~text(blocked[1])~" T"~text(blocked[2])~" B"~text(blocked[3]);
		}
		else+/
		{
			foreach( Map.TerrainMesh t; Map.sortedMeshes)
			{
				foreach(i; 0..(t.verts.length/3))
				{
					float inter = intersect(vec3(point.x, point.y, point.z), vec3(dir), t.verts[3*i..3*i+3]);
					if(!inter.isNaN && (intersectDistance.isNaN || inter < intersectDistance))
					{
						intersectDistance = inter;
						//intersects ~= inter; // vec4(inter.x, inter.y, inter.z, (vec3(point) - inter).length_squared);
					}
				}
			}
		}
		//int code = intersect(vec3(0,0,4),vec3(0,0,-1f),[vec3(-1,-1,0),vec3(0,1,0),vec3(1,-1,0)],&inter);
		//if(code == 1) intersects ~= vec4(inter.x, inter.y, inter.z, 0f); //(point - *inter).length_squared
		if(!intersectDistance.isNaN)
		{
			//if(intersects.length > 1) std.algorithm.sort!("a < b")(intersects);
			/// the intersection point
			vec3 inter = vec3(point) + (intersectDistance*vec3(dir));
			//UI.pickedCoord = vec2(intersects[0]).toString;
			vec2i coord;
			if(UI.mapMode == 1) // height: selection focus is on upper left corners, so subtract (0.5,0.5)
			{
				coord = vec2i(cast(int)floor(inter.x-0.5f),cast(int)floor(inter.y-0.5f));
			}
			else
			{
				coord = vec2i(cast(int)floor(inter.x),cast(int)floor(inter.y));
			}
			if(coord.x >= 0 && coord.x < Map.w)
				UI.pickedCoord.x = coord.x;
			else UI.pickedCoord.x = -1;
			if(coord.y >= 0 && coord.y < Map.h)
				UI.pickedCoord.y = coord.y;
			else UI.pickedCoord.y = -1;
		}
		else
		{
			UI.pickedCoord.x = -1;
			UI.pickedCoord.y = -1;
		}

		/// TODO: Middle mouse does camera movement, regardless of any other settings


		// No selection if mouse is within UI or if other windows are open
		if(mouseInUI)
		{
			/// Mouse in UI
			UI.pickedCoord.x = -1;
			UI.pickedCoord.y = -1;
		}
		else 
		{
			/// Mouse in viewport area.
			auto clicked = vec2ui(UI.pickedCoord);
			if(UI.editMode && Map.validCoord(clicked)) Map.mouseOverTile(clicked, mb);
		} // end else(mouse in viewport and NOT in ui)

		/// render terrain
		vao.bind();
		glEnable(GL_DEPTH_TEST);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		if( Map.tiles !is null && Map.sortedMeshes !is null && Map.sortedMeshes.length > 0) //Map.isMeshBuilt)
		{
			Map.renderMeshes();
		}

		/// render highlighted terrain
		if(Map.highlights !is null) Map.renderHighlights();

		/// render UI
		/// 
		//UI.renderOld();
		UI.render();
		
		glfwSwapBuffers(window);


		timePrev = time;
		time = glfwGetTime();
		deltaTime = time-timePrev;

		// reset keys
		foreach(k; 0..512)
		{
			pressedLastFrame[k] = UI.io.KeysDown[k];
		}
	}
	
	/+ unloading handled by scope(exit) +/
	
	
} // END main



ushort getScreenshotNumber()
{
	ushort start = screenshotNumber;
	while(exists(buildPath(path,"screenshot"~start.text~".jpg")))
	{
		start++;
	}
	screenshotNumber = start;
	return start;
}




static immutable string texturedrectsource130 = `#version 130

vertex:
uniform vec2 Viewport;
in vec2 VertexPosition;
in vec2 VertexTexCoord;
out vec2 texCoord;
void main(void)
{
	texCoord = VertexTexCoord;
	gl_Position = vec4(VertexPosition * 2.0 / Viewport - 1.0, 0.0, 1.0);
}

fragment:
in vec2 texCoord;
uniform vec4 uColor;
uniform sampler2D Texture;
//out vec4  Color;
out vec4 fragColor;

void main(void)
{
    //float alpha = texture2D(Texture, texCoord).r;
    vec4 tc = texture2D(Texture, texCoord).rgba; //vec4(vertexColor.rgb, vertexColor.a * alpha);
	fragColor = (tc*uColor).rgba;
    //fragColor = vec4(0.5,0.5,0.5, 1);
}`;
























void savePathString(string filePath, ref string[5] savedPaths)
{
	if(savedPaths[0] != filePath)
	{
		if(savedPaths[1] != filePath)
		{
			if(savedPaths[2] != filePath)
			{
				if(savedPaths[3] != filePath)
				{
					savedPaths[4] = savedPaths[3];
				}
				savedPaths[3] = savedPaths[2];
			}
			savedPaths[2] = savedPaths[1];
		}
		savedPaths[1] = savedPaths[0];
		savedPaths[0] = filePath;
	}
}

void saveINI()
{
	debugLog("Saving settings.ini");
	string data = "";
	data ~= "hideCeiling="~text(Map.hideCeiling)~"\r\n";
	data ~= "markHidden="~text(Map.markHidden)~"\r\n";
	data ~= "markErosion="~text(Map.markErosion)~"\r\n";
	data ~= "autoLoad="~text(Map.autoLoad)~"\r\n";
	data ~= "autoOverwrite="~text(Map.autoOverwrite)~"\r\n";
	foreach_reverse(uint i; 0..5)
	{
		if(pSurfM[i] != "") data ~= "pSurfM="~pSurfM[i]~"\r\n";
	}
	foreach_reverse(uint i; 0..5)
	{
		if(pHighM[i] != "") data ~= "pHighM="~pHighM[i]~"\r\n";
	}
	foreach_reverse(uint i; 0..5)
	{
		if(pHighI[i] != "") data ~= "pHighI="~pHighI[i]~"\r\n";
	}

	// biomes:
	foreach(Biome b; Biome.biomes)
	{
		if(b.name == "default") continue;
		data ~= ((b is Biome.selected)?"biome*=":"biome=")~b.name~","~b.path~"\r\n";
	}


	std.file.write(buildPath(path,"settings.ini"),data);
}







float[] cubeVerts = [
	-1.0f,-1.0f,-1.0f,
	-1.0f,-1.0f, 1.0f,
	-1.0f, 1.0f, 1.0f,
	1.0f, 1.0f,-1.0f,
	-1.0f,-1.0f,-1.0f,
	-1.0f, 1.0f,-1.0f,
	1.0f,-1.0f, 1.0f,
	-1.0f,-1.0f,-1.0f,
	1.0f,-1.0f,-1.0f,
	1.0f, 1.0f,-1.0f,
	1.0f,-1.0f,-1.0f,
	-1.0f,-1.0f,-1.0f,
	-1.0f,-1.0f,-1.0f,
	-1.0f, 1.0f, 1.0f,
	-1.0f, 1.0f,-1.0f,
	1.0f,-1.0f, 1.0f,
	-1.0f,-1.0f, 1.0f,
	-1.0f,-1.0f,-1.0f,
	-1.0f, 1.0f, 1.0f,
	-1.0f,-1.0f, 1.0f,
	1.0f,-1.0f, 1.0f,
	1.0f, 1.0f, 1.0f,
	1.0f,-1.0f,-1.0f,
	1.0f, 1.0f,-1.0f,
	1.0f,-1.0f,-1.0f,
	1.0f, 1.0f, 1.0f,
	1.0f,-1.0f, 1.0f,
	1.0f, 1.0f, 1.0f,
	1.0f, 1.0f,-1.0f,
	-1.0f, 1.0f,-1.0f,
	1.0f, 1.0f, 1.0f,
	-1.0f, 1.0f,-1.0f,
	-1.0f, 1.0f, 1.0f,
	1.0f, 1.0f, 1.0f,
	-1.0f, 1.0f, 1.0f,
	1.0f,-1.0f, 1.0f
];