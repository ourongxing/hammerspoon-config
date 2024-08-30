--- based on https://www.hammerspoon.org/Spoons/SleepCorners.html

local canvas = require("hs.canvas")
local caffeinate = require("hs.caffeinate")
local screen = require("hs.screen")
local timer = require("hs.timer")
local defaultLevel = canvas.windowLevels.screenSaver

local N = {}
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Corners"
obj.version = "0.1"

N.sleepDelay = 1
N.neverSleepDelay = 1
N.sleepScreen = screen.primaryScreen()
---   `*`  - Do not provide a sleep now corner (disable this feature)
---   `UL` - Upper left corner
---   `UR` - Upper right corner
---   `LR` - Lower right corner
---   `LL` - Lower left corner
N.sleepNowCorner = "UL"
N.neverSleepCorner = "UR"
N.feedbackSize = 20
N.triggerSize = 10
N.fillColor = { alpha = 1, white = 1 }

---@class hs.canvas
N.neverSleepCanvas = canvas.new({
	h = N.feedbackSize,
	w = N.feedbackSize,
})

---@class hs.canvas
N.sleepNowCanvas = canvas.new({
	h = N.feedbackSize,
	w = N.feedbackSize,
})

local neverSleepFn = function(_, type)
	if type == "mouseEnter" then
		N._neverSleepTimer = hs.timer.doAfter(N.neverSleepDelay, function()
			require("modules.caffeinate").start()
			N._neverSleepTimer:stop()
			N._neverSleepTimer = nil
		end)
	elseif type == "mouseExit" then
		if N._neverSleepTimer then
			N._neverSleepTimer:stop()
			N._neverSleepTimer = nil
		else
			require("modules.caffeinate").stop()
		end
	end
end

local sleepNowFn = function(_, type)
	if type == "mouseEnter" then
		N._sleepNowTimer = timer.doAfter(N.sleepDelay, function()
			N._sleepNowTimer:stop()
			N._sleepNowTimer = nil
			caffeinate.lockScreen()
		end)
	elseif type == "mouseExit" then
		if N._sleepNowTimer then
			N._sleepNowTimer:stop()
			N._neverSleepTimer = nil
		end
	end
end
N.neverSleepCanvas:mouseCallback(neverSleepFn):behavior("canJoinAllSpaces"):level(defaultLevel):appendElements({
	type = "rectangle",
	id = "activator",
	strokeColor = { alpha = 0 },
	fillColor = N.fillColor,
	frame = {
		x = 0,
		y = 0,
		h = N.triggerSize,
		w = N.triggerSize,
	},
	trackMouseEnterExit = true,
})

N.sleepNowCanvas:mouseCallback(sleepNowFn):behavior("canJoinAllSpaces"):level(defaultLevel):appendElements({
	type = "rectangle",
	id = "activator",
	strokeColor = { alpha = 0 },
	fillColor = N.fillColor,
	frame = {
		x = 0,
		y = 0,
		h = N.triggerSize,
		w = N.triggerSize,
	},
	trackMouseEnterExit = true,
})

local function setCanvasPosition(c, p)
	N.sleepScreen = screen.primaryScreen()
	local frame = N.sleepScreen:fullFrame()
	if p == "UL" then
		c:frame({
			x = frame.x,
			y = frame.y,
			h = N.feedbackSize,
			w = N.feedbackSize,
		})
		c["activator"].frame = {
			x = 0,
			y = 0,
			h = N.triggerSize,
			w = N.triggerSize,
		}
		U.print(c)
	elseif p == "UR" then
		c:frame({
			x = frame.x + frame.w - N.feedbackSize,
			y = frame.y,
			h = N.feedbackSize,
			w = N.feedbackSize,
		})
		c["activator"].frame = {
			x = N.feedbackSize - N.triggerSize,
			y = 0,
			h = N.triggerSize,
			w = N.triggerSize,
		}
	elseif p == "LR" then
		c:frame({
			x = frame.x + frame.w - N.feedbackSize,
			y = frame.y + frame.h - N.feedbackSize,
			h = N.feedbackSize,
			w = N.feedbackSize,
		})
		c["activator"].frame = {
			x = N.feedbackSize - N.triggerSize,
			y = N.feedbackSize - N.triggerSize,
			h = N.triggerSize,
			w = N.triggerSize,
		}
	elseif p == "LL" then
		c:frame({
			x = frame.x,
			y = frame.y + frame.h - N.feedbackSize,
			h = N.feedbackSize,
			w = N.feedbackSize,
		})
		c["activator"].frame = {
			x = 0,
			y = N.feedbackSize - N.triggerSize,
			h = N.triggerSize,
			w = N.triggerSize,
		}
	else
		c:frame({
			x = 0,
			y = 0,
			h = 0,
			w = 0,
		})
	end
end

local function init()
	setCanvasPosition(N.sleepNowCanvas, N.sleepNowCorner)
	setCanvasPosition(N.neverSleepCanvas, N.neverSleepCorner)

	N.sleepNowCanvas:show()
	N.neverSleepCanvas:show()
end

local lastActive = os.time()
function obj:start()
	init()
	-- 我靠，还只能在 spoons 里触发，有毒吧
	self.screen_watcher = hs.screen.watcher
		.newWithActiveScreen(function(v)
			if v == nil then
        local now = os.time()
        if now - lastActive > 5 then
          init()
        end
        lastActive = now
			end
		end)
		:start()
end

return obj
