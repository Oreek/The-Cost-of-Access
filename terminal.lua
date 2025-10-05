local utf8 = require("utf8")
local Terminal = {}
Terminal.__index = Terminal

function Terminal.new()
  local self = setmetatable({}, Terminal)
  self.lines = {}
  self.maxLines = 500
  self.input = ""
  self.promptStr = "PRISMIUM> "
  self.awaitingInput = false
  self.font = love.graphics.newFont(16)
  self.lineHeight = self.font:getHeight() + 4
  self.margin = 12
  self.history = {}
  self.historyIdx = 0
  self.scanlineCanvas = nil
  self.glitch = { t = 0, strength = 0, text = nil, ttl = 0 }
  self.scrollOffset = 0 -- 0 = pinned to latest
  return self
end

function Terminal:invalidateLayout()
  self.scanlineCanvas = nil
end

function Terminal:setPrompt(str)
  self.promptStr = str or self.promptStr
end

function Terminal:prompt()
  self.awaitingInput = true
  -- when prompting for input, pin view to the bottom so the prompt is visible
  self.scrollOffset = 0
end

function Terminal:println(text)
  table.insert(self.lines, text or "")
  if #self.lines > self.maxLines then
    table.remove(self.lines, 1)
  end
end

function Terminal:appendInput(t)
  if self.awaitingInput then
    self.input = self.input .. t
  end
end

function Terminal:backspace()
  if self.awaitingInput and #self.input > 0 then
    local byteoffset = utf8.offset(self.input, -1)
    if byteoffset then
      self.input = string.sub(self.input, 1, byteoffset - 1)
    else
      self.input = ""
    end
  end
end

function Terminal:consumeInput()
  if not self.awaitingInput then return nil end
  local s = self.input
  self:println(self.promptStr .. s)
  table.insert(self.history, 1, s)
  if #self.history > 50 then table.remove(self.history) end
  self.historyIdx = 0
  self.input = ""
  self.awaitingInput = false
  return s
end

function Terminal:historyUp()
  if #self.history == 0 then return end
  self.historyIdx = math.min(self.historyIdx + 1, #self.history)
  self.input = self.history[self.historyIdx] or ""
end

function Terminal:historyDown()
  if #self.history == 0 then return end
  self.historyIdx = math.max(self.historyIdx - 1, 0)
  if self.historyIdx == 0 then
    self.input = ""
  else
    self.input = self.history[self.historyIdx] or ""
  end
end

function Terminal:glitchText(text, ttl, strength)
  self.glitch.text = text
  self.glitch.ttl = ttl or 1.0
  self.glitch.t = 0
  self.glitch.strength = strength or 1
end

function Terminal:scroll(lines)
  -- positive = scroll up (older), negative = scroll down (newer)
  lines = lines or 0
  self.scrollOffset = self.scrollOffset + math.floor(lines)
  if self.scrollOffset < 0 then self.scrollOffset = 0 end
  if self.scrollOffset > #self.lines then self.scrollOffset = #self.lines end
end

function Terminal:scrollToBottom()
  self.scrollOffset = 0
end

local function drawScanlines(w, h)
  love.graphics.setColor(0, 1, 0, 0.06)
  for y = 0, h, 3 do
    love.graphics.rectangle("fill", 0, y, w, 1)
  end
end

function Terminal:draw(opts)
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(0, 0, 0)

  love.graphics.setFont(self.font)
  love.graphics.setColor(0, 1, 0, 1)

  -- compute capacity
  local capacity = math.floor((h - self.margin * 2) / self.lineHeight)
  if capacity < 1 then capacity = 1 end
  local historyVisible = capacity - (self.awaitingInput and 1 or 0)
  if historyVisible < 0 then historyVisible = 0 end

  -- clamp scroll offset to available history window
  local maxOffset = math.max(0, #self.lines - historyVisible)
  if self.scrollOffset > maxOffset then self.scrollOffset = maxOffset end

  -- determine which slice of lines to show
  local total = #self.lines
  local endIdx = math.max(0, total - self.scrollOffset)
  local startIdx = math.max(1, endIdx - historyVisible + 1)

  -- draw history lines
  local y = self.margin
  for i = startIdx, endIdx do
    love.graphics.print(self.lines[i], self.margin, y)
    y = y + self.lineHeight
  end

  -- input line
  if self.awaitingInput then
    local cursor = ((love.timer.getTime() * 2) % 1) > 0.5 and "_" or " "
    love.graphics.print(self.promptStr .. self.input .. cursor, self.margin, y)
  end

  -- CRT scanlines and subtle vignette
  drawScanlines(w, h)
  love.graphics.setColor(0, 0, 0, 0.12)
  love.graphics.rectangle("fill", 0, 0, w, 8)
  love.graphics.rectangle("fill", 0, h - 8, w, 8)

  -- scrolled indicator
  if self.scrollOffset > 0 then
    love.graphics.setColor(0, 1, 0, 0.6)
    local msg = string.format("[SCROLLED %d] PgUp/PgDn, Home/End", self.scrollOffset)
    local tw = self.font:getWidth(msg)
    love.graphics.print(msg, w - self.margin - tw, h - self.margin - self.lineHeight)
  end

  -- Boot flicker overlay
  if opts and opts.bootFlicker and opts.bootFlicker > 0 then
    local a = 0.08 + 0.05 * math.sin(opts.bootFlicker * math.pi * 2)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.rectangle("fill", 0, 0, w, h)
  end

  -- Glitch overlay text
  if self.glitch.ttl > 0 then
    self.glitch.t = self.glitch.t + love.timer.getDelta()
    self.glitch.ttl = self.glitch.ttl - love.timer.getDelta()
    local a = math.max(0, self.glitch.ttl / 1.0)
    local jitter = math.floor(3 * self.glitch.strength)
    love.graphics.setColor(0, 1, 0, 0.5 * a)
    for i = 1, 3 do
      local ox = love.math.random(-jitter, jitter)
      local oy = love.math.random(-jitter, jitter)
      love.graphics.print(self.glitch.text or "", self.margin + ox, self.margin + oy)
    end
  end
end

return Terminal
