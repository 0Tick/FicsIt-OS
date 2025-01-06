local util = {}

---Returns a copy of the object
---@param orig any
---@return any
function util.deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[util.deepCopy(orig_key)] = util.deepCopy(orig_value)
        end
        setmetatable(copy, util.deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

---Safley calls a function and returns the results. Logs the error if the function fails.
---@param func fun(...: any): ...?
----@param errFunc? fun(err: string)  The function to call if it fails
---@param ... any
---@return ... | nil 
function util.safeCall(func, ...)
---@diagnostic disable-next-line: param-type-mismatch
    local results = {xpcall(func, debug.traceback, ...)}
    if results[1] == false then
        return nil
    else
        table.remove(results, 1)
        return results
    end
end

return util
