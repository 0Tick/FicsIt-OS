local util = require("util")
local windowmgr = require("windowmgr")
local json = require("json")
local kc = require("key")
local process = require("process")
local log = require("log")

---@type FINComputerGPUT2
---@diagnostic disable param-type-mismatch
local gpu = __Windowmgr.gpu
---@type Build_ScreenDriver_C
local screen = __Windowmgr.screen
---@diagnostic enable param-type-mismatch

--- Global windowmgr update function
local proc = process.getSelf()
---@diagnostic disable-next-line: duplicate-set-field
__Windowmgr.update = function()
    proc.status = "suspended"
    coroutine.yield()
end

log.info("Starting window manager")
gpu:bindScreen(screen)

local winTitleHeight = 10
local taskbarSize = 20
--- 0 = Bottom 1 = Top
local taskbarPos = 0

__Windowmgr.w = gpu:getScreenSize().x
__Windowmgr.h = gpu:getScreenSize().y
local w = __Windowmgr.w
local h = __Windowmgr.h
local movex = 0
local movey = 0
local mdsx = 0
local mdsy = 0
local moveWindow = false
local resizeWindow = false
local mx = 0
local my = 0
local fontSize = 8
local textSize = windowmgr.textSizes[fontSize]
local nameSize = {x = 0, y = textSize.y}
local maxWinW = w
local maxWinH = h - taskbarSize
local mouseOutOfWindow = false
---@diagnostic disable-next-line
event.listen(__Windowmgr.gpu)
---@diagnostic disable-next-line: redundant-parameter
print(__Windowmgr.gpu, "GPU")
local taskbarOffset = 0
if taskbarPos == 0 then taskbarOffset = maxWinH end
event.registerListener({sender = __Windowmgr.gpu}, function(...)
    local e = {...}
    local newEvents = false
    local x
    local y
    local button
    local evAvailable = (not moveWindow) and (not resizeWindow)
    local evWindow = true
    if type(e[3]) == "userdata" then
        x = e[3].x
        y = e[3].y
        button = e[4]
        mx = x
        my = y
    end
    if e[1] == "OnMouseDown" then
        for i = #__Windowmgr.windows, 1, -1 do
            local win = __Windowmgr.windows[i]
            --- If mouseclick on/in Window
            if not win.minimized and x >= win.x and x <= (win.x + win.w) and y >=
                win.y and y <= win.y + win.w + winTitleHeight then
                --- If window top bar is clicked
                if x >= win.x and x <= (win.x + win.w) and y >= win.y and y <=
                    win.y + winTitleHeight then
                    --- If no Icon is clicked start window move
                    if x < win.x + win.w - winTitleHeight * 3 then
                        moveWindow = true
                        mdsx = x - win.x
                        mdsy = y - win.y
                        --- Minimize window
                    elseif x > win.x + win.w - winTitleHeight * 3 and x < win.x +
                        win.w - winTitleHeight * 2 then
                        win.minimized = true
                        win:pushEvent({
                            type = win.Minimize,
                            data = {table.unpack(e, 3)}
                        })
                        --- Maximize/Return window to previous state
                    elseif x > win.x + win.w - winTitleHeight * 2 and x < win.x +
                        win.w - winTitleHeight * 1 then
                        if win.maximized then
                            ---@diagnostic disable
                            win.x = win.lastDimensions.x
                            win.y = win.lastDimensions.y
                            win.w = win.lastDimensions.w
                            win.h = win.lastDimensions.h
                            ---@diagnostic enable
                            win.maximized = false
                        else
                            win.maximized = true
                            win.lastDimensions = {
                                x = win.x,
                                y = win.y,
                                w = win.w,
                                h = win.h
                            }
                            win.x = 0
                            if taskbarOffset > 0 then
                                win.y = 0
                            else
                                win.y = taskbarSize
                            end
                            win.h = maxWinH
                            win.w = maxWinW
                        end
                        win:pushEvent({
                            type = win.Maximize,
                            data = {table.unpack(e, 3)}
                        })
                        win:pushEvent({
                            type = win.EResized,
                            data = {table.unpack(e, 3)}
                        })
                    else
                        win:pushEvent({
                            type = win.Close,
                            data = {table.unpack(e, 3)}
                        })
                    end
                    --- Mouse in corner to start resizing
                elseif win.resizable and mx >= win.x + win.w - 6 and mx <= win.x +
                    win.w and my >= win.y + win.h + win.winTitleHeight - 6 and
                    my <= win.y + win.h + win.winTitleHeight then
                    resizeWindow = true
                    if nameSize.x == 0 then
                        nameSize.x = #__Windowmgr.windows[#__Windowmgr.windows]
                                         .name * textSize.x
                    end
                    mdsx = x - win.x - win.w + winTitleHeight
                    mdsy = y - win.y - win.h + winTitleHeight

                elseif evAvailable then
                    win:pushEvent({
                        type = win.EMouseDown,
                        data = {table.unpack(e, 3)}
                    })
                end
                --- If the window is not the top window put it on top of the window Stack
                if i < #__Windowmgr.windows then
                    __Windowmgr.windows[#__Windowmgr.windows]:pushEvent({
                        type = win.ELostFocus,
                        data = {table.unpack(e, 3)}
                    })
                    table.insert(__Windowmgr.windows,
                                 table.remove(__Windowmgr.windows, i))
                    nameSize.x =
                        #__Windowmgr.windows[#__Windowmgr.windows].name *
                            textSize.x
                end
                break
            end
        end
    elseif e[1] == "OnMouseUp" then
        local win = __Windowmgr.windows[#__Windowmgr.windows]
        if moveWindow then
            win.x = math.floor(x - mdsx + 0.5)
            win.y = math.floor(y - mdsy + 0.5)
            moveWindow = false
        end
        if resizeWindow then 
            resizeWindow = false 
            win:pushEvent({type = win.EResized, data = {table.unpack(e, 3)}})
            end
        if y >= maxWinH then
            local passed = 0
            for i, w in pairs(__Windowmgr.windows) do
                passed = passed + #w.name * textSize.x
                if x <= passed and x > passed - #w.name * textSize.x then
                    if w.minimized then
                        w.minimized = false
                    else
                        w.minimized = true
                    end
                end
            end
        end
        if not win.minimized and evAvailable and x >= win.x and x <=
            (win.x + win.w) and y >= win.y + winTitleHeight and y <= win.y +
            win.w + winTitleHeight then
            win:pushEvent({type = win.EMouseUp, data = {table.unpack(e, 3)}})
        end
    elseif e[1] == "OnMouseMove" then
        local win = __Windowmgr.windows[#__Windowmgr.windows]
        if moveWindow then
            movex = math.floor(x - mdsx + 0.5)
            movey = math.floor(y - mdsy + 0.5)
        elseif resizeWindow then
            if mx - win.x > nameSize.x + winTitleHeight * 3 + 1 then
                win.w = math.floor(mx - win.x - mdsx + 0.5)
            else
                win.w = math.floor(nameSize.x + winTitleHeight * 3 + 1 + 0.5)
            end
            if my - win.y > nameSize.y + winTitleHeight then
                win.h = math.floor(my - win.y - mdsy + 0.5)
            else
                win.h = math.floor(nameSize.y + winTitleHeight + 0.5)
            end
        end
        if not win.minimized and evAvailable and x >= win.x and x <=
            (win.x + win.w) and y >= win.y + winTitleHeight and y <= win.y +
            win.w + winTitleHeight then
            if mouseOutOfWindow then
                win:pushEvent({
                    type = win.EMouseEnter,
                    data = {table.unpack(e, 3)}
                })
                mouseOutOfWindow = false
            else
                win:pushEvent({
                    type = win.EMouseMove,
                    data = {table.unpack(e, 3)}
                })
            end
        end
        if not win.minimized and not mouseOutOfWindow and evAvailable then
            win:pushEvent({type = win.EMouseLeave, data = {table.unpack(e, 3)}})
            mouseOutOfWindow = true
        end
    elseif e[1] == "OnMouseLeave" then
        local win = __Windowmgr.windows[#__Windowmgr.windows]
        if moveWindow then
            local window = __Windowmgr.windows[#__Windowmgr.windows]
            window.x = x - mdsx
            window.y = y - mdsy
            moveWindow = false
        end
        if not win.minimized and evAvailable then
            win:pushEvent({type = win.EMouseUp, data = {table.unpack(e, 3)}})
        end
        mouseOutOfWindow = true
    elseif e[1] == "OnKeyChar" then
        local win = __Windowmgr.windows[#__Windowmgr.windows]
        if not win.minimized and evAvailable then
            win:pushEvent({type = win.EKeyChar, data = {table.unpack(e, 3)}})
        end
    elseif e[1] == "OnKeyUp" then
        local win = __Windowmgr.windows[#__Windowmgr.windows]
        local code = e[4]
        if not win.minimized and evAvailable then
            win:pushEvent({type = win.EKeyUp, data = {table.unpack(e, 3)}})
        end
        if code == kc.F5 then computer.reset() end
    elseif e[1] == "OnKeyDown" then
        local win = __Windowmgr.windows[#__Windowmgr.windows]
        if not win.minimized and evAvailable then
            win:pushEvent({type = win.EKeyDown, data = {table.unpack(e, 3)}})
        end
    end
    if moveWindow or resizeWindow then
        __Windowmgr.update()
    end end
    )

    future.addTask(async(
        function()
            while true do
                computer.promote()
                for _, w in pairs(__Windowmgr.windows) do
                    w:handleEvents()
                end
                sleep(0.3)
            end
        end))

while true do
    computer.promote()
    gpu:drawBox({
        position = {x = 0, y = 0},
        size = {x = w, y = h},
        color = {r = 0.4, g = 0.4, b = 0.4, a = 1}
    })
    for i, win in pairs(__Windowmgr.windows) do
        if not win.minimized then
            --- Window background
            ---@diagnostic disable-next-line: missing-fields
            gpu:drawBox({
                position = {x = win.x, y = win.y},
                size = {x = win.w, y = win.h + win.winTitleHeight},
                color = {r = 1, g = 1, b = 1, a = 1},
                hasOutline = true,
                outlineThickness = 1,
                outlineColor = {r = 0, g = 0, b = 0, a = 1}
            })
            --- Window Title Box
            ---@diagnostic disable-next-line: missing-fields
            gpu:drawBox({
                position = {x = win.x, y = win.y},
                size = {x = win.w, y = winTitleHeight},
                color = {r = 0, g = 0, b = 1, a = 1}
            })
            --- Window Title
            gpu:drawText({x = win.x, y = win.y}, win.name, fontSize,
                         {r = 0, g = 0, b = 0, a = 1}, true)
            --- Close Button
            gpu:drawText({x = win.x + win.w - winTitleHeight + 1, y = win.y},
                         "╳", fontSize, {r = 1, g = 0, b = 0, a = 1}, true)
            --- Maximize button
            gpu:drawText({x = win.x + win.w - winTitleHeight + 1, y = win.y},
                         "↕", fontSize, {r = 0, g = 0, b = 1, a = 1}, true)
            --- Minimze Button
            gpu:drawText({x = win.x + win.w - winTitleHeight + 1, y = win.y},
                         "─", fontSize, {r = 0, g = 0, b = 1, a = 1}, true)
            if not (moveWindow or resizeWindow) then
                win.render(win)
            end
        end
    end
    local win = __Windowmgr.windows[#__Windowmgr.windows]
    --- Taskbar
    local passed = 0
    ---@diagnostic disable-next-line
    gpu:drawBox({
        position = {x = 0, y = taskbarOffset},
        size = {x = w, y = taskbarSize},
        hasOutline = true,
        outlineThickness = 2,
        outlineColor = {r = 0, g = 0, b = 0, a = 1},
        color = {r = 0.97265625, g = 0.58203125, b = 0.28515625, a = 1}
    })
    for i, w in pairs(__Windowmgr.windows) do
        local size = #w.name * textSize.x
        ---@diagnostic disable-next-line
        gpu:drawBox({
            position = {x = passed, y = taskbarOffset + 1},
            size = {x = size, y = taskbarSize - 1},
            hasOutline = true,
            outlineThickness = 1,
            outlineColor = {r = 1, g = 1, b = 1, a = 1},
            color = {r = 1, g = 1, b = 1, a = 0.2}
        })
        gpu:drawText({x = passed, y = taskbarOffset + 2}, w.name, fontSize,
                     {r = 0, g = 0, b = 0, a = 1}, true)
        passed = passed + size
    end
    --- Window Resize/Move
    if #__Windowmgr.windows > 0 then
        --- Window Resize
        if win.resizable and
            ((mx >= win.x + win.w - 6 and mx <= win.x + win.w and my >= win.y +
                win.h + win.winTitleHeight - 6 and my <= win.y + win.h +
                win.winTitleHeight) or resizeWindow) then
            ---@diagnostic disable-next-line
            gpu:drawBox({
                position = {
                    x = win.x + win.w - 6,
                    y = win.y + win.h + win.winTitleHeight - 6
                },
                size = {x = 6, y = 6},
                color = {r = 0, g = 0, b = 1, a = 1}
            })
        end
        --- Window Move
        if moveWindow then
            local win = __Windowmgr.windows[#__Windowmgr.windows]
            ---@diagnostic disable-next-line
            gpu:drawBox({
                position = {x = movex, y = movey},
                size = {x = win.w, y = win.h},
                color = {r = 1, g = 1, b = 1, a = 0},
                hasOutline = true,
                outlineThickness = 2,
                outlineColor = {r = 0, g = 0, b = 0, a = 1}
            })
        end
    end
    gpu:flush()
    coroutine.yield()
end
