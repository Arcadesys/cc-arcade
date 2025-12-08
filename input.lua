-- input.lua
-- Input handling for Arcade OS

local config = {
    LEFT = { type = "key", value = keys.left },
    CENTER = { type = "key", value = keys.up },
    RIGHT = { type = "key", value = keys.right }
}

-- Load config if exists
if fs.exists(".button_config") then
    local file = fs.open(".button_config", "r")
    if file then
        local data = file.readAll()
        file.close()
        local loaded = textutils.unserialize(data)
        if loaded then
            config = loaded
        end
    end
end

-- Also support default keys for keyboard fallback
local DEFAULT_KEYS = {
    LEFT = { keys.left, keys.a, keys.q },
    CENTER = { keys.up, keys.w, keys.space, keys.enter },
    RIGHT = { keys.right, keys.d, keys.e }
}

local function isKey(key, set)
    for _, k in ipairs(set) do
        if key == k then return true end
    end
    return false
end

local function getButton(event, p1)
    if event == "key" then
        -- Check configured keys
        if config.LEFT.type == "key" and p1 == config.LEFT.value then return "LEFT" end
        if config.CENTER.type == "key" and p1 == config.CENTER.value then return "CENTER" end
        if config.RIGHT.type == "key" and p1 == config.RIGHT.value then return "RIGHT" end
        
        -- Check default keys (fallback/keyboard support)
        if isKey(p1, DEFAULT_KEYS.LEFT) then return "LEFT" end
        if isKey(p1, DEFAULT_KEYS.CENTER) then return "CENTER" end
        if isKey(p1, DEFAULT_KEYS.RIGHT) then return "RIGHT" end
        
    elseif event == "redstone" then
        -- Check configured redstone
        if config.LEFT.type == "redstone" and redstone.getInput(config.LEFT.value) then return "LEFT" end
        if config.CENTER.type == "redstone" and redstone.getInput(config.CENTER.value) then return "CENTER" end
        if config.RIGHT.type == "redstone" and redstone.getInput(config.RIGHT.value) then return "RIGHT" end
        
        -- Default redstone fallback (Legacy support)
        -- Only check if NOT configured as redstone to avoid double counting if config matches default
        if config.LEFT.type ~= "redstone" and redstone.getInput("left") then return "LEFT" end
        if config.RIGHT.type ~= "redstone" and redstone.getInput("right") then return "RIGHT" end
        if config.CENTER.type ~= "redstone" and (redstone.getInput("top") or redstone.getInput("front")) then return "CENTER" end
    end
    return nil
end

return {
    getButton = getButton
}
