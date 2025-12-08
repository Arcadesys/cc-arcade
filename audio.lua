-- audio.lua
-- Simple Audio Manager for Arcade Games
-- Provides DOS-esque sound effects using the Speaker peripheral

local audio = {}
local speaker = peripheral.find("speaker")

-- Helper to play a note safely
local function play(instrument, volume, pitch)
    if speaker then
        speaker.playNote(instrument, volume, pitch)
    end
end

-- Sound Effects

function audio.playClick()
    -- Simple UI click
    play("hat", 0.5, 24)
end

function audio.playConfirm()
    -- Selection confirmation
    play("bit", 1, 14)
end

function audio.playWin()
    -- Victory jingle
    if not speaker then return end
    play("bit", 2, 12)
    sleep(0.1)
    play("bit", 2, 16)
    sleep(0.1)
    play("bit", 2, 19)
    sleep(0.1)
    play("bit", 2, 24)
end

function audio.playLose()
    -- Losing sound
    if not speaker then return end
    play("bit", 2, 12)
    sleep(0.15)
    play("bit", 2, 8)
    sleep(0.15)
    play("bit", 2, 4)
end

function audio.playShuffle()
    -- Card shuffling / Slot spinning tick
    play("snare", 0.5, 24)
end

function audio.playDeal()
    -- Card dealing sound
    play("hat", 1, 16)
end

function audio.playSlotStop()
    -- Slot reel stopping
    play("basedrum", 2, 16)
end

function audio.playChip()
    -- Chip betting sound
    play("hat", 1, 12)
end

function audio.playCashRegister()
    -- Cha-ching!
    if not speaker then return end
    play("bell", 2, 12)
    sleep(0.1)
    play("bell", 2, 16)
end

function audio.playCoinDispense()
    -- Clinking coins
    if not speaker then return end
    for i = 1, 3 do
        play("bit", 1, 20 + math.random(-2, 2))
        sleep(0.05)
    end
end

function audio.playError()
    -- Error buzzer
    if not speaker then return end
    play("bass", 2, 6)
    sleep(0.1)
    play("bass", 2, 6)
end

return audio
