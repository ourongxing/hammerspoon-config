--# selene: allow(unused_variable)
---@diagnostic disable: unused-local

-- Modal keybindings environment management. Just an wrapper of `hs.hotkey.modal`.
--
-- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ModalMgr.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ModalMgr.spoon.zip)
---@class spoon.ModalMgr
local M = {}
spoon.ModalMgr = M

-- Activate all modal environment in `idList`.
--
-- Parameters:
--  * idList - An table specifying IDs of modal environments
--  * trayColor - An optional string (e.g. #000000) specifying the color of modalTray, defaults to `nil`.
--  * showKeys - A optional boolean value to show all available keybindings, defaults to `nil`.
function M:activate(idList, trayColor, showKeys, ...) end

-- Deactivate modal environments in `idList`.
--
-- Parameters:
--  * idList - An table specifying IDs of modal environments
function M:deactivate(idList, ...) end

-- Deactivate all active modal environments.
function M:deactivateAll() end

-- Create a new modal keybindings environment
--
-- Parameters:
--  * id - A string specifying ID of new modal keybindings
function M:new(id) end

-- Toggle the cheatsheet display of current modal environments's keybindings.
--
-- Parameters:
--  * iterList - An table specifying IDs of modal environments or active_list. Optional, defaults to all active environments.
--  * force - A optional boolean value to force show cheatsheet, defaults to `nil` (automatically).
function M:toggleCheatsheet(idList, force, ...) end

