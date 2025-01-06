local process = require("process")
local toml = require("toml")
local log = require("log")
log.log(0, "Starting service loader")
local services = toml.parse("/boot/services.toml")
for _, service in pairs(services) do
    if service.enabled and service.path then
        if service.name then
            log.log(0, "Loading service " .. service.name)
        else
            log.log(0, "Loading service " .. service.path)
        end
        local options = nil
        local args = nil
        if service.env then options = {ENV = service.env} end
        if service.args then args = service.args end
        local fun = filesystem.loadFile(service.path)
        if type(fun) == "function" then
            local proc = process.new(fun, options, args)
            if proc then proc:start() end
        else
            log.error("Service " .. service.path .. " failed to load:\n"..tostring(fun))
        end
    end
end
