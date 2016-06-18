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

module tile;

import std.algorithm.iteration, std.range, std.array;
import std.conv;
import std.meta;
import std.typecons : EnumMembers;
private import derelict.imgui.imgui : ImVec4;

/// surface and terrain type, all mutually exclusive
enum Type : ubyte
{
	ground,
	erosion,
	path,
	rubble,
	water,
	lava,
	dirt,
	loose,
	hard,
	solid,
	ore,
	crystal,
	recharge,
	slug,
	//soil,
}

private template ExtractTypeName(alias Type type)
{
	private enum ExtractTypeName = type.stringof;
}

//pragma(msg, TypeNameT!(Type.ground));

private enum TypeNames = staticMap!(ExtractTypeName, EnumMembers!Type);

static immutable string[] typeNames = iota(0,EnumMembers!Type.length).map!(  ti=>( [TypeNames][ti] )  ).array;
static immutable string[] typeNamesz = iota(0,EnumMembers!Type.length).map!(  ti=>( [TypeNames][ti]~'\0' )  ).array;

// LRR's map component file types
enum FileType : ubyte
{
	surf,
	path,
	dugg,
	high,
	erod,
	tuto,
	emrg,
	fall,
	cror
}

struct Tile
{
	static const uint[4] erosionTex = [6,16,26,36];
	static uint[4][Type] wallTex;
	static uint[Type] groundTex;
	static uint[Type] simpleTex; // for editor UI
	static const roofTex = 70;
	static ImVec4[Type] defaultColors;// = [ 0:RGBA(32,32,32), 1:RGBA(82,0,140), 2:RGBA(115,28,173), 3:RGBA(148,60,206), 4:RGBA(173,89,239), 5:RGBA(41,0,74), 6:RGBA(255,89,0), 8:RGBA(156,65,8), 10:RGBA(184,255,0), 11:RGBA(255,255,0) ]; // default colors: will be used as blank texture if not loaded
	static ImVec4[Type] colors;// = defaultColors.dup;
	// values for conversion
	//static immutable ubyte[ubyte] crystalValues;
	//static immutable ubyte[ubyte] oreValues;
	static const Type[0xb+1] surfValues = [Type.ground,Type.solid,Type.hard,Type.loose,Type.dirt,Type.ground,Type.lava,Type.ground,Type.ore,Type.water,Type.crystal,Type.recharge];

	/+static this()
	{
		// build the wallTex array: used by the mesh update function to assign texture to TerrainMesh
		wallTex[Type.solid] = [5,55,35,25];
		wallTex[Type.hard] = [4,54,34,24];
		wallTex[Type.loose] = [3,53,33,23];
		wallTex[Type.dirt] = [2,52,32,22];
		wallTex[Type.ore] = [40,70,70,70];
		wallTex[Type.crystal] = [20,70,70,70];
		wallTex[Type.recharge] = [67,70,70,70];

		groundTex[Type.ground] = 0;
		groundTex[Type.slug] = 30;
		groundTex[Type.rubble] = 10;
		groundTex[Type.path] = 76;
		groundTex[Type.water] = 45;
		groundTex[Type.lava] = 46;

		simpleTex = groundTex.dup;
		simpleTex[Type.solid] = 5;
		simpleTex[Type.hard] = 4;
		simpleTex[Type.loose] = 3;
		simpleTex[Type.dirt] = 2;
		simpleTex[Type.ore] = 40;
		simpleTex[Type.crystal] = 20;
		simpleTex[Type.recharge] = 67;
		simpleTex[Type.erosion] = 6;
		simpleTex[Type.soil] = 0; // doesn't exist in PC version; not sure if I'll leave it in or not

		with(Type) defaultColors = [ solid:RGBA(82,0,140), hard:RGBA(115,28,173), loose:RGBA(148,60,206), dirt:RGBA(173,89,239), soil:RGBA(190,98,255), water:RGBA(0,44,181), ground:RGBA(41,0,74), path:RGBA(160,160,240), rubble:RGBA(41,41,41), lava:RGBA(255,89,0), erosion:RGBA(148,45,37), slug:RGBA(148,128,37), ore:RGBA(156,65,8), crystal:RGBA(184,255,0), recharge:RGBA(255,255,0), ]; // default colors: will be used as blank texture if not loaded
		colors = defaultColors.dup;

		/+crystalValues = [1:1, 3:1, 5:3, 7:3, 
			9:5, 0xb:5, 0xd:11, 0x13:11, 0x11:25, 0x17:25 ];
		oreValues = [ 2:1, 4:1, 6:3, 8:3, 0xa:5,
			0xc:5, 0x10:5, 0xe:11, 0x14:11, 0x12:25, 0x18:25 ];+/
	}+/
	static pure nothrow bool isGround(Type t)
	{
		switch(t)
		{
			with(Type)
			{
				case ground, path, rubble, slug, erosion, water, lava:
				return true;
				default:
				return false;
			}
		}
	}

	// convert to LRR's format. template version; yay for constness, I hope the switch gets compiled out
	pure nothrow ubyte toLRR(FileType f)()
	{
		with(FileType) final switch(f)
		{
			case surf:
				with(Type) switch(type)
				{
					case solid:
						return 1;
					case hard:
						return 2;
					case loose:
						return 3;
					case dirt:
						return 4;
					/+case soil:
						return 5;+/ // lol
					case lava:
						return 6;
					case water:
						return 9;
					case crystal:
						return 0xa;
					case ore:
						return 8;
					case recharge:
						return 0xb;
					default:
						return 0;
				}
			case path:
				if(type == Type.path) return 2;
				else if(type == Type.rubble) return 1;
				else return 0;
			case high:
				return height;
			case dugg:
				if(type == Type.slug)
				{
					if(hidden) return 4;
					else return 3;
				}
				else if(isGround(type))
				{
					if(hidden) return 2;
					else return 1;
				}
				else return 0;
			case erod:
				ubyte ret = cast(ubyte)(2*erodeSpeed);
				if(type != Type.erosion && ret != 0) ret -= 1;
				return ret;
			case tuto:
				return tutorial;
			case emrg:
				return emerge;
			case fall:
				return landslide;
			case cror:
				return cryore;
		}
	}
	
	/+union
	{
		struct
		{
		align(1):+/
			Type type;			// combined dugg, surf, path, and erod: to simplify, since they're mutually exclusive in most cases.
			ubyte height;		// high
			ubyte erodeSpeed; 	// erod: magnitude only
			ubyte tutorial; 	// tuto
			ubyte emerge;		// emrg (?)
			ubyte landslide; 	// fall: 0 = can't occur; 1-8 = can occur
			ubyte cryore;		// cror
			bool hidden;		// dugg
		/+}
		ubyte[8] data;
		ulong dataLong;
	}+/
}