local CRAFTING_OPCODE = 219
local CONTRACT_VERSION = 1
local REFRESH_DEBOUNCE = 100

local COLOR_NORMAL = '#CFCFCF'
local COLOR_MUTED = '#7F7F7F'
local COLOR_ERROR = '#E86A6A'
local COLOR_SUCCESS = '#70C66B'
local COLOR_WARNING = '#E5B85C'

local craftingWindow = nil
local ui = nil
local refreshEvent = nil
local sessionId = nil
local stationType = nil
local recipes = {}
local selectedRecipeId = nil
local selectedDetail = nil
local craftPending = false
local pendingRequestId = nil
local requestCounter = 0
local closeSent = false
local unknownCodesLogged = {}

local RESULT_MESSAGES = {
    SUCCESS = 'Item crafted successfully.',
    CRAFT_FAILED = 'Crafting attempt failed.',
    NOT_ENOUGH_MATERIALS = 'Not enough materials.',
    MISSING_SOURCE_ITEM = 'Required source item is missing.',
    LOW_SKILL = 'Required skill level is too low.',
    LOW_SPECIALIZATION = 'Required specialization level is too low.',
    NO_CAPACITY = 'Not enough capacity or inventory space.',
    LOCKED_RECIPE = 'This recipe is locked.',
    TOO_FAR = 'You are too far from the crafting station.',
    INVALID_SESSION = 'The crafting session is no longer valid.',
    INVALID_RECIPE = 'The selected recipe is no longer available.',
    INTERNAL_ERROR = 'Crafting failed due to an internal error.',
    STATION_REMOVED = 'The crafting station is no longer available.',
    SESSION_EXPIRED = 'The crafting session has expired.',
    SESSION_REPLACED = 'The crafting session was replaced.'
}

local STATION_NAMES = {
    smith = 'Smithing station',
    bowmaster = 'Bowmaster station',
    armorer = 'Armorer station',
    rune = 'Rune station',
    alchemy = 'Alchemy station',
    cooking = 'Cooking station'
}

local function child(id)
    return craftingWindow and craftingWindow:recursiveGetChildById(id) or nil
end

local function bindUi()
    ui = {
        recipeList = child('recipeList'),
        recipesEmptyLabel = child('recipesEmptyLabel'),
        stationLabel = child('stationLabel'),
        chanceLabel = child('chanceLabel'),
        blockLabel = child('blockLabel'),
        detailList = child('detailList'),
        resultIcon = child('resultIcon'),
        resultName = child('resultName'),
        craftButton = child('craftButton'),
        feedbackLabel = child('feedbackLabel')
    }
end

local function logError(message)
    g_logger.error('[Crafting] ' .. tostring(message))
end

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeNumber(value)
    return isFiniteNumber(value) and value >= 0
end

local function isPositiveInteger(value)
    return isFiniteNumber(value) and value >= 1 and math.floor(value) == value
end

local function isNonEmptyString(value)
    return type(value) == 'string' and value:trim() ~= ''
end

local function validateArray(value, validator)
    if type(value) ~= 'table' then
        return false
    end

    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or math.floor(key) ~= key then
            return false
        end
        count = count + 1
    end

    for index = 1, count do
        if value[index] == nil or (validator and not validator(value[index])) then
            return false
        end
    end
    return true
end

local function validateRecipeSummary(recipe)
    return type(recipe) == 'table'
        and isNonEmptyString(recipe.id)
        and isNonEmptyString(recipe.name)
        and isPositiveInteger(recipe.clientId)
        and isPositiveInteger(recipe.resultCount)
        and isNonEmptyString(recipe.category)
        and (recipe.recipeType == 'craft' or recipe.recipeType == 'upgrade')
end

local function validateRequirement(requirement)
    return type(requirement) == 'table'
        and isNonEmptyString(requirement.type)
        and isNonEmptyString(requirement.name)
        and isNonNegativeNumber(requirement.current)
        and isNonNegativeNumber(requirement.required)
        and type(requirement.enough) == 'boolean'
end

local function validateItemRequirement(item)
    return type(item) == 'table'
        and isPositiveInteger(item.clientId)
        and isNonEmptyString(item.name)
        and isNonNegativeNumber(item.owned)
        and isPositiveInteger(item.required)
        and type(item.enough) == 'boolean'
end

local function validateDetail(detail)
    if not validateRecipeSummary(detail)
        or type(detail.canCraft) ~= 'boolean'
        or (detail.blockCode ~= nil and not isNonEmptyString(detail.blockCode))
        or (detail.chance ~= nil and (not isFiniteNumber(detail.chance) or detail.chance < 0
            or detail.chance > 100000 or math.floor(detail.chance) ~= detail.chance))
        or not validateArray(detail.requirements, validateRequirement)
        or not validateArray(detail.materials, validateItemRequirement) then
        return false
    end

    if (detail.canCraft and detail.blockCode ~= nil)
        or (not detail.canCraft and not isNonEmptyString(detail.blockCode)) then
        return false
    end

    return detail.source == nil or validateItemRequirement(detail.source)
end

local function validateRecipes(value)
    if not validateArray(value, validateRecipeSummary) then
        return false
    end

    local ids = {}
    for _, recipe in ipairs(value) do
        if ids[recipe.id] then
            return false
        end
        ids[recipe.id] = true
    end
    return true
end

local function validateRecipeSelection(recipeList, detail)
    if #recipeList == 0 then
        return detail == nil
    end
    if not validateDetail(detail) then
        return false
    end

    for _, recipe in ipairs(recipeList) do
        if recipe.id == detail.id then
            return recipe.name == detail.name
                and recipe.clientId == detail.clientId
                and recipe.resultCount == detail.resultCount
                and recipe.category == detail.category
                and recipe.recipeType == detail.recipeType
        end
    end
    return false
end

local function getMessage(code)
    local key = RESULT_MESSAGES[code]
    if not key then
        local codeKey = tostring(code)
        if not unknownCodesLogged[codeKey] then
            unknownCodesLogged[codeKey] = true
            logError('Unknown response code: ' .. codeKey)
        end
        key = 'Unknown crafting response.'
    end
    return tr(key)
end

local function setFeedback(text, color)
    if not ui or not ui.feedbackLabel then
        return
    end
    ui.feedbackLabel:setText(text or '')
    ui.feedbackLabel:setColor(color or COLOR_NORMAL)
end

local function setBlockCode(code)
    if not ui or not ui.blockLabel then
        return
    end
    if isNonEmptyString(code) then
        ui.blockLabel:setText(getMessage(code))
        ui.blockLabel:show()
    else
        ui.blockLabel:setText('')
        ui.blockLabel:hide()
    end
end

local function clearItem(widget)
    if widget then
        widget:setItem(nil)
        widget:setOpacity(1.0)
    end
end

local function clearDetails()
    selectedDetail = nil
    if not ui then
        return
    end
    ui.detailList:destroyChildren()
    ui.chanceLabel:setText('')
    ui.chanceLabel:hide()
    setBlockCode(nil)
    clearItem(ui.resultIcon)
    ui.resultName:setText('')
    ui.craftButton:setEnabled(false)
end

local function cancelScheduledRefresh()
    if refreshEvent then
        removeEvent(refreshEvent)
        refreshEvent = nil
    end
end

local function getProtocol()
    return g_game.getProtocolGame()
end

local function sendMessage(action, data)
    local protocol = getProtocol()
    if not protocol then
        return false
    end
    protocol:sendExtendedJSONOpcode(CRAFTING_OPCODE, {
        version = CONTRACT_VERSION,
        action = action,
        data = data
    })
    return true
end

local function sendStatus()
    if not sessionId or not selectedRecipeId or craftPending then
        return false
    end
    return sendMessage('status', {
        sessionId = sessionId,
        recipeId = selectedRecipeId
    })
end

local function scheduleInventoryRefresh()
    cancelScheduledRefresh()
    if not craftingWindow or not craftingWindow:isVisible() or not sessionId or not selectedRecipeId or craftPending then
        return
    end

    refreshEvent = scheduleEvent(function()
        refreshEvent = nil
        if craftingWindow and craftingWindow:isVisible() and sessionId and selectedRecipeId and not craftPending then
            sendStatus()
        end
    end, REFRESH_DEBOUNCE)
end

local function resetSession()
    cancelScheduledRefresh()
    sessionId = nil
    stationType = nil
    recipes = {}
    selectedRecipeId = nil
    selectedDetail = nil
    craftPending = false
    pendingRequestId = nil
    closeSent = false

    if ui then
        ui.recipeList:destroyChildren()
        ui.recipesEmptyLabel:hide()
        ui.stationLabel:setText('')
        clearDetails()
        setFeedback('', COLOR_NORMAL)
    end
end

local function findRecipe(recipeId)
    for _, recipe in ipairs(recipes) do
        if recipe.id == recipeId then
            return recipe
        end
    end
    return nil
end

local function setRecipeChecked(recipeId)
    for _, widget in ipairs(ui.recipeList:getChildren()) do
        widget:setChecked(widget.recipeId == recipeId)
    end
end

local function renderRecipeList()
    ui.recipeList:destroyChildren()
    ui.recipesEmptyLabel:setVisible(#recipes == 0)

    for _, recipe in ipairs(recipes) do
        local recipeId = recipe.id
        local row = g_ui.createWidget('CraftingRecipeRow', ui.recipeList)
        local icon = row:recursiveGetChildById('icon')
        local name = row:recursiveGetChildById('name')
        local displayName = recipe.name
        if recipe.resultCount > 1 then
            displayName = string.format('%s x%d', displayName, recipe.resultCount)
        end

        row.recipeId = recipeId
        icon:setItemId(recipe.clientId)
        icon:setItemCount(recipe.resultCount)
        name:setText(displayName)
        row:setTooltip(displayName)
        row:setChecked(recipeId == selectedRecipeId)
        row.onClick = function()
            selectedRecipeId = recipeId
            setRecipeChecked(selectedRecipeId)
            clearDetails()
            setFeedback('', COLOR_NORMAL)
            sendStatus()
        end
    end
end

local function createSection(text)
    local label = g_ui.createWidget('CraftingSectionLabel', ui.detailList)
    label:setText(text)
end

local function renderRequirement(requirement)
    local row = g_ui.createWidget('CraftingRequirementRow', ui.detailList)
    local name = row:recursiveGetChildById('name')
    local value = row:recursiveGetChildById('value')
    local status = row:recursiveGetChildById('status')

    name:setText(requirement.name)
    value:setText(string.format('%s / %s', tostring(requirement.current), tostring(requirement.required)))
    if requirement.enough then
        name:setColor(COLOR_NORMAL)
        value:setColor(COLOR_NORMAL)
        status:setText('')
    else
        name:setColor(COLOR_MUTED)
        value:setColor(COLOR_MUTED)
        status:setText(tr('Requirement not met'))
    end
end

local function renderItemRequirement(item, missingText)
    local row = g_ui.createWidget('CraftingMaterialRow', ui.detailList)
    local icon = row:recursiveGetChildById('icon')
    local name = row:recursiveGetChildById('name')
    local amount = row:recursiveGetChildById('amount')
    local status = row:recursiveGetChildById('status')

    icon:setItemId(item.clientId)
    icon:setItemCount(item.required)
    name:setText(item.name)
    amount:setText(string.format('%s / %s', tostring(item.owned), tostring(item.required)))
    row:setTooltip(item.name)

    if item.enough then
        icon:setOpacity(1.0)
        name:setColor(COLOR_NORMAL)
        amount:setColor(COLOR_NORMAL)
        status:setText('')
    else
        icon:setOpacity(0.4)
        name:setColor(COLOR_MUTED)
        amount:setColor(COLOR_MUTED)
        status:setText(tr(missingText))
    end
end

local function formatChance(chance)
    local text = string.format('%.1f', chance / 1000)
    local locale = modules.client_locales and modules.client_locales.getCurrentLocale
        and modules.client_locales.getCurrentLocale() or nil
    if locale and locale.name == 'pl' then
        text = text:gsub('%.', ',')
    end
    return text .. '%'
end

local function renderDetail(detail)
    selectedDetail = detail
    ui.detailList:destroyChildren()

    if detail.chance ~= nil then
        ui.chanceLabel:setText(string.format('%s: %s', tr('Success chance'), formatChance(detail.chance)))
        ui.chanceLabel:show()
    else
        ui.chanceLabel:setText('')
        ui.chanceLabel:hide()
    end

    setBlockCode(detail.canCraft and nil or detail.blockCode)

    if #detail.requirements > 0 then
        createSection(tr('Requirements'))
        for _, requirement in ipairs(detail.requirements) do
            renderRequirement(requirement)
        end
    end

    if detail.source then
        createSection(tr('Source item'))
        renderItemRequirement(detail.source, 'Missing source item')
    end

    createSection(tr('Materials'))
    if #detail.materials == 0 then
        local empty = g_ui.createWidget('CraftingEmptyRow', ui.detailList)
        empty:setText(tr('No materials required'))
    else
        for _, material in ipairs(detail.materials) do
            renderItemRequirement(material, 'Not enough materials')
        end
    end

    ui.resultIcon:setItemId(detail.clientId)
    ui.resultIcon:setItemCount(detail.resultCount)
    if detail.resultCount > 1 then
        ui.resultName:setText(string.format('%s x%d', detail.name, detail.resultCount))
    else
        ui.resultName:setText(detail.name)
    end
    ui.resultIcon:setTooltip(ui.resultName:getText())
    ui.craftButton:setEnabled(detail.canCraft and not craftPending)
end

local function showInvalidData(message, showDialog)
    logError(message)
    craftPending = false
    pendingRequestId = nil
    if ui then
        ui.craftButton:setEnabled(false)
        setFeedback(tr('Invalid crafting data received.'), COLOR_ERROR)
    end
    if showDialog then
        displayErrorBox(tr('Crafting'), tr('Invalid crafting data received.'))
    end
end

local function handleOpen(data)
    if type(data) ~= 'table'
        or not isNonEmptyString(data.sessionId)
        or not isNonEmptyString(data.stationType)
        or not validateRecipes(data.recipes)
        or not validateRecipeSelection(data.recipes, data.detail) then
        logError('Invalid open payload.')
        resetSession()
        craftingWindow:hide()
        displayErrorBox(tr('Crafting'), tr('Invalid crafting data received.'))
        return
    end

    resetSession()
    sessionId = data.sessionId
    stationType = data.stationType
    recipes = data.recipes

    local stationName = STATION_NAMES[stationType] or stationType
    ui.stationLabel:setText(string.format('%s: %s', tr('Current station'), tr(stationName)))

    if data.detail and findRecipe(data.detail.id) then
        selectedRecipeId = data.detail.id
    elseif #recipes > 0 then
        selectedRecipeId = recipes[1].id
    end

    renderRecipeList()
    if data.detail and data.detail.id == selectedRecipeId then
        renderDetail(data.detail)
    elseif selectedRecipeId then
        clearDetails()
        sendStatus()
    else
        clearDetails()
        setFeedback(tr('No unlocked recipes'), COLOR_MUTED)
    end

    craftingWindow:show()
    craftingWindow:raise()
    craftingWindow:focus()
end

local function handleDetail(data)
    if type(data) ~= 'table' or not isNonEmptyString(data.sessionId) then
        showInvalidData('Invalid detail payload.', false)
        return
    end
    if data.sessionId ~= sessionId then
        return
    end
    if not validateDetail(data.detail) then
        showInvalidData('Invalid detail payload.', false)
        return
    end
    if data.detail.id ~= selectedRecipeId then
        return
    end
    renderDetail(data.detail)
end

local function handleCraftResult(data)
    if type(data) ~= 'table' or not isNonEmptyString(data.sessionId) or not isNonEmptyString(data.requestId) then
        showInvalidData('Invalid craftResult payload.', false)
        return
    end
    if data.sessionId ~= sessionId or data.requestId ~= pendingRequestId then
        return
    end
    if type(data.success) ~= 'boolean'
        or not isNonEmptyString(data.resultCode)
        or not validateRecipes(data.recipes)
        or not validateRecipeSelection(data.recipes, data.detail) then
        showInvalidData('Invalid craftResult payload.', false)
        return
    end

    local previousRecipeId = selectedRecipeId
    craftPending = false
    pendingRequestId = nil
    recipes = data.recipes

    if previousRecipeId and findRecipe(previousRecipeId) then
        selectedRecipeId = previousRecipeId
    elseif data.detail and findRecipe(data.detail.id) then
        selectedRecipeId = data.detail.id
    elseif #recipes > 0 then
        selectedRecipeId = recipes[1].id
    else
        selectedRecipeId = nil
    end

    renderRecipeList()
    if data.detail and data.detail.id == selectedRecipeId then
        renderDetail(data.detail)
    elseif selectedRecipeId then
        clearDetails()
        sendStatus()
    else
        clearDetails()
    end

    local color = COLOR_ERROR
    if data.resultCode == 'SUCCESS' and data.success then
        color = COLOR_SUCCESS
    elseif data.resultCode == 'CRAFT_FAILED' then
        color = COLOR_WARNING
    end
    setFeedback(getMessage(data.resultCode), color)
end

local function handleServerClose(data)
    if type(data) ~= 'table' or not isNonEmptyString(data.sessionId) then
        showInvalidData('Invalid close payload.', false)
        return
    end
    if data.sessionId ~= sessionId then
        return
    end
    if not isNonEmptyString(data.reasonCode) then
        logError('Invalid close payload.')
        resetSession()
        craftingWindow:hide()
        displayErrorBox(tr('Crafting'), tr('Invalid crafting data received.'))
        return
    end

    local message = getMessage(data.reasonCode)
    resetSession()
    craftingWindow:hide()
    displayErrorBox(tr('Crafting'), message)
end

local function onCraftingOpcode(protocol, opcode, message)
    if type(message) ~= 'table' then
        showInvalidData('Payload is not a table.', not sessionId)
        return
    end
    if message.version ~= CONTRACT_VERSION then
        logError('Unsupported protocol version: ' .. tostring(message.version))
        resetSession()
        if craftingWindow then
            craftingWindow:hide()
        end
        displayErrorBox(tr('Crafting'), tr('Unsupported crafting protocol version.'))
        return
    end
    if not isNonEmptyString(message.action) or type(message.data) ~= 'table' then
        showInvalidData('Invalid message envelope.', not sessionId)
        return
    end

    if message.action == 'open' then
        handleOpen(message.data)
    elseif message.action == 'detail' then
        handleDetail(message.data)
    elseif message.action == 'craftResult' then
        handleCraftResult(message.data)
    elseif message.action == 'close' then
        handleServerClose(message.data)
    else
        logError('Unknown action: ' .. tostring(message.action))
        setFeedback(tr('Unknown crafting response.'), COLOR_ERROR)
    end
end

local function online()
    resetSession()
    if craftingWindow then
        craftingWindow:hide()
    end
end

local function offline()
    resetSession()
    if craftingWindow then
        craftingWindow:hide()
    end
end

local function onContainerAddItem(container, slot, item)
    scheduleInventoryRefresh()
end

local function onContainerUpdateItem(container, slot, item, oldItem)
    scheduleInventoryRefresh()
end

local function onContainerRemoveItem(container, slot, item)
    scheduleInventoryRefresh()
end

local function onInventoryChange(localPlayer, slot, item, oldItem)
    scheduleInventoryRefresh()
end

function init()
    craftingWindow = g_ui.loadUI('/game_crafting/crafting', g_ui.getRootWidget())
    bindUi()
    craftingWindow:hide()

    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })
    connect(Container, {
        onAddItem = onContainerAddItem,
        onUpdateItem = onContainerUpdateItem,
        onRemoveItem = onContainerRemoveItem
    })
    connect(LocalPlayer, {
        onInventoryChange = onInventoryChange
    })
    ProtocolGame.registerExtendedJSONOpcode(CRAFTING_OPCODE, onCraftingOpcode)
    g_logger.info(string.format('[Crafting] Module initialized; Extended JSON Opcode %d registered.', CRAFTING_OPCODE))
    resetSession()
end

function terminate()
    disconnect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })
    disconnect(Container, {
        onAddItem = onContainerAddItem,
        onUpdateItem = onContainerUpdateItem,
        onRemoveItem = onContainerRemoveItem
    })
    disconnect(LocalPlayer, {
        onInventoryChange = onInventoryChange
    })
    pcall(ProtocolGame.unregisterExtendedJSONOpcode, CRAFTING_OPCODE)
    resetSession()

    if craftingWindow then
        if craftingWindow:isVisible() then
            craftingWindow:hide()
        end
        craftingWindow:destroy()
        craftingWindow = nil
    end
    ui = nil
end

function closeWindow()
    if sessionId and not closeSent then
        closeSent = true
        sendMessage('close', { sessionId = sessionId })
    end
    resetSession()
    if craftingWindow then
        craftingWindow:hide()
    end
end

function craftSelected()
    if craftPending or not sessionId or not selectedRecipeId or not selectedDetail or not selectedDetail.canCraft then
        return
    end

    requestCounter = requestCounter + 1
    pendingRequestId = string.format('craft-%d', requestCounter)
    craftPending = true
    ui.craftButton:setEnabled(false)
    setFeedback('', COLOR_NORMAL)
    cancelScheduledRefresh()

    if not sendMessage('craft', {
        sessionId = sessionId,
        recipeId = selectedRecipeId,
        requestId = pendingRequestId
    }) then
        craftPending = false
        pendingRequestId = nil
        ui.craftButton:setEnabled(selectedDetail.canCraft)
        setFeedback(tr('The crafting session is no longer valid.'), COLOR_ERROR)
    end
end
