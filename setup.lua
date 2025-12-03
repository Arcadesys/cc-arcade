-- setup.lua
-- Initial Configuration Menu
-- Select the game to permanently install on this machine

local games = {
    { name = "Blackjack", cmd = "blackjack" },
    { name = "Super Slots", cmd = "slots" },
    { name = "Can't Stop", cmd = "cant_stop" },
    { name = "RPS Rogue", cmd = "rps_rogue" }
}

local selected = 1
local w, h = term.getSize()

-- 3-Button Configuration
local KEYS = {
    LEFT = { keys.left, keys.a },
    CENTER = { keys.up, keys.w, keys.space, keys.enter },
    RIGHT = { keys.right, keys.d }
}

local function isKey(key, set)
    for _, k in ipairs(set) do
        if key == k then return true end
    end
    return false
end

local function drawHeader()
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("SYSTEM SETUP - ONE TIME ONLY")
end

local function drawMenu()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader()
    
    local centerY = math.floor(h / 2)
    
    term.setCursorPos(2, 3)
    term.setTextColor(colors.gray)
    term.write("Select Game to Install:")

    for i, game in ipairs(games) do
        local y = centerY - 1 + i
        if y >= 4 and y < h then
            term.setCursorPos(2, y)
            if i == selected then
                term.setTextColor(colors.lime)
                term.write("> " .. game.name .. " <")
            else
                term.setTextColor(colors.white)
                term.write("  " .. game.name)
            end
        end
    end
    
    -- Footer
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.black)
    term.setCursorPos(1, h)
    term.clearLine()
    term.write(" [L] Prev  [C] INSTALL  [R] Next")
end

local function installGame()
    local game = games[selected]
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    print("Installing " .. game.name .. "...")
    
    local file = fs.open(".arcade_config", "w")
    file.write(game.cmd)
    file.close()
    
    print("Configuration saved.")
    print("Rebooting in 2 seconds...")
    sleep(2)
    os.reboot()
end

local function main()
    while true do
        drawMenu()
        
        local event, p1 = os.pullEvent()
        
        if event == "key" then
            if isKey(p1, KEYS.LEFT) then
                selected = selected - 1
                if selected < 1 then selected = #games end
            elseif isKey(p1, KEYS.RIGHT) then
                selected = selected + 1
                if selected > #games then selected = 1 end
            elseif isKey(p1, KEYS.CENTER) then
                installGame()
                break
            end
        elseif event == "redstone" then
            if redstone.getInput("left") then
                selected = selected - 1
                if selected < 1 then selected = #games end
                sleep(0.2)
            elseif redstone.getInput("right") then
                selected = selected + 1
                if selected > #games then selected = 1 end
                sleep(0.2)
            elseif redstone.getInput("top") or redstone.getInput("front") then
                installGame()
                break
            end
        end
    end
end

main()
