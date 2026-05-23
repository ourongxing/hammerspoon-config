local C = require("modules.window.transform.common")
local Single = require("modules.window.transform.single")
local UTransform = {}

local function getHorizontalScreenFrame(screens)
	screens = screens or hs.screen.allScreens()
	if not screens or #screens == 0 then
		return hs.screen.mainScreen():frame()
	end
	for _, s in ipairs(screens) do
		local f = s:frame()
		if f.w > f.h then
			return f
		end
	end
	return hs.screen.mainScreen():frame()
end

local function getUnifiedFrame(screens)
	screens = screens or hs.screen.allScreens()
	if not screens or #screens < 2 then
		return hs.screen.mainScreen():frame(), nil
	end
	local horizontalFrame = getHorizontalScreenFrame(screens)
	local minX, maxRight = math.huge, -math.huge
	local leftFrame, rightFrame
	for _, s in ipairs(screens) do
		local f = s:frame()
		if f.x < minX then
			minX = f.x
			leftFrame = f
		end
		maxRight = math.max(maxRight, f.x + f.w)
	end
	local splitX = minX + leftFrame.w
	for _, s in ipairs(screens) do
		local f = s:frame()
		if f.x >= splitX then
			rightFrame = f
			break
		end
	end
	rightFrame = rightFrame or horizontalFrame
	local verticalAbove, verticalBelow
	local gap = V.Gap or 6
	for _, f in ipairs({ leftFrame, rightFrame }) do
		if f and f.h > f.w then
			local hTop = horizontalFrame.y - f.y
			local hBottom = (f.y + f.h) - (horizontalFrame.y + horizontalFrame.h)
			if hTop > gap then
				verticalAbove = { x = f.x, y = f.y, w = f.w, h = hTop - gap // 2 }
			end
			if hBottom > gap then
				verticalBelow = {
					x = f.x,
					y = horizontalFrame.y + horizontalFrame.h + gap // 2,
					w = f.w,
					h = hBottom - (gap - gap // 2),
				}
			end
			break
		end
	end
	return {
		x = minX,
		y = horizontalFrame.y,
		w = maxRight - minX,
		h = horizontalFrame.h,
	}, {
		splitX = splitX,
		leftScreen = leftFrame,
		rightScreen = rightFrame,
		verticalAbove = verticalAbove,
		verticalBelow = verticalBelow,
	}
end

local function unifiedRegions(screen, split)
	local gap = V.Gap or 6
	local vertical = split.leftScreen and split.leftScreen.h > split.leftScreen.w and split.leftScreen
		or split.rightScreen and split.rightScreen.h > split.rightScreen.w and split.rightScreen
		or nil
	local horizontal = split.leftScreen and split.leftScreen.w > split.leftScreen.h and split.leftScreen
		or split.rightScreen and split.rightScreen.w > split.rightScreen.h and split.rightScreen
		or nil
	if not (vertical and horizontal) then
		return nil
	end

	local cLeftW = (horizontal.w - gap) // 2
	local cRightX = horizontal.x + cLeftW + gap
	local verticalTopH = (vertical.h - gap) // 2
	local verticalBottomY = vertical.y + verticalTopH + gap
	local regions = {
		A = split.verticalAbove,
		B = { x = vertical.x, y = screen.y, w = vertical.w, h = screen.h },
		D = split.verticalBelow,
		VT = { x = vertical.x, y = vertical.y, w = vertical.w, h = verticalTopH },
		VB = { x = vertical.x, y = verticalBottomY, w = vertical.w, h = vertical.y + vertical.h - verticalBottomY },
		CL = { x = horizontal.x, y = horizontal.y, w = cLeftW, h = horizontal.h },
		CR = { x = cRightX, y = horizontal.y, w = horizontal.x + horizontal.w - cRightX, h = horizontal.h },
		C = { x = horizontal.x, y = horizontal.y, w = horizontal.w, h = horizontal.h },
		BC = { x = screen.x, y = screen.y, w = screen.w, h = screen.h },
		ABD = { x = vertical.x, y = vertical.y, w = vertical.w, h = vertical.h },
	}
	regions.AB = regions.A and { x = vertical.x, y = vertical.y, w = vertical.w, h = screen.y + screen.h - vertical.y }
		or nil
	regions.BD = regions.D and { x = vertical.x, y = screen.y, w = vertical.w, h = regions.D.y + regions.D.h - screen.y }
		or nil
	return regions
end

local function regionName(origin, regions)
	for _, name in ipairs({ "A", "B", "D", "AB", "BD", "ABD", "VT", "VB", "CL", "CR", "C", "BC" }) do
		if regions[name] and U.sameFrame(origin, regions[name]) then
			return name
		end
	end
	return nil
end

local function compactRegionList(regions, names)
	local result = {}
	for _, name in ipairs(names) do
		if regions[name] then
			result[#result + 1] = name
		end
	end
	return result
end

function UTransform.transform(win, type, superposition, screens)
	local screen, split = getUnifiedFrame(screens)
	if not split then
		return Single.transform(win, type, superposition)
	end
	local origin = C.prepareWindowTransform(win, type)
	if not origin then
		return
	end
	local regions = unifiedRegions(screen, split)
	if not regions then
		return Single.transform(win, type, superposition)
	end

	local current = regionName(origin, regions)
	local centerX = origin.x + origin.w / 2
	local inVerticalColumn = centerX >= regions.B.x and centerX <= regions.B.x + regions.B.w
	local verticalCycle = compactRegionList(regions, { "A", "B", "D", "AB", "BD", "VT", "VB" })
	local horizontalCycle = compactRegionList(regions, { "B", "CL", "CR" })
	local preset = ({
		full = regions.BC,
		left = regions.B,
		right = regions.CL,
		top = regions.A or regions.B,
		bottom = regions.D or regions.B,
		["vertical-above"] = regions.A or regions.B,
		["vertical-below"] = regions.D or regions.B,
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
	})[type]

	if superposition then
		if type == "top" or type == "bottom" then
			local index = nil
			for i, name in ipairs(verticalCycle) do
				if current == name then
					index = i
					break
				end
			end
			if index then
				local nextIndex = type == "top" and (index - 2) % #verticalCycle + 1 or index % #verticalCycle + 1
				preset = regions[verticalCycle[nextIndex]]
			elseif current == "ABD" then
				preset = regions[type == "top" and "VB" or "A"] or regions.B
			elseif inVerticalColumn then
				preset = regions[type == "top" and "A" or "D"] or regions.B
			end
		elseif type == "left" then
			local index = nil
			for i, name in ipairs(horizontalCycle) do
				if current == name then
					index = i
					break
				end
			end
			if index then
				local nextIndex = (index - 2) % #horizontalCycle + 1
				preset = regions[horizontalCycle[nextIndex]]
			elseif current == "C" or current == "BC" then
				preset = regions.CR
			elseif inVerticalColumn then
				preset = regions.B
			end
		elseif type == "right" then
			local index = nil
			for i, name in ipairs(horizontalCycle) do
				if current == name then
					index = i
					break
				end
			end
			if index then
				local nextIndex = index % #horizontalCycle + 1
				preset = regions[horizontalCycle[nextIndex]]
			elseif current == "C" or current == "BC" then
				preset = regions.B
			elseif inVerticalColumn then
				preset = regions.B
			end
		end
	end

	C.applyWindowFrame(win, origin, preset)
end

return UTransform
