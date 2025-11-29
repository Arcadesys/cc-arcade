-- button_debug_test.lua
-- Pure-Lua harness for button_debug.lua without CraftOS/CC:Tweaked.
-- Mocks the CraftOS APIs and feeds a short sequence of key/redstone events.
-- Run with: lua button_debug_test.lua (do NOT run this on CraftOS)

-- Skip immediately if executed inside CraftOS/CC:Tweaked to avoid clobbering its APIs.
do
  local host = _G._HOST or (type(os) == "table" and os.version and os.version()) or ""
  if host:find("CraftOS") or host:find("CC:T") then
    print("button_debug_test.lua is desktop-only. On CraftOS, run button_debug.lua instead.")
    return
  end
end

--------------------------------------------------
-- Config: screen size + event sequence to play --
--------------------------------------------------

local SCREEN_W, SCREEN_H = 50, 12

-- keys.* codes used by button_debug.lua
keys = { a = 1, s = 2, d = 3, f = 4, g = 5 }

-- colors.* constants (only lightBlue/black/gray/white are used)
colors = { black = 0, gray = 1, lightBlue = 2, white = 3 }

-- Simulated redstone state per side
local redstoneState = { left = false, right = false, top = false, front = false, bottom = false }

-- Event queue: edit this list to simulate different presses.
-- key events use keys.* codes; redstone events update redstoneState and fire the event.
local eventQueue = {
  { "key", keys.a },                 -- press A -> button 1
  { "key", keys.d },                 -- press D -> button 3
  { "redstone", { left = true } },   -- rising edge on left -> button 1
  { "redstone", { left = false } },  -- release
  { "key", keys.g },                 -- press G -> button 5
}

--------------------------------------------------
-- CraftOS mocks                                --
--------------------------------------------------

-- Minimal terminal buffer with background awareness.
local buffer = {}
local cursorX, cursorY = 1, 1
local bgColor = colors.black
local textColor = colors.white

local function initBuffer()
  buffer = {}
  for y = 1, SCREEN_H do
    buffer[y] = {}
    for x = 1, SCREEN_W do
      buffer[y][x] = " "
    end
  end
end

local function clamp(n, min, max) return math.max(min, math.min(max, n)) end

term = {}

function term.getSize()
  return SCREEN_W, SCREEN_H
end

function term.setCursorPos(x, y)
  cursorX = clamp(math.floor(x), 1, SCREEN_W)
  cursorY = clamp(math.floor(y), 1, SCREEN_H)
end

function term.setBackgroundColor(c)
  bgColor = c
end

function term.setTextColor(c)
  textColor = c -- not rendered, but tracked for completeness
end

function term.clear()
  initBuffer()
  cursorX, cursorY = 1, 1
end

function term.write(str)
  str = tostring(str)
  for i = 1, #str do
    local ch = str:sub(i, i)
    -- Show highlighted regions by replacing space + lightBlue with '='
    local toWrite = ch
    if ch == " " and bgColor == colors.lightBlue then
      toWrite = "="
    end
    buffer[cursorY][cursorX] = toWrite
    cursorX = clamp(cursorX + 1, 1, SCREEN_W)
  end
end

-- Basic redstone mock
redstone = {}
function redstone.getInput(side)
  return redstoneState[side] or false
end

--------------------------------------------------
-- Event pump                                   --
--------------------------------------------------

local dumpPending = false

local function dumpBottomStrip()
  local function row(y)
    return table.concat(buffer[y])
  end
  local sep = string.rep("-", SCREEN_W)
  print(sep)
  print(row(SCREEN_H - 1))
  print(row(SCREEN_H))
  print(sep)
end

os = os or {}
function os.pullEvent()
  if dumpPending then
    dumpBottomStrip()
  end
  local evt = table.remove(eventQueue, 1)
  if not evt then
    -- Final dump after last event, then stop the program.
    dumpBottomStrip()
    error("__DONE__", 0)
  end

  local name, payload = evt[1], evt[2]
  if name == "redstone" and type(payload) == "table" then
    for k, v in pairs(payload) do
      redstoneState[k] = v
    end
    payload = nil -- redstone event carries no payload in CraftOS
  end

  dumpPending = true
  return name, payload
end

--------------------------------------------------
-- Run the real script under the mocks          --
--------------------------------------------------

initBuffer()

local ok, err = pcall(function()
  dofile("button_debug.lua")
end)

if not ok and err ~= "__DONE__" then
  error(err)
end

print("Simulation complete.")
