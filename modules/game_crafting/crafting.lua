local CRAFTING_OPCODE = 219
local CONTRACT_VERSION = 2
local REFRESH_DEBOUNCE = 100
local MAX_BATCH_QUANTITY = 100

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
local selectedQuantity = 1
local updatingQuantity = false
local renderedMaterialRows = {}
local detailLoading = false
local craftPending = false
local pendingRequestId = nil
local pendingQuantity = nil
local requestCounter = 0
local closeSent = false

local RESULT_MESSAGES = {
    SUCCESS = 'Item crafted successfully.',
    PARTIAL_SUCCESS = 'Partial success',
    CRAFT_FAILED = 'Crafting attempt failed.',
    INVALID_QUANTITY = 'Invalid crafting quantity.',
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
        recipeSearch = child('recipeSearch'),
        recipesEmptyLabel = child('recipesEmptyLabel'),
        stationLabel = child('stationLabel'),
        chanceLabel = child('chanceLabel'),
        blockLabel = child('blockLabel'),
        detailScrollbar = child('detailScrollbar'),
        detailList = child('detailList'),
        resultIcon = child('resultIcon'),
        resultName = child('resultName'),
        quantityPanel = child('quantityPanel'),
        quantityValueLabel = child('quantityValueLabel'),
        quantitySlider = child('quantitySlider'),
        quantityMaxButton = child('quantityMaxButton'),
        craftButton = child('craftButton'),
        feedbackLabel = child('feedbackLabel')
    }
end

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeNumber(value)
    return isFiniteNumber(value) and value >= 0
end

local function isInteger(value)
    return isFiniteNumber(value) and math.floor(value) == value
end

local function isNonNegativeInteger(value)
    return isInteger(value) and value >= 0
end

local function isPositiveInteger(value)
    return isInteger(value) and value >= 1
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
        or not isNonNegativeInteger(detail.maxQuantity)
        or detail.maxQuantity > MAX_BATCH_QUANTITY
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

    if detail.canCraft ~= (detail.maxQuantity >= 1)
        or (detail.recipeType == 'upgrade' and detail.maxQuantity > 1) then
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
        key = 'Unknown crafting response.'
    end
    return tr(key)
end

local function setFeedback(text, color)
    if not ui or not ui.feedbackLabel then
        return
    end
    local feedback = text or ''
    ui.feedbackLabel:setText(feedback)
    ui.feedbackLabel:setColor(color or COLOR_NORMAL)
    ui.feedbackLabel:setVisible(feedback ~= '')
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

local function setQuantityControlsEnabled(enabled)
    if not ui then
        return
    end
    ui.quantitySlider:setEnabled(enabled)
    ui.quantityMaxButton:setEnabled(enabled and selectedDetail ~= nil
        and selectedQuantity < selectedDetail.maxQuantity)
end

local function clearDetails()
    selectedDetail = nil
    renderedMaterialRows = {}
    if not ui then
        return
    end
    ui.detailList:destroyChildren()
    ui.detailScrollbar:setValue(0)
    ui.chanceLabel:setText('')
    ui.chanceLabel:hide()
    setBlockCode(nil)
    clearItem(ui.resultIcon)
    ui.resultName:setText('')
    ui.quantityPanel:hide()
    setQuantityControlsEnabled(false)
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

local function requestSelectedDetail()
    clearDetails()
    detailLoading = true
    setFeedback(tr('Loading...'), COLOR_MUTED)

    if not sendStatus() then
        detailLoading = false
        setFeedback(tr('The crafting session is no longer valid.'), COLOR_ERROR)
    end
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
    selectedQuantity = 1
    updatingQuantity = false
    renderedMaterialRows = {}
    detailLoading = false
    craftPending = false
    pendingRequestId = nil
    pendingQuantity = nil
    closeSent = false

    if ui then
        ui.recipeList:destroyChildren()
        ui.recipeSearch:setText('')
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

local function applyRecipeFilter(filterText)
    if not ui or not ui.recipeList then
        return
    end

    local searchText = tostring(filterText or ''):lower():trim()
    local visibleCount = 0
    for _, widget in ipairs(ui.recipeList:getChildren()) do
        local matches = searchText == '' or widget.recipeNameLower:find(searchText, 1, true) ~= nil
        widget:setVisible(matches)
        if matches then
            visibleCount = visibleCount + 1
        end
    end

    if #recipes == 0 then
        ui.recipesEmptyLabel:setText(tr('No unlocked recipes'))
    else
        ui.recipesEmptyLabel:setText(tr('No recipes found'))
    end
    ui.recipesEmptyLabel:setVisible(visibleCount == 0)
end

local function renderRecipeList()
    ui.recipeList:destroyChildren()

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
        row.recipeNameLower = recipe.name:lower()
        icon:setItemId(recipe.clientId)
        icon:setItemCount(recipe.resultCount)
        name:setText(displayName)
        row:setTooltip(displayName)
        row:setChecked(recipeId == selectedRecipeId)
        row.onClick = function()
            if selectedRecipeId ~= recipeId then
                selectedQuantity = 1
            end
            selectedRecipeId = recipeId
            setRecipeChecked(selectedRecipeId)
            requestSelectedDetail()
        end
    end

    applyRecipeFilter(ui.recipeSearch:getText())
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

local function updateItemRequirementRow(rowData, multiplier)
    local item = rowData.item
    local required = item.required * (multiplier or 1)
    local enough = item.owned >= required

    rowData.icon:setItemCount(required)
    rowData.amount:setText(string.format('%s / %s', tostring(item.owned), tostring(required)))

    if enough then
        rowData.icon:setOpacity(1.0)
        rowData.name:setColor(COLOR_NORMAL)
        rowData.amount:setColor(COLOR_NORMAL)
        rowData.status:setText('')
    else
        rowData.icon:setOpacity(0.4)
        rowData.name:setColor(COLOR_MUTED)
        rowData.amount:setColor(COLOR_MUTED)
        rowData.status:setText(tr(rowData.missingText))
    end
end

local function renderItemRequirement(item, missingText, multiplier)
    local row = g_ui.createWidget('CraftingMaterialRow', ui.detailList)
    local rowData = {
        item = item,
        missingText = missingText,
        row = row,
        icon = row:recursiveGetChildById('icon'),
        name = row:recursiveGetChildById('name'),
        amount = row:recursiveGetChildById('amount'),
        status = row:recursiveGetChildById('status')
    }

    rowData.icon:setItemId(item.clientId)
    rowData.name:setText(item.name)
    rowData.row:setTooltip(item.name)
    updateItemRequirementRow(rowData, multiplier)
    return rowData
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

local function configureQuantity(detail)
    local supportsQuantity = detail.recipeType == 'craft'
    ui.quantityPanel:setVisible(supportsQuantity)

    updatingQuantity = true
    if supportsQuantity then
        local maximum = math.max(detail.maxQuantity, 1)
        selectedQuantity = math.max(1, math.min(selectedQuantity, maximum))
        ui.quantitySlider:setMinimum(1)
        ui.quantitySlider:setMaximum(maximum)
        ui.quantitySlider:setValue(selectedQuantity)
    else
        selectedQuantity = 1
        ui.quantitySlider:setMinimum(1)
        ui.quantitySlider:setMaximum(1)
        ui.quantitySlider:setValue(1)
    end
    ui.quantityValueLabel:setText(tostring(selectedQuantity))
    updatingQuantity = false

    setQuantityControlsEnabled(supportsQuantity and detail.canCraft
        and detail.maxQuantity >= 1 and not craftPending)
end

local function updateResultPreview(detail)
    local displayCount = detail.resultCount * selectedQuantity
    ui.resultIcon:setItemId(detail.clientId)
    ui.resultIcon:setItemCount(displayCount)
    if stationType == 'alchemy' and selectedQuantity > 1 then
        ui.resultName:setText(string.format('%s: %s x%d', tr('Estimated result'), detail.name, displayCount))
    elseif displayCount > 1 then
        ui.resultName:setText(string.format('%s x%d', detail.name, displayCount))
    else
        ui.resultName:setText(detail.name)
    end
    ui.resultIcon:setTooltip(ui.resultName:getText())
end

local function refreshQuantityPreview()
    if not selectedDetail then
        return
    end

    for _, rowData in ipairs(renderedMaterialRows) do
        updateItemRequirementRow(rowData, selectedQuantity)
    end
    updateResultPreview(selectedDetail)
    ui.quantityMaxButton:setEnabled(not craftPending and selectedDetail.canCraft
        and selectedQuantity < selectedDetail.maxQuantity)
    ui.craftButton:setEnabled(not craftPending and selectedDetail.canCraft
        and selectedDetail.maxQuantity >= selectedQuantity)
end

local function renderDetail(detail)
    selectedDetail = detail
    configureQuantity(detail)
    ui.detailList:destroyChildren()
    renderedMaterialRows = {}

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
            table.insert(renderedMaterialRows,
                renderItemRequirement(material, 'Not enough materials', selectedQuantity))
        end
    end

    updateResultPreview(detail)
    ui.craftButton:setEnabled(detail.canCraft and detail.maxQuantity >= selectedQuantity and not craftPending)
end

local function showInvalidData(showDialog)
    detailLoading = false
    craftPending = false
    pendingRequestId = nil
    pendingQuantity = nil
    if ui then
        setQuantityControlsEnabled(false)
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
        requestSelectedDetail()
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
        showInvalidData(false)
        return
    end
    if data.sessionId ~= sessionId then
        return
    end
    if craftPending then
        return
    end
    if not validateDetail(data.detail) then
        showInvalidData(false)
        return
    end
    if data.detail.id ~= selectedRecipeId then
        return
    end
    local wasLoading = detailLoading
    detailLoading = false
    renderDetail(data.detail)
    if wasLoading then
        setFeedback('', COLOR_NORMAL)
    end
end

local function validateCraftResultData(data)
    local requestedQuantityMatches = data.requestedQuantity == pendingQuantity
        or (data.resultCode == 'INVALID_QUANTITY' and data.requestedQuantity == 0)
    if type(data.success) ~= 'boolean'
        or not isNonEmptyString(data.resultCode)
        or not isInteger(data.requestedQuantity)
        or not requestedQuantityMatches
        or not isNonNegativeInteger(data.attemptedQuantity)
        or data.attemptedQuantity > MAX_BATCH_QUANTITY
        or not isNonNegativeInteger(data.successfulAttempts)
        or data.successfulAttempts > data.attemptedQuantity
        or not isNonNegativeInteger(data.producedCount)
        or not validateRecipes(data.recipes)
        or not validateRecipeSelection(data.recipes, data.detail) then
        return false
    end

    if data.resultCode == 'SUCCESS' then
        return data.success
            and data.attemptedQuantity == data.requestedQuantity
            and data.successfulAttempts == data.attemptedQuantity
            and data.producedCount >= 1
    elseif data.resultCode == 'PARTIAL_SUCCESS' then
        return data.success
            and data.attemptedQuantity == data.requestedQuantity
            and data.successfulAttempts >= 1
            and data.successfulAttempts < data.attemptedQuantity
            and data.producedCount >= 1
    elseif data.resultCode == 'CRAFT_FAILED' then
        return not data.success
            and data.attemptedQuantity == data.requestedQuantity
            and data.successfulAttempts == 0
            and data.producedCount == 0
    end

    return not data.success
        and data.attemptedQuantity == 0
        and data.successfulAttempts == 0
        and data.producedCount == 0
end

local function getCraftResultFeedback(data)
    if data.resultCode ~= 'SUCCESS' and data.resultCode ~= 'PARTIAL_SUCCESS' then
        return getMessage(data.resultCode)
    end

    local created = string.format(tr('Created %d items'), data.producedCount)
    local attempts = string.format(tr('%d of %d attempts succeeded'),
        data.successfulAttempts, data.attemptedQuantity)
    if data.resultCode == 'PARTIAL_SUCCESS' then
        return string.format('%s %s %s', tr('Partial success'), created, attempts)
    end
    return string.format('%s %s', created, attempts)
end

local function handleCraftResult(data)
    if type(data) ~= 'table' or not isNonEmptyString(data.sessionId) or not isNonEmptyString(data.requestId) then
        showInvalidData(false)
        return
    end
    if data.sessionId ~= sessionId or data.requestId ~= pendingRequestId then
        return
    end
    if not validateCraftResultData(data) then
        showInvalidData(false)
        return
    end

    local previousRecipeId = selectedRecipeId
    local previousQuantity = selectedQuantity
    craftPending = false
    pendingRequestId = nil
    pendingQuantity = nil
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

    if selectedRecipeId == previousRecipeId then
        selectedQuantity = previousQuantity
    else
        selectedQuantity = 1
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
    elseif data.resultCode == 'PARTIAL_SUCCESS' or data.resultCode == 'CRAFT_FAILED' then
        color = COLOR_WARNING
    end
    setFeedback(getCraftResultFeedback(data), color)
end

local function handleServerClose(data)
    if type(data) ~= 'table' or not isNonEmptyString(data.sessionId) then
        showInvalidData(false)
        return
    end
    if data.sessionId ~= sessionId then
        return
    end
    if not isNonEmptyString(data.reasonCode) then
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
        showInvalidData(not sessionId)
        return
    end
    if message.version ~= CONTRACT_VERSION then
        resetSession()
        if craftingWindow then
            craftingWindow:hide()
        end
        displayErrorBox(tr('Crafting'), tr('Unsupported crafting protocol version.'))
        return
    end
    if not isNonEmptyString(message.action) or type(message.data) ~= 'table' then
        showInvalidData(not sessionId)
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

function filterRecipes(text)
    applyRecipeFilter(text)
end

function onQuantityChange(quantity)
    if updatingQuantity or craftPending or not selectedDetail or selectedDetail.recipeType ~= 'craft' then
        return
    end
    quantity = math.round(quantity)
    if not isPositiveInteger(quantity) then
        return
    end

    quantity = math.min(quantity, math.max(selectedDetail.maxQuantity, 1))
    if quantity == selectedQuantity then
        return
    end

    selectedQuantity = quantity
    ui.quantityValueLabel:setText(tostring(selectedQuantity))
    refreshQuantityPreview()
end

function selectMaxQuantity()
    if craftPending or not selectedDetail or selectedDetail.recipeType ~= 'craft'
        or selectedDetail.maxQuantity < 1 then
        return
    end
    ui.quantitySlider:setValue(selectedDetail.maxQuantity)
end

function craftSelected()
    local quantity = selectedDetail and selectedDetail.recipeType == 'craft' and selectedQuantity or 1
    if craftPending or not sessionId or not selectedRecipeId or not selectedDetail or not selectedDetail.canCraft
        or not isPositiveInteger(quantity) or quantity > selectedDetail.maxQuantity then
        return
    end

    requestCounter = requestCounter + 1
    pendingRequestId = string.format('craft-%d', requestCounter)
    pendingQuantity = quantity
    craftPending = true
    ui.craftButton:setEnabled(false)
    setQuantityControlsEnabled(false)
    setFeedback('', COLOR_NORMAL)
    cancelScheduledRefresh()

    if not sendMessage('craft', {
        sessionId = sessionId,
        recipeId = selectedRecipeId,
        requestId = pendingRequestId,
        quantity = quantity
    }) then
        craftPending = false
        pendingRequestId = nil
        pendingQuantity = nil
        configureQuantity(selectedDetail)
        ui.craftButton:setEnabled(selectedDetail.canCraft and selectedDetail.maxQuantity >= selectedQuantity)
        setFeedback(tr('The crafting session is no longer valid.'), COLOR_ERROR)
    end
end
