-- static.lua
-- Displays static noise and plays white noise.
-- Intended to be run as a screensaver.

local staticChars = { ".", ",", ":", ";", "*", "'" }
local staticColors = { colors.gray, colors.lightGray, colors.white }

local function seedRng()
  local seed = (os.epoch and os.epoch("utc")) or (os.time and os.time()) or 0
  math.randomseed(seed)
  math.random(); math.random(); math.random()
end

local function playWhiteNoise()
    local speaker = peripheral.find("speaker")
    if not speaker then 
        while true do sleep(10) end -- Sleep forever if no speaker
    end
    
    local buffer = {}
    for i = 1, 16 * 1024 do 
        buffer[i] = math.random(-128, 127)
    end
    
    while true do
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
        -- Yield briefly to allow other coroutines to run if playAudio was instant
        sleep(0) 
    end
end

local function drawStaticFrame()
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  for y = 1, math.max(1, h - 2) do
    term.setCursorPos(1, y)
    local fg = staticColors[math.random(#staticColors)]
    term.setTextColor(fg)
    local line = {}
    for x = 1, w do
      line[x] = staticChars[math.random(#staticChars)]
    end
    term.write(table.concat(line))
  end

  local msg = "NO SIGNAL"
  local x = math.max(1, math.floor((w - #msg) / 2) + 1)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.red)
  term.setCursorPos(x, h - 1)
  term.write(msg)
end

local function drawStaticLoop()
    while true do
        if _G.AR_STOP_STATIC then
            return
        end
        drawStaticFrame()
        sleep(0.05)
    end
end

local function main()
    seedRng()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    
    parallel.waitForAll(drawStaticLoop, playWhiteNoise)
end

main()
