-- disk_credits.lua
-- Simple helper to track credits stored on data disks.

local DiskCredits = {}

local CREDIT_FILE = "casino_credits.txt"

local function safePeriph()
  if type(peripheral) ~= "table" then return nil end
  return peripheral
end

local function findDrive(overrideSide)
  local p = safePeriph()
  if not p then return nil end
  local function matchesDrive(name)
    local ok, typ = pcall(function() return p.getType(name) end)
    return ok and typ == "drive"
  end

  local function wrapPeripheral(name)
    if not p.wrap then return nil end
    local ok, wrapped = pcall(function() return p.wrap(name) end)
    if ok then return wrapped end
    return nil
  end

  if overrideSide and p.isPresent and p.isPresent(overrideSide) and matchesDrive(overrideSide) then
    return overrideSide, wrapPeripheral(overrideSide)
  end

  if p.getNames then
    for _, name in ipairs(p.getNames()) do
      if matchesDrive(name) then
        return name, wrapPeripheral(name)
      end
    end
  end
  return nil
end

local function readCreditsFromDisk(path)
  if not path or not fs or not fs.exists then return 0 end
  local filePath = fs.combine(path, CREDIT_FILE)
  if not fs.exists(filePath) then return 0 end
  local handle = fs.open(filePath, "r")
  if not handle then return 0 end
  local contents = handle.readAll()
  handle.close()
  if not contents then return 0 end
  return tonumber(contents:match("%d+")) or 0
end

local function writeCreditsToDisk(path, amount)
  if not path or not fs then return false end
  local filePath = fs.combine(path, CREDIT_FILE)
  local handle = fs.open(filePath, "w")
  if not handle then return false end
  handle.write(tostring(math.floor(amount)))
  handle.close()
  return true
end

local function safeMethod(obj, name)
  if not obj then return nil end
  local method = obj[name]
  if type(method) ~= "function" then return nil end
  local ok, result = pcall(method, obj)
  if not ok then return nil end
  return result
end

local state = {
  present = false,
  credits = 0,
  diskId = nil,
  label = nil,
  mountPath = nil,
}
local cachedId = nil
local grooveSide = nil

local function refresh()
  local driveSide, drive = findDrive(grooveSide)
  if not drive then
    state.present = false
    state.diskId = nil
    state.label = nil
    state.mountPath = nil
    state.credits = 0
    cachedId = nil
    return
  end

  local isPresent = safeMethod(drive, "isDiskPresent")
  if not isPresent then
    state.present = false
    state.diskId = nil
    state.label = nil
    state.mountPath = nil
    state.credits = 0
    cachedId = nil
    return
  end

  local diskId = safeMethod(drive, "getDiskID")
  local label = safeMethod(drive, "getDiskLabel")
  local mountPath = safeMethod(drive, "getMountPath")

  state.present = true
  state.diskId = diskId
  state.label = label
  state.mountPath = mountPath
  grooveSide = driveSide

  if diskId ~= cachedId or state.credits == nil then
    state.credits = readCreditsFromDisk(mountPath)
    cachedId = diskId
  end
end

local function ensure()
  refresh()
  return state
end

function DiskCredits.getState()
  return ensure()
end

function DiskCredits.addCredits(amount)
  if not amount or amount <= 0 then return false end
  local current = ensure()
  if not current.present or not current.mountPath then return false end
  current.credits = current.credits + amount
  writeCreditsToDisk(current.mountPath, current.credits)
  return true
end

function DiskCredits.consumeCredits(amount)
  if not amount or amount <= 0 then return false end
  local current = ensure()
  if not current.present or current.credits < amount then return false end
  current.credits = current.credits - amount
  writeCreditsToDisk(current.mountPath, current.credits)
  return true
end

function DiskCredits.setDeviceSide(side)
  grooveSide = side
  cachedId = nil
  refresh()
end

return DiskCredits
