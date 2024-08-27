W = require("modules.window")
-- 通过 Karabiner-Elements 来调用，那边可以用 Caps 键
-- open -g "hammerspoon://restart?app=com.electron.lark"
hs.urlevent.bind("restart", function(eventName, params)
  local appId = params["app"]
  W.restartApp(appId)
end)

-- open -g "hammerspoon://switch?app=com.electron.lark"
hs.urlevent.bind("switch", function(eventName, params)
  local appId = params["app"]
  W.switchApp(appId)
end)

-- 重载配置
hs.urlevent.bind("reload", function(eventName, params)
  -- 这是异步的
  hs.reload()
  -- 包括 karabiner 的配置
  hs.execute("cd ~/dotfiles/_karabiner && /Users/ourongxing/.asdf/shims/bun run build")
end)

-- 始终使用 Chrome 打开本地链接
hs.urlevent.httpCallback = function(scheme, host, params, fullURL)
  if scheme == "file" then
    hs.execute("open -a 'Google Chrome' " .. fullURL)
    return
  end
  require("modules.search").openURL(fullURL, host)
end
