local frame = hs.screen.primaryScreen():frame()
local feedbackSize = 30
local triggerSize = 20

--- 右上角
---@class hs.canvas
local rightTop = hs.canvas.new {
  x = frame.x + frame.w - feedbackSize,
  y = 0,
  h = feedbackSize,
  w = feedbackSize,
}

rightTop:appendElements {
  type = "rectangle",
  id = "activator",
  strokeColor = { alpha = 0, hex = "#20B2AA" },
  fillColor = { alpha = 0, hex = "#20B2AA" },
  frame = {
    x = feedbackSize - triggerSize,
    y = 0,
    h = triggerSize,
    w = triggerSize,
  },
  trackMouseEnterExit = true,
}

rightTop:behavior("canJoinAllSpaces")
rightTop:level(hs.canvas.windowLevels.screenSaver)
rightTop:show()

local timer = nil
rightTop:mouseCallback(
  function(_, type)
    if type == "mouseEnter" then
      timer = hs.timer.doAfter(0.5, function()
        require("modules.caffeinate").start()
        timer = nil
      end)
    elseif type == "mouseExit" then
      if timer then
        timer:stop()
      else
        require("modules.caffeinate").stop()
      end
      timer = nil
    end
  end
)
