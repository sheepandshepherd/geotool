GeoTool
=======
GeoTool is a map viewer/editor for Lego Rock Raiders, written in D and OpenGL3.

Compiling
---------
1. Install DMD (or another D compiler) and DUB.
2. Install GLFW and DevIL (on Windows, put the DLLs in the geotool/bin/ folder where GeoTool will be built).
3. Open a terminal/command prompt in the geotool/ folder (containing dub.json) and type "dub" or "dub --build=release". DUB will download the dependencies and build GeoTool.

License
-------
GPL v2.0 or later - <http://www.gnu.org/licenses/old-licenses/gpl-2.0.html>

Tools and libraries used
------------------------
D Compiler: DMD v2.069.2 - <http://dlang.org/download.html#dmd>  
D Package Manager: DUB - <http://code.dlang.org/download>  
Window context library: GLFW - <http://www.glfw.org/>  
Image loading library: DevIL - <http://openil.sourceforge.net/>  
Derelict bindings [Util, GL3, GLFW, IL] - <https://github.com/DerelictOrg>  

Links
-----
GitHub repository - <https://github.com/sheepandshepherd/geotool>  
RRU forum topic - <http://www.rockraidersunited.com/topic/6249-geotool/>  