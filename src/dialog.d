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

module dialog;

debug import std.stdio : writeln, write;
import std.string : toStringz, fromStringz;

version(Windows)
{
	pragma(lib, "comdlg32.lib");


	import core.sys.windows.windows;
	import core.stdc.stdlib : malloc, free;
}
import core.stdc.stdio : FILENAME_MAX;
enum uint FILENAME_LENGTH = cast(uint)FILENAME_MAX;

/// Wrappers for minimal dialog windows that require platform-specific code.

/// returns: path of chosen file, or null if cancelled
static string dlgOpenFile(in string title = null)
{
	string fileName;

	version(Windows)
	{
		OPENFILENAMEA f;
		char* buffer = cast(char*)malloc(FILENAME_LENGTH);
		const(char)* titleBuffer = null;
		if(title !is null) titleBuffer = title.toStringz;

		scope(exit)
		{
			free(buffer);
			destroy(titleBuffer);
		}

		buffer[0..FILENAME_LENGTH] = '\0';
		f.lStructSize = OPENFILENAMEA.sizeof;
		f.hwndOwner = null;
		f.lpstrFile = buffer;
		f.lpstrFileTitle = null;
		f.lpstrTitle = titleBuffer;
		f.nMaxFile = FILENAME_LENGTH;
		f.Flags = 0x00001000 | 0x00000800; // file must exist | path must exist
		auto result = GetOpenFileNameA(&f);
		if(result != 0)
		{
			fileName = fromStringz(buffer).dup;
			debug writeln("Opened <",fileName,">");
			if(fileName.length > 1) return fileName;
		}
	}

	return null;
}

static string dlgSaveFile()
{
	string fileName;

	version(Windows)
	{
		OPENFILENAMEA f;
		char* buffer = cast(char*)malloc(FILENAME_LENGTH);
		
		scope(exit)
		{
			free(buffer);
		}
		
		buffer[0..FILENAME_LENGTH] = '\0';
		f.lStructSize = OPENFILENAMEA.sizeof;
		f.hwndOwner = null;
		f.lpstrFile = buffer;
		f.nMaxFile = FILENAME_LENGTH;
		f.Flags = 0; // default
		auto result = GetSaveFileNameA(&f);
		if(result != 0)
		{
			fileName = fromStringz(buffer).dup;
			debug writeln("Saved <",fileName,">");
			if(fileName.length > 1) return fileName;
		}
	}

	return null;
}


/// message box
/// returns: true if clicked Yes/OK, false if clicked No
static bool dlgMsg(string message, string title = "Error", bool yesNo = false)
{
	if(yesNo)
	{
		return MessageBoxA(null, message.toStringz, title.toStringz, MB_YESNO|MB_ICONEXCLAMATION|MB_TASKMODAL) == IDYES;
	}
	else
	{
		MessageBoxA(null, message.toStringz, title.toStringz, MB_OK|MB_TASKMODAL);
	}
	return true;
}
