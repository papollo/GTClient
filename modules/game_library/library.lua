local LIBRARY_OPCODE = 217
local PAGE_SIZE = 20
local SEARCH_DELAY = 250
local CLAIM_BUTTON_COLOR = '#6fbf5f'
local CLAIMED_BUTTON_COLOR = '#e84a4a'
local DAILY_REWARD_NOTIFY_COLOR = '#ffd34d'
local LIBRARY_BUTTON_DEFAULT_COLOR = '#ffffff'
local MONSTER_ROW_EVEN_COLOR = '#484848'
local MONSTER_ROW_ODD_COLOR = '#565656'
local MONSTER_ROW_HOVER_COLOR = '#525252'
local MONSTER_ROW_SELECTED_COLOR = '#585858'
local DAILY_TAB_DEFAULT_BACKGROUND = '#484848'
local DAILY_TAB_ACTIVE_BACKGROUND = '#585858'
local DAILY_TAB_DEFAULT_BORDER = '#222222'
local DAILY_TAB_ACTIVE_BORDER = '#747474'
local NOTIFICATION_BLINK_INTERVAL = 500
local VOCATION_FORMULA_POSITIVE_COLOR = '#6fbf5f'
local VOCATION_FORMULA_NEGATIVE_COLOR = '#e84a4a'
local VOCATION_FORMULA_NEUTRAL_COLOR = '#BDBDBD'

local libraryWindow = nil
local libraryButton = nil
local ui = nil
local searchEvent = nil
local requestCounter = 0
local showDetail = nil

local DOMAIN_ITEMS = 'items'
local DOMAIN_MONSTERS = 'monsters'
local DOMAIN_VOCATIONS = 'vocations'
local DOMAIN_DAILY_REWARDS = 'dailyRewards'
local DOMAIN_BLESSINGS = 'blessings'
local DOMAIN_DAMAGE_CALCULATOR = 'damageCalculator'

local BLESSING_IMAGE_BY_KEY = {
    ADANOS = '/images/game/gothic_tales/bless_gods/adanos',
    INNOS = '/images/game/gothic_tales/bless_gods/innos',
    BELIAR = '/images/game/gothic_tales/bless_gods/beliar',
    SLEEPER = '/images/game/gothic_tales/bless_gods/sleeper'
}

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
    { key = 'MAGIC_SCROLLS', label = 'Magic Scrolls' },
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
        selectedDetailMonsterId = nil,
        selectedTier = 1,
        selectedVariant = nil,
        availableTiers = {},
        availableVariants = {},
        selectedResult = nil,
        totalBestiaryPoints = nil,
        pageCache = {},
        detailCache = {}
    },
    vocations = {
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
        selectedResult = nil,
        pageCache = {},
        detailCache = {}
    },
    dailyRewards = {
        status = nil,
        statusRequested = false,
        notificationEvent = nil,
        tabNotificationEvent = nil,
        notificationBlinkOn = false,
        tabNotificationBlinkOn = false,
        notificationAvailable = false,
        selectedItems = {
            free = {},
            premium = {}
        },
        rewardWidgets = {
            free = {},
            premium = {}
        }
    },
    blessings = {
        status = nil,
        statusRequested = false
    },
    damageCalculator = {
        categoriesLoaded = false,
        categoriesRequested = false,
        categories = {},
        activeCategory = nil,
        search = '',
        page = 1,
        totalPages = 1,
        totalResults = 0,
        selectedId = nil,
        selectedClientId = nil,
        selectedName = nil,
        selectedTier = 1,
        availableTiers = {},
        runeTierNames = {
            [1] = 'I',
            [2] = 'II',
            [3] = 'III'
        },
        skillOverride = nil,
        calculationSkill = nil,
        skillOverrideEvent = nil,
        skillEditUpdating = false,
        levelOverride = nil,
        calculationLevel = nil,
        levelOverrideEvent = nil,
        levelEditUpdating = false,
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
        { key = 'summons', label = 'Summons' },
        { key = 'resistances', label = 'Resistances' },
        { key = 'loot', label = 'Loot' },
        { key = 'location', label = 'Location' },
        { key = 'skills', label = 'Skills' }
    },
    [DOMAIN_VOCATIONS] = {
        { key = 'basic', label = 'Basic' },
        { key = 'regeneration', label = 'Regeneration' },
        { key = 'formula', label = 'Formula' },
        { key = 'skills', label = 'Skills' }
    }
}

local groupFieldOrder = {
    basic = {
        'requiredLevel', 'requiredMagicLevel', 'requiredStrength', 'requiredAgility', 'tier', 'weight', 'armor',
        'attack', 'defense', 'extraDefense', 'hitChance', 'attackSpeed', 'containerSize', 'text', 'health',
        'experience', 'speed', 'mitigation', 'summonCost', 'convinceCost', 'healthGain', 'manaGain', 'capGain',
        'soul', 'pvpDamage', 'noPong'
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
        'magicLevel', 'magicLevelMultiplier', 'speed', 'healthGain', 'manaGain', 'maxHealthPoints', 'maxManaPoints'
    },
    loot = {
        'value', 'count', 'chance', 'difficulty', 'stackable'
    },
    location = {
        'name', 'area', 'places', 'notes'
    },
    regeneration = {
        'healthGain', 'healthTicks', 'manaGain', 'manaTicks'
    },
    progression = {
        'magicLevelMultiplier', 'weaponSkillMultiplier', 'role', 'promotionFrom', 'promotionTo'
    },
    formula = {
        'melee', 'meleeDamage', 'meleeDamageMultiplier',
        'dist', 'distance', 'distDamage', 'distanceDamage', 'distanceDamageMultiplier',
        'armor', 'armorMultiplier',
        'defense', 'defenseMultiplier'
    }
}

local fieldMeta = {
    requiredLevel = { label = 'Required Level' },
    requiredMagicLevel = { label = 'Required Magic Level' },
    requiredStrength = { label = 'Required Strength' },
    requiredAgility = { label = 'Required Agility' },
    tier = { label = 'Tier' },
    weight = { label = 'Weight', weight = true },
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
    capGain = { label = 'Capacity Gain' },
    pvpDamage = { label = 'PvP Damage' },
    noPong = { label = 'No Pong' },
    healthTicks = { label = 'Health Ticks' },
    manaTicks = { label = 'Mana Ticks' },
    magicLevelMultiplier = { label = 'Magic Level' },
    weaponSkillMultiplier = { label = 'Weapon Learning Speed' },
    role = { label = 'Role' },
    promotionFrom = { label = 'Promotion From' },
    promotionTo = { label = 'Promotion To' },
    meleeDamage = { label = 'Melee Damage' },
    meleeDamageMultiplier = { label = 'Melee Damage' },
    dist = { label = 'Dist Damage' },
    distanceDamage = { label = 'Dist Damage' },
    melee = { label = 'Melee Damage' },
    distance = { label = 'Dist Damage' },
    distDamage = { label = 'Dist Damage' },
    distanceDamageMultiplier = { label = 'Dist Damage' },
    defenseMultiplier = { label = 'Defense' },
    armorMultiplier = { label = 'Armor' },
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

local VARIANT_ORDER = {
    weak = 1,
    normal = 2,
    strong = 3
}

local function getProtocol()
    return g_game.getProtocolGame()
end

local function getDomainState(domain)
    return state[domain or state.domain]
end

local function isDamageCalculatorRuneCategory()
    local category = state.damageCalculator.activeCategory
    return type(category) == 'string' and category:lower():find('rune', 1, true) ~= nil
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
        vocationsTab = child('vocationsTab'),
        dailyRewardsTab = child('dailyRewardsTab'),
        blessingsTab = child('blessingsTab'),
        damageCalculatorTab = child('damageCalculatorTab'),
        leftColumn = child('leftColumn'),
        middleSeparator = child('middleSeparator'),
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
        damageTierFrame = child('damageTierFrame'),
        detailList = child('detailList'),
        detailPanel = child('detailPanel'),
        damageSkillPanel = child('damageSkillPanel'),
        damageActualSkillLabel = child('damageActualSkillLabel'),
        damageSkillOverrideLabel = child('damageSkillOverrideLabel'),
        damageSkillEdit = child('damageSkillEdit'),
        damageLevelPanel = child('damageLevelPanel'),
        damageActualLevelLabel = child('damageActualLevelLabel'),
        damageLevelOverrideLabel = child('damageLevelOverrideLabel'),
        damageLevelEdit = child('damageLevelEdit'),
        dailyRewardsPanel = child('dailyRewardsPanel'),
        dailyStatusLabel = child('dailyStatusLabel'),
        dailyClaimButton = child('dailyClaimButton'),
        dailyRewardsList = child('dailyRewardsList'),
        blessingsPanel = child('blessingsPanel'),
        blessingsStatusLabel = child('blessingsStatusLabel'),
        blessingsList = child('blessingsList'),
        dailyFooterStatsLabel = child('dailyFooterStatsLabel'),
        bestiaryFooterStatsLabel = child('bestiaryFooterStatsLabel'),
        closeButton = child('closeButton')
    }
end

local function getResultLabelText(domain)
    if domain == DOMAIN_DAILY_REWARDS then
        return tr('Daily Rewards')
    end
    if domain == DOMAIN_BLESSINGS then
        return tr('Blessings')
    end
    if domain == DOMAIN_VOCATIONS then
        return tr('Vocations')
    end
    if domain == DOMAIN_DAMAGE_CALCULATOR then
        return tr('Items')
    end
    return domain == DOMAIN_MONSTERS and tr('Monsters') or tr('Items')
end

local function getSelectionPlaceholder(domain)
    if domain == DOMAIN_DAILY_REWARDS then
        return tr('Daily rewards are shown in this tab.')
    end
    if domain == DOMAIN_BLESSINGS then
        return tr('Blessings are shown in this tab.')
    end
    if domain == DOMAIN_MONSTERS then
        return tr('Select a monster to see its details here.')
    end
    if domain == DOMAIN_VOCATIONS then
        return tr('Select a vocation to see its details here.')
    end
    if domain == DOMAIN_DAMAGE_CALCULATOR then
        return tr('Select an item to calculate its damage.')
    end
    return tr('Select an item to see its details here.')
end

local function getInitialPlaceholder(domain)
    if domain == DOMAIN_DAILY_REWARDS then
        return tr('Loading daily rewards...')
    end
    if domain == DOMAIN_BLESSINGS then
        return tr('Loading blessings...')
    end
    if domain == DOMAIN_MONSTERS then
        return tr('Choose the monsters tab and select a monster to see its details here.')
    end
    if domain == DOMAIN_VOCATIONS then
        return tr('Choose the vocations tab and select a vocation to see its details here.')
    end
    if domain == DOMAIN_DAMAGE_CALCULATOR then
        return tr('Select a category and an item to calculate its damage.')
    end
    return tr('Select a category and choose an item to see its details here.')
end

local function getLoadingText(domain)
    if domain == DOMAIN_DAILY_REWARDS then
        return tr('Loading daily rewards...')
    end
    if domain == DOMAIN_BLESSINGS then
        return tr('Loading blessings...')
    end
    if domain == DOMAIN_VOCATIONS then
        return tr('Loading vocations...')
    end
    if domain == DOMAIN_DAMAGE_CALCULATOR then
        return tr('Loading calculator items...')
    end
    return domain == DOMAIN_MONSTERS and tr('Loading monsters...') or tr('Loading items...')
end

local function getDetailLoadingText(domain)
    if domain == DOMAIN_VOCATIONS then
        return tr('Loading vocation details...')
    end
    if domain == DOMAIN_DAMAGE_CALCULATOR then
        return tr('Calculating damage...')
    end
    return domain == DOMAIN_MONSTERS and tr('Loading monster details...') or tr('Loading item details...')
end

local function getNoResultsText(domain)
    if domain == DOMAIN_DAILY_REWARDS then
        return tr('Reward is not available.')
    end
    if domain == DOMAIN_MONSTERS then
        return tr('No monsters found.')
    end
    if domain == DOMAIN_VOCATIONS then
        return tr('No vocations found.')
    end
    if domain == DOMAIN_DAMAGE_CALCULATOR then
        return tr('No calculator items found.')
    end
    return tr('No items found for this category.')
end

local function resetDetailCreature()
    if ui.detailCreature then
        ui.detailCreature:setVisible(false)
        ui.detailCreature:setOutfit({ type = 0 })
    end
end

local function cancelDamageSkillOverrideEvent()
    local calculatorState = state.damageCalculator
    if calculatorState.skillOverrideEvent then
        removeEvent(calculatorState.skillOverrideEvent)
        calculatorState.skillOverrideEvent = nil
    end
end

local function hideDamageSkillPanel()
    if not ui or not ui.damageSkillPanel then
        return
    end
    ui.damageSkillPanel:setHeight(0)
    ui.damageSkillPanel:hide()
end

state.damageCalculator.cancelLevelOverrideEvent = function()
    local calculatorState = state.damageCalculator
    if calculatorState.levelOverrideEvent then
        removeEvent(calculatorState.levelOverrideEvent)
        calculatorState.levelOverrideEvent = nil
    end
end

state.damageCalculator.hideLevelPanel = function()
    if not ui or not ui.damageLevelPanel then
        return
    end
    ui.damageLevelPanel:setHeight(0)
    ui.damageLevelPanel:hide()
end

state.damageCalculator.updateTierFrame = function(tier)
    if not ui or not ui.damageTierFrame then
        return
    end
    local frameImages = ItemsDatabase and ItemsDatabase.tierFrameImages or {
        [2] = '/images/ui/rarity_grey',
        [3] = '/images/ui/rarity_blue',
        [4] = '/images/ui/rarity_purple',
        [5] = '/images/ui/rarity_yellow'
    }
    local image = frameImages[tonumber(tier) or 1]
    if image then
        ui.damageTierFrame:setImageSource(image)
        ui.damageTierFrame:show()
    else
        ui.damageTierFrame:setImageSource('')
        ui.damageTierFrame:hide()
    end
end

local function resetDamageSkillOverride()
    local calculatorState = state.damageCalculator
    cancelDamageSkillOverrideEvent()
    calculatorState.skillOverride = nil
    calculatorState.calculationSkill = nil
end

state.damageCalculator.resetLevelOverride = function()
    local calculatorState = state.damageCalculator
    state.damageCalculator.cancelLevelOverrideEvent()
    calculatorState.levelOverride = nil
    calculatorState.calculationLevel = nil
end

local function resetDetailPanel(message, clearSelection)
    if clearSelection == nil then
        clearSelection = true
    end

    if state.domain == DOMAIN_DAILY_REWARDS or state.domain == DOMAIN_BLESSINGS then
        return
    end

    local domainState = getDomainState()
    ui.detailPlaceholder:setText(message)
    ui.detailPlaceholder:show()
    ui.detailContent:hide()
    hideDamageSkillPanel()
    state.damageCalculator.hideLevelPanel()
    ui.itemName:setText(state.domain == DOMAIN_MONSTERS and tr('Monster') or state.domain == DOMAIN_VOCATIONS and tr('Vocation') or tr('Item'))
    ui.tierTabsPanel:hide()
    ui.tierTabs:destroyChildren()
    ui.itemSprite:setItemId(0)
    state.damageCalculator.updateTierFrame(nil)
    ui.selectedItem:setVisible(state.domain == DOMAIN_ITEMS or state.domain == DOMAIN_DAMAGE_CALCULATOR)
    resetDetailCreature()
    ui.detailList:destroyChildren()
    if clearSelection then
        domainState.selectedId = nil
        if state.domain == DOMAIN_DAMAGE_CALCULATOR then
            domainState.selectedClientId = nil
            domainState.selectedName = nil
        end
        domainState.selectedTier = 1
        domainState.selectedVariant = nil
        domainState.availableTiers = {}
        domainState.availableVariants = {}
        if state.domain == DOMAIN_DAMAGE_CALCULATOR then
            if state.damageCalculator.captureSkillOverrideFromInput then
                state.damageCalculator.captureSkillOverrideFromInput()
            end
            if state.damageCalculator.captureLevelOverrideFromInput then
                state.damageCalculator.captureLevelOverrideFromInput()
            end
            domainState.calculationSkill = nil
            domainState.calculationLevel = nil
        end
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
    if state.domain == DOMAIN_DAILY_REWARDS or state.domain == DOMAIN_BLESSINGS then
        ui.pageLabel:setText(tr('Page 1 / 1'))
        ui.prevPageButton:setEnabled(false)
        ui.nextPageButton:setEnabled(false)
        return
    end

    local domainState = getDomainState()
    local page = math.max(1, tonumber(domainState.page) or 1)
    local totalPages = math.max(1, tonumber(domainState.totalPages) or 1)
    ui.pageLabel:setText(string.format('Page %d / %d', page, totalPages))
    local hasSource = state.domain == DOMAIN_MONSTERS or domainState.activeCategory ~= nil
    ui.prevPageButton:setEnabled(hasSource and page > 1)
    ui.nextPageButton:setEnabled(hasSource and page < totalPages)
end

local function setResultWidgetsEnabled(enabled)
    if state.domain == DOMAIN_DAILY_REWARDS or state.domain == DOMAIN_BLESSINGS then
        ui.searchEdit:setEnabled(false)
        ui.searchClearButton:setEnabled(false)
        ui.prevPageButton:setEnabled(false)
        ui.nextPageButton:setEnabled(false)
        return
    end

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
        return value and tr('Yes') or tr('No')
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
    if meta.weight then
        local numericValue = tonumber(value)
        if numericValue then
            return string.format('%.2f', numericValue / 100)
        end
    end
    if type(value) == 'boolean' then
        return value and tr('Yes') or tr('No')
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

local hiddenVocationFields = {
    attackSpeed = true,
    attack_speed = true,
    allowPvp = true,
    allowPvP = true,
    allowPVP = true,
    allow_pvp = true,
    baseSpeed = true,
    base_speed = true,
    noPongKickTime = true,
    noPongKick = true,
    no_pong_kick_time = true,
    soulGainTicks = true,
    soulTicks = true,
    soul_gain_ticks = true,
    soulMax = true,
    soul_max = true
}

local function removeHiddenVocationFields(values)
    if type(values) ~= 'table' then
        return
    end
    for key in pairs(hiddenVocationFields) do
        values[key] = nil
    end
end

local function formatVocationSkillLearningSpeed(value)
    local multiplier = tonumber(value)
    if not multiplier or multiplier <= 0 then
        return formatValue('', value), VOCATION_FORMULA_NEUTRAL_COLOR
    end

    local speed = 100 + (1.1 - multiplier) * 1000
    local color = VOCATION_FORMULA_NEUTRAL_COLOR
    if speed > 100 then
        color = VOCATION_FORMULA_POSITIVE_COLOR
    elseif speed < 100 then
        color = VOCATION_FORMULA_NEGATIVE_COLOR
    end

    local text
    if math.abs(speed - math.floor(speed + 0.5)) < 0.005 then
        text = string.format('%d%%', math.floor(speed + 0.5))
    else
        text = string.format('%.2f%%', speed)
    end
    return text, color
end

local function formatVocationFormulaMultiplier(value)
    local multiplier = tonumber(value)
    if not multiplier then
        return formatValue('', value), VOCATION_FORMULA_NEUTRAL_COLOR
    end

    local percent = multiplier * 100
    local color = VOCATION_FORMULA_NEUTRAL_COLOR
    if percent > 100 then
        color = VOCATION_FORMULA_POSITIVE_COLOR
    elseif percent < 100 then
        color = VOCATION_FORMULA_NEGATIVE_COLOR
    end

    local text
    if math.abs(percent - math.floor(percent + 0.5)) < 0.005 then
        text = string.format('%d%%', math.floor(percent + 0.5))
    else
        text = string.format('%.2f%%', percent)
    end
    return text, color
end

local function formatRegenValue(amount, ticks)
    if amount == nil or ticks == nil then
        return nil
    end
    return string.format('%s/%ss', tostring(amount), tostring(ticks))
end

local hiddenVocationSkills = {
    agility = true,
    skillAgility = true,
    alchemy = true,
    skillAlchemy = true,
    cooking = true,
    skillCooking = true,
    fishing = true,
    skillFishing = true,
    skillFish = true,
    fist = true,
    skillFist = true,
    hunting = true,
    skillHunting = true,
    mining = true,
    skillMining = true,
    shield = true,
    shielding = true,
    skillShield = true,
    smithing = true,
    smith = true,
    skillSmithing = true,
    skillSmith = true,
    strength = true,
    skillStrength = true
}

local hiddenVocationFormulaFields = {
    weaponSkillMultiplier = true
}

local function removeHiddenVocationSkills(values)
    if type(values) ~= 'table' then
        return
    end
    for key in pairs(hiddenVocationSkills) do
        values[key] = nil
    end
end

local function removeHiddenVocationFormulaFields(values)
    if type(values) ~= 'table' then
        return
    end
    for key in pairs(hiddenVocationFormulaFields) do
        values[key] = nil
    end
end

local function normalizeVocationRegeneration(values)
    if type(values) ~= 'table' then
        return values
    end

    local normalized = {}
    local health = formatRegenValue(values.healthAmount or values.healthGain, values.healthTicks)
    local mana = formatRegenValue(values.manaAmount or values.manaGain, values.manaTicks)
    if health then
        normalized.health = health
    end
    if mana then
        normalized.mana = mana
    end

    return normalized
end

local function normalizeVocationDetailGroups(details)
    if type(details) ~= 'table' or type(details.progression) ~= 'table' then
        return
    end

    details.skills = type(details.skills) == 'table' and details.skills or {}
    details.formula = type(details.formula) == 'table' and details.formula or {}

    if details.progression.magicLevelMultiplier ~= nil then
        details.skills.magicLevelMultiplier = details.progression.magicLevelMultiplier
        details.progression.magicLevelMultiplier = nil
    end
    details.progression.weaponSkillMultiplier = nil

    details.progression = nil
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
    return meta and tr(meta.label) or humanizeKey(key)
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

local function resetDailyRewardSelection()
    local domainState = state.dailyRewards
    domainState.selectedItems = {
        free = {},
        premium = {}
    }
    domainState.rewardWidgets = {
        free = {},
        premium = {}
    }
end

local function getDailyItemKey(item)
    return string.format('%s:%s', tostring(item.itemId or ''), tostring(item.count or 1))
end

local function getDailyPool(status, poolName)
    if type(status) ~= 'table' or type(status.rewards) ~= 'table' then
        return nil
    end
    local pool = status.rewards[poolName]
    if type(pool) ~= 'table' then
        return nil
    end
    return pool
end

local function getDailyPoolItems(pool)
    if type(pool) ~= 'table' or type(pool.items) ~= 'table' then
        return {}
    end
    return pool.items
end

local function getDailyItemsToSelect(pool)
    local value = tonumber(pool and pool.itemsToSelect)
    if not value or value < 1 then
        return 1
    end
    return math.floor(value)
end

local function isDailyChoicePool(pool)
    return type(pool) == 'table' and pool.mode == 'choice'
end

local function isDailyPremiumLocked(status)
    return type(status) == 'table' and status.premium ~= true
end

local function isDailyRewardAvailable(status)
    if type(status) ~= 'table' then
        return false
    end
    return status.available == true or status.available == 1 or status.available == 'true'
end

local function setLibraryButtonNotifyColor(enabled)
    if not libraryButton then
        return
    end
    libraryButton:setImageColor(enabled and DAILY_REWARD_NOTIFY_COLOR or LIBRARY_BUTTON_DEFAULT_COLOR)
end

local function setDailyRewardsTabNotifyColor(enabled)
    if not ui or not ui.dailyRewardsTab then
        return
    end

    local active = state.domain == DOMAIN_DAILY_REWARDS
    ui.dailyRewardsTab:setBackgroundColor(active and DAILY_TAB_ACTIVE_BACKGROUND or DAILY_TAB_DEFAULT_BACKGROUND)
    ui.dailyRewardsTab:setBorderColor(enabled and DAILY_REWARD_NOTIFY_COLOR
        or (active and DAILY_TAB_ACTIVE_BORDER or DAILY_TAB_DEFAULT_BORDER))
end

local function stopDailyRewardNotification()
    local domainState = state.dailyRewards
    removeEvent(domainState.notificationEvent)
    removeEvent(domainState.tabNotificationEvent)
    domainState.notificationEvent = nil
    domainState.tabNotificationEvent = nil
    domainState.notificationBlinkOn = false
    domainState.tabNotificationBlinkOn = false
    domainState.notificationAvailable = false
    setLibraryButtonNotifyColor(false)
    setDailyRewardsTabNotifyColor(false)
end

local function startDailyRewardNotification()
    local domainState = state.dailyRewards
    domainState.notificationAvailable = true

    if domainState.notificationEvent then
        return
    end

    domainState.notificationBlinkOn = false
    domainState.notificationEvent = cycleEvent(function()
        if not libraryButton or not domainState.notificationAvailable then
            stopDailyRewardNotification()
            return
        end
        domainState.notificationBlinkOn = not domainState.notificationBlinkOn
        setLibraryButtonNotifyColor(domainState.notificationBlinkOn)
    end, NOTIFICATION_BLINK_INTERVAL)

    domainState.tabNotificationBlinkOn = false
    domainState.tabNotificationEvent = cycleEvent(function()
        if not ui or not ui.dailyRewardsTab or not domainState.notificationAvailable then
            stopDailyRewardNotification()
            return
        end
        domainState.tabNotificationBlinkOn = not domainState.tabNotificationBlinkOn
        setDailyRewardsTabNotifyColor(domainState.tabNotificationBlinkOn)
    end, NOTIFICATION_BLINK_INTERVAL)
end

local function updateDailyRewardNotification(status)
    if isDailyRewardAvailable(status) then
        startDailyRewardNotification()
    else
        stopDailyRewardNotification()
    end
end

local function getSelectedDailyCount(poolName)
    local count = 0
    local selected = state.dailyRewards.selectedItems[poolName] or {}
    for _, enabled in pairs(selected) do
        if enabled then
            count = count + 1
        end
    end
    return count
end

local function isDailySelectionComplete(status, poolName)
    local pool = getDailyPool(status, poolName)
    if not isDailyChoicePool(pool) then
        return true
    end
    if poolName == 'premium' and isDailyPremiumLocked(status) then
        return true
    end
    return getSelectedDailyCount(poolName) == getDailyItemsToSelect(pool)
end

local function updateDailyClaimButton()
    local status = state.dailyRewards.status
    local available = isDailyRewardAvailable(status)
    local canClaim = available
        and isDailySelectionComplete(status, 'free')
        and isDailySelectionComplete(status, 'premium')

    if type(status) == 'table' and status.claimed == true then
        ui.dailyClaimButton:setText(tr('Claimed'))
        ui.dailyClaimButton:setImageColor(CLAIMED_BUTTON_COLOR)
        ui.dailyClaimButton:setColor('#ffffff')
    else
        ui.dailyClaimButton:setText(tr('Claim'))
        ui.dailyClaimButton:setImageColor(CLAIM_BUTTON_COLOR)
        ui.dailyClaimButton:setColor('#ffffff')
    end

    ui.dailyClaimButton:setEnabled(canClaim)
end

local function makeDailyStatusText(status)
    if type(status) ~= 'table' then
        return tr('Reward is not available.')
    end

    local stateText

    if isDailyRewardAvailable(status) then
        stateText = tr('REWARD IS AVAILABLE')
    elseif status.claimed == true then
        stateText = tr('REWARD CLAIMED TODAY')
    else
        stateText = tr('REWARD IS NOT AVAILABLE')
    end

    return stateText
end

local function makeDailyFooterStatsText(status)
    if type(status) ~= 'table' then
        return ''
    end

    local streak = tonumber(status.streak) or 0
    local cycleDay = tonumber(status.cycleDay) or 1
    return string.format('%s: %d    %s: %d', tr('Streak'), streak, tr('Day'), cycleDay)
end

local function createDailyLabel(parent, text, color)
    local label = g_ui.createWidget('Label', parent)
    label:setText(text or '')
    label:setColor(color or '#BDBDBD')
    label:setTextWrap(true)
    label:setWidth(620)
    label:setHeight(20)
    return label
end

local function createDailyPoolHeader(parent, poolName, pool, locked)
    local header = g_ui.createWidget('UIWidget', parent)
    header:setHeight(34)
    header:setBackgroundColor('#404040')

    local title = g_ui.createWidget('Label', header)
    title:addAnchor(AnchorTop, 'parent', AnchorTop)
    title:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    title:setMarginTop(6)
    title:setMarginLeft(8)
    title:setText(poolName == 'premium' and tr('Premium Rewards') or tr('Free Rewards'))
    title:setColor(locked and '#8A8A8A' or '#D7D7D7')
    title:setTextAutoResize(true)

    local modeText = tr('Bundle')
    if isDailyChoicePool(pool) then
        modeText = string.format('%s %d', tr('Choose'), getDailyItemsToSelect(pool))
    end
    if locked then
        modeText = modeText .. ' - ' .. tr('Locked')
    end

    local subtitle = g_ui.createWidget('Label', header)
    subtitle:addAnchor(AnchorTop, 'parent', AnchorTop)
    subtitle:addAnchor(AnchorRight, 'parent', AnchorRight)
    subtitle:setMarginTop(6)
    subtitle:setMarginRight(8)
    subtitle:setText(modeText)
    subtitle:setColor(locked and '#8A8A8A' or '#BDBDBD')
    subtitle:setTextAutoResize(true)

    return header
end

local function updateDailyPoolCounter(counter, poolName, pool)
    if not counter then
        return
    end
    if not isDailyChoicePool(pool) then
        counter:setText('')
        return
    end
    counter:setText(string.format('%s: %d / %d', tr('Selected'), getSelectedDailyCount(poolName), getDailyItemsToSelect(pool)))
end

local function applyDailyItemSelectionStyle(widget, checked)
    if not widget or widget:isDestroyed() then
        return
    end

    if widget.setChecked then
        widget:setChecked(checked)
    end
    widget:setBackgroundColor(checked and '#4f6244' or '#484848')
    widget:setBorderColor(checked and '#89F013' or '#222222')

end

local function setDailyItemChecked(poolName, itemKey, checked)
    local widgets = state.dailyRewards.rewardWidgets[poolName] or {}
    local widget = widgets[itemKey]
    applyDailyItemSelectionStyle(widget, checked)
end

local function toggleDailyItem(poolName, pool, item, counter)
    local status = state.dailyRewards.status
    if type(status) ~= 'table' or not isDailyRewardAvailable(status) or not isDailyChoicePool(pool) then
        return
    end
    if poolName == 'premium' and isDailyPremiumLocked(status) then
        return
    end

    local itemKey = getDailyItemKey(item)
    local selected = state.dailyRewards.selectedItems[poolName]
    if selected[itemKey] then
        selected[itemKey] = nil
        setDailyItemChecked(poolName, itemKey, false)
    else
        local itemsToSelect = getDailyItemsToSelect(pool)
        if itemsToSelect == 1 then
            for selectedKey in pairs(selected) do
                selected[selectedKey] = nil
                setDailyItemChecked(poolName, selectedKey, false)
            end
        elseif getSelectedDailyCount(poolName) >= itemsToSelect then
            return
        end
        selected[itemKey] = {
            itemId = tonumber(item.itemId) or item.itemId,
            count = tonumber(item.count) or 1
        }
        setDailyItemChecked(poolName, itemKey, true)
    end

    updateDailyPoolCounter(counter, poolName, pool)
    updateDailyClaimButton()
end

local function renderDailyItem(parent, poolName, pool, item, locked, counter)
    local widget = g_ui.createWidget('DailyRewardItem', parent)
    local itemKey = getDailyItemKey(item)
    local sprite = widget:recursiveGetChildById('Sprite')
    local name = widget:recursiveGetChildById('Name')
    local count = tonumber(item.count) or 1
    local itemName = item.name or tr('Unknown item')

    widget.itemKey = itemKey
    applyDailyItemSelectionStyle(widget, false)
    widget:setEnabled(true)
    widget:setOpacity((locked or not isDailyRewardAvailable(state.dailyRewards.status)) and 0.55 or 1.0)

    if sprite then
        sprite:setItemId(tonumber(item.clientId) or 0)
    end
    if name then
        if count > 1 then
            name:setText(string.format('%s x%d', itemName, count))
        else
            name:setText(itemName)
        end
    end
    widget:setTooltip(count > 1 and string.format('%s x%d', itemName, count) or itemName)

    state.dailyRewards.rewardWidgets[poolName][itemKey] = widget

    widget.onClick = function()
        toggleDailyItem(poolName, pool, item, counter)
    end

    return widget
end

local function renderDailyPool(parent, poolName, pool, locked)
    createDailyPoolHeader(parent, poolName, pool, locked)

    local items = getDailyPoolItems(pool)
    if #items == 0 then
        createDailyLabel(parent, tr('Reward is not available.'), '#9A9A9A')
        return
    end

    local counter = createDailyLabel(parent, '', locked and '#8A8A8A' or '#BDBDBD')
    updateDailyPoolCounter(counter, poolName, pool)

    local grid = g_ui.createWidget('DailyRewardGrid', parent)
    grid:setHeight(math.max(1, math.ceil(#items / 4)) * 110)

    for _, item in ipairs(items) do
        renderDailyItem(grid, poolName, pool, item, locked, counter)
    end
end

local function renderDailyRewardsStatus(data)
    local domainState = state.dailyRewards
    domainState.status = data
    domainState.statusRequested = false
    resetDailyRewardSelection()
    updateDailyRewardNotification(data)

    ui.dailyStatusLabel:setText(makeDailyStatusText(data))
    ui.dailyFooterStatsLabel:setText(makeDailyFooterStatsText(data))
    ui.dailyRewardsList:destroyChildren()

    if type(data) ~= 'table' then
        createDailyLabel(ui.dailyRewardsList, tr('Reward is not available.'), '#9A9A9A')
        updateDailyClaimButton()
        return
    end

    renderDailyPool(ui.dailyRewardsList, 'free', getDailyPool(data, 'free') or { mode = 'bundle', items = {} }, false)
    renderDailyPool(ui.dailyRewardsList, 'premium', getDailyPool(data, 'premium') or { mode = 'bundle', items = {} }, isDailyPremiumLocked(data))
    updateDailyClaimButton()
end

local function requestDailyRewardsStatus(force)
    local domainState = state.dailyRewards
    if domainState.statusRequested then
        return
    end
    if domainState.status and not force then
        renderDailyRewardsStatus(domainState.status)
        return
    end
    domainState.statusRequested = true
    ui.dailyStatusLabel:setText(tr('Loading daily rewards...'))
    ui.dailyRewardsList:destroyChildren()
    ui.dailyFooterStatsLabel:setText('')
    ui.dailyClaimButton:setEnabled(false)
    if not sendRequest(DOMAIN_DAILY_REWARDS, 'status') then
        domainState.statusRequested = false
    end
end

local function getBlessingDescription(blessing)
    local locale = modules.client_locales and modules.client_locales.getCurrentLocale
        and modules.client_locales.getCurrentLocale()
    if locale and locale.name == 'pl' and type(blessing.description_pl) == 'string'
        and blessing.description_pl:trim() ~= '' then
        return blessing.description_pl
    end
    return type(blessing.description) == 'string' and blessing.description or ''
end

local function renderBlessingsStatus(data)
    local domainState = state.blessings
    domainState.status = data
    domainState.statusRequested = false
    ui.blessingsList:destroyChildren()

    local blessings = type(data) == 'table' and data.blessings or nil
    if type(blessings) ~= 'table' then
        ui.blessingsStatusLabel:setText(tr('Blessings are not available.'))
        return
    end

    local activeCount = 0
    local renderedCount = 0
    for _, blessing in ipairs(blessings) do
        if type(blessing) == 'table' then
            local key = type(blessing.key) == 'string' and blessing.key:upper() or ''
            local imageSource = BLESSING_IMAGE_BY_KEY[key]
            local active = blessing.active == true
            local item = g_ui.createWidget('LibraryBlessingItem', ui.blessingsList)
            local image = item:recursiveGetChildById('godImage')
            local nameLabel = item:recursiveGetChildById('blessingName')
            local statusLabel = item:recursiveGetChildById('blessingStatus')
            local descriptionLabel = item:recursiveGetChildById('blessingDescription')

            if imageSource then
                image:setImageSource(imageSource)
            end
            image:setOpacity(active and 1 or 0.35)
            nameLabel:setText(type(blessing.name) == 'string' and blessing.name or '')
            descriptionLabel:setText(getBlessingDescription(blessing))
            statusLabel:setText(active and tr('Active') or tr('Inactive'))
            statusLabel:setColor(active and '#6fbf5f' or '#e84a4a')
            item:setBackgroundColor(active and '#4f6244' or '#484848')
            item:setBorderColor(active and '#6f8a5f' or '#222222')

            renderedCount = renderedCount + 1
            if active then
                activeCount = activeCount + 1
            end
        end
    end

    if renderedCount == 0 then
        ui.blessingsStatusLabel:setText(tr('Blessings are not available.'))
        return
    end
    ui.blessingsStatusLabel:setText(string.format('%s: %d / %d', tr('Active blessings'), activeCount, renderedCount))
end

local function requestBlessingsStatus(force)
    local domainState = state.blessings
    if domainState.statusRequested then
        return
    end
    if domainState.status and not force then
        renderBlessingsStatus(domainState.status)
        return
    end

    domainState.statusRequested = true
    ui.blessingsStatusLabel:setText(tr('Loading blessings...'))
    ui.blessingsList:destroyChildren()
    if not sendRequest(DOMAIN_BLESSINGS, 'status') then
        domainState.statusRequested = false
        ui.blessingsStatusLabel:setText(tr('Blessings are not available.'))
    end
end

local function buildDailyClaimPayload()
    local selectedItems = {
        free = {},
        premium = {}
    }

    for poolName, selected in pairs(state.dailyRewards.selectedItems) do
        for _, item in pairs(selected) do
            table.insert(selectedItems[poolName], {
                itemId = item.itemId,
                count = item.count
            })
        end
    end

    return { selectedItems = selectedItems }
end

local function claimDailyReward()
    local status = state.dailyRewards.status
    if type(status) ~= 'table' or not isDailyRewardAvailable(status) then
        return
    end
    if not isDailySelectionComplete(status, 'free') or not isDailySelectionComplete(status, 'premium') then
        return
    end

    ui.dailyClaimButton:setEnabled(false)
    ui.dailyStatusLabel:setText(tr('Claiming daily reward...'))
    sendRequest(DOMAIN_DAILY_REWARDS, 'claim', buildDailyClaimPayload())
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

local function ensureVocationCategoriesRequested()
    local vocationsState = state.vocations
    if vocationsState.categoriesLoaded or vocationsState.categoriesRequested then
        return
    end
    vocationsState.categoriesRequested = true
    sendRequest(DOMAIN_VOCATIONS, 'categories')
end

local function ensureDamageCalculatorCategoriesRequested()
    local calculatorState = state.damageCalculator
    if calculatorState.categoriesLoaded or calculatorState.categoriesRequested then
        return
    end
    calculatorState.categoriesRequested = true
    sendRequest(DOMAIN_DAMAGE_CALCULATOR, 'categories')
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

local function normalizeVariantList(variants)
    local result = {}
    if type(variants) ~= 'table' then
        return result
    end

    local seen = {}
    for _, entry in ipairs(variants) do
        if type(entry) == 'table' and type(entry.key) == 'string' and VARIANT_ORDER[entry.key] and not seen[entry.key] then
            seen[entry.key] = true
            local label = entry.label
            if type(label) ~= 'string' or label == '' then
                label = humanizeKey(entry.key)
            end
            table.insert(result, {
                key = entry.key,
                label = label,
                monsterId = entry.monsterId,
                name = entry.name,
                default = entry.default == true
            })
        end
    end

    table.sort(result, function(a, b)
        return (VARIANT_ORDER[a.key] or 99) < (VARIANT_ORDER[b.key] or 99)
    end)

    return result
end

local function normalizeDetailGroups(details)
    if type(details) ~= 'table' then
        return
    end

    local basic = details.basic
    if type(basic) ~= 'table' then
        return
    end

    if basic.requiredMagicLevel ~= nil then
        basic.requiredMagicLevel = tonumber(basic.requiredMagicLevel) or basic.requiredMagicLevel
    end
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

local function getBestiaryData(entry)
    if type(entry) ~= 'table' or type(entry.bestiary) ~= 'table' then
        return nil
    end
    if entry.bestiary.enabled == false then
        return nil
    end
    return entry.bestiary
end

local function getBestiaryProgressText(bestiary)
    if type(bestiary) ~= 'table' then
        return ''
    end

    local progressKills = tonumber(bestiary.progressKills) or tonumber(bestiary.kills) or 0
    local requiredKills = tonumber(bestiary.requiredKills) or 0
    if requiredKills <= 0 then
        return tr('Bestiary unavailable')
    end

    return string.format('%d/%d', math.min(progressKills, requiredKills), requiredKills)
end

local function getBestiaryStatusText(bestiary)
    if type(bestiary) ~= 'table' then
        return tr('Unavailable')
    end
    if bestiary.claimed == true then
        return tr('Reward claimed')
    elseif bestiary.claimable == true then
        return tr('Reward available')
    elseif bestiary.completed == true then
        return tr('Completed')
    end
    return tr('In progress')
end

local function getBestiaryTotalPoints(data)
    if type(data) ~= 'table' then
        return nil
    end
    local totalPoints = tonumber(data.totalBestiaryPoints)
    if totalPoints then
        return totalPoints
    end
    if type(data.bestiary) == 'table' then
        return tonumber(data.bestiary.totalPoints)
    end
    return nil
end

local function updateBestiaryPoints(points)
    local numericPoints = tonumber(points)
    if not numericPoints then
        return
    end
    state.monsters.totalBestiaryPoints = numericPoints
    if ui and ui.bestiaryFooterStatsLabel and state.domain == DOMAIN_MONSTERS then
        ui.bestiaryFooterStatsLabel:setText(string.format('%s: %d', tr('Bestiary points'), numericPoints))
        ui.bestiaryFooterStatsLabel:setVisible(true)
    end
end

local function updateBestiaryFooterVisibility()
    if not ui or not ui.bestiaryFooterStatsLabel then
        return
    end

    local points = tonumber(state.monsters.totalBestiaryPoints)
    local visible = state.domain == DOMAIN_MONSTERS and points ~= nil
    ui.bestiaryFooterStatsLabel:setVisible(visible)
    if visible then
        ui.bestiaryFooterStatsLabel:setText(string.format('%s: %d', tr('Bestiary points'), points))
    end
end

local function updateCachedMonsterBestiary(monsterId, bestiary)
    if not monsterId or type(bestiary) ~= 'table' then
        return
    end

    local domainState = state.monsters
    for _, pageData in pairs(domainState.pageCache) do
        if type(pageData) == 'table' and type(pageData.items) == 'table' then
            for _, entry in ipairs(pageData.items) do
                if type(entry) == 'table' and (entry.monsterId == monsterId or entry.id == monsterId) then
                    entry.bestiary = copyTable(bestiary)
                end
            end
        end
    end

    for _, detail in pairs(domainState.detailCache) do
        if type(detail) == 'table' and (detail.monsterId == monsterId or detail.id == monsterId) then
            detail.bestiary = copyTable(bestiary)
        end
    end
end

local function applyBestiaryProgressToRow(row, bestiary)
    if type(bestiary) ~= 'table' or not row or row:isDestroyed() then
        return
    end

    local progressLabel = row:recursiveGetChildById('BestiaryProgress')
    if not progressLabel then
        return
    end

    progressLabel:setText(getBestiaryProgressText(bestiary))
    progressLabel:setVisible(true)
    local progressKills = tonumber(bestiary.progressKills) or tonumber(bestiary.kills) or 0
    local requiredKills = tonumber(bestiary.requiredKills) or 0
    if bestiary.completed == true or (requiredKills > 0 and progressKills >= requiredKills) then
        progressLabel:setColor(CLAIM_BUTTON_COLOR)
    else
        progressLabel:setColor('#ff8a8a')
    end
end

local function updateVisibleMonsterBestiaryRow(monsterId, bestiary)
    if not monsterId or type(bestiary) ~= 'table' or not ui or not ui.monsterList then
        return
    end

    for _, row in ipairs(ui.monsterList:getChildren()) do
        if row.monsterId == monsterId then
            applyBestiaryProgressToRow(row, bestiary)
        end
    end
end

local function updateMonsterRowBackground(row)
    if not row or row:isDestroyed() or not row.monsterBaseColor then
        return
    end

    if row:isChecked() then
        row:setBackgroundColor(MONSTER_ROW_SELECTED_COLOR)
    elseif row.monsterHovered then
        row:setBackgroundColor(MONSTER_ROW_HOVER_COLOR)
    else
        row:setBackgroundColor(row.monsterBaseColor)
    end
end

local function requestDetail(entryId, selector)
    if not entryId then
        return
    end

    local domainState = getDomainState()
    local cacheKey
    local payload
    if state.domain == DOMAIN_MONSTERS then
        local variant = type(selector) == 'string' and selector ~= '' and selector or nil
        domainState.selectedId = entryId
        domainState.selectedDetailMonsterId = nil
        domainState.selectedVariant = variant
        cacheKey = makeDetailCacheKey(state.domain, entryId, variant or '')
        payload = { monsterId = entryId }
        if variant then
            payload.variant = variant
        end
    elseif state.domain == DOMAIN_VOCATIONS then
        domainState.selectedId = entryId
        cacheKey = makeDetailCacheKey(state.domain, entryId, 1)
        payload = { vocationId = entryId }
    else
        local numericTier = tonumber(selector) or 1
        domainState.selectedId = entryId
        domainState.selectedTier = numericTier
        cacheKey = makeDetailCacheKey(state.domain, entryId, numericTier)
        payload = { wareId = entryId, tier = numericTier }
        if state.domain == DOMAIN_DAMAGE_CALCULATOR and domainState.skillOverride ~= nil then
            payload.skillOverride = domainState.skillOverride
        end
        if state.domain == DOMAIN_DAMAGE_CALCULATOR and domainState.levelOverride ~= nil then
            payload.levelOverride = domainState.levelOverride
        end
    end

    local cached = state.domain ~= DOMAIN_DAMAGE_CALCULATOR and domainState.detailCache[cacheKey] or nil
    if cached then
        showDetail(cached)
        return
    end

    resetDetailPanel(getDetailLoadingText(state.domain), false)
    sendRequest(state.domain, 'detail', payload)
end

local function renderTierTabs(currentTier, availableTiers)
    ui.tierTabs:destroyChildren()

    if (state.domain ~= DOMAIN_ITEMS and state.domain ~= DOMAIN_DAMAGE_CALCULATOR) or #availableTiers <= 1 then
        ui.tierTabsPanel:hide()
        return
    end

    for _, tier in ipairs(availableTiers) do
        local button = g_ui.createWidget('LibraryTierButton', ui.tierTabs)
        button.tierValue = tier
        local label = state.domain == DOMAIN_DAMAGE_CALCULATOR and isDamageCalculatorRuneCategory() and state.damageCalculator.runeTierNames[tier] or tierNames[tier]
        button:setText(label or ('Tier ' .. tier))
        button:setChecked(tier == currentTier)
        button.onClick = function(widget)
            local domainState = getDomainState()
            if widget.tierValue == domainState.selectedTier then
                return
            end
            if state.domain == DOMAIN_DAMAGE_CALCULATOR and state.damageCalculator.captureSkillOverrideFromInput then
                state.damageCalculator.captureSkillOverrideFromInput()
            end
            if state.domain == DOMAIN_DAMAGE_CALCULATOR and state.damageCalculator.captureLevelOverrideFromInput then
                state.damageCalculator.captureLevelOverrideFromInput()
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

local function renderVariantTabs(currentVariant, availableVariants)
    ui.tierTabs:destroyChildren()

    if state.domain ~= DOMAIN_MONSTERS or type(availableVariants) ~= 'table' or #availableVariants <= 1 then
        ui.tierTabsPanel:hide()
        return
    end

    for _, variant in ipairs(availableVariants) do
        local button = g_ui.createWidget('LibraryTierButton', ui.tierTabs)
        button.variantValue = variant.key
        button:setText(variant.label)
        button:setChecked(variant.key == currentVariant)
        button.onClick = function(widget)
            local domainState = getDomainState()
            if widget.variantValue == domainState.selectedVariant then
                return
            end
            requestDetail(domainState.selectedId, widget.variantValue)
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

local function claimBestiaryReward()
    local domainState = state.monsters
    local monsterId = domainState.selectedDetailMonsterId or domainState.selectedId
    if not monsterId then
        return
    end

    sendRequest(DOMAIN_MONSTERS, 'claim', { monsterId = monsterId })
end

local function renderBestiaryDetails(data)
    if state.domain ~= DOMAIN_MONSTERS then
        return
    end

    local bestiary = getBestiaryData(data)
    if not bestiary then
        return
    end

    local list = ui.detailList
    local heading = g_ui.createWidget('LibrarySectionLabel', list)
    heading:setText(tr('Bestiary') .. ':')

    local progressKills = tonumber(bestiary.progressKills) or tonumber(bestiary.kills) or 0
    local requiredKills = tonumber(bestiary.requiredKills) or 0
    local rows = {
        { label = tr('Progress'), value = string.format('%d/%d', math.min(progressKills, requiredKills), requiredKills) },
        { label = tr('Kills'), value = tostring(tonumber(bestiary.kills) or 0) },
        { label = tr('Reward points'), value = tostring(tonumber(bestiary.rewardPoints) or 0) },
        { label = tr('Status'), value = getBestiaryStatusText(bestiary) }
    }

    for _, entry in ipairs(rows) do
        local row = g_ui.createWidget('ItemBasicDetail', list)
        local background = row:getChildById('background')
        local nameLabel = background and background:getChildById('name')
        local valueLabel = background and background:getChildById('value')
        if nameLabel then
            nameLabel:setText(entry.label)
        end
        if valueLabel then
            valueLabel:setText(entry.value)
            valueLabel:setColor('#BDBDBD')
        end
    end

    local rewardButton = g_ui.createWidget('Button', list)
    local rewardPoints = tonumber(bestiary.rewardPoints) or 0
    rewardButton:setHeight(22)
    rewardButton:setWidth(180)
    rewardButton:setColor('#ffffff')
    rewardButton:setMarginTop(4)

    if bestiary.claimed == true then
        rewardButton:setText(tr('Reward claimed'))
        rewardButton:setImageColor(CLAIMED_BUTTON_COLOR)
        rewardButton:setEnabled(false)
    elseif bestiary.claimable == true then
        rewardButton:setText(string.format('%s (+%d)', tr('Claim reward'), rewardPoints))
        rewardButton:setImageColor(CLAIM_BUTTON_COLOR)
        rewardButton:setEnabled(true)
        rewardButton.onClick = claimBestiaryReward
    elseif bestiary.completed == true then
        rewardButton:setText(tr('Reward available'))
        rewardButton:setImageColor(CLAIM_BUTTON_COLOR)
        rewardButton:setEnabled(false)
    else
        rewardButton:setText(tr('Reward locked'))
        rewardButton:setImageColor(CLAIMED_BUTTON_COLOR)
        rewardButton:setEnabled(false)
    end
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
                    heading:setText(tr(group.label) .. ':')

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
                    heading:setText(tr(group.label) .. ':')

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
            elseif group.key == 'summons' then
                local entries = type(values.entries) == 'table' and values.entries or {}
                local visibleSummons = {}
                for _, entry in ipairs(entries) do
                    if type(entry) == 'table' and type(entry.name) == 'string' and entry.name:trim() ~= '' then
                        table.insert(visibleSummons, entry)
                    end
                end

                if #visibleSummons > 0 then
                    local heading = g_ui.createWidget('LibrarySectionLabel', list)
                    local maxSummons = tonumber(values.maxSummons)
                    if maxSummons and maxSummons > 0 then
                        heading:setText(string.format('%s (%s: %d):', tr(group.label), tr('Max'), maxSummons))
                    else
                        heading:setText(tr(group.label) .. ':')
                    end

                    g_ui.createWidget('LibrarySummonTableHeader', list)

                    for _, entry in ipairs(visibleSummons) do
                        local row = g_ui.createWidget('LibrarySummonTableRow', list)
                        local nameLabel = row:getChildById('name')
                        local chanceLabel = row:getChildById('chance')
                        local intervalLabel = row:getChildById('interval')

                        local name = tostring(entry.name)
                        local lineCount = select(2, name:gsub('\n', '\n')) + 1
                        local requiresTallRow = #name > 18 or lineCount > 1
                        row:setHeight(requiresTallRow and math.max(24, lineCount * 14) or 20)

                        if nameLabel then
                            nameLabel:setText(name)
                            nameLabel:setTextWrap(requiresTallRow)
                        end
                        if chanceLabel then
                            local chance = entry.chance ~= nil and tostring(entry.chance) or ''
                            chanceLabel:setText(chance ~= '' and chance or '-')
                        end
                        if intervalLabel then
                            local interval = entry.interval ~= nil and tostring(entry.interval) or ''
                            intervalLabel:setText(interval ~= '' and interval or '-')
                        end
                    end
                end
            else
            local displayValues = copyTable(values)
            if state.domain == DOMAIN_VOCATIONS then
                removeHiddenVocationFields(displayValues)
                if group.key == 'skills' then
                    removeHiddenVocationSkills(displayValues)
                elseif group.key == 'formula' then
                    removeHiddenVocationFormulaFields(displayValues)
                elseif group.key == 'regeneration' then
                    displayValues = normalizeVocationRegeneration(displayValues)
                end
            end

            if group.key == 'basic' then
                displayValues.range = nil
                if (tonumber(displayValues.requiredStrength) or 0) <= 0 then
                    displayValues.requiredStrength = nil
                end
                if (tonumber(displayValues.requiredAgility) or 0) <= 0 then
                    displayValues.requiredAgility = nil
                end
            elseif group.key == 'combat' and not shouldShowRange(state.domain) then
                displayValues.range = nil
            end

            if next(displayValues) ~= nil then
                local heading = g_ui.createWidget('LibrarySectionLabel', list)
                heading:setText(tr(group.label) .. ':')

                for _, entry in ipairs(getOrderedGroupEntries(group.key, displayValues)) do
                    local key = entry.key
                    local value = entry.value
                    local row = g_ui.createWidget('ItemBasicDetail', list)
                    local background = row:getChildById('background')
                    local nameLabel = background and background:getChildById('name')
                    local valueLabel = background and background:getChildById('value')
                    local textValue
                    local valueColor
                    if state.domain == DOMAIN_VOCATIONS and group.key == 'skills' then
                        textValue, valueColor = formatVocationSkillLearningSpeed(value)
                    elseif state.domain == DOMAIN_VOCATIONS and group.key == 'formula' then
                        textValue, valueColor = formatVocationFormulaMultiplier(value)
                    else
                        textValue = formatValue(key, value)
                    end
                    local lineCount = select(2, textValue:gsub('\n', '\n')) + 1
                    local requiresTallRow = (type(value) == 'string' and #value > 40) or lineCount > 1
                    row:setHeight(requiresTallRow and math.max(34, lineCount * 14) or 20)
                    if nameLabel then
                        nameLabel:setText(getFieldLabel(key))
                    end
                    if valueLabel then
                        valueLabel:setText(textValue)
                        valueLabel:setColor(valueColor or '#BDBDBD')
                        valueLabel:setTextWrap(type(value) == 'string' or lineCount > 1)
                    end
                end
            end
            end
        end
    end
end

local function calculatorValueText(value)
    if value == true then
        return tr('Yes')
    elseif value == false then
        return tr('No')
    elseif value == nil then
        return '-'
    end
    return tostring(value)
end

local function calculatorRangeText(range)
    if type(range) ~= 'table' then
        return '-'
    end
    local minimum = range.min
    local maximum = range.max
    if minimum == nil and maximum == nil then
        return '-'
    end
    minimum = minimum ~= nil and minimum or maximum
    maximum = maximum ~= nil and maximum or minimum
    return string.format('%s - %s', calculatorValueText(minimum), calculatorValueText(maximum))
end

local function addCalculatorDetailRow(label, value, color)
    local row = g_ui.createWidget('ItemBasicDetail', ui.detailList)
    local background = row:getChildById('background')
    local nameLabel = background and background:getChildById('name')
    local valueLabel = background and background:getChildById('value')
    if nameLabel then
        nameLabel:setText(label)
    end
    if valueLabel then
        local textValue = calculatorValueText(value)
        local lineCount = select(2, textValue:gsub('\n', '\n')) + 1
        local requiresTallRow = #textValue > 40 or lineCount > 1
        row:setHeight(requiresTallRow and math.max(34, lineCount * 14, math.ceil(#textValue / 42) * 14) or 20)
        valueLabel:setText(textValue)
        valueLabel:setColor(color or '#BDBDBD')
        valueLabel:setTextWrap(requiresTallRow)
    end
end

local function addCalculatorSection(title)
    local heading = g_ui.createWidget('LibrarySectionLabel', ui.detailList)
    heading:setText(title .. ':')
end

local function collectCalculatorSnapshotRows(value, prefix, rows, depth)
    if type(value) ~= 'table' then
        table.insert(rows, { label = prefix, value = value })
        return
    end
    if depth >= 5 then
        table.insert(rows, { label = prefix, value = tr('Nested data') })
        return
    end
    local keys = {}
    for key in pairs(value) do
        table.insert(keys, key)
    end
    table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
    for _, key in ipairs(keys) do
        local label = prefix ~= '' and (prefix .. ' / ' .. humanizeKey(key)) or humanizeKey(key)
        collectCalculatorSnapshotRows(value[key], label, rows, depth + 1)
    end
end

local function getCalculatorRequirementsSummary(requirements)
    if type(requirements) ~= 'table' then
        return nil, true
    end

    local parts = {}
    local allMet = true
    local function addRequirement(requirement, fallbackKey)
        if type(requirement) ~= 'table' then
            return
        end
        local label = requirement.label or requirement.name or requirement.type or fallbackKey or tr('Requirement')
        local required = requirement.required
        if required == nil then
            required = requirement.value ~= nil and requirement.value or requirement.minimum
        end
        local current = requirement.current ~= nil and requirement.current or requirement.actual
        local text = humanizeKey(label)
        if current ~= nil and required ~= nil then
            text = string.format('%s %s/%s', text, calculatorValueText(current), calculatorValueText(required))
        elseif required ~= nil then
            text = string.format('%s %s', text, calculatorValueText(required))
        end
        local met = requirement.met ~= false
        allMet = allMet and met
        table.insert(parts, (met and '[OK] ' or '[X] ') .. text)
    end

    if requirements.met ~= nil and (requirements.required ~= nil or requirements.value ~= nil or requirements.minimum ~= nil or requirements.type ~= nil or requirements.name ~= nil) then
        addRequirement(requirements)
    elseif #requirements > 0 then
        for _, requirement in ipairs(requirements) do
            addRequirement(requirement)
        end
    else
        local keys = {}
        for key in pairs(requirements) do
            table.insert(keys, key)
        end
        table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
        for _, key in ipairs(keys) do
            addRequirement(requirements[key], key)
        end
    end

    return #parts > 0 and table.concat(parts, '\n') or nil, allMet
end

local function getCalculatorDamageValue(entry)
    if type(entry) ~= 'table' then
        return {}
    end
    return type(entry.damage) == 'table' and entry.damage or type(entry.result) == 'table' and entry.result or entry
end

local function getCalculatorCriticalRange(damage)
    local critical = damage.critical or damage.crit or damage.criticalPerHit or damage.criticalRange
    if type(critical) == 'table' and type(critical.perHit) == 'table' then
        return critical.perHit
    end
    return critical
end

local function addCalculatorDamageRow(entry, fallbackName, hideRequirements)
    local damage = getCalculatorDamageValue(entry)
    local row = g_ui.createWidget('LibraryDamageTableRow', ui.detailList)
    local name = entry.name or entry.label or damage.name or fallbackName or tr('Damage')
    local element = damage.element or damage.elementType or damage.damageType or entry.element or entry.elementType or '-'
    if type(element) == 'number' then
        element = elementNames[element] or tostring(element)
    else
        element = humanizeKey(element)
    end

    local perHit = damage.perHit
    if type(perHit) ~= 'table' and (damage.min ~= nil or damage.max ~= nil) then
        perHit = { min = damage.min, max = damage.max }
    end
    local total = damage.total
    local hits = tonumber(damage.hits or damage.hitCount)
    local totalText = calculatorRangeText(total)
    if hits then
        totalText = string.format('%s (%dx)', totalText, hits)
    end

    local values = {
        name = name,
        element = element,
        min = type(perHit) == 'table' and calculatorValueText(perHit.min ~= nil and perHit.min or perHit.max) or '-',
        max = type(perHit) == 'table' and calculatorValueText(perHit.max ~= nil and perHit.max or perHit.min) or '-',
        total = totalText,
        critical = calculatorRangeText(getCalculatorCriticalRange(damage))
    }
    for id, value in pairs(values) do
        local label = row:getChildById(id)
        if label then
            label:setText(value)
        end
    end

    if not hideRequirements then
        local requirements = entry.requirements or damage.requirements
        local summary, met = getCalculatorRequirementsSummary(requirements)
        if summary then
            addCalculatorDetailRow(string.format('%s %s', name, tr('requirements')), summary, met and '#6fbf5f' or '#e84a4a')
        end
    end
    local critical = damage.critical or damage.crit
    local criticalTotal = type(critical) == 'table' and critical.total or damage.criticalTotal
    if type(criticalTotal) == 'table' then
        addCalculatorDetailRow(string.format('%s %s', name, tr('critical total')), calculatorRangeText(criticalTotal), '#E6B85C')
    end
end

local function addCalculatorDamageTable(title, entries, fallbackName, hideRequirements)
    if type(entries) ~= 'table' then
        return
    end

    local normalized = {}
    local function appendEntry(entry, inheritedName)
        if type(entry) ~= 'table' then
            return
        end
        local nested = entry.results or entry.damages
        if type(entry.damage) == 'table' and #entry.damage > 0 then
            nested = entry.damage
        end
        if type(nested) == 'table' and #nested > 0 then
            for _, child in ipairs(nested) do
                if type(child) == 'table' then
                    local copy = copyTable(child)
                    copy.name = copy.name or entry.name or inheritedName
                    copy.requirements = copy.requirements or entry.requirements
                    appendEntry(copy, copy.name)
                end
            end
            return
        end
        if not entry.name and inheritedName then
            local copy = copyTable(entry)
            copy.name = inheritedName
            entry = copy
        end
        table.insert(normalized, entry)
    end

    if entries.perHit or entries.min ~= nil or entries.max ~= nil or entries.damage or entries.result then
        appendEntry(entries, fallbackName)
    elseif #entries > 0 then
        for _, entry in ipairs(entries) do
            appendEntry(entry, fallbackName)
        end
    else
        local keys = {}
        for key, entry in pairs(entries) do
            if type(entry) == 'table' then
                table.insert(keys, key)
            end
        end
        table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
        for _, key in ipairs(keys) do
            appendEntry(entries[key], humanizeKey(key))
        end
    end

    if #normalized == 0 then
        return
    end
    addCalculatorSection(title)
    g_ui.createWidget('LibraryDamageTableHeader', ui.detailList)
    for _, entry in ipairs(normalized) do
        addCalculatorDamageRow(entry, fallbackName, hideRequirements)
    end
end

local function setDamageSkillEditValue(value)
    if not ui or not ui.damageSkillEdit then
        return
    end
    local calculatorState = state.damageCalculator
    calculatorState.skillEditUpdating = true
    ui.damageSkillEdit:setText(value ~= nil and tostring(value) or '')
    calculatorState.skillEditUpdating = false
end

local function renderCalculationSkill(calculationSkill)
    local calculatorState = state.damageCalculator
    calculatorState.calculationSkill = type(calculationSkill) == 'table' and calculationSkill or nil
    if not calculatorState.calculationSkill then
        cancelDamageSkillOverrideEvent()
        hideDamageSkillPanel()
        return
    end

    local skill = calculatorState.calculationSkill
    local current = tonumber(skill.current or skill.currentValue or skill.playerValue) or 0
    local used = tonumber(skill.used or skill.usedValue or skill.value) or current
    local minimum = tonumber(skill.min) or 0
    local maximum = tonumber(skill.max) or 300
    local skillType = skill.type or skill.skillType or tr('Weapon skill')
    calculatorState.skillOverride = skill.overridden == true and used or nil

    local status = skill.overridden == true and ('  |  ' .. tr('Simulated')) or ''
    ui.damageActualSkillLabel:setText(string.format('%s: %d%s', humanizeKey(skillType), current, status))
    ui.damageActualSkillLabel:setColor('#BDBDBD')
    ui.damageSkillEdit:setValidCharacters('0123456789')
    ui.damageSkillEdit.skillMinimum = minimum
    ui.damageSkillEdit.skillMaximum = maximum
    setDamageSkillEditValue(used)
    ui.damageSkillPanel:setHeight(42)
    ui.damageSkillPanel:show()
end

state.damageCalculator.captureSkillOverrideFromInput = function()
    local calculatorState = state.damageCalculator
    cancelDamageSkillOverrideEvent()
    if not calculatorState.calculationSkill then
        return false
    end

    local text = ui.damageSkillEdit:getText() or ''
    local override = tonumber(text)
    local current = tonumber(calculatorState.calculationSkill.current or calculatorState.calculationSkill.currentValue or calculatorState.calculationSkill.playerValue) or 0
    if override == nil then
        if text:trim() ~= '' then
            setDamageSkillEditValue(calculatorState.skillOverride or current)
            return false
        end
    else
        override = math.floor(override)
        local minimum = tonumber(calculatorState.calculationSkill.min) or 0
        local maximum = tonumber(calculatorState.calculationSkill.max) or 300
        override = math.max(minimum, math.min(maximum, override))
        if override == current then
            override = nil
        end
    end

    local changed = override ~= calculatorState.skillOverride
    calculatorState.skillOverride = override
    setDamageSkillEditValue(override or current)
    return changed
end

local function applyDamageSkillOverrideFromInput()
    local calculatorState = state.damageCalculator
    if state.domain ~= DOMAIN_DAMAGE_CALCULATOR or not calculatorState.selectedId or not calculatorState.calculationSkill then
        cancelDamageSkillOverrideEvent()
        return
    end
    if state.damageCalculator.captureSkillOverrideFromInput() then
        requestDetail(calculatorState.selectedId, calculatorState.selectedTier)
    end
end

local function queueDamageSkillOverride()
    local calculatorState = state.damageCalculator
    if calculatorState.skillEditUpdating or not calculatorState.calculationSkill then
        return
    end
    cancelDamageSkillOverrideEvent()
    calculatorState.skillOverrideEvent = scheduleEvent(function()
        calculatorState.skillOverrideEvent = nil
        applyDamageSkillOverrideFromInput()
    end, 250)
end

state.damageCalculator.setLevelEditValue = function(value)
    if not ui or not ui.damageLevelEdit then
        return
    end
    local calculatorState = state.damageCalculator
    calculatorState.levelEditUpdating = true
    ui.damageLevelEdit:setText(value ~= nil and tostring(value) or '')
    calculatorState.levelEditUpdating = false
end

state.damageCalculator.renderCalculationLevel = function(calculationLevel)
    local calculatorState = state.damageCalculator
    calculatorState.calculationLevel = type(calculationLevel) == 'table' and calculationLevel or nil
    if not calculatorState.calculationLevel then
        state.damageCalculator.cancelLevelOverrideEvent()
        state.damageCalculator.hideLevelPanel()
        return
    end

    local level = calculatorState.calculationLevel
    local current = tonumber(level.current or level.currentValue or level.playerValue) or 1
    local used = tonumber(level.used or level.usedValue or level.value) or current
    local minimum = tonumber(level.min) or 1
    local maximum = tonumber(level.max) or 500
    calculatorState.levelOverride = level.overridden == true and used or nil

    local status = level.overridden == true and ('  |  ' .. tr('Simulated')) or ''
    ui.damageActualLevelLabel:setText(string.format('%s: %d%s', tr('Level'), current, status))
    ui.damageActualLevelLabel:setColor('#BDBDBD')
    ui.damageLevelEdit:setValidCharacters('0123456789')
    ui.damageLevelEdit.levelMinimum = minimum
    ui.damageLevelEdit.levelMaximum = maximum
    state.damageCalculator.setLevelEditValue(used)
    ui.damageLevelPanel:setHeight(42)
    ui.damageLevelPanel:show()
end

state.damageCalculator.captureLevelOverrideFromInput = function()
    local calculatorState = state.damageCalculator
    state.damageCalculator.cancelLevelOverrideEvent()
    if not calculatorState.calculationLevel then
        return false
    end

    local text = ui.damageLevelEdit:getText() or ''
    local override = tonumber(text)
    local current = tonumber(calculatorState.calculationLevel.current or calculatorState.calculationLevel.currentValue or calculatorState.calculationLevel.playerValue) or 1
    if override == nil then
        if text:trim() ~= '' then
            state.damageCalculator.setLevelEditValue(calculatorState.levelOverride or current)
            return false
        end
    else
        override = math.floor(override)
        local minimum = tonumber(calculatorState.calculationLevel.min) or 1
        local maximum = tonumber(calculatorState.calculationLevel.max) or 500
        override = math.max(minimum, math.min(maximum, override))
        if override == current then
            override = nil
        end
    end

    local changed = override ~= calculatorState.levelOverride
    calculatorState.levelOverride = override
    state.damageCalculator.setLevelEditValue(override or current)
    return changed
end

state.damageCalculator.applyLevelOverrideFromInput = function()
    local calculatorState = state.damageCalculator
    if state.domain ~= DOMAIN_DAMAGE_CALCULATOR or not calculatorState.selectedId or not calculatorState.calculationLevel then
        state.damageCalculator.cancelLevelOverrideEvent()
        return
    end
    if state.damageCalculator.captureLevelOverrideFromInput() then
        requestDetail(calculatorState.selectedId, calculatorState.selectedTier)
    end
end

state.damageCalculator.queueLevelOverride = function()
    local calculatorState = state.damageCalculator
    if calculatorState.levelEditUpdating or not calculatorState.calculationLevel then
        return
    end
    state.damageCalculator.cancelLevelOverrideEvent()
    calculatorState.levelOverrideEvent = scheduleEvent(function()
        calculatorState.levelOverrideEvent = nil
        state.damageCalculator.applyLevelOverrideFromInput()
    end, 250)
end

local function renderDamageCalculatorDetail(data)
    local domainState = state.damageCalculator
    local selectedItem = type(data.selectedItem) == 'table' and data.selectedItem or type(data.item) == 'table' and data.item or data
    domainState.selectedId = tonumber(data.baseWareId or selectedItem.baseWareId) or domainState.selectedId or tonumber(data.wareId or selectedItem.wareId or selectedItem.id)
    domainState.selectedTier = tonumber(data.tier or selectedItem.tier) or domainState.selectedTier or 1
    domainState.availableTiers = normalizeTierList(data.availableTiers or selectedItem.availableTiers)
    if #domainState.availableTiers == 0 then
        domainState.availableTiers = { domainState.selectedTier }
    end

    ui.detailPlaceholder:hide()
    ui.detailContent:show()
    resetDetailCreature()
    ui.selectedItem:show()
    local clientId = tonumber(selectedItem.clientId or selectedItem.itemClientId or selectedItem.itemId or data.clientId or data.itemClientId or data.itemId)
    if clientId and clientId > 0 then
        domainState.selectedClientId = clientId
    end
    ui.itemSprite:setItemId(domainState.selectedClientId or 0)
    state.damageCalculator.updateTierFrame(domainState.selectedTier)
    local itemName = selectedItem.baseName or data.baseName or selectedItem.name or data.name or domainState.selectedName or tr('Damage Calculator')
    domainState.selectedName = itemName
    ui.itemName:setText(itemName)
    ui.detailList:destroyChildren()
    renderTierTabs(domainState.selectedTier, domainState.availableTiers)
    renderCalculationSkill(data.calculationSkill)
    state.damageCalculator.renderCalculationLevel(data.calculationLevel)

    local requirementSummary, requirementsMet = getCalculatorRequirementsSummary(data.requirements or selectedItem.requirements)
    if requirementSummary then
        addCalculatorSection(tr('Item requirements'))
        addCalculatorDetailRow(tr('Status'), requirementSummary, requirementsMet and '#6fbf5f' or '#e84a4a')
    end

    addCalculatorDamageTable(tr('Basic attack'), data.basicAttack, tr('Basic attack'))
    addCalculatorDamageTable(tr('Ammunition'), data.ammunition, tr('Ammunition'))
    addCalculatorDamageTable(tr('Spells'), data.spells, tr('Spell'))
    addCalculatorDamageTable(tr('Runes'), data.runes or data.rune or data.runeDamage or data.magicRunes or data.magicRune, tr('Rune'), true)
    addCalculatorDamageTable(tr('Damage'), data.damageResults or data.results or data.damages or data.damage, tr('Damage'))

    if #ui.detailList:getChildren() == 0 then
        addCalculatorDetailRow(tr('Result'), tr('No damage data available.'))
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

    if domain == DOMAIN_DAMAGE_CALCULATOR then
        renderDamageCalculatorDetail(data)
        return
    end
    state.damageCalculator.updateTierFrame(nil)

    local domainState = getDomainState(domain)
    if domain == DOMAIN_MONSTERS then
        domainState.selectedDetailMonsterId = data.monsterId or data.id or domainState.selectedId
        if type(data.bossVariant) == 'string' and data.bossVariant ~= '' then
            domainState.selectedVariant = data.bossVariant
        end
        domainState.availableVariants = normalizeVariantList(data.availableVariants)
        domainState.availableTiers = {}
    elseif domain == DOMAIN_VOCATIONS then
        domainState.selectedId = tonumber(data.vocationId) or tonumber(data.id) or domainState.selectedId
        domainState.availableTiers = {}
        domainState.availableVariants = {}
    else
        domainState.selectedId = tonumber(data.wareId) or domainState.selectedId
        domainState.selectedTier = tonumber(data.tier) or 1
        domainState.availableTiers = normalizeTierList(data.availableTiers)
        domainState.availableVariants = {}
    end
    ui.detailPlaceholder:hide()
    ui.detailContent:show()
    ui.itemName:setText(data.name or (domain == DOMAIN_MONSTERS and tr('Monster') or domain == DOMAIN_VOCATIONS and tr('Vocation') or tr('Item')))

    local details = copyTable(data.details or {})
    details.__description = data.description
    if domain == DOMAIN_VOCATIONS then
        normalizeVocationDetailGroups(details)
    end
    normalizeDetailGroups(details)

    if domain == DOMAIN_MONSTERS then
        ui.selectedItem:setVisible(false)
        ui.itemSprite:setItemId(0)
        local visible = applyMonsterPreview(ui.detailContent, data.raceId, data.outfit)
        if not visible then
            resetDetailCreature()
        end
    elseif domain == DOMAIN_VOCATIONS then
        resetDetailCreature()
        ui.selectedItem:setVisible(false)
        ui.itemSprite:setItemId(0)
    else
        resetDetailCreature()
        ui.selectedItem:setVisible(true)
        ui.itemSprite:setItemId(tonumber(data.clientId) or 0)
    end

    if domain == DOMAIN_MONSTERS then
        renderVariantTabs(domainState.selectedVariant, domainState.availableVariants)
    elseif domain == DOMAIN_VOCATIONS then
        ui.tierTabsPanel:hide()
        ui.tierTabs:destroyChildren()
    else
        renderTierTabs(domainState.selectedTier, domainState.availableTiers)
    end
    renderDetailGroups(details)
    renderBestiaryDetails(data)
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
        updateMonsterRowBackground(domainState.selectedResult)
    end

    domainState.selectedResult = widget
    widget:setChecked(true)
    updateMonsterRowBackground(widget)
    if state.domain == DOMAIN_MONSTERS then
        domainState.selectedId = entry.monsterId or entry.id
        local variant = type(entry.bossVariant) == 'string' and entry.bossVariant ~= '' and entry.bossVariant or nil
        domainState.selectedVariant = variant
        requestDetail(domainState.selectedId, variant)
    elseif state.domain == DOMAIN_VOCATIONS then
        domainState.selectedId = tonumber(entry.vocationId or entry.id)
        requestDetail(domainState.selectedId, 1)
    else
        if state.domain == DOMAIN_DAMAGE_CALCULATOR then
            state.damageCalculator.captureSkillOverrideFromInput()
            state.damageCalculator.captureLevelOverrideFromInput()
            domainState.calculationSkill = nil
            domainState.calculationLevel = nil
        end
        domainState.selectedId = tonumber(entry.wareId or entry.id)
        if state.domain == DOMAIN_DAMAGE_CALCULATOR then
            domainState.selectedClientId = tonumber(entry.clientId or entry.itemClientId or entry.itemId)
            domainState.selectedName = entry.baseName or entry.name or entry.label or entry.title
        end
        domainState.selectedTier = tonumber(entry.tier) or 1
        requestDetail(domainState.selectedId, domainState.selectedTier)
    end
end

local function renderResults(response)
    local usesCombinedList = state.domain == DOMAIN_MONSTERS or state.domain == DOMAIN_VOCATIONS or state.domain == DOMAIN_DAMAGE_CALCULATOR
    local list = usesCombinedList and ui.monsterList or ui.resultList
    list:destroyChildren()
    hideAllEmptyLabels()
    clearResultSelection(state.domain)

    local domainState = getDomainState()
    local items = response.items or {}
    domainState.page = tonumber(response.page) or 1
    domainState.totalPages = math.max(1, tonumber(response.totalPages) or 1)
    domainState.totalResults = tonumber(response.totalResults) or #items
    updatePagination()
    setResultWidgetsEnabled(state.domain == DOMAIN_MONSTERS or state.domain == DOMAIN_VOCATIONS or domainState.activeCategory ~= nil)

    if #items == 0 then
        if usesCombinedList then
            updateMonsterEmptyLabel(getNoResultsText(state.domain))
        else
            updateResultEmptyLabel(getNoResultsText(state.domain))
        end
        resetDetailPanel(getSelectionPlaceholder(state.domain))
        return
    end

    for index, entry in ipairs(items) do
        local rowType = state.domain == DOMAIN_VOCATIONS and 'LibraryVocationListItem' or state.domain == DOMAIN_MONSTERS and 'LibraryMonsterListItem' or 'LibraryResultItem'
        local row = g_ui.createWidget(rowType, list)
        if state.domain == DOMAIN_DAMAGE_CALCULATOR then
            row:setWidth(182)
        end
        local sprite = row:recursiveGetChildById('Sprite')
        local creature = row:recursiveGetChildById('Creature')
        local nameLabel = row:recursiveGetChildById('Name')
        local bestiaryProgressLabel = row:recursiveGetChildById('BestiaryProgress')
        row:setPhantom(false)
        row.monsterId = entry.monsterId or entry.id
        if state.domain == DOMAIN_MONSTERS then
            row.monsterBaseColor = index % 2 == 0 and MONSTER_ROW_EVEN_COLOR or MONSTER_ROW_ODD_COLOR
            row.monsterHovered = false
            updateMonsterRowBackground(row)
            row.onHoverChange = function(widget, hovered)
                widget.monsterHovered = hovered
                updateMonsterRowBackground(widget)
            end
        end

        if state.domain == DOMAIN_MONSTERS then
            if sprite then
                sprite:setItemId(0)
                sprite:setVisible(false)
            end
            if not applyMonsterPreview(row, entry.raceId, entry.outfit) and creature then
                creature:setVisible(false)
            end
        elseif state.domain == DOMAIN_VOCATIONS then
            if creature then
                creature:setVisible(false)
            end
            if sprite then
                sprite:setItemId(0)
                sprite:setVisible(false)
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
            nameLabel:setText(entry.name or (state.domain == DOMAIN_MONSTERS and tr('Unknown monster') or state.domain == DOMAIN_VOCATIONS and tr('Unknown vocation') or tr('Unknown item')))
        end
        if bestiaryProgressLabel then
            local bestiary = getBestiaryData(entry)
            if state.domain == DOMAIN_MONSTERS and bestiary then
                applyBestiaryProgressToRow(row, bestiary)
            else
                bestiaryProgressLabel:setText('')
                bestiaryProgressLabel:setVisible(false)
            end
        end
        row.onClick = function()
            onResultSelected(row, entry)
        end
        row.onMouseRelease = function(widget, mousePos, mouseButton)
            if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                widget:onClick()
                updateMonsterRowBackground(widget)
                return true
            end
        end
    end

    resetDetailPanel(getSelectionPlaceholder(state.domain))
end

local function requestCurrentPage(force)
    if state.domain == DOMAIN_DAILY_REWARDS then
        requestDailyRewardsStatus(force)
        return
    elseif state.domain == DOMAIN_BLESSINGS then
        requestBlessingsStatus(force)
        return
    end

    local domainState = getDomainState()
    if not domainState.activeCategory then
        if state.domain == DOMAIN_MONSTERS or state.domain == DOMAIN_VOCATIONS or state.domain == DOMAIN_DAMAGE_CALCULATOR then
            updateMonsterEmptyLabel(state.domain == DOMAIN_VOCATIONS and tr('Select a category to load vocations.') or tr('Select a category to load monsters.'))
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

    if state.domain == DOMAIN_MONSTERS or state.domain == DOMAIN_VOCATIONS or state.domain == DOMAIN_DAMAGE_CALCULATOR then
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
    local isMonsters = state.domain == DOMAIN_MONSTERS
    local isVocations = state.domain == DOMAIN_VOCATIONS
    local isDailyRewards = state.domain == DOMAIN_DAILY_REWARDS
    local isBlessings = state.domain == DOMAIN_BLESSINGS
    local isDamageCalculator = state.domain == DOMAIN_DAMAGE_CALCULATOR
    local isFullWidthPanel = isDailyRewards or isBlessings
    ui.itemsTab:setOn(isItems)
    ui.monstersTab:setOn(isMonsters)
    ui.vocationsTab:setOn(isVocations)
    ui.dailyRewardsTab:setOn(isDailyRewards)
    ui.blessingsTab:setOn(isBlessings)
    ui.damageCalculatorTab:setOn(isDamageCalculator)
    if state.dailyRewards.notificationAvailable then
        setDailyRewardsTabNotifyColor(state.dailyRewards.tabNotificationBlinkOn)
    else
        setDailyRewardsTabNotifyColor(false)
    end
    ui.leftColumn:setVisible(not isFullWidthPanel)
    ui.middleSeparator:setVisible(not isFullWidthPanel)
    ui.detailPanel:setVisible(not isFullWidthPanel)
    ui.dailyRewardsPanel:setVisible(isDailyRewards)
    ui.blessingsPanel:setVisible(isBlessings)
    ui.dailyFooterStatsLabel:setVisible(isDailyRewards)
    updateBestiaryFooterVisibility()
    ui.categoryPanel:setVisible(isItems)
    ui.monsterPanel:setVisible(isMonsters or isVocations or isDamageCalculator)
    ui.itemsSection:setVisible(isItems)
    ui.resultLabel:setText(getResultLabelText(state.domain) .. ':')
    ui.monsterCategoryLabel:setText(tr('Categories') .. ':')
    ui.monsterLabel:setText((isVocations and tr('Vocations') or isDamageCalculator and tr('Items') or tr('Monsters')) .. ':')
    if not isDamageCalculator then
        hideDamageSkillPanel()
    end
    if not isFullWidthPanel then
        ui.detailPlaceholder:setText(getInitialPlaceholder(state.domain))
    end
    ui.topListEmptyLabel:setVisible(false)
    ui.monsterEmptyLabel:setVisible(false)
    if not isFullWidthPanel then
        anchorSearchSection(isItems)
    end

    if isDailyRewards then
        ui.resultEmptyLabel:setVisible(false)
        ui.resultList:destroyChildren()
        ui.monsterList:destroyChildren()
    elseif isBlessings then
        ui.resultEmptyLabel:setVisible(false)
        ui.resultList:destroyChildren()
        ui.monsterList:destroyChildren()
    elseif isItems then
        ui.resultEmptyLabel:setVisible(false)
    elseif isDamageCalculator then
        ui.resultList:destroyChildren()
        ui.resultEmptyLabel:setVisible(false)
    else
        ui.resultList:destroyChildren()
        ui.resultEmptyLabel:setText(isVocations and tr('Select a vocation from the list above.') or tr('Select a monster from the list above.'))
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

local function getVocationCategoryLabel(entry)
    if type(entry) ~= 'table' then
        return ''
    end
    if entry.key == 'NO_CAMP' then
        return tr('None')
    elseif entry.key == 'OLD_CAMP' then
        return tr('Old Camp')
    elseif entry.key == 'NEW_CAMP' then
        return tr('New Camp')
    end
    if type(entry.label) == 'string' and entry.label ~= '' then
        return tr(entry.label)
    end
    return humanizeKey(entry.key)
end

local function getDamageCalculatorCategoryLabel(entry)
    if type(entry) ~= 'table' then
        return ''
    end
    if type(entry.label) == 'string' and entry.label ~= '' then
        return tr(entry.label)
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
    domainState.selectedDetailMonsterId = nil
    domainState.selectedTier = 1
    domainState.selectedVariant = nil
    domainState.availableVariants = {}
    ui.searchEdit:setText('')

    for _, widget in ipairs(ui.monsterCategoryList:getChildren()) do
        widget:setChecked(widget.categoryKey == categoryKey)
    end

    requestCurrentPage(false)
end

local function setVocationCategory(categoryKey)
    local domainState = state.vocations
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

local function renderVocationCategories()
    local list = ui.monsterCategoryList
    list:destroyChildren()

    for _, entry in ipairs(state.vocations.categories) do
        local widget = g_ui.createWidget('LibraryCategoryItem', list)
        widget.categoryKey = entry.key
        widget:setText(getVocationCategoryLabel(entry))
        widget:setChecked(state.vocations.activeCategory == entry.key)
        widget.onClick = function()
            setVocationCategory(entry.key)
        end
        widget.onMouseRelease = function(self, mousePos, mouseButton)
            if self:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                self:onClick()
                return true
            end
        end
    end
end

local function setDamageCalculatorCategory(categoryKey)
    local domainState = state.damageCalculator
    if domainState.activeCategory == categoryKey then
        return
    end

    domainState.activeCategory = categoryKey
    domainState.page = 1
    domainState.search = ''
    clearResultSelection(DOMAIN_DAMAGE_CALCULATOR)
    domainState.selectedId = nil
    domainState.selectedTier = 1
    domainState.availableTiers = {}
    state.damageCalculator.captureSkillOverrideFromInput()
    state.damageCalculator.captureLevelOverrideFromInput()
    domainState.calculationSkill = nil
    domainState.calculationLevel = nil
    ui.searchEdit:setText('')

    for _, widget in ipairs(ui.monsterCategoryList:getChildren()) do
        widget:setChecked(widget.categoryKey == categoryKey)
    end

    requestCurrentPage(false)
end

local function renderDamageCalculatorCategories()
    local list = ui.monsterCategoryList
    list:destroyChildren()

    for _, entry in ipairs(state.damageCalculator.categories) do
        local widget = g_ui.createWidget('LibraryCategoryItem', list)
        widget.categoryKey = entry.key
        widget:setText(getDamageCalculatorCategoryLabel(entry))
        widget:setChecked(state.damageCalculator.activeCategory == entry.key)
        widget.onClick = function()
            setDamageCalculatorCategory(entry.key)
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

local function normalizeVocationCategories(serverCategories)
    local normalized = {}
    local seen = {}
    local defaultCategory = nil

    local function addCategory(category)
        if type(category) ~= 'table' or type(category.key) ~= 'string' or category.key == '' or seen[category.key] then
            return
        end
        local entry = {
            key = category.key,
            label = category.label,
            default = category.default == true
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

    if #normalized == 0 then
        addCategory({ key = 'NO_CAMP', label = 'None' })
        addCategory({ key = 'OLD_CAMP', label = 'Old Camp' })
        addCategory({ key = 'NEW_CAMP', label = 'New Camp' })
    end

    if not defaultCategory and normalized[1] then
        defaultCategory = normalized[1].key
    end

    return normalized, defaultCategory
end

local function normalizeDamageCalculatorCategories(serverCategories)
    local normalized = {}
    local seen = {}
    local defaultCategory = nil

    if type(serverCategories) == 'table' then
        for _, category in ipairs(serverCategories) do
            local entry = type(category) == 'string' and { key = category } or category
            if type(entry) == 'table' and type(entry.key) == 'string' and entry.key ~= '' and not seen[entry.key] then
                seen[entry.key] = true
                table.insert(normalized, {
                    key = entry.key,
                    label = entry.label,
                    default = entry.default == true
                })
                if entry.default == true and not defaultCategory then
                    defaultCategory = entry.key
                end
            end
        end
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

local function handleVocationCategoriesResponse(data)
    local vocationsState = state.vocations
    local previousCategory = vocationsState.activeCategory
    vocationsState.categoriesLoaded = true
    vocationsState.categoriesRequested = false
    vocationsState.categories, vocationsState.activeCategory = normalizeVocationCategories(data.categories)
    renderVocationCategories()

    if state.domain == DOMAIN_VOCATIONS and vocationsState.activeCategory and vocationsState.activeCategory ~= previousCategory then
        requestCurrentPage(false)
    end
end

local function handleDamageCalculatorCategoriesResponse(data)
    local calculatorState = state.damageCalculator
    local previousCategory = calculatorState.activeCategory
    calculatorState.categoriesLoaded = true
    calculatorState.categoriesRequested = false
    calculatorState.categories, calculatorState.activeCategory = normalizeDamageCalculatorCategories(data.categories)
    renderDamageCalculatorCategories()

    if state.domain == DOMAIN_DAMAGE_CALCULATOR and calculatorState.activeCategory and calculatorState.activeCategory ~= previousCategory then
        requestCurrentPage(false)
    end
end

local function handleListResponse(domain, data, requestData)
    local domainState = getDomainState(domain)
    requestData = requestData or {}
    if domain == DOMAIN_MONSTERS then
        updateBestiaryPoints(getBestiaryTotalPoints(data))
        if type(data.items) == 'table' then
            for _, entry in ipairs(data.items) do
                updateBestiaryPoints(getBestiaryTotalPoints(entry))
            end
        end
    end
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
    data.domain = domain
    if domain == DOMAIN_MONSTERS then
        updateBestiaryPoints(getBestiaryTotalPoints(data))
    end

    if domain == DOMAIN_MONSTERS then
        local familyId = requestData.monsterId or data.monsterId or data.id
        local variant
        if type(data.bossVariant) == 'string' and data.bossVariant ~= '' then
            variant = data.bossVariant
        elseif type(requestData.variant) == 'string' and requestData.variant ~= '' then
            variant = requestData.variant
        end
        if familyId then
            domainState.detailCache[makeDetailCacheKey(domain, familyId, variant or '')] = data
        end
        if domain == state.domain and familyId == domainState.selectedId and (variant or '') == (domainState.selectedVariant or '') then
            showDetail(data)
        end
    elseif domain == DOMAIN_VOCATIONS then
        local vocationId = tonumber(data.vocationId or data.id or requestData.vocationId or requestData.id)
        if vocationId then
            domainState.detailCache[makeDetailCacheKey(domain, vocationId, 1)] = data
        end
        if domain == state.domain and vocationId == domainState.selectedId then
            showDetail(data)
        end
    else
        local id = domain == DOMAIN_DAMAGE_CALCULATOR and tonumber(requestData.wareId or data.baseWareId or data.wareId) or tonumber(data.wareId or requestData.wareId)
        local tier = tonumber(data.tier or requestData.tier) or 1
        if id then
            domainState.detailCache[makeDetailCacheKey(domain, id, tier)] = data
        end
        local overrideMatches = true
        if domain == DOMAIN_DAMAGE_CALCULATOR then
            local requestedOverride = requestData.skillOverride ~= nil and tonumber(requestData.skillOverride) or nil
            local requestedLevelOverride = requestData.levelOverride ~= nil and tonumber(requestData.levelOverride) or nil
            overrideMatches = requestedOverride == domainState.skillOverride and requestedLevelOverride == domainState.levelOverride
        end
        if domain == state.domain and id == domainState.selectedId and tier == tonumber(domainState.selectedTier) and overrideMatches then
            showDetail(data)
        end
    end
end

local function handleBestiaryClaimResponse(data, requestData)
    local domainState = state.monsters
    requestData = requestData or {}
    data.domain = DOMAIN_MONSTERS

    local monsterId = data.monsterId or requestData.monsterId or data.id
    if monsterId and type(data.bestiary) == 'table' then
        updateCachedMonsterBestiary(monsterId, data.bestiary)
        updateVisibleMonsterBestiaryRow(monsterId, data.bestiary)
    end

    updateBestiaryPoints(getBestiaryTotalPoints(data))

    if monsterId and (domainState.selectedDetailMonsterId == monsterId or domainState.selectedId == monsterId) then
        local cacheKey = makeDetailCacheKey(DOMAIN_MONSTERS, domainState.selectedId or monsterId, domainState.selectedVariant or '')
        local detail = cacheKey and domainState.detailCache[cacheKey] or nil
        if type(detail) == 'table' then
            detail.bestiary = copyTable(data.bestiary)
            detail.totalBestiaryPoints = data.totalBestiaryPoints
            showDetail(detail)
        else
            showDetail(data)
        end
    end

end

local function handleBestiaryUpdate(data)
    if type(data) ~= 'table' then
        return
    end

    local domainState = state.monsters
    local monsterId = data.monsterId or data.id
    local bestiary = data.bestiary
    if not monsterId or type(bestiary) ~= 'table' then
        return
    end

    updateCachedMonsterBestiary(monsterId, bestiary)
    updateVisibleMonsterBestiaryRow(monsterId, bestiary)
    updateBestiaryPoints(getBestiaryTotalPoints(data))

    if domainState.selectedDetailMonsterId ~= monsterId then
        return
    end

    local cacheKey = makeDetailCacheKey(DOMAIN_MONSTERS, domainState.selectedId or monsterId, domainState.selectedVariant or '')
    local detail = domainState.detailCache[cacheKey]
    if type(detail) ~= 'table' then
        return
    end

    detail.bestiary = copyTable(bestiary)
    if data.totalBestiaryPoints ~= nil then
        detail.totalBestiaryPoints = data.totalBestiaryPoints
    end

    if state.domain == DOMAIN_MONSTERS then
        showDetail(detail)
    end
end

local function handleLibraryError(domain, action, payload)
    if domain == DOMAIN_DAILY_REWARDS then
        state.dailyRewards.statusRequested = false
        if domain == state.domain then
            local message = tr('Reward is not available.')
            local errorCode
            if type(payload) == 'table' and type(payload.error) == 'table' and type(payload.error.message) == 'string' then
                message = payload.error.message
            end
            if type(payload) == 'table' and type(payload.error) == 'table' and type(payload.error.code) == 'string' then
                errorCode = payload.error.code
            end
            ui.dailyStatusLabel:setText(message)
            if action == 'status' then
                stopDailyRewardNotification()
            elseif action == 'claim' and (errorCode == 'ALREADY_CLAIMED' or errorCode == 'REWARD_NOT_AVAILABLE') then
                requestDailyRewardsStatus(true)
            else
                updateDailyClaimButton()
            end
        end
        return
    end

    if domain == DOMAIN_BLESSINGS then
        state.blessings.statusRequested = false
        if domain == state.domain then
            local message = tr('Blessings are not available.')
            if type(payload) == 'table' and type(payload.error) == 'table' and type(payload.error.message) == 'string' then
                message = payload.error.message
            end
            ui.blessingsStatusLabel:setText(message)
            ui.blessingsList:destroyChildren()
        end
        return
    end

    if domain ~= state.domain then
        return
    end

    local message = tr('Library request failed.')
    local errorCode
    if type(payload) == 'table' and type(payload.error) == 'table' then
        if type(payload.error.message) == 'string' then
            message = payload.error.message
        end
        if type(payload.error.code) == 'string' then
            errorCode = payload.error.code
        end
    end

    if domain == DOMAIN_ITEMS and action == 'categories' then
        state.items.categoriesRequested = false
    elseif domain == DOMAIN_MONSTERS and action == 'categories' then
        state.monsters.categoriesRequested = false
    elseif domain == DOMAIN_VOCATIONS and action == 'categories' then
        state.vocations.categoriesRequested = false
    elseif domain == DOMAIN_DAMAGE_CALCULATOR and action == 'categories' then
        state.damageCalculator.categoriesRequested = false
    end

    if domain == DOMAIN_MONSTERS and action == 'detail' and errorCode == 'INVALID_VARIANT' then
        local domainState = state.monsters
        if domainState.selectedId and domainState.selectedVariant ~= 'normal' then
            requestDetail(domainState.selectedId, 'normal')
            return
        end
    end

    if domain == DOMAIN_MONSTERS and action == 'claim' then
        local domainState = state.monsters
        if domainState.selectedId then
            domainState.detailCache[makeDetailCacheKey(DOMAIN_MONSTERS, domainState.selectedId, domainState.selectedVariant or '')] = nil
            requestDetail(domainState.selectedId, domainState.selectedVariant)
            return
        end
    end

    if domain == DOMAIN_DAMAGE_CALCULATOR and action == 'detail' and errorCode == 'INVALID_SKILL_OVERRIDE' then
        local calculatorState = state.damageCalculator
        cancelDamageSkillOverrideEvent()
        calculatorState.skillOverride = nil
        local calculationSkill = calculatorState.calculationSkill
        if type(calculationSkill) == 'table' then
            local current = calculationSkill.current or calculationSkill.currentValue or calculationSkill.playerValue or 0
            setDamageSkillEditValue(current)
            ui.damageActualSkillLabel:setText(message)
            ui.damageActualSkillLabel:setColor('#e84a4a')
            ui.detailPlaceholder:hide()
            ui.detailContent:show()
            ui.damageSkillPanel:setHeight(42)
            ui.damageSkillPanel:show()
        else
            resetDetailPanel(message, false)
        end
        return
    end

    if domain == DOMAIN_DAMAGE_CALCULATOR and action == 'detail' and errorCode == 'INVALID_LEVEL_OVERRIDE' then
        local calculatorState = state.damageCalculator
        state.damageCalculator.cancelLevelOverrideEvent()
        calculatorState.levelOverride = nil
        local calculationLevel = calculatorState.calculationLevel
        if type(calculationLevel) == 'table' then
            local current = calculationLevel.current or calculationLevel.currentValue or calculationLevel.playerValue or 1
            state.damageCalculator.setLevelEditValue(current)
            ui.damageActualLevelLabel:setText(message)
            ui.damageActualLevelLabel:setColor('#e84a4a')
            ui.detailPlaceholder:hide()
            ui.detailContent:show()
            ui.damageLevelPanel:setHeight(42)
            ui.damageLevelPanel:show()
        else
            resetDetailPanel(message, false)
        end
        return
    end

    if domain == DOMAIN_DAMAGE_CALCULATOR and action == 'detail' then
        resetDetailPanel(message, false)
        return
    end

    if domain == DOMAIN_MONSTERS or domain == DOMAIN_VOCATIONS or domain == DOMAIN_DAMAGE_CALCULATOR then
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
    elseif action == 'categories' and domain == DOMAIN_VOCATIONS then
        handleVocationCategoriesResponse(data)
    elseif action == 'categories' and domain == DOMAIN_DAMAGE_CALCULATOR then
        handleDamageCalculatorCategoriesResponse(data)
    elseif action == 'list' then
        handleListResponse(domain, data, requestData)
    elseif action == 'detail' then
        handleDetailResponse(domain, data, requestData)
    elseif domain == DOMAIN_MONSTERS and action == 'claim' then
        handleBestiaryClaimResponse(data, requestData)
    elseif domain == DOMAIN_MONSTERS and action == 'bestiaryUpdate' then
        handleBestiaryUpdate(data)
    elseif domain == DOMAIN_DAILY_REWARDS and (action == 'status' or action == 'claim') then
        renderDailyRewardsStatus(data)
    elseif domain == DOMAIN_BLESSINGS and action == 'status' then
        renderBlessingsStatus(data)
    end
end

local function queueSearch()
    if state.domain == DOMAIN_DAILY_REWARDS or state.domain == DOMAIN_BLESSINGS then
        return
    end

    if searchEvent then
        removeEvent(searchEvent)
        searchEvent = nil
    end

    searchEvent = scheduleEvent(function()
        searchEvent = nil
        if state.domain == DOMAIN_DAILY_REWARDS or state.domain == DOMAIN_BLESSINGS then
            return
        end
        local domainState = getDomainState()
        domainState.search = ui.searchEdit:getText() or ''
        domainState.page = 1
        requestCurrentPage(true)
    end, SEARCH_DELAY)
end

local function clearSearch()
    if state.domain == DOMAIN_DAILY_REWARDS or state.domain == DOMAIN_BLESSINGS then
        return
    end

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

    if state.domain == DOMAIN_DAMAGE_CALCULATOR then
        state.damageCalculator.captureSkillOverrideFromInput()
        state.damageCalculator.captureLevelOverrideFromInput()
        state.damageCalculator.calculationSkill = nil
        state.damageCalculator.calculationLevel = nil
    end
    state.domain = domain
    updateDomainUi()
    clearResultSelection(DOMAIN_ITEMS)
    clearResultSelection(DOMAIN_MONSTERS)
    clearResultSelection(DOMAIN_VOCATIONS)
    clearResultSelection(DOMAIN_DAMAGE_CALCULATOR)

    if domain == DOMAIN_DAILY_REWARDS then
        setResultWidgetsEnabled(false)
        updatePagination()
        requestDailyRewardsStatus(true)
        return
    elseif domain == DOMAIN_BLESSINGS then
        setResultWidgetsEnabled(false)
        updatePagination()
        requestBlessingsStatus(true)
        return
    end

    local domainState = getDomainState()
    ui.searchEdit:setText(domainState.search or '')

    if domain == DOMAIN_ITEMS then
        ensureCategoriesRequested()
        renderCategories()
    elseif domain == DOMAIN_VOCATIONS then
        ensureVocationCategoriesRequested()
        renderVocationCategories()
    elseif domain == DOMAIN_DAMAGE_CALCULATOR then
        ensureDamageCalculatorCategoriesRequested()
        renderDamageCalculatorCategories()
    else
        ensureMonsterCategoriesRequested()
        renderMonsterCategories()
    end

    if domainState.activeCategory then
        requestCurrentPage(false)
    else
        if domain == DOMAIN_MONSTERS or domain == DOMAIN_VOCATIONS or domain == DOMAIN_DAMAGE_CALCULATOR then
            updateMonsterEmptyLabel(domain == DOMAIN_VOCATIONS and tr('Select a category to load vocations.') or tr('Select a category to load monsters.'))
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
    if state.domain == DOMAIN_DAILY_REWARDS then
        setResultWidgetsEnabled(false)
        updatePagination()
        requestDailyRewardsStatus(true)
        return
    elseif state.domain == DOMAIN_BLESSINGS then
        setResultWidgetsEnabled(false)
        updatePagination()
        requestBlessingsStatus(true)
        return
    elseif state.domain == DOMAIN_ITEMS then
        ensureCategoriesRequested()
        renderCategories()
    elseif state.domain == DOMAIN_VOCATIONS then
        ensureVocationCategoriesRequested()
        renderVocationCategories()
    elseif state.domain == DOMAIN_DAMAGE_CALCULATOR then
        ensureDamageCalculatorCategoriesRequested()
        renderDamageCalculatorCategories()
    else
        ensureMonsterCategoriesRequested()
        renderMonsterCategories()
    end

    local domainState = getDomainState()
    ui.searchEdit:setText(domainState.search or '')
    if domainState.activeCategory then
        requestCurrentPage(false)
    else
        if state.domain == DOMAIN_MONSTERS or state.domain == DOMAIN_VOCATIONS or state.domain == DOMAIN_DAMAGE_CALCULATOR then
            updateMonsterEmptyLabel(state.domain == DOMAIN_VOCATIONS and tr('Select a category to load vocations.') or tr('Select a category to load monsters.'))
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
    clearResultSelection(DOMAIN_VOCATIONS)
    clearResultSelection(DOMAIN_DAMAGE_CALCULATOR)
    ui.searchEdit:setText('')
    ui.resultList:destroyChildren()
    ui.monsterList:destroyChildren()
    ui.dailyRewardsList:destroyChildren()
    ui.blessingsList:destroyChildren()
    ui.dailyStatusLabel:setText(tr('Loading daily rewards...'))
    ui.blessingsStatusLabel:setText(tr('Loading blessings...'))
    ui.dailyFooterStatsLabel:setText('')
    ui.dailyFooterStatsLabel:setVisible(false)
    ui.bestiaryFooterStatsLabel:setText('')
    ui.bestiaryFooterStatsLabel:setVisible(false)
    ui.dailyClaimButton:setEnabled(false)
    renderCategories()
    if state.domain == DOMAIN_VOCATIONS then
        renderVocationCategories()
    elseif state.domain == DOMAIN_DAMAGE_CALCULATOR then
        renderDamageCalculatorCategories()
    else
        renderMonsterCategories()
    end
    ui.detailList:destroyChildren()
    updateDomainUi()
    if state.domain == DOMAIN_MONSTERS or state.domain == DOMAIN_VOCATIONS or state.domain == DOMAIN_DAMAGE_CALCULATOR then
        updateMonsterEmptyLabel(state.domain == DOMAIN_VOCATIONS and tr('Select a category to load vocations.') or tr('Select a category to load monsters.'))
    else
        updateResultEmptyLabel(tr('Select a category to load items.'))
    end
    resetDetailPanel(getInitialPlaceholder(state.domain))
    updatePagination()
    setResultWidgetsEnabled(false)
end

local function resetDomainState(domain)
    local domainState = getDomainState(domain)
    if domain == DOMAIN_DAILY_REWARDS then
        stopDailyRewardNotification()
        domainState.status = nil
        domainState.statusRequested = false
        resetDailyRewardSelection()
        return
    elseif domain == DOMAIN_BLESSINGS then
        domainState.status = nil
        domainState.statusRequested = false
        return
    end

    domainState.search = ''
    domainState.page = 1
    domainState.totalPages = 1
    domainState.totalResults = 0
    domainState.selectedId = nil
    if domain == DOMAIN_DAMAGE_CALCULATOR then
        domainState.selectedClientId = nil
        domainState.selectedName = nil
    end
    domainState.selectedTier = 1
    domainState.availableTiers = {}
    if domain == DOMAIN_DAMAGE_CALCULATOR then
        resetDamageSkillOverride()
        domainState.resetLevelOverride()
        domainState.skillEditUpdating = false
        domainState.levelEditUpdating = false
    end
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
        domainState.selectedVariant = nil
        domainState.availableVariants = {}
        domainState.selectedDetailMonsterId = nil
        if domain == DOMAIN_MONSTERS then
            domainState.totalBestiaryPoints = nil
        end
    end
end

local function resetDataState()
    state.domain = DOMAIN_ITEMS
    resetDomainState(DOMAIN_ITEMS)
    resetDomainState(DOMAIN_MONSTERS)
    resetDomainState(DOMAIN_VOCATIONS)
    resetDomainState(DOMAIN_DAILY_REWARDS)
    resetDomainState(DOMAIN_BLESSINGS)
    resetDomainState(DOMAIN_DAMAGE_CALCULATOR)
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
    ui.vocationsTab.onClick = function() switchDomain(DOMAIN_VOCATIONS) end
    ui.dailyRewardsTab.onClick = function() switchDomain(DOMAIN_DAILY_REWARDS) end
    ui.blessingsTab.onClick = function() switchDomain(DOMAIN_BLESSINGS) end
    ui.damageCalculatorTab.onClick = function() switchDomain(DOMAIN_DAMAGE_CALCULATOR) end
    ui.closeButton.onClick = hide
    ui.dailyClaimButton.onClick = claimDailyReward
    ui.damageSkillEdit:setValidCharacters('0123456789')
    ui.damageSkillEdit.onTextChange = queueDamageSkillOverride
    ui.damageSkillEdit.onKeyPress = function(widget, keyCode, keyboardModifiers)
        if keyCode == KeyEnter and keyboardModifiers == KeyboardNoModifier then
            applyDamageSkillOverrideFromInput()
            return true
        end
        return false
    end
    ui.damageSkillEdit.onFocusChange = function(widget, focused)
        if not focused then
            applyDamageSkillOverrideFromInput()
        end
    end
    ui.damageLevelEdit:setValidCharacters('0123456789')
    ui.damageLevelEdit.onTextChange = state.damageCalculator.queueLevelOverride
    ui.damageLevelEdit.onKeyPress = function(widget, keyCode, keyboardModifiers)
        if keyCode == KeyEnter and keyboardModifiers == KeyboardNoModifier then
            state.damageCalculator.applyLevelOverrideFromInput()
            return true
        end
        return false
    end
    ui.damageLevelEdit.onFocusChange = function(widget, focused)
        if not focused then
            state.damageCalculator.applyLevelOverrideFromInput()
        end
    end
    ui.dailyClaimButton:setImageColor(CLAIM_BUTTON_COLOR)
    ui.dailyClaimButton:setColor('#ffffff')
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

    stopDailyRewardNotification()
    cancelDamageSkillOverrideEvent()
    state.damageCalculator.cancelLevelOverrideEvent()

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
    requestDailyRewardsStatus(true)
end

function offline()
    stopDailyRewardNotification()
    resetDataState()
    resetUiState()
    hide()
end
