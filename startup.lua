-- startup.lua
-- Launches the Arcade Menu OS

term.clear()
term.setCursorPos(1, 1)
print("Booting ArcadeOS...")

_G.ARCADE_DEV_MODE = false
if fs.exists(".arcade_mode") then
    local f = fs.open(".arcade_mode", "r")
    local mode = f.readAll()
    f.close()
    if mode == "dev" then
        _G.ARCADE_DEV_MODE = true
    end
end

if _G.ARCADE_DEV_MODE then
    print("DEV MODE ENABLED: Infinite Credits")
else
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
