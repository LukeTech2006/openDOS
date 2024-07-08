if not ntkrnl then error("This program can only run in DOS Mode!", 0) end --are we in openNT?
error("App function not available!", 0)

local run = False --debug run switch
local filesystem = component.proxy(fs.drive.letterToProxy('C'))
if run then
  term.setCursorBlink(true)
  term.clear()
  term.write("+-----------------------------+\n|   openNT BIOS Update Tool   |\n|   Version: 0.0.0            |\n+-----------------------------+\n\n")
  if component.isAvailable("internet") then --check if update is possible
    local internet = component.internet
    local eeprom   = component.eeprom
    local biosDump = filesystem.open('bios.dmp', 'w')
    biosDump.write(tostring(eeprom.get()))
    biosDump.close()
    term.write('Dumped current BIOS to C:\\bios.dmp')
    term.write('Current BIOS Version: ' .. eeprom.getData() .. '\n')


  else --abort program if no internet card present
    printErr("Unable to connect to the Update Server, Exiting Program!")
    os.sleep(1)
    term.clear()
    return false
  end
end