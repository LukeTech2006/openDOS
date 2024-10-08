_G._OSNAME = "openDOS"
_G._OSVER = "A.0.5"
_G._OSVERSION = _OSNAME .. " " .. _OSVER
_G._OSCREDIT = "A Disc Operating System, based off of miniOS classic by Skye.\nminiOS code is under BSD 2-clause licence."
kernel = {}


local function printProcess(...)
  local args = table.pack(...)
  local argstr = ""
  for i = 1, args.n do
    local arg = tostring(args[i])
    if i > 1 then
      arg = "\t" .. arg
    end
    argstr = argstr .. arg
  end
  return argstr
end

function print(...)
  term.write(printProcess(...) .. "\n", true)
end

function printErr(...)
		local c = component.gpu.getForeground()
		component.gpu.setForeground(0xFF0000)
		print(...)
		component.gpu.setForeground(c)
end

function printPaged(...)
  argstr = printProcess(...) .. "\n"
  local i = 0
  local p = 0
  function readline()
    i = string.find(argstr, "\n", i+1)    -- find 'next' newline
    if i == nil then return nil end
	local out = argstr:sub(p,i)
	p = i + 1
    return out
  end
  local function readlines(file, line, num)
    local w, h = component.gpu.getResolution()
    num = num or (h - 1)
	--num = num or (h)
    term.setCursorBlink(false)
    for _ = 1, num do
      if not line then
        line = readline()
        if not line then -- eof
          return nil
        end
      end
      local wrapped
      wrapped, line = text.wrap(text.detab(line), w, w)
      term.write(wrapped .. "\n")
    end
    term.setCursor(1, h)
    term.write("Press enter or space to continue:")
    term.setCursorBlink(true)
    return true
  end

  local line = nil
  while true do
    if not readlines(file, line) then
      return
    end
    while true do
      local event, address, char, code = event.pull("key_down")
      if component.isPrimary(address) then
        if code == keyboard.keys.q then
          term.setCursorBlink(false)
          term.clearLine()
          return
        elseif code == keyboard.keys.space or code == keyboard.keys.pageDown then
		  term.clearLine()
          break
        elseif code == keyboard.keys.enter or code == keyboard.keys.down then
          term.clearLine()
          if not readlines(file, line, 1) then
            return
          end
        end
      end
    end
  end
end

function loadfile(file, mode, env)
  if mode == nil then mode = 'r' end
  if env == nil then env = _G end
  local handle, reason = filesystem.open(file, mode)
  if not handle then
    error(file..':'..reason, 2)
  end
  local buffer = ""
  repeat
    local data, reason = filesystem.read(handle, math.huge)
    if not data and reason then
      error(file..':'..reason)
    end
    buffer = buffer .. (data or "")
  until not data
  filesystem.close(handle)
  return load(buffer, "=" .. file)
end

function dofile(file)
  local program, reason = loadfile(file)
  if program then
    local result = table.pack(pcall(program))
    if result[1] then
      return table.unpack(result, 2, result.n)
    else
      error(file..':'..result[2])
    end
  else
    error(file..':'..reason)
  end
end

local function selftest()
  term.setCursorBlink(false)

  kernel.mem_inst = math.floor(computer.totalMemory() / 1024 + 0.5)
  print('CPU Architecture: '..computer.getArchitecture()..'\nMemory installed: '..kernel.mem_inst..' KiB')
  os.sleep(0.5)

  print('\nComponents attached:')
  local maxName = 0
  for _, name in pairs(component.list()) do if #name > maxName then maxName = #name end end
  for address, name in pairs(component.list()) do print(text.padRight(name, maxName).." -> "..address) end
  print()
  
  os.sleep(1)
  term.setCursorBlink(true)
end

local function interrupt(data)
  --print("INTERRUPT!")
  if data[2] == "RUN" then return kernel.runfile(data[3], table.unpack(data[4])) end
  if data[2] == "ERR" then error("Debug Error!") end
  if data[2] == "EXIT" then return data[3] end
end

local function runfile(file, ...)
  local program, reason = loadfile(file)
  if program then
    local targs = {...}
	local traceback
    local result = table.pack(xpcall(program,
	  function(err) traceback = debug.traceback(nil, 2); return err end,
    ...))
  --os.sleep(0)
	if traceback then
		local function dropsame(s1,s2)
			t1,t2={},{}
			for l in s1:gmatch("(.-)\n") do t1[#t1+1] = l end
			for l in s2:gmatch("(.-)\n") do t2[#t2+1] = l end
			for i = #t1,1,-1 do
				if t1[i] == t2[i] then
					t1[i] = nil
					t2[i] = nil
				else
					break
				end
			end
			os1,os2 = "",""
			for k,v in ipairs(t1) do
				os1 = os1 .. v .. "\n"
			end
			for k,v in ipairs(t2) do
				os2 = os2 .. v .. "\n"
			end
			return os1,os2
		end
	  traceback = dropsame(traceback, debug.traceback(nil, 2)) .. "\t..."
	end
    if result[1] then
      return table.unpack(result, 2, result.n)
    else
	  if type(result[2]) == "table" then if result[2][1] then if result[2][1] == "INTERRUPT" then
	    result = {interrupt(result[2])}
		return
	  end end end
      error(result[2] .. "\n" .. traceback, 3)
    end
  else
    error(reason, 3)
  end
end

local function kernelError()
  printErr("\nPress any key to try again.")
  term.readKey()
end

function kernel.saferunfile(...)
  local r = {pcall(runfile, ...)}
  if not r[1] then
	local c = component.gpu.getForeground()
	component.gpu.setForeground(0xFF0000)
	printPaged(r[2])
	component.gpu.setForeground(c)
  end
  return r
end

function kernel.runfile(...)
 local r = kernel.saferunfile(...)
 return table.unpack(r, 2, r.n)
end

local function tryrunlib(lib)
	local ret
	local opt = {lib .. ".lua", lib}
	for _,o in ipairs(opt) do
		if fs.exists(o) then
			return kernel.runfile(o)
		end
	end
	error("Can't find the library specified: `" .. lib .. "`", 3)
end

function require(lib)
	return _G[lib] or _G[string.lower(lib)] or tryrunlib(lib)
end

local function shellrun(...)
	local success = kernel.saferunfile(...)[1]
  if not success then
    printErr("\nError in running file.")
		return false
	end
	return true
end

function runFileComp(drive_proxy, filepath)
  local file_handle = drive_proxy.open(filepath, "r")
  local run_func = kernelDecompress(drive_proxy.address, file_handle)
  return load(run_func, "="..filepath)()
end

--set up libs
local boot_fs = component.proxy(computer.getBootAddress())
event = runFileComp(boot_fs, 'dos/event.clf')
component = runFileComp(boot_fs, 'dos/component.clf')
text = runFileComp(boot_fs, 'dos/text.clf')
filesystem = runFileComp(boot_fs, 'dos/filesystem.clf')
keyboard = runFileComp(boot_fs, 'dos/keyboard.clf')
term = runFileComp(boot_fs, 'dos/term.clf')
sfs = runFileComp(boot_fs, 'dos/sfs.clf')
fs = filesystem

--set os vars
kernel.freeMem = computer.freeMemory() --compatibility

-- set up other functions...
function os.sleep(timeout)
  checkArg(1, timeout, "number", "nil")
  local deadline = computer.uptime() + (timeout or 0)
  repeat
    event.pull(deadline - computer.uptime())
  until computer.uptime() >= deadline
end

function os.exit(code)
  error({[1]="INTERRUPT", [2]="EXIT", [3]=code})
end

--set up terminal
if term.isAvailable() then
  component.gpu.bind(component.screen.address)
  component.gpu.setResolution(component.gpu.getResolution())
  component.gpu.setBackground(0x000000)
  component.gpu.setForeground(0xFFFFFF)
  term.setCursorBlink(true)
  term.clear()
end

--execute POST
print("Decompressing kernel...\n\nHello from ".._OSVERSION.." kernel!\n")
selftest()

--rescan fs
filesystem.drive.scan() 

--start shell
local fallback_drive = filesystem.drive.getcurrent()
kernel.base_shell = true

while true do
  filesystem.drive.setcurrent(fallback_drive)
  shell_file_handle = component.proxy(computer.getBootAddress()).open("dos/shell.clf", "r")
  if not load(kernelDecompress(computer.getBootAddress(), shell_file_handle), "=dos/shell.clf")() then term.pause() end
end