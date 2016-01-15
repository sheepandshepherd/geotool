/+
This file is part of GeoTool, a map viewer/editor for Lego Rock Raiders.
Copyright (C) 2014-2016  sheepandshepherd

Modified source code from dimgui: see zlib license below. <https://github.com/d-gamedev-team/dimgui>

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

/*
 * Copyright (c) 2009-2010 Mikko Mononen memon@inside.org
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */
module imgui.api;

/**
    imgui is an immediate mode GUI. See also:
    http://sol.gfxile.net/imgui/

    This module contains the API of the library.
*/

import std.algorithm;
import std.math;
import std.stdio;
import std.string;
import std.range;

import imgui.engine;
import imgui.gl3_renderer;
/* import imgui.util; */

// todo: opApply to allow changing brightness on all colors.
// todo: check CairoD samples for brightness settingsroutines.

/** A color scheme contains all the configurable GUI element colors. */
struct ColorScheme
{
    /**
        Return a range of all colors. This gives you ref access,
        which means you can modify the values.
    */
    auto walkColors()
    {
        return chain(
            (&generic.text).only,
            (&generic.line).only,
            (&generic.rect).only,
            (&generic.roundRect).only,
            (&scroll.area.back).only,
            (&scroll.area.text).only,
            (&scroll.bar.back).only,
            (&scroll.bar.thumb).only,
            (&scroll.bar.thumbHover).only,
            (&scroll.bar.thumbPress).only,
            (&button.text).only,
            (&button.textHover).only,
            (&button.textDisabled).only,
            (&button.back).only,
            (&button.backPress).only,
            (&checkbox.back).only,
            (&checkbox.press).only,
            (&checkbox.checked).only,
            (&checkbox.doUncheck).only,
            (&checkbox.disabledChecked).only,
            (&checkbox.text).only,
            (&checkbox.textHover).only,
            (&checkbox.textDisabled).only,
            (&item.hover).only,
            (&item.press).only,
            (&item.text).only,
            (&item.textDisabled).only,
            (&collapse.shown).only,
            (&collapse.hidden).only,
            (&collapse.doShow).only,
            (&collapse.doHide).only,
            (&collapse.textHover).only,
            (&collapse.text).only,
            (&collapse.textDisabled).only,
            (&collapse.subtext).only,
            (&label.text).only,
            (&value.text).only,
            (&slider.back).only,
            (&slider.thumb).only,
            (&slider.thumbHover).only,
            (&slider.thumbPress).only,
            (&slider.text).only,
            (&slider.textHover).only,
            (&slider.textDisabled).only,
            (&slider.value).only,
            (&slider.valueHover).only,
            (&slider.valueDisabled).only,
            (&separator).only);
    }

    ///
    static struct Generic
    {
        RGBA text;       /// Used by imguiDrawText.
        RGBA line;       /// Used by imguiDrawLine.
        RGBA rect;       /// Used by imguiDrawRect.
        RGBA roundRect;  /// Used by imguiDrawRoundedRect.
    }

    ///
    static struct Scroll
    {
        ///
        static struct Area
        {
            RGBA back = RGBA(0, 0, 0, 192);
            RGBA text = RGBA(255, 255, 255, 128);
        }

        ///
        static struct Bar
        {
            RGBA back = RGBA(0, 0, 0, 196);
            RGBA thumb = RGBA(255, 255, 255, 64);
            RGBA thumbHover = RGBA(255, 196, 0, 96);
            RGBA thumbPress = RGBA(255, 196, 0, 196);
        }

        Area area; ///
        Bar bar; ///
    }

    ///
    static struct Button
    {
        RGBA text         = RGBA(255, 255, 255, 200);
        RGBA textHover    = RGBA(255, 196,   0, 255);
        RGBA textDisabled = RGBA(128, 128, 128, 200);
        RGBA back         = RGBA(128, 128, 128,  96);
        RGBA backPress    = RGBA(128, 128, 128, 196);
    }

    ///
    static struct Checkbox
    {
        /// Checkbox background.
        RGBA back = RGBA(128, 128, 128, 96);

        /// Checkbox background when it's pressed.
        RGBA press = RGBA(128, 128, 128, 196);

        /// An enabled and checked checkbox.
        RGBA checked = RGBA(255, 255, 255, 255);

        /// An enabled and checked checkbox which was just pressed to be disabled.
        RGBA doUncheck = RGBA(255, 255, 255, 200);

        /// A disabled but checked checkbox.
        RGBA disabledChecked = RGBA(128, 128, 128, 200);

        /// Label color of the checkbox.
        RGBA text = RGBA(255, 255, 255, 200);

        /// Label color of a hovered checkbox.
        RGBA textHover = RGBA(255, 196, 0, 255);

        /// Label color of an disabled checkbox.
        RGBA textDisabled = RGBA(128, 128, 128, 200);
    }

    ///
    static struct Item
    {
        RGBA hover        = RGBA(255, 196, 0, 96);
        RGBA press        = RGBA(255, 196, 0, 196);
        RGBA text         = RGBA(255, 255, 255, 200);
        RGBA textDisabled = RGBA(128, 128, 128, 200);
    }

    ///
    static struct Collapse
    {
        RGBA shown = RGBA(255, 255, 255, 200);
        RGBA hidden = RGBA(255, 255, 255, 200);

        RGBA doShow = RGBA(255, 255, 255, 255);
        RGBA doHide = RGBA(255, 255, 255, 255);

        RGBA text         = RGBA(255, 255, 255, 200);
        RGBA textHover    = RGBA(255, 196, 0, 255);
        RGBA textDisabled = RGBA(128, 128, 128, 200);

        RGBA subtext = RGBA(255, 255, 255, 128);
    }

    ///
    static struct Label
    {
        RGBA text = RGBA(255, 255, 255, 255);
    }

    ///
    static struct Value
    {
        RGBA text = RGBA(255, 255, 255, 200);
    }

    ///
    static struct Slider
    {
        RGBA back = RGBA(0, 0, 0, 128);
        RGBA thumb = RGBA(255, 255, 255, 64);
        RGBA thumbHover = RGBA(255, 196, 0, 128);
        RGBA thumbPress = RGBA(255, 255, 255, 255);

        RGBA text = RGBA(255, 255, 255, 200);
        RGBA textHover = RGBA(255, 196, 0, 255);
        RGBA textDisabled = RGBA(128, 128, 128, 200);

        RGBA value = RGBA(255, 255, 255, 200);
        RGBA valueHover = RGBA(255, 196, 0, 255);
        RGBA valueDisabled = RGBA(128, 128, 128, 200);
    }

    /// Colors for the generic imguiDraw* functions.
    Generic generic;

    /// Colors for the scrollable area.
    Scroll scroll;

    /// Colors for button elements.
    Button button;

    /// Colors for checkbox elements.
    Checkbox checkbox;

    /// Colors for item elements.
    Item item;

    /// Colors for collapse elements.
    Collapse collapse;

    /// Colors for label elements.
    Label label;

    /// Colors for value elements.
    Value value;

    /// Colors for slider elements.
    Slider slider;

    /// Color for the separator line.
    RGBA separator = RGBA(255, 255, 255, 32);
}

/**
    The current default color scheme.

    You can configure this scheme, it will be used by
    default by GUI element creation functions unless
    you explicitly pass a custom color scheme.
*/
__gshared ColorScheme defaultColorScheme;

///
struct RGBA
{
    ubyte r;
    ubyte g;
    ubyte b;
    ubyte a = 255;

    RGBA opBinary(string op)(RGBA rgba)
    {
        RGBA res = this;

        mixin("res.r = cast(ubyte)res.r " ~ op ~ " rgba.r;");
        mixin("res.g = cast(ubyte)res.g " ~ op ~ " rgba.g;");
        mixin("res.b = cast(ubyte)res.b " ~ op ~ " rgba.b;");
        mixin("res.a = cast(ubyte)res.a " ~ op ~ " rgba.a;");

        return res;
    }
}

///
enum TextAlign
{
    left,
    center,
    right,
}

/** The possible mouse buttons. These can be used as bitflags. */
enum MouseButton : ubyte
{
    left  = 0x01,
    right = 0x02,
	middle = 0x04,
}

///
enum Enabled : bool
{
    no,
    yes,
}

/** Initialize the imgui library. 

    Params: 
    
    fontPath        = Path to a TrueType font file to use to draw text.
    fontTextureSize = Size of the texture to store font glyphs in. The actual texture
                      size is a square of this value.

                      A bigger texture allows to draw more Unicode characters (if the
                      font supports them). 256 (62.5kiB) should be enough for ASCII,
                      1024 (1MB) should be enough for most European scripts.

    Returns: True on success, false on failure.
*/
bool imguiInit(const(char)[] fontPath, uint fontTextureSize = 1024)
{
    return imguiRenderGLInit(fontPath, fontTextureSize);
}

/** Destroy the imgui library. */
void imguiDestroy()
{
    imguiRenderGLDestroy();
}

/**
    Begin a new frame. All batched commands after the call to
    $(D imguiBeginFrame) will be rendered as a single frame once
    $(D imguiRender) is called.

    Note: You should call $(D imguiEndFrame) after batching all
    commands to reset the input handling for the next frame.

    Example:
    -----
    int cursorX, cursorY;
    ubyte mouseButtons;
    int mouseScroll;

    /// start a new batch of commands for this frame (the batched commands)
    imguiBeginFrame(cursorX, cursorY, mouseButtons, mouseScroll);

    /// define your UI elements here
    imguiLabel("some text here");

    /// end the frame (this just resets the input control state, e.g. mouse button states)
    imguiEndFrame();

    /// now render the batched commands
    imguiRender();
    -----

    Params:

    cursorX = The cursor's last X position.
    cursorY = The cursor's last Y position.
    mouseButtons = The last mouse buttons pressed (a value or a combination of values of a $(D MouseButton)).
    mouseScroll = The last scroll value emitted by the mouse.
*/
void imguiBeginFrame(int cursorX, int cursorY, ubyte mouseButtons, int mouseScroll)
{
    updateInput(cursorX, cursorY, mouseButtons, mouseScroll);

    g_state.hot     = g_state.hotToBe;
    g_state.hotToBe = 0;

    g_state.wentActive = false;
    g_state.isActive   = false;
    g_state.isHot      = false;

    g_state.widgetX = 0;
    g_state.widgetY = 0;
    g_state.widgetW = 0;

    g_state.areaId   = 1;
    g_state.widgetId = 1;

    resetGfxCmdQueue();
}

/** End the list of batched commands for the current frame. */
void imguiEndFrame()
{
    clearInput();
}

/** Render all of the batched commands for the current frame. */
void imguiRender(int width, int height)
{
    imguiRenderGLDraw(width, height);
}

/**
    Begin the definition of a new scrollable area.

    Once elements within the scrollable area are defined
    you must call $(D imguiEndScrollArea) to end the definition.

    Params:

    title = The title that will be displayed for this scroll area.
    xPos = The X position of the scroll area.
    yPos = The Y position of the scroll area.
    width = The width of the scroll area.
    height = The height of the scroll area.
    scroll = A pointer to a variable which will hold the current scroll value of the widget.
    colorScheme = Optionally override the current default color scheme when creating this element.

    Returns:

    $(D true) if the mouse was located inside the scrollable area.
*/
bool imguiBeginScrollArea(bool scrollable = true)(const(char)[] title, int xPos, int yPos, int width, int height, int* scroll, const ref ColorScheme colorScheme = defaultColorScheme, TextAlign alignment = TextAlign.left)
{
    g_state.areaId++;
    g_state.widgetId = 0;
    g_scrollId       = (g_state.areaId << 16) | g_state.widgetId;

	int header = (title !is null)?AREA_HEADER:SCROLL_AREA_PADDING;

    g_state.widgetX = xPos + SCROLL_AREA_PADDING;
	g_state.widgetY = yPos + height - header + ((scrollable && scroll !is null)?(*scroll):0);
    g_state.widgetW = width - SCROLL_AREA_PADDING * (scrollable?4:2); /// was 4; TODO: make conditional on whether scroll is necessary
    g_scrollTop     = yPos - header + height;
    g_scrollBottom  = yPos + SCROLL_AREA_PADDING;
	g_scrollRight   = xPos + width - SCROLL_AREA_PADDING * 3;
    g_scrollVal     = scroll;

    g_scrollAreaTop = g_state.widgetY;

    g_focusTop    = yPos - header;
    g_focusBottom = yPos - header + height;

    g_insideScrollArea = inRect(xPos, yPos, width, height, false);
    g_state.insideCurrentScroll = g_insideScrollArea;

    addGfxCmdRoundedRect(cast(float)xPos, cast(float)yPos, cast(float)width, cast(float)height, 0, colorScheme.scroll.area.back); // r was 6

	if(title !is null) 
	{
		int xp = xPos + AREA_HEADER / 2, yp = yPos + height - AREA_HEADER / 2 - TEXT_HEIGHT / 2;
		if(alignment == TextAlign.center) xp = xPos + width/2;
		else if(alignment == TextAlign.right) xp = xPos - AREA_HEADER / 2 + width;
		addGfxCmdText(xp, yp, alignment, title, colorScheme.scroll.area.text);
	}
    // The max() ensures we never have zero- or negative-sized scissor rectangle when the window is very small,
    // avoiding a segfault.
	/// 2 was 4
    addGfxCmdScissor(xPos + SCROLL_AREA_PADDING, 
                     yPos + SCROLL_AREA_PADDING,
                     max(1, width - SCROLL_AREA_PADDING * 2), 
                     max(1, height - header - SCROLL_AREA_PADDING));

    return g_insideScrollArea;
}

/**
    End the definition of the last scrollable element.

    Params:

    colorScheme = Optionally override the current default color scheme when creating this element.
*/
void imguiEndScrollArea(bool scrollable = true)(const ref ColorScheme colorScheme = defaultColorScheme)
{
    // Disable scissoring.
    addGfxCmdScissor(-1, -1, -1, -1);

    // Draw scroll bar
    int x = g_scrollRight + SCROLL_AREA_PADDING / 2;
    int y = g_scrollBottom;
    int w = SCROLL_AREA_PADDING * 2;
    int h = g_scrollTop - g_scrollBottom;

    int stop = g_scrollAreaTop;
    int sbot = g_state.widgetY;
    int sh   = stop - sbot;   // The scrollable area height.

    float barHeight = cast(float)h / cast(float)sh;

    if (barHeight < 1)
    {
        float barY = cast(float)(y - sbot) / cast(float)sh;

        if (barY < 0)
            barY = 0;

        if (barY > 1)
            barY = 1;

        // Handle scroll bar logic.
        uint hid = g_scrollId;
        int hx = x;
        int hy = y + cast(int)(barY * h);
        int hw = w;
        int hh = cast(int)(barHeight * h);

        const int range = h - (hh - 1);
        bool over       = inRect(hx, hy, hw, hh);
        buttonLogic(hid, over);

        if (isActive(hid))
        {
            float u = cast(float)(hy - y) / cast(float)range;

            if (g_state.wentActive)
            {
                g_state.dragY    = g_state.my;
                g_state.dragOrig = u;
            }

            if (g_state.dragY != g_state.my)
            {
                u = g_state.dragOrig + (g_state.my - g_state.dragY) / cast(float)range;

                if (u < 0)
                    u = 0;

                if (u > 1)
                    u = 1;
                if(g_scrollVal !is null) *g_scrollVal = cast(int)((1 - u) * (sh - h));
            }
        }

		static if(scrollable)
		{
	        // BG
	        addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, cast(float)w / 2 - 1, colorScheme.scroll.bar.back);

	        // Bar
	        if (isActive(hid))
	            addGfxCmdRoundedRect(cast(float)hx, cast(float)hy, cast(float)hw, cast(float)hh, cast(float)w / 2 - 1, colorScheme.scroll.bar.thumbPress);
	        else
	            addGfxCmdRoundedRect(cast(float)hx, cast(float)hy, cast(float)hw, cast(float)hh, cast(float)w / 2 - 1, isHot(hid) ? colorScheme.scroll.bar.thumbHover : colorScheme.scroll.bar.thumb);

		}

        if (g_insideScrollArea)         // && !anyActive())  /// <-- what's this?
        {
			if (g_state.scroll && scrollable && g_scrollVal !is null)
            {
                *g_scrollVal += 20 * g_state.scroll;

                if (*g_scrollVal < 0)
                    *g_scrollVal = 0;

                if (*g_scrollVal > (sh - h))
                    *g_scrollVal = (sh - h);
            }
        }
    }
	else // no bar, reset scroll so it's not "stuck"
	{
		//addGfxCmdRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, RGBA(255,0,0,63));
		static if(scrollable) if(g_scrollVal !is null) *g_scrollVal = 0;
	}


    g_state.insideCurrentScroll = false;
}

/**
    Define a new button.

    Params:

    label = The text that will be displayed on the button.
    enabled = Set whether the button can be pressed.
    colorScheme = Optionally override the current default color scheme when creating this element.

    Returns:

    $(D true) if the button is enabled and was pressed.
    Note that pressing a button implies pressing and releasing the
    left mouse button while over the gui button.

    Example:
    -----
    void onPress() { }
    if (imguiButton("Push me"))  // button was pushed
        onPress();
    -----
*/
bool imguiButton(float start = 0f, float end = 1f, bool skipHeight = false)(const(char)[] label, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

	int x = cast(int)(max(g_state.widgetX,g_state.widgetX+start*g_state.widgetW));
    int y = g_state.widgetY - BUTTON_HEIGHT;
	int w = cast(int)(min(cast(float)g_state.widgetW,g_state.widgetW*end)-start*g_state.widgetW);
    int h = BUTTON_HEIGHT;
    if(!skipHeight) g_state.widgetY -= BUTTON_HEIGHT + DEFAULT_SPACING;

    bool over = enabled && inRect(x, y, w, h);
    bool res  = buttonLogic(id, over);

    addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 0,
                         isActive(id) ? colorScheme.button.backPress : colorScheme.button.back);

	if(label !is null)
	{
	    if (enabled)
	    {
	        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label,
	                      isHot(id) ? colorScheme.button.textHover : colorScheme.button.text);
	    }
	    else
	    {
	        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label,
	                      colorScheme.button.textDisabled);
	    }
	}

    return res;
}


bool imguiButtonTextured(float start = 0f, float end = 1f, bool skipHeight = false, bool matchHeight = false, bool fullWidth = false)(const(char)[] label, uint texID, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme, RGBA fallbackColor = RGBA(0,0,0))
{
	g_state.widgetId++;
	uint id = (g_state.areaId << 16) | g_state.widgetId;
	
	int x = cast(int)(max(g_state.widgetX,g_state.widgetX+start*g_state.widgetW));
	int w = cast(int)(min(cast(float)g_state.widgetW,g_state.widgetW*end)-start*g_state.widgetW);
	int h = matchHeight?w:BUTTON_HEIGHT;
	int y = g_state.widgetY - h;
	if(!skipHeight) g_state.widgetY -= h + DEFAULT_SPACING;
	
	bool over = enabled && inRect(x, y, fullWidth?(g_state.widgetW):(w), h);
	bool res  = buttonLogic(id, over);

	if(texID == 0 || texID == uint.max)
	{
		RGBA backCol, pressCol;
		if(fallbackColor == RGBA(0,0,0))
		{
			backCol = colorScheme.button.back;
			pressCol = colorScheme.button.backPress;
		}
		else
		{
			//import util.linalg, biome;
			//vec3ub surfCol = biome.Biome.colors.get(fallbackColorID,vec3ub(colorScheme.button.back.r,colorScheme.button.back.g,colorScheme.button.back.b));
			backCol = fallbackColor;
			backCol.a = colorScheme.button.back.a;
			pressCol = fallbackColor;
			pressCol.a = colorScheme.button.backPress.a;
		}
		addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 0,
		                     isActive(id) ? pressCol : backCol);
	}
	else
	{
		addGfxCmdTexturedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, texID,
		                      isActive(id) ? colorScheme.button.backPress : RGBA(255,255,255,255));
	}

	if(label !is null)
	{
		if (enabled)
		{
			addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label,
			              isHot(id) ? colorScheme.button.textHover : colorScheme.button.text);
		}
		else
		{
			addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label,
			              colorScheme.button.textDisabled);
		}
	}
	
	return res;
}


void imguiLines(uint num, bool invert = false)(in bool[] enabled, int height = 0, in RGBA color = RGBA(255,255,0,127))
{
	if(enabled is null || (enabled.length != 1 && enabled.length != num)) return;
	int width = g_state.widgetW/num - (num-1)*DEFAULT_SPACING/num; // safer: without spacing
	foreach(uint i; 0..num)
	{
		bool draw = (enabled.length>=i)?(enabled[i]):(enabled[0]);
		if( draw == invert ) continue;
		int x = g_state.widgetX + i*width + i*DEFAULT_SPACING;
		float y = g_state.widgetY - height * 0.5;
		int w = width;
		int h = 1;
		
		addGfxCmdRect(cast(float)x, y, cast(float)w, cast(float)h, color);
	}

	g_state.widgetY -= height; // BUTTON_HEIGHT + DEFAULT_SPACING;
}

// r was cast(float)BUTTON_HEIGHT / 2 - 1
// const ref bool[num] enabled
/// if string[n] is null, the entire button will be left out (functionality of the null button is undefined)
void imguiButtons(uint num)(bool[] pressed, in string[] label, in bool[] enabled, const ref ColorScheme colorScheme = defaultColorScheme)
{
	if(pressed is null || pressed.length != num) return;
	if(label is null || label.length != num) return;
	if(enabled is null || (enabled.length != 1 && enabled.length != num)) return;
	int width = g_state.widgetW/num - (num-1)*DEFAULT_SPACING/num; // safer: without spacing
	bool res = false;
	foreach(uint i; 0..num)
	{
		/// maybe oversimplified?
		if(label[i] is null) continue;
		g_state.widgetId++;
		uint id = (g_state.areaId << 16) | g_state.widgetId;

		int x = g_state.widgetX + i*width + i*DEFAULT_SPACING; // safer: without spacing
		int y = g_state.widgetY - BUTTON_HEIGHT;
		int w = width;
		int h = BUTTON_HEIGHT;
		
		bool over = (enabled.length == 1)?enabled[0]:enabled[i] && inRect(x, y, w, h);
		res  = buttonLogic(id, over);
		
		addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 0,
		                     isActive(id) ? colorScheme.button.backPress : colorScheme.button.back);
		
		if ((enabled.length == 1)?enabled[0]:enabled[i])
		{
			addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label[i],
			              isHot(id) ? colorScheme.button.textHover : colorScheme.button.text);
		}
		else
		{
			addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label[i],
			              colorScheme.button.textDisabled);
		}
		pressed[i] = res;
	}

	// add height only once to keep them in a row
	g_state.widgetY -= BUTTON_HEIGHT + DEFAULT_SPACING;
}

void imguiButtonsTC(uint num)(ref bool[num] pressed, string[num] label, const ref bool[num] enabled, const ref RGBA[num] textColors)
{
	import ui:colorScheme;
	int width = g_state.widgetW/num - (num-1)*DEFAULT_SPACING/num; // safer: without spacing
	bool res = false;
	RGBA oldColor = colorScheme.button.text;
	foreach(uint i; 0..num)
	{
		g_state.widgetId++;
		uint id = (g_state.areaId << 16) | g_state.widgetId;

		colorScheme.button.text = textColors[i];

		int x = g_state.widgetX + i*width + i*DEFAULT_SPACING; // safer: without spacing
		int y = g_state.widgetY - BUTTON_HEIGHT;
		int w = width;
		int h = BUTTON_HEIGHT;
		
		bool over = enabled[i] && inRect(x, y, w, h);
		res  = buttonLogic(id, over);
		
		addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 0,
		                     isActive(id) ? colorScheme.button.backPress : colorScheme.button.back);
		
		if (enabled[i])
		{
			addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label[i],
			isHot(id) ? colorScheme.button.textHover : colorScheme.button.text);
		}
		else
		{
			addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label[i],
			colorScheme.button.textDisabled);
		}
		pressed[i] = res;
	}

	colorScheme.button.text = oldColor;

	// add height only once to keep them in a row
	g_state.widgetY -= BUTTON_HEIGHT + DEFAULT_SPACING;
}

void imguiButtonsBC(uint num)(ref bool[num] pressed, string[num] label, const ref bool[num] enabled, const ref RGBA[num] backgroundColors)
{
	import ui:colorScheme;
	int width = g_state.widgetW/num - (num-1)*DEFAULT_SPACING/num; // safer: without spacing
	bool res = false;
	RGBA oldColor = colorScheme.button.back;
	foreach(uint i; 0..num)
	{
		g_state.widgetId++;
		uint id = (g_state.areaId << 16) | g_state.widgetId;
		
		colorScheme.button.back = backgroundColors[i];
		
		int x = g_state.widgetX + i*width + i*DEFAULT_SPACING; // safer: without spacing
		int y = g_state.widgetY - BUTTON_HEIGHT;
		int w = width;
		int h = BUTTON_HEIGHT;
		
		bool over = enabled[i] && inRect(x, y, w, h);
		res  = buttonLogic(id, over);
		
		addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 0,
		                     isActive(id) ? colorScheme.button.backPress : colorScheme.button.back);
		
		if (enabled[i])
		{
			addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label[i],
			isHot(id) ? colorScheme.button.textHover : colorScheme.button.text);
		}
		else
		{
			addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label[i],
			colorScheme.button.textDisabled);
		}
		pressed[i] = res;
	}
	
	colorScheme.button.back = oldColor;
	
	// add height only once to keep them in a row
	g_state.widgetY -= BUTTON_HEIGHT + DEFAULT_SPACING;
}

/**
    Define a new checkbox.

    Params:

    label = The text that will be displayed on the button.
    checkState = A pointer to a variable which holds the current state of the checkbox.
    enabled = Set whether the checkbox can be pressed.
    colorScheme = Optionally override the current default color scheme when creating this element.

    Returns:

    $(D true) if the checkbox was toggled on or off.
    Note that toggling implies pressing and releasing the
    left mouse button while over the checkbox.

    Example:
    -----
    bool checkState = false;  // initially un-checked
    if (imguiCheck("checkbox", &checkState))  // checkbox was toggled
        writeln(checkState);  // check the current state
    -----
*/
bool imguiCheck(const(char)[] label, bool* checkState, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    int w = g_state.widgetW;
    int h = BUTTON_HEIGHT;
    g_state.widgetY -= BUTTON_HEIGHT + DEFAULT_SPACING;

    bool over = enabled && inRect(x, y, w, h);
    bool res  = buttonLogic(id, over);

    if (res)  // toggle the state
        *checkState ^= 1;

    const int cx = x + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;
    const int cy = y + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;

    addGfxCmdRoundedRect(cast(float)cx - 3, cast(float)cy - 3, cast(float)CHECK_SIZE + 6, cast(float)CHECK_SIZE + 6, 4,
        isActive(id) ? colorScheme.checkbox.press : colorScheme.checkbox.back);

    if (*checkState)
    {
        if (enabled)
            addGfxCmdRoundedRect(cast(float)cx, cast(float)cy, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE / 2 - 1, isActive(id) ? colorScheme.checkbox.checked : colorScheme.checkbox.doUncheck);
        else
            addGfxCmdRoundedRect(cast(float)cx, cast(float)cy, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE / 2 - 1, colorScheme.checkbox.disabledChecked);
    }

    if (enabled)
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, isHot(id) ? colorScheme.checkbox.textHover : colorScheme.checkbox.text);
    else
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, colorScheme.checkbox.textDisabled);

    return res;
}

/**
    Define a new item.

    Params:

    label = The text that will be displayed as the item.
    enabled = Set whether the item can be pressed.
    colorScheme = Optionally override the current default color scheme when creating this element.

    Returns:

    $(D true) if the item is enabled and was pressed.
    Note that pressing an item implies pressing and releasing the
    left mouse button while over the item.
*/
bool imguiItem(const(char)[] label, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    int w = g_state.widgetW;
    int h = BUTTON_HEIGHT;
    g_state.widgetY -= BUTTON_HEIGHT + DEFAULT_SPACING;

    bool over = enabled && inRect(x, y, w, h);
    bool res  = buttonLogic(id, over);

    if (isHot(id))
        addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 2.0f, isActive(id) ? colorScheme.item.press : colorScheme.item.hover);

    if (enabled)
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, colorScheme.item.text);
    else
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, colorScheme.item.textDisabled);

    return res;
}

/**
    Define a new collapsable element.

    Params:

    label = The text that will be displayed as the item.
    subtext = Additional text displayed on the right of the label.
    checkState = A pointer to a variable which holds the current state of the collapsable element.
    enabled = Set whether the element can be pressed.
    colorScheme = Optionally override the current default color scheme when creating this element.

    Returns:

    $(D true) if the collapsable element is enabled and was pressed.
    Note that pressing a collapsable element implies pressing and releasing the
    left mouse button while over the collapsable element.
*/
bool imguiCollapse(const(char)[] label, const(char)[] subtext, bool* checkState, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    int w = g_state.widgetW;
    int h = BUTTON_HEIGHT;
    g_state.widgetY -= BUTTON_HEIGHT;     // + DEFAULT_SPACING;

    const int cx = x + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;
    const int cy = y + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;

    bool over = enabled && inRect(x, y, w, h);
    bool res  = buttonLogic(id, over);

    if (res)  // toggle the state
        *checkState ^= 1;

    if (*checkState)
        addGfxCmdTriangle(cx, cy, CHECK_SIZE, CHECK_SIZE, 2, isActive(id) ? colorScheme.collapse.doHide : colorScheme.collapse.shown);
    else
        addGfxCmdTriangle(cx, cy, CHECK_SIZE, CHECK_SIZE, 1, isActive(id) ? colorScheme.collapse.doShow : colorScheme.collapse.hidden);

    if (enabled)
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, isHot(id) ? colorScheme.collapse.textHover : colorScheme.collapse.text);
    else
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, colorScheme.collapse.textDisabled);

    if (subtext)
        addGfxCmdText(x + w - BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, subtext, colorScheme.collapse.subtext);

    return res;
}

/**
    Define a new label.

    Params:

    label = The text that will be displayed as the label.
    colorScheme = Optionally override the current default color scheme when creating this element.
*/
void imguiLabel(bool skipHeight = false)(const(char)[] label, const ref ColorScheme colorScheme = defaultColorScheme)
{
    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    if(!skipHeight) g_state.widgetY -= BUTTON_HEIGHT;
    addGfxCmdText(x, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, colorScheme.label.text);
}


/**
    Define a new value.

    Params:

    label = The text that will be displayed as the value.
    colorScheme = Optionally override the current default color scheme when creating this element.
*/
void imguiValue(const(char)[] label, const ref ColorScheme colorScheme = defaultColorScheme)
{
    const int x = g_state.widgetX;
    const int y = g_state.widgetY - BUTTON_HEIGHT;
    const int w = g_state.widgetW;
    g_state.widgetY -= BUTTON_HEIGHT;

    addGfxCmdText(x + w - BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, label, colorScheme.value.text);
}

/**
    Define a new slider.

    Params:

    label = The text that will be displayed above the slider.
    sliderState = A pointer to a variable which holds the current slider value.
    minValue = The minimum value that the slider can hold.
    maxValue = The maximum value that the slider can hold.
    stepValue = The step at which the value of the slider will increase or decrease.
    enabled = Set whether the slider's value can can be changed with the mouse.
    colorScheme = Optionally override the current default color scheme when creating this element.

    Returns:

    $(D true) if the slider is enabled and was pressed.
    Note that pressing a slider implies pressing and releasing the
    left mouse button while over the slider.
*/
bool imguiSlider(const(char)[] label, float* sliderState, float minValue, float maxValue, float stepValue, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    int w = g_state.widgetW;
    int h = SLIDER_HEIGHT;
    g_state.widgetY -= SLIDER_HEIGHT + DEFAULT_SPACING;

    addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 4.0f, colorScheme.slider.back);

    const int range = w - SLIDER_MARKER_WIDTH;

    float u = (*sliderState - minValue) / (maxValue - minValue);

    if (u < 0)
        u = 0;

    if (u > 1)
        u = 1;
    int m = cast(int)(u * range);

    bool over       = enabled && inRect(x + m, y, SLIDER_MARKER_WIDTH, SLIDER_HEIGHT);
    bool res        = buttonLogic(id, over);
    bool valChanged = false;

    if (isActive(id))
    {
        if (g_state.wentActive)
        {
            g_state.dragX    = g_state.mx;
            g_state.dragOrig = u;
        }

        if (g_state.dragX != g_state.mx)
        {
            u = g_state.dragOrig + cast(float)(g_state.mx - g_state.dragX) / cast(float)range;

            if (u < 0)
                u = 0;

            if (u > 1)
                u = 1;
            *sliderState = minValue + u * (maxValue - minValue);
            *sliderState = floor(*sliderState / stepValue + 0.5f) * stepValue; // Snap to stepValue
            m          = cast(int)(u * range);
            valChanged = true;
        }
    }

    if (isActive(id))
        addGfxCmdRoundedRect(cast(float)(x + m), cast(float)y, cast(float)SLIDER_MARKER_WIDTH, cast(float)SLIDER_HEIGHT, 4.0f, colorScheme.slider.thumbPress);
    else
        addGfxCmdRoundedRect(cast(float)(x + m), cast(float)y, cast(float)SLIDER_MARKER_WIDTH, cast(float)SLIDER_HEIGHT, 4.0f, isHot(id) ? colorScheme.slider.thumbHover : colorScheme.slider.thumb);

    // TODO: fix this, take a look at 'nicenum'.
    // todo: this should display sub 0.1 if the step is low enough.
    int digits = cast(int)(ceil(log10(stepValue)));
    char[16] fmtBuf;
    auto fmt = sformat(fmtBuf, "%%.%df", digits >= 0 ? 0 : -digits);
    char[32] msgBuf;
    string msg = sformat(msgBuf, fmt, *sliderState).idup;

    if (enabled)
    {
        addGfxCmdText(x + SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, isHot(id) ? colorScheme.slider.textHover : colorScheme.slider.text);
        addGfxCmdText(x + w - SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, msg, isHot(id) ? colorScheme.slider.valueHover : colorScheme.slider.value);
    }
    else
    {
        addGfxCmdText(x + SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, colorScheme.slider.textDisabled);
        addGfxCmdText(x + w - SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, msg, colorScheme.slider.valueDisabled);
    }

    return res || valChanged;
}

/** Add horizontal indentation for elements to be added. */
void imguiIndent()
{
    g_state.widgetX += INDENT_SIZE;
    g_state.widgetW -= INDENT_SIZE;
}

/** Remove horizontal indentation for elements to be added. */
void imguiUnindent()
{
    g_state.widgetX -= INDENT_SIZE;
    g_state.widgetW += INDENT_SIZE;
}

/** Add vertical space as a separator below the last element. */
void imguiSeparator()
{
    g_state.widgetY -= DEFAULT_SPACING * 3;
}
void imguiSeparator(int separation)
{
	g_state.widgetY -= separation;
}

/**
    Add a horizontal line as a separator below the last element.

    Params:
    colorScheme = Optionally override the current default color scheme when creating this element.
*/
void imguiSeparatorLine(const ref ColorScheme colorScheme = defaultColorScheme)
{
    int x = g_state.widgetX;
    int y = g_state.widgetY - DEFAULT_SPACING * 2;
    int w = g_state.widgetW;
    int h = 1;
    g_state.widgetY -= DEFAULT_SPACING * 4;

    addGfxCmdRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, colorScheme.separator);
}

/**
    Draw text.

    Params:
    color = Optionally override the current default text color when creating this element.
*/
void imguiDrawText(int xPos, int yPos, TextAlign textAlign, const(char)[] text, RGBA color = defaultColorScheme.generic.text)
{
    addGfxCmdText(xPos, yPos, textAlign, text, color);
}

/**
    Draw a line.

    Params:
    colorScheme = Optionally override the current default color scheme when creating this element.
*/
void imguiDrawLine(float x0, float y0, float x1, float y1, float r, RGBA color = defaultColorScheme.generic.line)
{
    addGfxCmdLine(x0, y0, x1, y1, r, color);
}

/**
    Draw a rectangle.

    Params:
    colorScheme = Optionally override the current default color scheme when creating this element.
*/
void imguiDrawRect(float xPos, float yPos, float width, float height, RGBA color = defaultColorScheme.generic.rect)
{
    addGfxCmdRect(xPos, yPos, width, height, color);
}

void imguiDrawTexturedRect(float xPos, float yPos, float width, float height, uint texID, RGBA color = RGBA(255,255,255))
{
	addGfxCmdTexturedRect(xPos, yPos, width, height, texID, color);
}

/**
    Draw a rounded rectangle.

    Params:
    colorScheme = Optionally override the current default color scheme when creating this element.
*/
void imguiDrawRoundedRect(float xPos, float yPos, float width, float height, float r, RGBA color = defaultColorScheme.generic.roundRect)
{
    addGfxCmdRoundedRect(xPos, yPos, width, height, r, color);
}
