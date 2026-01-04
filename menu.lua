-- menu.lua
-- The lightweight Arcade OS Shell
-- Controls: [Left] Prev, [Center] Launch, [Right] Next

-- Kiosk machines should never expose the menu UI.
if _G.ARCADE_KIOSK then
    return
end

local games = {
    { name = "Blackjack", cmd = "blackjack" },
    { name = "Baccarat", cmd = "baccarat" },
    { name = "Super Slots", cmd = "slots" },
    { name = "Horse Race", cmd = "race" },
    { name = "Can't Stop (Free)", cmd = "cant_stop" },
    { name = "RPS Rogue", cmd = "rps_rogue" },
    { name = "Roulette Watch", cmd = "screensavers/roulette" },
    { name = "Exit", cmd = "exit" },
    { name = "Reboot", cmd = "reboot" },
    { name = "Shutdown", cmd = "shutdown" }
}

local selected = 1
local w, h = term.getSize()

local input = require("input")
local credits = require("credits")
local audio = require("audio")

local function drawHeader()
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.yellow)
    term.setCursorPos(1, 1)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("ARCADE OS")
    
    local c = credits.get()
    local name = credits.getName()

    local rightText = "Credits: " .. c
    if name then
        rightText = name .. " | " .. rightText
    end

    term.setCursorPos(w - #rightText - 1, 1)
    term.write(rightText)
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
    term.write(" [L] Prev  [C] Launch  [R] Next  [S] Monitor")
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
    elseif game.cmd == "exit" then
        return true
    else
        if fs.exists(game.cmd .. ".lua") then
            -- Persist selection so this game auto-loads at startup.
            local f = fs.open(".arcade_config", "w")
            if f then
                f.write(game.cmd)
                f.close()
            end
            shell.run(game.cmd)
        else
            print("Game not installed: " .. game.cmd)
            sleep(1)
        end
    end
    return false
end

local function main()
    while true do
        drawMenu()
        
        local event, p1 = os.pullEvent()
        local button = input.getButton(event, p1)
        
        if button == "LEFT" then
            selected = selected - 1
            if selected < 1 then selected = #games end
            audio.playClick()
            if event == "redstone" then sleep(0.2) end
        elseif button == "RIGHT" then
            selected = selected + 1
            if selected > #games then selected = 1 end
            audio.playClick()
            if event == "redstone" then sleep(0.2) end
        elseif button == "CENTER" then
            audio.playConfirm()
            if launchGame() then break end
            if event == "redstone" then sleep(0.2) end
        elseif event == "char" and p1:lower() == "s" then
            local m = peripheral.find("monitor")
            if m then
                audio.playConfirm()
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
                term.clear()
                term.setCursorPos(1, 1)
                print("Monitor detected.")
                print("Rebooting to switch display...")
                sleep(1)
                os.reboot()
            else
                audio.playLose()
            end
        elseif event == "disk" then
             local name = credits.getName()
             local amount = credits.get()
             if name then
                audio.playConfirm()
                local popupW, popupH = 24, 7
                local px = math.floor((w - popupW) / 2)
                local py = math.floor((h - popupH) / 2)
                
                -- Draw box
                paintutils.drawFilledBox(px, py, px + popupW, py + popupH, colors.blue)
                term.setTextColor(colors.yellow)
                term.setCursorPos(px + 2, py + 1)
                term.write("WELCOME BACK!")
                
                term.setTextColor(colors.white)
                term.setCursorPos(px + 2, py + 3)
                term.write(name)
                
                term.setCursorPos(px + 2, py + 5)
                term.write("Credits: " .. amount)
                
                sleep(3)
             end
        end
    end
end

main()
