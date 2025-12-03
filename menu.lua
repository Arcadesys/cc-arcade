-- menu.lua
-- The lightweight Arcade OS Shell
-- Controls: [Left] Prev, [Center] Launch, [Right] Next

local games = {
    { name = "Blackjack", cmd = "blackjack" },
    { name = "Super Slots", cmd = "slots" },
    { name = "Can't Stop", cmd = "cant_stop" },
    { name = "RPS Rogue", cmd = "rps_rogue" },
    { name = "Reboot", cmd = "reboot" },
    { name = "Shutdown", cmd = "shutdown" }
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
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.yellow)
    term.setCursorPos(1, 1)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("ARCADE OS")
end

local function drawMenu()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader()
    
    local centerY = math.floor(h / 2)
    
    for i, game in ipairs(games) do
        local y = centerY - 2 + i
        if y >= 2 and y < h then
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
    term.write(" [L] Prev  [C] Launch  [R] Next")
end

local function launchGame()
    local game = games[selected]
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    
    if game.cmd == "reboot" then
        os.reboot()
    elseif game.cmd == "shutdown" then
        os.shutdown()
    else
        if fs.exists(game.cmd .. ".lua") then
            shell.run(game.cmd)
        else
            print("Game not installed: " .. game.cmd)
            sleep(1)
        end
    end
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
                launchGame()
            end
        elseif event == "redstone" then
            -- Poll redstone inputs for physical buttons
            if redstone.getInput("left") then
                selected = selected - 1
                if selected < 1 then selected = #games end
                sleep(0.2) -- Debounce
            elseif redstone.getInput("right") then
                selected = selected + 1
                if selected > #games then selected = 1 end
                sleep(0.2)
            elseif redstone.getInput("top") or redstone.getInput("front") then
                launchGame()
                sleep(0.2)
            end
        end
    end
end

main()
