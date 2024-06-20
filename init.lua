-- global variables
V = {}
-- global util functions
U = {}
-- hs 命令行
require("hs.ipc")
require("utils")

U.windowEvent({
	created = function(win)
		U.disableAXEnhancedUserInterface(win)
	end,
})

-- 定时执行
require("modules.cron")
-- URL Scheme
require("modules.urlEvent")
-- 快捷键
require("modules.hotkey")
-- 屏幕角落
require("modules.screenCorner")
