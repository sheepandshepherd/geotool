/*
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
*/

#version 130

vertex:
in vec3 vPos;

out vec3 pos;

uniform mat4 MVP;

void main(){
	gl_Position =  MVP*vec4(vPos.x,vPos.y,-vPos.z,1);
	pos = vec3(vPos.x,vPos.y,-vPos.z);
}

fragment:
in vec3 pos;

uniform vec4 color;

out vec4 fragColor;

void main()
{
	fragColor.a = color.a;
	fragColor.rgb = color.rgb;
}