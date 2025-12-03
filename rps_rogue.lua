-- rps_rogue.lua
-- Rock-Paper-Scissors Roguelike

local w, h = term.getSize()

-- 3-Button Config
local KEYS = {
    LEFT = { keys.left, keys.a },
    CENTER = { keys.up, keys.w, keys.space, keys.enter },
    RIGHT = { keys.right, keys.d }
}

local function isKey(key, set)
    for _, k in ipairs(set) do if key == k then return true end end
    return false
end

local function waitKey()
    while true do
        local e, p1 = os.pullEvent()
        if e == "key" then
            if isKey(p1, KEYS.LEFT) then return "LEFT" end
            if isKey(p1, KEYS.CENTER) then return "CENTER" end
            if isKey(p1, KEYS.RIGHT) then return "RIGHT" end
        elseif e == "redstone" then
            if redstone.getInput("left") then sleep(0.2) return "LEFT" end
            if redstone.getInput("top") or redstone.getInput("front") then sleep(0.2) return "CENTER" end
            if redstone.getInput("right") then sleep(0.2) return "RIGHT" end
        end
    end
end

--------------------------------------------------------------------------------
-- GAME LOGIC
--------------------------------------------------------------------------------

local MOVES = { "Rock", "Paper", "Scissors" }
local BEATS = { Rock = "Scissors", Paper = "Rock", Scissors = "Paper" }

local player = { hp = 20, maxHp = 20, dmg = 3, level = 1 }
local enemy = { hp = 10, maxHp = 10, dmg = 2, name = "Slime" }
local floor = 1
local log = {}

local function addLog(msg)
    table.insert(log, 1, msg)
    if #log > 5 then table.remove(log) end
end

local function generateEnemy()
    local types = {
        {name="Slime", hp=10, dmg=2},
        {name="Goblin", hp=15, dmg=3},
        {name="Orc", hp=25, dmg=4},
        {name="Dragon", hp=50, dmg=8}
    }
    local idx = math.min(#types, math.floor((floor-1)/3) + 1)
    if floor > 10 then idx = 4 end
    
    local base = types[idx]
    enemy = {
        name = base.name,
        hp = base.hp + math.floor(floor * 1.5),
        maxHp = base.hp + math.floor(floor * 1.5),
        dmg = base.dmg + math.floor(floor * 0.5)
    }
end

local function resolveRound(pMove, eMove)
    addLog("You: " .. pMove .. " vs " .. eMove)
    
    if pMove == eMove then
        addLog("Draw!")
    elseif BEATS[pMove] == eMove then
        addLog("Hit! Dealt " .. player.dmg .. " dmg.")
        enemy.hp = enemy.hp - player.dmg
    else
        addLog("Ouch! Took " .. enemy.dmg .. " dmg.")
        player.hp = player.hp - enemy.dmg
    end
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

local function drawBar(label, val, max, y, color)
    term.setCursorPos(2, y)
    term.setTextColor(color)
    term.write(label .. ": " .. val .. "/" .. max)
    
    local barW = 10
    local fill = math.ceil((val/max) * barW)
    term.setCursorPos(2, y+1)
    term.setBackgroundColor(color)
    term.write(string.rep(" ", fill))
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", barW - fill))
    term.setBackgroundColor(colors.black)
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Header
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.clearLine()
    term.write(" FLOOR " .. floor .. " - " .. enemy.name)
    
    -- Stats
    drawBar("PLAYER", player.hp, player.maxHp, 3, colors.lime)
    drawBar("ENEMY", enemy.hp, enemy.maxHp, 3, colors.red)
    
    -- Enemy is on the right
    term.setCursorPos(w - 15, 3)
    term.setTextColor(colors.red)
    term.write(enemy.name)
    term.setCursorPos(w - 15, 4)
    term.write("HP: " .. enemy.hp .. "/" .. enemy.maxHp)
    
    -- Log
    term.setCursorPos(2, 8)
    term.setTextColor(colors.white)
    term.write("--- LOG ---")
    for i, msg in ipairs(log) do
        term.setCursorPos(2, 9 + i)
        term.setTextColor(colors.lightGray)
        term.write(msg)
    end
    
    -- Controls
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.black)
    term.clearLine()
    term.write(" [L] Rock   [C] Paper   [R] Scissors")
end

local function drawUpgradeMenu()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.yellow)
    term.clearLine()
    term.write(" LEVEL UP! Choose Upgrade:")
    
    term.setCursorPos(2, 5)
    term.setTextColor(colors.white)
    term.write("[L] Heal Full HP")
    
    term.setCursorPos(2, 7)
    term.write("[C] +5 Max HP")
    
    term.setCursorPos(2, 9)
    term.write("[R] +1 Damage")
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

local function main()
    generateEnemy()
    
    while true do
        if player.hp <= 0 then
            term.clear()
            term.setCursorPos(1, h/2)
            term.setTextColor(colors.red)
            term.write("GAME OVER")
            term.setCursorPos(1, h/2 + 1)
            term.write("Reached Floor " .. floor)
            sleep(3)
            break
        end
        
        if enemy.hp <= 0 then
            -- Victory
            floor = floor + 1
            player.level = player.level + 1
            
            -- Upgrade
            drawUpgradeMenu()
            local key = waitKey()
            if key == "LEFT" then
                player.hp = player.maxHp
            elseif key == "CENTER" then
                player.maxHp = player.maxHp + 5
                player.hp = player.hp + 5
            elseif key == "RIGHT" then
                player.dmg = player.dmg + 1
            end
            
            generateEnemy()
            log = {}
            addLog("Floor " .. floor .. " start!")
        else
            drawUI()
            local key = waitKey()
            local pMove = nil
            if key == "LEFT" then pMove = "Rock"
            elseif key == "CENTER" then pMove = "Paper"
            elseif key == "RIGHT" then pMove = "Scissors" end
            
            if pMove then
                local eMove = MOVES[math.random(1, 3)]
                resolveRound(pMove, eMove)
            end
        end
    end
    
    if fs.exists("menu.lua") then shell.run("menu.lua") end
end

main()
