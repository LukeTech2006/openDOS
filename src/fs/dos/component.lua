--component lib

local adding = {}
local removing = {}
local primaries = {}

-- This allows writing component.modem.open(123) instead of writing
-- component.getPrimary("modem").open(123), which may be nicer to read.
setmetatable(component, { __index = function(_, key)
    return component.getPrimary(key)
end})

function component.get(address, componentType)
    checkArg(1, address, "string")
    checkArg(2, componentType, "string", "nil")
    for c in component.list(componentType, true) do
    if c:sub(1, address:len()) == address then
        return c
    end
    end
    return nil, "no such component"
end

function component.isAvailable(componentType)
    checkArg(1, componentType, "string")
    if not primaries[componentType] then
    -- This is mostly to avoid out of memory errors preventing proxy
    -- creation cause confusion by trying to create the proxy again,
    -- causing the oom error to be thrown again.
    component.setPrimary(componentType, component.list(componentType, true)())
    end
    return primaries[componentType] ~= nil
end

function component.isPrimary(address)
    local componentType = component.type(address)
    if componentType then
    if component.isAvailable(componentType) then
        return primaries[componentType].address == address
    end
    end
    return false
end

function component.getPrimary(componentType)
    checkArg(1, componentType, "string")
    assert(component.isAvailable(componentType),
    "No primary '" .. componentType .. "' available")
    return primaries[componentType]
end

function component.setPrimary(componentType, address)
    checkArg(1, componentType, "string")
    checkArg(2, address, "string", "nil")
    if address ~= nil then
    address = component.get(address, componentType)
    assert(address, "No such component")
    end

    local wasAvailable = primaries[componentType]
    if wasAvailable and address == wasAvailable.address then
    return
    end
    local wasAdding = adding[componentType]
    if wasAdding and address == wasAdding.address then
    return
    end
    if wasAdding then
    event.cancel(wasAdding.timer)
    end
    primaries[componentType] = nil
    adding[componentType] = nil

    local primary = address and component.proxy(address) or nil
    if wasAvailable then
    computer.pushSignal("component_unavailable", componentType)
    end
    if primary then
    if wasAvailable or wasAdding then
        adding[componentType] = {
        address=address,
        timer=event.timer(0.1, function()
            adding[componentType] = nil
            primaries[componentType] = primary
            computer.pushSignal("component_available", componentType)
        end)
        }
    else
        primaries[componentType] = primary
        computer.pushSignal("component_available", componentType)
    end
    end
end

local function onComponentAdded(_, address, componentType)
    if not (primaries[componentType] or adding[componentType]) then
    component.setPrimary(componentType, address)
    end
end

local function onComponentRemoved(_, address, componentType)
    if primaries[componentType] and primaries[componentType].address == address or
    adding[componentType] and adding[componentType].address == address
    then
    component.setPrimary(componentType, component.list(componentType, true)())
    end
end

event.listen("component_added", onComponentAdded)
event.listen("component_removed", onComponentRemoved)

return component