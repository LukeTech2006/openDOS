--terminal lib

local term = {}
local cursorX, cursorY = 1, 1
local cursorBlink = nil
--- quick and dirty hacks that allow newer programs to run while not actually writing new code
term.gpu = function() return component.gpu end
term.getViewport = function()
    local w, h = component.gpu.getResolution()
    return w, h, 0, 0, cursorX, cursorY
end
term.getGlobalArea = function(ignored)
    local w,h,dx,dy,rx,ry = term.getViewport(window)
    return dx+1,dy+1,w,h
end
term.pull = event.pull
term.keyboard = function() return component.keyboard.address end
term.screen = function() return term.gpu().getScreen() end

local function toggleBlink()
    if term.isAvailable() then
    cursorBlink.state = not cursorBlink.state
    if cursorBlink.state then
        cursorBlink.alt = component.gpu.get(cursorX, cursorY)
        component.gpu.set(cursorX, cursorY, "▁")
    else
        component.gpu.set(cursorX, cursorY, cursorBlink.alt)
    end
    end
end

function term.clear()
    if term.isAvailable() then
    local w, h = component.gpu.getResolution()
    component.gpu.fill(1, 1, w, h, " ")
    end
    cursorX, cursorY = 1, 1
end

function term.clearLine()
    if term.isAvailable() then
    local w = component.gpu.getResolution()
    component.gpu.fill(1, cursorY, w, 1, " ")
    end
    cursorX = 1
end

function term.getCursor()
    return cursorX, cursorY
end

function term.setCursor(col, row)
    checkArg(1, col, "number")
    checkArg(2, row, "number")
    if cursorBlink and cursorBlink.state then
    toggleBlink()
    end
    cursorX = math.floor(col)
    cursorY = math.floor(row)
end

function term.getCursorBlink()
    return cursorBlink ~= nil
end

function term.setCursorBlink(enabled)
    checkArg(1, enabled, "boolean")
    if enabled then
    if not cursorBlink then
        cursorBlink = {}
        cursorBlink.id = event.timer(0.5, toggleBlink, math.huge)
        cursorBlink.state = false
    elseif not cursorBlink.state then
        toggleBlink()
    end
    elseif cursorBlink then
    event.cancel(cursorBlink.id)
    if cursorBlink.state then
        toggleBlink()
    end
    cursorBlink = nil
    end
end

function term.isAvailable()
    return component.isAvailable("gpu") and component.isAvailable("screen")
end

function term.readKey(echo)
    local blink = term.getCursorBlink()
    term.setCursorBlink(true)
    local ok, name, address, charOrValue, code = pcall(event.pull, "key_down")
    if not ok then
        term.setCursorBlink(blink)
        error("interrupted", 0)
    end
    if name == "key_down" then
        if echo then term.write(charOrValue) end
        term.setCursorBlink(blink)
    end
end

function term.read(history, dobreak, hint)
    checkArg(1, history, "table", "nil")
    checkArg(3, hint, "table", "function", "nil")
    history = history or {}
    table.insert(history, "")
    local offset = term.getCursor() - 1
    local scrollX, scrollY = 0, #history - 1
    
    local hints = { handler = hint }

    local function getCursor()
    local cx, cy = term.getCursor()
    return cx - offset + scrollX, 1 + scrollY
    end

    local function line()
    local cbx, cby = getCursor()
    return history[cby]
    end
    
    local function setCursor(nbx, nby)
    local w, h = component.gpu.getResolution()
    local cx, cy = term.getCursor()

    scrollY = nby - 1

    nbx = math.max(1, math.min(unicode.len(history[nby]) + 1, nbx))
    local ncx = nbx + offset - scrollX
    if ncx > w then
        local sx = nbx - (w - offset)
        local dx = math.abs(scrollX - sx)
        scrollX = sx
        component.gpu.copy(1 + offset + dx, cy, w - offset - dx, 1, -dx, 0)
        local str = unicode.sub(history[nby], nbx - (dx - 1), nbx)
        str = text.padRight(str, dx)
        component.gpu.set(1 + math.max(offset, w - dx), cy, unicode.sub(str, 1 + math.max(0, dx - (w - offset))))
    elseif ncx < 1 + offset then
        local sx = nbx - 1
        local dx = math.abs(scrollX - sx)
        scrollX = sx
        component.gpu.copy(1 + offset, cy, w - offset - dx, 1, dx, 0)
        local str = unicode.sub(history[nby], nbx, nbx + dx)
        --str = text.padRight(str, dx)
        component.gpu.set(1 + offset, cy, str)
    end

    term.setCursor(nbx - scrollX + offset, cy)
    end

    local function copyIfNecessary()
    local cbx, cby = getCursor()
    if cby ~= #history then
        history[#history] = line()
        setCursor(cbx, #history)
    end
    end

    local function redraw()
    local cx, cy = term.getCursor()
    local bx, by = 1 + scrollX, 1 + scrollY
    local w, h = component.gpu.getResolution()
    local l = w - offset
    local str = unicode.sub(history[by], bx, bx + l)
    str = text.padRight(str, l)
    component.gpu.set(1 + offset, cy, str)
    end
    
    local function setline(to)
    local cbx, cby = getCursor()
    history[cby] = to
    redraw()
    end


    local function home()
    local cbx, cby = getCursor()
    setCursor(1, cby)
    end

    local function ende()
    local cbx, cby = getCursor()
    setCursor(unicode.len(line()) + 1, cby)
    end

    local function left()
    local cbx, cby = getCursor()
    if cbx > 1 then
        setCursor(cbx - 1, cby)
        return true -- for backspace
    end
    end

    local function right(n)
    n = n or 1
    local cbx, cby = getCursor()
    local be = unicode.len(line()) + 1
    if cbx < be then
        setCursor(math.min(be, cbx + n), cby)
    end
    end

    local function up()
    local cbx, cby = getCursor()
    if cby > 1 then
        setCursor(1, cby - 1)
        redraw()
        ende()
    end
    end

    local function down()
    local cbx, cby = getCursor()
    if cby < #history then
        setCursor(1, cby + 1)
        redraw()
        ende()
    end
    end

    local function delete()
    copyIfNecessary()
    local cbx, cby = getCursor()
    if cbx <= unicode.len(line()) then
        history[cby] = unicode.sub(line(), 1, cbx - 1) ..
                        unicode.sub(line(), cbx + 1)
        local cx, cy = term.getCursor()
        local w, h = component.gpu.getResolution()
        component.gpu.copy(cx + 1, cy, w - cx, 1, -1, 0)
        local br = cbx + (w - cx)
        local char = unicode.sub(line(), br, br)
        if not char or unicode.len(char) == 0 then
        char = " "
        end
        component.gpu.set(w, cy, char)
    end
    end

    local function insert(value)
    copyIfNecessary()
    local cx, cy = term.getCursor()
    local cbx, cby = getCursor()
    local w, h = component.gpu.getResolution()
    history[cby] = unicode.sub(line(), 1, cbx - 1) ..
                    value ..
                    unicode.sub(line(), cbx)
    local len = unicode.len(value)
    local n = w - (cx - 1) - len
    if n > 0 then
        component.gpu.copy(cx, cy, n, 1, len, 0)
    end
    component.gpu.set(cx, cy, value)
    right(len)
    end

    local function tab()
    if not hints.handler then return end
    local main_kb = term.keyboard()
    if not main_kb then
        return
    end
    if not hints.cache then
        local data = hints.handler
        hints.handler = function(...)
        if type(data) == "table" then
            local args = {...}
            local filtered = {}
            for _,option in ipairs(data) do
            if string.sub(option, 1, #args[1]) == args[1] then
                filtered[#filtered + 1] = option
                --print(option)
            end
            end
            return filtered
        else
            return data(...) or {}
        end
        end
        hints.cache = hints.handler(line(), #line() + 1)
        hints.cache.i = -1
    end
    
    local cache = hints.cache
    local cache_size = #cache
    
    if cache_size == 1 and cache.i == 0 then
        -- there was only one solution, and the user is asking for the next
        hints.cache = hints.handler(cache[1], #line() + 1)
        hints.cache.i = -1
        cache = hints.cache
        cache_size = #cache
    end
    
    local change = keyboard.isShiftDown(main_kb) and -1 or 1
    cache.i = (cache.i + change) % math.max(#cache, 1)
    local next = cache[cache.i + 1]
    if next then
        local tail = unicode.len(line()) - #line()
        setline(next)
        local cbx, cby = getCursor()
        setCursor(cbx + #line(), cby)
    end
    end

    local function onKeyDown(char, code)
    term.setCursorBlink(false)
    
    if code == keyboard.keys.tab then
        tab()
    else
        hints.cache = nil
    end
    if code == keyboard.keys.back then
        if left() then delete() end
    elseif code == keyboard.keys.delete then
        delete()
    elseif code == keyboard.keys.left then
        left()
    elseif code == keyboard.keys.right then
        right()
    elseif code == keyboard.keys.home then
        home()
    elseif code == keyboard.keys["end"] then
        ende()
    elseif code == keyboard.keys.up then
        up()
    elseif code == keyboard.keys.down then
        down()
    elseif code == keyboard.keys.enter then
        local cbx, cby = getCursor()
        if cby ~= #history then -- bring entry to front
        history[#history] = line()
        table.remove(history, cby)
        end
        return true, history[#history] .. "\n"
    elseif keyboard.isControlDown() and code == keyboard.keys.d then
        if line() == "" then
        history[#history] = ""
        return true, nil
        end
    elseif keyboard.isControlDown() and code == keyboard.keys.c then
        history[#history] = ""
        return true, nil
    elseif not keyboard.isControl(char) then
        insert(unicode.char(char))
    end
    term.setCursorBlink(true)
    term.setCursorBlink(true) -- force toggle to caret
    end

    local function onClipboard(value)
    copyIfNecessary()
    term.setCursorBlink(false)
    local cbx, cby = getCursor()
    local l = value:find("\n", 1, true)
    if l then
        history[cby] = unicode.sub(line(), 1, cbx - 1)
        redraw()
        insert(unicode.sub(value, 1, l - 1))
        return true, line() .. "\n"
    else
        insert(value)
        term.setCursorBlink(true)
        term.setCursorBlink(true) -- force toggle to caret
    end
    end

    local function cleanup()
    if history[#history] == "" then
        table.remove(history)
    end
    term.setCursorBlink(false)
    if term.getCursor() > 1 and dobreak ~= false then
        print()
    end
    end

    term.setCursorBlink(true)
    while term.isAvailable() do
    local ocx, ocy = getCursor()
    local ok, name, address, charOrValue, code = pcall(event.pull)
    if not ok then
        cleanup()
        error("interrupted", 0)
    end
    local ncx, ncy = getCursor()
    if ocx ~= ncx or ocy ~= ncy then
        cleanup()
        return "" -- soft fail the read if someone messes with the term
    end
    if term.isAvailable() and -- may have changed since pull
        type(address) == "string" and
        component.isPrimary(address)
    then
        local done, result
        if name == "key_down" then
        done, result = onKeyDown(charOrValue, code)
        elseif name == "clipboard" then
        done, result = onClipboard(charOrValue)
        end
        if done then
        cleanup()
        return result
        end
    end
    end
    cleanup()
    return nil -- fail the read if term becomes unavailable
end

function term.write(value, wrap)
    if not term.isAvailable() then
    return
    end
    value = tostring(value)
    if unicode.len(value) == 0 then
    return
    end
    do
    local noBell = value:gsub("\a", "")
    if #noBell ~= #value then
        value = noBell
        computer.beep()
    end
    end
    value = text.detab(value)
    local w, h = component.gpu.getResolution()
    if not w then
    return -- gpu lost its screen but the signal wasn't processed yet.
    end
    local blink = term.getCursorBlink()
    term.setCursorBlink(false)
    local line, nl
    repeat
    local wrapAfter, margin = math.huge, math.huge
    if wrap then
        wrapAfter, margin = w - (cursorX - 1), w
    end
    line, value, nl = text.wrap(value, wrapAfter, margin)
    component.gpu.set(cursorX, cursorY, line)
    cursorX = cursorX + unicode.len(line)
    if nl or (cursorX > w and wrap) then
        cursorX = 1
        cursorY = cursorY + 1
    end
    if cursorY > h then
        component.gpu.copy(1, 1, w, h, 0, -1)
        component.gpu.fill(1, h, w, 1, " ")
        cursorY = h
    end
    until not value
    term.setCursorBlink(blink)
end

function term.pause()
    term.write('Press any key to continue...\n'); term.readKey()
    return
end

return term