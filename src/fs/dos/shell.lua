if not kernel then error('This program can only run in DOS mode!') end

--set up shell system environment (1st shell is system shell)
base_shell = false
if kernel.base_shell then
    base_shell = true
    kernel.base_shell = false
end

term.clear()
print("openDOS Command Interpreter\n(C) Lukas Kretschmar\n")
local running = true
while running do
    term.write(filesystem.drive.getcurrent()..":\\> ")
    local line = term.read()
end

--if system shell: halt, else: return to upper shell
if base_shell then
    print('System halted!')
    os.sleep(math.huge)
end