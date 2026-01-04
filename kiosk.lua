-- kiosk.lua
-- Kiosk launcher: runs the configured game forever.
-- Intended for spawn / public machines (e.g., dedicated Can't Stop).

local function readArcadeConfig()
    if not fs.exists(".arcade_config") then return nil end
    local f = fs.open(".arcade_config", "r")
    if not f then return nil end
    local cmd = (f.readAll() or "")
    f.close()
    cmd = cmd:gsub("%s+", "")
    if cmd == "" then return nil end
    return cmd
end

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

while true do
    _G.ARCADE_KIOSK = true
    local cmd = readArcadeConfig() or "cant_stop"

    -- Run the game; if it errors or is terminated, just restart.
    local ok, err = pcall(function()
        if fs.exists(cmd .. ".lua") then
            shell.run(cmd)
        else
            clear()
            print("KIOSK ERROR")
            print("Missing program: " .. cmd .. ".lua")
            sleep(2)
        end
    end)

    -- Swallow all errors (including Ctrl+T "Terminated").
    if not ok then
        clear()
        term.setTextColor(colors.red)
        print("Restarting kiosk...")
        term.setTextColor(colors.gray)
        print(tostring(err))
        sleep(0.6)
    else
        sleep(0.1)
    end
end
