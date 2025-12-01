-- Quiz Show: buzzer-driven host-led quiz with JSON-fed questions.
-- Buttons: BTN1/BTN2/BTN3 = player buzzers, BTN4 = right answer, BTN5 = wrong/skip, hold BTN4+BTN5 for 1s = quit.
-- Keyboard fallback: A/S/D/F/G map to BTN1..BTN5; Q quits.
-- Questions: provide quiz_questions.json (array or {questions=[...]}) with fields `question` (or `prompt`) and optional `answer`.

-----------------------------
-- BUTTON MAP               --
-----------------------------

local buttons = {
  [1] = { side = "left",   label = "P1" },
  [2] = { side = "right",  label = "P2" },
  [3] = { side = "top",    label = "P3" },
  [4] = { side = "front",  label = "RIGHT" },
  [5] = { side = "bottom", label = "WRONG" },
}

local keyToButton = {
  [keys.a] = 1,
  [keys.s] = 2,
  [keys.d] = 3,
  [keys.f] = 4,
  [keys.g] = 5,
}

local lastState = {}
for i, btn in ipairs(buttons) do
  lastState[i] = redstone.getInput(btn.side)
end

-----------------------------
-- QUESTION LOADING         --
-----------------------------

local QUESTIONS_FILE = "quiz_questions.json"

local fallbackQuestions = {
  { question = "Name the largest ocean on Earth.", answer = "Pacific Ocean" },
  { question = "Which planet is known as the Red Planet?", answer = "Mars" },
  { question = "What is the tallest mammal?", answer = "The giraffe" },
}

local function normalizeQuestions(raw)
  if type(raw) ~= "table" then return {} end
  local list = raw.questions or raw
  if type(list) ~= "table" then return {} end
  local out = {}
  for _, q in ipairs(list) do
    if type(q) == "table" then
      local prompt = q.question or q.prompt or q.text or nil
      if not prompt and type(q[1]) == "string" then
        prompt = q[1]
      end
      if prompt then
        table.insert(out, { question = tostring(prompt), answer = q.answer })
      end
    elseif type(q) == "string" then
      table.insert(out, { question = q })
    end
  end
  return out
end

local function loadQuestions()
  if not fs.exists(QUESTIONS_FILE) then
    return fallbackQuestions, "Using built-in sample questions (no quiz_questions.json found)."
  end

  local ok, data = pcall(function()
    local f = fs.open(QUESTIONS_FILE, "r")
    local content = f.readAll()
    f.close()
    return textutils.unserializeJSON(content)
  end)

  if not ok then
    return fallbackQuestions, "Invalid JSON in quiz_questions.json; using fallback set."
  end

  local list = normalizeQuestions(data)
  if #list == 0 then
    return fallbackQuestions, "quiz_questions.json was empty; using fallback set."
  end
  return list, nil
end

-----------------------------
-- UTILITIES                --
-----------------------------

local function setLargeTextScale()
  if term.setTextScale then
    -- Push text larger but keep at least ~22 columns for wrapping.
    local w = select(1, term.getSize())
    local targetCols = 22
    local scale = math.max(1, math.min(2.5, w / targetCols))
    term.setTextScale(scale)
  end
end

local function wrapLines(text, maxWidth)
  local lines = textutils.wrap(text or "", maxWidth)
  local out = {}
  for _, line in ipairs(lines) do
    if #line > maxWidth then
      table.insert(out, line:sub(1, maxWidth - 3) .. "...")
    else
      table.insert(out, line)
    end
  end
  return out
end

local function getSegments()
  local w, h = term.getSize()
  local segs = {}
  local base = math.floor(w / 5)
  local x = 1
  for i = 1, 5 do
    local width = (i < 5) and base or (w - base * 4)
    segs[i] = { x1 = x, x2 = x + width - 1 }
    x = x + width
  end
  return segs, h - 1, h
end

local function centerText(y, text, fg, bg)
  local w = select(1, term.getSize())
  if #text > w then
    if w >= 3 then
      text = text:sub(1, w - 3) .. "..."
    else
      text = text:sub(1, w)
    end
  end
  local x = math.floor((w - #text) / 2) + 1
  term.setBackgroundColor(bg or colors.black)
  term.setTextColor(fg or colors.white)
  term.setCursorPos(x, y)
  term.write(text)
end

local function countRemainingPlayers(eliminated)
  local alive = 0
  for i = 1, 3 do
    if not eliminated[i] then alive = alive + 1 end
  end
  return alive
end

-----------------------------
-- STATE                    --
-----------------------------

local questions, loadMessage = loadQuestions()
local currentIndex = 1
local state = "waiting" -- waiting | answering | celebrate | finished
local activePlayer = nil
local eliminated = {}
local answerDeadline = nil
local timerId = nil
local quitTimerId = nil
local celebrateUntil = nil
local answeringExpired = false
local quitHoldStart = nil

-----------------------------
-- DRAWING                  --
-----------------------------

local function drawFooter(activeBtn)
  local segs, y1, y2 = getSegments()
  local labels = {
    "Buzz P1",
    "Buzz P2",
    "Buzz P3",
    "Right",
    "Wrong",
  }

  for i = 1, 5 do
    local seg = segs[i]
    local bg = (activeBtn == i) and colors.yellow or colors.gray
    term.setBackgroundColor(bg)
    term.setTextColor(colors.black)
    term.setCursorPos(seg.x1, y1)
    term.write(string.rep(" ", seg.x2 - seg.x1 + 1))
    term.setCursorPos(seg.x1, y2)
    term.write(string.rep(" ", seg.x2 - seg.x1 + 1))

    local label = labels[i]
    local width = seg.x2 - seg.x1 + 1
    local labelX = seg.x1 + math.floor((width - #label) / 2)
    term.setCursorPos(labelX, y2)
    term.write(label)
  end

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
end

local function drawQuestionScreen(status)
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()

  local header = string.format("Quiz Show  |  Question %d/%d", currentIndex, #questions)
  centerText(1, header, colors.yellow, colors.black)
  centerText(2, "First buzz locks. Host judges with BTN4/BTN5.", colors.lightGray, colors.black)
  if loadMessage then
    centerText(3, loadMessage, colors.lightBlue, colors.black)
  end

  local question = questions[currentIndex] or { question = "No question loaded." }
  local maxWidth = math.max(16, w - 4)
  local lines = wrapLines(question.question or "?", maxWidth)

  local y = 5
  local maxLines = math.min(#lines, h - 6)
  for i = 1, maxLines do
    term.setCursorPos(3, y)
    term.setTextColor(colors.white)
    term.write(lines[i])
    y = y + 1
  end

  local statusLine = status or ""
  local maxStatus = math.max(10, w - 4)
  if #statusLine > maxStatus then
    statusLine = statusLine:sub(1, maxStatus - 3) .. "..."
  end
  term.setCursorPos(3, h - 3)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.cyan)
  term.write(statusLine)

  drawFooter(nil)
end

local function drawAnswering(remainSeconds)
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()

  centerText(1, "Answering", colors.yellow, colors.black)
  local playerLabel = string.format("Player %d locked in. 10s timer running.", activePlayer or 0)
  centerText(2, playerLabel, colors.lightGray, colors.black)
  centerText(3, "BTN4 Right | BTN5 Wrong/Next", colors.gray, colors.black)
  centerText(4, "Hold BTN4+BTN5 for 1s to quit", colors.gray, colors.black)

  local question = questions[currentIndex] or {}
  local maxWidth = math.max(16, w - 4)
  local lines = wrapLines(question.question or "?", maxWidth)
  local y = 6
  local maxLines = math.min(#lines, h - 6)
  for i = 1, maxLines do
    term.setCursorPos(3, y)
    term.write(lines[i])
    y = y + 1
  end

  local timerText = answeringExpired and "Time up!" or string.format("Time left: %ds", remainSeconds)
  centerText(h - 3, timerText, colors.orange, colors.black)

  drawFooter(activePlayer)
end

local function drawCelebrate()
  local w, h = term.getSize()
  term.setBackgroundColor(colors.green)
  term.setTextColor(colors.black)
  term.clear()

  centerText(math.floor(h / 2) - 1, "Correct!", colors.black, colors.green)
  centerText(math.floor(h / 2), "Great job!", colors.black, colors.green)

  local answer = questions[currentIndex] and questions[currentIndex].answer
  if answer then
    centerText(math.floor(h / 2) + 2, "Answer: " .. tostring(answer), colors.black, colors.green)
  end

  centerText(h - 2, "BTN5 to skip wait • BTN4+BTN5 to quit", colors.black, colors.green)
end

local function drawFinished()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  centerText(3, "All questions complete.", colors.yellow, colors.black)
  centerText(5, "Hold BTN4+BTN5 to quit or press BTN1 to restart.", colors.lightGray, colors.black)
  drawFooter(nil)
end

-----------------------------
-- INPUT HANDLING           --
-----------------------------

local function pollRedstone()
  local pressedIndex = nil
  for i, btn in ipairs(buttons) do
    local newState = redstone.getInput(btn.side)
    if newState and not lastState[i] then
      pressedIndex = i
    end
    lastState[i] = newState
  end
  return pressedIndex
end

local function pressed(btn)
  if not btn then return end

  -- Simulate momentary press for keyboard path
  if not lastState[btn] then
    lastState[btn] = true
  end

  return btn
end

-----------------------------
-- GAME LOGIC               --
-----------------------------

local function availablePlayerPressed(btn)
  return btn and btn >= 1 and btn <= 3 and not eliminated[btn]
end

local function nextQuestion()
  currentIndex = currentIndex + 1
  activePlayer = nil
  eliminated = {}
  answeringExpired = false
  answerDeadline = nil
  timerId = nil
  celebrateUntil = nil
  if currentIndex > #questions then
    state = "finished"
    drawFinished()
  else
    state = "waiting"
    drawQuestionScreen("Buzz in. 4=Right 5=Wrong. Hold 4+5 Quit.")
  end
end

local function startAnswer(player)
  activePlayer = player
  answerDeadline = os.clock() + 10
  answeringExpired = false
  state = "answering"
  timerId = os.startTimer(0.2)
  drawAnswering(10)
end

local function markCorrect()
  state = "celebrate"
  celebrateUntil = os.clock() + 2
  timerId = os.startTimer(0.2)
  drawCelebrate()
end

local function markIncorrect()
  if activePlayer then
    eliminated[activePlayer] = true
  end
  activePlayer = nil
  answerDeadline = nil
  answeringExpired = false
  timerId = nil
  if countRemainingPlayers(eliminated) == 0 then
    nextQuestion()
  else
    state = "waiting"
    drawQuestionScreen("Wrong. Others may buzz. Hold 4+5 Quit.")
  end
end

local function checkQuitHold()
  if lastState[4] and lastState[5] then
    quitHoldStart = quitHoldStart or os.clock()
    if not quitTimerId then
      quitTimerId = os.startTimer(0.1)
    end
    if os.clock() - quitHoldStart >= 1 then
      return true
    end
  else
    quitHoldStart = nil
    quitTimerId = nil
  end
  return false
end

-----------------------------
-- MAIN LOOP                --
-----------------------------

local function main()
  setLargeTextScale()
  drawQuestionScreen("Buzz in. 4=Right 5=Wrong. Hold 4+5 Quit.")

  while true do
    local event, p1 = os.pullEvent()
    local btn = nil

    if event == "redstone" then
      btn = pollRedstone()
    elseif event == "key" then
      if p1 == keys.q then return end
      btn = keyToButton[p1]
      if btn then
        pressed(btn)
        lastState[btn] = false
      end
    elseif event == "timer" then
      if p1 == timerId then
        timerId = nil
        if state == "answering" then
          local remain = math.max(0, math.ceil(answerDeadline - os.clock()))
          if os.clock() >= answerDeadline then
            answeringExpired = true
            remain = 0
          else
            timerId = os.startTimer(0.2)
          end
          drawAnswering(remain)
        elseif state == "celebrate" then
          if os.clock() >= celebrateUntil then
            nextQuestion()
          else
            timerId = os.startTimer(0.2)
          end
        end
      elseif p1 == quitTimerId then
        quitTimerId = nil
        if checkQuitHold() then
          term.setBackgroundColor(colors.black)
          term.setTextColor(colors.white)
          term.clear()
          centerText(2, "Exiting Quiz Show.", colors.white, colors.black)
          return
        elseif quitHoldStart then
          quitTimerId = os.startTimer(0.1)
        end
      end
    elseif event == "terminate" then
      return
    end

    if checkQuitHold() then
      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.white)
      term.clear()
      centerText(2, "Exiting Quiz Show.", colors.white, colors.black)
      return
    end

    if btn then
      if state == "finished" then
        if btn == 1 then
          currentIndex = 1
          eliminated = {}
          state = "waiting"
          drawQuestionScreen("Restarted. Buzz in. Hold 4+5 Quit.")
        end
      elseif state == "waiting" then
        if availablePlayerPressed(btn) then
          startAnswer(btn)
        end
      elseif state == "answering" then
        if btn == 4 then
          markCorrect()
        elseif btn == 5 then
          markIncorrect()
        end
      elseif state == "celebrate" then
        if btn == 5 then
          nextQuestion()
        end
      end
    end
  end
end

main()
