-- Config wizardry: where we decide how big the vibes are and what the window is called
function love.conf(t)
  t.identity = "PRISMIUM_OS"
  t.appendidentity = false
  t.version = "11.5"
  t.console = false
  t.window.title = "PRISMIUM_OS: The Cost of Access" -- dramatic title for dramatic choices
  t.window.width = 1080
  t.window.height = 720
  t.window.vsync = 1
  t.window.msaa = 0
  t.window.resizable = true
  t.window.minwidth = 800
  t.window.minheight = 600
end
