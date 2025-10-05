-- Mark of ownership lol

local Terminal = require("terminal")
local Game = require("state")
local Audio = require("audio")

local term
local game
local audio
local boot = {
  lines = {
    "PRISMIUM BIOS v2.7",
    "Memory Check.................... OK",
    "Storage: PRISMIUM_DISK_01........ OK",
    "Initializing containment kernel...",
    "Warning: ENTITY-67 residual signals detected",
    "Loading PRISMIUM_OS...",
  },
  idx = 1,
  timer = 0,
  delay = 0.75,
  done = false,
  flicker = 0,
}

function love.load()
  love.graphics.setBackgroundColor(0, 0, 0)
  audio = Audio.new()
  audio:playHum()
  term = Terminal.new()
  game = Game.new(term)
  -- Boot screen prefill
  term:println("BOOT> Press any key to begin sequence...")
end

function love.update(dt)
  if not boot.done then
    boot.timer = boot.timer + dt
    boot.flicker = (boot.flicker + dt * 9) % 1
    if boot.timer >= boot.delay and boot.idx <= #boot.lines then
      boot.timer = 0
      term:println(boot.lines[boot.idx])
      audio:click()
      boot.idx = boot.idx + 1
      if boot.idx > #boot.lines then
        boot.done = true
        term:println("")
        term:println("PRISMIUM_OS CONSOLE READY.")
        term:println("Type 'help' to list commands.")
        term:println("")
        term:prompt()
      end
    end
  else
    game:update(dt)
  end
end

function love.draw()
  term:draw({ bootFlicker = (not boot.done) and boot.flicker or 0 })
end

function love.keypressed(key)
  if not boot.done then
    -- any key to speed through boot
    if boot.idx <= #boot.lines then
      term:println(boot.lines[boot.idx])
      audio:click()
      boot.idx = boot.idx + 1
      if boot.idx > #boot.lines then
        boot.done = true
        term:println("")
        term:println("PRISMIUM_OS CONSOLE READY.")
        term:println("Type 'help' to list commands.")
        term:prompt()
      end
    end
    return
  end
  if key == "return" then
    local input = term:consumeInput()
    if input ~= nil then
      audio:click()
      game:handleCommand(input)
      -- After executing, ensure we pin to latest so new output is visible
      term:scrollToBottom()
    end
  elseif key == "backspace" then
    term:backspace()
    audio:click()
  elseif key == "escape" then
    -- Quick exit safety
    love.event.quit()
  elseif key == "up" then
    term:historyUp()
  elseif key == "down" then
    term:historyDown()
  elseif key == "pageup" then
    term:scroll(10)
  elseif key == "pagedown" then
    term:scroll(-10)
  elseif key == "home" then
    term:scroll(999999)
  elseif key == "end" then
    term:scrollToBottom()
  end
end

function love.textinput(t)
  if not boot.done then return end
  term:appendInput(t)
  audio:click()
end

function love.wheelmoved(x, y)
  if not boot.done then return end
  if y > 0 then
    term:scroll(3)
  elseif y < 0 then
    term:scroll(-3)
  end
end

function love.resize()
  term:invalidateLayout()
end
