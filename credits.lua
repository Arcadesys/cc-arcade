-- credits.lua
-- Unified Credit System API

local CREDITS_FILE = ".credits"
local DEFAULT_CREDITS = 100

local credits = {}

function credits.get()
    if not fs.exists(CREDITS_FILE) then
        credits.set(DEFAULT_CREDITS)
        return DEFAULT_CREDITS
    end
    
    local f = fs.open(CREDITS_FILE, "r")
    local amount = tonumber(f.readAll())
    f.close()
    
    if not amount then
        amount = DEFAULT_CREDITS
        credits.set(amount)
    end
    
    return amount
end

function credits.set(amount)
    local f = fs.open(CREDITS_FILE, "w")
    f.write(tostring(math.floor(amount)))
    f.close()
end

function credits.add(amount)
    local current = credits.get()
    credits.set(current + amount)
    return current + amount
end

function credits.remove(amount)
    local current = credits.get()
    if current >= amount then
        credits.set(current - amount)
        return true
    else
        return false
    end
end

return credits
