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

module dialog;

debug import std.stdio : writeln, write;
import std.string : toStringz, fromStringz;

version(Windows)
{
	pragma(lib, "comdlg32.lib");


	import core.sys.windows.windows;
	import std.c.stdlib : malloc, free;
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
