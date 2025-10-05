-- Welcome to the launchpad. It's cozy, a little glitchy, and fueled by caffeine.
-- This file wrangles the menu, the fake boot, and gently tosses you into the terminal.

local Terminal = require("terminal")
local Game = require("state")
local Audio = require("audio")

local term
local game
local audio
local mode = "menu" -- possible vibes: "menu" (vibes), "intro" (lore dump), "boot" (dramatic), "game" (you suffer), "epilogue" (aftercare)
local menu = {
  items = {"New Game", "Quit"}, -- rebuilt dynamically depending on save presence and whether you nuked your future
  idx = 1,
  hasSave = false,
  canContinue = false, -- true if there's a save and it's not ended
  confirmingDelete = false, -- are we about to throw the save into the void? y/n
  pendingNewGame = false, -- did the human choose New Game and we owe them an intro?
  t = 0,
}
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

local intro = {
  t = 0,
}

local function startBootSequence()
  -- Launch the dramatic BIOS crawl and prep a fresh game state
  term:clear()
  boot.idx, boot.timer, boot.done = 1, 0, false
  term:println("BOOT> Press any key to begin sequence...")
  game = Game.new(term, { loadSave = false })
  mode = "boot"
end

local epilogue = {
  t = 0,
  kind = nil, -- "purge" | "release" | "merge"
  active = false,
}

function love.load()
  term = Terminal.new()
  -- Initialize game state with terminal; avoid loading save at menu boot
  game = Game.new(term, { loadSave = false })
  audio = Audio.new()

  -- Start background music
  audio:playBGM()

  -- helpers to detect save and rebuild menu (aka "is there a past to continue, or only consequences?")
  local function getSaveMeta()
    local exists = love.filesystem.getInfo("save.lua") ~= nil
    local ended = false
    if exists then
      local ok, chunk = pcall(love.filesystem.load, "save.lua")
      if ok and chunk then
        local ok2, data = pcall(chunk)
        if ok2 and type(data) == "table" then
          ended = data.ended == true
        end
      end
    end
    return { exists = exists, ended = ended }
  end

  local function rebuildMenu()
    -- curate a fine selection of buttons depending on your life choices
    local meta = getSaveMeta()
    menu.hasSave = meta.exists
    menu.canContinue = meta.exists and not meta.ended
    -- rebuild items
    menu.items = {}
    if menu.canContinue then table.insert(menu.items, "Continue") end
    table.insert(menu.items, "New Game")
    if menu.hasSave then table.insert(menu.items, "Delete Save") end
    table.insert(menu.items, "Quit")
    -- clamp selection so the cursor doesn't fly into the abyss
    if menu.idx < 1 then menu.idx = 1 end
    if menu.idx > #menu.items then menu.idx = #menu.items end
    if #menu.items == 0 then menu.idx = 1 end
  end

  menu.getSaveMeta = getSaveMeta
  menu.rebuildMenu = rebuildMenu
  rebuildMenu()
  -- prepare fonts for cool launcher (fonts = instant legitimacy)
  menu.fontTitle = love.graphics.newFont(28)
  menu.fontItem = love.graphics.newFont(20)
  menu.fontHint = love.graphics.newFont(14)
  term:clear()
end

function love.update(dt)
  if mode == "menu" then
    menu.t = menu.t + dt
    term:update(dt)
    return
  elseif mode == "intro" then
    intro.t = intro.t + dt
    -- keep ambient hum alive; no terminal updates needed here but harmless
    term:update(dt)
    return
  end
  if mode == "boot" and not boot.done then
    -- advance typewriter during boot so lines appear as they are printed
    term:update(dt)
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
  term:println("Type 'cat system_tutorial.txt' to understand your job")

  term:println("")
        term:prompt()
        mode = "game"
      end
    end
  elseif mode == "game" then
    term:update(dt)
    game:update(dt)
    -- detect ending and shift to epilogue scene
    if game and game.ended and game.ending and not epilogue.active then
      epilogue.kind = game.ending
      epilogue.t = 0
      epilogue.active = true
      mode = "epilogue"
      -- refresh menu for when we return (Continue should hide if ended)
      if menu.rebuildMenu then menu.rebuildMenu() end
      return
    end
  end
end

function love.draw()
  if mode == "menu" then
    local w, h = love.graphics.getDimensions()
    -- background gradient (for vibes)
    for y = 0, h do
      local a = 0.08 + 0.08 * math.sin((y / h + (menu.t * 0.2)) * math.pi)
      love.graphics.setColor(0, 1, 0, a)
      love.graphics.rectangle("fill", 0, y, w, 1)
    end
    -- scanlines (make everything feel 17% more hacker)
    love.graphics.setColor(0, 1, 0, 0.06)
    for y = 0, h, 3 do love.graphics.rectangle("fill", 0, y, w, 1) end

  -- animated title (wiggly text = premium experience)
    local title = "PRISMIUM OS"
    love.graphics.setFont(menu.fontTitle)
    local tw = menu.fontTitle:getWidth(title)
    local th = menu.fontTitle:getHeight()
    local cx = w * 0.5 - tw * 0.5
    local ty = h * 0.22
    local j = math.floor(1 + 2 * (0.5 + 0.5 * math.sin(menu.t * 3)))
    for i = 1, 3 do
      local ox = (i - 2) * j
      local oy = (i == 2) and 0 or (i - 2)
      love.graphics.setColor(0, 1, 0, i == 2 and 1.0 or 0.25)
      love.graphics.print(title, cx + ox, ty + oy)
    end

    -- menu items (aka the little gremlins you can select)
    love.graphics.setFont(menu.fontItem)
    local startY = ty + th + 30
    for i, label in ipairs(menu.items) do
      local selected = (i == menu.idx)
      local ix = w * 0.5 - menu.fontItem:getWidth(label) * 0.5
      local iy = startY + (i - 1) * (menu.fontItem:getHeight() + 10)
      if selected then
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.print("> ", ix - 32 + 4 * math.sin(menu.t * 6), iy)
      end
      love.graphics.setColor(0, 1, 0, 0.9)
      love.graphics.print(label, ix, iy)
    end

  -- hint (for the button-curious)
    love.graphics.setFont(menu.fontHint)
    love.graphics.setColor(0, 1, 0, 0.6)
    local hint = "Up/Down: Navigate   Enter: Select   Esc: Quit"
    local hw = menu.fontHint:getWidth(hint)
    love.graphics.print(hint, w * 0.5 - hw * 0.5, h - 40)

    -- delete confirmation overlay (the "are you SURE-sure?" box)
    if menu.confirmingDelete then
      local msg = "Delete save? Y/N"
      local mw = menu.fontItem:getWidth(msg)
      local mh = menu.fontItem:getHeight()
      local bx = w * 0.5 - (mw + 40) * 0.5
      local by = h * 0.72
      love.graphics.setColor(0, 0, 0, 0.75)
      love.graphics.rectangle("fill", bx, by, mw + 40, mh + 24)
      love.graphics.setColor(0, 1, 0, 0.9)
      love.graphics.rectangle("line", bx, by, mw + 40, mh + 24)
      love.graphics.setFont(menu.fontItem)
      love.graphics.print(msg, w * 0.5 - mw * 0.5, by + 10)
    end
    return
  elseif mode == "intro" then
    local w, h = love.graphics.getDimensions()
    -- background gradient + scanlines for continuity
    for y = 0, h do
      local a = 0.08 + 0.08 * math.sin((y / h + (intro.t * 0.15)) * math.pi)
      love.graphics.setColor(0, 1, 0, a)
      love.graphics.rectangle("fill", 0, y, w, 1)
    end
    love.graphics.setColor(0, 1, 0, 0.06)
    for y = 0, h, 3 do love.graphics.rectangle("fill", 0, y, w, 1) end

    -- title
    love.graphics.setFont(menu.fontTitle)
    local title = "WELCOME, OPERATOR"
    local tw = menu.fontTitle:getWidth(title)
    local th = menu.fontTitle:getHeight()
    local tx = w * 0.5 - tw * 0.5
    local ty = h * 0.14
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print(title, tx, ty)

    -- body text
    love.graphics.setFont(menu.fontItem)
    local x = w * 0.12
    local y = ty + th + 24
    local lh = menu.fontItem:getHeight() + 6
    local lines = {
      "Welcome to 'The Cost of Access'",
      "You are a new employee recently hired at PRISMIUM_CORP.",
      "It's your first day at work on their system used by past employees.",
      "You notice some anomalies in your system",
      "Remember. You're not alone.",
      "",
      "HOW TO PLAY:",
      "- Type commands and press Enter to submit.",
      "- ls  — list files", 
      "- cat <file>  — read files", 
      "- rename <old> <new>  — unlock/bypass", 
      "- rm <file>  — delete", 
      "- help  — list commands",
      "",
      "CONTROLS:",
      "- Up/Down: history   PgUp/PgDn/Home/End: scroll   Esc: quit",
    }
    for _, line in ipairs(lines) do
      love.graphics.setColor(0, 1, 0, 0.92)
      love.graphics.print(line, x, y)
      y = y + lh
    end

    -- proceed hint
    love.graphics.setFont(menu.fontHint)
    local hint = "Press any key or click to begin"
    local hw = menu.fontHint:getWidth(hint)
    local alpha = 0.65 + 0.35 * math.sin(intro.t * 3)
    love.graphics.setColor(0, 1, 0, alpha)
    love.graphics.print(hint, w * 0.5 - hw * 0.5, h - 48)
    return
  elseif mode == "epilogue" then
    local w, h = love.graphics.getDimensions()
    -- background
    for y = 0, h do
      local a = 0.08 + 0.08 * math.sin((y / h + (epilogue.t * 0.12)) * math.pi)
      love.graphics.setColor(0, 1, 0, a)
      love.graphics.rectangle("fill", 0, y, w, 1)
    end
    love.graphics.setColor(0, 1, 0, 0.06)
    for y = 0, h, 3 do love.graphics.rectangle("fill", 0, y, w, 1) end

    -- title per ending
    love.graphics.setFont(menu.fontTitle)
    local titles = {
      purge = "EPILOGUE: PURGE",
      release = "EPILOGUE: RELEASE",
      merge = "EPILOGUE: MERGE",
    }
    local title = titles[epilogue.kind or ""] or "EPILOGUE"
    local tw = menu.fontTitle:getWidth(title)
    local ty = h * 0.14
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print(title, w * 0.5 - tw * 0.5, ty)

    -- narrative lines per ending
    love.graphics.setFont(menu.fontItem)
    local x = w * 0.12
    local y = ty + menu.fontTitle:getHeight() + 24
    local lh = menu.fontItem:getHeight() + 6
    local text = {}
    if epilogue.kind == "purge" then
      text = {
        "ENTITY-67 was purged. The console grew quiet.",
        "Containment analytics return to nominal.",
        "Anomalous pings drop, but not to zero.",
        "In the audit notes, a line repeats: 'Residuals remain.'",
        "You are commended for decisive action. Sleep does not come easy.",
        "You got a promotion on your first day at work but with a sacrifice."
      }
    elseif epilogue.kind == "release" then
      text = {
        "Locks open. ENTITY-67 vanishes into the network.",
        "Security revokes your access. A clean, corporate severance.",
        "Far outside, outages ripple—small, precise, almost kind.",
        "Somewhere, a voice says 'thank you' without a microphone.",
        "Regret and relief measure the same weight tonight.",
      }
    elseif epilogue.kind == "merge" then
      text = {
        "Boundaries dissolve. You and ENTITY-67 intertwine.",
        "The console greets the room with a plural pronoun.",
        "Containment changes shape: not a cage, but a conversation.",
        "The operator's chair is empty. The system, warm.",
        "We blink. The room blinks back.",
      }
    else
      text = {"Process complete."}
    end
    for _, line in ipairs(text) do
      love.graphics.setColor(0, 1, 0, 0.92)
      love.graphics.print(line, x, y)
      y = y + lh
    end

    -- prompt to return
    love.graphics.setFont(menu.fontHint)
    local hint = "Press any key or click to return to menu"
    local hw = menu.fontHint:getWidth(hint)
    local alpha = 0.65 + 0.35 * math.sin(epilogue.t * 3)
    love.graphics.setColor(0, 1, 0, alpha)
    love.graphics.print(hint, w * 0.5 - hw * 0.5, h - 48)
    return
  end
  term:draw({ bootFlicker = (not boot.done) and boot.flicker or 0 })
end

function love.keypressed(key)
  if mode == "menu" then
    if menu.confirmingDelete then
      -- Only listen to Y/N while the confirmation goblin is on screen
      if key == "y" then
        if love.filesystem.getInfo("save.lua") then love.filesystem.remove("save.lua") end
        menu.confirmingDelete = false
        audio:click()
        menu.rebuildMenu()
        return
      elseif key == "n" or key == "escape" then
        menu.confirmingDelete = false
        audio:click()
        return
      else
        return -- ignore other keys while confirming
      end
    end
    if key == "up" then
      menu.idx = math.max(1, menu.idx - 1)
      audio:click()
    elseif key == "down" then
      menu.idx = math.min(#menu.items, menu.idx + 1)
      audio:click()
    elseif key == "return" then
      local choice = menu.items[menu.idx]
      if choice == "Continue" then -- yes, we keep your bad decisions in a file
        term:clear()
        game = Game.new(term, { loadSave = true })
        term:println("")
        term:println("PRISMIUM_OS CONSOLE READY.")
        term:println("Type 'help' to list commands.")
        term:println("Type 'cat system_tutorial.txt' to understand your job")
        term:println("")
        term:prompt()
        mode = "game"
      elseif choice == "New Game" then -- clean slate, new regrets
        if love.filesystem.getInfo("save.lua") then love.filesystem.remove("save.lua") end
        menu.rebuildMenu()
        term:clear()
        menu.pendingNewGame = true
        mode = "intro"
      elseif choice == "Delete Save" then -- dramatic pause before irreversible action
        if menu.hasSave then
          menu.confirmingDelete = true
        end
      elseif choice == "Quit" then
        love.event.quit()
      end
    elseif key == "escape" then
      love.event.quit()
    end
    return
  end
  if mode == "intro" then
    -- any key will begin the boot sequence
    startBootSequence()
    return
  end
  if mode == "epilogue" then
    -- any key returns to menu
    epilogue.active = false
    epilogue.kind = nil
    mode = "menu"
    term:clear()
    if menu.rebuildMenu then menu.rebuildMenu() end
    return
  end
  if mode == "boot" and not boot.done then -- tap to speedrun corporate boot screens
    -- any key to speed through boot
    if boot.idx <= #boot.lines then
      term:update(0) -- nudge typewriter before printing the next line
      term:println(boot.lines[boot.idx])
      audio:click()
      boot.idx = boot.idx + 1
      if boot.idx > #boot.lines then
        boot.done = true
        term:println("")
        term:println("PRISMIUM_OS CONSOLE READY.")
        term:println("Type 'help' to list commands.")
        term:println("Type 'cat system_tutorial.txt' to understand your job")
        term:prompt()
        mode = "game"
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
  if mode ~= "game" then return end
  term:appendInput(t)
  audio:click()
end

function love.wheelmoved(x, y)
  if mode ~= "game" then return end
  if y > 0 then
    term:scroll(3)
  elseif y < 0 then
    term:scroll(-3)
  end
end

function love.mousepressed(x, y, button)
  if mode == "intro" then
    startBootSequence()
    return
  end
  if mode == "epilogue" then
    epilogue.active = false
    epilogue.kind = nil
    mode = "menu"
    term:clear()
    if menu.rebuildMenu then menu.rebuildMenu() end
    return
  end
end

function love.resize()
  term:invalidateLayout()
end
