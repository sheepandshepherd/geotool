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

module mesh;

import derelict.opengl3.gl3;
import gl3n.linalg, util.linalg;
import glamour.vbo : Buffer, ElementBuffer;

class Mesh(bool element = true)
{
	Buffer vertbuffer, uvbuffer, normalbuffer;
	static if(element) ElementBuffer tribuffer;
	vec3[] verts;
	//float[] vertsF() @property { float[] ret = new float[3*verts.length]; foreach(uint i; 0..verts.length) ret[i*3..i*3+3] = verts[i].vector[0..3]; return ret; }
	vec3[] normals;
	vec3[] uvs;
	ushort[] tris;
	
	void Update()
	{
		/// Unload(); /// 6 Aug 2015: recycle buffers instead of destroying and remaking them.
		if(vertbuffer is null) vertbuffer = new Buffer(verts.ptr,cast(uint)verts.length*3u*float.sizeof);
		else vertbuffer.set_data(verts.ptr,cast(uint)verts.length*3u*float.sizeof);

		if(uvbuffer is null) uvbuffer = new Buffer(uvs.ptr,cast(uint)uvs.length*3u*float.sizeof);
		else uvbuffer.set_data(uvs.ptr,cast(uint)uvs.length*3u*float.sizeof);

		if(normalbuffer is null) normalbuffer = new Buffer(normals.ptr,cast(uint)normals.length*3u*float.sizeof);
		else normalbuffer.set_data(normals.ptr,cast(uint)normals.length*3u*float.sizeof);
		static if(element)
		{
			if(tribuffer is null) tribuffer = new ElementBuffer(tris.ptr,cast(uint)tris.length*ushort.sizeof);
			else tribuffer.set_data(tris.ptr,cast(uint)tris.length*ushort.sizeof);
		}
	}

	void Unload()
	{
		if(vertbuffer !is null){vertbuffer.remove(); vertbuffer = null;}
		if(uvbuffer !is null){uvbuffer.remove(); uvbuffer = null;}
		if(normalbuffer !is null){normalbuffer.remove(); normalbuffer = null;}
		static if(element) tribuffer.remove();
	}
	
	this()
	{

	}
	~this()
	{
		// need to call Unload separately -- GC destructor may be called after OpenGL is released.
		//Unload();
	}
	
	this(vec3[] _verts, ushort[] _tris, vec3[] _uvs = null, vec3[] _normals = null)
	{
		verts = _verts;
		tris = _tris;
		if(_uvs !is null) uvs = _uvs;
		if(_normals !is null) normals = _normals;
	}
	
	/+this(string filePath)
	{
		import derelict.assimp3.assimp, util.assimp;
		const aiScene* scene = aiImportFile(std.string.toStringz(filePath),aiProcess_CalcTangentSpace | aiProcess_Triangulate);
		verts = new vec3[scene.mMeshes[0].mNumVertices];
		uvs = new vec3[scene.mMeshes[0].mNumVertices];
		foreach(uint v; 0..scene.mMeshes[0].mNumVertices)
		{
			verts[v] = scene.mMeshes[0].mVertices[v].toVec3;
			uvs[v] = scene.mMeshes[0].mTextureCoords[0][v].toVec3;
		}
		tris = new ushort[3*scene.mMeshes[0].mNumFaces];
		foreach(uint t; 0..scene.mMeshes[0].mNumFaces)
		{
			tris[3*t] = cast(short)scene.mMeshes[0].mFaces[t].mIndices[0];
			tris[3*t+1] = cast(short)scene.mMeshes[0].mFaces[t].mIndices[1];
			tris[3*t+2] = cast(short)scene.mMeshes[0].mFaces[t].mIndices[2];
		}
		
		
	}+/
	

}