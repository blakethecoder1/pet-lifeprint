NUI = {}
local isOpen = false

--- Send a message to the UI
---@param action string The action name the UI listens for
---@param data? table Optional data payload
function NUI.SendMessage(action, data)
    SendNuiMessage(json.encode({ action = action, data = data or {} }))
end

--- Set UI visibility without changing focus
---@param visible boolean
function NUI.SetVisibility(visible)
    NUI.SendMessage('setVisible', { visible = visible })
end

--- Set NUI focus (keyboard/mouse capture)
---@param hasFocus boolean
---@param hasCursor boolean|nil Defaults to hasFocus if not provided
function NUI.SetFocus(hasFocus, hasCursor)
    SetNuiFocus(hasFocus, hasCursor ~= false and hasFocus)
end

--- Open the UI with optional data
---@param data? table Data to pass to UI on open
function NUI.Open(data)
    if isOpen then return end
    isOpen = true
    NUI.SetFocus(true, true)
    NUI.SendMessage('open', data)
end

--- Close the UI and release focus
function NUI.Close()
    if not isOpen then return end
    isOpen = false
    NUI.SetFocus(false, false)
    NUI.SendMessage('close')
end

--- Check if UI is currently open
---@return boolean
function NUI.IsOpen()
    return isOpen
end

-- Register close callback from UI
RegisterNuiCallback('close', function(_, cb)
    NUI.Close()
    cb({ success = true })
end)
