local PVP_ARENA_OPCODE = 220
local PROTOCOL_VERSION = 1
local FINISH_DISPLAY_TIME = 5000
local COUNTDOWN_INTERVAL = 1000

local COLOR_OLD_CAMP = '#7fb6ff'
local COLOR_NEW_CAMP = '#ff8f8f'
local COLOR_SCORE = '#f0f0f0'
local COLOR_WINNER = '#73d673'
local COLOR_DIMMED = '#858585'
local COLOR_NEUTRAL = '#ffd65a'

local hudPanel = nil
local currentState = nil
local countdownEvent = nil
local finishHideEvent = nil

local function cancelCountdown()
    if countdownEvent then
        removeEvent(countdownEvent)
        countdownEvent = nil
    end
end

local function cancelFinishHide()
    if finishHideEvent then
        removeEvent(finishHideEvent)
        finishHideEvent = nil
    end
end

local function getWidget(id)
    return hudPanel and hudPanel:recursiveGetChildById(id) or nil
end

local function getOldCampPanel()
    return getWidget('oldCampPanel')
end

local function getNewCampPanel()
    return getWidget('newCampPanel')
end

local function formatTime(seconds)
    local safeSeconds = math.max(0, math.floor(seconds))
    return string.format('%02d:%02d', math.floor(safeSeconds / 60), safeSeconds % 60)
end

local function clearResult()
    local result = getWidget('result')
    if result then
        result:setText('')
        result:hide()
    end
end

local function resetColors()
    local oldCampPanel = getOldCampPanel()
    oldCampPanel.campName:setColor(COLOR_OLD_CAMP)
    oldCampPanel.campScore:setColor(COLOR_SCORE)

    local newCampPanel = getNewCampPanel()
    newCampPanel.campName:setColor(COLOR_NEW_CAMP)
    newCampPanel.campScore:setColor(COLOR_SCORE)

    getWidget('arenaName'):setColor('#d8d8d8')
    getWidget('remainingTime'):setColor('#ffffff')
end

local function resetHud()
    cancelCountdown()
    cancelFinishHide()
    currentState = nil

    if not hudPanel then
        return
    end

    hudPanel:hide()
    local oldCampPanel = getOldCampPanel()
    oldCampPanel.campName:setText('')
    oldCampPanel.campScore:setText('')

    local newCampPanel = getNewCampPanel()
    newCampPanel.campName:setText('')
    newCampPanel.campScore:setText('')

    getWidget('arenaName'):setText('')
    getWidget('remainingTime'):setText('00:00')
    clearResult()
    resetColors()
end

local function renderState()
    if not hudPanel or not currentState then
        return
    end

    local oldCampPanel = getOldCampPanel()
    oldCampPanel.campName:setText(currentState.oldCampName)
    oldCampPanel.campScore:setText(string.format('%d/%d', currentState.oldCampScore, currentState.scoreLimit))

    local newCampPanel = getNewCampPanel()
    newCampPanel.campName:setText(currentState.newCampName)
    newCampPanel.campScore:setText(string.format('%d/%d', currentState.newCampScore, currentState.scoreLimit))

    getWidget('arenaName'):setText(currentState.arenaName)
    getWidget('remainingTime'):setText(formatTime(currentState.remainingSeconds))
    hudPanel:show()
    hudPanel:raise()
end

local function scheduleCountdown()
    cancelCountdown()

    if not currentState or currentState.remainingSeconds <= 0 then
        return
    end

    countdownEvent = scheduleEvent(function()
        countdownEvent = nil
        if not currentState then
            return
        end

        currentState.remainingSeconds = math.max(0, currentState.remainingSeconds - 1)
        getWidget('remainingTime'):setText(formatTime(currentState.remainingSeconds))
        scheduleCountdown()
    end, COUNTDOWN_INTERVAL)
end

local function isNonEmptyString(value)
    return type(value) == 'string' and value ~= ''
end

local function isNonNegativeInteger(value)
    return type(value) == 'number' and value >= 0 and value == math.floor(value)
end

local function parseSnapshot(data)
    if not isNonEmptyString(data.arenaId) or not isNonEmptyString(data.arenaName) or
        not isNonEmptyString(data.oldCampName) or not isNonEmptyString(data.newCampName) or
        not isNonNegativeInteger(data.oldCampScore) or not isNonNegativeInteger(data.newCampScore) or
        not isNonNegativeInteger(data.scoreLimit) or data.scoreLimit == 0 or
        not isNonNegativeInteger(data.remainingSeconds) then
        return nil
    end

    return {
        arenaId = data.arenaId,
        arenaName = data.arenaName,
        oldCampName = data.oldCampName,
        newCampName = data.newCampName,
        oldCampScore = math.min(data.oldCampScore, data.scoreLimit),
        newCampScore = math.min(data.newCampScore, data.scoreLimit),
        scoreLimit = data.scoreLimit,
        remainingSeconds = data.remainingSeconds
    }
end

local function showFinish(data)
    local snapshot = parseSnapshot(data)
    local validWinners = { oldCamp = true, newCamp = true, neutral = true }
    local validReasons = { scoreLimit = true, timeLimitDefended = true, timeLimitNeutral = true }

    if not snapshot or not validWinners[data.winner] or not validReasons[data.reason] then
        return
    end

    cancelCountdown()
    cancelFinishHide()
    currentState = snapshot
    currentState.remainingSeconds = 0
    resetColors()
    renderState()

    local oldCampPanel = getOldCampPanel()
    local oldCampName = oldCampPanel.campName
    local oldCampScore = oldCampPanel.campScore
    local newCampPanel = getNewCampPanel()
    local result = getWidget('result')

    if data.winner == 'oldCamp' then
        oldCampName:setColor(COLOR_WINNER)
        oldCampScore:setColor(COLOR_WINNER)
        newCampPanel.campName:setColor(COLOR_DIMMED)
        newCampPanel.campScore:setColor(COLOR_DIMMED)
        result:setText(snapshot.oldCampName .. ' wygrywa')
    elseif data.winner == 'newCamp' then
        oldCampName:setColor(COLOR_DIMMED)
        oldCampScore:setColor(COLOR_DIMMED)
        newCampPanel.campName:setColor(COLOR_WINNER)
        newCampPanel.campScore:setColor(COLOR_WINNER)
        result:setText(snapshot.newCampName .. ' wygrywa')
    else
        oldCampName:setColor(COLOR_NEUTRAL)
        oldCampScore:setColor(COLOR_NEUTRAL)
        newCampPanel.campName:setColor(COLOR_NEUTRAL)
        newCampPanel.campScore:setColor(COLOR_NEUTRAL)
        getWidget('arenaName'):setColor(COLOR_NEUTRAL)
        result:setText('Remis')
    end

    result:show()
    finishHideEvent = scheduleEvent(function()
        finishHideEvent = nil
        resetHud()
    end, FINISH_DISPLAY_TIME)
end

local function onExtendedOpcode(protocol, opcode, data)
    if opcode ~= PVP_ARENA_OPCODE or type(data) ~= 'table' or data.version ~= PROTOCOL_VERSION or
        type(data.action) ~= 'string' then
        return
    end

    if data.action == 'hide' then
        if isNonEmptyString(data.arenaId) and currentState and currentState.arenaId == data.arenaId then
            resetHud()
        end
        return
    end

    if data.action == 'finish' then
        showFinish(data)
        return
    end

    if data.action ~= 'state' then
        return
    end

    local snapshot = parseSnapshot(data)
    if not snapshot then
        return
    end

    cancelFinishHide()
    currentState = snapshot
    resetColors()
    clearResult()
    renderState()
    scheduleCountdown()
end

function init()
    hudPanel = g_ui.loadUI('pvparenahud', modules.game_interface.getMapPanel())
    hudPanel:hide()

    ProtocolGame.registerExtendedJSONOpcode(PVP_ARENA_OPCODE, onExtendedOpcode)
    connect(g_game, {
        onGameStart = resetHud,
        onGameEnd = resetHud
    })
end

function terminate()
    disconnect(g_game, {
        onGameStart = resetHud,
        onGameEnd = resetHud
    })
    pcall(ProtocolGame.unregisterExtendedJSONOpcode, PVP_ARENA_OPCODE)

    resetHud()
    if hudPanel then
        hudPanel:destroy()
        hudPanel = nil
    end
end
