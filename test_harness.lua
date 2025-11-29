-- test_harness.lua
-- Desktop-only simulator that drives the arcade menu with fake events.
-- Run with: lua test_harness.lua  (do NOT run inside CraftOS/CC:Tweaked)

do
  local host = _G._HOST or (type(os) == "table" and os.version and os.version()) or ""
  if host:find("CraftOS") or host:find("CC:T") then
    print("This harness is desktop-only. On CraftOS, just run `menu`.")
    return
  end
end

--------------------------------------------------
-- Minimal CraftOS mocks                        --
--------------------------------------------------

local SCREEN_W, SCREEN_H = 50, 16

-- keys.* codes that menu.lua expects (A S D F G)
keys = { a = 1, s = 2, d = 3, f = 4, g = 5 }

-- colors.* constants used by menu.lua
colors = {
  black = 0, blue = 1, gray = 2, lightBlue = 3,
  yellow = 4, white = 5, lightGray = 6, red = 7,
}

--------------------------------------------------
-- Discover apps from menu.lua                  --
--------------------------------------------------

local function readMenuCommands()
  local cmds = {}
  local fh = io.open("menu.lua", "r")
  if not fh then return cmds end

  local inApps = false
  local depth = 0
  for line in fh:lines() do
    if not inApps then
      if line:find("local%s+apps%s*=%s*{") then
        inApps = true
        depth = 1
      end
    else
      local opens = select(2, line:gsub("{", ""))
      local closes = select(2, line:gsub("}", ""))
      depth = depth + opens - closes

      local cmd = line:match('command%s*=%s*"([^"]+)"')
      if cmd then table.insert(cmds, cmd) end

      if depth <= 0 then
        inApps = false
      end
    end
  end

  fh:close()
  return cmds
end

local appCommands = readMenuCommands()
if #appCommands == 0 then
  appCommands = { "blackjack", "video_poker", "button_debug" }
end

-- Track resolved "installed" programs for the menu list.
local installed = {}
for _, cmd in ipairs(appCommands) do
  installed[cmd] = true
end
local runLog = {}

-- Terminal buffer so drawing calls succeed (content only printed on dump).
local buffer = {}
local cursorX, cursorY = 1, 1
local bgColor, textColor = colors.black, colors.white

local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end

local function initBuffer()
  buffer = {}
  for y = 1, SCREEN_H do
    buffer[y] = {}
    for x = 1, SCREEN_W do
      buffer[y][x] = " "
    end
  end
end

term = {}

function term.getSize() return SCREEN_W, SCREEN_H end
function term.setCursorPos(x, y)
  cursorX = clamp(math.floor(x), 1, SCREEN_W)
  cursorY = clamp(math.floor(y), 1, SCREEN_H)
end
function term.setBackgroundColor(c) bgColor = c end
function term.setTextColor(c) textColor = c end
function term.clear() initBuffer(); cursorX, cursorY = 1, 1 end
function term.write(str)
  str = tostring(str)
  for i = 1, #str do
    local ch = str:sub(i, i)
    buffer[cursorY][cursorX] = ch
    cursorX = clamp(cursorX + 1, 1, SCREEN_W)
  end
end

-- File system + shell stubs so resolveProgram/run work.
fs = {}
function fs.exists(path)
  return installed[path] or installed[path:gsub("%.lua$", "")]
end

shell = {}
function shell.resolveProgram(name)
  if installed[name] then return name .. ".lua" end
  return nil
end
function shell.run(cmd)
  table.insert(runLog, cmd)
  return true
end

-- Redstone mock
local redstoneState = { left = false, right = false, top = false, front = false, bottom = false }
redstone = {}
function redstone.getInput(side) return redstoneState[side] or false end

-- Event pump: feeds a short sequence into os.pullEvent
local function buildEventQueue(commands)
  local events = {}
  local function push(name, payload)
    table.insert(events, { name, payload })
  end

  local total = #commands
  if total == 0 then
    push("key", keys.g)
    return events
  end

  local current = 1
  for target = 1, total do
    local steps = target - current
    if steps < 0 then steps = steps + total end
    for _ = 1, steps do
      push("key", keys.s) -- Next
    end
    push("key", keys.d) -- Launch
    current = target
  end

  push("key", keys.f) -- Refresh
  push("key", keys.g) -- Exit
  return events
end

local eventQueue = buildEventQueue(appCommands)

os = os or {}
function os.pullEvent()
  local evt = table.remove(eventQueue, 1)
  if not evt then error("__DONE__", 0) end

  local name, payload = evt[1], evt[2]
  if name == "redstone" and type(payload) == "table" then
    for k, v in pairs(payload) do redstoneState[k] = v end
    payload = nil
  end
  return name, payload
end

--------------------------------------------------
-- Tiny expectation helper                      --
--------------------------------------------------

local function expect(label, cond)
  if cond then
    print("[PASS] " .. label)
  else
    error("[FAIL] " .. label, 0)
  end
end

--------------------------------------------------
-- Run menu.lua under the mocks                 --
--------------------------------------------------

initBuffer()

local ok, err = pcall(function()
  dofile("menu.lua")
end)

if not ok then
  if err ~= "__DONE__" then error(err) end
end

--------------------------------------------------
-- Assertions                                   --
--------------------------------------------------

expect("Launched " .. #appCommands .. " apps", #runLog == #appCommands)
for i, cmd in ipairs(appCommands) do
  expect("Launch " .. i .. " was " .. cmd, runLog[i] == cmd)
end

print("Harness complete.")
