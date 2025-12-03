-- startup.lua
-- Launches the Arcade Menu OS

term.clear()
term.setCursorPos(1, 1)
print("Booting ArcadeOS...")
print("Press 'D' for Dev Mode (2s)...")

_G.ARCADE_DEV_MODE = false
local timer = os.startTimer(2)
while true do
    local event, p1 = os.pullEvent()
    if event == "timer" and p1 == timer then
        break
    elseif event == "char" and p1:lower() == "d" then
        _G.ARCADE_DEV_MODE = true
        print("DEV MODE ENABLED: Infinite Credits")
        sleep(1)
        break
    end
end

if not _G.ARCADE_DEV_MODE then
    print("Production Mode: Standard Credits")
end
sleep(0.5)

if fs.exists(".arcade_config") then
    local file = fs.open(".arcade_config", "r")
    local cmd = file.readAll()
    file.close()
    
    -- Trim whitespace just in case
    cmd = cmd:gsub("%s+", "")
    
    if fs.exists(cmd .. ".lua") then
        print("Launching " .. cmd .. "...")
        sleep(0.5)
        shell.run(cmd)
    else
        print("Error: Configured game '" .. cmd .. "' not found!")
        print("Delete .arcade_config to reset.")
    end
elseif fs.exists("setup.lua") then
    shell.run("setup.lua")
else
    print("Error: setup.lua not found!")
end
