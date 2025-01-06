computer.beep(1)

__REQUIRECACHE__ = {}
---@param name string
function require(name)
    local fs = filesystem
    if __REQUIRECACHE__[name] then
        return __REQUIRECACHE__[name]
    end
    local result = nil
    local fullPath = nil
    if fs.exists(name .. ".lua") then
        result = fs.doFile(name .. ".lua")
        fullPath = name .. ".lua"
    elseif fs.exists(name) then
        result = fs.doFile(name)
        fullPath = name
    elseif fs.exists("/lib/" .. name .. ".lua") then
        result = fs.doFile("/lib/" .. name .. ".lua")
        fullPath = "/lib/" .. name .. ".lua"
    elseif fs.exists("/lib/" .. name) then
        result = fs.doFile("/lib/" .. name)
        fullPath = "/lib/" .. name
    end
    if result then
        __REQUIRECACHE__[name] = result
        return result
    else
        return nil
    end
end

local entries = {}
for _, item in pairs(filesystem.children("/boot") ) do
    if string.find(item, "(%d+)_[^\n]+.lua$") ~= nil and filesystem.isFile("/boot/"..item) then
        table.insert(entries, item)
    end
end
table.sort(entries, function(a, b)
    return tonumber(a:sub(1, a:find("_") - 1)) < tonumber(b:sub(1, b:find("_") - 1))
end)
local process = require("process")
for _,f in pairs(entries) do
    computer.log(0, "Running boot script: " .. f)
    filesystem.doFile("/boot/"..f)
end
process.handleProcesses()