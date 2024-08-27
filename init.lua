-- global variables
V = {}
-- global util functions
U = {}
-- hs commandline
require("hs.ipc")
require("utils")

U.windowEvent({
	created = function(win)
		U.disableAXEnhancedUserInterface(win)
	end,
})

-- hs.timer.doAfter(1, function()
-- 	for _, win in ipairs(windows) do
-- 		U.disableAXEnhancedUserInterface(win)
-- 	end
-- end)

-- 定时执行
require("modules.cron")
-- URL Scheme
require("modules.urlEvent")
-- 快捷键
require("modules.hotkey")
-- 屏幕角落
require("modules.sleepCorners")
