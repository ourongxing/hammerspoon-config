local M = require("modules.window.undoManager")
local W = {}

-- window name and screen name
local PIP = "Vertical"

function W.focusPip()
	local currentWindow = U.currentWindow()
	local current = currentWindow:screen()
	local pipScreen = hs.screen.find(PIP)
	local pipWindow = hs.window.find(PIP)

	if not pipScreen or not pipWindow then
		return
	end
	local pipWindowFrame = pipWindow:frame()
	local pipScreenFrame = pipScreen:frame()
	pipWindowFrame.y = pipWindowFrame.y + 25
	pipWindowFrame.h = pipWindowFrame.h - 25

	local currentMouse = hs.mouse.absolutePosition()
	if current == pipScreen then
		M.undoManager(function()
			pipWindow:focus()
			hs.mouse.absolutePosition(U.transformPoint(currentMouse, pipScreenFrame, pipWindowFrame))
		end)
	else
		local targetWindows = U.currentSpaceWindows(pipScreen)
		M.undoManager(function()
			targetWindows[1]:focus()
			if currentWindow == pipWindow then
				hs.mouse.absolutePosition(U.transformPoint(currentMouse, pipWindowFrame, pipScreenFrame))
			else
				pipWindow:focus()
				hs.mouse.absolutePosition(targetWindows[1]:frame().center)
			end
		end)
	end
end

local lastFrame
function W.fixed()
	local pipWindow = hs.window.find(PIP)
	if not pipWindow then
		return
	end
	local screen = hs.screen.mainScreen():frame()
	local gap = V.Gap or 6
	local origin = pipWindow:frame()

	local fixedWidth = 200
	local fixedSize = { w = fixedWidth, h = fixedWidth // 12 * 16 }

	local fixedFrame = {
		x = screen.x + (screen.w - fixedSize.w) / 2,
		y = screen.y + screen.h - fixedSize.h,
		w = fixedSize.w,
		h = fixedSize.h
	}

	M.undoManager(function()
		if U.samePosition(origin, fixedFrame) and lastFrame then
			pipWindow:setFrame(lastFrame, U.allowAnimation(lastFrame, origin) and 0.2 or 0)
		else
			lastFrame = origin
			pipWindow:setFrame(fixedFrame, U.allowAnimation(fixedFrame, origin) and 0.2 or 0)
		end
	end)
end

return W
