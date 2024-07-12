--sfs lib
--This is actually custom functionality, aiming to evolve into a real file system later

local sfs = {}

function sfs.writeSession(proxy, session, compression)

    --set up drive proxy
    local unmanaged_drive = proxy

    --compress data
    if compression and component.isAvailable("data") then
        local compressed_session = {}
        for stream in session do table.insert(compressed_session, component.data.deflate(stream)) end
        session = compressed_session
    end
    
    --calculate full file size
    local full_length = 6 + #session
    for stream in session do full_length = full_length + #stream end

    --check for oversized streams & sessions
    if full_length <= unmanaged_drive.getCapacity() and #session <= 248 then

        --write session header
        local preamble = 'SFS1.0'
        for i = 1, #preamble do unmanaged_drive.writeByte(i, string.byte(preamble[i])) end

        --write session data
        local offset_pointer = 7
        for stream in session do
            for i = 1, #stream do unmanaged_drive.writeByte(offset_pointer, string.byte(stream[i])); offset_pointer = offset_pointer + 1 end
            unmanaged_drive.writeByte(offset_pointer, 0); offset_pointer = offset_pointer + 1
        end
    else error('SFS allocation error: Session too big!') end
end

function sfs.readSession(proxy)

    --set up drive proxy
    local unmanaged_drive = proxy

end