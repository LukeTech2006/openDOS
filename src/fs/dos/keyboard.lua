--keyboard lib

local keyboard_data = {}
keyboard_data.keys = {
  ["1"]           = 0x02,
  ["2"]           = 0x03,
  ["3"]           = 0x04,
  ["4"]           = 0x05,
  ["5"]           = 0x06,
  ["6"]           = 0x07,
  ["7"]           = 0x08,
  ["8"]           = 0x09,
  ["9"]           = 0x0A,
  ["0"]           = 0x0B,
  a               = 0x1E,
  b               = 0x30,
  c               = 0x2E,
  d               = 0x20,
  e               = 0x12,
  f               = 0x21,
  g               = 0x22,
  h               = 0x23,
  i               = 0x17,
  j               = 0x24,
  k               = 0x25,
  l               = 0x26,
  m               = 0x32,
  n               = 0x31,
  o               = 0x18,
  p               = 0x19,
  q               = 0x10,
  r               = 0x13,
  s               = 0x1F,
  t               = 0x14,
  u               = 0x16,
  v               = 0x2F,
  w               = 0x11,
  x               = 0x2D,
  y               = 0x15,
  z               = 0x2C,

  apostrophe      = 0x28,
  at              = 0x91,
  back            = 0x0E, -- backspace
  backslash       = 0x2B,
  colon           = 0x92,
  comma           = 0x33,
  enter           = 0x1C,
  equals          = 0x0D,
  grave           = 0x29, -- accent grave
  lbracket        = 0x1A,
  lcontrol        = 0x1D,
  lmenu           = 0x38, -- left Alt
  lshift          = 0x2A,
  minus           = 0x0C,
  numlock         = 0x45,
  pause           = 0xC5,
  period          = 0x34,
  rbracket        = 0x1B,
  rcontrol        = 0x9D,
  rmenu           = 0xB8, -- right Alt
  rshift          = 0x36,
  scroll          = 0x46, -- Scroll Lock
  semicolon       = 0x27,
  slash           = 0x35, -- / on main keyboard
  space           = 0x39,
  stop            = 0x95,
  tab             = 0x0F,
  underline       = 0x93,

  -- Keypad (and numpad with numlock off)
  up              = 0xC8,
  down            = 0xD0,
  left            = 0xCB,
  right           = 0xCD,
  home            = 0xC7,
  ["end"]         = 0xCF,
  pageUp          = 0xC9,
  pageDown        = 0xD1,
  insert          = 0xD2,
  delete          = 0xD3,

  -- Function keys
  f1              = 0x3B,
  f2              = 0x3C,
  f3              = 0x3D,
  f4              = 0x3E,
  f5              = 0x3F,
  f6              = 0x40,
  f7              = 0x41,
  f8              = 0x42,
  f9              = 0x43,
  f10             = 0x44,
  f11             = 0x57,
  f12             = 0x58,
  f13             = 0x64,
  f14             = 0x65,
  f15             = 0x66,
  f16             = 0x67,
  f17             = 0x68,
  f18             = 0x69,
  f19             = 0x71,

  -- Japanese keyboards
  kana            = 0x70,
  kanji           = 0x94,
  convert         = 0x79,
  noconvert       = 0x7B,
  yen             = 0x7D,
  circumflex      = 0x90,
  ax              = 0x96,

  -- Numpad
  numpad0         = 0x52,
  numpad1         = 0x4F,
  numpad2         = 0x50,
  numpad3         = 0x51,
  numpad4         = 0x4B,
  numpad5         = 0x4C,
  numpad6         = 0x4D,
  numpad7         = 0x47,
  numpad8         = 0x48,
  numpad9         = 0x49,
  numpadmul       = 0x37,
  numpaddiv       = 0xB5,
  numpadsub       = 0x4A,
  numpadadd       = 0x4E,
  numpaddecimal   = 0x53,
  numpadcomma     = 0xB3,
  numpadenter     = 0x9C,
  numpadequals    = 0x8D,
}

local keyboard = {pressedChars = {}, pressedCodes = {}, keys = keyboard_data.keys}

-- Create inverse mapping for name lookup.
setmetatable(keyboard.keys, {
__index = function(tbl, k)
    if type(k) ~= "number" then return end
    for name,value in pairs(tbl) do
    if value == k then
        return name
    end
    end
end
})

local function getKeyboardAddress(address)
return address or term.keyboard()
end

local function getPressedCodes(address)
address = getKeyboardAddress(address)
return address and keyboard.pressedCodes[address] or false
end

local function getPressedChars(address)
address = getKeyboardAddress(address)
return address and keyboard.pressedChars[address] or false
end

function keyboard.isAltDown(address)
checkArg(1, address, "string", "nil")
local pressedCodes = getPressedCodes(address)
return pressedCodes and (pressedCodes[keyboard.keys.lmenu] or pressedCodes[keyboard.keys.rmenu]) ~= nil
end

function keyboard.isControl(char)
return type(char) == "number" and (char < 0x20 or (char >= 0x7F and char <= 0x9F))
end

function keyboard.isControlDown(address)
checkArg(1, address, "string", "nil")
local pressedCodes = getPressedCodes(address)
return pressedCodes and (pressedCodes[keyboard.keys.lcontrol] or pressedCodes[keyboard.keys.rcontrol]) ~= nil
end

function keyboard.isKeyDown(charOrCode, address)
checkArg(1, charOrCode, "string", "number")
checkArg(2, address, "string", "nil")
if type(charOrCode) == "string" then
    local pressedChars = getPressedChars(address)
    return pressedChars and pressedChars[utf8 and utf8.codepoint(charOrCode) or charOrCode:byte()]
elseif type(charOrCode) == "number" then
    local pressedCodes = getPressedCodes(address)
    return pressedCodes and pressedCodes[charOrCode]
end
end

function keyboard.isShiftDown(address)
checkArg(1, address, "string", "nil")
local pressedCodes = getPressedCodes(address)
return pressedCodes and (pressedCodes[keyboard.keys.lshift] or pressedCodes[keyboard.keys.rshift]) ~= nil
end

local function onKeyDown(_, address, char, code)
if keyboard.pressedChars[address] then
    keyboard.pressedChars[address][char] = true
    keyboard.pressedCodes[address][code] = true
end
end

local function onKeyUp(_, address, char, code)
if keyboard.pressedChars[address] then
    keyboard.pressedChars[address][char] = nil
    keyboard.pressedCodes[address][code] = nil
end
end

local function onComponentAdded(_, address, componentType)
if componentType == "keyboard" then
    keyboard.pressedChars[address] = {}
    keyboard.pressedCodes[address] = {}
end
end

local function onComponentRemoved(_, address, componentType)
if componentType == "keyboard" then
    keyboard.pressedChars[address] = nil
    keyboard.pressedCodes[address] = nil
end
end

for address in component.list("keyboard", true) do
onComponentAdded("component_added", address, "keyboard")
end

event.listen("key_down", onKeyDown)
event.listen("key_up", onKeyUp)
event.listen("component_added", onComponentAdded)
event.listen("component_removed", onComponentRemoved)

return keyboard