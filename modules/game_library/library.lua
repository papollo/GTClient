local LIBRARY_OPCODE = 217
local PAGE_SIZE = 20
local MAX_PAGE_SIZE = 50
local SEARCH_DELAY = 250

local libraryWindow = nil
local libraryButton = nil
local ui = nil
local searchEvent = nil
local requestCounter = 0
local showDetail = nil

local categories = {
    { key = 'ARMORS', label = 'Armors' },
    { key = 'AMULETS', label = 'Amulets' },
    { key = 'BOOTS', label = 'Boots' },
    { key = 'CONTAINERS', label = 'Containers' },
    { key = 'CREATURE_PRODUCTS', label = 'Creature Products' },
    { key = 'FOOD', label = 'Food' },
    { key = 'HELMETS_AND_HATS', label = 'Helmets and Hats' },
    { key = 'LEGS', label = 'Legs' },
    { key = 'OTHERS', label = 'Others' },
    { key = 'POTIONS', label = 'Potions' },
    { key = 'QUIVERS', label = 'Quivers' },
    { key = 'RINGS', label = 'Rings' },
    { key = 'RUNES', label = 'Runes' },
    { key = 'TOOLS', label = 'Tools' },
    { key = 'VALUABLES', label = 'Valuables' },
    { key = 'WEAPONS_AMMO', label = 'Weapons: Ammo' },
    { key = 'WEAPONS_BOW', label = 'Weapons: Bow' },
    { key = 'WEAPONS_TWO_HANDED', label = 'Weapons: Two Handed' },
    { key = 'WEAPONS_CROSSBOW', label = 'Weapons: Crossbow' },
    { key = 'WEAPONS_ONE_HANDED', label = 'Weapons: One Handed' },
    { key = 'WEAPONS_WANDS', label = 'Weapons: Wands' },
    { key = 'WEAPONS_ALL', label = 'Weapons: All' }
}

local state = {
    categoriesLoaded = false,
    categoriesRequested = false,
    activeCategory = nil,
    search = '',
    page = 1,
    totalPages = 1,
    totalResults = 0,
    selectedWareId = nil,
    selectedTier = 1,
    availableTiers = {},
    selectedResult = nil,
    pageCache = {},
    detailCache = {},
    pending = {}
}

local groupOrder = {
    { key = 'basic', label = 'Basic' },
    { key = 'combat', label = 'Combat' },
    { key = 'resistances', label = 'Resistances' },
    { key = 'skills', label = 'Skills' }
}

local groupFieldOrder = {
    basic = {
        'tier', 'weight', 'armor', 'defense', 'extraDefense', 'attack', 'hitChance', 'attackSpeed',
        'containerSize', 'text'
    },
    combat = {
        'range', 'elementDamage', 'elementType', 'criticalhitamount', 'criticalhitchance',
        'lifeleechamount', 'lifeleechchance', 'manaleechamount', 'manaleechchance'
    },
    resistances = {
        'absorbPercentPhysical', 'absorbPercentEnergy', 'absorbPercentEarth', 'absorbPercentFire',
        'absorbPercentIce', 'absorbPercentHoly', 'absorbPercentDeath', 'absorbPercentLifeDrain',
        'absorbPercentManaDrain', 'absorbPercentDrown'
    },
    skills = {
        'skillSword', 'skillAxe', 'skillClub', 'skillDist', 'skillShield', 'skillFish',
        'magicLevel', 'speed', 'healthGain', 'manaGain', 'maxHealthPoints', 'maxManaPoints'
    }
}

local fieldMeta = {
    tier = { label = 'Tier' },
    weight = { label = 'Weight' },
    armor = { label = 'Armor' },
    defense = { label = 'Defense' },
    extraDefense = { label = 'Extra Defense' },
    attack = { label = 'Attack' },
    hitChance = { label = 'Hit Chance' },
    range = { label = 'Range' },
    attackSpeed = { label = 'Attack Speed' },
    containerSize = { label = 'Container Size' },
    text = { label = 'Text' },
    elementDamage = { label = 'Element Damage' },
    elementType = { label = 'Element Type' },
    criticalhitamount = { label = 'Critical Hit Amount' },
    criticalhitchance = { label = 'Critical Hit Chance' },
    lifeleechamount = { label = 'Life Leech Amount' },
    lifeleechchance = { label = 'Life Leech Chance' },
    manaleechamount = { label = 'Mana Leech Amount' },
    manaleechchance = { label = 'Mana Leech Chance' },
    absorbPercentPhysical = { label = 'Physical Protection', percent = true },
    absorbPercentEnergy = { label = 'Energy Protection', percent = true },
    absorbPercentEarth = { label = 'Earth Protection', percent = true },
    absorbPercentFire = { label = 'Fire Protection', percent = true },
    absorbPercentIce = { label = 'Ice Protection', percent = true },
    absorbPercentHoly = { label = 'Holy Protection', percent = true },
    absorbPercentDeath = { label = 'Death Protection', percent = true },
    absorbPercentLifeDrain = { label = 'Life Drain Protection', percent = true },
    absorbPercentManaDrain = { label = 'Mana Drain Protection', percent = true },
    absorbPercentDrown = { label = 'Drown Protection', percent = true },
    skillSword = { label = 'One Handed Fighting' },
    skillAxe = { label = 'Bow Fighting' },
    skillClub = { label = 'Two Handed Fighting' },
    skillDist = { label = 'Crossbow Fighting' },
    skillShield = { label = 'Shielding Skill' },
    skillFish = { label = 'Fishing Skill' },
    magicLevel = { label = 'Magic Level' },
    speed = { label = 'Speed' },
    healthGain = { label = 'Health Gain' },
    manaGain = { label = 'Mana Gain' },
    maxHealthPoints = { label = 'Max Health' },
    maxManaPoints = { label = 'Max Mana' },
    charges = { label = 'Charges' },
    showCount = { label = 'Shows Count', boolean = true },
    showCharges = { label = 'Shows Charges', boolean = true },
    duration = { label = 'Duration' },
    decayTo = { label = 'Decay To' },
    transformEquipTo = { label = 'Transform On Equip' },
    transformDeEquipTo = { label = 'Transform On De-Equip' },
    stackable = { label = 'Stackable', boolean = true },
    pickupable = { label = 'Pickupable', boolean = true },
    moveable = { label = 'Moveable', boolean = true },
    readable = { label = 'Readable', boolean = true },
    writable = { label = 'Writable', boolean = true },
    rotatable = { label = 'Rotatable', boolean = true },
    container = { label = 'Container', boolean = true },
    usable = { label = 'Usable', boolean = true },
    rune = { label = 'Rune', boolean = true },
    fluidContainer = { label = 'Fluid Container', boolean = true },
    splash = { label = 'Splash', boolean = true },
    weapon = { label = 'Weapon', boolean = true },
    armorItem = { label = 'Armor Item', boolean = true }
}

local elementNames = {
    [0] = 'None',
    [1] = 'Physical',
    [2] = 'Energy',
    [4] = 'Earth',
    [8] = 'Fire',
    [16] = 'Undefined',
    [32] = 'Life Drain',
    [64] = 'Mana Drain',
    [128] = 'Healing',
    [256] = 'Drown',
    [512] = 'Ice',
    [1024] = 'Holy',
    [2048] = 'Death'
}

local tierNames = {
    [1] = 'Normal',
    [2] = 'Solid',
    [3] = 'Superior',
    [4] = 'Epic',
    [5] = 'Legendary'
}

local function getProtocol()
    return g_game.getProtocolGame()
end

local function makeRequestId(action)
    requestCounter = requestCounter + 1
    return string.format('library-%s-%d', action, requestCounter)
end

local function normalizeSearch(text)
    text = text or ''
    if text:trim() == '' then
        return ''
    end
    return text:lower()
end

local function makePageCacheKey(category, search, page)
    return string.format('%s|%s|%d|%d', category or '', search or '', page or 1, PAGE_SIZE)
end

local function makeDetailCacheKey(wareId, tier)
    return string.format('%s|%s', tostring(wareId or ''), tostring(tier or 1))
end

local function copyTable(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

local function child(id)
    return libraryWindow and libraryWindow:recursiveGetChildById(id)
end

local function bindUi()
    ui = {
        itemsTab = child('itemsTab'),
        categoryList = child('categoryList'),
        resultList = child('resultList'),
        resultEmptyLabel = child('resultEmptyLabel'),
        searchEdit = child('searchEdit'),
        searchClearButton = child('searchClearButton'),
        prevPageButton = child('prevPageButton'),
        nextPageButton = child('nextPageButton'),
        pageLabel = child('pageLabel'),
        detailPlaceholder = child('detailPlaceholder'),
        detailContent = child('detailContent'),
        itemName = child('itemName'),
        itemDescription = child('itemDescription'),
        tierTabsPanel = child('tierTabsPanel'),
        tierTabs = child('tierTabs'),
        itemSprite = child('sprite'),
        detailList = child('detailList'),
        closeButton = child('closeButton')
    }
end

local function resetDetailPanel(message, clearSelection)
    if clearSelection == nil then
        clearSelection = true
    end

    ui.detailPlaceholder:setText(message)
    ui.detailPlaceholder:show()
    ui.detailContent:hide()
    ui.itemName:setText(tr('Item'))
    ui.itemDescription:setVisible(false)
    ui.tierTabsPanel:hide()
    ui.tierTabs:destroyChildren()
    ui.itemSprite:setItemId(0)
    ui.detailList:destroyChildren()
    if clearSelection then
        state.selectedWareId = nil
        state.selectedTier = 1
        state.availableTiers = {}
        state.selectedResult = nil
    end
end

local function updateResultEmptyLabel(message)
    ui.resultEmptyLabel:setText(message)
    ui.resultEmptyLabel:setVisible(true)
end

local function updatePagination()
    local page = math.max(1, tonumber(state.page) or 1)
    local totalPages = math.max(1, tonumber(state.totalPages) or 1)
    ui.pageLabel:setText(string.format('Page %d / %d', page, totalPages))
    ui.prevPageButton:setEnabled(state.activeCategory ~= nil and page > 1)
    ui.nextPageButton:setEnabled(state.activeCategory ~= nil and page < totalPages)
end

local function setResultWidgetsEnabled(enabled)
    ui.searchEdit:setEnabled(enabled)
    ui.searchClearButton:setEnabled(enabled)
    ui.prevPageButton:setEnabled(enabled and state.page > 1)
    ui.nextPageButton:setEnabled(enabled and state.page < state.totalPages)
end

local function humanizeKey(key)
    local spaced = key:gsub('(%l)(%u)', '%1 %2')
    spaced = spaced:gsub('(%a)(%d)', '%1 %2')
    spaced = spaced:gsub('(%d)(%a)', '%1 %2')
    return spaced:gsub('^%l', string.upper)
end

local function formatValue(key, value)
    local meta = fieldMeta[key] or {}
    if meta.boolean then
        return value and 'Yes' or 'No'
    end
    if key == 'tier' then
        local numericValue = tonumber(value)
        if numericValue and tierNames[numericValue] then
            return tierNames[numericValue]
        end
    end
    if key == 'elementType' then
        if type(value) == 'number' and elementNames[value] then
            return elementNames[value]
        end
    end
    if meta.percent and type(value) == 'number' then
        return string.format('%d%%', value)
    end
    if type(value) == 'boolean' then
        return value and 'Yes' or 'No'
    end
    return tostring(value)
end

local function getFieldLabel(key)
    local meta = fieldMeta[key]
    return meta and meta.label or humanizeKey(key)
end

local function sendRequest(action, data)
    local protocol = getProtocol()
    if not protocol then
        return nil
    end

    local requestId = makeRequestId(action)
    state.pending[requestId] = action
    local payload = {
        version = 1,
        action = action,
        domain = 'items',
        requestId = requestId,
        data = data or {}
    }
    protocol:sendExtendedJSONOpcode(LIBRARY_OPCODE, payload)
    return requestId
end

local function ensureCategoriesRequested()
    if state.categoriesLoaded or state.categoriesRequested then
        return
    end
    state.categoriesRequested = true
    sendRequest('categories')
end

local function getOrderedGroupEntries(groupKey, values)
    local ordered = {}
    local seen = {}

    for _, fieldKey in ipairs(groupFieldOrder[groupKey] or {}) do
        if values[fieldKey] ~= nil then
            table.insert(ordered, { key = fieldKey, value = values[fieldKey] })
            seen[fieldKey] = true
        end
    end

    local remainder = {}
    for key, value in pairs(values) do
        if not seen[key] then
            table.insert(remainder, { key = key, value = value })
        end
    end

    table.sort(remainder, function(a, b)
        return a.key < b.key
    end)

    for _, entry in ipairs(remainder) do
        table.insert(ordered, entry)
    end

    return ordered
end

local function shouldShowRange()
    return state.activeCategory == 'WEAPONS_AMMO'
        or state.activeCategory == 'WEAPONS_BOW'
        or state.activeCategory == 'WEAPONS_CROSSBOW'
end

local function normalizeTierList(tiers)
    local result = {}
    local seen = {}
    if type(tiers) ~= 'table' then
        return result
    end

    for _, tier in ipairs(tiers) do
        local numericTier = tonumber(tier)
        if numericTier and numericTier >= 1 and numericTier <= 5 and not seen[numericTier] then
            seen[numericTier] = true
            table.insert(result, numericTier)
        end
    end

    table.sort(result)
    return result
end

local function requestItemDetail(wareId, tier)
    if not wareId then
        return
    end

    local numericTier = tonumber(tier) or 1
    state.selectedWareId = tonumber(wareId) or state.selectedWareId
    state.selectedTier = numericTier
    local cacheKey = makeDetailCacheKey(wareId, numericTier)
    local cached = state.detailCache[cacheKey]
    if cached then
        showDetail(cached)
        return
    end

    resetDetailPanel(tr('Loading item details...'), false)
    sendRequest('detail', {
        wareId = wareId,
        tier = numericTier
    })
end

local function renderTierTabs(currentTier, availableTiers)
    ui.tierTabs:destroyChildren()

    if #availableTiers <= 1 then
        ui.tierTabsPanel:hide()
        return
    end

    for _, tier in ipairs(availableTiers) do
        local button = g_ui.createWidget('LibraryTierButton', ui.tierTabs)
        button.tierValue = tier
        button:setText(tierNames[tier] or ('Tier ' .. tier))
        button:setChecked(tier == currentTier)
        button.onClick = function(widget)
            if widget.tierValue == state.selectedTier then
                return
            end
            requestItemDetail(state.selectedWareId, widget.tierValue)
        end
        button.onMouseRelease = function(widget, mousePos, mouseButton)
            if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                widget:onClick()
                return true
            end
        end
    end

    ui.tierTabsPanel:show()
end

local function renderDetailGroups(details)
    local list = ui.detailList
    list:destroyChildren()

    for _, group in ipairs(groupOrder) do
        local values = details[group.key]
        if type(values) == 'table' then
            local displayValues = copyTable(values)

            if group.key == 'basic' then
                displayValues.range = nil
            elseif group.key == 'combat' and not shouldShowRange() then
                displayValues.range = nil
            end

            if displayValues and next(displayValues) ~= nil then
                local heading = g_ui.createWidget('LibrarySectionLabel', list)
                heading:setText(group.label .. ':')

                for _, entry in ipairs(getOrderedGroupEntries(group.key, displayValues)) do
                    local key = entry.key
                    local value = entry.value
                    local row = g_ui.createWidget('ItemBasicDetail', list)
                    local background = row:getChildById('background')
                    local nameLabel = background and background:getChildById('name')
                    local valueLabel = background and background:getChildById('value')
                    row:setHeight(type(value) == 'string' and #value > 40 and 34 or 20)
                    if nameLabel then
                        nameLabel:setText(getFieldLabel(key))
                    end
                    if valueLabel then
                        valueLabel:setText(formatValue(key, value))
                        valueLabel:setTextWrap(type(value) == 'string')
                    end
                end
            end
        end
    end
end

showDetail = function(data)
    if not data then
        return
    end

    state.selectedWareId = tonumber(data.wareId) or state.selectedWareId
    state.selectedTier = tonumber(data.tier) or 1
    state.availableTiers = normalizeTierList(data.availableTiers)
    ui.detailPlaceholder:hide()
    ui.detailContent:show()
    ui.itemName:setText(data.name or tr('Item'))
    ui.itemSprite:setItemId(tonumber(data.clientId) or 0)

    local description = data.description
    if type(description) == 'string' and description:trim() ~= '' then
        ui.itemDescription:setText(description)
        ui.itemDescription:setVisible(true)
    else
        ui.itemDescription:setVisible(false)
    end

    renderTierTabs(state.selectedTier, state.availableTiers)
    renderDetailGroups(data.details or {})
end

local function clearResultSelection()
    if state.selectedResult and not state.selectedResult:isDestroyed() then
        state.selectedResult:setChecked(false)
    end
    state.selectedResult = nil
end

local function onResultSelected(widget, entry)
    if state.selectedResult and state.selectedResult ~= widget and not state.selectedResult:isDestroyed() then
        state.selectedResult:setChecked(false)
    end

    state.selectedResult = widget
    state.selectedWareId = tonumber(entry.wareId)
    state.selectedTier = 1
    widget:setChecked(true)
    requestItemDetail(tonumber(entry.wareId), 1)
end

local function renderResults(response)
    local list = ui.resultList
    list:destroyChildren()
    clearResultSelection()

    local items = response.items or {}
    state.page = tonumber(response.page) or 1
    state.totalPages = math.max(1, tonumber(response.totalPages) or 1)
    state.totalResults = tonumber(response.totalResults) or #items
    updatePagination()
    setResultWidgetsEnabled(state.activeCategory ~= nil)

    if #items == 0 then
        updateResultEmptyLabel(state.activeCategory and tr('No items found for this category.') or tr('Select a category to load items.'))
        resetDetailPanel(state.activeCategory and tr('Select an item to see its details here.') or tr('Select a category and choose an item to see its details here.'))
        return
    end

    ui.resultEmptyLabel:hide()

    for _, entry in ipairs(items) do
        local row = g_ui.createWidget('LibraryResultItem', list)
        local sprite = row:recursiveGetChildById('Sprite')
        local nameLabel = row:recursiveGetChildById('Name')
        row:setPhantom(false)
        if sprite then
            sprite:setItemId(tonumber(entry.clientId) or 0)
        end
        if nameLabel then
            nameLabel:setText(entry.name or tr('Unknown item'))
        end
        row.onClick = function()
            onResultSelected(row, entry)
        end
        row.onMouseRelease = function(widget, mousePos, mouseButton)
            if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                widget:onClick()
                return true
            end
        end
    end

    resetDetailPanel(tr('Select an item to see its details here.'))
end

local function requestCurrentPage(force)
    if not state.activeCategory then
        updateResultEmptyLabel(tr('Select a category to load items.'))
        setResultWidgetsEnabled(false)
        return
    end

    local search = normalizeSearch(state.search or '')
    local cacheKey = makePageCacheKey(state.activeCategory, search, state.page)
    if not force and state.pageCache[cacheKey] then
        renderResults(state.pageCache[cacheKey])
        return
    end

    ui.resultList:destroyChildren()
    updateResultEmptyLabel(tr('Loading items...'))
    resetDetailPanel(tr('Select an item to see its details here.'))
    setResultWidgetsEnabled(true)
    sendRequest('list', {
        category = state.activeCategory,
        page = state.page,
        pageSize = PAGE_SIZE,
        search = search
    })
end

local function setCategory(categoryKey)
    if state.activeCategory == categoryKey then
        return
    end

    state.activeCategory = categoryKey
    state.page = 1
    state.search = ''
    ui.searchEdit:setText('')

    for _, widget in ipairs(ui.categoryList:getChildren()) do
        widget:setChecked(widget.categoryKey == categoryKey)
    end

    requestCurrentPage(false)
end

local function renderCategories()
    local list = ui.categoryList
    list:destroyChildren()

    for _, entry in ipairs(categories) do
        local widget = g_ui.createWidget('LibraryCategoryItem', list)
        widget.categoryKey = entry.key
        widget:setText(entry.label)
        widget:setChecked(state.activeCategory == entry.key)
        widget.onClick = function()
            setCategory(entry.key)
        end
        widget.onMouseRelease = function(self, mousePos, mouseButton)
            if self:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                self:onClick()
                return true
            end
        end
    end
end

local function mergeServerCategories(serverCategories)
    if type(serverCategories) ~= 'table' then
        return
    end

    local byKey = {}
    for _, category in ipairs(serverCategories) do
        if type(category) == 'table' and type(category.key) == 'string' then
            byKey[category.key] = category
        end
    end

    for _, category in ipairs(categories) do
        local incoming = byKey[category.key]
        if incoming and type(incoming.label) == 'string' and incoming.label ~= '' then
            category.label = incoming.label
        end
    end
end

local function handleCategoriesResponse(data)
    state.categoriesLoaded = true
    state.categoriesRequested = false
    mergeServerCategories(data.categories)
    renderCategories()
end

local function handleListResponse(data)
    local search = normalizeSearch(data.search or '')
    local category = data.category or state.activeCategory
    local page = tonumber(data.page) or 1
    local cacheKey = makePageCacheKey(category, search, page)
    state.pageCache[cacheKey] = data

    if category == state.activeCategory and search == normalizeSearch(state.search or '') then
        renderResults(data)
    end
end

local function handleDetailResponse(data)
    local wareId = tonumber(data.wareId)
    local tier = tonumber(data.tier) or 1
    if wareId then
        state.detailCache[makeDetailCacheKey(wareId, tier)] = data
    end
    if wareId == tonumber(state.selectedWareId) and tier == tonumber(state.selectedTier) then
        showDetail(data)
    end
end

local function handleLibraryError(payload)
    local message = tr('Library request failed.')
    if type(payload) == 'table' and type(payload.error) == 'table' and type(payload.error.message) == 'string' then
        message = payload.error.message
    end

    if payload and payload.action == 'categories' then
        state.categoriesRequested = false
    end

    if state.activeCategory then
        updateResultEmptyLabel(message)
    else
        ui.detailPlaceholder:setText(message)
    end
end

local function onLibraryOpcode(protocol, opcode, payload)
    if type(payload) ~= 'table' then
        return
    end

    local requestId = payload.requestId
    local action = payload.action
    if requestId ~= nil then
        local pendingAction = state.pending[requestId]
        state.pending[requestId] = nil
        action = action or pendingAction
    end

    payload.action = action
    if payload.ok == false then
        handleLibraryError(payload)
        return
    end

    local data = payload.data or {}
    if action == 'categories' then
        handleCategoriesResponse(data)
    elseif action == 'list' then
        handleListResponse(data)
    elseif action == 'detail' then
        handleDetailResponse(data)
    end
end

local function queueSearch()
    if searchEvent then
        removeEvent(searchEvent)
        searchEvent = nil
    end

    searchEvent = scheduleEvent(function()
        searchEvent = nil
        state.search = ui.searchEdit:getText() or ''
        state.page = 1
        requestCurrentPage(true)
    end, SEARCH_DELAY)
end

local function clearSearch()
    if ui.searchEdit:getText() == '' then
        return
    end
    ui.searchEdit:setText('')
    state.search = ''
    state.page = 1
    requestCurrentPage(true)
end

local function show()
    if not libraryWindow or not g_game.isOnline() then
        return
    end

    libraryWindow:show()
    libraryWindow:raise()
    libraryWindow:focus()
    ui.itemsTab:setOn(true)
    if libraryButton then
        libraryButton:setOn(true)
    end

    ensureCategoriesRequested()
    renderCategories()
    if state.activeCategory then
        requestCurrentPage(false)
    else
        updateResultEmptyLabel(tr('Select a category to load items.'))
        resetDetailPanel(tr('Select a category and choose an item to see its details here.'))
        setResultWidgetsEnabled(false)
        updatePagination()
    end
end

function hide()
    if not libraryWindow then
        return
    end
    libraryWindow:hide()
    if libraryButton then
        libraryButton:setOn(false)
    end
end

function toggle()
    if not libraryWindow or not g_game.isOnline() then
        return
    end
    if libraryWindow:isVisible() then
        hide()
    else
        show()
    end
end

local function resetUiState()
    state.page = 1
    state.totalPages = 1
    state.totalResults = 0
    clearResultSelection()
    ui.searchEdit:setText('')
    ui.resultList:destroyChildren()
    ui.detailList:destroyChildren()
    renderCategories()
    updateResultEmptyLabel(tr('Select a category to load items.'))
    resetDetailPanel(tr('Select a category and choose an item to see its details here.'))
    updatePagination()
    setResultWidgetsEnabled(false)
end

local function resetDataState()
    state.categoriesLoaded = false
    state.categoriesRequested = false
    state.activeCategory = nil
    state.search = ''
    state.selectedWareId = nil
    state.selectedTier = 1
    state.availableTiers = {}
    state.pageCache = {}
    state.detailCache = {}
    state.pending = {}
end

function init()
    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    g_ui.importStyle('/game_cyclopedia/cyclopedia_widgets')

    libraryWindow = g_ui.loadUI('/game_library/library', g_ui.getRootWidget())
    bindUi()
    libraryWindow:hide()
    ui.itemsTab:setOn(true)
    ui.itemsTab:setEnabled(false)
    ui.closeButton.onClick = hide
    libraryWindow.onEscape = hide
    ui.searchEdit.onTextChange = queueSearch
    ui.searchClearButton.onClick = clearSearch
    ui.prevPageButton.onClick = function()
        if state.page > 1 then
            state.page = state.page - 1
            requestCurrentPage(false)
        end
    end
    ui.nextPageButton.onClick = function()
        if state.page < state.totalPages then
            state.page = state.page + 1
            requestCurrentPage(false)
        end
    end

    libraryButton = modules.game_mainpanel.addToggleButton('libraryButton', tr('Library'),
        '/game_library/images/library_button', toggle, false, 5)
    libraryButton:setOn(false)

    ProtocolGame.registerExtendedJSONOpcode(LIBRARY_OPCODE, onLibraryOpcode)
    Keybind.new('Windows', 'Show/hide library window', 'Ctrl+Shift+L', '')
    Keybind.bind('Windows', 'Show/hide library window', {
        {
            type = KEY_DOWN,
            callback = toggle
        }
    })

    resetUiState()
end

function terminate()
    disconnect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    if searchEvent then
        removeEvent(searchEvent)
        searchEvent = nil
    end

    Keybind.delete('Windows', 'Show/hide library window')
    pcall(ProtocolGame.unregisterExtendedJSONOpcode, LIBRARY_OPCODE)

    if libraryButton then
        libraryButton:destroy()
        libraryButton = nil
    end

    if libraryWindow then
        libraryWindow:destroy()
        libraryWindow = nil
    end
    ui = nil
end

function online()
    resetDataState()
    resetUiState()
    if libraryButton then
        libraryButton:setOn(false)
    end
    hide()
end

function offline()
    resetDataState()
    resetUiState()
    hide()
end
