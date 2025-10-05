-- Audio: tiny clicky dopamine and a low hum so it feels like a real angry machine
local Audio = {}
Audio.__index = Audio

local function makeSineBuffer(freq, seconds, sampleRate)
  -- synth a polite hum without shipping giant audio files
  sampleRate = sampleRate or 22050
  local samples = math.floor(seconds * sampleRate)
  local sd = love.sound.newSoundData(samples, sampleRate, 16, 1)
  for i = 0, samples - 1 do
    local t = i / sampleRate
    local v = math.sin(2 * math.pi * freq * t) * 0.1
    sd:setSample(i, v)
  end
  return sd
end

local function makeClickBuffer(sampleRate)
  -- DIY key click: crunchy lil' pop with fast decay, like a shy popcorn
  sampleRate = sampleRate or 22050
  local samples = math.floor(0.015 * sampleRate)
  local sd = love.sound.newSoundData(samples, sampleRate, 16, 1)
  for i = 0, samples - 1 do
    local t = i / sampleRate
    -- Exponential decay click
    local v = (math.random() * 2 - 1) * math.exp(-t * 80) * 0.2
    sd:setSample(i, v)
  end
  return sd
end

function Audio.new()
  local self = setmetatable({}, Audio)
  self.clickSrc = love.audio.newSource(makeClickBuffer(), "static")
  self.humSrc = love.audio.newSource(makeSineBuffer(70, 2.0), "static")
  self.humSrc:setLooping(true)
  self.humSrc:setVolume(0.4)

  -- Load BGM if present (optional asset)
  if love.filesystem.getInfo("bgm.mp3") then
    self.bgmSrc = love.audio.newSource("bgm.mp3", "stream")
    self.bgmSrc:setLooping(true)
    self.bgmSrc:setVolume(0.5)
  else
    self.bgmSrc = nil
  end

  return self
end

function Audio:click()
  if self.clickSrc:isPlaying() then
    self.clickSrc:stop()
  end
  self.clickSrc:play() -- press button, get serotonin
end

function Audio:playHum()
  if not self.humSrc:isPlaying() then
    self.humSrc:play() -- hum engages; immersion +3
  end
end

function Audio:playBGM()
  if self.bgmSrc and (not self.bgmSrc:isPlaying()) then
    self.bgmSrc:play() -- start the background music if available
  end
end

return Audio
