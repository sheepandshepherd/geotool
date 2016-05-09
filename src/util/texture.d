module util.texture;

import derelict.opengl3.gl3;
import derelict.devil.il;
import derelict.devil.ilu, derelict.devil.ilut;
import util.linalg;
import gl3n.linalg;


private bool ilProcessErrors(string tag = null)
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

/++
Returns: an OpenGL texture handle for the loaded data.
+/
uint imageDataToGLTexture(ILenum type, in void[] data)
{
	// clear il error stack
	ilProcessErrors();

	uint imageIL = ilGenImage();
	scope(exit)
	{
		ilDeleteImage(imageIL);
	}

	ilBindImage(imageIL);

	uint imageGL;

	if(ilLoadL(type,data.ptr,cast(uint)data.length))
	{
		import std.c.stdlib;
		// loaded image, move to GL
		glGenTextures(1,&imageGL);
		glBindTexture(GL_TEXTURE_2D, imageGL);
		vec2i size = vec2i(ilGetInteger(IL_IMAGE_WIDTH),ilGetInteger(IL_IMAGE_HEIGHT));
		///void* pixels = (new ubyte[size.x*size.y*4]).ptr;
		void* pixels = malloc(size.x*size.y*4);
		scope(exit) free(pixels);
		ilCopyPixels(0,0,0,size.x,size.y,1,IL_RGBA,IL_UNSIGNED_BYTE,pixels);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,size.x,size.y,0,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
	}
	
	if(!ilProcessErrors(/++baseName(d.name)+/))
	{
		return imageGL;
	}
	else throw new Exception("DevIL could not load the image data.");
}


