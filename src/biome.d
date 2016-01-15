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

module biome;
import std.path, std.file;
import derelict.devil.il;
import util.linalg;

import derelict.opengl3.gl3;

class Biome
{
	// Currently selected biome
	static Biome selected;
	// List of loaded biomes
	static Biome[string] biomes;
	static uint[78] surfType = [5,0,4,3,2,1,5,0,0,0,5,5,5,5,0,0,5,0,0,0,0xa,0,4,3,2,1,5,0,0,0,5,0,4,3,2,1,5,0,0,0,8,0,0,0,0,9,6,0,0,0,0,0,4,3,2,1,0,0,0,0,5,5,5,5,5,5,5,0xb,0,0,255,5,5,5,5,5,5,5];
	/// [wall type][surf] - the texture number matching the actual files and used in the TerrainMesh class
	/// wall types: 0=straight/(ground/ceiling), 1=corner, 2=innerCorner, 3=enforced (split is ALWAYS 77)
	static uint[4][uint] wallTex;
	static uint[uint] simpleGroundTex; // cannot account for path and dugg maps yet
	static vec3ub[uint] defaultColors;// = [ 0:v3ub(32,32,32), 1:v3ub(82,0,140), 2:v3ub(115,28,173), 3:v3ub(148,60,206), 4:v3ub(173,89,239), 5:v3ub(41,0,74), 6:v3ub(255,89,0), 8:v3ub(156,65,8), 10:v3ub(184,255,0), 11:v3ub(255,255,0) ]; // default colors: will be used as blank texture if not loaded
	static vec3ub[uint] colors;// = defaultColors.dup;
	static this()
	{
		defaultColors = [ 0:v3ub(32,32,32), 1:v3ub(82,0,140), 2:v3ub(115,28,173), 3:v3ub(148,60,206), 4:v3ub(173,89,239), 9:v3ub(0,44,181), 5:v3ub(41,0,74), 6:v3ub(255,89,0), 8:v3ub(156,65,8), 10:v3ub(184,255,0), 11:v3ub(255,255,0), ]; // default colors: will be used as blank texture if not loaded
		colors = defaultColors.dup;
		selected = new Biome();

		// build the wallTex array: used by the mesh update function to assign texture to TerrainMesh
		wallTex[1] = [5,55,35,25];
		wallTex[2] = [4,54,34,24];
		wallTex[3] = [3,53,33,23];
		wallTex[4] = [2,52,32,22];
		wallTex[8] = [40,70,70,70];
		wallTex[10] = [20,70,70,70];
		wallTex[11] = [67,70,70,70];

		simpleGroundTex[5] = 0;
		simpleGroundTex[9] = 45;
		simpleGroundTex[6] = 46;
	}

	bool defaultBiome = false; // to make checking simpler than string comparison on name
	string name, path;
	// OpenGL index of each texture for this biome
	//   for unassigned textures, USE GL ID 0: the render function will shade them with surf color instead of texture
	// GL_ID[tex_ID] (tex_ID is not the surf type, but the number on the texture file -- corners/etc accounted for)
	uint[uint] textures;
	string[uint] paths; // save the filePaths for later; TODO: allow creation of LEGO.CFG snippet from a loaded biome

	/// Load a biome from a folder. Individual filenames are not needed, they're determined automatically.
	static public Biome loadFromFile(string _name, string folderPath)
	{
		uint[uint] _textures;
		string[uint] _paths;

		// 
		if( !isValidPath(folderPath) || !exists(folderPath) || !isDir(folderPath)) return null;

		uint imageID;

		foreach(DirEntry d; dirEntries(folderPath,SpanMode.shallow))
		{
			// skip if file doesn't exist or is hidden (Windows attribute for hidden is 0b10)
			if(!exists(d.name) || (getAttributes(d.name) & 0b10)) continue;
			uint num = fileNumber(d.name);
			if(num < 78)
			{
				// clear il error stack
				ilProcessErrors();

				// attempt to read the texture
				ilBindImage(imageID);
				uint imageGL;
				if(ilLoadImage(std.string.toStringz(d.name)))
				{
					scope(exit)
					{
						ilDeleteImage(imageID);
					}
					// loaded image, move to GL
					glGenTextures(1,&imageGL);
					glBindTexture(GL_TEXTURE_2D, imageGL);
					vec2i size = vec2i(ilGetInteger(IL_IMAGE_WIDTH),ilGetInteger(IL_IMAGE_HEIGHT));
					void* data = (new ubyte[size.x*size.y*3]).ptr;
					ilCopyPixels(0,0,0,size.x,size.y,1,IL_RGB,IL_UNSIGNED_BYTE,data);
					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
					glTexImage2D(GL_TEXTURE_2D,0,GL_RGB8,size.x,size.y,0,GL_RGB,GL_UNSIGNED_BYTE,data);
				}

				if(!ilProcessErrors(baseName(d.name)))
				{
					_textures[num] = imageGL;
					_paths[num] = d.name;

				}

			}

		}



		if(_name is null) _name = baseName(folderPath);
		return new Biome(_name,_textures,_paths,folderPath);
	}
	static bool ilProcessErrors(string tag = null)
	{
		ILenum error;
		bool errors = false;
		//char[] errors;
		while((error = ilGetError()) != IL_NO_ERROR)
		{
			//errors ~= derelict.devil.ilu.iluErrorString(error);
			errors = true;
			if(tag !is null) std.stdio.write("[",tag,"] ");
			std.stdio.writeln("IL Error ",error,": ",std.conv.text(derelict.devil.ilu.iluErrorString(error)));
		}
		return errors;
	}


	private this(string _name, uint[uint] _textures, string[uint] _paths, string folderPath = null)
	{
		biomes[_name] = this;
		name = _name;
		textures = _textures;
		paths = _paths;
		path = folderPath;
	}

	/// create the default biome, with no textures (will draw only surf colors)
	private this()
	{
		biomes["default"] = this;
		defaultBiome = true;
		name = "default";
	}

	/// release assets; use instead of gc-based destructor (gc is non-deterministic)
	public void unload()
	{
		//foreach(uint k, uint v; textures)
		glDeleteTextures(cast(int)textures.values.length,textures.values.ptr);
	}


	/// Determine from the filename which surf number it is; this accounts for varying biome names.
	static uint fileNumber(string filePath)
	{
		import std.path, std.ascii;
		string nameOnly = stripExtension(baseName(filePath));
		uint from = 0, to = 0;
		bool numberStarted = false;
		// search backwards for the digits (presumably they'll be at the end)
		foreach_reverse(i; 0..cast(uint)nameOnly.length)
		{
			if(nameOnly[i].isDigit)
			{
				from = i;
				if(!numberStarted)
				{
					numberStarted = true;
					to = i+1;
				}
			}
			else 
			{
				if(numberStarted)
					break;
				else
					continue;
			}
		}

		if(to != 0)
		{
			return std.conv.to!(uint)(nameOnly[from..to]);
		}
		else
			return uint.max; // if it returns uint.max, there was no number in the filename at all, so ignore it

	}
}

