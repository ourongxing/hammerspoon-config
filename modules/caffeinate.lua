--- require betterdispaly and betterdisplaycli

local M = {}

local origin = {
  PHL = 0.7,
  BuildIn = 0.5,
}

local sleep = {
  PHL = 0.1,
  BuildIn = 0.1,
}

function M.storeBrightness()
  local PHL, statusP = hs.execute([[/opt/homebrew/bin/betterdisplaycli get --name="PHL 279C9" --brightness]])
  local BuildIn, statusB = hs.execute([[/opt/homebrew/bin/betterdisplaycli get --name="Built-In Display" --brightness]])
  if statusP then
    origin.PHL = tonumber(PHL)
  end
  if statusB then
    origin.BuildIn = tonumber(BuildIn)
  end
end

function M.setBrightness(brightness)
  hs.execute('/opt/homebrew/bin/betterdisplaycli set --name="PHL 279C9" --brightness=' ..
    brightness.PHL)
  hs.execute('/opt/homebrew/bin/betterdisplaycli set --name="Built-In Display" --brightness=' ..
    brightness.BuildIn)
end

function M.start()
  M.storeBrightness()
  M.setBrightness(sleep)
  hs.caffeinate.set("displayIdle", true)
end

function M.stop()
  M.setBrightness(origin)
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
