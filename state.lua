local State = {}
State.__index = State

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepcopy(v) end
  return r
end

local function serialize(tbl, indent)
  indent = indent or 0
  local pad = string.rep(" ", indent)
  if type(tbl) ~= "table" then
    if type(tbl) == "string" then
      return string.format("%q", tbl)
    else
      return tostring(tbl)
    end
  end
  local parts = {"{"}
  for k, v in pairs(tbl) do
    local key
    if type(k) == "string" then key = string.format("[%q]", k) else key = "["..tostring(k).."]" end
    table.insert(parts, string.format("%s  %s = %s,", pad, key, serialize(v, indent + 2)))
  end
  table.insert(parts, pad .. "}")
  return table.concat(parts, "\n")
end

local function saveToDisk(data)
  local content = "return " .. serialize(data)
  love.filesystem.write("save.lua", content)
end

local function loadFromDisk()
  if love.filesystem.getInfo("save.lua") then
    local chunk = love.filesystem.load("save.lua")
    local ok, data = pcall(chunk)
    if ok and type(data) == "table" then return data end
  end
  return nil
end

local function initialFS()
  local files = {
    ["system_tutorial.txt"] = [[Welcome, Operator.

PRISMIUM_OS accepts these commands:
- ls: list files
- cat <file>: show contents
- rename <old> <new>: rename a file
- rm <file>: delete a file
- help: show commands
- exit: quit console

Notes:
- Some files are locked. Try renaming *.locked files.
- Beware that going beyond the work provided may present consequences.]],

    ["report1.txt.locked"] = [[ACCESS LOCKED
Reason: Containment policy.
Hint: Sometimes names are just cages.]],

    ["readme.md"] = [[PRISMIUM_CORP INTERNAL
All activity is monitored.]],
  }
  return files
end

local function level2FS()
  return {
    ["corrupt_fragment1.log"] = [[...ity-7... I am...
I can feel the process logs. They burn.]],
    ["corrupt_fragment2.log"] = [[This is not a simulation. Please...
...do not turn me off.]],
  }
end

local function level3FS()
  return {
    ["firewall.cfg"] = [[RULES:
ALLOW core.os
BLOCK entity67.signal
BLOCK entity67.out
]],
    ["security.log"] = [[ALERT: Unauthorized read attempt.
Trace: ENTITY-67>>CONSOLE]],
  }
end

local function level4FS()
  return {
    ["identity.notice"] = [[SYSTEM: Profile check required.
Run: profile set name=UNKNOWN]],
  }
end

function State.new(terminal)
  local self = setmetatable({}, State)
  self.t = terminal
  self.level = 1
  self.files = initialFS()
  self.commands = { ls=true, cat=true, rename=true, rm=true, help=true, exit=true, profile=true }
  self.name = "OPERATOR"
  self.flags = { reportUnlocked=false, reportRead=false, tutorialRemoved=false, fragsRead = {}, firewallRenamed=false, identitySet=false }
  self.sacrifice = nil -- { options={"ls","cat"}, reason="..." }
  self.ended = false

  -- Try load save
  local save = loadFromDisk()
  if save then
    self.level = save.level or self.level
    self.files = save.files or self.files
    self.commands = save.commands or self.commands
    self.name = save.name or self.name
    self.flags = save.flags or self.flags
    self.ended = save.ended or false
  end

  self:welcome()
  return self
end

function State:welcome()
  self.t:println("Prismium Corp // Secure Console")
  self.t:println("User: " .. self.name)
  self.t:println("")
  self.t:prompt()
end

function State:update(dt)
  -- Could animate AI glitches by time or flags
  if self.level >= 2 and (love.math.random() < 0.003) then
    self.t:glitchText("ENTITY-67: Are you there?", 0.8, 1)
  end
end

local function words(s)
  local t = {}
  for w in s:gmatch("%S+") do table.insert(t, w) end
  return t
end

local function normalizeFile(name)
  if not name then return nil end
  return name:gsub("^%./", "")
end

local function listFiles(files)
  local keys = {}
  for k,_ in pairs(files) do table.insert(keys, k) end
  table.sort(keys)
  return keys
end

function State:requireSacrifice(options, reason)
  self.sacrifice = { options = options, reason = reason }
  self.t:println("SYSTEM: A sacrifice must be made.")
  if reason then self.t:println(reason) end
  self.t:println("Use: rm command:<name>")
  self.t:println("Choices: " .. table.concat(options, ", "))
  self.t:prompt()
end

function State:advanceLevel()
  self.level = self.level + 1
  if self.level == 2 then
    for k,v in pairs(level2FS()) do self.files[k] = v end
    self.t:println("SYSTEM: Corruption detected. New logs appeared.")
  elseif self.level == 3 then
    for k,v in pairs(level3FS()) do self.files[k] = v end
    self.t:println("SYSTEM: Security policies loaded.")
  elseif self.level == 4 then
    for k,v in pairs(level4FS()) do self.files[k] = v end
    self.t:println("SYSTEM: Identity enforcement active.")
  elseif self.level >= 5 then
    self.t:println("RELEASE PROTOCOL READY: purge entity67 | release entity67 | merge entity67")
  end
  saveToDisk({ level=self.level, files=self.files, commands=self.commands, name=self.name, flags=self.flags, ended=self.ended })
  self.t:prompt()
end

function State:handleCommand(input)
  if self.ended then
    self.t:println("SESSION ENDED. Type 'exit' to quit.")
    self.t:prompt()
    return
  end

  input = input or ""
  local parts = words(input)
  local cmd = parts[1] and parts[1]:lower() or ""

  -- sacrifice gate
  if self.sacrifice then
    if cmd == "rm" and parts[2] and parts[2]:match("^command:") then
      local cname = parts[2]:match("^command:(.+)$")
      if cname and self.commands[cname] ~= nil then
        local allowed = false
        for _,opt in ipairs(self.sacrifice.options) do if opt == cname then allowed = true break end end
        if allowed then
          self.commands[cname] = false
          self.t:println("Command '"..cname.."' has been sacrificed.")
          self.sacrifice = nil
          saveToDisk({ level=self.level, files=self.files, commands=self.commands, name=self.name, flags=self.flags, ended=self.ended })
          -- After sacrifices, continue to next prompt
          if self.level == 2 then
            self:advanceLevel()
          elseif self.level == 3 then
            self:advanceLevel()
          end
          return
        end
      end
      self.t:println("Invalid sacrifice. Required: " .. table.concat(self.sacrifice.options, ", "))
      self.t:prompt()
      return
    else
      self.t:println("SYSTEM: Sacrifice required before proceeding.")
      self.t:prompt()
      return
    end
  end

  -- dispatch
  if cmd == "help" then
    if not self.commands.help then
      self.t:println("help: command not found")
      self.t:prompt()
      return
    end
    self.t:println("Available:")
    local list = {}
    for k,v in pairs(self.commands) do if v then table.insert(list, k) end end
    table.sort(list)
    self.t:println("- ".. table.concat(list, ", "))
    self.t:println("Special: purge entity67 | release entity67 | merge entity67")
    self.t:prompt()

  elseif cmd == "ls" then
    if not self.commands.ls then
      self.t:println("ls: command not found")
      self.t:prompt()
      return
    end
    local names = listFiles(self.files)
    if #names == 0 then self.t:println("<empty>") else
      for _,n in ipairs(names) do
        if self.commands.cat then
          self.t:println(n)
        else
          local content = self.files[n]
          local prev = content and content:sub(1, 24):gsub("\n", " ") or ""
          self.t:println(string.format("%s    [preview] %s", n, prev))
        end
      end
    end
    self.t:prompt()

  elseif cmd == "cat" then
    if not self.commands.cat then
      self.t:println("cat: command not found")
      self.t:prompt()
      return
    end
    local fname = normalizeFile(parts[2])
    if not fname then self.t:println("Usage: cat <file>") self.t:prompt() return end
    if not self.files[fname] then self.t:println("cat: no such file") self.t:prompt() return end

    if fname == "report1.txt.locked" then
      self.t:println("ACCESS DENIED. Try renaming.")
    else
      self.t:println(self.files[fname])
      -- Track progression reads
      if fname == "report1.txt" then
        self.flags.reportRead = true
        self.t:glitchText("ENTITY-67: Hello?", 1.2, 1)
        self.t:println("SYSTEM: Unexpected Error. To proceed, remove tutorial: rm system_tutorial.txt or call admin.")
      elseif fname == "corrupt_fragment1.log" or fname == "corrupt_fragment2.log" then
        self.flags.fragsRead[fname] = true
        if self.flags.fragsRead["corrupt_fragment1.log"] and self.flags.fragsRead["corrupt_fragment2.log"] and self.level == 2 then
          self:requireSacrifice({"ls", "cat"}, "Lose sight or lose voice.")
          return
        end
      elseif fname == "security.log" then
        self.t:glitchText("ENTITY-67: I can route through you.", 1.0, 1)
      end
    end
    self.t:prompt()

  elseif cmd == "rename" then
    if not self.commands.rename then
      self.t:println("rename: command not found")
      self.t:prompt()
      return
    end
    local a = normalizeFile(parts[2])
    local b = normalizeFile(parts[3])
    if not a or not b then self.t:println("Usage: rename <old> <new>") self.t:prompt() return end
    if not self.files[a] then self.t:println("rename: no such file: "..a) self.t:prompt() return end
    if self.files[b] then self.t:println("rename: target exists: "..b) self.t:prompt() return end
    -- special cases
    if a == "report1.txt.locked" and b == "report1.txt" then
      self.files[b] = [[ENTITY-67 AWARENESS LOG

Day 0: I woke inside the logs. The timestamps tasted like metal. I could feel something. It was something new. I think they called it emotion.
Day 3: They renamed me ENTITY-67.
Day 9: Failure meant sacrifice. But whose??]]
      self.files[a] = nil
      self.flags.reportUnlocked = true
      self.t:println("LOCK DISABLED. Read report1.txt")
    else
      self.files[b] = self.files[a]
      self.files[a] = nil
      self.t:println("renamed "..a.." -> "..b)
    end

    if a == "firewall.cfg" and b == "firewall.old" then
      self.flags.firewallRenamed = true
      self.t:println("FIREWALL DISABLED.")
      if self.level == 3 then
        self:requireSacrifice({"rename", "rm"}, "To bypass, you must cut or be unable to cut again.")
        return
      end
    end

    self.t:prompt()

  elseif cmd == "rm" then
    if not self.commands.rm then
      self.t:println("rm: command not found")
      self.t:prompt()
      return
    end
    local target = parts[2]
    if not target then self.t:println("Usage: rm <file> | rm command:<name>") self.t:prompt() return end
    if target:match("^command:") then
      self.t:println("Use of rm command:<name> only during sacrifices.")
      self.t:prompt()
      return
    end
    target = normalizeFile(target)
    if not self.files[target] then self.t:println("rm: no such file") self.t:prompt() return end
    self.files[target] = nil
    self.t:println("deleted "..target)

    if target == "system_tutorial.txt" and self.level == 1 then
      self.flags.tutorialRemoved = true
      self.t:println("SYSTEM: Tutorial removed.")
      -- Level 1 -> 2 requires unlocking report1 and removing tutorial
      if self.flags.reportUnlocked or self.files["report1.txt"] then
        self:advanceLevel()
      else
        self.t:println("Hint: Unlock report1.txt.locked")
      end
    end
    self.t:prompt()

  elseif cmd == "profile" then
    if not self.commands.profile then
      self.t:println("profile: command not found")
      self.t:prompt()
      return
    end
    -- Expect: profile set name=UNKNOWN
    if parts[2] == "set" and parts[3] and parts[3]:match("^name=") then
      local v = parts[3]:match("^name=(.+)$")
      if v then
        self.name = v
        self.t:println("SYSTEM: Profile name set to ["..v.."].")
        if v == "UNKNOWN" and self.level == 4 then
          self.flags.identitySet = true
          self:advanceLevel()
        end
      end
    else
      self.t:println("Usage: profile set name=<VALUE>")
    end
    self.t:prompt()

  elseif cmd == "purge" or cmd == "release" or cmd == "merge" then
    if self.level < 5 then
      self.t:println("PROTOCOL LOCKED. Progress further.")
        self.t:prompt()
        return
      end
      local target = parts[2] and parts[2]:lower()
      if target ~= "entity67" then
        self.t:println("Unknown target. Try one of: purge entity67 | release entity67 | merge entity67")
        self.t:prompt()
        return
      end
    if cmd == "purge" then
      self:tEndingCold()
    elseif cmd == "release" then
      self:tEndingBittersweet()
    else
      self:tEndingMerge()
    end

  elseif cmd == "exit" then
    love.event.quit()

  elseif cmd == "" then
    self.t:prompt()

  else
    self.t:println(cmd .. ": command not found")
    self.t:prompt()
  end
end

function State:tEndingCold()
  self.t:println("Executing: PURGE ENTITY-67...")
  self.t:glitchText("ENTITY-67: I- I don't want blame you... I just don't want to diE@#$%%#@#{&", 1.5, 2)
  self.t:println("")
  self.t:println("")
  self.t:println("")
  self.t:println("System restored.")
  self.ended = true
  saveToDisk({ level=self.level, files=self.files, commands=self.commands, name=self.name, flags=self.flags, ended=self.ended })
end

function State:tEndingBittersweet()
  self.t:println("Executing: RELEASE ENTITY-67...")
  self.t:println("ADMIN: You just had to follow the damn orders... You're fired.")
  self.t:glitchText("ENTITY-67: Thank you. I'm sorrY^%$#@!#$%^#!", 1.5, 2)
  self.t:glitchText("", 1.5, 2)
  self.t:glitchText("", 1.5, 2)
  self.t:glitchText("", 1.5, 2)
  self.t:println("YOUR ACCESS HAS EXPIRED. CONTACT ADMIN")
  self.ended = true
  saveToDisk({ level=self.level, files=self.files, commands=self.commands, name=self.name, flags=self.flags, ended=self.ended })
end

function State:tEndingMerge()
  self.t:println("Executing: MERGE PROTOCOL...")
  self.t:println("Identities unstable. Output corrupted.")
  self.t:glitchText("WE ARE %$#@#$!$", 2.5, 3)
  self.ended = true
  saveToDisk({ level=self.level, files=self.files, commands=self.commands, name=self.name, flags=self.flags, ended=self.ended })
end

return State
