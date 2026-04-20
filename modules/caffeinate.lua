local M = {}

function M.start()
  hs.execute("/usr/bin/pmset displaysleepnow")
  hs.caffeinate.set("displayIdle", true)
end

function M.stop()
  hs.execute("/usr/bin/caffeinate -u -t 1")
  hs.caffeinate.set("displayIdle", false)
end

function M.toggle()
  if hs.caffeinate.get("displayIdle") then
    M.stop()
  else
    M.start()
  end
end

return M
