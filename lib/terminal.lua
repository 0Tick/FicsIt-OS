local terminal = {}
local util = require("util")
local process = require("process")
local windowmgr = require("windowmgr")

---comment
---@param options {window: Window?, fontsize: integer?, color: Color?, backgroundColor: Color?, maxScroll:integer?}
---@return Terminal
function terminal.new(options)
    local proc = process.getSelf()
    ---@class Terminal
    ---@field fontsize integer
    ---@field widthPixel integer
    ---@field widthChar integer
    ---@field heightPixel integer
    ---@field heightChar integer
    ---@field cursorX integer
    ---@field cursorY integer
    ---@field maxScroll integer
    ---@field scroll integer
    ---@field color Color
    ---@field backgroundColor Color
    ---@field win Window
    ---@field stdColor Color
    ---@field stdBackgroundColor Color
    ---@field logicalLines table<{chars:string, color:Color, backgroundColor:Color}[]>
    ---@field renderdBuffer table<{chars:string, color:Color, backgroundColor:Color}[]>
    local term = {
        fontsize = options.fontsize or 12,
        widthPixel = 0,
        widthChar = 0,
        heightPixel = 0,
        heightChar = 0,
        cursorX = 1,
        cursorY = 1,
        maxScroll = options.maxScroll or 1200,
        scroll = 0,
        color = options.color or {r = 1, g = 1, b = 1, a = 1},
        backgroundColor = options.backgroundColor or
            {r = 0, g = 0, b = 0, a = 1},
        win = options.window or windowmgr.new(0, 0, 400, 200),
        stdColor = options.color or {r = 1, g = 1, b = 1, a = 1},
        stdBackgroundColor = options.backgroundColor or
            {r = 0, g = 0, b = 0, a = 1},
        logicalLines = {{}},
        renderdBuffer = {{}}
    }
    term.win.renderFunc = function(win) term:render(win) end
    term.widthPixel = term.win.w
    term.widthChar = math.floor(term.widthPixel /
                                    windowmgr.textSizes[term.fontsize].x)
    term.heightPixel = term.win.h
    term.heightChar = math.floor(term.heightPixel /
                                     windowmgr.textSizes[term.fontsize].y)

    term.win.event = function(event)
        if event.type == windowmgr.EResized then
            util.safeCall(proc.signalHandlers["SIGWINCH"])
            term.widthPixel = term.win.w
            term.widthChar = math.floor(term.widthPixel /
                                            windowmgr.textSizes[term.fontsize].x)
            term.heightPixel = term.win.h
            term.heightChar = math.floor(term.heightPixel /
                                             windowmgr.textSizes[term.fontsize]
                                                 .y)
            term:write("")
        end
    end

    function term:write(text)
        local json = require("json")
        if string.find(text, "[^\n]+") then
            for i in string.gmatch(text, "[^\n]+") do
                table.insert(self.logicalLines[1], {
                    color = self.color,
                    backgroundColor = self.backgroundColor,
                    chars = i
                })
                table.insert(self.logicalLines, 1, {})
            end
            table.remove(self.logicalLines, 1)
        else
            table.insert(self.logicalLines[1], {
                color = self.color,
                backgroundColor = self.backgroundColor,
                chars = text or " "
            })
        end
        for i = 1, #self.logicalLines do
            local line = self.logicalLines[i]
            local cursorX = self.cursorX
            local cursorY = self.cursorY
            for i = 1, #line do
                local c = line[i]
                local str = c.chars
                for j = 1, #str do
                    local char = str:sub(j,j)
                    self.renderdBuffer[cursorY][cursorX] = {
                        color = c.color,
                        backgroundColor = c.backgroundColor,
                        char = char
                    }
                    cursorX = cursorX + 1
                    if cursorX == self.widthChar then
                        cursorX = 0
                        if cursorY == 1 then
                            table.insert(self.renderdBuffer, 1, {})
                        else
                            cursorY = cursorY - 1
                        end
                    end
                end
            end
        end
    end

    function term:writeLine(text) self:write(text .. "\n") end

    function term:render(win)
        local charSize = windowmgr.textSizes[term.fontsize]
        local debug = true
        local function renderLine(lineIdx, y)
            local colors = {}
            ---@type { chars: string, color: Color, backgroundColor: Color }[]
            local line = term.renderdBuffer[lineIdx]
            if line then
                for i = 1, #line do
                    local c = line[i]
                    if colors[c.color] == nil then
                        colors[c.color] = string.rep(" ", i - 1)
                    end
                    colors[c.color] = colors[c.color] .. c.chars
                    ---@type GPUT2DrawCallBox
                    win:drawBox({
                        position = {
                            x = i * charSize.x,
                            y = self.heightPixel - y
                        },
                        size = {x = charSize.x, y = charSize.y},
                        color = c.backgroundColor
                    })
                end
                for color, str in pairs(colors) do
                    if debug then
                        local json = require("json")
                        print(json:encode(win))
                        debug = false
                    end
                    win:drawText({x = 0, y = y}, str, term.fontsize, color,
                                      true)
                end
            end
        end
        for i = 1, self.heightChar + 2 do
            local index = math.floor(i + self.scroll / charSize.y)
            if index > 0 and term.renderdBuffer[index] then
                renderLine(index, i * charSize.y + term.scroll - charSize.y)
            end
        end

    end
    term.__tostring = function()
        local json = require("json")
        return json:encode_pretty({
            back = term.backgroundColor,
            col = term.color,
            logical = term.logicalLines,
            rendered = term.renderdBuffer
        })
    end
    term.__index = term
    setmetatable(term, term)
    return term

end

return terminal
