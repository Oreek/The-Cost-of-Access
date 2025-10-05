-- Terminal gremlin lives here. It eats text, spits vibes, and occasionally glitches for drama.

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
  self.glitch = { t = 0, strength = 0, text = nil, ttl = 0 } -- spooky overlay text with a short life span
  self.scrollOffset = 0 -- 0 = pinned to latest
  self.typewriter = {
    queue = {},
    active = nil, -- { text=string, index=int } aka "the current sentence doing a dramatic entrance"
    cps = 60, -- characters per second (choose your poison)
    accum = 0,
  }
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

local function utf8_prefix(s, n)
  -- returns first n UTF-8 codepoints of s (because bytes are chaos and we respect characters)
  if n <= 0 then return "" end
  local i = 1
  local bytes = #s
  local count = 0
  while i <= bytes and count < n do
    count = count + 1
    local c = s:byte(i)
    local step = 1
    if c >= 0xF0 then step = 4
    elseif c >= 0xE0 then step = 3
    elseif c >= 0xC0 then step = 2
    else step = 1 end
    i = i + step
  end
  return s:sub(1, i - 1)
end

function Terminal:_startNextTypeLine()
  local q = self.typewriter.queue
  if #q == 0 then
    self.typewriter.active = nil
    return
  end
  local line = table.remove(q, 1)
  self.typewriter.active = { text = line, index = 0 }
  -- create an empty line to fill
  table.insert(self.lines, "")
  if #self.lines > self.maxLines then table.remove(self.lines, 1) end
end

function Terminal:println(text)
  text = tostring(text or "")
  text = text:gsub("\r\n", "\n")
  -- split on newlines because sometimes one line wants to be many lines, and that's growth
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(self.typewriter.queue, line)
  end
  if not self.typewriter.active then
    self:_startNextTypeLine()
  end
end

function Terminal:printlnInstant(text)
  text = tostring(text or "")
  text = text:gsub("\r\n", "\n")
  -- slap it right into history, no dramatic typing, just vibes
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(self.lines, line)
    if #self.lines > self.maxLines then table.remove(self.lines, 1) end
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
      self.input = "" -- when in doubt, erase the existential dread
    end
  end
end

function Terminal:consumeInput()
  if not self.awaitingInput then return nil end
  local s = self.input
  self:printlnInstant(self.promptStr .. s)
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
  self.glitch.text = text -- spooky text goes brrrr
  self.glitch.ttl = ttl or 1.4
  self.glitch.t = 0
  self.glitch.strength = strength or 1
end

function Terminal:update(dt)
  -- typewriter advance
  if self.typewriter.active then
    local cps = math.max(10, math.min(120, self.typewriter.cps or 60))
    self.typewriter.accum = (self.typewriter.accum or 0) + dt * cps
    local nextIndex = math.floor(self.typewriter.accum)
    if nextIndex > self.typewriter.active.index then
      self.typewriter.active.index = nextIndex
      local target = self.typewriter.active.text or ""
      if self.typewriter.active.index >= utf8.len(target or "") then
        -- finish this line
        if #self.lines == 0 then table.insert(self.lines, target) else self.lines[#self.lines] = target end
        self.typewriter.accum = self.typewriter.accum - nextIndex
        self.typewriter.active = nil
        self:_startNextTypeLine()
      else
        local shown = utf8_prefix(target, self.typewriter.active.index)
        if #self.lines == 0 then table.insert(self.lines, shown) else self.lines[#self.lines] = shown end
      end
    end
  end

  if self.glitch.ttl and self.glitch.ttl > 0 then
    self.glitch.t = (self.glitch.t or 0) + dt
    self.glitch.ttl = self.glitch.ttl - dt
    if self.glitch.ttl <= 0 then
      self.glitch.ttl = 0
      -- clear text to avoid drawing stale overlays
      self.glitch.text = nil
    end
  end
end

function Terminal:isGlitchActive()
  return (self.glitch and (self.glitch.ttl or 0) > 0 and self.glitch.text ~= nil and self.glitch.text ~= "") or false
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

function Terminal:clear()
  self.lines = {}
  self.input = ""
  self.awaitingInput = false
  self.history = {}
  self.historyIdx = 0
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

  local function colorForLine(txt)
    txt = tostring(txt or "")
    if txt:match("^%s*ENTITY%-67:%s*") then
      return 1, 0.4, 0.4, 1 -- light red
    elseif txt:match("^%s*SYSTEM:%s*") then
      return 0.6, 0.8, 1.0, 1 -- light blue
    end
    return 0, 1, 0, 1 -- default green
  end
  -- compute capacity
  local capacity = math.floor((h - self.margin * 2) / self.lineHeight)
  if capacity < 1 then capacity = 1 end
  local overlayActive = (self.glitch.ttl or 0) > 0 and (self.glitch.text ~= nil and self.glitch.text ~= "")
  local overlayRows = overlayActive and 1 or 0
  local historyVisible = capacity - (self.awaitingInput and 1 or 0) - overlayRows -- we save space for drama and for your typing

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
    local r,g,b,a = colorForLine(self.lines[i])
    love.graphics.setColor(r,g,b,a)
    love.graphics.print(self.lines[i], self.margin, y)
    y = y + self.lineHeight
  end
  local lastLineY = y - self.lineHeight

  -- input line
  -- reserved glitch overlay row (so we never cover history lines)
  if overlayActive then
    -- subtle background bars
    love.graphics.setColor(0, 1, 0, 0.06)
    love.graphics.rectangle("fill", 0, y, w, self.lineHeight)
    for i = 1, 3 do
      local by = y + love.math.random(0, math.max(0, self.lineHeight - 2))
      love.graphics.rectangle("fill", 0, by, w, 1)
    end

    -- layered jittered text
    local a = math.max(0, (self.glitch.ttl or 0) / 1.0) -- alpha fades, like my resolve at 2am
    local jitter = math.max(1, math.floor(4 * (self.glitch.strength or 1)))
    local gr,gg,gb,ga = colorForLine(self.glitch.text)
    love.graphics.setColor(gr, gg, gb, 0.45 * a)
    for i = 1, 5 do
      local ox = love.math.random(-jitter, jitter)
      local oy = love.math.random(-1, 1)
      love.graphics.print(self.glitch.text or "", self.margin + ox, y + oy)
    end
    y = y + self.lineHeight
  end
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
    local msg = string.format("[SCROLLED %d] PgUp/PgDn, Home/End", self.scrollOffset) -- you've seen things; press End to return
    local tw = self.font:getWidth(msg)
    love.graphics.print(msg, w - self.margin - tw, h - self.margin - self.lineHeight)
  end

  -- Boot flicker overlay
  if opts and opts.bootFlicker and opts.bootFlicker > 0 then
    local a = 0.08 + 0.05 * math.sin(opts.bootFlicker * math.pi * 2)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.rectangle("fill", 0, 0, w, h)
  end

  -- Glitch overlay text handled in reserved row above; nothing to do here
  -- We did the thing already. Past us is proud. Future us will forget.
end

return Terminal
