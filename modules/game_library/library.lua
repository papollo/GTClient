local LIBRARY_OPCODE = 217
local PAGE_SIZE = 20
local SEARCH_DELAY = 250

local libraryWindow = nil
local libraryButton = nil
local ui = nil
local searchEvent = nil
local requestCounter = 0
local showDetail = nil

local DOMAIN_ITEMS = 'items'
local DOMAIN_MONSTERS = 'monsters'

local categories = {
    { key = 'ARMORS', label = 'Armors' },
    { key = 'AMULETS', label = 'Amulets' },
    { key = 'BOOTS', label = 'Boots' },
    { key = 'HELMETS_AND_HATS', label = 'Helmets and Hats' },
    { key = 'LEGS', label = 'Legs' },
    { key = 'RINGS', label = 'Rings' },
    { key = 'WEAPONS_AMMO', label = 'Weapons: Ammo' },
    { key = 'WEAPONS_BOW', label = 'Weapons: Bow' },
    { key = 'WEAPONS_TWO_HANDED', label = 'Weapons: Two Handed' },
    { key = 'WEAPONS_CROSSBOW', label = 'Weapons: Crossbow' },
    { key = 'WEAPONS_ONE_HANDED', label = 'Weapons: One Handed' },
    { key = 'WEAPONS_WANDS', label = 'Weapons: Wands' },
    { key = 'WEAPONS_ALL', label = 'Weapons: All' },
    { key = 'PLANT', label = 'Plants' },
    { key = 'FOOD', label = 'Food' },
    { key = 'MATERIALS', label = 'Materials' },
    { key = 'ALCHEMY_RECIPIES', label = 'Alchemy Recipies' },
    { key = 'COOKING_RECIPIES', label = 'Cooking Recipies' },
    { key = 'BOW_SCHEMAS', label = 'Bow Schemas' },
    { key = 'SMITH_SCHEMAS', label = 'Smith Schemas' },
    { key = 'CONTAINERS', label = 'Containers' },
    { key = 'CREATURE_PRODUCTS', label = 'Creature Products' },
    { key = 'OTHERS', label = 'Others' },
    { key = 'POTIONS', label = 'Potions' },
    { key = 'QUIVERS', label = 'Quivers' },
    { key = 'RUNES', label = 'Runes' },
    { key = 'TOOLS', label = 'Tools' },
    { key = 'VALUABLES', label = 'Valuables' }
}

local defaultMonsterCategories = {
    { key = 'normal', label = 'Normal Monsters', default = true, implicit = true }
}

local state = {
    domain = DOMAIN_ITEMS,
    items = {
        categoriesLoaded = false,
        categoriesRequested = false,
        activeCategory = nil,
        search = '',
        page = 1,
        totalPages = 1,
        totalResults = 0,
        selectedId = nil,
        selectedTier = 1,
        availableTiers = {},
        selectedResult = nil,
        pageCache = {},
        detailCache = {}
    },
    monsters = {
        categoriesLoaded = false,
        categoriesRequested = false,
        categories = {},
        activeCategory = nil,
        search = '',
        page = 1,
        totalPages = 1,
        totalResults = 0,
        selectedId = nil,
        selectedTier = 1,
        availableTiers = {},
        selectedResult = nil,
        pageCache = {},
        detailCache = {}
    },
    pending = {}
}

local groupOrder = {
    [DOMAIN_ITEMS] = {
        { key = 'basic', label = 'Basic' },
        { key = 'combat', label = 'Combat' },
        { key = 'resistances', label = 'Resistances' },
        { key = 'skills', label = 'Skills' }
    },
    [DOMAIN_MONSTERS] = {
        { key = 'basic', label = 'Basic' },
        { key = 'combat', label = 'Combat' },
        { key = 'attacks', label = 'Attacks' },
        { key = 'resistances', label = 'Resistances' },
        { key = 'loot', label = 'Loot' },
        { key = 'location', label = 'Location' },
        { key = 'skills', label = 'Skills' }
    }
}

local groupFieldOrder = {
    basic = {
        'tier', 'weight', 'armor', 'defense', 'extraDefense', 'attack', 'hitChance', 'attackSpeed',
        'containerSize', 'text', 'health', 'experience', 'speed', 'mitigation', 'summonCost', 'convinceCost'
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
    },
    loot = {
        'value', 'count', 'chance', 'difficulty', 'stackable'
    },
    location = {
        'name', 'area', 'places', 'notes'
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
    health = { label = 'Health' },
    experience = { label = 'Experience' },
    mitigation = { label = 'Mitigation' },
    summonCost = { label = 'Summon Cost' },
    convinceCost = { label = 'Convince Cost' },
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
    armorItem = { label = 'Armor Item', boolean = true },
    value = { label = 'Value' },
    count = { label = 'Count' },
    chance = { label = 'Chance' },
    difficulty = { label = 'Difficulty' },
    area = { label = 'Area' },
    places = { label = 'Places' },
    notes = { label = 'Notes' }
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

local function getDomainState(domain)
    return state[domain or state.domain]
end

local function makeRequestId(domain, action)
    requestCounter = requestCounter + 1
    return string.format('library-%s-%s-%d', domain, action, requestCounter)
end

local function normalizeSearch(text)
    text = text or ''
    if text:trim() == '' then
        return ''
    end
    return text:lower()
end

local function makePageCacheKey(domain, category, search, page)
    return string.format('%s|%s|%s|%d|%d', domain or '', category or '', search or '', page or 1, PAGE_SIZE)
end

local function makeDetailCacheKey(domain, id, tier)
    return string.format('%s|%s|%s', domain or '', tostring(id or ''), tostring(tier or 1))
end

local function copyTable(source)
    local result = {}
    if type(source) ~= 'table' then
        return result
    end
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
        monstersTab = child('monstersTab'),
        categoryPanel = child('categoryPanel'),
        itemsSection = child('itemsSection'),
        categoryLabel = child('categoryLabel'),
        categoryList = child('categoryList'),
        topListEmptyLabel = child('topListEmptyLabel'),
        monsterPanel = child('monsterPanel'),
        monsterCategoryLabel = child('monsterCategoryLabel'),
        monsterCategoryList = child('monsterCategoryList'),
        monsterLabel = child('monsterLabel'),
        monsterList = child('monsterList'),
        monsterEmptyLabel = child('monsterEmptyLabel'),
        resultLabel = child('itemsLabel'),
        resultList = child('resultList'),
        resultEmptyLabel = child('resultEmptyLabel'),
        searchLabel = child('searchLabel'),
        searchEdit = child('searchEdit'),
        searchClearButton = child('searchClearButton'),
        prevPageButton = child('prevPageButton'),
        nextPageButton = child('nextPageButton'),
        pageLabel = child('pageLabel'),
        detailPlaceholder = child('detailPlaceholder'),
        detailContent = child('detailContent'),
        itemName = child('itemName'),
        tierTabsPanel = child('tierTabsPanel'),
        tierTabs = child('tierTabs'),
        itemSprite = child('sprite'),
        detailCreature = child('detailCreature'),
        selectedItem = child('selectedItem'),
        detailList = child('detailList'),
        closeButton = child('closeButton')
    }
end

local function getResultLabelText(domain)
    return domain == DOMAIN_MONSTERS and tr('Monsters') or tr('Items')
end

local function getSelectionPlaceholder(domain)
    if domain == DOMAIN_MONSTERS then
        return tr('Select a monster to see its details here.')
    end
    return tr('Select an item to see its details here.')
end

local function getInitialPlaceholder(domain)
    if domain == DOMAIN_MONSTERS then
        return tr('Choose the monsters tab and select a monster to see its details here.')
    end
    return tr('Select a category and choose an item to see its details here.')
end

local function getLoadingText(domain)
    return domain == DOMAIN_MONSTERS and tr('Loading monsters...') or tr('Loading items...')
end

local function getDetailLoadingText(domain)
    return domain == DOMAIN_MONSTERS and tr('Loading monster details...') or tr('Loading item details...')
end

local function getNoResultsText(domain)
    if domain == DOMAIN_MONSTERS then
        return tr('No monsters found.')
    end
    return tr('No items found for this category.')
end

local function resetDetailCreature()
    if ui.detailCreature then
        ui.detailCreature:setVisible(false)
        ui.detailCreature:setOutfit({ type = 0 })
    end
end

local function resetDetailPanel(message, clearSelection)
    if clearSelection == nil then
        clearSelection = true
    end

    local domainState = getDomainState()
    ui.detailPlaceholder:setText(message)
    ui.detailPlaceholder:show()
    ui.detailContent:hide()
    ui.itemName:setText(state.domain == DOMAIN_MONSTERS and tr('Monster') or tr('Item'))
    ui.tierTabsPanel:hide()
    ui.tierTabs:destroyChildren()
    ui.itemSprite:setItemId(0)
    ui.selectedItem:setVisible(state.domain == DOMAIN_ITEMS)
    resetDetailCreature()
    ui.detailList:destroyChildren()
    if clearSelection then
        domainState.selectedId = nil
        domainState.selectedTier = 1
        domainState.availableTiers = {}
        domainState.selectedResult = nil
    end
end

local function anchorSearchSection(isItems)
    ui.searchLabel:removeAnchor(AnchorTop)
    if isItems then
        ui.searchLabel:addAnchor(AnchorTop, 'itemsSection', AnchorBottom)
    else
        ui.searchLabel:addAnchor(AnchorTop, 'monsterPanel', AnchorBottom)
    end
end

local function updateResultEmptyLabel(message)
    ui.resultEmptyLabel:setText(message)
    ui.resultEmptyLabel:setVisible(true)
    ui.topListEmptyLabel:setVisible(false)
    ui.monsterEmptyLabel:setVisible(false)
end

local function updateMonsterEmptyLabel(message)
    ui.monsterEmptyLabel:setText(message)
    ui.monsterEmptyLabel:setVisible(true)
    ui.resultEmptyLabel:setVisible(false)
    ui.topListEmptyLabel:setVisible(false)
end

local function hideAllEmptyLabels()
    ui.resultEmptyLabel:setVisible(false)
    ui.topListEmptyLabel:setVisible(false)
    ui.monsterEmptyLabel:setVisible(false)
end

local function updatePagination()
    local domainState = getDomainState()
    local page = math.max(1, tonumber(domainState.page) or 1)
    local totalPages = math.max(1, tonumber(domainState.totalPages) or 1)
    ui.pageLabel:setText(string.format('Page %d / %d', page, totalPages))
    local hasSource = state.domain == DOMAIN_MONSTERS or domainState.activeCategory ~= nil
    ui.prevPageButton:setEnabled(hasSource and page > 1)
    ui.nextPageButton:setEnabled(hasSource and page < totalPages)
end

local function setResultWidgetsEnabled(enabled)
    local domainState = getDomainState()
    ui.searchEdit:setEnabled(enabled)
    ui.searchClearButton:setEnabled(enabled)
    ui.prevPageButton:setEnabled(enabled and domainState.page > 1)
    ui.nextPageButton:setEnabled(enabled and domainState.page < domainState.totalPages)
end

local function humanizeKey(key)
    if key == nil then
        return ''
    end
    key = tostring(key)
    local spaced = key:gsub('(%l)(%u)', '%1 %2')
    spaced = spaced:gsub('(%a)(%d)', '%1 %2')
    spaced = spaced:gsub('(%d)(%a)', '%1 %2')
    return spaced:gsub('^%l', string.upper)
end

local function formatScalarValue(key, value)
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

local function formatValue(key, value)
    if type(value) == 'table' then
        if value.name or value.itemId or value.amount or value.count or value.chance or value.difficulty or value.diffculty then
            local parts = {}
            local count = tonumber(value.count) or tonumber(value.amount)
            local chance = value.chance
            local difficulty = value.difficulty or value.diffculty

            if count and count > 0 then
                table.insert(parts, string.format('Max count: %d', count))
            end
            if chance ~= nil and tostring(chance) ~= '' then
                table.insert(parts, string.format('Chance: %s', tostring(chance)))
            end
            if difficulty ~= nil and tostring(difficulty) ~= '' then
                table.insert(parts, string.format('Difficulty: %s', tostring(difficulty)))
            end

            if #parts > 0 then
                return table.concat(parts, ', ')
            end

            if value.name and tostring(value.name) ~= '' then
                return tostring(value.name)
            end

            if tonumber(value.itemId) and tonumber(value.itemId) > 0 then
                return string.format('Item ID: %d', tonumber(value.itemId))
            end

            return ''
        end

        local parts = {}
        for _, entry in ipairs(value) do
            if type(entry) == 'table' then
                if entry.name then
                    local text = tostring(entry.name)
                    if entry.count then
                        text = string.format('%s x%s', text, tostring(entry.count))
                    end
                    if entry.chance then
                        text = string.format('%s (%s)', text, tostring(entry.chance))
                    end
                    table.insert(parts, text)
                else
                    local nested = {}
                    for nestedKey, nestedValue in pairs(entry) do
                        table.insert(nested, string.format('%s: %s', humanizeKey(nestedKey), formatScalarValue(nestedKey, nestedValue)))
                    end
                    table.sort(nested)
                    table.insert(parts, table.concat(nested, ', '))
                end
            else
                table.insert(parts, tostring(entry))
            end
        end
        return table.concat(parts, '\n')
    end
    return formatScalarValue(key, value)
end

local function isVisibleLootEntry(entry)
    if type(entry) ~= 'table' then
        return false
    end

    local name = entry.name and tostring(entry.name) or ''
    if name:trim() ~= '' then
        return true
    end

    local itemId = tonumber(entry.itemId) or 0
    return itemId > 0
end

local function getLootDisplayData(entry)
    local itemName = entry.name and tostring(entry.name) or ''
    local count = tonumber(entry.count) or tonumber(entry.amount)
    local chance = entry.chance

    return {
        name = itemName ~= '' and itemName or '-',
        count = count and count > 0 and tostring(count) or '-',
        chance = chance ~= nil and tostring(chance) ~= '' and tostring(chance) or '-'
    }
end

local function isVisibleAttackEntry(entry)
    if type(entry) ~= 'table' then
        return false
    end

    local name = entry.name and tostring(entry.name) or ''
    return name:trim() ~= ''
end

local function getAttackDisplayData(entry)
    local name = entry.name and tostring(entry.name) or '-'
    local range = entry.range ~= nil and tostring(entry.range) ~= '' and tostring(entry.range) or '-'
    local damage = entry.damage ~= nil and tostring(entry.damage) ~= '' and tostring(entry.damage) or '-'
    local chance = entry.chance ~= nil and tostring(entry.chance) ~= '' and tostring(entry.chance) or '-'
    local interval = entry.interval ~= nil and tostring(entry.interval) ~= '' and tostring(entry.interval) or '-'

    return {
        name = name,
        range = range,
        damage = damage,
        chance = chance,
        interval = interval
    }
end

local function getFieldLabel(key)
    local meta = fieldMeta[key]
    return meta and meta.label or humanizeKey(key)
end

local function sendRequest(domain, action, data)
    local protocol = getProtocol()
    if not protocol then
        return nil
    end

    local requestId = makeRequestId(domain, action)
    state.pending[requestId] = {
        domain = domain,
        action = action,
        data = copyTable(data)
    }
    local payload = {
        version = 1,
        action = action,
        domain = domain,
        requestId = requestId,
        data = data or {}
    }
    protocol:sendExtendedJSONOpcode(LIBRARY_OPCODE, payload)
    return requestId
end

local function ensureCategoriesRequested()
    local itemsState = state.items
    if itemsState.categoriesLoaded or itemsState.categoriesRequested then
        return
    end
    itemsState.categoriesRequested = true
    sendRequest(DOMAIN_ITEMS, 'categories')
end

local function ensureMonsterCategoriesRequested()
    local monstersState = state.monsters
    if monstersState.categoriesLoaded or monstersState.categoriesRequested then
        return
    end
    monstersState.categoriesRequested = true
    sendRequest(DOMAIN_MONSTERS, 'categories')
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
        if type(a.key) == 'number' and type(b.key) == 'number' then
            return a.key < b.key
        end
        return tostring(a.key) < tostring(b.key)
    end)

    for _, entry in ipairs(remainder) do
        table.insert(ordered, entry)
    end

    return ordered
end

local function shouldShowRange(domain)
    local domainState = getDomainState(domain)
    return domain == DOMAIN_ITEMS and (
        domainState.activeCategory == 'WEAPONS_AMMO'
        or domainState.activeCategory == 'WEAPONS_BOW'
        or domainState.activeCategory == 'WEAPONS_CROSSBOW'
    )
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

local function normalizeMonsterOutfit(outfitData)
    if type(outfitData) ~= 'table' then
        return nil
    end

    local outfit = {
        type = tonumber(outfitData.type) or tonumber(outfitData.lookType) or 0,
        head = tonumber(outfitData.head) or 0,
        body = tonumber(outfitData.body) or 0,
        legs = tonumber(outfitData.legs) or 0,
        feet = tonumber(outfitData.feet) or 0,
        addons = tonumber(outfitData.addons) or 0,
        mount = tonumber(outfitData.mount) or 0,
        auxType = tonumber(outfitData.auxType) or 0
    }

    if outfit.type <= 0 then
        return nil
    end

    outfit.category = tonumber(outfitData.category) or ThingCategoryCreature
    return outfit
end

local function applyMonsterPreview(widget, raceId, outfitData)
    local sprite = widget and widget:recursiveGetChildById('Sprite')
    local creature = widget and (widget:recursiveGetChildById('Creature') or widget:recursiveGetChildById('detailCreature'))
    local iconBackground = widget and widget:recursiveGetChildById('iconBackground')

    if sprite then
        sprite:setItemId(0)
        sprite:setVisible(false)
    end
    if creature then
        creature:setVisible(false)
    end
    if iconBackground then
        iconBackground:setImageSource('/images/ui/item')
    end

    if not widget then
        return false
    end

    local resolvedOutfit = normalizeMonsterOutfit(outfitData)
    if not resolvedOutfit then
        local numericRaceId = tonumber(raceId) or 0
        if numericRaceId <= 0 then
            return false
        end

        local raceData = g_things.getRaceData(numericRaceId)
        if not raceData or raceData.raceId == 0 then
            return false
        end

        resolvedOutfit = raceData.outfit
    end

    if creature then
        creature:setOutfit(resolvedOutfit)
        creature:getCreature():setStaticWalking(1000)
        creature:setVisible(true)
    end
    if iconBackground then
        iconBackground:setImageSource('')
    end
    return true
end

local function requestDetail(entryId, tier)
    if not entryId then
        return
    end

    local domainState = getDomainState()
    local numericTier = tonumber(tier) or 1
    domainState.selectedId = entryId
    domainState.selectedTier = numericTier
    local cacheKey = makeDetailCacheKey(state.domain, entryId, numericTier)
    local cached = domainState.detailCache[cacheKey]
    if cached then
        showDetail(cached)
        return
    end

    resetDetailPanel(getDetailLoadingText(state.domain), false)
    local payload = state.domain == DOMAIN_MONSTERS and { monsterId = entryId } or { wareId = entryId, tier = numericTier }
    sendRequest(state.domain, 'detail', payload)
end

local function renderTierTabs(currentTier, availableTiers)
    ui.tierTabs:destroyChildren()

    if state.domain ~= DOMAIN_ITEMS or #availableTiers <= 1 then
        ui.tierTabsPanel:hide()
        return
    end

    for _, tier in ipairs(availableTiers) do
        local button = g_ui.createWidget('LibraryTierButton', ui.tierTabs)
        button.tierValue = tier
        button:setText(tierNames[tier] or ('Tier ' .. tier))
        button:setChecked(tier == currentTier)
        button.onClick = function(widget)
            local domainState = getDomainState()
            if widget.tierValue == domainState.selectedTier then
                return
            end
            requestDetail(domainState.selectedId, widget.tierValue)
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

    local description = details.__description
    if state.domain == DOMAIN_ITEMS and type(description) == 'string' and description:trim() ~= '' then
        local heading = g_ui.createWidget('LibrarySectionLabel', list)
        heading:setText(tr('Description') .. ':')

        local descriptionLabel = g_ui.createWidget('Label', list)
        descriptionLabel:setText(description)
        descriptionLabel:setColor('#BDBDBD')
        descriptionLabel:setTextWrap(true)
        descriptionLabel:setWidth(360)
        if descriptionLabel.setAutoResize then
            descriptionLabel:setAutoResize(false)
        end
        descriptionLabel:setHeight(math.max(34, math.ceil(#description / 48) * 14))
    end

    for _, group in ipairs(groupOrder[state.domain] or {}) do
        local values = details[group.key]
        if type(values) == 'table' then
            if group.key == 'attacks' then
                local visibleAttacks = {}
                for _, entry in ipairs(values) do
                    if isVisibleAttackEntry(entry) then
                        table.insert(visibleAttacks, entry)
                    end
                end

                if #visibleAttacks > 0 then
                    local heading = g_ui.createWidget('LibrarySectionLabel', list)
                    heading:setText(group.label .. ':')

                    g_ui.createWidget('LibraryAttackTableHeader', list)

                    for _, entry in ipairs(visibleAttacks) do
                        local attackData = getAttackDisplayData(entry)
                        local row = g_ui.createWidget('LibraryAttackTableRow', list)
                        local nameLabel = row:getChildById('name')
                        local rangeLabel = row:getChildById('range')
                        local damageLabel = row:getChildById('damage')
                        local chanceLabel = row:getChildById('chance')
                        local intervalLabel = row:getChildById('interval')

                        local lineCount = select(2, attackData.name:gsub('\n', '\n')) + 1
                        local requiresTallRow = #attackData.name > 24 or lineCount > 1
                        row:setHeight(requiresTallRow and math.max(24, lineCount * 14) or 20)

                        if nameLabel then
                            nameLabel:setText(attackData.name)
                            nameLabel:setTextWrap(requiresTallRow)
                        end
                        if rangeLabel then
                            rangeLabel:setText(attackData.range)
                        end
                        if damageLabel then
                            damageLabel:setText(attackData.damage)
                        end
                        if chanceLabel then
                            chanceLabel:setText(attackData.chance)
                        end
                        if intervalLabel then
                            intervalLabel:setText(attackData.interval)
                        end
                    end
                end
            elseif group.key == 'loot' then
                local visibleLoot = {}
                for _, entry in ipairs(values) do
                    if isVisibleLootEntry(entry) then
                        table.insert(visibleLoot, entry)
                    end
                end

                if #visibleLoot > 0 then
                    local heading = g_ui.createWidget('LibrarySectionLabel', list)
                    heading:setText(group.label .. ':')

                    g_ui.createWidget('LibraryLootTableHeader', list)

                    for _, entry in ipairs(visibleLoot) do
                        local lootData = getLootDisplayData(entry)
                        local row = g_ui.createWidget('LibraryLootTableRow', list)
                        local nameLabel = row:getChildById('name')
                        local countLabel = row:getChildById('count')
                        local chanceLabel = row:getChildById('chance')

                        local lineCount = select(2, lootData.name:gsub('\n', '\n')) + 1
                        local requiresTallRow = #lootData.name > 26 or lineCount > 1
                        row:setHeight(requiresTallRow and math.max(24, lineCount * 14) or 20)

                        if nameLabel then
                            nameLabel:setText(lootData.name)
                            nameLabel:setTextWrap(requiresTallRow)
                        end
                        if countLabel then
                            countLabel:setText(lootData.count)
                        end
                        if chanceLabel then
                            chanceLabel:setText(lootData.chance)
                        end
                    end
                end
            else
            local displayValues = copyTable(values)

            if group.key == 'basic' then
                displayValues.range = nil
            elseif group.key == 'combat' and not shouldShowRange(state.domain) then
                displayValues.range = nil
            end

            if next(displayValues) ~= nil then
                local heading = g_ui.createWidget('LibrarySectionLabel', list)
                heading:setText(group.label .. ':')

                for _, entry in ipairs(getOrderedGroupEntries(group.key, displayValues)) do
                    local key = entry.key
                    local value = entry.value
                    local row = g_ui.createWidget('ItemBasicDetail', list)
                    local background = row:getChildById('background')
                    local nameLabel = background and background:getChildById('name')
                    local valueLabel = background and background:getChildById('value')
                    local textValue = formatValue(key, value)
                    local lineCount = select(2, textValue:gsub('\n', '\n')) + 1
                    local requiresTallRow = (type(value) == 'string' and #value > 40) or lineCount > 1
                    row:setHeight(requiresTallRow and math.max(34, lineCount * 14) or 20)
                    if nameLabel then
                        nameLabel:setText(getFieldLabel(key))
                    end
                    if valueLabel then
                        valueLabel:setText(textValue)
                        valueLabel:setTextWrap(type(value) == 'string' or lineCount > 1)
                    end
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

    local domain = data.domain or state.domain
    if domain ~= state.domain then
        return
    end

    local domainState = getDomainState(domain)
    local selectedId = domain == DOMAIN_MONSTERS and (data.monsterId or data.id) or tonumber(data.wareId)
    domainState.selectedId = selectedId or domainState.selectedId
    domainState.selectedTier = tonumber(data.tier) or 1
    domainState.availableTiers = domain == DOMAIN_ITEMS and normalizeTierList(data.availableTiers) or {}
    ui.detailPlaceholder:hide()
    ui.detailContent:show()
    ui.itemName:setText(data.name or (domain == DOMAIN_MONSTERS and tr('Monster') or tr('Item')))

    local details = copyTable(data.details or {})
    details.__description = data.description

    if domain == DOMAIN_MONSTERS then
        ui.selectedItem:setVisible(false)
        ui.itemSprite:setItemId(0)
        local visible = applyMonsterPreview(ui.detailContent, data.raceId, data.outfit)
        if not visible then
            resetDetailCreature()
        end
    else
        resetDetailCreature()
        ui.selectedItem:setVisible(true)
        ui.itemSprite:setItemId(tonumber(data.clientId) or 0)
    end

    renderTierTabs(domainState.selectedTier, domainState.availableTiers)
    renderDetailGroups(details)
end

local function clearResultSelection(domain)
    local domainState = getDomainState(domain)
    if domainState.selectedResult and not domainState.selectedResult:isDestroyed() then
        domainState.selectedResult:setChecked(false)
    end
    domainState.selectedResult = nil
end

local function onResultSelected(widget, entry)
    local domainState = getDomainState()
    if domainState.selectedResult and domainState.selectedResult ~= widget and not domainState.selectedResult:isDestroyed() then
        domainState.selectedResult:setChecked(false)
    end

    domainState.selectedResult = widget
    domainState.selectedId = state.domain == DOMAIN_MONSTERS and (entry.monsterId or entry.id) or tonumber(entry.wareId)
    domainState.selectedTier = 1
    widget:setChecked(true)
    requestDetail(domainState.selectedId, 1)
end

local function renderResults(response)
    local list = state.domain == DOMAIN_MONSTERS and ui.monsterList or ui.resultList
    list:destroyChildren()
    hideAllEmptyLabels()
    clearResultSelection(state.domain)

    local domainState = getDomainState()
    local items = response.items or {}
    domainState.page = tonumber(response.page) or 1
    domainState.totalPages = math.max(1, tonumber(response.totalPages) or 1)
    domainState.totalResults = tonumber(response.totalResults) or #items
    updatePagination()
    setResultWidgetsEnabled(state.domain == DOMAIN_MONSTERS or domainState.activeCategory ~= nil)

    if #items == 0 then
        if state.domain == DOMAIN_MONSTERS then
            updateMonsterEmptyLabel(getNoResultsText(state.domain))
        else
            updateResultEmptyLabel(getNoResultsText(state.domain))
        end
        resetDetailPanel(getSelectionPlaceholder(state.domain))
        return
    end

    for _, entry in ipairs(items) do
        local rowType = state.domain == DOMAIN_MONSTERS and 'LibraryMonsterListItem' or 'LibraryResultItem'
        local row = g_ui.createWidget(rowType, list)
        local sprite = row:recursiveGetChildById('Sprite')
        local creature = row:recursiveGetChildById('Creature')
        local nameLabel = row:recursiveGetChildById('Name')
        row:setPhantom(false)

        if state.domain == DOMAIN_MONSTERS then
            if sprite then
                sprite:setItemId(0)
                sprite:setVisible(false)
            end
            if not applyMonsterPreview(row, entry.raceId, entry.outfit) and creature then
                creature:setVisible(false)
            end
        else
            if creature then
                creature:setVisible(false)
            end
            if sprite then
                sprite:setVisible(true)
                sprite:setItemId(tonumber(entry.clientId) or 0)
            end
        end

        if nameLabel then
            nameLabel:setText(entry.name or (state.domain == DOMAIN_MONSTERS and tr('Unknown monster') or tr('Unknown item')))
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

    resetDetailPanel(getSelectionPlaceholder(state.domain))
end

local function requestCurrentPage(force)
    local domainState = getDomainState()
    if not domainState.activeCategory then
        if state.domain == DOMAIN_MONSTERS then
            updateMonsterEmptyLabel(tr('Select a category to load monsters.'))
        else
            updateResultEmptyLabel(tr('Select a category to load items.'))
        end
        setResultWidgetsEnabled(false)
        return
    end

    local search = normalizeSearch(domainState.search or '')
    local category = domainState.activeCategory or ''
    local cacheKey = makePageCacheKey(state.domain, category, search, domainState.page)
    if not force and domainState.pageCache[cacheKey] then
        renderResults(domainState.pageCache[cacheKey])
        return
    end

    if state.domain == DOMAIN_MONSTERS then
        ui.monsterList:destroyChildren()
        updateMonsterEmptyLabel(getLoadingText(state.domain))
    else
        ui.resultList:destroyChildren()
        updateResultEmptyLabel(getLoadingText(state.domain))
    end
    resetDetailPanel(getSelectionPlaceholder(state.domain))
    setResultWidgetsEnabled(true)

    local payload = {
        category = domainState.activeCategory,
        page = domainState.page,
        pageSize = PAGE_SIZE,
        search = search
    }
    sendRequest(state.domain, 'list', payload)
end

local function updateDomainUi()
    local isItems = state.domain == DOMAIN_ITEMS
    ui.itemsTab:setOn(isItems)
    ui.monstersTab:setOn(not isItems)
    ui.categoryPanel:setVisible(isItems)
    ui.monsterPanel:setVisible(not isItems)
    ui.itemsSection:setVisible(isItems)
    ui.resultLabel:setText(getResultLabelText(state.domain) .. ':')
    ui.detailPlaceholder:setText(getInitialPlaceholder(state.domain))
    ui.topListEmptyLabel:setVisible(false)
    ui.monsterEmptyLabel:setVisible(false)
    anchorSearchSection(isItems)

    if isItems then
        ui.resultEmptyLabel:setVisible(false)
    else
        ui.resultList:destroyChildren()
        ui.resultEmptyLabel:setText(tr('Select a monster from the list above.'))
        ui.resultEmptyLabel:setVisible(true)
    end
end

local function setCategory(categoryKey)
    local domainState = state.items
    if domainState.activeCategory == categoryKey then
        return
    end

    domainState.activeCategory = categoryKey
    domainState.page = 1
    domainState.search = ''
    ui.searchEdit:setText('')

    for _, widget in ipairs(ui.categoryList:getChildren()) do
        widget:setChecked(widget.categoryKey == categoryKey)
    end

    requestCurrentPage(false)
end

local function getMonsterCategoryLabel(entry)
    if type(entry) ~= 'table' then
        return ''
    end
    if type(entry.label) == 'string' and entry.label ~= '' then
        return entry.label
    end
    return humanizeKey(entry.key)
end

local function renderCategories()
    local list = ui.categoryList
    list:destroyChildren()

    for _, entry in ipairs(categories) do
        local widget = g_ui.createWidget('LibraryCategoryItem', list)
        widget.categoryKey = entry.key
        widget:setText(entry.label)
        widget:setChecked(state.items.activeCategory == entry.key)
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

local function setMonsterCategory(categoryKey)
    local domainState = state.monsters
    if domainState.activeCategory == categoryKey then
        return
    end

    domainState.activeCategory = categoryKey
    domainState.page = 1
    domainState.search = ''
    if domainState.selectedResult and not domainState.selectedResult:isDestroyed() then
        domainState.selectedResult:setChecked(false)
    end
    domainState.selectedResult = nil
    domainState.selectedId = nil
    domainState.selectedTier = 1
    ui.searchEdit:setText('')

    for _, widget in ipairs(ui.monsterCategoryList:getChildren()) do
        widget:setChecked(widget.categoryKey == categoryKey)
    end

    requestCurrentPage(false)
end

local function renderMonsterCategories()
    local list = ui.monsterCategoryList
    list:destroyChildren()

    for _, entry in ipairs(state.monsters.categories) do
        local widget = g_ui.createWidget('LibraryCategoryItem', list)
        widget.categoryKey = entry.key
        widget:setText(getMonsterCategoryLabel(entry))
        widget:setChecked(state.monsters.activeCategory == entry.key)
        widget.onClick = function()
            setMonsterCategory(entry.key)
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

local function normalizeMonsterCategories(serverCategories)
    local normalized = {}
    local seen = {}
    local defaultCategory = nil
    local hiddenMonsterCategories = {
        newCampArena = true
    }

    local function addCategory(category)
        if type(category) ~= 'table' or type(category.key) ~= 'string' or category.key == '' or seen[category.key] then
            return
        end
        if hiddenMonsterCategories[category.key] then
            return
        end
        local entry = {
            key = category.key,
            label = category.label,
            default = category.default == true,
            implicit = category.implicit == true
        }
        seen[entry.key] = true
        table.insert(normalized, entry)
        if entry.default and not defaultCategory then
            defaultCategory = entry.key
        end
    end

    if type(serverCategories) == 'table' then
        for _, category in ipairs(serverCategories) do
            addCategory(category)
        end
    end

    if not seen.normal then
        addCategory(defaultMonsterCategories[1])
        defaultCategory = defaultCategory or 'normal'
    end

    if not defaultCategory and normalized[1] then
        defaultCategory = normalized[1].key
    end

    return normalized, defaultCategory
end

local function handleCategoriesResponse(data)
    state.items.categoriesLoaded = true
    state.items.categoriesRequested = false
    mergeServerCategories(data.categories)
    renderCategories()
end

local function handleMonsterCategoriesResponse(data)
    local monstersState = state.monsters
    local previousCategory = monstersState.activeCategory
    monstersState.categoriesLoaded = true
    monstersState.categoriesRequested = false
    monstersState.categories, monstersState.activeCategory = normalizeMonsterCategories(data.categories)
    renderMonsterCategories()

    if state.domain == DOMAIN_MONSTERS and monstersState.activeCategory and monstersState.activeCategory ~= previousCategory then
        requestCurrentPage(false)
    end
end

local function handleListResponse(domain, data, requestData)
    local domainState = getDomainState(domain)
    requestData = requestData or {}
    local search = normalizeSearch(data.search or requestData.search or '')
    local category = data.category or requestData.category or domainState.activeCategory or ''
    local page = tonumber(data.page) or tonumber(requestData.page) or 1
    data.domain = domain
    local cacheKey = makePageCacheKey(domain, category, search, page)
    domainState.pageCache[cacheKey] = data

    if domain == state.domain and category == (domainState.activeCategory or '') and search == normalizeSearch(domainState.search or '') then
        renderResults(data)
    end
end

local function handleDetailResponse(domain, data, requestData)
    local domainState = getDomainState(domain)
    requestData = requestData or {}
    local id = domain == DOMAIN_MONSTERS and (data.monsterId or data.id or requestData.monsterId) or tonumber(data.wareId or requestData.wareId)
    local tier = tonumber(data.tier or requestData.tier) or 1
    data.domain = domain
    if id then
        domainState.detailCache[makeDetailCacheKey(domain, id, tier)] = data
    end
    if domain == state.domain and id == domainState.selectedId and (domain == DOMAIN_MONSTERS or tier == tonumber(domainState.selectedTier)) then
        showDetail(data)
    end
end

local function handleLibraryError(domain, action, payload)
    if domain ~= state.domain then
        return
    end

    local message = tr('Library request failed.')
    if type(payload) == 'table' and type(payload.error) == 'table' and type(payload.error.message) == 'string' then
        message = payload.error.message
    end

    if domain == DOMAIN_ITEMS and action == 'categories' then
        state.items.categoriesRequested = false
    elseif domain == DOMAIN_MONSTERS and action == 'categories' then
        state.monsters.categoriesRequested = false
    end

    if domain == DOMAIN_MONSTERS then
        updateMonsterEmptyLabel(message)
    else
        updateResultEmptyLabel(message)
    end
    ui.detailPlaceholder:setText(message)
end

local function onLibraryOpcode(protocol, opcode, payload)
    if type(payload) ~= 'table' then
        return
    end

    local requestId = payload.requestId
    local action = payload.action
    local domain = payload.domain or state.domain
    local requestData = {}
    if requestId ~= nil then
        local pending = state.pending[requestId]
        state.pending[requestId] = nil
        if pending then
            action = action or pending.action
            domain = payload.domain or pending.domain
            requestData = pending.data or requestData
        end
    end

    if payload.ok == false then
        handleLibraryError(domain, action, payload)
        return
    end

    local data = payload.data or {}
    if action == 'categories' and domain == DOMAIN_ITEMS then
        handleCategoriesResponse(data)
    elseif action == 'categories' and domain == DOMAIN_MONSTERS then
        handleMonsterCategoriesResponse(data)
    elseif action == 'list' then
        handleListResponse(domain, data, requestData)
    elseif action == 'detail' then
        handleDetailResponse(domain, data, requestData)
    end
end

local function queueSearch()
    if searchEvent then
        removeEvent(searchEvent)
        searchEvent = nil
    end

    searchEvent = scheduleEvent(function()
        searchEvent = nil
        local domainState = getDomainState()
        domainState.search = ui.searchEdit:getText() or ''
        domainState.page = 1
        requestCurrentPage(true)
    end, SEARCH_DELAY)
end

local function clearSearch()
    if ui.searchEdit:getText() == '' then
        return
    end
    ui.searchEdit:setText('')
    local domainState = getDomainState()
    domainState.search = ''
    domainState.page = 1
    requestCurrentPage(true)
end

local function switchDomain(domain)
    if state.domain == domain then
        return
    end

    state.domain = domain
    updateDomainUi()
    clearResultSelection(DOMAIN_ITEMS)
    clearResultSelection(DOMAIN_MONSTERS)

    local domainState = getDomainState()
    ui.searchEdit:setText(domainState.search or '')

    if domain == DOMAIN_ITEMS then
        ensureCategoriesRequested()
        renderCategories()
    else
        ensureMonsterCategoriesRequested()
        renderMonsterCategories()
    end

    if domainState.activeCategory then
        requestCurrentPage(false)
    else
        if domain == DOMAIN_MONSTERS then
            updateMonsterEmptyLabel(tr('Select a category to load monsters.'))
        else
            updateResultEmptyLabel(tr('Select a category to load items.'))
        end
        resetDetailPanel(getInitialPlaceholder(domain))
        setResultWidgetsEnabled(false)
        updatePagination()
    end
end

local function show()
    if not libraryWindow or not g_game.isOnline() then
        return
    end

    libraryWindow:show()
    libraryWindow:raise()
    libraryWindow:focus()
    if libraryButton then
        libraryButton:setOn(true)
    end

    updateDomainUi()
    if state.domain == DOMAIN_ITEMS then
        ensureCategoriesRequested()
        renderCategories()
    else
        ensureMonsterCategoriesRequested()
        renderMonsterCategories()
    end

    local domainState = getDomainState()
    ui.searchEdit:setText(domainState.search or '')
    if domainState.activeCategory then
        requestCurrentPage(false)
    else
        if state.domain == DOMAIN_MONSTERS then
            updateMonsterEmptyLabel(tr('Select a category to load monsters.'))
        else
            updateResultEmptyLabel(tr('Select a category to load items.'))
        end
        resetDetailPanel(getInitialPlaceholder(state.domain))
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
    clearResultSelection(DOMAIN_ITEMS)
    clearResultSelection(DOMAIN_MONSTERS)
    ui.searchEdit:setText('')
    ui.resultList:destroyChildren()
    ui.monsterList:destroyChildren()
    renderCategories()
    renderMonsterCategories()
    ui.detailList:destroyChildren()
    updateDomainUi()
    if state.domain == DOMAIN_MONSTERS then
        updateMonsterEmptyLabel(tr('Select a category to load monsters.'))
    else
        updateResultEmptyLabel(tr('Select a category to load items.'))
    end
    resetDetailPanel(getInitialPlaceholder(state.domain))
    updatePagination()
    setResultWidgetsEnabled(false)
end

local function resetDomainState(domain)
    local domainState = getDomainState(domain)
    domainState.search = ''
    domainState.page = 1
    domainState.totalPages = 1
    domainState.totalResults = 0
    domainState.selectedId = nil
    domainState.selectedTier = 1
    domainState.availableTiers = {}
    domainState.selectedResult = nil
    domainState.pageCache = {}
    domainState.detailCache = {}
    if domain == DOMAIN_ITEMS then
        domainState.categoriesLoaded = false
        domainState.categoriesRequested = false
        domainState.activeCategory = nil
    else
        domainState.categoriesLoaded = false
        domainState.categoriesRequested = false
        domainState.categories = {}
        domainState.activeCategory = nil
    end
end

local function resetDataState()
    state.domain = DOMAIN_ITEMS
    resetDomainState(DOMAIN_ITEMS)
    resetDomainState(DOMAIN_MONSTERS)
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
    ui.itemsTab.onClick = function() switchDomain(DOMAIN_ITEMS) end
    ui.monstersTab.onClick = function() switchDomain(DOMAIN_MONSTERS) end
    ui.closeButton.onClick = hide
    libraryWindow.onEscape = hide
    ui.searchEdit.onTextChange = queueSearch
    ui.searchClearButton.onClick = clearSearch
    ui.prevPageButton.onClick = function()
        local domainState = getDomainState()
        if domainState.page > 1 then
            domainState.page = domainState.page - 1
            requestCurrentPage(false)
        end
    end
    ui.nextPageButton.onClick = function()
        local domainState = getDomainState()
        if domainState.page < domainState.totalPages then
            domainState.page = domainState.page + 1
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

    resetDataState()
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
