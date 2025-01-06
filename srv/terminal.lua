local winmgr = require("windowmgr")
local process = require("process")
local term = require("terminal")
print("Terminal starting")
local term = term.new({})
term:write("Hello World")
local i = 1
while true do
    sleep(5)
    i = i + 1
    term:writeLine("Hello ".. tostring(i))
    -- print(term)
end