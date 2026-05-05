-- idlecraft.lua
-- A simple idle/clicker game for CC Arcade

local w, h = term.getSize()
local cx, cy = math.floor(w / 2), math.floor(h / 2)

-- Game State
local state = {
    wood = 0,
    steves = 0,
    pickaxeLevel = 1,
    lastTick = os.clock()
}

-- Costs & Config
local COSTS = {
    steve = 15,
    pickaxe = 50
}

local MULTIPLIERS = {
    steve = 1.2, -- Cost multiplier
    pickaxe = 1.5
}

-- Controls
local KEYS = {
    LEFT = { keys.left, keys.a },
    CENTER = { keys.up, keys.w, keys.space, keys.enter },
    RIGHT = { keys.right, keys.d }
}

local function isKey(key, set)
    for _, k in ipairs(set) do if key == k then return true end end
    return false
end

-- UI State
local selectedAction = 1 -- 1: Punch, 2: Hire, 3: Upgrade
local ACTIONS = { "Punch Tree", "Hire Steve", "Upgrade Pickaxe" }

local function getCost(type)
    if type == "steve" then
        return math.floor(COSTS.steve * (MULTIPLIERS.steve ^ state.steves))
    elseif type == "pickaxe" then
        return math.floor(COSTS.pickaxe * (MULTIPLIERS.pickaxe ^ (state.pickaxeLevel - 1)))
    end
    return 0
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Header
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.white)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("IDLECRAFT")
    
    -- Stats
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(2, 3)
    term.write("Wood: " .. math.floor(state.wood))
    term.setCursorPos(2, 4)
    term.write("Steves: " .. state.steves .. " (+" .. state.steves .. "/s)")
    term.setCursorPos(2, 5)
    term.write("Pickaxe Lvl: " .. state.pickaxeLevel .. " (+" .. state.pickaxeLevel .. "/click)")

    -- Actions
    local startY = 8
    for i, action in ipairs(ACTIONS) do
        term.setCursorPos(2, startY + (i-1)*2)
        if i == selectedAction then
            term.setTextColor(colors.yellow)
            term.write("> " .. action)
        else
            term.setTextColor(colors.gray)
            term.write("  " .. action)
        end
        
        -- Cost display
        local cost = 0
        if i == 2 then cost = getCost("steve") end
        if i == 3 then cost = getCost("pickaxe") end
        
        if cost > 0 then
            term.setTextColor(colors.lightGray)
            term.write(" (Cost: " .. cost .. ")")
        end
    end

    -- Footer
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.black)
    term.clearLine()
    term.write(" [L] Select  [C] Action  [R] Exit")
end

local function update()
    local now = os.clock()
    local dt = now - state.lastTick
    if dt >= 1 then
        state.wood = state.wood + (state.steves * dt)
        state.lastTick = now
        drawUI()
    end
end

local function performAction()
    if selectedAction == 1 then -- Punch Tree
        state.wood = state.wood + state.pickaxeLevel
        
        -- Visual feedback
        term.setCursorPos(15, 8)
        term.setTextColor(colors.lime)
        term.write("+" .. state.pickaxeLevel)
        sleep(0.1)
        
    elseif selectedAction == 2 then -- Hire Steve
        local cost = getCost("steve")
        if state.wood >= cost then
            state.wood = state.wood - cost
            state.steves = state.steves + 1
        else
            -- Feedback for not enough wood
            term.setCursorPos(2, h-2)
            term.setTextColor(colors.red)
            term.write("Need more wood!")
            sleep(0.5)
        end
        
    elseif selectedAction == 3 then -- Upgrade Pickaxe
        local cost = getCost("pickaxe")
        if state.wood >= cost then
            state.wood = state.wood - cost
            state.pickaxeLevel = state.pickaxeLevel + 1
        else
             -- Feedback for not enough wood
            term.setCursorPos(2, h-2)
            term.setTextColor(colors.red)
            term.write("Need more wood!")
            sleep(0.5)
        end
    end
end

local function main()
    -- Main Loop
    local timerID = os.startTimer(1)
    
    while true do
        drawUI()
        
        local event, p1 = os.pullEvent()
        
        if event == "key" then
            if isKey(p1, KEYS.LEFT) then
                selectedAction = (selectedAction % #ACTIONS) + 1
            elseif isKey(p1, KEYS.CENTER) then
                performAction()
            elseif isKey(p1, KEYS.RIGHT) then
                break
            end
        elseif event == "timer" and p1 == timerID then
            state.wood = state.wood + state.steves
            timerID = os.startTimer(1)
        elseif event == "redstone" then
             if redstone.getInput("left") then
                selectedAction = (selectedAction % #ACTIONS) + 1
                sleep(0.2)
            elseif redstone.getInput("top") or redstone.getInput("front") then
                performAction()
                sleep(0.2)
            elseif redstone.getInput("right") then
                -- break -- Disabled exit
            end
        end
    end
end

main()
