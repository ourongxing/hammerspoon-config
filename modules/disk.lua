-- 带 log 的机械硬盘防休眠脚本

local TOUCH_INTERVAL = 30
local KEEP_ALIVE_VOLUMES = {
    "/Volumes/Home",
}

local activeKeepAlive = {}
local M = {
    activeKeepAlive = activeKeepAlive,
    keepAliveVolumes = KEEP_ALIVE_VOLUMES,
}

-- 打印日志
local function log(msg)
    print("[HD KeepAlive] "..msg)
end

local function shellQuote(value)
    return "'"..tostring(value):gsub("'", "'\\''").."'"
end

local function volumeName(path, info)
    if info and info.NSURLVolumeLocalizedNameKey then
        return info.NSURLVolumeLocalizedNameKey
    end
    if info and info.NSURLVolumeNameKey then
        return info.NSURLVolumeNameKey
    end
    return tostring(path):match("([^/]+)$") or tostring(path)
end

local function shouldKeepAlive(volumePath)
    for _, path in ipairs(KEEP_ALIVE_VOLUMES) do
        if path == volumePath then
            return true
        end
    end

    return false
end

local function touchKeepAlive(volumePath)
    local path = volumePath.."/.keepalive"
    local output, ok = hs.execute("touch "..shellQuote(path))

    if ok then
        log("触发 touch: "..path)
    else
        log("touch 失败: "..path.." -> "..(output ~= "" and output or "<empty>"))
    end
end

-- 启动防休眠
local function startKeepAlive(volumePath, name)
    if activeKeepAlive[volumePath] then
        log(name.." 已经在防休眠")
        return
    end

    local timer = hs.timer.doEvery(TOUCH_INTERVAL, function()
        touchKeepAlive(volumePath)
    end)

    touchKeepAlive(volumePath)
    timer:start()
    activeKeepAlive[volumePath] = timer
    log("启动防休眠: "..name.." ("..volumePath..")")
end

-- 停止防休眠
local function stopKeepAlive(volumePath, name)
    local timer = activeKeepAlive[volumePath]
    if timer then
        timer:stop()
        activeKeepAlive[volumePath] = nil
        log("停止防休眠: "..name.." ("..volumePath..")")
    else
        log("停止防休眠: "..name.." 没有找到正在运行的定时器")
    end
end

-- 处理挂载事件
local function handleMount(volumePath, info)
    local name = volumeName(volumePath, info)

    if not shouldKeepAlive(volumePath) then
        return
    end

    log("检测到目标卷: "..name.." ("..volumePath..")")
    startKeepAlive(volumePath, name)
end

-- volume watcher 回调
local volWatcher = hs.fs.volume.new(function(eventType, info)
    info = info or {}
    local path = info.path
    local name = volumeName(path, info)

    if not path then
        log("卷事件缺少 path: "..tostring(eventType))
        return
    end

    if eventType == hs.fs.volume.didMount then
        handleMount(path, info)
    elseif eventType == hs.fs.volume.didUnmount then
        if shouldKeepAlive(path) then
            log("目标卷卸载事件: "..name.." ("..path..")")
            stopKeepAlive(path, name)
        end
    else
        if shouldKeepAlive(path) then
            log("目标卷其他事件: "..tostring(eventType).." -> "..name.." ("..path..")")
        end
    end
end)

volWatcher:start()
M.volWatcher = volWatcher
log("Volume watcher 已启动")

-- 脚本初始化：检查已挂载卷
for path, info in pairs(hs.fs.volume.allVolumes()) do
    handleMount(path, info)
end
log("初始化检查完成")

return M
