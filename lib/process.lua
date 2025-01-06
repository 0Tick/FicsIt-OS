local json = require("json")
---@diagnostic disable: duplicate-set-field
local process = {}
process.signals = {
    SIGHUP = "SIGHUP",
    SIGINT = "SIGINT",
    SIGQUIT = "SIGQUIT",
    SIGABRT = "SIGABRT",
    SIGKILL = "SIGKILL",
    SIGPIPE = "SIGPIPE",
    SIGALRM = "SIGALRM",
    SIGTERM = "SIGTERM",
    SIGURG = "SIGURG",
    SIGSTOP = "SIGSTOP",
    SIGTSTP = "SIGTSTP",
    SIGCONT = "SIGCONT",
    SIGCHLD = "SIGCHLD",
    SIGTTIN = "SIGTTIN",
    SIGTTOU = "SIGTTOU",
    SIGIO = "SIGIO",
    SIGXCPU = "SIGXCPU",
    SIGXFSZ = "SIGXFSZ",
    SIGVTALRM = "SIGVTALRM",
    SIGPROF = "SIGPROF",
    SIGWINCH = "SIGWINCH",
    SIGINFO = "SIGINFO",
    SIGUSR1 = "SIGUSR1",
    SIGUSR2 = "SIGUSR2"
}
local buffer = require("buffer")
local log = require("log")
local util = require("util")
function coroutine.xpcall(co)
    local output = {coroutine.resume(co)}
    if output[1] == false then return false, output[2], debug.traceback(co) end
    return table.unpack(output)
end

do
    local __PROCESSES = {}
    local __NamedPipes = {}
    local __PROCESSGROUPS = {}
    local __HighestPID = 2
    local __AvailablePIDs = {}
    local __devFiles = {}

    __PROCESSES.__index = function(table, key)
        if type(key) == "thread" then
            for _, v in pairs(__PROCESSES) do
                if v.co == key then return v end
            end
        else
            return table[key]
        end
    end
    setmetatable(__PROCESSES, __PROCESSES)
    __PROCESSGROUPS.__index = function(table, key)
        local sid = process.getSelf().sid
        if table[sid] == nil then table[sid] = {} end
        return table[sid][key]
    end
    __PROCESSGROUPS.__newindex = function(table, key, value)
        local sid = process.getSelf().sid
        if table[sid] == nil then table[sid] = {} end
        table[sid][key] = value
    end
    setmetatable(__PROCESSGROUPS, __PROCESSGROUPS)

    ---@alias MODE string
    ---| "r"
    ---| "w"
    ---| "a"
    ---| "r+"
    ---| "w+"
    ---| "a+"
    ---| "rb"
    ---| "wb"
    ---| "ab"
    io = {}
    ---@param file string
    ---@param mode MODE
    function io.open(file, mode)
        local proc = process.getSelf()
        if file:sub(1, 5) == "/dev/" then
            local devFile = __devFiles[file]
            if devFile then
                return devFile
            else
                local devFile = buffer.create("w+", buffer.stringstream())
                __devFiles[file] = devFile
                return devFile
            end
        elseif file:sub(1, 6) == "/pipe/" then
            if __NamedPipes[file] then
                return __NamedPipes[file]
            else
                __NamedPipes[file] = buffer.create("w+", buffer.stringstream())
                return __NamedPipes[file]
            end
        else
            return buffer.create(mode, filesystem.open(
                                     process.expandFilePath(file), mode))
        end
    end
    ---@param ... any
    function io.write(...)
        local stdOut = process.getSelf().stdOut
        for _, v in pairs({...}) do stdOut:write(tostring(v)) end
    end
    ---@param file Buffer|string?
    ---@return Buffer?
    ---@diagnostic disable-next-line
    function io.input(file)
        if file then
            if type(file) == "string" then
                file = buffer.create("r", filesystem.open(file, "r"))
            end
            process.getSelf().stdIn = file
        else
            return process.getSelf().stdIn
        end
        return nil
    end
    ---@param mode "*all"|"*line"|"*number"
    function io.read(mode) return process.getSelf().stdIn:read(mode) end

    ---@param filename string?
    ---@param ... any?
    function io.lines(filename, ...)
        if filename then
            local buf = buffer.create("r", filesystem.open(filename, "r"))
            return buf:lines()
        end
    end
    function io.flush() process.getSelf().stdOut:flush() end

    ---@param func function
    ---@param options {parent: Process, stdIn: any?, stdOut: any?, stdErr: any?, ENV: table?}?
    ---@param args table?
    ---@return Process?
    function process.new(func, options, args)
        ---@class Process
        ---@field func function Original Function 
        ---@field co thread Coroutine
        ---@field args table Process Arguments
        ---@field status string status used for handling processes
        ---@field pid integer Process ID
        ---@field ppid integer Parent PID
        ---@field sid integer
        ---@field pgid integer
        ---@field stdIn Buffer | any
        ---@field stdOut Buffer | any
        ---@field stdErr Buffer | any
        ---@field exitCode integer
        ---@field signalHandlers table
        ---@field ENV table
        ---@field name string
        local proc = {}

        local co = coroutine.create(func)
        local parent = process.getSelf()
        if options and options.parent then parent = options.parent end
        proc.ppid = parent.pid
        proc.stdIn = parent.stdIn
        proc.stdOut = parent.stdOut
        proc.stdErr = parent.stdErr
        proc.ENV = util.deepCopy(parent.ENV)
        proc.sid = parent.sid
        proc.pgid = parent.pgid
        if options then
            if options.stdIn then proc.stdIn = options.stdIn end
            if options.stdOut then proc.stdOut = options.stdOut end
            if options.stdErr then proc.stdErr = options.stdErr end
            if options.ENV then proc.ENV = util.deepCopy(options.ENV) end
        end

        if #__AvailablePIDs > 0 then
            proc.pid = table.remove(__AvailablePIDs, 1)
        else
            proc.pid = __HighestPID
            __HighestPID = __HighestPID + 1
        end

        proc.status = "not started"
        proc.co = co
        proc.func = func
        proc.args = args or {}
        proc.signalHandlers = {
            SIGINT = function(proc) proc:kill() end,
            SIGTERM = function(proc) proc:kill() end
        }
        function proc:start()
            if self.status ~= "to start" then
                self.status = "to start"
            end
        end
        function proc:kill()
            self.status = "dead"
            local success, err = coroutine.close(self.co)
            if not success then
                local msg = string.format(
                                "Error closing Process '%s' (PID:%d)\n",
                                self.name, self.pid) ..
                                debug.traceback(self.co, err)
                log.error(msg)
            end
            self.signalHandlers[process.signals.SIGTERM] = nil
            self.signalHandlers[process.signals.SIGKILL] = nil
            process.kill(self.pid, process.signals.SIGHUP)
            process.kill(self.pid, process.signals.SIGTERM)
            process.kill(self.pid, process.signals.SIGKILL)
            table.remove(__PROCESSES, self.pid)
            if __PROCESSGROUPS[self.pid] then
                __PROCESSGROUPS[self.pid] = nil
            end
            table.insert(__AvailablePIDs, self.pid)
        end
        function proc:resume() self.status = "suspended" end

        function proc:pause() self.status = "paused" end

        setmetatable(proc, proc)
        table.insert(__PROCESSES, proc.pid, proc)

        return proc
    end

    ---@return Process
    function process.getSelf() return __PROCESSES[coroutine.running()] end

    ---@param pid integer
    ---@return Process|nil
    function process.getByPID(pid)
        for _, v in pairs(__PROCESSES) do
            if v.pid == pid then return v end
        end
    end

    function process.prgrpRaise(pgid, signal)
        if pgid == 0 then pgid = process.getSelf().pid end
        for _, v in pairs(__PROCESSES) do
            if v.pgid == pgid then
                util.safeCall(v.signalHandlers[signal])
            end
        end
    end

    function process.setSID() process.getSelf().sid = process.getSelf().pid end

    function process.raise(pid, pgid)
        process.getByPID(pid).pgid = pgid
        if __PROCESSGROUPS[pgid] == nil then
            __PROCESSGROUPS[pgid] = {pid}
        else
            table.insert(__PROCESSGROUPS[pgid], pid)
        end
    end

    function process.kill(pid, signal)
        if pid == 0 then pid = process.getSelf().pid end
        local proc = process.getByPID(pid)
        if proc and proc.pgid == proc.pgid then
            for _, v in pairs(__PROCESSES) do
                if v.pgid == proc.pgid and v.signalHandlers[signal] then
                    util.safeCall(v.signalHandlers[signal])
                end
            end
        elseif proc and proc.signalHandlers[signal] then
            util.safeCall(function()
                proc.signalHandlers[signal](proc)
            end)
        end
    end

    function process.createNewSession()
        process.getSelf().sid = process.getSelf().pid
    end

    ---@param path string
    function process.expandFilePath(path)
        local proc = process.getSelf()
        path = filesystem.path(path)
        if filesystem.exists(path) then
            return path
        else
            if path:sub(1, 2) ~= "./" or
                filesystem.exists(filesystem.path(proc.ENV.cwd "/", path)) then
                return filesystem.path(proc.ENV.cwd .. "/", path)
            else
                for _, v in pairs(proc.ENV.PATH:split(";")) do
                    if filesystem.exists(filesystem.path(v .. "/", path)) then
                        return filesystem.path(v .. "/", path)
                    end
                end
            end
        end
    end

    function process.handleProcesses()
        while true do
            for pid, proc in pairs(__PROCESSES) do
                computer.promote()
                if pid ~= 1 then
                    local result = nil
                    if proc.status == "to start" then
                        proc.status = "running"
                        result = util.safeCall(function()
                            return coroutine.resume(proc.co,
                                                    table.unpack(proc.args))
                        end)
                        proc.status = coroutine.status(proc.co)
                    elseif proc.status == "suspended" then
                        result = {coroutine.xpcall(proc.co)}
                        proc.status = coroutine.status(proc.co)
                    end
                    if proc.status == "dead" then
                        if result and result[1] == false then
                            table.remove(result, 1)
                            local traceback = ""
                            for i = 1, #result do
                                traceback = traceback .. result[i] .. "\n"
                            end
                            log.error("Process '" .. tostring(proc.func) ..
                                          "' died. Traceback:\n" .. traceback)
                        end
                        util.safeCall(proc.kill, proc)
                    end
                end
            end
            event.pull(0)
            future.run()
            coroutine.yield()
        end
    end
    __PROCESSES[1] = {
        status = "running",
        co = coroutine.running(),
        func = nil,
        args = {},
        ppid = 0,
        pid = 0,
        pgid = 0,
        stdIn = buffer.create("w+", buffer.stringstream()),
        stdOut = buffer.create("w+", buffer.stringstream()),
        stdErr = buffer.create("w+", buffer.stringstream()),
        ENV = {PATH = "/", cwd = "/"},
        name = "System"
    }
end
return process
