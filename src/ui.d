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

module ui;

import imgui.api;
import derelict.opengl3.gl3;
import derelict.glfw3.glfw3;
import util.linalg;

import std.string : toStringz;

import main: window, width, height, m, mb, showLoadMenu, savePathString, saveINI, pSurfM, pHighI, pHighM, debugLog, versionString;
import main : filePath = path;
import map, biome;
import std.conv : text;
import dialog;

import std.algorithm.comparison : clamp, min, max;

import std.typecons : EnumMembers;
import tile : Tile, Type;

public int buttonHeight() @property {import imgui.engine : BUTTON_HEIGHT; return BUTTON_HEIGHT;}
public void buttonHeight(int bh) @property {import imgui.engine : BUTTON_HEIGHT; BUTTON_HEIGHT=bh;}
// copy of the defaultColorScheme for use in custom UI types
public ColorScheme colorScheme;
public ColorScheme yellowColorScheme;
public ColorScheme greenColorScheme;

const RGBA white = RGBA(255,255,255);
const RGBA gray = RGBA(127,127,127);
const RGBA black = RGBA(0,0,0);
const RGBA blue = RGBA(0,0,255);
const RGBA green = RGBA(0,255,0);
const RGBA red = RGBA(255,0,0);
const RGBA yellow = RGBA(255,255,0);
const RGBA orange = RGBA(255,127,0);

// background colors
const RGBA whiteBG = RGBA(255,255,255,127);
const RGBA grayBG = RGBA(127,127,127,127);
const RGBA blackBG = RGBA(0,0,0,127);
const RGBA blueBG = RGBA(0,0,255,127);
const RGBA greenBG = RGBA(0,255,0,127);
const RGBA redBG = RGBA(255,0,0,127);
const RGBA yellowBG = RGBA(255,255,0,127);
const RGBA orangeBG = RGBA(255,127,0,127);
const RGBA transparent = RGBA(0,0,0,0);

static class UI
{
static:
	string mapStatus = "Map status: ";
	string debugMessage = "";
	bool showDebug = true;

	// Map bar stuff
	vec2ui prevSize = vec2ui(-1, -1);
	string mapBarLabel, mapBarLabel2;
	//string pickedCoord = "";
	vec2i pickedCoord = vec2i(-1,-1);

	int menuMode = -1; // for which window is currently open
	const string[5] menuNames = ["New","Load","Save","Close",null];
	bool[5] menu = false;
	bool[5] menuEnabled = [true,true,true,true,false];
	RGBA[5] menuColors = [grayBG,grayBG,grayBG,transparent,transparent];

	bool newDialogOpen = false; // the New Map dialog
	int newDialogTerrainScroll = 0;
	Type newDialogType = Type.solid;
	float newDialogW = 40;
	float newDialogH = 40;
	float newDialogHeight = 8;

	int mapMode = 0;
	bool[] mapTabs = new bool[9];
	const string[] mapTabNames = ["Terrain", "Height", "dugg", "cror", "path", "erod", "slid","emrg","OL"];
	bool[] mapTabEnabled = new bool[9];
	RGBA[9] mapColors = orangeBG;

	// surf mode
	bool surfBlankPickMode = false;

	// high mode
	float highSliderValue = 8f;

	// terrain editing settings
	bool editMode = true;
	ubyte editBrush = 0; // Brushes -- 0:Square, 1:Circle, 2:Fill
	float editBrushSize = 1;
	ubyte editHeightMode = 0; // Height mode -- 0:Set, 1:Decrease, 2:Increase
	float editSetHeight = 8;
	///ubyte editSurf = 0; // 0-10 -- index into Map.terrainTypes /// 15 Aug 2015: removed LRR-style maps, replaced with Tile.type below

	/// Terrain mode stuff
	ubyte editTerrainMode = 0; // 0:type, 1:erodeSpeed, 2:hidden
	Type editType = Type.solid;
	float editErodeSpeed = 0;
	bool editHidden = true;
	
	// string versions of [0..5] for the UI
	const string[6] erodeStrings = ["0","1","2","3","4","5"];
	pure nothrow erodeColor(ubyte erodeSpeed)
	{
		if(erodeSpeed==0) return gray;
		else return RGBA(255,cast(ubyte)(255-(erodeSpeed-1)*(255/4)),0);
	}
	//float newSizeX = 40, newSizeY = 40;

	// biome bar
	bool showBiomeBar = true;
	bool chooseBiome = true;
	bool showAbout = false;

	// scroll stuff
	int scrollNull = 0; // for the ones that should never be scrolling
	int scrollUIBar = 0;
	int scrollSideBar = 0;
	int scrollBiome = 0;

	bool deletionConfirmation = false;

	bool locked = false; /// all-purpose lock: gray out the UI while pop-up windows and such things are focused
	Enabled enabled() @property
	{
		return locked?Enabled.no:Enabled.yes;
	}


	static void render()
	{
		// clear depth so UI is always above rendered map
		glClear(GL_DEPTH_BUFFER_BIT);
		//glEnable(GL_BLEND);
		//glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glDisable(GL_DEPTH_TEST);
		scrollNull = 0;
		imguiBeginFrame(m.x,m.y,mb,m.z);

		auto defaultDisabledColor = defaultColorScheme.button.textDisabled;

		//imguiDrawRect(width/2,height/2,199,199);
		if(showDebug)
		{
			imguiBeginScrollArea!false(debugMessage,200,0,width-400,32,&scrollNull);
			imguiEndScrollArea!false();
		}

		/// map
		imguiBeginScrollArea!(false)(null,0,height-200,200,200,&scrollNull,defaultColorScheme);
		//imguiDrawRect(width/2,height/2,199,199);
		//imguiDrawTexturedRect(width/2,height/2,188,188,Biome.selected.textures.get(5,uint.max));
		
		imguiEndScrollArea!(false)();

		if(Map.tiles !is null && Map.mapImages[mapMode] != 0)
		{
			imguiDrawTexturedRect(2,height-198,196,196,Map.mapImages[mapMode]);
			vec2 camPos = vec2(Map.cameraPos.x/Map.w,Map.cameraPos.y/Map.h); // 0..1, square
			if(Map.w > Map.h) camPos.y =  0.5f+(camPos.y-0.5f)*((cast(float)Map.h)/(cast(float)Map.w-1f))  ;//camPos.y * ((cast(float)Map.h)/(cast(float)Map.w));
			else if(Map.h > Map.w) camPos.x =  0.5f+(camPos.x-0.5f)*((cast(float)Map.w)/(cast(float)Map.h-1f))  ;//camPos.x * ((cast(float)Map.w)/(cast(float)Map.h));
			camPos *= 196;
			imguiDrawRoundedRect(camPos.x,height-camPos.y-4,4,4,1.5f,yellow);
			vec2 rotDir = vec2(std.math.cos((Map.cameraRot-0.25f)*2*std.math.PI),std.math.sin((Map.cameraRot-0.25f)*2*std.math.PI));
			rotDir *= 6f;
			rotDir += camPos;
			imguiDrawLine(camPos.x+2,height-camPos.y-2,rotDir.x+2,height-rotDir.y-2,1,yellow);
		}

		
		/// menu thing under map
		imguiBeginScrollArea(null,0,height-260,200,60,&scrollNull,defaultColorScheme); // 
		if(!Map.empty)
		{
			mapBarLabel = "Size: "~Map.mapSize.toString;
			//mapBarLabel2 = "Height at "~Map.cameraPos.toString~": "~text(Map.heightAtPos(Map.cameraPos));
			imguiLabel(mapBarLabel);
			if(mapBarLabel2 !is null) imguiLabel(mapBarLabel2);
		}
		imguiEndScrollArea();

		/// Load/Save/Import menus
		imguiBeginScrollArea!(false)(null,width-200,height-32,200,32,&scrollNull);
		menu[] = false;
		menuEnabled[2..4] = Map.tiles !is null;
		imguiButtons!(4)(menu[0..4],menuNames[0..4],menuEnabled[0..4]); // load and save
		if(menu[0]) // new
		{
			locked = true;
			newDialogOpen = true;
		}
		else if(menu[1]) // load
		{
			newDialogOpen = false;
			string response = dlgOpenFile();
			if(response !is null)
			{
				bool loaded = Map.load([response]);
				debug std.stdio.writeln("loaded: ",loaded);
			}
		}
		else if(menu[2]) // save
		{
			newDialogOpen = false;
			string response = dlgSaveFile();
			if(response !is null)
			{
				bool saved = Map.save(response);
				debug std.stdio.writeln("saved: ",saved);
			}
		}
		else if(menu[3]) // close
		{
			newDialogOpen = false;
			Map.close();
		}

		imguiEndScrollArea!(false)();

		/// new map dialog in the middle
		if(newDialogOpen)
		{
			imguiBeginScrollArea!(false)("Create New Map:",200,height-64-600,width-400,600,null);
			imguiSeparator(548); // blank background
			if(imguiButton!(0.7,0.845,true)("Cancel"))
			{
				newDialogOpen = false;
				locked = false;
			}
			if(imguiButton!(0.855,1,false)("Create"))
			{
				newDialogOpen = false;
				Map.create(cast(ubyte)newDialogW,cast(ubyte)newDialogH,newDialogType,cast(ubyte)newDialogHeight);
				locked = false;
			}
			imguiEndScrollArea!(false)();

			imguiBeginScrollArea!true("Terrain type",202,height-64-600+22,200,600-45-4,&newDialogTerrainScroll);
			uint glID = 0;
			foreach(Type t; EnumMembers!Type)
			{
				glID = Biome.selected.textures.get(Tile.simpleTex[t],0);
				//imguiButton!(0.25,1,true)(std.conv.text(t),(newDialogType==t)?Enabled.no:Enabled.yes);
				if(imguiButtonTextured!(0f,0.25f,false,true,true)(std.conv.text("          ",t),glID,(newDialogType==t)?Enabled.no:Enabled.yes,defaultColorScheme,Tile.colors.get(t,RGBA(1,0,0))))
				{
					newDialogType = t;
				}
			}
			imguiEndScrollArea!true();
			imguiBeginScrollArea!false(null,404,height-64-600+22,width-400-206,600-45-4,&scrollNull);
			imguiLabel("Map size:");
			imguiSlider("X - Width",&newDialogW,4,255,1);
			imguiSlider("Y - Height",&newDialogH,4,255,1);
			imguiLabel("Height:");
			imguiSlider("",&newDialogHeight,0,63,1);
			imguiEndScrollArea!false();
		}

		/// sidebar - map mode picker grid
		imguiBeginScrollArea!(false)(null,width-200,height-48-32,200,48,&scrollNull); // was 48
		buttonHeight = 32;
		mapTabEnabled[] = true;
		foreach(int i; 0..cast(int)mapTabEnabled.length)
		{
			if(mapMode == i || locked) mapTabEnabled[i] = false;
			mapColors[i] = (Map.tiles is null)?redBG:greenBG;
		}
		/// TODO: restore the rest as their functionalities are implemented
		imguiButtons!(2)(mapTabs[0..2],mapTabNames[0..2],mapTabEnabled[0..2]); ///    imguiButtonsBC       ,mapColors[0..2]
		///imguiButtonsBC!(3)(mapTabs[3..6],mapTabNames[3..6],mapTabEnabled[3..6],mapColors[3..6]);
		///imguiButtonsBC!(3)(mapTabs[6..9],mapTabNames[6..9],mapTabEnabled[6..9],mapColors[6..9]);
		foreach(int i; 0..cast(int)mapTabs.length)
		{
			if(mapTabs[i]) mapMode=i;
		}
		
		buttonHeight = 20;

		if(!locked) imguiLines!(2,true)(mapTabEnabled[0..2],0);

		imguiEndScrollArea!(false)();

		/// sidebar
		imguiBeginScrollArea(null,width-200,0,200,height-48-32,&scrollSideBar);

		imguiSeparatorLine();


		if(mapMode == 0) /// conditional: surf mode
		{
			imguiLabel!(true)(" Import:");
			if(imguiButton!(0.5f,1f)("LRR map...",enabled))
			{
				string response = dlgOpenFile();
				if(response !is null)
				{
					Map.load([response]);
				}
			}
			/+if(imguiButton!(0.5f,1f)("MCM map...",enabled))
			{
				
			}+/
			if(imguiButton!(0.5f,1f)("PS1 map...",enabled))
			{
				string response = dlgOpenFile();
				if(response !is null)
				{
					Map.loadPS1TerrainMap(response);
				}
			}


			/// bottom section of bar: editing tools for existing map
			defaultColorScheme.button.textDisabled = yellow;
			if(Map.tiles !is null)
			{
				imguiSeparatorLine();

				/// EDIT panel
				imguiCollapse("Edit terrain",null,&editMode);
				if(editMode)
				{
					// brush selector
					if(imguiButtonTextured!(0f,0.25f,true,true)("square",0,(editBrush==0)?Enabled.no:Enabled.yes))
					{
						editBrush = 0;
					}
					/++if(imguiButtonTextured!(0.25f,0.5f,true,true)("round",0,(editBrush==1)?Enabled.no:Enabled.yes))
					{
						editBrush = 1;
					}+/
					if(imguiButtonTextured!(0.5f,0.75f,false,true)("fill",0,(editBrush==2)?Enabled.no:Enabled.yes))
					{
						editBrush = 2;
					}
					imguiSlider("Brush size",&editBrushSize,1,6,1,(editBrush==2)?Enabled.no:Enabled.yes);
					uint glID = 0;

					// Hidden cavern buttons
					glID = Biome.selected.textures.get(70,0);
					if(imguiButtonTextured!(0.5f,0.74f,true,true)("Hide",glID,(editTerrainMode==2&&editHidden)?Enabled.no:Enabled.yes))
					{
						editTerrainMode = 2;
						editHidden = true;
					}
					glID = Biome.selected.textures.get(0,0);
					if(imguiButtonTextured!(0.75f,0.99f,true,true)("Show",glID,(editTerrainMode==2&& !editHidden)?Enabled.no:Enabled.yes))
					{
						editTerrainMode = 2;
						editHidden = false;
					}
					buttonHeight = 50;
					imguiLabel("Hidden cave:",(editTerrainMode==2)?yellowColorScheme:defaultColorScheme);
					buttonHeight = 20;

					// erosion button and slider
					ubyte uErodeSpeed = cast(ubyte)editErodeSpeed;
					glID = (uErodeSpeed==0)?(Biome.selected.textures.get(0,0)):(Biome.selected.textures.get(Tile.erosionTex[clamp(uErodeSpeed-2,0,3)],0));
					if(imguiButtonTextured!(0.5f,0.74f,true,true)("Set...",glID,(editTerrainMode==1)?Enabled.no:Enabled.yes,defaultColorScheme,(uErodeSpeed==0)?RGBA(128,128,128):RGBA(255,cast(ubyte)(255-(uErodeSpeed-1)*(255/4)),0)) )
					{
						editTerrainMode = 1;
					}
					buttonHeight = 50;
					imguiLabel("Lava erosion:",(editTerrainMode==1)?yellowColorScheme:defaultColorScheme);
					buttonHeight = 20;

					imguiSlider("Erode speed",&editErodeSpeed,0,5,1);

					imguiLabel("Terrain type:",(editTerrainMode==0)?yellowColorScheme:defaultColorScheme);
					// Terrain type buttons
					foreach(Type t; EnumMembers!Type)
					{
						glID = Biome.selected.textures.get(Tile.simpleTex[t],0);
						bool selected = editTerrainMode == 0 && editType == t;
						if(imguiButtonTextured!(0f,0.25f,false,true,true)(std.conv.text("          ",t),glID,(selected)?Enabled.no:Enabled.yes,defaultColorScheme,Tile.colors.get(t,RGBA(1,0,0))))
						{
							editTerrainMode = 0;
							editType = t;
						}
					}
				}

			}
		} /// end surf mode
		else if(mapMode == 1) /// conditional: heightmap mode
		{
			imguiLabel!(true)(" Import:");
			if(imguiButton!(0.5f,1f)("LRR map...",enabled))
			{
				string response = dlgOpenFile();
				if(response !is null)
				{
					Map.load([response]);
				}
			}
			if(imguiButton!(0.5f,1f)("Image...",enabled))
			{
				import derelict.devil.il;
				string response = dlgOpenFile();
				if(response !is null)
				{
					string imagePath = response;
					Map.MapComponent mc;



					uint imageID = ilGenImage();
					ilBindImage(imageID);
					ilLoadImage(imagePath.toStringz);
					uint w, h;
					scope(exit)
					{
						ilDeleteImage(imageID);
					}
					
					if(ilGetError() == IL_NO_ERROR && (w = ilGetInteger(IL_IMAGE_WIDTH)) > 0 && (h = ilGetInteger(IL_IMAGE_HEIGHT)) > 0)
					{
						bool mapExists = !(Map.tiles is null || Map.w == 0 || Map.h == 0);

						//// error if mismatched sizes.
						if(mapExists && ((Map.w!=w) || (Map.h!=h)) )
						{
							string mapmsg = "Image "~std.path.baseName(imagePath)~" ("~text(w)~","~text(h)~") doesn't have the correct size ("~text(Map.w)~","~text(Map.h)~").";
							debugLog(mapmsg);
							dlgMsg(mapmsg);
						}
						else
						{
							if(!mapExists) // null map; create new one
							{
								Map.create(cast(ubyte)w,cast(ubyte)h);
							}

							ubyte scale = 4;
							ubyte[] data = new ubyte[w*h];
							void* rawData = cast(void*)(new ubyte[w*h]).ptr;
							ilCopyPixels(0,0,0,w,h,1,IL_LUMINANCE,IL_UNSIGNED_BYTE,rawData);
							foreach(uint oy; 0..h)
							{
								uint y = h - oy - 1;
								foreach(uint x; 0..w)
								{
									data[x+oy*w] = cast(ubyte)((cast(ubyte*)rawData)[x+y*w]/scale);
								}
							}
							// map is valid; select hrcMR, save map, generate image
							mc = Map.MapComponent.create(cast(ubyte)w,cast(ubyte)h,data);

							foreach(x; 0..w) foreach(y; 0..h)
							{
								Map[x,y].height = mc[x,y];
							}

							savePathString(imagePath,pHighI);
							
							// Validate map and rebuild mesh if valid (Map.isMeshBuilt is updated to true or false)
							Map.buildMeshes();
							Map.sortMeshes();

							Map.updateHighMapImage();
						}
					}
					else
					{
						string mapmsg = "Image "~std.path.baseName(imagePath)~" could not be loaded."; // TODO: display devIL error
						dlgMsg(mapmsg);
					}
				}
			}
			/+if(imguiButton!(0.5f,1f)("MCM map...",enabled))
			{
				
			}+/
			
			if(Map.tiles !is null)
			{
				imguiSeparatorLine();
				imguiLabel!(true)("Export:");
				if(imguiButton!(0.5f,1f)("Image...",enabled))
				{
					string response = dlgSaveFile();
					if(response !is null)
					{
						Map.saveHighImage(response);
					}
				}
				imguiSeparator();
				imguiSeparatorLine();
				
				/// EDIT panel
				imguiCollapse("Edit heightmap",null,&editMode);
				if(editMode)
				{
					// brush selector
					if(imguiButtonTextured!(0f,0.25f,true,true)("square",0,(editBrush==0)?Enabled.no:Enabled.yes))
					{
						editBrush = 0;
					}
					/++if(imguiButtonTextured!(0.25f,0.5f,true,true)("round",0,(editBrush==1)?Enabled.no:Enabled.yes))
					{
						editBrush = 1;
					}+/
					if(imguiButtonTextured!(0.5f,0.75f,false,true)("fill",0,(editBrush==2)?Enabled.no:Enabled.yes))
					{
						editBrush = 2;
					}
					imguiSlider("Brush size",&editBrushSize,1,6,1,(editBrush==2)?Enabled.no:Enabled.yes);

					// height editing tools
					if(imguiButtonTextured!(0f,0.25f,true,true)("set",0,(editHeightMode==0)?Enabled.no:Enabled.yes))
					{
						editHeightMode = 0;
					}
					if(imguiButtonTextured!(0.25f,0.5f,true,true)("--",0,(editHeightMode==1)?Enabled.no:Enabled.yes))
					{
						editHeightMode = 1;
					}
					if(imguiButtonTextured!(0.5f,0.75f,false,true)("++",0,(editHeightMode==2)?Enabled.no:Enabled.yes))
					{
						editHeightMode = 2;
					}
					imguiSlider("Height",&editSetHeight,0f,63f,1f,(editHeightMode==0)?Enabled.yes:Enabled.no);

				}
			}
		}
		imguiEndScrollArea();
		defaultColorScheme.button.textDisabled = defaultDisabledColor;
		/// end sidebar

		/// Biome bar under map
		imguiBeginScrollArea(null,0,height-260-buttonHeight-12,200,12+buttonHeight,&scrollNull,defaultColorScheme);
		if(imguiButton!(0f,0.12f,true)(showBiomeBar?"-":"+"))
		{
			showBiomeBar = !showBiomeBar;
		}
		imguiLabel("       Settings");
		imguiEndScrollArea();

		if(showBiomeBar)
		{
			imguiBeginScrollArea(null,0,0,200,(height-260-12-buttonHeight),&scrollBiome,defaultColorScheme);
			imguiSeparatorLine();
			imguiCollapse("Biome:",Biome.selected.name,&chooseBiome);
			if(chooseBiome)
			{
				defaultColorScheme.button.textDisabled = yellow;
				if(imguiButton!(0.1f,1f)("[Map Colors]",(Biome.selected.defaultBiome)?Enabled.no:Enabled.yes))
				{
					Biome.selected = Biome.biomes["default"];
				}
				foreach(string bn, Biome b; Biome.biomes)
				{
					if(b.defaultBiome) continue;
					if(imguiButton!(0.1f,0.87f,true)(b.name,(Biome.selected is b)?Enabled.no:Enabled.yes))
					{
						Biome.selected = b;
					}
					if(imguiButton!(0.88f,1f)("x"))
					{
						import main : biomeRemovalQueue;
						Biome.selected = Biome.biomes["default"];
						biomeRemovalQueue ~= bn;
					}
				}
				if(imguiButton!(0.1f)(" + Load biome folder"))
				{
					import std.path, std.file;
					// TODO: allow naming the biome
					string response = dlgOpenFile("Open any image in a biome folder");
					if(response !is null)
					{
						string folderPath = buildNormalizedPath(std.string.strip(std.string.fromStringz(std.string.toStringz(response))));
						if(exists(folderPath))
						{
							if(!isDir(folderPath))
							{
								folderPath = dirName(folderPath);
							}
							debug std.stdio.writeln(folderPath);
							// function already handles errors by returning null:
							Biome nb = Biome.loadFromFile(null, folderPath);
						}
					}
				}
				defaultColorScheme.button.textDisabled = defaultDisabledColor;
			}
			else
			{

			}

			if(imguiCheck("Hide ceiling",&Map.hideCeiling))
			{
				//Map.buildMeshes(); // 6 Aug 2015: no longer necessary, the renderMap function and shaders handle ceiling automatically.
				//Map.sortMeshes();
			}

			imguiCheck("Mark hidden caves",&Map.markHidden);
			imguiCheck("Mark lava erosion",&Map.markErosion);

			/+++++++++if(imguiCheck("Cull terrain outside view",&Map.cull))
			{

			}+/

			imguiSeparatorLine();


			/// Other non-display settings
			imguiCheck("Auto-load map components",&Map.autoLoad);
			imguiCheck("Auto-overwrite on save",&Map.autoOverwrite);

			imguiSeparator();
			imguiCollapse("About",versionString,&showAbout);
			if(showAbout)
			{
				if(imguiButton("RRU topic"))
				{
					openURL("http://www.rockraidersunited.com/topic/6249-geotool/"w);
				}
				imguiSeparator();
				imguiLabel("  Program controls:");
				imguiLabel("Drag map(s) into window = load");
				imguiLabel("F = toggle FPS/info bar");
				imguiLabel("F5/P = screenshot");
				imguiLabel("Esc = exit");

				imguiSeparator();
				imguiLabel("  Camera controls:");
				imguiLabel("WASD/Click on map = move");
				imguiLabel("Home = reset/center view");
				imguiLabel("Arrow keys = rotate");
				imguiLabel("PGUP/PGDN/+/- = zoom");

				imguiSeparator();
				imguiSeparator();
				imguiLabel("  Libraries used:");
				imguiLabel("Derelict bindings");
				if(imguiButton!(0f,0.2f,true)(". . ."))
				{
					openURL("https://github.com/DerelictOrg"w);
				}
				if(imguiButton!(0.21f,1f)("Boost license"))
				{

					dlgMsg(boostLicense,"Derelict: Boost license");
				}

				imguiLabel("GLFW 3");
				if(imguiButton!(0f,0.2f,true)(". . ."))
				{
					openURL("http://www.glfw.org"w);
				}
				if(imguiButton!(0.21f,1f)("zlib/libpng license"))
				{
					dlgMsg(glfwLicense,"GLFW 3: zlib/libpng license");
				}

				imguiLabel("DevIL");
				if(imguiButton!(0f,0.2f,true)(". . ."))
				{
					openURL("http://openil.sourceforge.net"w);
				}
				if(imguiButton!(0.21f,1f)("LGPL v2.1"))
				{
					openURL("http://openil.sourceforge.net/license.php"w);
				}

				imguiLabel("Dimgui");
				if(imguiButton!(0f,0.2f,true)(". . ."))
				{
					openURL("https://github.com/d-gamedev-team/dimgui"w);
				}
				if(imguiButton!(0.21f,1f)("zlib/libpng license"))
				{
					dlgMsg(dimguiLicense,"Dimgui: zlib/libpng license");
				}

				imguiLabel("gl3n / glamour");
				if(imguiButton!(0f,0.2f,true)(". . ."))
				{
					openURL("https://github.com/Dav1dde/gl3n"w);
					openURL("https://github.com/Dav1dde/glamour"w);
				}
				if(imguiButton!(0.21f,1f)("MIT license"))
				{
					dlgMsg(mitLicense,"gl3n / glamour: MIT license");
				}


			}

			imguiEndScrollArea();
		}

		/// Mouse decoration in edit mode
		if(editMode && Map.tiles !is null && Map.validCoord(vec2ui(pickedCoord)))
		{
			uint glID = 0;
			if(mapMode==0) // Terrain
			{
				if(editTerrainMode==0) // type
				{
					glID = Biome.selected.textures.get(Tile.simpleTex[editType],0);
					if(glID==0) imguiDrawRect(m.x+10,m.y-30,32,32,Tile.colors.get(editType,gray));
					else imguiDrawTexturedRect(m.x+10,m.y-30,32,32,glID,white);
					glID = Biome.selected.textures.get(0,0);
					if(glID==0) imguiDrawRect(m.x+42,m.y-30,32,32,Tile.colors.get(Type.ground,gray));
					else imguiDrawTexturedRect(m.x+42,m.y-30,32,32,glID,white);
				}
				else if(editTerrainMode==1) // erode
				{
					ubyte uErodeSpeed = cast(ubyte)editErodeSpeed;
					glID = (uErodeSpeed==0)?(Biome.selected.textures.get(0,0)):(Biome.selected.textures.get(Tile.erosionTex[clamp(uErodeSpeed-2,0,3)],0));
					if(glID==0) imguiDrawRect(m.x+10,m.y-30,32,32,erodeColor(uErodeSpeed));
					else imguiDrawTexturedRect(m.x+10,m.y-30,32,32,glID,white);
					imguiBeginScrollArea!(false)(erodeStrings[clamp(uErodeSpeed,0,5)],m.x+42,m.y-26,32,24,&scrollNull);
					imguiEndScrollArea!(false)();
				}
				else if(editTerrainMode==2) // hidden caves
				{
					glID = Biome.selected.textures.get(editHidden?70:0,0);
					if(glID==0) imguiDrawRect(m.x+10,m.y-30,32,32,editHidden?red:gray);
					else imguiDrawTexturedRect(m.x+10,m.y-30,32,32,glID,white);
					imguiBeginScrollArea!(false)(editHidden?"Hide":"Show",m.x+42,m.y-26,58,24,&scrollNull);
					imguiEndScrollArea!(false)();
				}
			}
		}

		imguiEndFrame();
		imguiRender(width,height);
		//glDisable(GL_BLEND);
		glEnable(GL_DEPTH_TEST);
	}



	private void openURL(wstring url)
	{
		version(Windows) import core.sys.windows.windows;
		else import std.process : browse;
		//extern( Windows ) HINSTANCE ShellExecuteW(HWND, LPCWSTR, LPCWSTR, LPCWSTR, LPCWSTR, INT);

		const(wchar)[] open = "open"w;

		version(Windows) ShellExecuteW(null, open.ptr, url.ptr, null, null, SW_SHOW);
		else browse(cast(string)url);
	}

	private const string boostLicense = `Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license ( the "Software" ) to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:
The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.`;

	private const string glfwLicense = `Copyright © 2002-2006 Marcus Geelnard

Copyright © 2006-2011 Camilla Berglund

This software is provided ‘as-is’, without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.

Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:

The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.

Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.

This notice may not be removed or altered from any source distribution.`;

	private const string dimguiLicense = `Copyright (c) 2009-2010 Mikko Mononen memon@inside.org

This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.
Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:
1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.`;

	private const string mitLicense = `Copyright (c) 2012, David Herberth.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.`;

}