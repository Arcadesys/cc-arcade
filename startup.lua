-- Boot entrypoint that launches the arcade menu or disk game.
-- Watches disk eject/insert events.

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

local function inputLoop()
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "mouse_click" then
            -- Click anywhere to open menu (was settings)
            term.setBackgroundColor(colors.black)
            term.clear()
            shell.run("menu.lua")
            return
        elseif event == "redstone" then
            -- Press any button to open main menu
            local hasInput = false
            for _, side in ipairs(rs.getSides()) do
                if rs.getInput(side) then hasInput = true break end
            end
            
            if hasInput then
                term.setBackgroundColor(colors.black)
                term.clear()
                shell.run("menu.lua")
                return
            end
        elseif event == "disk" or event == "disk_inserted" then
            -- Disk inserted, return to main loop to handle it
            return
        end
    end
end

local function showStaticNoDrive()
  local function runStatic()
      shell.run("static.lua")
  end

  while true do
      -- Run loops in parallel. If inputLoop returns (after settings/menu exit or disk insert), we restart.
      parallel.waitForAny(runStatic, inputLoop)
      
      -- Clear screen before restarting loop (or returning to main)
      term.setBackgroundColor(colors.black)
      term.clear()
      
      if anyDiskPresent() then return end
  end
end

local function runDisk()
    if fs.exists("disk/startup.lua") then
        shell.run("disk/startup.lua")
    elseif fs.exists("disk/startup") then
        shell.run("disk/startup")
    else
        -- Fallback if disk is empty or has no startup
        -- We return to static screen instead of menu
        showStaticNoDrive()
    end
end

local function main()
  if anyDiskPresent() then
    runDisk()
  else
    showStaticNoDrive()
  end
end

main()
