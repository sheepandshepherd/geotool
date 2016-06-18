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

import derelict.imgui.imgui;
import derelict.opengl3.gl3;
import derelict.glfw3.glfw3;
import util.linalg;

import std.string : toStringz;
import std.meta;
debug import std.stdio : writeln;

import main: window, width, height, m, mb, showLoadMenu, savePathString, saveINI, pSurfM, pHighI, pHighM, debugLog, versionString, iconHandle;
import main : filePath = path;
import map, biome;
import std.conv : text;
import dialog;
import util.texture;

import std.algorithm.comparison : clamp, min, max;

import std.typecons : EnumMembers, Tuple;
import tile;

static class UI
{
static:
	GLFWwindow* g_window;
	double g_Time = 0.0f;
	bool[3] g_MousePressed;
	float g_MouseWheel = 0.0f;
	uint g_FontTexture = 0;
	int g_ShaderHandle = 0, g_VertHandle = 0, g_FragHandle = 0;
	int g_AttribLocationTex = 0, g_AttribLocationProjMtx = 0;
	int g_AttribLocationPosition = 0, g_AttribLocationUV = 0, g_AttribLocationColor = 0;
	uint g_VboHandle, g_VaoHandle, g_ElementsHandle;
	ImGuiIO* io;


	/++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	UI variables
	++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++/
	size_t debugMessageMeshes, debugMessageSortedMeshes;
	float debugMessageFPS;
	bool showDebug = true;

	// Map bar stuff
	vec2ui prevSize = vec2ui(-1, -1);
	string mapBarLabel, mapBarLabel2;
	//string pickedCoord = "";
	vec2i pickedCoord = vec2i(-1,-1);

	int menuMode = -1; // for which window is currently open
	static immutable string[5] menuNames = ["New\0","Load\0","Save\0","Close\0",null];
	bool[5] menu = false;
	bool[5] menuEnabled = [true,true,true,true,false];

	bool newDialogOpen = false; // the New Map dialog
	int newDialogTerrainScroll = 0;
	Type newDialogType = Type.solid;
	int newDialogW = 40;
	int newDialogH = 40;
	int newDialogHeight = 8;

	int mapMode = 0;
	static immutable string[] mapTabNames = ["Terrain\0", "Height\0", "dugg\0", "cror\0", "path\0", "erod\0", "slid\0","emrg\0","OL\0"];

	// surf mode
	bool surfBlankPickMode = false;

	// high mode
	float highSliderValue = 8f;

	// terrain editing settings
	bool editMode = true;
	int editBrush = 0; // Brushes -- 0:Square, 1:Circle, 2:Fill
	int editBrushSize = 1;
	int editHeightMode = 0; // Height mode -- 0:Set, 1:Decrease, 2:Increase
	int editSetHeight = 8;

	/// Terrain mode stuff
	int editTerrainMode = 0; // 0:type, 1:erodeSpeed, 2:hidden
	Type editType = Type.solid;
	int editErodeSpeed = 0;
	bool editHidden = true;
	
	// string versions of [0..5] for the UI
	static immutable string[6] erodeStrings = ["0\0","1\0","2\0","3\0","4\0","5\0"];
	pure nothrow ImVec4 erodeColor(int erodeSpeed)
	{
		return (erodeSpeed==0)?ImVec4(0.5f,0.5f,0.5f,0.5f):ImVec4(1, 1f-((erodeSpeed-1f)/4f) ,0,0.9f);
	}

	// biome bar
	bool showBiomeBar = true;
	bool chooseBiome = true;
	bool showAbout = false;

	bool deletionConfirmation = false;

	bool locked = false; /// all-purpose lock: gray out the UI while pop-up windows and such things are focused

	/// draw a 2-column grid of terrain image buttons, storing the picked terrain ID in $(D pickedType)
	/// Returns: true if clicked
	bool terrainPicker(ref Type pickedType, bool active = true)
	{
		import util.texture;

		bool ret = false;

		foreach(ti, Type t; EnumMembers!Type)
		{
			assert(ti == cast(size_t)t);
			if(ti & 1) igSameLine(102);
			uint glID;
			/+if(Biome.selected && !Biome.selected.defaultBiome)+/ glID = Biome.selected.textures.get(Tile.simpleTex[t],0);

			if(glID == 0) glID = blankTexture;

			foreach(style; AliasSeq!(ImGuiCol_Button/++, ImGuiCol_ButtonActive, ImGuiCol_ButtonHovered+/)) igPushStyleColor(style,ImVec4(1,1,0,(active&&pickedType==t)?1:0 ));
			bool sa = igImageButton(cast(void*)glID, ImVec2(86,86), ImVec2(0, 1), ImVec2(1, 0), 1, Tile.colors.get(t,ImVec4(1,0,0,1)));

			igSameLine((ti&1)?102f:8f);
			igPushIdInt(cast(int)t);
			igSetItemAllowOverlap();
			/// BUG: igImageButton behaves *very* inconsistently when the image is transparent. An overlapping non-image button is necessary to ensure activation.
			bool sb = igInvisibleButton("terrainPickerButton",ImVec2(86,86));
			igPopId();
			if(igIsItemHovered()) igSetTooltip(typeNamesz[ti].ptr);
			igPopStyleColor(1);
			
			if( sa || sb )
			{
				ret = true;
				pickedType = t;
			}
		}

		return ret;
	}

	/// map
	void minimap()
	{
		igPushStyleVarVec(ImGuiStyleVar_WindowPadding, ImVec2(2,2));
		igSetNextWindowPos(ImVec2(0,0),ImGuiSetCond_Always);
		igSetNextWindowSize(ImVec2(200,220),ImGuiSetCond_Always);
		igBegin("Minimap",null,ImGuiWindowFlags_NoTitleBar|ImGuiWindowFlags_NoResize|ImGuiWindowFlags_NoMove|
			ImGuiWindowFlags_NoScrollbar|ImGuiWindowFlags_NoScrollWithMouse|ImGuiWindowFlags_NoCollapse|ImGuiWindowFlags_NoSavedSettings);
		
		if(Map.tiles !is null && Map.mapImages[mapMode] != 0)
		{
			igImage(cast(void*)Map.mapImages[mapMode],ImVec2(200-4,200-4),ImVec2(0,1),ImVec2(1,0));

			auto drawList = igGetWindowDrawList();

			vec2 camPos = vec2(Map.cameraPos.x/Map.w,Map.cameraPos.y/Map.h); // 0..1, square
			if(Map.w > Map.h) camPos.y =  0.5f+(camPos.y-0.5f)*((cast(float)Map.h)/(cast(float)Map.w-1f));
			else if(Map.h > Map.w) camPos.x =  0.5f+(camPos.x-0.5f)*((cast(float)Map.w)/(cast(float)Map.h-1f));
			camPos *= 196;
			ImDrawList_AddCircleFilled(drawList,ImVec2(camPos.x+2,camPos.y+2),2,uint.max);

			vec2 rotDir = vec2(std.math.cos((Map.cameraRot-0.25f)*2*std.math.PI),std.math.sin((Map.cameraRot-0.25f)*2*std.math.PI));
			rotDir *= 6f;
			rotDir += camPos;
			ImDrawList_AddLine(drawList,ImVec2(camPos.x+2,camPos.y+2),ImVec2(rotDir.x+2,rotDir.y+2),uint.max);

			igText("Map size: %d x %d",Map.w,Map.h);
		}

		igEnd();
		igPopStyleVar();
	}

	/// Biome bar under map at bottom left
	void biomeBar()
	{
		igSetNextWindowPos(ImVec2(0,220),ImGuiSetCond_Always);
		igSetNextWindowSize(ImVec2(200,height-220),ImGuiSetCond_Always);
		igBegin("Settings",null,ImGuiWindowFlags_NoResize|ImGuiWindowFlags_NoMove/+|ImGuiWindowFlags_NoSavedSettings+/);
		
		chooseBiome = igCollapsingHeader("Biome",null,true,true);
		if(chooseBiome)
		{
			if(igRadioButtonBool("[Map Colors]",Biome.selected.defaultBiome))
			{
				Biome.selected = Biome.biomes["default"];
			}
			foreach(string bn, Biome b; Biome.biomes)
			{
				if(b.defaultBiome) continue;
				if(igRadioButtonBool(b.namez,(Biome.selected is b)))
				{
					Biome.selected = b;
				}
				igSameLine(1f,165f);
				igPushIdPtr(cast(void*)b); /// add Biome's pointer to the hash to avoid colliding "x" buttons
				if(igButton("x"))
				{
					import main : biomeRemovalQueue;
					if(Biome.selected is b) Biome.selected = Biome.biomes["default"];
					biomeRemovalQueue ~= bn;
					debugLog("Removing biome <",bn,">");
				}
				igPopId();
			}
			if(igButton(" + Load biome folder "))
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
			igSeparator();
		}
		else
		{
			
		}
		igCheckbox("Hide ceiling",&Map.hideCeiling);
		igCheckbox("Mark hidden caves",&Map.markHidden);
		igCheckbox("Mark lava erosion",&Map.markErosion);
		igSeparator();
		
		/// Other non-display settings
		igCheckbox("Autoload map components",&Map.autoLoad);
		igCheckbox("Overwrite on save",&Map.autoOverwrite);
		
		igSeparator();

		showAbout = igCollapsingHeader("About",null,true,true);
		if(showAbout)
		{
			igIndent();
			igImage(cast(void*)iconHandle,ImVec2(128,128),ImVec2(0,1),ImVec2(1,0));
			igUnindent();
			
			if(igButton("RRU topic"))
			{
				openURL("http://www.rockraidersunited.com/topic/6249-geotool/"w);
			}
			igSameLine();
			igText(versionString.ptr);
			igSeparator();
			igText("  Program controls:");
			igText("Drag map(s) into window = load");
			igText("F = toggle FPS/info bar");
			igText("F5/P = screenshot");
			igText("Esc = exit");
			
			igSeparator();
			igText("  Camera controls:");
			igText("WASD/Click on map = move");
			igText("Home = reset/center view");
			igText("Arrow keys = rotate");
			igText("PGUP/PGDN/+/- = zoom");
			
			igSeparator();
			igText("  Libraries used:");
			
			if(igButton("Licenses..."))
			{
				openURL(".\\LICENSES - dependencies.txt"w);
			}
			
			
			if(igSelectable("Derelict bindings"))
			{
				openURL("https://github.com/DerelictOrg"w);
			}
			if(igSelectable("GLFW"))
			{
				openURL("http://www.glfw.org"w);
			}
			if(igSelectable("DevIL"))
			{
				openURL("http://openil.sourceforge.net"w);
			}
			if(igSelectable("cimgui"))
			{
				openURL("https://github.com/Extrawurst/cimgui"w);
				openURL("https://github.com/ocornut/imgui"w);
			}
			if(igSelectable("gl3n / glamour"))
			{
				openURL("https://github.com/Dav1dde/gl3n"w);
				openURL("https://github.com/Dav1dde/glamour"w);
			}
			
			
		}
		
		igEnd();
	}

	/// Load/Save/Import/Close at the top right
	void fileMenu()
	{
		igSetNextWindowPos(ImVec2(width-200,0),ImGuiSetCond_Always);
		igSetNextWindowSize(ImVec2(200,32),ImGuiSetCond_Always);
		igBegin("File menu buttons",null,ImGuiWindowFlags_NoTitleBar|ImGuiWindowFlags_NoResize|ImGuiWindowFlags_NoMove|
			ImGuiWindowFlags_NoScrollbar|ImGuiWindowFlags_NoScrollWithMouse|ImGuiWindowFlags_NoCollapse|ImGuiWindowFlags_NoSavedSettings);
		menu[] = false;
		menuEnabled[2..4] = Map.tiles !is null;
		//imguiButtons!(4)(menu[0..4],menuNames[0..4],menuEnabled[0..4]); // load and save
		foreach(i; 0..4)
		{
			if(i > 0) igSameLine();
			if(igButton(menuNames[i].ptr) && menuEnabled[i])
			{
				menu[i] = true;
			}
		}
		
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
		igEnd();
	}

	/// Pop-up for creating a new map
	void newDialog()
	{
		igSetNextWindowPos(ImVec2(200,30),ImGuiSetCond_Always);
		igSetNextWindowSize(ImVec2(width-400,710),ImGuiSetCond_Always);
		
		igBegin("Create New Map",null,ImGuiWindowFlags_NoResize|ImGuiWindowFlags_NoMove|    /+ImGuiWindowFlags_ShowBorders|+/
			ImGuiWindowFlags_NoCollapse|ImGuiWindowFlags_NoSavedSettings|ImGuiWindowFlags_NoScrollbar|ImGuiWindowFlags_NoScrollWithMouse);
		
		igBeginChild("New - Terrain type",ImVec2(200,675),true, ImGuiWindowFlags_NoScrollbar|ImGuiWindowFlags_NoScrollWithMouse);
		igText("Terrain type:");
		igSeparator();
		
		terrainPicker(newDialogType);
		
		igEndChild();
		
		igSameLine();
		igBeginGroup();
		igBeginChild("New - map settings",ImVec2(/++width-400-20+/0,645),false);
		igText("Map size:");
		igSliderInt("X - Width",&newDialogW,4,255);
		igSliderInt("Y - Height",&newDialogH,4,255);
		igSliderInt("Floor height",&newDialogHeight,0,63);
		igEndChild();
		
		igBeginChild("New - confirmations",ImVec2(width-400-200,25),false,ImGuiWindowFlags_NoTitleBar);
		
		/// right-alignment?
		if(igButton("Cancel"))
		{
			newDialogOpen = false;
			locked = false;
		}
		igSameLine();
		if(igButton("Create"))
		{
			newDialogOpen = false;
			Map.create(cast(ubyte)newDialogW,cast(ubyte)newDialogH,newDialogType,cast(ubyte)newDialogHeight);
			locked = false;
		}
		
		igEndChild();
		igEndGroup();
		
		igEnd();
	}

	void modePicker()
	{
		igSetNextWindowPos(ImVec2(width-200,32),ImGuiSetCond_Always);
		igSetNextWindowSize(ImVec2(200,48),ImGuiSetCond_Always);
		igBegin("Mode picker buttons",null,ImGuiWindowFlags_NoTitleBar|ImGuiWindowFlags_NoResize|ImGuiWindowFlags_NoMove|
			ImGuiWindowFlags_NoScrollbar|ImGuiWindowFlags_NoScrollWithMouse|ImGuiWindowFlags_NoCollapse|ImGuiWindowFlags_NoSavedSettings);

		/// TODO: restore the rest as their functionalities are implemented
		igColumns(2,"Mode picker columns",false);
		foreach(mi; 0..2)
		{
			if(mi != 0) igNextColumn();
			if(igSelectable(mapTabNames[mi].ptr, mi == mapMode,0,const ImVec2(0,32)))
			{
				mapMode = mi;
			}
			if(mi == mapMode)
			{
				
			}
		}
		igColumns();

		igEnd();
	}




	/// the massive right sidebar for all tools
	void sideBar()
	{
		igSetNextWindowPos(ImVec2(width-200,48+32),ImGuiSetCond_Always);
		igSetNextWindowSize(ImVec2(200,height-48-32),ImGuiSetCond_Always);
		igBegin("Sidebar",null,ImGuiWindowFlags_NoResize|ImGuiWindowFlags_NoMove);

		
		if(mapMode == 0) sideBarSurfTab();/// conditional: surf mode
		else if(mapMode == 1) sideBarHeightTab(); /// conditional: heightmap mode
		
		igEnd();
	}

	/// brush picker
	void brushPicker()
	{
		// brush selector
		igText("Brush:");
		igColumns(2,"Brush columns",false);
		igRadioButton("Square",&editBrush,0);
		igNextColumn();
		igRadioButton("Fill",&editBrush,2);
		igColumns();
		igSliderInt("Size",&editBrushSize,1,6);
	}

	/// surf tab
	void sideBarSurfTab()
	{
		igPushIdStr("SurfTab");
		igText("Import:");
		if(igButton("LRR map..."))
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
		if(igButton("PS1 map..."))
		{
			string response = dlgOpenFile();
			if(response !is null)
			{
				Map.loadPS1TerrainMap(response);
			}
		}
		
		
		/// bottom section of bar: editing tools for existing map
		if(Map.tiles !is null)
		{
			/// EDIT panel
			editMode = igCollapsingHeader("Edit terrain",null,true,true);
			if(editMode)
			{
				brushPicker();

				uint glID = 0;
				
				// Hidden cavern buttons
				igText("Hidden caverns");
				glID = Biome.selected.textures.get(70,blankTexture);
				//(editTerrainMode==2&&editHidden)
				igPushStyleColor(ImGuiCol_Button,ImVec4(1,1,0,(editTerrainMode==2&&editHidden)?1:0 ));
				bool setHideA = igImageButton(cast(void*)glID,ImVec2(50,50),ImVec2(0,1),ImVec2(1,0),1,ImVec4(0.5,0.0,0.0,0.9));
				igSameLine(8f);
				igSetItemAllowOverlap();
				bool setHideB = igInvisibleButton("setHideB",ImVec2(50,50));
				if( setHideA || setHideB )
				{
					editTerrainMode = 2;
					editHidden = true;
				}
				if(igIsItemHovered()) igSetTooltip("Hide");
				igPopStyleColor();

				glID = Biome.selected.textures.get(0,blankTexture);
				//(editTerrainMode==2&& !editHidden)
				igPushStyleColor(ImGuiCol_Button,ImVec4(1,1,0,(editTerrainMode==2&& !editHidden)?1:0 ));
				igSameLine(66f);
				bool setShowA = igImageButton(cast(void*)glID,ImVec2(50,50),ImVec2(0,1),ImVec2(1,0),1,ImVec4(0.0,0.5,0,0.9));
				igSameLine(66f);
				igSetItemAllowOverlap();
				bool setShowB = igInvisibleButton("setShowB",ImVec2(50,50));
				if( setShowA || setShowB )
				{
					editTerrainMode = 2;
					editHidden = false;
				}
				if(igIsItemHovered()) igSetTooltip("Show");
				igPopStyleColor();
				
				// erosion button and slider
				igText("Lava spread rate");

				glID = (editErodeSpeed==0)?(Biome.selected.textures.get(0,0)):(Biome.selected.textures.get(Tile.erosionTex[clamp(editErodeSpeed-2,0,3)],0));
				if(glID == 0) glID = blankTexture;
				igPushStyleColor(ImGuiCol_Button,ImVec4(1,1,0,(editTerrainMode==1)?1:0 ));
				ImVec4 erosionColor = erodeColor(editErodeSpeed);
				bool setErodeA = igImageButton(cast(void*)glID,ImVec2(50,50),ImVec2(0,1),ImVec2(1,0),1,erosionColor);
				igSameLine(8f);
				igSetItemAllowOverlap();
				bool setErodeB = igInvisibleButton("setErodeB",ImVec2(50,50));
				if( setErodeA || setErodeB )
				{
					editTerrainMode = 1;
				}
				if(igIsItemHovered()) igSetTooltip("Set erosion rate...");
				igPopStyleColor();
				
				igSliderInt("Erode speed",&editErodeSpeed,0,5);

				igText("Terrain type:");
				igSeparator();
				if(terrainPicker(editType, editTerrainMode==0)) editTerrainMode = 0;
			}
			
		}
		igPopId();
	} /// end surf mode

	void sideBarHeightTab()
	{
		igPushIdStr("HeightTab");
		igText("Import:");
		if(igButton("LRR map..."))
		{
			string response = dlgOpenFile();
			if(response !is null)
			{
				Map.load([response]);
			}
		}
		if(igButton("Image..."))
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
			igSeparator();
			igText("Export:");
			if(igButton("Image..."))
			{
				string response = dlgSaveFile();
				if(response !is null)
				{
					Map.saveHighImage(response);
				}
			}

			igSeparator();
			
			/// EDIT panel
			editMode = igCollapsingHeader("Edit heightmap",null,true,true);
			if(editMode)
			{
				// brush selector
				brushPicker();
				
				// height editing tools
				igText("Edit mode:");
				igColumns(3,"Height editing tools columns",false);
				igRadioButton("Set",&editHeightMode,0);
				igNextColumn();
				igRadioButton("--",&editHeightMode,1);
				igNextColumn();
				igRadioButton("++",&editHeightMode,2);

				/+if(imguiButtonTextured!(0f,0.25f,true,true)("set",0,(editHeightMode==0)?Enabled.no:Enabled.yes))
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
				}+/
				igColumns();
				igSliderInt("Height",&editSetHeight,0,63);
				
			}
		}
		igPopId();
	}

	void mouseDecoration()
	{
		igPushStyleVarVec(ImGuiStyleVar_WindowPadding, ImVec2(2,2));
		igPushStyleColor(ImGuiCol_PopupBg,ImVec4(0,0,0,0.333));
		uint glID = 0;
		if(mapMode==0) // Terrain
		{
			if(editTerrainMode==0) // type
			{
				igBeginTooltip();
				glID = Biome.selected.textures.get(Tile.simpleTex[editType],0);
				if(glID==0)
				{
					glID = blankTexture;
				}
				igImage(cast(void*)glID,ImVec2(32,32),ImVec2(0,1),ImVec2(1,0),ImVec4(1,1,1,1),Tile.colors.get(editType,ImVec4(1,0,0,1)));

				igSameLine();
				glID = Biome.selected.textures.get(0,0);
				if(glID==0)
				{
					glID = blankTexture;
				}
				igImage(cast(void*)glID,ImVec2(32,32),ImVec2(0,1),ImVec2(1,0),ImVec4(1,1,1,1),Tile.colors.get(Type.ground,ImVec4(1,0,0,1)));
				igEndTooltip();
			}
			else if(editTerrainMode==1) // erode
			{
				igBeginTooltip();
				glID = (editErodeSpeed==0)?(Biome.selected.textures.get(0,0)):(Biome.selected.textures.get(Tile.erosionTex[clamp(editErodeSpeed-2,0,3)],0));
				if(glID==0) glID = blankTexture;
				igImage(cast(void*)glID,ImVec2(32,32),ImVec2(0,1),ImVec2(1,0),ImVec4(1,1,1,1),erodeColor(editErodeSpeed));
				igSameLine();
				igText(erodeStrings[clamp(editErodeSpeed,0,5)].ptr);
				igEndTooltip();
			}
			else if(editTerrainMode==2) // hidden caves
			{
				igBeginTooltip();
				glID = Biome.selected.textures.get(editHidden?70:0,0);
				if(glID==0) glID = blankTexture;
				igImage(cast(void*)glID,ImVec2(32,32),ImVec2(0,1),ImVec2(1,0),ImVec4(1,1,1,1),ImVec4(editHidden?1:0, editHidden?0:1,0,1));
				igSameLine();
				igText(editHidden?"Hide":"Show");
				igEndTooltip();
			}
		}
		igPopStyleColor();
		igPopStyleVar();
	}

	static void render()
	{
		int w, h;
		int display_w, display_h;
		glfwGetWindowSize(g_window, &w, &h);
		glfwGetFramebufferSize(g_window, &display_w, &display_h);

		newFrame();


		/// FPS bar at bottom
		if(showDebug && Map.tiles !is null && Map.sortedMeshes !is null && Map.sortedMeshes.length > 0)
		{
			igSetNextWindowPos(ImVec2(200,height-32),ImGuiSetCond_Always);
			igSetNextWindowSize(ImVec2(width-400,32),ImGuiSetCond_Always);
			igBegin("FPS",null,ImGuiWindowFlags_NoTitleBar|ImGuiWindowFlags_NoResize|ImGuiWindowFlags_NoMove|
				ImGuiWindowFlags_NoScrollbar|ImGuiWindowFlags_NoScrollWithMouse|ImGuiWindowFlags_NoCollapse|ImGuiWindowFlags_NoSavedSettings|ImGuiWindowFlags_NoInputs);
			igText("[F] Rendering %d meshes sorted into %d material groups. %.1f FPS", debugMessageMeshes, debugMessageSortedMeshes, debugMessageFPS);
			igEnd();
		}

		minimap();

		biomeBar();

		fileMenu();

		/// new map dialog in the middle +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		if(newDialogOpen)
		{
			newDialog();
		}
		/// Mode picker +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		modePicker();

		sideBar();


		/// Mouse decoration in edit mode
		if(editMode && Map.tiles !is null && Map.validCoord(vec2ui(pickedCoord)))
		{
			mouseDecoration();
		}


		igRender();
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






	extern(C) nothrow void renderDrawLists(ImDrawData* data)
	{
		// Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled
		glEnable(GL_BLEND);
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glDisable(GL_CULL_FACE);
		glDisable(GL_DEPTH_TEST);
		glEnable(GL_SCISSOR_TEST);
		glActiveTexture(GL_TEXTURE0);
		
		auto io = igGetIO();
		// Setup orthographic projection matrix
		const float width = io.DisplaySize.x;
		const float height = io.DisplaySize.y;
		const float[4][4] ortho_projection =
		[
			[ 2.0f/width,	0.0f,			0.0f,		0.0f ],
			[ 0.0f,			2.0f/-height,	0.0f,		0.0f ],
			[ 0.0f,			0.0f,			-1.0f,		0.0f ],
			[ -1.0f,		1.0f,			0.0f,		1.0f ],
		];
		glUseProgram(g_ShaderHandle);
		glUniform1i(g_AttribLocationTex, 0);
		glUniformMatrix4fv(g_AttribLocationProjMtx, 1, GL_FALSE, &ortho_projection[0][0]);
		
		glBindVertexArray(g_VaoHandle);
		glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ElementsHandle);
		
		foreach (n; 0..data.CmdListsCount)
		{
			ImDrawList* cmd_list = data.CmdLists[n];
			ImDrawIdx* idx_buffer_offset;
			
			auto countVertices = ImDrawList_GetVertexBufferSize(cmd_list);
			auto countIndices = ImDrawList_GetIndexBufferSize(cmd_list);
			
			glBufferData(GL_ARRAY_BUFFER, countVertices * ImDrawVert.sizeof, cast(GLvoid*)ImDrawList_GetVertexPtr(cmd_list,0), GL_STREAM_DRAW);
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, countIndices * ImDrawIdx.sizeof, cast(GLvoid*)ImDrawList_GetIndexPtr(cmd_list,0), GL_STREAM_DRAW);
			
			auto cmdCnt = ImDrawList_GetCmdSize(cmd_list);
			
			foreach(i; 0..cmdCnt)
			{
				auto pcmd = ImDrawList_GetCmdPtr(cmd_list, i);
				
				if (pcmd.UserCallback)
				{
					pcmd.UserCallback(cmd_list, pcmd);
				}
				else
				{
					glBindTexture(GL_TEXTURE_2D, cast(GLuint)pcmd.TextureId);
					glScissor(cast(int)pcmd.ClipRect.x, cast(int)(height - pcmd.ClipRect.w), cast(int)(pcmd.ClipRect.z - pcmd.ClipRect.x), cast(int)(pcmd.ClipRect.w - pcmd.ClipRect.y));
					glDrawElements(GL_TRIANGLES, pcmd.ElemCount, GL_UNSIGNED_SHORT, idx_buffer_offset);
				}
				
				idx_buffer_offset += pcmd.ElemCount;
			}
		}
		
		// Restore modified state
		glBindVertexArray(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
		glDisable(GL_SCISSOR_TEST);
	}
	
	void initialize(GLFWwindow* window, bool install_callbacks)
	{
		g_window = window;
		
		ImGuiIO* io = igGetIO(); 
		io.KeyMap[ImGuiKey_Tab] = GLFW_KEY_TAB;				 // Keyboard mapping. ImGui will use those indices to peek into the io.KeyDown[] array.
		io.KeyMap[ImGuiKey_LeftArrow] = GLFW_KEY_LEFT;
		io.KeyMap[ImGuiKey_RightArrow] = GLFW_KEY_RIGHT;
		io.KeyMap[ImGuiKey_UpArrow] = GLFW_KEY_UP;
		io.KeyMap[ImGuiKey_DownArrow] = GLFW_KEY_DOWN;
		io.KeyMap[ImGuiKey_Home] = GLFW_KEY_HOME;
		io.KeyMap[ImGuiKey_End] = GLFW_KEY_END;
		io.KeyMap[ImGuiKey_Delete] = GLFW_KEY_DELETE;
		io.KeyMap[ImGuiKey_Backspace] = GLFW_KEY_BACKSPACE;
		io.KeyMap[ImGuiKey_Enter] = GLFW_KEY_ENTER;
		io.KeyMap[ImGuiKey_Escape] = GLFW_KEY_ESCAPE;
		io.KeyMap[ImGuiKey_A] = GLFW_KEY_A;
		io.KeyMap[ImGuiKey_C] = GLFW_KEY_C;
		io.KeyMap[ImGuiKey_V] = GLFW_KEY_V;
		io.KeyMap[ImGuiKey_X] = GLFW_KEY_X;
		io.KeyMap[ImGuiKey_Y] = GLFW_KEY_Y;
		io.KeyMap[ImGuiKey_Z] = GLFW_KEY_Z;
		
		io.RenderDrawListsFn = &renderDrawLists;
		io.SetClipboardTextFn = &setClipboardText;
		io.GetClipboardTextFn = &getClipboardText;
		/+#ifdef _MSC_VER
		io.ImeWindowHandle = glfwGetWin32Window(g_Window);
	#endif+/
		
		if (install_callbacks)
		{
			glfwSetMouseButtonCallback(window, &mouseButtonCallback);
			glfwSetScrollCallback(window, &scrollCallback);
			glfwSetKeyCallback(window, &keyCallback);
			glfwSetCharCallback(window, &charCallback);
		}
	}
	
	void createDeviceObjects()
	{
		const GLchar *vertex_shader =
			"#version 330\n"
				"uniform mat4 ProjMtx;\n"
				"in vec2 Position;\n"
				"in vec2 UV;\n"
				"in vec4 Color;\n"
				"out vec2 Frag_UV;\n"
				"out vec4 Frag_Color;\n"
				"void main()\n"
				"{\n"
				"	Frag_UV = UV;\n"
				"	Frag_Color = Color;\n"
				"	gl_Position = ProjMtx * vec4(Position.xy,0,1);\n"
				"}\n";
		
		const GLchar* fragment_shader =
			"#version 330\n"
				"uniform sampler2D Texture;\n"
				"in vec2 Frag_UV;\n"
				"in vec4 Frag_Color;\n"
				"out vec4 Out_Color;\n"
				"void main()\n"
				"{\n"
				"	Out_Color = Frag_Color * texture( Texture, Frag_UV.st);\n"
				"}\n";
		
		g_ShaderHandle = glCreateProgram();
		g_VertHandle = glCreateShader(GL_VERTEX_SHADER);
		g_FragHandle = glCreateShader(GL_FRAGMENT_SHADER);
		glShaderSource(g_VertHandle, 1, &vertex_shader, null);
		glShaderSource(g_FragHandle, 1, &fragment_shader, null);
		glCompileShader(g_VertHandle);
		glCompileShader(g_FragHandle);
		glAttachShader(g_ShaderHandle, g_VertHandle);
		glAttachShader(g_ShaderHandle, g_FragHandle);
		glLinkProgram(g_ShaderHandle);
		
		g_AttribLocationTex = glGetUniformLocation(g_ShaderHandle, "Texture");
		g_AttribLocationProjMtx = glGetUniformLocation(g_ShaderHandle, "ProjMtx");
		g_AttribLocationPosition = glGetAttribLocation(g_ShaderHandle, "Position");
		g_AttribLocationUV = glGetAttribLocation(g_ShaderHandle, "UV");
		g_AttribLocationColor = glGetAttribLocation(g_ShaderHandle, "Color");
		
		glGenBuffers(1, &g_VboHandle);
		glGenBuffers(1, &g_ElementsHandle);
		
		glGenVertexArrays(1, &g_VaoHandle);
		glBindVertexArray(g_VaoHandle);
		glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
		glEnableVertexAttribArray(g_AttribLocationPosition);
		glEnableVertexAttribArray(g_AttribLocationUV);
		glEnableVertexAttribArray(g_AttribLocationColor);
		
		glVertexAttribPointer(g_AttribLocationPosition, 2, GL_FLOAT, GL_FALSE, ImDrawVert.sizeof, cast(void*)0);
		glVertexAttribPointer(g_AttribLocationUV, 2, GL_FLOAT, GL_FALSE, ImDrawVert.sizeof, cast(void*)ImDrawVert.uv.offsetof);
		glVertexAttribPointer(g_AttribLocationColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, ImDrawVert.sizeof, cast(void*)ImDrawVert.col.offsetof);
		
		glBindVertexArray(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);

		createFontsTexture();
	}
	
	extern(C) nothrow const(char)* getClipboardText()
	{
		return glfwGetClipboardString(g_window);
	}
	
	extern(C) nothrow void setClipboardText(const(char)* text)
	{
		glfwSetClipboardString(g_window, text);
	}
	
	extern(C) nothrow void mouseButtonCallback(GLFWwindow*, int button, int action, int /*mods*/)
	{
		if (action == GLFW_PRESS && button >= 0 && button < 3)
			g_MousePressed[button] = true;
	}
	
	extern(C) nothrow void scrollCallback(GLFWwindow*, double /*xoffset*/, double yoffset)
	{
		g_MouseWheel += cast(float)yoffset; // Use fractional mouse wheel, 1.0 unit 5 lines.
	}
	
	extern(C) nothrow void keyCallback(GLFWwindow*, int key, int, int action, int mods)
	{
		auto io = igGetIO();
		if (action == GLFW_PRESS)
			io.KeysDown[key] = true;
		if (action == GLFW_RELEASE)
			io.KeysDown[key] = false;
		io.KeyCtrl = (mods & GLFW_MOD_CONTROL) != 0;
		io.KeyShift = (mods & GLFW_MOD_SHIFT) != 0;
		io.KeyAlt = (mods & GLFW_MOD_ALT) != 0;
	}
	
	extern(C) nothrow void charCallback(GLFWwindow*, uint c)
	{
		if (c > 0 && c < 0x10000)
		{
			ImGuiIO_AddInputCharacter(cast(ushort)c);
		}
	}
	
	void createFontsTexture()
	{
		ImGuiIO* io = igGetIO();
		
		ubyte* pixels;
		int width, height;
		ImFontAtlas_GetTexDataAsRGBA32(io.Fonts,&pixels,&width,&height,null);
		
		glGenTextures(1, &g_FontTexture);
		glBindTexture(GL_TEXTURE_2D, g_FontTexture);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
		
		// Store our identifier
		ImFontAtlas_SetTexID(io.Fonts, cast(void*)g_FontTexture);
	}
	
	void shutdown()
	{
		if (g_VaoHandle) glDeleteVertexArrays(1, &g_VaoHandle);
		if (g_VboHandle) glDeleteBuffers(1, &g_VboHandle);
		if (g_ElementsHandle) glDeleteBuffers(1, &g_ElementsHandle);
		g_VaoHandle = 0;
		g_VboHandle = 0;
		g_ElementsHandle = 0;
		
		glDetachShader(g_ShaderHandle, g_VertHandle);
		glDeleteShader(g_VertHandle);
		g_VertHandle = 0;
		
		glDetachShader(g_ShaderHandle, g_FragHandle);
		glDeleteShader(g_FragHandle);
		g_FragHandle = 0;
		
		glDeleteProgram(g_ShaderHandle);
		g_ShaderHandle = 0;
		
		if (g_FontTexture)
		{
			glDeleteTextures(1, &g_FontTexture);
			ImFontAtlas_SetTexID(igGetIO().Fonts, cast(void*)0);
			g_FontTexture = 0;
		}
		
		igShutdown();
	}
	
	void newFrame()
	{
		if (!g_FontTexture)
			createDeviceObjects();

		auto io = igGetIO();
		
		// Setup display size (every frame to accommodate for window resizing)
		int w, h;
		int display_w, display_h;
		glfwGetWindowSize(g_window, &w, &h);
		glfwGetFramebufferSize(g_window, &display_w, &display_h);
		io.DisplaySize = ImVec2(cast(float)display_w, cast(float)display_h);
		
		// Setup time step
		double current_time =  glfwGetTime();
		io.DeltaTime = g_Time > 0.0 ? cast(float)(current_time - g_Time) : cast(float)(1.0f/60.0f);
		g_Time = current_time;
		
		// Setup inputs
		// (we already got mouse wheel, keyboard keys & characters from glfw callbacks polled in glfwPollEvents())
		if (glfwGetWindowAttrib(g_window, GLFW_FOCUSED))
		{
			double mouse_x, mouse_y;
			glfwGetCursorPos(g_window, &mouse_x, &mouse_y);
			mouse_x *= cast(float)display_w / w;						// Convert mouse coordinates to pixels
			mouse_y *= cast(float)display_h / h;
			io.MousePos = ImVec2(mouse_x, mouse_y);   // Mouse position, in pixels (set to -1,-1 if no mouse / on another screen, etc.)
		}
		else
		{
			io.MousePos = ImVec2(-1,-1);
		}
		
		for (int i = 0; i < 3; i++)
		{
			io.MouseDown[i] = g_MousePressed[i] || glfwGetMouseButton(g_window, i) != 0;	// If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
			g_MousePressed[i] = false;
		}
		
		io.MouseWheel = g_MouseWheel;
		g_MouseWheel = 0.0f;

	// Hide/show hardware mouse cursor
		glfwSetInputMode(g_window, GLFW_CURSOR, io.MouseDrawCursor ? GLFW_CURSOR_HIDDEN : GLFW_CURSOR_NORMAL);

	igNewFrame();
	}
}