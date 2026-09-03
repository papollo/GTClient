local COMBAT_LOGOUT_OPCODE = 221
local PROTOCOL_VERSION = 1
local COUNTDOWN_INTERVAL = 100

local overlay = nil
local countdownEvent = nil
local currentSessionId = nil
local deadline = nil
local cancelRequested = false
local incomingJSON = nil

local function isValidSessionId(sessionId)
    if type(sessionId) == 'string' then
        return sessionId ~= ''
    end

    return type(sessionId) == 'number' and sessionId >= 0 and sessionId < math.huge and
        sessionId == math.floor(sessionId)
end

local function isValidDuration(duration)
    return type(duration) == 'number' and duration >= 0 and duration < math.huge and
        duration == math.floor(duration)
end

local function cancelCountdownEvent()
    if countdownEvent then
        removeEvent(countdownEvent)
        countdownEvent = nil
    end
end

local function destroyOverlay()
    cancelCountdownEvent()

    if overlay then
        if not overlay:isDestroyed() then
            overlay:ungrabKeyboard()
            overlay:destroy()
        end
        overlay = nil
    end
end

local function reset()
    destroyOverlay()
    currentSessionId = nil
    deadline = nil
    cancelRequested = false
    incomingJSON = nil
end

local function getWindow()
    if not overlay or overlay:isDestroyed() then
        return nil
    end

    return overlay:getChildById('combatLogoutWindow')
end

local function updateCountdown()
    countdownEvent = nil

    local window = getWindow()
    if not window or not deadline then
        return
    end

    local remainingMs = math.max(0, deadline - g_clock.millis())
    window:getChildById('countdown'):setText(tostring(math.ceil(remainingMs / 1000)))

    if remainingMs > 0 then
        countdownEvent = scheduleEvent(updateCountdown, math.min(COUNTDOWN_INTERVAL, remainingMs))
    end
end

local function requestCancel()
    if cancelRequested or currentSessionId == nil or not g_game.isOnline() then
        return true
    end

    local protocol = g_game.getProtocolGame()
    if not protocol then
        return true
    end

    cancelRequested = true

    local window = getWindow()
    if window then
        local cancelButton = window:getChildById('cancelButton')
        cancelButton:setText('Anulowanie...')
        cancelButton:setEnabled(false)
    end

    protocol:sendExtendedJSONOpcode(COMBAT_LOGOUT_OPCODE, {
        version = PROTOCOL_VERSION,
        action = 'cancel',
        sessionId = currentSessionId
    })
    return true
end

local function createOverlay()
    if overlay and not overlay:isDestroyed() then
        return true
    end

    overlay = g_ui.displayUI('combatlogout', rootWidget)
    if not overlay then
        g_logger.error('[Combat logout] The modal overlay could not be created.')
        return false
    end

    overlay.onKeyPress = function(_, keyCode, keyboardModifiers)
        if keyCode == KeyEscape and keyboardModifiers == KeyboardNoModifier then
            requestCancel()
        end
        return true
    end

    local window = getWindow()
    if not window then
        g_logger.error('[Combat logout] The countdown window is missing from the modal overlay.')
        destroyOverlay()
        return false
    end

    window:setText(utf8ToCp1250('Wylogowywanie'))
    window:getChildById('description'):setText(
        utf8ToCp1250('Wylogowanie nastąpi po zakończeniu odliczania.'))
    window:getChildById('closeButton').onClick = requestCancel
    local cancelButton = window:getChildById('cancelButton')
    cancelButton:setText(utf8ToCp1250('Anuluj'))
    cancelButton.onClick = requestCancel

    overlay:show()
    overlay:raise()
    overlay:focus()
    overlay:grabKeyboard()
    window:show(true)
    window:raise()
    window:focus()
    return true
end

local function startCountdown(data)
    local remainingMs = data.remainingMs
    if remainingMs == nil then
        remainingMs = data.durationMs
    end

    if not isValidSessionId(data.sessionId) then
        g_logger.warning('[Combat logout] Invalid sessionId (type: ' .. type(data.sessionId) .. ', value: ' ..
            tostring(data.sessionId) .. ').')
        return
    end

    if not isValidDuration(remainingMs) then
        g_logger.warning('[Combat logout] Invalid remaining time (type: ' .. type(remainingMs) .. ', value: ' ..
            tostring(remainingMs) .. ').')
        return
    end

    local isSameSession = currentSessionId == data.sessionId
    currentSessionId = data.sessionId
    deadline = g_clock.millis() + remainingMs

    if not isSameSession then
        cancelRequested = false
    end

    if not createOverlay() then
        reset()
        return
    end

    local window = getWindow()
    local cancelButton = window:getChildById('cancelButton')
    cancelButton:setText(cancelRequested and 'Anulowanie...' or 'Anuluj')
    cancelButton:setEnabled(not cancelRequested)

    cancelCountdownEvent()
    updateCountdown()
end

local function cancelCountdown(data)
    if not isValidSessionId(data.sessionId) or currentSessionId ~= data.sessionId then
        return
    end

    reset()
end

local function handlePayload(opcode, data)
    if opcode ~= COMBAT_LOGOUT_OPCODE or type(data) ~= 'table' or data.version ~= PROTOCOL_VERSION or
        type(data.action) ~= 'string' then
        g_logger.warning('[Combat logout] Ignoring invalid opcode payload.')
        return
    end

    if data.action == 'start' then
        g_logger.info('[Combat logout] Received start action.')
        startCountdown(data)
    elseif data.action == 'cancel' then
        g_logger.info('[Combat logout] Received cancel action.')
        cancelCountdown(data)
    else
        g_logger.warning('[Combat logout] Ignoring unknown action: ' .. data.action)
    end
end

local function decodePayload(payload)
    local success, data = pcall(json.decode, payload)
    if not success then
        g_logger.warning('[Combat logout] Invalid JSON payload: ' .. tostring(data))
        return
    end

    handlePayload(COMBAT_LOGOUT_OPCODE, data)
end

local function onExtendedOpcode(_, opcode, buffer)
    if opcode ~= COMBAT_LOGOUT_OPCODE or type(buffer) ~= 'string' or buffer == '' then
        return
    end

    g_logger.info('[Combat logout] Received extended opcode 221 (' .. #buffer .. ' bytes).')

    local status = buffer:sub(1, 1)
    local payload = buffer:sub(2)

    if status == 'S' then
        incomingJSON = payload
        return
    end

    if status == 'P' then
        if incomingJSON == nil then
            g_logger.warning('[Combat logout] Received a JSON continuation without a start packet.')
            return
        end
        incomingJSON = incomingJSON .. payload
        return
    end

    if status == 'E' then
        if incomingJSON == nil then
            g_logger.warning('[Combat logout] Received a JSON end packet without a start packet.')
            return
        end
        payload = incomingJSON .. payload
        incomingJSON = nil
        decodePayload(payload)
        return
    end

    incomingJSON = nil
    decodePayload(status == 'O' and payload or buffer)
end

function init()
    ProtocolGame.registerExtendedOpcode(COMBAT_LOGOUT_OPCODE, onExtendedOpcode)
    connect(g_game, {
        onGameStart = reset,
        onGameEnd = reset
    })
    g_logger.info('[Combat logout] Module loaded; listening on extended opcode 221.')
end

function terminate()
    disconnect(g_game, {
        onGameStart = reset,
        onGameEnd = reset
    })
    pcall(ProtocolGame.unregisterExtendedOpcode, COMBAT_LOGOUT_OPCODE)
    reset()
end
