local CREDITS_FILE = "disk/credits"
local DEFAULT_CREDITS = 0 -- Default to 0 if no disk/file

local credits = {}

function credits.get()
    if _G.ARCADE_DEV_MODE then
        return math.huge
    end

    if not fs.exists(CREDITS_FILE) then
        return DEFAULT_CREDITS
    end
    
    local f = fs.open(CREDITS_FILE, "r")
    if not f then return DEFAULT_CREDITS end
    local content = f.readAll()
    f.close()
    
    local amount = tonumber(content)
    
    if not amount then
        return DEFAULT_CREDITS
    end
    
    return amount
end

function credits.set(amount)
    if _G.ARCADE_DEV_MODE then
        return true -- No-op in dev mode
    end

    -- Only write if the directory exists (disk is present)
    local dir = fs.getDir(CREDITS_FILE)
    if not fs.exists(dir) then
        return false 
    end

    local f = fs.open(CREDITS_FILE, "w")
    if f then
        f.write(tostring(math.floor(amount)))
        f.close()
        return true
    end
    return false
end

function credits.add(amount)
    local current = credits.get()
    local newAmount = current + amount
    credits.set(newAmount)
    return newAmount
end

function credits.remove(amount)
    if _G.ARCADE_DEV_MODE then
        return true -- Always successful in dev mode
    end

    local current = credits.get()
    if current >= amount then
        credits.set(current - amount)
        return true
    else
        return false
    end
end

return credits
