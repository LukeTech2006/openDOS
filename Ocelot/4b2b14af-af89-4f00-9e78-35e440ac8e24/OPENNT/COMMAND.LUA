if not ntkrnl then error("This program can only run in DOS Mode!", 0) end --are we in openNT?

local shell = {}
dirPointer = "C:/"

local tArgs={...}
local continue
if tArgs[1] == "-c" then continue = true table.remove(tArgs, 1)
else ntkrnl.cmdBat = nil end

local function intro()
	print("openNT(R) Default Command Interpreter\n             (C)Copyright Lukas Kretschmar - 2022")
end

if not continue then intro() end

local function memtest()
	print("Running Memtest(R)...")
	print(math.floor(computer.totalMemory() / 1024 * 10 + 0.5) /10 .. "KiB RAM present\n" .. math.floor(computer.freeMemory() / 1024 * 10 + 0.5) / 10 .. "KiB RAM available\n")
end

local history = {}
if ntkrnl.cmdHistory then history = ntkrnl.cmdHistory end
if ntkrnl.cmdDrive then fs.drive.setcurrent(ntkrnl.cmdDrive) end

function round(num)
	return math.floor(num + 0.5)
end

local function fixPath(path)
	checkArg(1, path, "string")
	if path:sub(1,1) == '"' and path:sub(-1,-1) == '"' then path = path:sub(2, -2) end
	return path
end

local function runprog(file, parts)
	ntkrnl.cmdHistory = history
	ntkrnl.cmdDrive = fs.drive.getcurrent()
	table.remove(parts, 1)
	error({[1]="INTERRUPT", [2]="RUN", [3]=file, [4]=parts})
end

local function runbat(file, parts)
	if not ntkrnl.cmdBat then ntkrnl.cmdBat = {} end
	local lines = {}
	local line = ""
	local handle = fs.open(file)
	repeat
		local char = fs.read(handle, 1)
		if (char == "\n" or char == nil) then
			lines[#lines+1] = line
			if char == nil then line = nil end
			if char == "\n" then line = "" end
		else line = line .. char end
	until line == nil
	fs.close(handle)

	--for _,l in ipairs(lines) do print(l) end
	ntkrnl.cmdBat[#ntkrnl.cmdBat + 1] = lines
	os.exit(0)
end

local function listdrives()
	for letter, address in fs.drive.list() do
		print(letter, address)
	end
end

local function labels()
	for letter, address in fs.drive.list() do
		print(letter, component.invoke(address, "getLabel") or "")
	end
end

local function label(parts)
	proxy, reason = fs.proxy(parts[2])
	if not proxy then
		print(reason)
		return
	end
	if #parts < 3 then
		print(proxy.getLabel() or "no label")
	else
		local result, reason = proxy.setLabel(parts[3])
		if not result then print(reason or "could not set label") end
	end
end

local function outputFile(file, paged)
  local handle, reason = filesystem.open(file)
  if not handle then
    error(reason, 2)
  end
  local buffer = ""
  repeat
    local data, reason = filesystem.read(handle)
    if not data and reason then
      error(reason)
    end
    buffer = buffer .. (data or "")
  until not data
  filesystem.close(handle)
  if paged then printPaged(buffer)
  else print(buffer) end
end

local function dir(folder)
	local function getDirInsert(file, folder)
		local size_disp
		if folder == nil then folder = dirPointer end
		filepath = folder.."/"..file
		if filesystem.isDirectory(filepath) then size_disp = "<DIR>" else
			local tempfile = fs.open(filepath)
			local tempsize = tempfile:seek("end", 0)
			if tempsize < 1024 then size_disp = tempsize .. " B" end
			if tempsize > 1024 and tempsize < 1048576 then size_disp = (round(tempsize / 1024 * 10) / 10) .. " KiB" end
			if tempsize > 1048576 and tempsize < 1073741824 then size_disp = (round(tempsize / 1048576 * 10) / 10) .. " MiB" end
		end
		for i = 0, 10 - #size_disp, 1 do
			size_disp = size_disp.." "
		end return size_disp.."| "
	end
	--we will have to get the current dir
	if folder ~= nil then folder = dirPointer..folder else folder = dirPointer end
	--is it a directory?
	if not fs.isDirectory(folder, folder) then print("No such folder.") return end
	--if it is we start...
	local output = ""
	--put the list of files into a massive string
	for file in filesystem.list(folder) do
		output = output .. "|" .. getDirInsert(file, folder) .. file .. "\n"
	end
	--get rid of the last newline
	--output = output:sub(0, -2)
	--get rid of folder postfixes
	output = output:gsub("/", "")
	--we want the output to be paged
	printPaged("+-----------+----------------\n|Size       | File Name\n+-----------+----------------\n|<DIR>      | .\n|<DIR>      | ..\n"..output.."+-----------+----------------")
end

local function changeDir(relPath)
	if relPath == ".." then
		if #dirPointer > 3 then --check if we are actually in a subdirectory, else return
			local newPath = {}
			for word in dirPointer:gmatch('[^/%s]+') do --break up pointer, going "up" one directory
				table.insert(newPath, word)
			end
			table.remove(newPath, #newPath)
			dirPointer = table.concat(newPath, "/").."/" --create new pointer
			return
		else return end
	end
	if relPath ~= "." then
		if filesystem.isDirectory(dirPointer..relPath) and filesystem.exists(dirPointer..relPath) then
			dirPointer = dirPointer..relPath.."/"
		else printErr("Folder does not exist.") end
	end
end

local function moveFile(from, to, force)
	checkArg(1, from, "string")
	checkArg(2, to, "string")
	if fs.isDirectory(to) then
	    if not fs.name then error("Need to specify name for destination!", 0) end
		to = to .. "/" .. fs.name(from)
    end
	if fs.exists(to) then
		if not force then
			printErr("Target file already exists!")
			return
		end
		fs.remove(to)
	end
	local result, reason = fs.rename(from, to)
	if not result then
		error(reason or "Unknown Error!", 0)
	end
end

local function copyFile(from, to, force)
	checkArg(1, from, "string")
	checkArg(2, to, "string")
	if fs.isDirectory(to) then
	    if not fs.name then error("Need to specify name for destination!", 0) end
		to = to .. "/" .. fs.name(from)
    end
	if fs.exists(to) then
		if not force then
			printErr("Target file already exists!")
			return
		end
		fs.remove(to)
	end
	local result, reason = fs.copy(from, to)
	if not result then
		error(reason or "Unknown Error!", 0)
	end
end

local function twoFileCommandHelper(run, parts)
	if #parts >= 3 then
		if parts[2] == "-f" then
			table.remove(parts, 2)
			run(fixPath(parts[2]), fixPath(parts[3]), true)
			return true
		else
			run(fixPath(parts[2]), fixPath(parts[3]))
			return true
		end
	else printErr("Bad Parameters!") return true end
end

local function runline(line)
	
	checkArg(1, line, "string", "nil")
	--print(line)
	line = text.trim(line)
	if line == "" then return true end
	parts = text.tokenize(line)
	command = string.lower(text.trim(parts[1]))

	--blank commands
	if command == "" then return true end
	if command == nil then return true end

	--drive selector
	if #command == 2 then if string.sub(command, 2, 2) == ":" then filesystem.drive.setcurrent(string.sub(command, 1, 1)) return true end end

	--internal commands
	if command == "exit" then history = {} return "exit" end
	if command == "cls" then term.clear(); term.gpu().setForeground(0xFFFFFF); term.gpu().setBackground(0x000000) return true end
	if command == "ver" then print(_OSVERSION) return true end
	if command == "whoami" then print('NT-AUTHORITY/SYSTEM') return true end
	if command == "mem" then memtest() return true end
	if command == "dir" then if parts[2] then dir(fixPath(parts[2])) else dir() end return true end
	if command == "cd" then if parts[2] then changeDir(fixPath(parts[2])) end return true end
	if command == "intro" then intro() return true end
	if command == "disks" then listdrives() return true end
	if command == "drives" then listdrives() return true end
	if command == "labels" then labels() return true end
	if command == "scndrv" then filesystem.drive.scan() return true end
	if command == "label" then if parts[2] then label(parts) return true else printErr("Invalid Parameters") return false end end
	if command == "type" then outputFile(fixPath(parts[2])) return true end
	if command == "more" then outputFile(fixPath(parts[2]), true) return true end
	if command == "echo" then print(table.concat(parts, " ", 2)) return true end
	if command == "print" then print(table.concat(parts, "\t", 2)) return true end
	if command == "touch" then filesystem.close(filesystem.open(fixPath(parts[2]), 'w')) return true end
	if command == "del" then if filesystem.remove(fixPath(parts[2])) then return true else error("Can't delete!",0) end end
	if command == "copy" then return twoFileCommandHelper(copyFile, parts) end
	if command == "rename" then return twoFileCommandHelper(moveFile, parts) end
	if command == "ren" then return twoFileCommandHelper(moveFile, parts) end
	if command == "move" then return twoFileCommandHelper(moveFile, parts) end
  	if command == "mkdir" then return filesystem.makeDirectory(fixPath(dirPointer..parts[2])) end
	if command == "edit" then return runprog("C:/opennt/edit.lua", parts) end
	if command == "shutdown" then return runprog("C:/opennt/shutdown.lua", parts) end
	if command == "cmds" then printPaged([[
Internal Commands:
exit ----- Exit the command interpreter.
cls ------ Clears the screen.
ver ------ Outputs version information.
whoami---- Outputs your current user.
mem ------ Outputs memory information.
dir ------ Lists the files on the current disk or a path.
cd ------- Changes the current directory. 
cmds ----- Lists the commands.
intro ---- Outputs the introduction message.
drives --- Lists the drives and their addresses.
labels --- Lists the drives and their labels.
scndrv --- Updates the drive list.
label ---- Sets the label of a drive.
echo ----- Outputs its arguments.
type ----- Like echo, but outputs a file.
more ----- Like type, but the output is paged.
touch ---- Creates a file.
del ------ Deletes a file.
copy ----- Copies a file.
move ----- Moves a file.
ren ------ Renames a file.
mkdir ---- Creates a directory.
shutdown - Shuts down the computer.
edit ----- Opens a simple Text Editor. Takes an absolute Path.]]) printPaged() return true end

  --external commands and programs
	command = parts[1]
	if filesystem.exists(command) then
		if not filesystem.isDirectory(command) then
			if text.endswith(command, ".lua") then runprog(command, parts) return true end
			if text.endswith(command, ".bat") then runbat(command, parts) return true end
			runprog(command, parts) return true
		end
	end
	if filesystem.exists(command .. ".lua")  then
		if not filesystem.isDirectory(command .. ".lua") then
			runprog(command .. ".lua", parts)
			return true
		end
	end
	if filesystem.exists(command .. ".bat") then
		if not filesystem.isDirectory(command .. ".bat") then
			runbat(command .. ".bat", parts)
			return true
		end
	end

	print("Bad command or file name")
	return false
end

function shell.runline(line)
	local result = table.pack(pcall(runline, line))
	if result[1] then
		return table.unpack(result, 2, result.n)
	else
		if type(result[2]) == "table" then if result[2][1] == "INTERRUPT" then error(result[2]) end end
		printErr("ERROR:", result[2])
	end
end

if shell.runline(table.concat(tArgs, " ")) == "exit" then return end

local cmds = {"exit", "cls", "ver", "mem", "dir ", "cd", "cmds", "intro", "drives", "labels", "echo ", "type ", "more ", "touch", "del ", "copy ", "move ", "ren ", "mkdir ", "edit "}

while true do
	if ntkrnl.cmdBat and #ntkrnl.cmdBat == 0 then
		ntkrnl.cmdBat = nil
	end

	local line
	if ntkrnl.cmdBat then
		while #ntkrnl.cmdBat > 0 do
			repeat
				line = ntkrnl.cmdBat[#ntkrnl.cmdBat][1]
				if line == nil then
					ntkrnl.cmdBat[#ntkrnl.cmdBat] = nil
					line = ""
				else
					table.remove(ntkrnl.cmdBat[#ntkrnl.cmdBat], 1)
				end
			until line ~= "" or #ntkrnl.cmdBat <= 0
			if line ~= "" then break end
		end
	else
		term.write(dirPointer .. ">")
		line = term.read(history, nil, function(line, pos)
      		local filtered = {}
      
      		local space = string.match(line, '^.*() ')
      
      		if space == nil then
        		for _,option in ipairs(cmds) do
          			if string.sub(option, 1, #line) == line then
            			filtered[#filtered + 1] = option
          			end
        		end
      		end
      
      		local preline
      		if space ~= nil then
        		preline = string.sub(line, 1, space)
        		line = string.sub(line, space + 1)
      		else
        		preline = ""
      		end
      		local path
      		local dirsep = string.match(line, '^.*()/')
      		if dirsep ~= nil then
        		path = string.sub(line, 1, dirsep)
      		else path = "" end
      
      		for file in fs.list(path) do
        		file = path .. file
        		if string.sub(file, 1, #line) == line and string.sub(file, -1) == '/' then
          		filtered[#filtered + 1] = preline .. file
        		elseif string.sub(file, 1, #line) == line and (string.sub(file, -4) == '.lua' or string.sub(file, -4) == '.bat') then
          		filtered[#filtered + 1] = preline .. file .. ' '
        		end
      		end
      		return filtered
    	end)
		while #history > 10 do
			table.remove(history, 1)
		end
	end
	if shell.runline(line) == "exit" then
		if ntkrnl.cmdBat then ntkrnl.cmdBat[#ntkrnl.cmdBat] = nil end
		return true
	end
end
