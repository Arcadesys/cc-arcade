-- Boot entrypoint that launches the arcade menu.
-- Watches disk eject/insert events as an out-of-band "sixth button."

local staticChars = { ".", ",", ":", ";", "*", "'" }
local staticColors = { colors.gray, colors.lightGray, colors.white }

local function seedRng()
  local seed = (os.epoch and os.epoch("utc")) or (os.time and os.time()) or 0
  math.randomseed(seed)
  math.random(); math.random(); math.random()
end

local function driveAvailable()
  return peripheral and peripheral.find and (peripheral.find("drive") ~= nil)
end

local function anyDiskPresent()
  if not peripheral or not peripheral.find then return false end
  local drives = { peripheral.find("drive") }
  for i = 1, #drives do
    local drive = drives[i]
    if drive and drive.isDiskPresent and drive.isDiskPresent() then
      return true
    end
  end
  return false
end

local function waitForDiskInsert()
  while true do
    local ev = { os.pullEvent() }
    local name = ev[1]
    if name == "disk" or name == "disk_inserted" then
      return
    end
  end
end

local function waitForDiskRemoval()
  while true do
    local ev = { os.pullEvent() }
    local name, side = ev[1], ev[2]
    if name == "disk_eject" or name == "disk_removed" then
      return
    elseif name == "peripheral_detach" and peripheral and peripheral.getType then
      if peripheral.getType(side) == "drive" then
        return
      end
    end
  end
end

local function drawStaticFrame()
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  for y = 1, math.max(1, h - 2) do
    term.setCursorPos(1, y)
    local fg = staticColors[math.random(#staticColors)]
    term.setTextColor(fg)
    local line = {}
    for x = 1, w do
      line[x] = staticChars[math.random(#staticChars)]
    end
    term.write(table.concat(line))
  end

  local msg = "Cartridge missing. Insert to return to menu."
  if #msg > w then
    msg = (w > 3) and (msg:sub(1, w - 3) .. "...") or msg:sub(1, w)
  end
  local x = math.max(1, math.floor((w - #msg) / 2) + 1)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.lightGray)
  term.setCursorPos(x, h - 1)
  term.write(msg)
end

local function showStaticUntilDisk()
  seedRng()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()

  while true do
    drawStaticFrame()
    local timer = os.startTimer(0.08)
    while true do
      local ev = { os.pullEvent() }
      local name, id = ev[1], ev[2]
      if name == "disk" or name == "disk_inserted" then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        return
      elseif name == "timer" and id == timer then
        break
      end
    end
  end
end

local function runMenu()
  if shell and shell.run then
    return shell.run("menu")
  else
    local baseEnv = _ENV or _G
    return os.run(setmetatable({}, { __index = baseEnv }), "menu.lua")
  end
end

local function runArcade()
  if driveAvailable() and not anyDiskPresent() then
    showStaticUntilDisk()
  end

  while true do
    local diskPulled = false
    local ok, err = true, nil

    local function menuThread()
      ok, err = pcall(runMenu)
    end

    local function diskThread()
      waitForDiskRemoval()
      diskPulled = true
    end

    parallel.waitForAny(menuThread, diskThread)

    if diskPulled then
      showStaticUntilDisk()
      -- After reinsertion, restart at the menu entry point.
    else
      if not ok then
        print("Arcade menu failed to start:")
        print(tostring(err))
        print("Dropping to shell.")
      end
      return
    end
  end
end

runArcade()
