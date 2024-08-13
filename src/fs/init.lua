local boot_fs = component.proxy(computer.getBootAddress())
local boot_term = component.proxy(component.list("gpu")())
if not component.list("data")() then error("No decompression available! Please install a data card!") end

function kernelDecompress(fs_address, filehandle)
    local data_card = component.proxy(component.list("data")())
    local maxDecompSize = data_card.getLimit()
    local buffer = ""
    repeat
        local data, reason = component.invoke(fs_address, "read", filehandle, math.huge)
        if not data and reason then return nil, reason end
        buffer = buffer .. (data or "")
    until not data
    if #buffer > maxDecompSize then error("Insufficient decompression capacity! Please upgrade your data card!") end
    return data_card.inflate(buffer)
end

boot_term.set(1, 1, "Decompressing kernel...")
local kernelFile = boot_fs.open("dos/kernel.clf", "r")
local kernel_func = load(kernelDecompress(computer.getBootAddress(), kernelFile))

return kernel_func()