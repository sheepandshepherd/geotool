/+
This file is part of GeoTool, a map viewer/editor for Lego Rock Raiders.
Copyright (C) 2014-2017  sheepandshepherd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
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
