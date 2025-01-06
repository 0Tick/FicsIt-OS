local json = require("json")
local function clamp(val, min, max) return math.max(math.min(val, max), min) end
--- A window which can be drawn by the windowmanager. Wraps GPUT2 to keep calls in Window Bounds
---@class Window : FINComputerGPUT2
---@field x integer
---@field y integer
---@field w integer
---@field h integer
---@field lastDimensions integer[] x, y, w, h
---@field winTitleHeight integer
---@field minimized boolean
---@field maximized boolean
---@field name string
---@field resizable boolean
---@field protected gpu FINComputerGPUT2
---@field protected clipCount number
---@field protected geometryCount number
---@field protected events WindowEvent[]
---@field renderFunc fun(gpu: Window)
---@field event fun(event: WindowEvent)
local window = {}
---@class WindowEvent
---@field type integer
---@field data table
local windowEvent
window.Close = 0
window.Minimize = 1
window.Maximize = 2
window.EMouseMove = 3
window.EMouseUp = 4
window.EMouseDown = 5
window.EMouseLeave = 6
window.EMouseEnter = 7
window.EKeyDown = 8
window.EKeyUp = 9
window.EKeyChar = 10
window.EFocus = 11
window.ELostFocus = 12
window.EResized = 13

--- Renders the window
function window:render()
    computer.skip()
    self.clipAmount = 0
    self.gpu:pushTransform({x = self.x, y = self.y + self.winTitleHeight}, 1,
                           {x = 1, y = 1})
    self.gpu:pushClipRect({x = 0, y = 0}, {x = self.w, y = self.h})
    self.renderFunc(self)
    for i = 0, self.clipAmount, 1 do self.gpu:popClip() end
    for i = 0, self.geometryCount, 1 do self.gpu:popGeometry() end
end
--- Pushes a transformation to the geometry stack. All subsequent drawcalls will be transformed through all previously pushed geometries and this one. Be aware, only all draw calls till, this geometry gets pop'ed are transformed, previous draw calls (and draw calls after the pop) are unaffected by this.
---@param translation Vector2D @The local translation that is supposed to happen to all further drawcalls. Translation can be also thought as 'repositioning'.
---@param rotation number @The local rotation that gets applied to all subsequent draw calls. The origin of the rotation is the whole screens center point. The value is in degrees.
---@param scale Vector2D @The scale that gets applied to the whole screen localy along the (rotated) axis. No change in scale is (1,1).
function window:pushTransform(translation, rotation, scale)
    self.gpu:pushTransform(translation, rotation, scale)
    self.geometryCount = self.geometryCount + 1
end
--- Pushes a layout to the geometry stack. All subsequent drawcalls will be transformed through all previously pushed geometries and this one. Be aware, only all draw calls, till this geometry gets pop'ed are transformed, previous draw calls (and draw calls after the pop) are unaffected by this.
---@param offset Vector2D @The local translation (or offset) that is supposed to happen to all further drawcalls. Translation can be also thought as 'repositioning'.
---@param size Vector2D @The scale that gets applied to the whole screen localy along both axis. No change in scale is 1.
---@param scale number @
function window:pushLayout(offset, size, scale)
    self.gpu:pushLayout(offset, size, scale)
    self.geometryCount = self.geometryCount + 1
end
--- Pushes a rectangle to the clipping stack. All subsequent drawcalls will be clipped to only be visible within this clipping zone and all previously pushed clipping zones. Be aware, only all draw calls, till this clipping zone gets pop'ed are getting clipped by it, previous draw calls (and draw calls after the pop) are unaffected by this.
---@param position Vector2D @The local position of the upper left corner of the clipping rectangle.
---@param size Vector2D @The size of the clipping rectangle.
function window:pushClipRect(position, size)
    self.gpu:pushClipRect(position, size)
    self.clipAmount = self.clipAmount + 1
end
--- Pushes a 4 pointed polygon to the clipping stack. All subsequent drawcalls will be clipped to only be visible within this clipping zone and all previously pushed clipping zones. Be aware, only all draw calls, till this clipping zone gets pop'ed are getting clipped by it, previous draw calls (and draw calls after the pop) are unaffected by this.
---@param topLeft Vector2D @The local position of the top left point.
---@param topRight Vector2D @The local position of the top right point.
---@param bottomLeft Vector2D @The local position of the top right point.
---@param bottomRight Vector2D @The local position of the bottom right point.
function window:pushClipPolygon(topLeft, topRight, bottomLeft, bottomRight)
    self.gpu:pushClipPolygon(topLeft, topRight, bottomLeft, bottomRight)
    self.clipAmount = self.clipAmount + 1
end
--- Pops the top most geometry from the geometry stack. The latest geometry on the stack gets removed first. (Last In, First Out)
function window:popGeometry()
    if self.geometryCount > 0 then
        self.gpu:popGeometry()
        self.geometryCount = self.geometryCount - 1
    end
end
--- Pops the top most clipping zone from the clipping stack. The latest clipping zone on the stack gets removed first. (Last In, First Out)
function window:popClip()
    if self.clipCount > 0 then
        self.gpu:popClip()
        self.clipCount = self.clipCount - 1
    end
end
--- 
---@param Text string @
---@param Size number @
---@param bMonospace boolean @
---@return Future_FINComputerGPUT2_measureText<Vector2D>
function window:measureText(Text, Size, bMonospace)
    return self.gpu:measureText(Text, Size, bMonospace)
end
--- Flushes all draw calls to the visible draw call buffer to show all changes at once. The draw buffer gets cleared afterwards.
function window:flush() coroutine.yield() end
--- Draws some Text at the given position (top left corner of the text), text, size, color and rotation.
---@param position Vector2D @The position of the top left corner of the text.
---@param text string @The text to draw.
---@param size number @The font size used.
---@param color Color @The color of the text.
---@param monospace boolean @True if a monospace font should be used.
function window:drawText(position, text, size, color, monospace)
    self.gpu:drawText(position, text, size, color, monospace)
end
--- Draws a Spline from one position to another with given directions, thickness and color.
---@param start Vector2D @The local position of the start point of the spline.
---@param startDirections Vector2D @The direction of the spline of how it exists the start point.
---@param endPos Vector2D @The local position of the end point of the spline.
---@param endDirection Vector2D @The direction of how the spline enters the end position.
---@param thickness number @The thickness of the line drawn.
---@param color Color @The color of the line drawn.
function window:drawSpline(start, startDirections, endPos, endDirection,
                           thickness, color)
    self.gpu:drawSpline(start, startDirections, endPos, endDirection, thickness,
                        color)
end
--- Draws a Rectangle with the upper left corner at the given local position, size, color and rotation around the upper left corner.
---@param position Vector2D @The local position of the upper left corner of the rectangle.
---@param size Vector2D @The size of the rectangle.
---@param color Color @The color of the rectangle.
---@param URL string @The url to the image to show
---@param rotation number @The rotation of the rectangle around the upper left corner in degrees.
function window:drawRect(position, size, color, URL, rotation)
    self.gpu:drawRect(position, size, color, URL, rotation)
end
--- Draws connected lines through all given points with the given thickness and color.
---@param points Vector2D[] @The local points that get connected by lines one after the other.
---@param thickness number @The thickness of the lines.
---@param color Color @The color of the lines.
function window:drawLines(points, thickness, color)
    self.gpu:drawLines(points, thickness, color)
end
--- Draws a box. (check the description of the parameters to make a more detailed description)
---@param boxSettings GPUT2DrawCallBox
function window:drawBox(boxSettings) self.gpu:drawBox(boxSettings) end
--- Draws a Cubic Bezier Spline from one position to another with given control points, thickness and color.
---@param p0 Vector2D @The local position of the start point of the spline.
---@param p1 Vector2D @The local position of the first control point.
---@param p2 Vector2D @The local position of the second control point.
---@param p3 Vector2D @The local position of the end point of the spline.
---@param thickness number @The thickness of the line drawn.
---@param color Color @The color of the line drawn.
function window:drawBezier(p0, p1, p2, p3, thickness, color)
    self:drawBezier(p0, p1, p2, p3, thickness, color)
end

---Draws some Text with fore-/background color
---@param position Vector2D
---@param text string
---@param size number
---@param foreground Color
---@param background Color
function window:coloredText(position, text, size, foreground, background)
    ---@diagnostic disable-next-line
    self:drawBox({
        position = position,
        size = {
            x = #text * __Windowmgr.textSizes[size].x,
            y = __Windowmgr.textSizes[size].y
        },
        color = background
    })
    self:drawText(position, text, size, foreground, true)
end

---Adds a new event to the events queue of the window
---@param event WindowEvent
function window:pushEvent(event) table.insert(self.events, event) end

---Handles all events in the event Queue of the window
function window:handleEvents()
    for i, event in pairs(self.events) do
        self.event(event)
        table.remove(self.events, i)
    end
end

__Windowmgr = {
    ---@type FINComputerGPUT2
    ---@diagnostic disable-next-line
    gpu = computer.getPCIDevices(classes["FINComputerGPUT2"])[1],

    ---@type Build_ScreenDriver_C
    ---@diagnostic disable-next-line
    screen = computer.getPCIDevices(classes["Build_ScreenDriver_C"])[1],
    ---@type Window[]
    windows = {},
    w = 0,
    h = 0,
    name = "Window"
}

---@class WindowMgr
local windmgr = {}
---
---@param x? integer
---@param y? integer
---@param w? integer
---@param h? integer
---@param name? string
---@param resizable? boolean
---@param renderFunc? fun(gpu: Window)
---@param event? fun(event:WindowEvent)
---@param winTitleHeight? integer
---@return Window
function windmgr.new(x, y, w, h, renderFunc, event, name, resizable,
                     winTitleHeight)
    if resizable ~= nil then
        resizable = resizable
    else
        resizable = true
    end
    ---@type Window
    ---@diagnostic disable-next-line
    local win = {
        x = x or 0,
        y = y or 0,
        w = w or 100,
        h = h or 100,
        minimized = false,
        gpu = __Windowmgr.gpu,
        clipCount = 0,
        geometryCount = 0,
        renderFunc = renderFunc or function() end,
        name = name or ("New Window " .. #__Windowmgr.windows),
        resizable = resizable,
        winTitleHeight = winTitleHeight or 10,
        lastDimensions = {x = x, y = y, w = w, h = h},
        maximized = false,
        event = event or function() end,
        events = {},
        dontRender = false
    }
    setmetatable(win, window)
    window.__index = window
    table.insert(__Windowmgr.windows, win)
    return win
end

---@param win? Window
function windmgr.remove(win)
    if win then
        for i, w in pairs(__Windowmgr.windows) do
            if w == win then table.remove(__Windowmgr.windows, i) end
        end
    else
        table.remove(__Windowmgr.windows, #__Windowmgr.windows)
    end
end

windmgr.textSizes = {
    {x = 0.905, y = 1.0}, {x = 1.81, y = 3.6}, {x = 1.81, y = 3.6},
    {x = 3.62, y = 5.6}, {x = 3.62, y = 7.8}, {x = 5.43, y = 8.4},
    {x = 5.43, y = 9.0}, {x = 6.35, y = 11.0}, {x = 7.24, y = 12.5},
    {x = 8.150, y = 13.0}, {x = 9.05, y = 15.0}, {x = 9.95, y = 16.0},
    {x = 10.86, y = 17.0}, {x = 11.77, y = 20.0}, {x = 12.67, y = 21.0},
    {x = 13.58, y = 23.0}, {x = 13.6, y = 23.0}, {x = 15.38, y = 25.0},
    {x = 15.4, y = 25.0}, {x = 16.3, y = 26.0}, {x = 17.2, y = 28.0},
    {x = 18.1, y = 30.0}, {x = 19.0, y = 32.0}, {x = 19.9, y = 32.0},
    {x = 20.82, y = 32.368}, {x = 20.85, y = 33.947}, {x = 22.65, y = 34.736},
    {x = 22.65, y = 36.315}, {x = 23.55, y = 37.894}, {x = 24.45, y = 38.684},
    {x = 25.35, y = 39.473}, {x = 26.24, y = 41.842}, {x = 27.15, y = 42.631},
    {x = 28.05, y = 43.421}, {x = 28.95, y = 45.789}, {x = 29.85, y = 46.578},
    {x = 30.8, y = 47.368}, {x = 30.8, y = 49.736}, {x = 31.7, y = 50.526},
    {x = 32.58, y = 51.315}, {x = 33.45, y = 53.684}, {x = 34.37, y = 54.473},
    {x = 35.3, y = 55.263}, {x = 36.2, y = 57.631}, {x = 37.1, y = 58.421},
    {x = 38.0, y = 59.21}, {x = 38.0, y = 61.578}, {x = 39.8, y = 62.368},
    {x = 39.8, y = 63.157}, {x = 41.6, y = 64.736}, {x = 41.6, y = 66.315},
    {x = 42.55, y = 67.105}, {x = 43.4, y = 68.684}, {x = 44.3, y = 70.263},
    {x = 45.2, y = 71.052}, {x = 46.1, y = 72.631}, {x = 47.0, y = 74.21},
    {x = 47.0, y = 75.0}, {x = 48.85, y = 76.578}, {x = 48.85, y = 77.368},
    {x = 49.8, y = 78.947}, {x = 50.65, y = 80.526}, {x = 51.55, y = 81.315},
    {x = 52.5, y = 82.894}, {x = 53.35, y = 84.473}, {x = 54.3, y = 85.263},
    {x = 55.15, y = 86.842}, {x = 56.0, y = 88.421}, {x = 57.0, y = 89.21},
    {x = 57.0, y = 90.0}, {x = 58.8, y = 92.368}, {x = 58.8, y = 93.157},
    {x = 59.7, y = 93.947}, {x = 60.6, y = 96.315}, {x = 61.6, y = 97.105},
    {x = 62.4, y = 97.894}, {x = 63.3, y = 100.263}, {x = 64.2, y = 101.052},
    {x = 64.2, y = 101.842}, {x = 66.0, y = 104.21}, {x = 66.0, y = 105.0},
    {x = 67.0, y = 105.789}, {x = 68.0, y = 108.157}, {x = 69.0, y = 108.947},
    {x = 70.0, y = 109.736}, {x = 71.0, y = 112.105}, {x = 71.5, y = 112.894},
    {x = 72.3, y = 113.684}, {x = 73.2, y = 115.263}, {x = 74.1, y = 116.842},
    {x = 74.2, y = 117.631}, {x = 76.0, y = 119.21}, {x = 76.0, y = 120.789},
    {x = 77.8, y = 121.578}, {x = 77.8, y = 123.157}, {x = 78.7, y = 124.736},
    {x = 79.6, y = 125.526}, {x = 80.6, y = 127.105}, {x = 81.3, y = 127.894},
    {x = 81.3, y = 129.473}, {x = 83.2, y = 131.052}, {x = 83.2, y = 131.842},
    {x = 85.0, y = 133.421}, {x = 85.0, y = 135.0}, {x = 86.0, y = 135.789},
    {x = 87.0, y = 137.368}, {x = 88.0, y = 138.947}, {x = 89.0, y = 139.736},
    {x = 89.8, y = 140.526}, {x = 90.6, y = 142.894}, {x = 91.6, y = 143.684},
    {x = 92.2, y = 144.473}, {x = 93.1, y = 146.842}, {x = 93.1, y = 147.631},
    {x = 94.8, y = 148.421}, {x = 95.0, y = 150.789}, {x = 96.0, y = 151.578},
    {x = 97.0, y = 152.368}, {x = 98.0, y = 154.736}, {x = 98.4, y = 155.526},
    {x = 98.0, y = 156.315}, {x = 99.0, y = 158.684}, {x = 100.0, y = 159.473},
    {x = 101.0, y = 160.263}, {x = 102.0, y = 162.631},
    {x = 102.0, y = 163.421}, {x = 103.0, y = 164.21}, {x = 104.0, y = 165.789},
    {x = 105.0, y = 167.368}, {x = 105.0, y = 168.157},
    {x = 107.0, y = 169.736}, {x = 107.0, y = 171.315},
    {x = 108.0, y = 172.105}, {x = 109.0, y = 173.684},
    {x = 110.0, y = 175.263}, {x = 110.0, y = 176.052},
    {x = 112.0, y = 177.631}, {x = 112.0, y = 178.421}, {x = 113.0, y = 180.0},
    {x = 114.0, y = 181.578}, {x = 115.0, y = 182.368},
    {x = 117.0, y = 185.526}, {x = 117.0, y = 186.315},
    {x = 118.0, y = 187.894}, {x = 119.0, y = 189.473},
    {x = 120.0, y = 190.263}, {x = 120.0, y = 191.052},
    {x = 121.0, y = 193.421}, {x = 122.0, y = 194.21}, {x = 123.0, y = 195.0},
    {x = 124.0, y = 197.368}, {x = 125.0, y = 198.157},
    {x = 125.0, y = 198.947}, {x = 126.0, y = 201.315},
    {x = 127.0, y = 202.105}, {x = 128.0, y = 202.894},
    {x = 129.0, y = 205.263}, {x = 129.0, y = 206.052},
    {x = 130.0, y = 206.842}, {x = 131.0, y = 209.21}, {x = 132.0, y = 210.0},
    {x = 133.0, y = 210.789}, {x = 134.0, y = 213.157},
    {x = 134.0, y = 213.947}, {x = 135.0, y = 214.736},
    {x = 136.0, y = 216.315}, {x = 137.0, y = 217.894},
    {x = 137.0, y = 218.684}, {x = 139.0, y = 220.263},
    {x = 139.0, y = 221.842}, {x = 140.0, y = 222.631}, {x = 141.0, y = 224.21},
    {x = 141.0, y = 225.789}, {x = 141.0, y = 226.578},
    {x = 143.0, y = 228.157}, {x = 143.0, y = 228.947},
    {x = 144.0, y = 230.526}, {x = 145.0, y = 232.105},
    {x = 146.0, y = 232.894}, {x = 146.0, y = 234.473},
    {x = 148.0, y = 236.052}, {x = 148.0, y = 236.842},
    {x = 149.0, y = 238.421}, {x = 150.0, y = 240.0}, {x = 151.0, y = 240.789},
    {x = 151.0, y = 241.578}, {x = 152.0, y = 243.947},
    {x = 153.0, y = 244.736}, {x = 154.0, y = 245.526},
    {x = 155.0, y = 247.894}, {x = 156.0, y = 248.684},
    {x = 156.0, y = 249.473}, {x = 157.0, y = 251.842},
    {x = 158.0, y = 252.631}, {x = 159.0, y = 253.421},
    {x = 160.0, y = 255.789}, {x = 160.0, y = 256.578},
    {x = 161.0, y = 257.368}, {x = 162.0, y = 259.736}
}
windmgr.Close = window.Close
windmgr.Minimize = window.Minimize
windmgr.Maximize = window.Maximize
windmgr.EMouseMove = window.EMouseMove
windmgr.EMouseUp = window.EMouseUp
windmgr.EMouseDown = window.EMouseDown
windmgr.EMouseLeave = window.EMouseLeave
windmgr.EMouseEnter = window.EMouseEnter
windmgr.EKeyDown = window.EKeyDown
windmgr.EKeyUp = window.EKeyUp
windmgr.EKeyChar = window.EKeyChar
windmgr.EFocus = window.EFocus
windmgr.ELostFocus = window.ELostFocus
windmgr.EResized = window.EResized
if __Windowmgr.update == nil then
---@diagnostic disable-next-line: duplicate-set-field
    __Windowmgr.update = function() end
    
end

return windmgr
