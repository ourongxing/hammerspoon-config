--# selene: allow(unused_variable)
---@diagnostic disable: unused-local

-- Trigger or prevent screen saver/sleep by moving your mouse pointer to specified hot corners on your screen.
--
-- While this functionality is provided by macOS in the Mission Control System Preferences, it doesn't provide any type of visual feedback so it's easy to forget which corners have been assigned which roles.
--
-- For best results while using this spoon, it is recommended that you disable "Start Screen Saver" and "Disable Screen Saver" if they are currently assigned to a corner with the Mission Control System Preferences Panel as this Spoon can't override them and may result in confusing or incorrect behavior.
--
-- The visual feed back provided by this spoon is of a small plus (for triggering sleep now) or a small minus (to prevent sleep) when the mouse pointer is moved into the appropriate corner. This feedback was inspired by a vague recollection of an early Mac screen saver (After Dark maybe?) which provided similar functionality. If someone knows for certain, please inform me and I will give appropriate attribution.
--
-- Note that sleep prevention is not guaranteed; macOS may override our attempts at staying awake in extreme situations (CPU temperature dangerously high, low battery, etc.) See `hs.caffeinate` for more details.
--
-- Download: https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SleepCorners.spoon.zip
---@class spoon.SleepCorners
local M = {}
spoon.SleepCorners = M

-- Binds hotkeys for SleepCorners
--
-- Parameters:
--  * `mapping` - A table containing hotkey modifier/key details for one or more of the following commands:
--    * "start"  - start monitoring the defined corners
--    * "stop"   - stop monitoring the defined corners
--    * "toggle" - toggles monitoring on or off
--    * "show"   - shows the current corners for 3 seconds as a reminder of their assigned locations
--
-- Returns:
--  * the SleepCorners spoon object
--
-- Notes:
--  * the `mapping` table is a table of one or more key-value pairs of the format `command = { { modifiers }, key }` where:
--    * `command`   - is one of the commands listed above
--    * `modifiers` - is a table containing keyboard modifiers, as specified in `hs.hotkey.bind()`
--    * `key`       - is a string containing the name of a keyboard key, as specified in `hs.hotkey.bind()`
---@return spoon.SleepCorners
function M:bindHotkeys(mapping, ...) end

-- Specifies the height and width in screen pixels, default 20, of the visual feedback to be displayed when the mouse pointer moves into one of the recognized hot corners
M.feedbackSize = nil

-- A table, default `{ fn = true }`, specifying keyboard modifiers which if held when the mouse pointer enters the sleep now hot corner will trigger sleep immediately rather then delay for [SleepCorners.sleepDelay](#sleepDelay) seconds.
--
-- This variable may be set to nil or an empty table, disabling the immediate sleep option, or a table containing one or more of the following keys:
--
--   * `fn`    - Set to true to require that the `Fn` key be pressed. May not be available on all keyboards, especially non-Apple ones.
--   * `cmd`   - Set to true to require that the Command (⌘) key be pressed
--   * `alt`   - Set to true to require that the Alt (or Option) (⌥) key be pressed
--   * `shift` - Set to true to require that the Shift (⇧) key be pressed
--   * `ctrl`  - Set to true to require that the Control (^) key be pressed
--
-- If this table contains multiple keys, then all of the specified modifiers must be pressed for immediate sleep to take affect.
M.immediateSleepModifiers = nil

-- Specifies whether the sleep now corner, when the modifiers defined for [SleepCorners.immediateSleepModifiers](#immediateSleepModifiers) are also held, should trigger the display sleep or lock the users session. Defaults to true.
--
-- When this variable is set to true, triggering the sleep now corner for immediate sleep will lock the users session. When this variable is false, the display will be put to sleep instead.
--
-- Note that depending upon the user's settings in the Security & Privacy System Preferences, triggering the display sleep may also lock the user session immediately.
M.immediateSleepShouldLock = nil

-- Returns whether or not the sleep corners are currently active
--
-- Parameters:
--  * None
--
-- Returns:
--  * `true` if the sleep corners are currently active or `false` if they are not
--
-- Notes:
--  * This method only identifies whether or not the SleepCorners spoon has been started; it does not check whether or not the specified corners have been set to a location of "*" with [SleepCorners.sleepNowCorner](#sleepNowCorner) or [SleepCorners.neverSleepCorner](#neverSleepCorner).
--  * If you want to check to see if SleepCorners has been started and that at least one of the corners is assigned to a corner, you should use something like `SleepCorners:isActive() and (SleepCorners.sleepNowCorner ~= "*" or SleepCorners.neverSleepCorner ~= "*")`
---@return boolean
function M:isActive() end

-- Specifies the location of the never sleep corner on the screen. Defaults to "LR".
--
-- This variable may be set to one of the following string values:
--
--   * `*`  - Do not provide a sleep now corner (disable this feature)
--   * `UL` - Upper left corner
--   * `UR` - Upper right corner
--   * `LR` - Lower right corner
--   * `LL` - Lower left corner
M.neverSleepCorner = nil

-- A table, default `{ fn = true }`, specifying keyboard modifiers which if held when the mouse pointer enters the never sleep hot corner will disable display sleep and leave it disabled even if the mouse pointer leaves the hot corner. While the never sleep lock is in effect the never sleep visual feedback will remain visible in the appropriate corner of the screen. The never sleep lock may is unlocked when you move the mouse pointer back into the never sleep corner with the modifiers held down a second time or move the mouse pointer into the sleep now corner.
--
-- This variable may be set to nil or an empty table, disabling the never sleep lock option, or a table containing one or more of the following keys:
--
--   * `fn`    - Set to true to require that the `Fn` key be pressed. May not be available on all keyboards, especially non-Apple ones.
--   * `cmd`   - Set to true to require that the Command (⌘) key be pressed
--   * `alt`   - Set to true to require that the Alt (or Option) (⌥) key be pressed
--   * `shift` - Set to true to require that the Shift (⇧) key be pressed
--   * `ctrl`  - Set to true to require that the Control (^) key be pressed
--
-- If this table contains multiple keys, then all of the specified modifiers must be pressed for the never sleep lock to be triggered.
M.neverSleepLockModifiers = nil

-- Specifies which action should be preferred if both the sleep now and never sleep hot corners are assigned to the same location on the screen. The default is false.
--
-- If this variable is set to `true`, then sleep now action will be triggered if both hot corners are assigned to the same location on the screen. If this variable is set to `false`, then the never sleep action will be triggered.
--
-- Note that this variable has no effect if the hot corners are distinct (i.e. are not assigned to the same corner)
M.preferSleepNow = nil

-- Temporarily show the SleepCorner feedback images in their current locations as a reminder of their positions on the screen.
--
-- Parameters:
--  * `duration` - an optional number, default 3, specifying the number of seconds the feedback images should be displayed. If you specify `false` and the feedback images are currently being shown, the timer will be cur short and the images will be removed immediately.
--
-- Returns:
--  * the SleepCorners spoon object
--
-- Notes:
--  * this method will temporarily show the feedback images even if SleepCorners has been stopped (or has not yet been started).
---@return spoon.SleepCorners
function M:show(duration, ...) end

-- Specifies the number of seconds, default 2, the mouse pointer must remain within the trigger area of the sleep now corner in order to put the system's display to sleep.
--
-- When the mouse pointer moves into the trigger area for the sleep now hot corner, visual feedback will be provided for the user. If the user does not move the mouse pointer out of the trigger area within the number of seconds specified by this variable, display sleep will be activated.
M.sleepDelay = nil

-- Specifies the location of the sleep now corner on the screen. Defaults to "LL".
--
-- This variable may be set to one of the following string values:
--
--   `*`  - Do not provide a sleep now corner (disable this feature)
--   `UL` - Upper left corner
--   `UR` - Upper right corner
--   `LR` - Lower right corner
--   `LL` - Lower left corner
M.sleepNowCorner = nil

-- Specifies whether the sleep now corner should trigger the display sleep or lock the users session. Defaults to false.
--
-- When this variable is set to true, triggering the sleep now corner will lock the users session. When this variable is false, the display will be put to sleep instead.
--
-- Note that depending upon the user's settings in the Security & Privacy System Preferences, triggering the display sleep may also lock the user session immediately.
M.sleepNowShouldLock = nil

-- Specifies the screen on which the sleep corners are made active. Defaults to the value returned by `hs.screen.primaryScreen()`.
--
-- This variable may be set to an `hs.screen` userdata object or a function which returns an `hs.screen` userdata object. For example, to make the sleep corners active on the screen with the currently focused window, you could use the following function:
--
--     SleepCorners.sleepScreen = function()
--         return hs.screen.mainScreen()
--     end
M.sleepScreen = nil

-- Starts monitoring the defined sleep corners to allow triggering or preventing the system display  sleep state.
--
-- Parameters:
--  * None
--
-- Returns:
--  * the SleepCorners spoon object
--
-- Notes:
--  * has no effect if SleepCorners has already been started
---@return spoon.SleepCorners
function M:start() end

-- Stop monitoring the defined sleep corners.
--
-- Parameters:
--  * None
--
-- Returns:
--  * the SleepCorners spoon object
--
-- Notes:
--  * has no effect if SleepCorners has already been stopped
--  * if SleepCorners was active, this method will return the display idle sleep setting back to its previous state and reset the never sleep lock if it has been triggered.
---@return spoon.SleepCorners
function M:stop() end

-- Toggles or sets whether or not SleepCorners is currently monitoring the defined screen corners for managing the system display's sleep state and displays an alert indicating the new state of the SleepCorners spoon.
--
-- Parameters:
--  * `state` - an optional boolean which specifies specifically whether SleepCorners should be started if it isn't already running (true) or stopped if it currently is running (false)
--
-- Returns:
--  * the SleepCorners spoon object
--
-- Notes:
--  * If `state` is not provided, this method will start SleepCorners if it is currently stopped or stop it if is currently started.
--  * `SleepCorners:toggle(true)` is equivalent to [SleepCorners:start()](#start) with the addition of displaying an alert specifying that SleepCorners is active.
--  * `SleepCorners:toggle(false)` is equivalent to [SleepCorners:stop()](#stop) with the addition of displaying an alert specifying that SleepCorners has been deactivated.
---@return spoon.SleepCorners
function M:toggle(state, ...) end

-- Specifies the height and width in screen pixels, default 2, of the trigger area for the recognized hot corners.
--
-- The trigger area, which may be smaller than the [SleepCorners.feedbackSize](#feedbackSize) area, is the region which the mouse pointer must be moved into before the specified feedback or sleep activity will occur.
M.triggerSize = nil

