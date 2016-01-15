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

module util.linalg;

public import gl3n.linalg;


public alias Vector!(short,2) vec2s;

public alias Vector!(uint, 2) vec2ui;

public alias Vector!(ubyte,3) vec3ub;
public vec3ub v3ub(int x, int y, int z){return vec3ub(cast(ubyte)x,cast(ubyte)y,cast(ubyte)z);}


/// intersect - implementation of Möller-Trumbore ray/triangle intersection
/// Möller, T. and Trumbore, B.  "Fast, Minimum Storage Ray/Triangle Intersection" Journal of Graphics Tools 1997.
/// http://www.cs.virginia.edu/~gfx/Courses/2003/ImageSynthesis/papers/Acceleration/Fast%20MinimumStorage%20RayTriangle%20Intersection.pdf
/// returns: distance to intersection if intersection found, otherwise float.nan
float intersect(vec3 origin, vec3 direction, in vec3[] tri)
{
	origin.z = -origin.z;
	direction.z = -direction.z;
	vec3 e0, e1, pv, qv, tv;
	float det, invDet, u, v, t;

	e0 = tri[1]-tri[0];
	e1 = tri[2]-tri[0];
	pv = direction.cross(e1);
	det = e0.dot(pv);
	if(det > -float.epsilon && det < float.epsilon) return float.nan;
	invDet = 1f/det;
	tv = origin-tri[0];
	u = tv.dot(pv) * invDet;
	if(u < 0f || u > 1f) return float.nan;

	qv = tv.cross(e0);
	v = direction.dot(qv) * invDet;
	if(v < 0f || u+v > 1f) return float.nan;

	t = e1.dot(qv) * invDet;
	if(t > float.epsilon)
	{
		return t;
	}
	return float.nan;
}

public float[] matrixFlat(mat4 m)
{
	float[] ret = new float[16];
	foreach(uint i; 0..16)
	{
		ret[i] = m.value_ptr[i];
	}
	return ret;
}

public vec3 matMult(mat4 m, vec3 v)
{
	return vec3(m*vec4(v,1));
}

float angle(vec3 v1, vec3 v2)
{
	import std.math;
	v1.normalize;
	v2.normalize;
	float angle = acos(dot(v1, v2));
	return angle;
}
