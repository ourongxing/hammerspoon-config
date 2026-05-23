local M = require("modules.window.undoManager")
local C = {}

function C.prepareWindowTransform(win, type)
	local app = win:application()
	local axApp = hs.axuielement.applicationElement(app)
	if axApp and axApp.AXEnhancedUserInterface then
		axApp.AXEnhancedUserInterface = false
	end

	if app:name() == "Raycast" and win:title() == "" then
		if type == "top" then
			hs.eventtap.keyStroke({}, "up", 200000, app)
		elseif type == "bottom" then
			hs.eventtap.keyStroke({}, "down", 200000, app)
		elseif type == "left" then
			hs.eventtap.keyStroke({}, "left", 200000, app)
		elseif type == "right" then
			hs.eventtap.keyStroke({}, "right", 200000, app)
		end
		return nil
	end
	return win:frame()
end

function C.applyWindowFrame(win, origin, preset)
	if not preset then
		return
	end
	M.undoManager(function()
		win:setFrame(preset, U.allowAnimation(preset, origin) and 0.2 or 0)
	end, { win = win })
end

return C
