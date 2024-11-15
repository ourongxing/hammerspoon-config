local O = {}
function O.isLocalHost(host)
	return (host == "localhost" or host == "127.0.0.1" or host == "0.0.0.0" or string.find(host, "192.168."))
end

function O.openURL(fullURL, host)
	if host == nil then
		host = hs.http.urlParts(fullURL).host
	end
	local app = "company.thebrowser.Browser"
	-- if O.isLocalHost(host) then
	-- 	-- app = "com.google.Chrome"
	-- 	app = "com.google.Chrome.canary"
	-- end
	if string.find(host, "jav") then
		app = "com.microsoft.edgemac"
	end
	hs.urlevent.openURLWithBundle(fullURL, app)
end

function O.isLink(str)
	-- 基本的 URL 模式匹配
	local pattern = "([a-zA-Z0-9]+://[-a-zA-Z0-9+&@#/%?=~_|!:,.;]*[-a-zA-Z0-9+&@#/%=~_|])"
	local match = string.match(str, pattern)
	return match and true or false
end

function O.makeNewTabInArc(url, space)
	local applescript = string.format(
		[[
    tell application "Arc"
      tell front window
        tell space "%s" to focus
        make new tab with properties {URL:"%s"}
      end tell

      activate
    end tell
  ]],
		space,
		url
	)
	if space == nil then
		applescript = string.format(
			[[
    tell application "Arc"
      tell front window
        make new tab with properties {URL:"%s"}
      end tell

      activate
    end tell
    ]],
			url
		)
	end
	hs.osascript.applescript(applescript)
end

function O.searchCopiedText()
	local text = hs.pasteboard.getContents()
	if text then
		local url = nil
		if O.isLink(text) then
			url = text
		else
			url = "https://www.google.com/search?q=" .. hs.http.encodeForQuery(text)
		end

		if hs.application.frontmostApplication():name() == "Arc" then
			O.makeNewTabInArc(url)
		else
			O.openURL(url)
		end
	end
end

return O
