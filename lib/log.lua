local log = {}

function log.fatal(msg)
    computer.log(4, msg)
end

function log.error(msg)
    computer.log(3, msg)
end

function log.warn(msg)
    computer.log(2, msg)
end

function log.info(msg)
    computer.log(1, msg)
end

function log.debug(msg)
    computer.log(0, msg)
end

function log.log(level, msg)
    if level == 0 then
        log.debug(msg)
    elseif level == 1 then
        log.info(msg)
    elseif level == 2 then
        log.warn(msg)
    elseif level == 3 then
        log.error(msg)
    elseif level == 4 then
        log.fatal(msg)
    end
end

return log