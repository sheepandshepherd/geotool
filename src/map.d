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

module map;

import derelict.opengl3.gl3;
import derelict.devil.il, derelict.devil.ilut, derelict.devil.ilu : iluScale;
import util.linalg;
import mesh, biome;

import std.typecons : tuple, Tuple, EnumMembers;

import std.algorithm.searching : canFind;
import std.algorithm.comparison : clamp, min, max;


import gl3n.plane;

import tile;


import main : debugLog;
import dialog;
import main : filePath = path;



struct MeshSort
{
	align(4) uint texID;	// texID, not glID
	align(1) ubyte erode;	// erosion level (0-5)
	align(1) bool ceiling;	// separate hidden walls
	align(1) bool hidden;	// separate hidden caverns
	/+union
	{
		struct
		{

		}
		ulong data;
		struct
		{
			uint _dataPart1;
			uint _dataPart2;
		}
	}+/
	/+bool opEquals()(auto ref const MeshSort s) const { return data == s.data; }
	int opCmp(ref const MeshSort s) const
	{
		if(data==s.data) return 0;
		if(data<s.data) return -1;
		return 1;
	}
	size_t toHash() const nothrow @safe
	{
		return (_dataPart1 ^ _dataPart2);
	}+/
}

/// std.path.isValidFilename
static class Map
{
static:
	ubyte w=0, h=0;
	Tile[] tiles;
	nothrow Tile* opIndex(uint x, uint y)
	{
		if(x >= w || y >= h) return null;
		return &tiles[x+w*y];
	}
	nothrow void opIndexAssign(Tile v, uint x, uint y)
	{
		if(x >= w || y >= h) return;
		tiles[x+w*y] = v;
	}



	static const ubyte[10] terrainTypes = [5,4,3,2,1,8,0xa,0xb,9,6];
	static const string[10] terrainTypeNames = ["Ground","Dirt","Loose rock","Hard rock","Solid rock","Ore seam","Crystal seam","Recharge seam","Water","Lava"];
	static const float heightMod = 1f/8f;
	static vec2i[][6] brushesSquare;
	static vec2i[][6] brushesRound;
	static vec2ui[] brushFill;
	static this()
	{
		brushesSquare[0] = [vec2i(0,0)];
		foreach(uint i; 1..6)
		{
			brushesSquare[i] = brushFillSquare(i+1);
		}

		brushesRound[0] = brushesSquare[1];
	}

	static vec2i[] brushFillSquare(int range)
	{
		vec2i[] ret = [];
		foreach(int y; 0..range)
		{
			foreach(int x; 0..range)
			{
				ret ~= vec2i(x,y);
			}
		}
		vec2i minus = vec2i((range-1)/2,(range-1)/2);
		foreach(i; 0..ret.length)
		{
			ret[i] -= minus;
		}
		return ret;
	}

static:
	/// data components of the map; 15 Aug 2015: replaced with Tile class
	///MapComponent surf, high, dugg, cror, path, erod, slid;
	///MapComponent surfDefault, highDefault;
	bool isMeshBuilt = false;

	/+MapComponent opIndex(uint comp)
	{
		switch(comp)
		{
			case 0:
				return surf;
			case 1:
				return high;
			default:
				return null;
		}
	}+/



	bool hideCeiling = false;
	bool markHidden = true;		// red lines on hidden caverns
	bool markErosion = true;	// yellow/red squares for erosion
	bool cull = false; // cull terrain not on the camera. (uses meshes instead of sortedMeshes)

	vec2ui[] neighbors(uint x, uint y)
	{
		vec2ui[] ret = [];
		const vec2i[8] nDirs = [vec2i(1,0),vec2i(1,1),vec2i(0,1),vec2i(-1,1),
								vec2i(-1,0),vec2i(-1,-1),vec2i(0,-1),vec2i(1,-1),];
		foreach(vec2i d; nDirs)
		{
			vec2i coord = vec2i(x,y)+d;
			if(coord.x >= 0 && coord.x < w && coord.y >= 0 && coord.y < h)
			{
				ret ~= vec2ui(coord.x, coord.y);
			}
		}
		return ret;
	}

	vec2ui[] neighborsHigh(uint x, uint y)
	{
		vec2ui[] ret = [];
		const vec2i[3] nDirs = [vec2i(-1,0),vec2i(-1,-1),vec2i(0,-1)];
		foreach(vec2i d; nDirs)
		{
			vec2i coord = vec2i(x,y)+d;
			if(coord.x >= 0 && coord.x < w && coord.y >= 0 && coord.y < h)
			{
				ret ~= vec2ui(coord.x, coord.y);
			}
		}
		return ret;
	}

	vec2ui[] neighborsConnected(uint x, uint y)
	{
		vec2ui[] ret = [];
		const vec2i[4] nDirs = [vec2i(1,0),vec2i(0,1),vec2i(-1,0),vec2i(0,-1)];
		foreach(vec2i d; nDirs)
		{
			vec2i coord = vec2i(x,y)+d;
			if(coord.x >= 0 && coord.x < w && coord.y >= 0 && coord.y < h)
			{
				ret ~= vec2ui(coord.x, coord.y);
			}
		}
		return ret;
	}

	// lazy, because allocation every frame = bad
	void fill(vec2ui v)
	{
		if(!validCoord(v)) brushFill = null;
		else
		{
			vec2ui[] ret = [];
			fillAddRecursive(v, ret); // brushFill[0] will always be the center/picked coordinate
			brushFill = (ret.length==0)?null:ret;
		}
	}

	private void fillAddRecursive(vec2ui v, ref vec2ui[] into)
	{
		if(canFind(into,v)) return; // do nothing if it's already there
		into ~= v;
		foreach(vec2ui n; neighborsConnected(v.x,v.y))
		{
			if(Map[n.x,n.y].type == Map[v.x,v.y].type) fillAddRecursive(n, into);
		}

	}

	/// [w-1,h-1] meshes for each tile, using "surf mode", in which all surfs are shown
	TerrainMesh[] meshes;
	/// meshes sorted into arrays by texture index; batch rendering of each texture type
	TerrainMesh[MeshSort] sortedMeshes;

	/// rebuilds the mesh at x,y. remember to rebuild neighboring meshes as well when changing this one's terrain type.
	void buildMesh(uint x, uint y)
	{
		import derelict.glfw3.glfw3 : glfwGetTime;

		auto timeStart = glfwGetTime();

		if((brushFill !is null) && brushFill.canFind(vec2ui(x,y))) brushFill = null; // recalculate the fill area if any changes are made to it
		/++if(meshes[x+w*y] !is null)
		{
			meshes[x+w*y].Unload();
			meshes[x+w*y].destroy();
			meshes[x+w*y] = null;
		}+/
		// surf and high maps are *required* to build the mesh.
		// since putting (surf !is null) everywhere would get very unreadable, I will create a temp
		//    surf/high of size [0,x], which will always return the value x when indexed.
		if(tiles is null || tiles.length < 4 || x==w-1 || y==h-1) return;

		Tile* t = Map[x,y];

		TerrainMesh m = (meshes[x+w*y] is null)?(new TerrainMesh()):(meshes[x+w*y]);
		m.sort.erode = t.erodeSpeed;
		m.sort.hidden = false;
		m.sort.ceiling = false;
		m.sort.texID = 0;

		scope(exit)
		{
			meshes[x+w*y] = m;
			m.UpdateIndexed;
			auto timeTotal = glfwGetTime() - timeStart;
			//debugLog("buildMesh(): ",timeTotal);
		}

		float typeF = cast(float)t.type;
		m.uvs = [vec3(0,1,typeF),vec3(1,1,typeF),vec3(1,0,typeF),vec3(0,0,typeF)];
		//ubyte[4] highCorners = [high[x,y],high[x+1,y],high[x+1,y+1],high[x,y+1]];
		float[4] hC = [heightMod*t.height,heightMod*Map[x+1,y].height,heightMod*Map[x+1,y+1].height,heightMod*Map[x,y+1].height];

		with(Type)
		{
			if(Tile.isGround(t.type))
			{
				// ground: use flat mesh. triangles drawn from the two opposite corners with LARGER height difference.
				m.M = mat4.translation(cast(float)x+0.5f,cast(float)y+0.5f,0);
				m.verts = [vec3(-0.5,-0.5,hC[0]),vec3(0.5,-0.5,hC[1]),vec3(0.5,0.5,hC[2]),vec3(-0.5,0.5,hC[3])];
				
				if(std.math.abs(hC[0]-hC[2]) > std.math.abs(hC[1]-hC[3]))
				{
					m.tris = triLayout0;
				}
				else
				{
					m.tris = triLayout1;
				}

				m.sort.hidden = t.hidden;
				if(t.type == erosion) m.sort.texID = Tile.erosionTex[std.algorithm.comparison.clamp(t.erodeSpeed-2,0,3)];
				else m.sort.texID = Tile.groundTex.get(t.type,0); //Biome.simpleGroundTex.get(surf[x,y],70);
				return;
			}
			else
			{
				// else: wall: determine mesh and rotation from surroundings, and exact texture type from surf
				ubyte rot = ubyte.max;

				// create the surf Match to compare with:
				Match wallMatch = Match([
						(x > 0 && y > 0)?((Tile.isGround(Map[x-1,y-1].type))?mGround:mWall):mWall,
						(y > 0)?((Tile.isGround(Map[x,y-1].type))?mGround:mWall):mWall,
						(y > 0)?((Tile.isGround(Map[x+1,y-1].type))?mGround:mWall):mWall,
						(x > 0)?((Tile.isGround(Map[x-1,y].type))?mGround:mWall):mWall,
						((Tile.isGround(Map[x+1,y].type))?mGround:mWall),
						(x > 0)?((Tile.isGround(Map[x-1,y+1].type))?mGround:mWall):mWall,
						((Tile.isGround(Map[x,y+1].type))?mGround:mWall),
						((Tile.isGround(Map[x+1,y+1].type))?mGround:mWall)
					]);
				// COMPARE: straight
				rot = wallMatch.compare(matchTemplates[0]);
				if(rot < 4)
				{
					m.M = mat4(rotM[rot]).translate(cast(float)x+0.5f,cast(float)y+0.5f,0);
					m.verts = [vec3(-0.5,-0.5,hC[normalize(0+rot)]+1f),vec3(0.5,-0.5,hC[normalize(1+rot)]+1f),vec3(0.5,0.5,hC[normalize(2+rot)]),vec3(-0.5,0.5,hC[normalize(3+rot)])];
					if(std.math.abs(m.verts[0].z-m.verts[2].z) < std.math.abs(m.verts[1].z-m.verts[3].z))
					{
						m.tris = triLayout0;
					}
					else
					{
						m.tris = triLayout1;
					}
					m.sort.texID = Tile.wallTex.get(t.type,[0,0,0,0])[0];
					return;
				}
				// COMPARE: corner
				rot = wallMatch.compare(matchTemplates[1]);
				if(rot < 4)
				{
					m.M = mat4(rotM[rot]).translate(cast(float)x+0.5f,cast(float)y+0.5f,0);
					m.verts = [vec3(-0.5,-0.5,hC[normalize(0+rot)]+1f),vec3(0.5,-0.5,hC[normalize(1+rot)]),vec3(0.5,0.5,hC[normalize(2+rot)]),vec3(-0.5,0.5,hC[normalize(3+rot)])];
					m.tris = triLayout1;
					m.sort.texID = Tile.wallTex.get(t.type,[0,0,0,0])[1];
					return;
				}
				// COMPARE: innerCorner
				rot = wallMatch.compare(matchTemplates[2]);
				if(rot < 4)
				{
					m.M = mat4(rotM[rot]).translate(cast(float)x+0.5f,cast(float)y+0.5f,0);
					m.verts = [vec3(-0.5,-0.5,hC[normalize(0+rot)]+1f),vec3(0.5,-0.5,hC[normalize(1+rot)]+1f),vec3(0.5,0.5,hC[normalize(2+rot)]),vec3(-0.5,0.5,hC[normalize(3+rot)]+1f)];
					m.tris = triLayout1;
					m.sort.texID = Tile.wallTex.get(t.type,[0,0,0,0])[2];
					return;
				}
				// COMPARE: between
				rot = wallMatch.compare(matchTemplates[3]);
				if(rot < 4)
				{
					m.M = mat4(rotM[rot]).translate(cast(float)x+0.5f,cast(float)y+0.5f,0);
					m.verts = [vec3(-0.5,-0.5,hC[normalize(0+rot)]+1f),vec3(0.5,-0.5,hC[normalize(1+rot)]),vec3(0.5,0.5,hC[normalize(2+rot)]+1f),vec3(-0.5,0.5,hC[normalize(3+rot)])];
					m.tris = triLayout0;
					m.sort.texID = 77;
					return;
				}
				// COMPARE: ceiling
				rot = wallMatch.compare(matchTemplates[4]);
				if(rot < 4)
				{
					m.M = mat4.translation(cast(float)x+0.5f,cast(float)y+0.5f,0);
					m.verts = [vec3(-0.5,-0.5,hC[0]+1f),vec3(0.5,-0.5,hC[1]+1f),vec3(0.5,0.5,hC[2]+1f),vec3(-0.5,0.5,hC[3]+1f)];
					m.sort.texID = Tile.wallTex.get(t.type,[77,77,77,77])[0]; // removed: hideCeiling?70:
					/// TODO: check out level 12, top center "roof", to see if it appears as a diamond (this) or a square (reverse triLayout0/1 ORDER).
					if(std.math.abs(hC[0]-hC[2]) > std.math.abs(hC[1]-hC[3]))
					{
						m.tris = triLayout0;
					}
					else
					{
						m.tris = triLayout1;
					}
					if(m.sort.texID==0) m.sort.texID = 77;
					m.sort.ceiling = true;
					return;
				}
				// ELSE: no match to a correct wall type, use flat
				m.M = mat4.translation(cast(float)x+0.5f,cast(float)y+0.5f,0);
				m.verts = [vec3(-0.5,-0.5,hC[0]),vec3(0.5,-0.5,hC[1]),vec3(0.5,0.5,hC[2]),vec3(-0.5,0.5,hC[3])];
				
				if(std.math.abs(hC[0]-hC[2]) > std.math.abs(hC[1]-hC[3]))
				{
					m.tris = triLayout0;
				}
				else
				{
					m.tris = triLayout1;
				}
				m.sort.texID = Tile.wallTex.get(t.type,[0,0,0,0])[0];
				return;
			}
		}

	}

	/// erases the map meshes.
	void cleanMeshes()
	{
		if(meshes is null) return;
		foreach(TerrainMesh t; meshes)
		{
			if(t is null) continue; // last row/column
			t.Unload();
			t.destroy();
		}
		meshes = null;
	}

	/// rebuilds the map meshes. returns true if successful, false if invalid map.
	bool buildMeshes()
	{
		import derelict.glfw3.glfw3 : glfwGetTime;
		
		///auto timeStart = glfwGetTime();
		///debugLog("buildMeshes()");
		isMeshBuilt = false;
		if(!isValidMap)
		{
			cleanMeshes();
			return false;
		}
		if(meshes.length != w*h) // Only clean and rebuild if necessary
		{
			cleanMeshes();
			meshes = new TerrainMesh[w*h];
		}

		foreach(int y; 0..h)
		{
			foreach(int x; 0..w)
			{
				buildMesh(x,y);

			}
		}
		isMeshBuilt = true;
		///auto timeTotal = glfwGetTime() - timeStart;
		///debugLog("buildMeshes(): ",timeTotal);
		return true;
	}

	void cleanSortedMeshes()
	{
		foreach(TerrainMesh t; sortedMeshes)
		{
			t.Unload();
			t.destroy();
		}
		sortedMeshes = null;
	}

	/// sorts the meshes into arrays based on GL ID for texture. needs to be redone when changing biome!
	void sortMeshes()
	{
		import derelict.glfw3.glfw3 : glfwGetTime;

		//auto timeStart = glfwGetTime();
		///debugLog("sortMeshes()");
		//cleanSortedMeshes(); /// 6 Aug 2015: recycle as many as possible, only remaining ones are cleaned below

		TerrainMesh[] recycleStack = (sortedMeshes.length==0)?[]:sortedMeshes.values;
		sortedMeshes = null;

		foreach(i; 0..meshes.length)
		{
			if(meshes[i] is null) continue; // skip the blank ones in the last row/column
			//uint glid = Biome.selected.textures.get(meshes[i].textureID,uint.max); /// 6 Aug 2015: textureID refers to the SURF TYPE ID, not the OpenGL texture ID thereof in the selected biome.
			MeshSort sort = meshes[i].sort;
			if(sortedMeshes.get(sort,null) is null)
			{
				// create blank mesh to hold combined submeshes for each tile of this texture ID
				TerrainMesh nt;
				if(recycleStack.length != 0)
				{
					nt = recycleStack[$-1];
					nt.recycle();
					recycleStack = recycleStack[0..$-1]; // take last one out of the slice
				}
				else{
					nt = new TerrainMesh();
				}
				nt.sort = sort;

				sortedMeshes[sort] = nt;
			}
			// add this tile's mesh to the combined mesh
			sortedMeshes[sort].add(meshes[i]);
		}
		///debugLog("updating...");
		foreach(TerrainMesh t; sortedMeshes)
		{
			t.Update();
		}
		///debugLog("recycling...");
		foreach(TerrainMesh t; recycleStack) // clean leftovers that weren't recycled
		{
			t.Unload();
			t.destroy();
		}
		recycleStack = null;

		///updateMatrix(); /// why?
		//auto timeTotal = glfwGetTime() - timeStart;
		//std.stdio.writeln("sortMeshes(): ",timeTotal,"; add time: ",(timeAddAverage),"/av ",(timeAddAverage/numAdd));
	}

	/// ---------- RENDERING STUFF ----------
	/// these should be updated any time the camera is modified
	vec2 cameraPos = vec2(6,6); // target of camera; height is taken from high map. For now: center of light source.
	vec4 viewerPos;
	float cameraAngle = 0.8f; // [0.1f..1f], 1f being fully top-down
	float cameraRot = 0f; // [0f..1f)
	float cameraZoom = 10f; // distance from cameraPos, in direction of Angle and Rot
	mat4 VP, iVP, V, P, iV, iP; // projection and view matrix
	vec4 f00, f10, f01, f11; // corners of the frustum
	Plane pR, pL, pT, pB;

	nothrow void updateMatrix()
	{
		import main: window, width, height, m, mb;
		vec4 centerPos = vec4(cameraPos.x,cameraPos.y,-heightAtPos(cameraPos),1);
		cameraAngle = (cameraAngle < 0.1f)?0.1f:(cameraAngle > 1f)?1f:cameraAngle;
		float rot = normalize(cameraRot,1f)*std.math.PI*2;
		
		viewerPos = mat4.translation(centerPos.x,centerPos.y,centerPos.z)*(mat4.zrotation(rot)*(mat4.xrotation(-cameraAngle*std.math.PI_2)*vec4(0,cameraZoom,0,1)));
		vec3 lookUp = (cameraAngle == 1f)?vec3(mat4.zrotation(rot)*vec4(0,-1,0,0)):vec3(0,0,-1);
		V = mat4.look_at(vec3(viewerPos),vec3(centerPos),lookUp);
		iV = V.inverse;//mat4.identity;
		/+mat4 rV = mat4.identity;
		iV.matrix[3][0] = -V.matrix[3][0];
		iV.matrix[3][1] = -V.matrix[3][1];
		iV.matrix[3][2] = -V.matrix[3][2];
		foreach(uint x; 0..3)
		{
			foreach(uint y; 0..3)
			{
				rV.matrix[y][x] = V[y][x];
			}
		}
		rV = rV.transposed;
		foreach(uint x; 0..3)
		{
			foreach(uint y; 0..3)
			{
				iV.matrix[y][x] = rV.matrix[y][x];
			}
		}+/


		P = mat4.perspective(width,height,80f,0.1f,100f);
		//iP = mat4.perspective_inverse(width,height,80f,0.1f,100f);
		iP = P.inverse;
		VP = P*V;
		//iVP = projectionMatrix
		iVP = iV*iP; /// TODO: can this be done more efficiently, without fully recomputing the inverse version of the VPmat?
		f00 = (iVP*vec4(-1f,-1f,0f,1f));
		f01 = (iVP*vec4(-1f,1f,0f,1f));
		f10 = (iVP*vec4(1f,-1f,0f,1f));
		f11 = (iVP*vec4(1f,1f,0f,1f));
		foreach(vec4* point; [&f00,&f01,&f10,&f11])
		{
			point.w = 1f/point.w;
			point.x *= point.w;
			point.y *= point.w;
			point.z *= point.w;
		}

		vec3 s00 = vec3(viewerPos-f00), s01 = vec3(viewerPos-f01), s10 = vec3(viewerPos-f10), s11 = vec3(viewerPos-f11);
		//vec3 vR = f01-f00, vL = f11-f10, vT = f11-f01, vB = f10-f00;
		pR = Plane((s00).cross(-s01),0).normalized();
		pL = Plane((s11).cross(-s10),0).normalized();
		pT = Plane((s01).cross(-s11),0).normalized();
		pB = Plane((s10).cross(-s00),0).normalized();
		pR.d = pR.distance(vec3(viewerPos));
		pL.d = pL.distance(vec3(viewerPos));
		pT.d = pT.distance(vec3(viewerPos));
		pB.d = pB.distance(vec3(viewerPos));
	}

	nothrow float heightAtPos(vec2 v){ return heightAtPos(v.x,v.y); }
	nothrow float heightAtPos(float x, float y)
	{
		/// BILINEAR INTERPOLATION
		import std.math;
		import std.algorithm : clamp;
		if(tiles is null) return 0f;
		uint x1 = clamp(cast(uint)trunc(x),0,w-2);
		uint y1 = clamp(cast(uint)trunc(y),0,h-2);
		uint x2 = clamp(x1+1,1,w-1);
		uint y2 = clamp(y1+1,1,h-1);

		float tx = 1f-clamp(clamp(x,0,w) - cast(float)x1,0f,1f);
		float ty = 1f-clamp(clamp(y,0,h) - cast(float)y1,0f,1f);

		/+import ui;
		import std.conv;
		UI.mapBarLabel2 = text(x,",",y,"  ",tx,",",ty,"  ",x1,",",y1);+/

		//if(x1 < 0 || y1 < 0 || x2 > w-1 || y2 > h-1) return 0f;

		float x1y1 = heightMod*Map[x1,y1].height, x2y1 = heightMod*Map[x2,y1].height, x1y2 = heightMod*Map[x1,y2].height, x2y2 = heightMod*Map[x2,y2].height;

		float h = (tx)*( (ty)*(x1y1) + (1f-ty)*(x1y2) ) + (1f-tx)*( (ty)*(x2y1) + (1f-ty)*(x2y2) );
		return h;
		//return -(ty*(tx*x1y1+(1f-tx)*x2y1)+(1f-ty)*(tx*x1y2+(1f-tx)*x2y2));
	}

	/// draw terrain from meshesSorted using Biome.selected for textures or Biome.colors for missing texture IDs
	void renderMeshes()
	{
		import main : terrainShader;
		import ui : UI;
		import derelict.opengl3.gl3;

		/+auto glErr = glGetError();
		if(glErr != 0) debugLog("RENDER begin: ", glErr);+/

		///debugLog("renderMeshes()");

		terrainShader.bind();
		

		//terrainShader.uniform_matrix4fv("M",cast(float[])t.M.matrix);

		//debug std.stdio.writeln("@MVP = ",terrainShader.get_uniform_location("MVP"));
		/// TODO: move this array out, update it along with cameraPos. Allocating every frame = bad.
		terrainShader.uniform3fv("lightPos",[cameraPos.x,cameraPos.y,-heightAtPos(cameraPos)]);
		//terrainShader.uniform3fv("surf",(vec3(Biome.colors.get(Biome.surfType[t.textureID],v3ub(128,128,128)))*(1f/255f)).vector);
		///terrainShader.uniform4fv("select",[cast(float)UI.pickedCoord.x, cast(float)UI.pickedCoord.y,0f,0f]);
		terrainShader.uniform_matrix4fv("MVP",(VP).matrixFlat);  // *t.M not needed, always identity

		///debugLog("sortedMeshes loop");
		foreach(MeshSort tsort, TerrainMesh t; sortedMeshes)
		{
			//if(Biome.selected.textures.get(texID,uint.max) == uint.max) continue;


			// bind and activate texture IF texture exists
			int ehcc = markErosion?((cast(int)(t.sort.erode))<<3):0; // erode, (1)hidden, (1)color, (1)ceiling
			uint surfTexID = t.sort.texID;
			bool ceiling = t.sort.ceiling;
			uint glTexID = Biome.selected.textures.get(surfTexID,0);
			if(hideCeiling&&ceiling)
			{
				ehcc |= (1); // ceiling (1st bit)
				glTexID = Biome.selected.textures.get(70,0); // use the ceiling tex instead if we're supposed to hide it
			}

			if(markHidden && t.sort.hidden) ehcc |= (1<<2); // hidden (3rd bit)

			if(Biome.selected.defaultBiome || glTexID == 0)
			{
				ehcc |= (1<<1); // color (2nd bit)
				//terrainShader.uniform1i("useColor",(hideCeiling&&ceiling)?2:1);
			}
			else
			{
				//terrainShader.uniform1i("useColor",0);
				glActiveTexture(GL_TEXTURE0);
				glBindTexture(GL_TEXTURE_2D, glTexID);
				terrainShader.uniform1i("tex",0);
			}
			terrainShader.uniform1i("ehcc",ehcc);

			uint storage = terrainShader.get_attrib_location("vPos");
			glEnableVertexAttribArray(storage);
			t.vertbuffer.bind;
			glVertexAttribPointer(storage, 3, GL_FLOAT,GL_FALSE,0,null);

			t.uvbuffer.bind;
			storage = terrainShader.get_attrib_location("vUV");
			glEnableVertexAttribArray(storage);
			glVertexAttribPointer(storage, 3, GL_FLOAT,GL_FALSE,0,null);

			t.normalbuffer.bind;
			storage = terrainShader.get_attrib_location("vNorm");

			glEnableVertexAttribArray(storage);
			glVertexAttribPointer(storage, 3, GL_FLOAT,GL_FALSE,0,null);

			glDrawArrays(GL_TRIANGLES,0,cast(uint)t.verts.length);
			
			glDisableVertexAttribArray(storage);
			storage = terrainShader.get_attrib_location("vPos");
			glDisableVertexAttribArray(storage);

		}
		import std.conv : text;
		import main : deltaTime;
		if(UI.showDebug) UI.debugMessage = "[F] Rendering "~text(meshes.length)~" meshes sorted into "~text(sortedMeshes.length)~" material groups. "~text(cast(uint)(1f/deltaTime))~"FPS";

		terrainShader.unbind();

		/+glErr = glGetError();
		if(glErr != 0) debugLog("RENDER end: ", glErr);+/
	}

	/// draw terrain from meshes using Biome.selected for textures or Biome.colors for missing texture IDs, but DISCARD terrain outside the view frustum
	version(none) void renderCulledMeshes()
	{
		import main : terrainShader;
		import ui : UI;
		debugLog("BAD");
		return;
		terrainShader.bind();
		
		return; ///////////////////////////////////////////////////////////////////////
		//terrainShader.uniform_matrix4fv("M",cast(float[])t.M.matrix);
		
		//debug std.stdio.writeln("@MVP = ",terrainShader.get_uniform_location("MVP"));
		/// TODO: move this array out, update it along with cameraPos. Allocating every frame = bad.
		terrainShader.uniform3fv("lightPos",[cameraPos.x,cameraPos.y,-heightAtPos(cameraPos)]);
		//terrainShader.uniform3fv("surf",(vec3(Biome.colors.get(Biome.surfType[t.textureID],v3ub(128,128,128)))*(1f/255f)).vector);
		///terrainShader.uniform4fv("select",[cast(float)UI.pickedCoord.x, cast(float)UI.pickedCoord.y,0f,0f]);

		uint numMeshesRendered = 0;

		foreach(uint x; 0..w) foreach(uint y; 0..h)
		{
			//if(Biome.selected.textures.get(texID,uint.max) == uint.max) continue;
			TerrainMesh t = meshes[x+w*y];

			/+++vec3 center = vec3(x+0.5f,y+0.5f,0f);
			center.z = heightAtPos(center.x,center.y);
			if(pR.distance(center) < 2f) continue;
			if(pL.distance(center) < 2f) continue;
			if(pT.distance(center) < 2f) continue;
			if(pB.distance(center) < 2f) continue;+/
			numMeshesRendered += 1;

			terrainShader.uniform_matrix4fv("MVP",(VP*t.M).matrixFlat);  // *t.M needed in this case
			
			// bind and activate texture IF texture exists
			uint surfTexID = t.sort.texID;
			bool ceiling = t.sort.ceiling;
			if(ceiling) surfTexID -= 100;
			uint glTexID = Biome.selected.textures.get(surfTexID,0);
			if(hideCeiling&&ceiling) glTexID = Biome.selected.textures.get(70,0); // use the ceiling tex instead if we're supposed to hide it
			if(Biome.selected.defaultBiome || glTexID == 0)
			{
				terrainShader.uniform1i("useColor",(hideCeiling&&ceiling)?2:1);
			}
			else
			{
				terrainShader.uniform1i("useColor",0);
				glActiveTexture(GL_TEXTURE0);
				glBindTexture(GL_TEXTURE_2D, glTexID);
				terrainShader.uniform1i("tex",0);
			}
			
			uint storage = terrainShader.get_attrib_location("vPos");
			glEnableVertexAttribArray(storage);
			t.vertbuffer.bind;
			glVertexAttribPointer(storage, 3, GL_FLOAT,GL_FALSE,0,null);
			
			t.uvbuffer.bind;
			storage = terrainShader.get_attrib_location("vUV");
			glEnableVertexAttribArray(storage);
			glVertexAttribPointer(storage, 3, GL_FLOAT,GL_FALSE,0,null);
			
			t.normalbuffer.bind;
			storage = terrainShader.get_attrib_location("vNorm");
			
			glEnableVertexAttribArray(storage);
			glVertexAttribPointer(storage, 3, GL_FLOAT,GL_FALSE,0,null);
			
			glDrawArrays(GL_TRIANGLES,0,t.verts.length);
			
			glDisableVertexAttribArray(storage);
			storage = terrainShader.get_attrib_location("vPos");
			glDisableVertexAttribArray(storage);
			
		}
		import std.conv : text;
		import main : deltaTime;
		if(UI.showDebug) UI.debugMessage = "[F] Rendering "~text(numMeshesRendered)~" of "~text(meshes.length)~" meshes. "~text(cast(uint)(1f/deltaTime))~"FPS";
		
		terrainShader.unbind();
	}

	vec2ui[] highlights;
	/// redraw all squares that are in the editor brush's selection
	/// SURF highlights: make sure last row and column are not included
	void renderHighlights()
	{
		import main : colorShader;
		import ui : UI;

		if(highlights is null || highlights.length == 0) return;

		colorShader.bind();

		const float[4] colorArray = [0f,1f,0f,0.1f];

		colorShader.uniform4fv("color",colorArray);

		foreach(vec2ui v; highlights)
		{
			// valid coordinate?
			if(!validCoord(v)) continue;
			if(v.x == w-1 || v.y == h-1) continue; // skip last row and column

			TerrainMesh t = meshes[v.x+(w)*v.y];

			colorShader.uniform_matrix4fv("MVP",(Map.VP).matrixFlat);  // *t.M not needed, always identity
			
			uint storage = colorShader.get_attrib_location("vPos");
			///debug std.stdio.writeln("@vPos = ",storage);
			glEnableVertexAttribArray(storage);
			t.vertbuffer.bind; /// CRASHES
			glVertexAttribPointer(storage, 3, GL_FLOAT,GL_FALSE,0,null);

			glDrawArrays(GL_TRIANGLES,0,6); // always 6, since 2 triangles

		}

		colorShader.unbind();
	}

	///
	// void renderPoints()

	/// draw terrain from meshes as index to
	void renderControls()
	{

	}

	/// test validity of map: all required components must be present and equally sized.
	/// call before each rebuild of the mesh. clear the map if invalid.
	bool isValidMap()
	{
		if(tiles is null) return false;  // allows "default values" for null maps, as long as either is present
		if(tiles.length < 4 || w < 2 || h < 2) return false;
		return true;
	}


	/// ------------------------------------------------------------------------------
	/// Map stuff  -------------------------------------------------------------------
	/// ------------------------------------------------------------------------------

	/// radar maps for each component; always 256x256 pixels with alpha background behind non-square maps
	uint[2] mapImages;
	ubyte[256*256*4] blankData = 0; // buffer for map image updates, so no allocation needs to happen

	/// Initiates the textures for each map image
	void generateMapImages()
	{

		glGenTextures(mapImages.length, mapImages.ptr);
		foreach(uint id; mapImages)
		{
			//glGenTextures(1, id);
			glBindTexture(GL_TEXTURE_2D, id);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,256,256,0,GL_RGBA,GL_UNSIGNED_BYTE,&blankData);
		}
		glBindTexture(GL_TEXTURE_2D, 0);

		// store in the indexed array; no need for pointers, values won't ever change
		//mapImages[0..2] = [terrainMap, highMap];
	}

	bool updateSurfMapImage()
	{
		import derelict.opengl3.gl3;
		import imgui.api : RGBA;
		if(tiles is null) return false;
		/+auto glErr = glGetError();
		if(glErr != 0) debugLog("SURF MAP begin: ", glErr);+/
		glBindTexture(GL_TEXTURE_2D, mapImages[0]);
		// clear the image with transparency:
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 256, 256, GL_RGB, GL_UNSIGNED_BYTE, &blankData);
		///glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,256,256,0,GL_RGBA,GL_UNSIGNED_BYTE,&blankData);

		ubyte[] data = new ubyte[w*h*4];

		foreach(uint oy; 0..h)
		{
			uint y = h - oy - 1;
			foreach(uint x; 0..w)
			{
				// TODO: add custom surf radar color loading from file
				RGBA sColor = Tile.colors.get(Map[x,oy].type,RGBA(32,32,32));
				data[4*(x+w*y)] = sColor.r;
				data[4*(x+w*y)+1] = sColor.g;
				data[4*(x+w*y)+2] = sColor.b;
				data[4*(x+w*y)+3] = 255;
			}
		}

		uint ilTemp = ilGenImage();
		ilBindImage(ilTemp);
		ilTexImage(w, h, 1, 4, IL_RGBA, IL_UNSIGNED_BYTE, data.ptr);

		if(w == h)
		{
			iluScale(256, 256, 1);
			//ilSaveImage(std.string.toStringz(filePath~"\\TESTscaled.png"));
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 256, 256, GL_RGBA, GL_UNSIGNED_BYTE, ilGetData());
		}
		else if(w > h)
		{
			int nh = min(256,cast(int)(256f*(cast(float)h/cast(float)w)));
			iluScale(256, nh, 1);
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 128-(nh/2), 256, nh, GL_RGBA, GL_UNSIGNED_BYTE, ilGetData());
		}
		else
		{
			int nw = min(256,cast(int)(256f*(cast(float)w/cast(float)h)));
			iluScale(nw, 256, 1);
			glTexSubImage2D(GL_TEXTURE_2D, 0, 128-(nw/2), 0, nw, 256, GL_RGBA, GL_UNSIGNED_BYTE, ilGetData());
		}

		ilDeleteImage(ilTemp);

		/+glErr = glGetError();
		if(glErr != 0) debugLog("SURF MAP end: ", glErr);+/

		return true;
	}

	bool updateHighMapImage()
	{
		import imgui.api : RGBA;
		if(tiles is null) return false;
		glBindTexture(GL_TEXTURE_2D, mapImages[1]);
		// clear the image with transparency:
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 256, 256, GL_RGB, GL_UNSIGNED_BYTE, &blankData);
		///glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,256,256,0,GL_RGBA,GL_UNSIGNED_BYTE,&blankData);
		
		ubyte[] data = new ubyte[w*h*4];
		
		foreach(uint oy; 0..h)
		{
			uint y = h - oy - 1;
			foreach(uint x; 0..w)
			{
				// TODO: add custom surf radar color loading from file
				ubyte heightByte = (Map[x,oy].height >= 64)?255:cast(ubyte)(Map[x,oy].height*4);
				data[4*(x+w*y)] = heightByte;
				data[4*(x+w*y)+1] = heightByte;
				data[4*(x+w*y)+2] = heightByte;
				data[4*(x+w*y)+3] = 255;
			}
		}
		
		uint ilTemp = ilGenImage();
		ilBindImage(ilTemp);
		ilTexImage(w, h, 1, 4, IL_RGBA, IL_UNSIGNED_BYTE, data.ptr);
		//ilSaveImage(std.string.toStringz(filePath~"\\TESTunscaled.png"));
		
		if(w == h)
		{
			iluScale(256, 256, 1);
			//ilSaveImage(std.string.toStringz(filePath~"\\TESTscaled.png"));
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 256, 256, GL_RGBA, GL_UNSIGNED_BYTE, ilGetData());
		}
		else if(w > h)
		{
			int nh = min(256,cast(int)(256f*(cast(float)h/cast(float)w)));
			iluScale(256, nh, 1);
			//ilSaveImage(std.string.toStringz(filePath~"\\TESTscaled.png"));
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 128-(nh/2), 256, nh, GL_RGBA, GL_UNSIGNED_BYTE, ilGetData());
		}
		else
		{
			int nw = min(256,cast(int)(256f*(cast(float)w/cast(float)h)));
			iluScale(nw, 256, 1);
			//ilSaveImage(std.string.toStringz(filePath~"\\TESTscaled.png"));
			glTexSubImage2D(GL_TEXTURE_2D, 0, 128-(nw/2), 0, nw, 256, GL_RGBA, GL_UNSIGNED_BYTE, ilGetData());
		}
		
		ilDeleteImage(ilTemp);
		
		return true;
	}

	public bool empty() @property
	{
		return tiles is null;
	}

	public bool validCoord(vec2ui coord)
	{
		import std.algorithm : min;
		if(mapSize.x == 0 || mapSize.y == 0 || coord.x >= mapSize.x || coord.y >= mapSize.y)
			return false;
		return true;
	}

	public bool validCoord(uint x, uint y)
	{
		import std.algorithm : min;
		if(mapSize.x == 0 || mapSize.y == 0 || x >= mapSize.x || y >= mapSize.y)
			return false;
		return true;
	}

	/// size of the map, (0, 1) if sizes are mismatched, or (0, 0) if no maps loaded
	vec2ui mapSize() @property
	{
		return vec2ui(cast(uint)w,cast(uint)h);
	}

	/// component of a map in LRR-form: just an array of ubytes. Temporary holder for data during loading.
	public static class MapComponent
	{
		ubyte w, h;
		ubyte[] data;

		/+uint id(uint x, uint y)
		{
			return x + w*y;
		}+/

		ubyte opIndex(uint x, uint y)
		{
			if(w == 0 || data is null)
				return cast(ubyte)h;
			else if(x < w && y < h)
				return data[x + w*y];
			else
				return ubyte.max;
		}

		void opIndexAssign(ubyte v, uint x, uint y)
		{
			if(w == 0 || data is null)
				return;
			else if(x < w && y < h)
				data[x + w*y] = v;
		}

		/// general all-purpose map loader
		static MapComponent loadMap(string filePath)
		{
			import std.file;
			import std.stdio : writeln;
			import main : debugLog;

			if(!exists(filePath))
			{
				debugLog("Error: Map <",filePath,"> does not exist");
				return null;
			}
			MapComponent mc;
			ubyte[] data = cast(ubyte[])read(filePath);
			
			// verify validity of data
			if(data[0..3] != [0x4d,0x41,0x50]) debugLog("Warning: wrong header: ",cast(string)data[0..3]);
			size_t w = data[0x8], h = data[0xc];
			size_t length = data[0x10..$].length;

			if(length != w*h*2)
			{
				debugLog("Error: Map data of length ",length/2," does not match size ",w,"x",h);
				return null;
			}
			ubyte[] processedData = new ubyte[w*h];
			foreach(i; 0..w*h)
			{
				processedData[i] = data[i*2+0x10];
			}
			mc = create(cast(ubyte)w,cast(ubyte)h,processedData);
			return mc;
		}

		/// PS1 maps: surf-only, and it has different surf IDs than the PC version
		static MapComponent loadPS1Map(string filePath)
		{
			import std.file;
			import std.stdio : writeln;
			import main : debugLog;
			
			if(!exists(filePath))
			{
				debugLog("Error: Map <",filePath,"> does not exist");
				return null;
			}
			MapComponent mc;
			ubyte[] data = cast(ubyte[])read(filePath);
			
			// verify validity of data
			if(data[0..3] != [0x4d,0x41,0x50]) debugLog("Warning: wrong header: ",cast(string)data[0..3]);
			size_t w = data[0x8], h = data[0xc];
			size_t length = data[0x10..$].length;
			
			if(length != w*h*2)
			{
				debugLog("Error: Map data of length ",length/2," does not match size ",w,"x",h);
				return null;
			}
			ubyte[] processedData = new ubyte[w*h];
			foreach(i; 0..w*h)
			{
				/// this is where the PS1 data gets converted to PC format.
				ubyte orig = data[i*2+0x10];
				ubyte processed = 5;
				switch(orig)
				{
					case 2:
						processed = 4;
						break;
					case 3:
						processed = 3;
						break;
					case 4:
						processed = 2;
						break;
					case 5:
						processed = 1;
						break;
					case 6:
						processed = 6;
						break;
					case 7:
						processed = 9;
						break;
					default:
						break;
				}
				processedData[i] = processed;
			}
			mc = create(cast(ubyte)w,cast(ubyte)h,processedData);
			return mc;
		}

		public static MapComponent create(ubyte width, ubyte height, in ubyte[] mapData)
		{
			if(mapData.length == width*height)
			{
				return new MapComponent(width,height,mapData);
			}
			else return null;
		}

		protected this(ubyte width, ubyte height, in ubyte[] mapData)
		{
			w = width;
			h = height;
			data = mapData.dup;
		}

		public static MapComponent create(ubyte width, ubyte height, ubyte singleValue)
		{
			return new MapComponent(width,height,singleValue);
		}

		protected this(ubyte width, ubyte height, ubyte singleValue)
		{
			w = width;
			h = height;
			data = new ubyte[w*h];
			data[] = singleValue;
		}

		public ubyte[] bytes()
		{
			ubyte[] ret = [0x4D,0x41,0x50,0x20,0x28,0x1C,00,00,cast(ubyte)w,00,00,00,cast(ubyte)h,00,00,00];
			// simplifying: size as ubyte (need to fix if allowing maps larger than 256x256)
			foreach(ubyte v; data)
			{
				ret ~= v;
				ret ~= 00;
			}
			return ret;
		}

	}

	public static class TerrainMesh : Mesh!(false)
	{
		MeshSort sort;

		mat4 M = mat4.identity;
		//ushort[] tris; // fake tri element array; used when adding to convert to non-indexed array and create normals

		/// empty this mesh for reuse
		void recycle()
		{
			verts = null;
			uvs = null;
			normals = null;
			tris = null;

			Update();
		}

		void deindex()
		{
			// translate verts using matrix
			foreach(i; 0..verts.length)
			{
				verts[i] = vec3(M*vec4(verts[i],1));
			}

			verts = [verts[tris[0]],verts[tris[1]],verts[tris[2]],verts[tris[3]],verts[tris[4]],verts[tris[5]]];
			uvs = [uvs[tris[0]],uvs[tris[1]],uvs[tris[2]],uvs[tris[3]],uvs[tris[4]],uvs[tris[5]]];
			
			// new normals
			vec3 norm1 = cross((verts[0]-verts[1]),(verts[1]-verts[2]));
			if(norm1.z < 0) norm1 = -1*norm1;
			vec3 norm2 = cross(verts[3]-verts[4],verts[4]-verts[5]);
			if(norm2.z < 0) norm2 = -1*norm2;
			normals = [norm1,norm1,norm1,norm2,norm2,norm2];

			M = mat4.identity;
		}

		void add(TerrainMesh a)
		{
			if(verts is null) verts = new vec3[0];
			//if(tris is null) tris = new ushort[0];

			verts~=a.verts;
			uvs~=a.uvs;
			normals~=a.normals;
		}

		/// deindexes and then properly updates indexed tile meshes
		void UpdateIndexed()
		{
			deindex();
			Update();
		}
	}

	/// normalizes an integer ROTATION (by) to the range 0..max
	public static nothrow uint normalize(int by, int max = 4)
	{
		while(by >= max)
		{
			by -= max;
		}
		while(by < 0)
		{
			by += max;
		}
		return cast(uint)by;
	}

	/// normalizes a float to the range 0f..max
	public static nothrow float normalize(float by, float max = 2*std.math.PI)
	{
		while(by >= max)
		{
			by -= max;
		}
		while(by < 0)
		{
			by += max;
		}
		return by;
	}

	public static struct Match
	{
		ubyte[8] matches;
		string visual() @property { return "["~StoC[matches[0]]~StoC[matches[1]]~StoC[matches[2]]~"/"~StoC[matches[3]]~"."~StoC[matches[4]]~"/"~StoC[matches[5]]~StoC[matches[6]]~StoC[matches[7]]~"]"; }
		string visualML() @property { return "["~StoC[matches[0]]~StoC[matches[1]]~StoC[matches[2]]~"\n "~StoC[matches[3]]~"."~StoC[matches[4]]~"\n "~StoC[matches[5]]~StoC[matches[6]]~StoC[matches[7]]~"]"; }

		/*public this(ref ubyte[8] input)
		{
			matches = input;
		}*/


		/*public ubyte[8] rot1() @property
		{
			return matches[7,6,5,4,3,2,1,0];
		}*/

		private ubyte[8] slice(uint[8] indexes)
		{
			ubyte[8] ret;
			foreach(uint i; 0..8)
			{
				ret[i] = matches[indexes[i]];
			}
			return ret;
		}

		public Match rotate(int by)
		{
			uint normal = normalize(by,4);
			const uint[8] rot1 = [5,3,0,6,1,7,4,2], rot2 = [7,6,5,4,3,2,1,0], rot3 = [2,4,7,1,6,0,3,5];
			switch(normal)
			{
				case 1:
					return Match(slice(rot1));
				case 2:
					return Match(slice(rot2));
				case 3:
					return Match(slice(rot3));
				default:
					return this;
			}
		}

		/// Returns the rotation of matchTemplate that fits this Match, or ubyte.max if none fit
		public ubyte compare(Match matchTemplate)
		{
			//byte ret = -1;
			Match temp;
			foreach(ubyte rotation; 0..4)
			{
				temp = matchTemplate.rotate(rotation);
				if(this == temp) return rotation;
			}
			return ubyte.max;
		}

		bool opEquals()(auto ref const Match m) const
		{
			bool[8] c = true;
			foreach(uint i; 0..8)
			{
				c[i] = compare(matches[i],m.matches[i]);
			}
			return c[0]&&c[1]&&c[2]&&c[3]&&c[4]&&c[5]&&c[6]&&c[7];
		}

		private bool compare()(auto ref const ubyte a, auto ref const ubyte b) const
		{
			if(a > mEither || b > mEither)
				return false;
			if(a == mEither || b == mEither)
				return true;
			if(a == b)
				return true;
			return false;
		}

	}



	const ubyte mGround = 0, mWall = 1, mEither = 2;
	string StoC = "_x*";

	/// match templates
	///              0          1          2          3          4
	///             straight   corner     inner      between    ceiling
	///  0  1  2    x  x  x    x  x  *    x  x  x    x  x  _    x  x  x
	///  3  .  4    x  .  x    x  .  _    x  .  x    x  .  x    x  .  x
	///  5  6  7    *  _  *    *  _  *    x  x  _    _  x  x    x  x  x
	static Match[5] matchTemplates = [
		Match([1,1,1,1,1,2,0,2]),
		Match([1,1,2,1,0,2,0,2]),
		Match([1,1,1,1,1,1,1,0]),
		Match([1,1,0,1,1,0,1,1]),
		Match([1,1,1,1,1,1,1,1]) ];


	static const float[4] rotF = [0f,std.math.PI/2f,std.math.PI,std.math.PI*1.5f];
	static const mat4[4] rotM = [mat4.zrotation(0f),mat4.zrotation(std.math.PI/2f),mat4.zrotation(std.math.PI),mat4.zrotation(std.math.PI*1.5f)];


	/// surf IDs of all types that are walls and should be drawn as walls (everything else is always drawn as flat ground)
	uint[] wallTypes = [1,2,3,4,8,10,11];
	ushort[] triLayout0 = [0,1,3,1,2,3];
	ushort[] triLayout1 = [0,1,2,0,2,3];




	/// automatically load other map components if they are null?
	bool autoLoad = true;

	/// automatically overwrite without asking?
	bool autoOverwrite = false;

	/// CREATE function -- blank map
	bool create(ubyte width, ubyte height, Type type = Type.solid, ubyte elevation = 8)
	{
		close();
		tiles = new Tile[width*height];
		w = width;
		h = height;

		foreach(x; 0..w) foreach(y; 0..h)
		{
			Map[x,y].type = type;
			Map[x,y].height = elevation;
			if(type == Type.erosion) Map[x,y].erodeSpeed = 1;
		}

		buildMeshes();
		sortMeshes();

		updateSurfMapImage();
		updateHighMapImage();

		cameraPos = vec2(w*0.5f,h*0.5f);
		updateMatrix();

		return true;
	}

	/// SET function -- convert from MapComponents to Tile format
	bool set(MapComponent[(EnumMembers!FileType).length] mapComponents)
	{
		/// if map is blank, create it
		if(tiles is null || w==0 || h==0)
		{
			foreach(const FileType f; EnumMembers!FileType)
			{
				if(mapComponents[f] is null || mapComponents[f].w == 0 || mapComponents[f].h == 0) continue;
				w = mapComponents[f].w;
				h = mapComponents[f].h;
				break;
			}
			if(w==0 || h==0) return false;
			tiles = new Tile[w*h];
		}

		/// validate each one, and also fill in blank ones with default
		foreach(const FileType f; EnumMembers!FileType)
		{
			if(mapComponents[f] !is null && mapComponents[f].w == w && mapComponents[f].h == h) continue;
			const bool defaultVal = (f == FileType.surf)?1:0; // surf default is solid rock, not "ground"
			mapComponents[f] = MapComponent.create(w,h,defaultVal);
		}
		
		/// conversion of LRR-type data into new Tile[] format
		foreach(uint y; 0..h) foreach(uint x; 0..w)
		{
			uint i = x+w*y;
			Tile* t = Map[x,y];
			t.height = mapComponents[FileType.high][x,y];
			t.emerge = mapComponents[FileType.emrg][x,y];
			t.height = mapComponents[FileType.high][x,y];
			t.tutorial = mapComponents[FileType.tuto][x,y];
			t.landslide = mapComponents[FileType.fall][x,y];
			
			t.cryore = mapComponents[FileType.cror][x,y];
			/+t.crystals = Tile.crystalValues.get(cryore,0);
			t.ore = Tile.oreValues.get(cryore,0);+/
			
			ubyte erod = mapComponents[FileType.erod][x,y];
			t.erodeSpeed = erod;
			if(t.erodeSpeed&1u) t.erodeSpeed += 1u; // normalize so even and odd are same (only magnitude here)
			if(t.erodeSpeed!=0) t.erodeSpeed /= 2u;
			
			ubyte path = mapComponents[FileType.path][x,y];
			ubyte dugg = mapComponents[FileType.dugg][x,y];
			ubyte surf = mapComponents[FileType.surf][x,y];
			
			if(dugg==1 || dugg==2) // exposed ground, could be any type
			{
				if(surf==6)
				{
					t.type = Type.lava;
				}
				else if(surf==9)
				{
					t.type = Type.water;
				}
				else if(path==2)
				{
					t.type = Type.path;
				}
				else if(path==1)
				{
					t.type = Type.rubble;
				}
				else // ground or erosion
				{
					if((erod!=0) && !(erod&1u)) // non-zero even erod: erosion-start block here
					{
						t.type = Type.erosion;
					}
					else
					{
						t.type = Type.ground;
					}
				}
				t.hidden = dugg==2;
			}
			else if(dugg==3 || dugg==4) // exposed slug
			{
				t.type = Type.slug;
				t.hidden = dugg == 4;
			}
			else // finally: actual terrain from the surf map
			{
				if(surf < Tile.surfValues.length) t.type = Tile.surfValues[surf];
				else t.type = Type.ground;
			}
			
		}

		// Validate map and rebuild mesh if valid (Map.isMeshBuilt is updated to true or false)
		buildMeshes();
		sortMeshes();

		updateSurfMapImage();
		updateHighMapImage();

		return true;
	}

	/// LOAD functions -- these will load the map (or do nothing if unsuccessful). will handle auto-loading of other maps.
	/// takes an array of filepaths and loads the ones that can be matched to a map component type (surf, high, etc.).
	bool load(in string[] mapPaths)
	{
		if(tiles is null || w==0 || h==0)
		{
			return loadNew(mapPaths);
		}
		else
		{
			return loadAdd(mapPaths);
		}
	}

	bool loadNew(in string[] mapPaths)
	{
		import std.file : exists;
		import std.algorithm.searching : canFind, find, findSplit;
		import std.range : retro;
		import std.uni : toLower;
		import std.conv : text;
		import main : savePathString, saveINI, pSurfM, pHighI, pHighM, debugLog;
		import std.conv : text;

		uint w = 0, h = 0;

		const size_t fileTypeNum = (EnumMembers!FileType).length;
		MapComponent[fileTypeNum] mapComponents;
		bool empty = true;
		string[2][] loaded; // store successfully loaded map paths for auto-loading


		foreach(s; mapPaths)
		{
			if(!exists(s)) continue;
			foreach(const FileType f; EnumMembers!FileType)
			{
				if(mapComponents[f] !is null) continue; // don't test for maps that have already been loaded
				const string fPred = text(f);
				// if doesn't match predicate, continue
				bool foundPred = canFind!((a,b)=>(toLower(a)==toLower(b)))(s,fPred);
				if(!foundPred) continue;

				debug std.stdio.writeln("predicate <",fPred,"> found in <",s,">");

				MapComponent mc = MapComponent.loadMap(s);
				if(mc is null)
				{
					string mapmsg = fPred~" map "~std.path.baseName(s)~" could not be loaded.";
					debugLog(mapmsg);
					dlgMsg(mapmsg);
					continue;
				}
				else if((w!=0 && mc.w!=w) || (h!=0 && mc.h!=h))
				{
					string mapmsg = fPred~" map "~std.path.baseName(s)~" ("~text(mc.w)~","~text(mc.h)~") doesn't have the correct size ("~text(w)~","~text(h)~").";
					debugLog(mapmsg);
					dlgMsg(mapmsg);
					continue;
				}
				else
				{
					//surf = mc;
					empty = false;
					mapComponents[f] = mc;
					if(autoLoad)
					{
						auto split = findSplit!((a,b)=>(toLower(a)==toLower(b)))(s.retro, fPred.retro);
						loaded ~= [text(text(split[2]).retro),text(text(split[0]).retro)]; 	// still not sure why split::Result doesn't work with retro; isn't it also a range?
																				// ^ NOTE: strings are NOT random access ranges due to variable-length encoding, thus no retro on the return result.
						debug std.stdio.writeln("Adding ",s.retro," = ",split[0]," ~ ",split[2]);
					}
					break; // don't test this file for any of the other filetype predicates
				}
			}
		}

		if(empty) return false; // none of them existed and loaded properly

		if(autoLoad)
		{
			foreach(const FileType f; EnumMembers!FileType)
			{
				if(mapComponents[f] !is null) continue; // don't test for maps that have already been loaded
				const string fPred = text(f);
				foreach(string[2] l; loaded)
				{
					string replacement = l[0]~fPred~l[1];

					if(exists(replacement))
					{
						MapComponent mc = MapComponent.loadMap(replacement);
						if(mc is null)
						{
							// no need to show error on autoload, since user didn't pick this map. just ignore it
							continue;
						}
						else if((w!=0 && mc.w!=w) || (h!=0 && mc.h!=h))
						{
							continue;
						}
						else
						{
							mapComponents[f] = mc;
						}
					}
				}

			}
		}

		return set(mapComponents);
	}

	/// Import into currently open map
	bool loadAdd(in string[] mapPaths)
	{
		import std.traits : EnumMembers;
		import std.file : exists;
		import std.algorithm.searching : canFind, find, findSplit;
		import std.range : retro;
		import std.uni : toLower;
		import std.conv : text;
		import main : savePathString, saveINI, pSurfM, pHighI, pHighM, debugLog;
		import std.conv : text;

		uint w = Map.w, h = Map.h;
		
		const uint fileTypeNum = (EnumMembers!FileType).length;
		MapComponent[fileTypeNum] mapComponents = getMapComponents();
		bool empty = true;
		//string[2][] loaded; // store successfully loaded map paths for auto-loading
		
		
		foreach(s; mapPaths)
		{
			if(!exists(s)) continue;
			foreach(const FileType f; EnumMembers!FileType)
			{
				const string fPred = text(f);
				// if doesn't match predicate, continue
				bool foundPred = canFind!((a,b)=>(toLower(a)==toLower(b)))(s,fPred);
				if(!foundPred) continue;
				
				debug std.stdio.writeln("predicate <",fPred,"> found in <",s,">");
				
				MapComponent mc = MapComponent.loadMap(s);
				if(mc is null)
				{
					string mapmsg = fPred~" map "~std.path.baseName(s)~" could not be loaded.";
					debugLog(mapmsg);
					dlgMsg(mapmsg);
					continue;
				}
				else if((w!=0 && mc.w!=w) || (h!=0 && mc.h!=h))
				{
					string mapmsg = fPred~" map "~std.path.baseName(s)~" ("~text(mc.w)~","~text(mc.h)~") doesn't have the correct size ("~text(w)~","~text(h)~").";
					debugLog(mapmsg);
					dlgMsg(mapmsg);
					continue;
				}
				else
				{
					//surf = mc;
					empty = false;
					mapComponents[f] = mc;
					/+if(autoLoad)
					{
						auto split = findSplit!((a,b)=>(toLower(a)==toLower(b)))(s.retro, fPred.retro);
						loaded ~= [text(text(split[2]).retro),text(text(split[0]).retro)]; 	// still not sure why split::Result doesn't work with retro; isn't it also a range?
						// ^ NOTE: strings are NOT random access ranges due to variable-length encoding, thus no retro on the return result.
						std.stdio.writeln("Adding ",s.retro," = ",split[0]," ~ ",split[2]);
					}+/
					break; // don't test this file for any of the other filetype predicates
				}
			}
		}
		
		if(empty) return false; // none of them existed and loaded properly
		
		/+if(autoLoad)
		{
			foreach(const FileType f; EnumMembers!FileType)
			{
				if(mapComponents[f] !is null) continue; // don't test for maps that have already been loaded
				const string fPred = text(f);
				foreach(string[2] l; loaded)
				{
					string replacement = l[0]~fPred~l[1];
					
					if(exists(replacement))
					{
						MapComponent mc = MapComponent.loadMap(replacement);
						if(mc is null)
						{
							// no need to show error on autoload, since user didn't pick this map. just ignore it
							continue;
						}
						else if((w!=0 && mc.w!=w) || (h!=0 && mc.h!=h))
						{
							continue;
						}
						else
						{
							mapComponents[f] = mc;
						}
					}
				}
				
			}
		}+/
		
		return set(mapComponents);
	}


	/// save all map components; exportPath should be one of the components, *appropriately named*, from which the other names will be generated.
	bool save(in string s)
	{
		import std.traits : EnumMembers;
		import std.file : exists, write, rename;
		import std.path : baseName;
		import std.algorithm.searching : canFind, find, findSplit;
		import std.range : retro;
		import std.uni : toLower;
		import std.conv : text;
		import main : savePathString, saveINI, pSurfM, pHighI, pHighM, debugLog;
		import std.conv : text;
		
		if(w==0 || h==0 || tiles is null) return false;
		
		const uint fileTypeNum = (EnumMembers!FileType).length;
		string[fileTypeNum] files;
		//MapComponent[fileTypeNum] mapComponents;
		bool empty = true;

		bool foundPred = false;
		FileType foundType;

		foreach(const FileType f; EnumMembers!FileType)
		{
			const string fPred = text(f);
			foundPred = canFind!((a,b)=>(toLower(a)==toLower(b)))(s,fPred);
			if(foundPred)
			{
				foundType = f;
				break;
			}
		}
		if(!foundPred)
		{
			string mapmsg = "Filename <"~s.baseName~"> is invalid; it should contain one of the map type names (\"surf\"/\"high\"/etc.)";
			debugLog(mapmsg);
			dlgMsg(mapmsg);
			return false;
		}

		auto split = findSplit!((a,b)=>(toLower(a)==toLower(b)))(s.retro, text(foundType).retro); // this is why I don't like auto
		string[2] exportPathSplit = [text(text(split[2]).retro),text(text(split[0]).retro)];
		foreach(const FileType f; EnumMembers!FileType)
		{
			const string fPred = text(f);
			files[f] = exportPathSplit[0]~fPred~exportPathSplit[1];
		}

		/// create all the MapComponents and save them to file
		foreach(const FileType f; EnumMembers!FileType)
		{
			const string fn = files[f];
			if(exists(fn))
			{
				if(!autoOverwrite) // && no
				{
					bool response = dlgMsg("Map <"~fn.baseName~"> already exists.\nWould you like to overwrite it?","Overwrite?",true);
					if(!response) continue;
				}

				rename(fn,fn~".bak");
			}
			MapComponent mc = getMapComponent!f();
			write(fn,mc.bytes);
		}
		
		return true;
	}

	/// close the currently opened maps
	void close()
	{
		tiles = null;
		w = 0;
		h = 0;
	}

	/// TODO: add static arrays for mouseOverTile's updateCoords and main loop's hover so that no allocation needs to happen (other than with the fill brush)

	/// modify the tile using the UI's current settings and the mouseclick info in mb, then return whether this tile needs to be updated
	bool mouseOverTile(vec2ui clicked, ubyte mb)
	{
		import ui;
		import imgui.api : MouseButton;
		import std.algorithm.searching : canFind;

		vec2ui[] updateCoords = [];

		//UI.pickedCoord.x >= 0 && UI.pickedCoord.x < (Map.mapSize.x) && UI.pickedCoord.y >= 0 && UI.pickedCoord.y < (Map.mapSize.y)
		
		if(UI.mapMode == 0) // TERRAIN mode (select whole square tiles starting from center of tile)
		{
			/// SELECT the stuff to be edited
			if(UI.editBrush == 0) // square brush
			{
				//Map.highlights = [vec2ui(UI.pickedCoord.x, UI.pickedCoord.y) ];
				foreach(vec2i v; Map.brushesSquare[min(6,(cast(uint)UI.editBrushSize)-1)])
				{
					vec2ui nv = vec2ui(clicked.x + v.x, clicked.y + v.y);
					if(Map.validCoord(nv)) Map.highlights ~= nv;
				}
			} // end square brush
			else if(UI.editBrush == 2) // fill
			{
				/// fill is too slow to use for the preview shading.
				/++if(Map.brushFill is null || Map.brushFill[0] != vec2ui(UI.pickedCoord.x,UI.pickedCoord.y))
					{
						Map.fill(vec2ui(UI.pickedCoord.x,UI.pickedCoord.y));
					}

					if(Map.brushFill is null)
					{
						// null - fill is invalid, so do not highlight or allow clicking
						Map.highlights = null;
					}
					else
					{}+/
				///Map.highlights = Map.brushFill;
				
				if(Map.highlights is null || Map.highlights.length != 1)
				{
					Map.highlights = [ clicked ];
				}
				else
				{
					// exists and is length 1 -- don't reallocate
					Map.highlights[0] = clicked;
				}
			} // end fill brush


			/// EDIT the stuff
			if((mb & MouseButton.left)||(mb & MouseButton.right))
			{
				if(UI.editBrush == 2) fill(clicked);
				// clicked on a terrain tile
				foreach(vec2ui v; (UI.editBrush==0)?Map.highlights:Map.brushFill)
				{
					if(v.x >= Map.w-1 || v.y >= Map.h-1) continue;
					if(UI.editTerrainMode==0) // terrain type
					{
						Type editType = (mb & MouseButton.left)?(UI.editType):(Type.ground); // right-click places ground
						if(Map[v.x, v.y].type != editType)
						{
							Map[v.x,v.y].type = editType;
							if(editType == Type.erosion && Map[v.x,v.y].erodeSpeed == 0) Map[v.x,v.y].erodeSpeed = 1;
							else if(Map[v.x,v.y].hidden && ((!Tile.isGround(editType)) || editType == Type.path || editType == Type.rubble)) Map[v.x,v.y].hidden = false;
							if(!updateCoords.canFind(v)) updateCoords ~= v;
							foreach(vec2ui coord; Map.neighbors(v.x,v.y)) if(!updateCoords.canFind(coord)) updateCoords ~= coord;
						}
					}
					else if(UI.editTerrainMode==1) // erode speed
					{
						ubyte editErodeSpeed = (mb & MouseButton.left)?(clamp(cast(ubyte)UI.editErodeSpeed,cast(ubyte)0,cast(ubyte)5)):(cast(ubyte)0);
						if(Map[v.x, v.y].erodeSpeed != editErodeSpeed)
						{
							Map[v.x,v.y].erodeSpeed = editErodeSpeed;
							if(!updateCoords.canFind(v)) updateCoords ~= v;
							if(Map[v.x,v.y].type == Type.erosion && editErodeSpeed == 0)
							{
								Map[v.x,v.y].type = Type.ground;
								foreach(vec2ui coord; Map.neighbors(v.x,v.y)) if(!updateCoords.canFind(coord)) updateCoords ~= coord; // only need to update neighbors if changing type
							}
						}
					}
					else if(UI.editTerrainMode==2) // hidden caverns
					{
						bool editHidden = (mb & MouseButton.left)?(UI.editHidden):(!UI.editHidden);
						if(Tile.isGround(Map[v.x, v.y].type) && Map[v.x, v.y].hidden != editHidden) // completely ignore non-ground types
						{
							Map[v.x,v.y].hidden = editHidden;
							if(!updateCoords.canFind(v)) updateCoords ~= v;
							if(editHidden == true && (Map[v.x,v.y].type == Type.path || Map[v.x, v.y].type == Type.rubble)) // rubble and path can't be hidden, so delete them
							{
								Map[v.x,v.y].type = Type.ground;
							}
						}
					}
				}
			} // end leftclick
			
			if(updateCoords.length > 0)
			{
				foreach(vec2ui u; updateCoords)
				{
					Map.buildMesh(u.x,u.y);
				}
				
				Map.sortMeshes();
				Map.updateSurfMapImage();
			}
		} // end surf mode
		else if(UI.mapMode == 1) // high mode
		{
			if(UI.editBrush == 0)
			{
				//Map.highlights = [vec2ui(UI.pickedCoord.x, UI.pickedCoord.y) ];
				foreach(vec2i v; Map.brushesSquare[min(6,(cast(uint)UI.editBrushSize)-1)])
				{
					vec2ui nv = vec2ui(clicked.x + v.x, clicked.y + v.y);
					if(Map.validCoord(nv)) Map.highlights ~= nv;
				}
				
				if(mb)
				{
					// clicked on a terrain tile // && UI.editSurf < 10
					
					if((UI.editHeightMode == 0) && (mb&MouseButton.left)) // set mode (ignore rightclicks)
					{
						ubyte editHeight = cast(ubyte)(UI.editSetHeight+0.1f);
						
						foreach(vec2ui v; Map.highlights)
						{
							//if(v.x == Map.w || v.y == Map.h) continue;
							if(Map[v.x, v.y].height != editHeight)
							{
								// setting new height
								Map[v.x,v.y].height = editHeight;
								// update mesh and neighbors, then sort and update map
								//Map.buildMesh(v.x,v.y);
								if(!updateCoords.canFind(v)) updateCoords ~= v;
								foreach(vec2ui coord; Map.neighborsHigh(v.x,v.y)) // high map version
								{
									if(!updateCoords.canFind(coord)) updateCoords ~= coord;
								}
							}
						}
					} // end set mode
					else if((UI.editHeightMode == 1 || UI.editHeightMode == 2)&&((mb&MouseButton.right) || (mb&MouseButton.left))) // decrease or increase
					{
						bool decrease = (UI.editHeightMode == 1);
						if(mb&MouseButton.right) decrease = !decrease;
						foreach(vec2ui v; Map.highlights)
						{
							// increase or decrease height
							Map[v.x,v.y].height = cast(ubyte)(decrease?(max(0,Map[v.x,v.y].height-1)):(min(63,Map[v.x,v.y].height+1)));
							// update mesh and neighbors, then sort and update map
							//Map.buildMesh(v.x,v.y);
							if(!updateCoords.canFind(v)) updateCoords ~= v;
							foreach(vec2ui coord; Map.neighborsHigh(v.x,v.y)) // high map version
							{
								if(!updateCoords.canFind(coord)) updateCoords ~= coord;
							}
						}
					}
				} // end click
			} // end square brush
			
			if(updateCoords.length > 0)
			{
				foreach(vec2ui u; updateCoords)
				{
					if(u.x > 0 && u.y > 0)
					{
						
					}
					if(u.x == Map.w-1 || u.y == Map.h-1) continue; // skip building of invisible edges
					Map.buildMesh(u.x,u.y);
				}
				
				Map.sortMeshes();
				Map.updateHighMapImage();
			}
		} // end high mode
		
		return true;
	}

	// create a MapComponent (LRR binary format) from the current map; template version
	MapComponent getMapComponent(FileType f)()
	{
		MapComponent c = MapComponent.create(w,h,0);
		foreach(x; 0..w) foreach(y; 0..h)
		{
			c[x,y] = Map[x,y].toLRR!f();
		}
		return c;
	}

	MapComponent[(EnumMembers!FileType).length] getMapComponents()
	{
		MapComponent[(EnumMembers!FileType).length] mcs;
		foreach(const FileType f; EnumMembers!FileType)
		{
			mcs[f] = getMapComponent!f();
		}
		return mcs;
	}

	bool loadPS1TerrainMap(string mapPath)
	{
		import std.file : exists;
		import main : savePathString, saveINI, pSurfM, pHighI, pHighM;

		MapComponent[(EnumMembers!FileType).length] mcs;
		if(tiles is null || w==0 || h==0) mcs = getMapComponents();

		mcs[FileType.surf] = MapComponent.loadPS1Map(mapPath);
		
		if(mcs[FileType.surf] is null)
		{
			string mapmsg = "Map "~std.path.baseName(mapPath)~" could not be loaded.";
			dlgMsg(mapmsg);
			return false;
		}
		else
		{
			set(mcs);
			updateSurfMapImage();
			return true;
		}
	}




	bool saveHighImage(string mapPath)
	{
		import std.file : exists, write, rename;
		import std.path : baseName;
		
		if(tiles is null)
			return false;
		
		if(exists(mapPath))
			rename(mapPath,mapPath~".bak");


		ubyte[] data = new ubyte[w*h*3];
		
		foreach(uint oy; 0..h)
		{
			uint y = h - oy - 1;
			foreach(uint x; 0..w)
			{
				// TODO: add custom surf radar color loading from file
				ubyte heightByte = (Map[x,oy].height >= 64)?255:cast(ubyte)(Map[x,oy].height*4);
				data[3*(x+w*y)] = heightByte;
				data[3*(x+w*y)+1] = heightByte;
				data[3*(x+w*y)+2] = heightByte;
			}
		}
		
		uint ilTemp = ilGenImage();
		ilBindImage(ilTemp);
		ilTexImage(w, h, 1, 3, IL_RGB, IL_UNSIGNED_BYTE, data.ptr);
		ilSaveImage(std.string.toStringz(mapPath));
		ilDeleteImage(ilTemp);
		
		return true;
	}

}

