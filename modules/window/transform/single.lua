local C = require("modules.window.transform.common")
local S = {}

function S.transform(win, type, superposition)
	local gap = V.Gap or 6
	local screen = win:screen():frame()
	local origin = C.prepareWindowTransform(win, type)
	if not origin then
		return
	end
	local fullW = screen.w
	local fullH = screen.h
	local halfWLeft = (screen.w - gap) // 2
	local halfWRight = halfWLeft
	local halfX = screen.x + halfWLeft + gap
	local halfH = (screen.h - gap) // 2
	local halfY = screen.y + halfH + gap
	local presets = {
		full = { x = screen.x, y = screen.y, w = fullW, h = fullH },
		left = { x = screen.x, y = screen.y, w = halfWLeft, h = fullH },
		right = { x = halfX, y = screen.y, w = halfWRight, h = fullH },
		top = { x = screen.x, y = screen.y, w = fullW, h = halfH },
		bottom = { x = screen.x, y = halfY, w = fullW, h = halfH },
		["vertical-above"] = { x = screen.x, y = screen.y, w = fullW, h = halfH },
		["vertical-below"] = { x = screen.x, y = halfY, w = fullW, h = halfH },
		["left-top"] = { x = screen.x, y = screen.y, w = halfWLeft, h = halfH },
		["left-bottom"] = { x = screen.x, y = halfY, w = halfWLeft, h = halfH },
		["right-top"] = { x = halfX, y = screen.y, w = halfWRight, h = halfH },
		["right-bottom"] = { x = halfX, y = halfY, w = halfWRight, h = halfH },
		reasonable = {
			x = win:screen():frame().x + win:screen():frame().w * 0.2,
			y = win:screen():frame().y + win:screen():frame().h * 0.1,
			w = win:screen():frame().w * 0.6,
			h = win:screen():frame().h * 0.8,
		},
		center = {
			x = screen.x + (screen.w - origin.w) / 2,
			y = screen.y + (screen.h - origin.h) / 2,
			w = origin.w,
			h = origin.h,
		},
	}

	local function withPatterns(patterns, fallback)
		for _, v in ipairs(patterns) do
			if U.sameFrame(origin, presets[v[1]]) then
				return presets[v[2]]
			end
		end
		return presets[fallback]
	end

	local preset = presets[type]
	if superposition then
		if type == "left" or type == "right" then
			local reverse = type == "right" and "left" or "right"
			local patterns = {
				{ "top", type .. "-" .. "top" },
				{ "bottom", type .. "-" .. "bottom" },
				{ reverse .. "-" .. "top", type .. "-" .. "top" },
				{ reverse .. "-" .. "bottom", type .. "-" .. "bottom" },
				{ type .. "-" .. "top", reverse .. "-" .. "top" },
				{ type .. "-" .. "bottom", reverse .. "-" .. "bottom" },
				{ type, reverse },
			}
			preset = withPatterns(patterns, type)
		elseif type == "top" or type == "bottom" then
			local reverse = type == "bottom" and "top" or "bottom"
			local patterns = {
				{ "left", "left" .. "-" .. type },
				{ "right", "right" .. "-" .. type },
				{ "left" .. "-" .. reverse, "left" .. "-" .. type },
				{ "right" .. "-" .. reverse, "right" .. "-" .. type },
				{ "left" .. "-" .. type, "left" .. "-" .. reverse },
				{ "right" .. "-" .. type, "right" .. "-" .. reverse },
				{ type, reverse },
			}
			preset = withPatterns(patterns, type)
		end
	end

	C.applyWindowFrame(win, origin, preset)
end

return S
