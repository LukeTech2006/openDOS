--filesystem lib

local filesystem = {}
filesystem.drive = {}

--drive mapping table, initilized later
filesystem.drive._map = {}

--converts a drive letter into a proxy
function filesystem.drive.letterToProxy(letter)
    return filesystem.drive._map[letter]
end

--finds the proxy associated with the letter
function filesystem.drive.proxyToLetter(proxy)
    for l,p in pairs(filesystem.drive._map) do
        if p == proxy then return l end
    end
    return nil
end

--maps a proxy to a letter
function filesystem.drive.mapProxy(letter, proxy)
    filesystem.drive._map[letter] = proxy
end

--finds the address of a drive letter.
function filesystem.drive.toAddress(letter)
    return filesystem.drive._map[letter].address
end

--finds the drive letter mapped to an address
function filesystem.drive.toLetter(address)
    for l,p in pairs(filesystem.drive._map) do
        if p.address == address then return l end
    end
    return nil
end

function filesystem.drive.mapAddress(letter, address)
    --print("mapAddress")
    if address == nil then filesystem.drive._map[letter] = nil
    else filesystem.drive._map[letter] = filesystem.proxy(address) end
end

function filesystem.drive.autoMap(address) --returns the letter if mapped OR already mapped, false if not.
    --print("autoMap")
    --we get the address and see if it already is mapped...
    local l = filesystem.drive.toLetter(address)

    if l then return l end
    --then we take the address and attempt to map it
    --start at C:	
    l = "C"
        while true do
            --see if it is mapped and then go to the next letter...
            if filesystem.drive._map[l] then l = ('CABDEFGHIJKLMNOPQRSTUVWXYZ_'):match(l..'(.)') else filesystem.drive.mapAddress(l, address) return l end
            
        --if we got to the end, fail
            if l == "_" then return false end
        end
end

function filesystem.drive.listProxy()
    local t = filesystem.drive._map
    local p = {}
    for n in pairs(t) do table.insert(p, n) end
    table.sort(p, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
    i = i + 1
    if p[i] == nil then return nil
    else return p[i], t[p[i]]
    end
    end
    return iter
end

function filesystem.drive.list()
    local i = 0      -- iterator variable
    local proxyIter = filesystem.drive.listProxy()
    local iter = function ()   -- iterator function
    l, p = proxyIter()
    if not l then return nil end
    return l, p.address
    end
    return iter
end

filesystem.drive._current = "C" --as the boot drive is C:

function filesystem.drive.setcurrent(letter)
    letter = letter:upper()
    if not filesystem.drive._map[letter] then error("Invalid Drive", 2) end
    filesystem.drive._current = letter
end

function filesystem.drive.drivepathSplit(mixed)
    local drive = filesystem.drive._current
    local path
    if string.sub(mixed, 2,2) == ":" then
    drive = string.sub(mixed, 1,1):upper()
    path = string.sub(mixed, 3)
    else
    path = mixed
    end
    return drive, path
end

function filesystem.drive.getcurrent() return filesystem.drive._current end

function filesystem.drive.scan()
    local to_remove = {}
    for letter,proxy in pairs(filesystem.drive._map) do
    if component.type(proxy.address) == nil then
        to_remove[#to_remove + 1] = letter
    end
    end
    for _,l in ipairs(to_remove) do
    filesystem.drive._map[l] = nil
    end
    for address, componentType in component.list() do 
    if componentType == "filesystem" then filesystem.drive.autoMap(address) end
    end
end

function filesystem.invoke(method, ...) return filesystem.drive._map[filesystem.drive._current][method](...) end

function filesystem.proxy(filter)
    checkArg(1, filter, "string")
    local address
    for c in component.list("filesystem") do
    if component.invoke(c, "getLabel") == filter then
        address = c
        break
    end
    if filter:sub(2,2) == ":" then
        if filesystem.drive.toAddress(filter:sub(1,1)) == c then address = c break end
    end
    if c:sub(1, filter:len()) == filter then
        address = c
        break
    end
    end
    if not address then
    return nil, "no such file system"
    end
    return component.proxy(address)
end

function filesystem.open(file, mode)
    local drive, handle, proxy
    drive, path = filesystem.drive.drivepathSplit(file)
    proxy = filesystem.drive.letterToProxy(drive)
    handle, reason = proxy.open(path, mode or 'r')
    if not handle then return nil, reason end
    return setmetatable({_handle = handle, _proxy = proxy}, {__index = fs})
end

function filesystem.write(handle, data) return handle._proxy.write(handle._handle, data) end

function filesystem.read(handle, length) return handle._proxy.read(handle._handle, length or math.huge) end

function filesystem.seek(handle, whence, offset) return handle._proxy.seek(handle._handle, whence, offset) end

function filesystem.close(handle) return handle._proxy.close(handle._handle) end

function filesystem.isDirectory(path)
    local drive
    drive, path = filesystem.drive.drivepathSplit(path)
    return filesystem.drive.letterToProxy(drive).isDirectory(path)
end

function filesystem.exists(path)
    local drive
    drive, path = filesystem.drive.drivepathSplit(path)
    return filesystem.drive.letterToProxy(drive).exists(path)
end

function filesystem.remove(path)
    local drive
    drive, path = filesystem.drive.drivepathSplit(path)
    return filesystem.drive.letterToProxy(drive).remove(path)
end

function filesystem.copy(fromPath, toPath)
    if filesystem.isDirectory(fromPath) then
    return nil, "cannot copy folders"
    end
    local input, reason = filesystem.open(fromPath, "rb")
    if not input then
    return nil, reason
    end
    local output, reason = filesystem.open(toPath, "wb")
    if not output then
    filesystem.close(input)
    return nil, reason
    end
    repeat
    local buffer, reason = filesystem.read(input)
    if not buffer and reason then
        return nil, reason
    elseif buffer then
        local result, reason = filesystem.write(output, buffer)
        if not result then
        filesystem.close(input)
        filesystem.close(output)
        return nil, reason
        end
        end
    until not buffer
    filesystem.close(input)
    filesystem.close(output)
    return true
end

function filesystem.rename(path1, path2)
    local drive
    drive, path = filesystem.drive.drivepathSplit(path)
    return filesystem.drive.letterToProxy(drive).rename(path1, path2)
end

function filesystem.makeDirectory(path)
    local drive
    drive, path = filesystem.drive.drivepathSplit(path)
    return filesystem.drive.letterToProxy(drive).makeDirectory(path)
end

function filesystem.list(path)
    local drive
    drive, path = filesystem.drive.drivepathSplit(path)
    local i = 0
    local t = filesystem.drive.letterToProxy(drive).list(path)
    local n = #t
    return function()
    i = i + 1
    if i <= n then return t[i] end
    return nil end
end

function filesystem.get(path)
    local drive
    drive, path = filesystem.drive.drivepathSplit(path)
    drive = filesystem.drive.letterToProxy(drive)
    if not drive then return nil, "no such file system"
    else return drive, path end
end

--handle inserted and removed filesystems
local function onComponentAdded(_, address, componentType)
    if componentType == "filesystem" then
        filesystem.drive.autoMap(address)
    end
end
local function onComponentRemoved(_, address, componentType)
    if componentType == "filesystem" then
    filesystem.drive.mapAddress(filesystem.drive.toLetter(address), nil)
    end
end

event.listen("component_added", onComponentAdded)
event.listen("component_removed", onComponentRemoved)

local function driveInit()
    local boot = filesystem.proxy(computer.getBootAddress())
    local temp = filesystem.proxy(computer.tmpAddress())
    filesystem.drive._map = { ["C"]=boot, ["X"]=temp } 
end

driveInit()
return filesystem