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
in vec3 vUV; // z = color index, or -1 if textured, or 70 if ceiling
in vec3 vNorm;

out vec3 pos;
out vec3 uv;
out vec3 norm;

uniform mat4 MVP;

void main(){
	gl_Position =  MVP*vec4(vPos.x,vPos.y,-vPos.z,1);
	norm = normalize( vec3(vNorm.x,vNorm.y,vNorm.z) );
	pos = vec3(vPos.x,vPos.y,-vPos.z);
	uv = vUV.xyz; //vec3(vUV.xy,distance(vec3((M*vec4(lightPos,0,1)).xy,0),vec3(vPos.xy,0)));
	
}

fragment:
in vec3 pos;
in vec3 uv;
in vec3 norm;

uniform vec3[15] colors;
uniform int ehcc; // erosion, hidden, color, ceiling
uniform sampler2D tex;
uniform vec3 lightPos;

out vec4 fragColor;

void main()
{
	vec3 lightDirection = normalize( vec3(lightPos.x, lightPos.y, (lightPos.z+0.5)) - pos );
	float distance = length( lightDirection );
	distance = max(0.0, distance-3);
	
	float dotProduct = dot( norm, lightDirection );
	float cosAngle = clamp( dotProduct, 0.0, 1.0 );
	
	fragColor.a = 1.0;
	vec3 diffuse;
	
	bool ceiling = bool(ehcc&1);
	bool hidden = bool((ehcc>>2)&1);
	bool useColor = bool((ehcc>>1)&1);
	int erosion = clamp(ehcc>>3, 0, 5);
	
	if(useColor) // replaced: uv.z + 0.4 > 0
	{
		if(ceiling) diffuse = vec3(0,0,0);
		else diffuse = colors[int(floor(uv.z+0.4))];  //*(0.5+clamp(1.5/uv.z,0.0,0.5));
	}
	else
	{
		diffuse = texture2D(tex,uv.xy).rgb;
	}
	
	if(hidden)
	{
		// gray (wasn't visible enough): vec3(dot(vec3(0.2126,0.7152,0.0722), diffuse));
		float fx = fract(pos.x);
		float fy = fract(pos.y);
		float dxy = fract((pos.x+pos.y)*4.0);
		if(dxy < 0.5 && (fx < 0.1 || fx > 0.9 || fy < 0.1 || fy > 0.9)) diffuse = vec3(1,0,0);//vec3(1.25*diffuse.x,0.5*diffuse.y,0.5*diffuse.z);
	}
	if(erosion > 0)
	{
		float fx = fract(pos.x);
		float fy = fract(pos.y);
		/*float dx = clamp(abs(0.02/(fx-0.5)) - 0.05, 0.0, 1.0);
		float dy = clamp(abs(0.02/(fy-0.5)) - 0.05, 0.0, 1.0);*/
		
		/// Old version with parabolic blending (it was hideous)
		/*float px = clamp(-16*(fx-0.5)*(fx-0.5)+1,0,1);
		float py = clamp(-16*(fy-0.5)*(fy-0.5)+1,0,1);
		float dx = mix(0,px,px);
		float dy = mix(0,py,py);
		float d = dx*dy;
		diffuse = mix(diffuse,erm,d); //d*erm + (1.0-d)*diffuse;*/
		if(fx > 0.4 && fx < 0.6 && fy > 0.4 && fy < 0.6)
		{
			vec3 erm = vec3(1.0,1.0-((erosion-1)/4.0),0.0);
			diffuse = mix(diffuse,erm,0.85);
		}
	}
	
	// LAVA (Type 5): simulate glow by multiplying
	fragColor.rgb = ((round(uv.z) == 5)?0.35:0.01)*diffuse + min(0.35, 30.0/max(0.5,distance))*diffuse + min(0.6,30.0/max(0.5,distance))*cosAngle*diffuse; //distance*
}