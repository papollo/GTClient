local SpelllistProfile = 'Gothic'
local CUSTOM_SPELL_ORDER = {}
local CUSTOM_SPELL_INFO = {}
local ACTIVE_SPELL_PROFILE = 'Gothic'

spelllistWindow = nil
spelllistButton = nil
spellList = nil
nameValueLabel = nil
formulaValueLabel = nil
vocationValueLabel = nil
groupValueLabel = nil
typeValueLabel = nil
cooldownValueLabel = nil
levelValueLabel = nil
manaValueLabel = nil
premiumValueLabel = nil
descriptionValueLabel = nil

vocationBoxAny = nil
vocationBoxOneHanded = nil
vocationBoxTwoHanded = nil
vocationBoxCrossbow = nil
vocationBoxBow = nil

groupBoxAny = nil
groupBoxAttack = nil
groupBoxHealing = nil
groupBoxSupport = nil

premiumBoxAny = nil
premiumBoxNo = nil
premiumBoxYes = nil

vocationRadioGroup = nil
groupRadioGroup = nil
premiumRadioGroup = nil

-- consts
FILTER_PREMIUM_ANY = 0
FILTER_PREMIUM_NO = 1
FILTER_PREMIUM_YES = 2

FILTER_VOCATION_ANY = 0
FILTER_VOCATION_ONE_HANDED = 1
FILTER_VOCATION_TWO_HANDED = 2
FILTER_VOCATION_CROSSBOW = 3
FILTER_VOCATION_BOW = 4

FILTER_GROUP_ANY = 0
FILTER_GROUP_ATTACK = 1
FILTER_GROUP_HEALING = 2
FILTER_GROUP_SUPPORT = 3

local WEAPON_TYPE_NAMES = {
    [1] = 'One handed',
    [2] = 'Two handed',
    [3] = 'Crossbow',
    [4] = 'Bow',
    [5] = 'One handed',
    [6] = 'Two handed',
    [7] = 'Crossbow',
    [8] = 'Bow'
}

-- Filter Settings
local filters = {
    level = false,
    vocation = false,

    vocationId = FILTER_VOCATION_ANY,
    premium = FILTER_PREMIUM_ANY,
    groupId = FILTER_GROUP_ANY
}

local function loadCustomSpells()
    SpelllistProfile = ACTIVE_SPELL_PROFILE
    if not SpelllistSettings[SpelllistProfile] or not SpellInfo[SpelllistProfile] then
        SpelllistProfile = 'Default'
    end

    CUSTOM_SPELL_INFO = SpellInfo[SpelllistProfile]
    CUSTOM_SPELL_ORDER = {}

    for _, spellName in ipairs(SpelllistSettings[SpelllistProfile].spellOrder) do
        local info = CUSTOM_SPELL_INFO[spellName]
        if info and info.words and info.words ~= '' then
            table.insert(CUSTOM_SPELL_ORDER, spellName)
        end
    end
end

function getSpelllistProfile()
    return SpelllistProfile
end

function setSpelllistProfile(name)
    if SpelllistProfile == name then
        return
    end

    if SpelllistSettings[name] and SpellInfo[name] then
        local oldProfile = SpelllistProfile
        SpelllistProfile = name
        changeSpelllistProfile(oldProfile)
    else
        perror('Spelllist profile \'' .. name .. '\' could not be set.')
    end
end

function online()
    if g_game.getFeature(GameSpellList) and not spelllistButton then
        spelllistButton = modules.game_mainpanel.addToggleButton('spelllistButton', tr('Spell List'),
        '/images/options/button_spells', toggle, false, 4)
        spelllistButton:setOn(false)
    end

    -- Vocation is only send in newer clients
    if g_game.getClientVersion() >= 950 then
        spelllistWindow:getChildById('buttonFilterVocation'):setVisible(true)
    else
        spelllistWindow:getChildById('buttonFilterVocation'):setVisible(false)
    end
end

function offline()
    resetWindow()
end

function init()
    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    spelllistWindow = g_ui.displayUI('spelllist', modules.game_interface.getRightPanel())
    spelllistWindow:hide()

    nameValueLabel = spelllistWindow:getChildById('labelNameValue')
    formulaValueLabel = spelllistWindow:getChildById('labelFormulaValue')
    vocationValueLabel = spelllistWindow:getChildById('labelVocationValue')
    groupValueLabel = spelllistWindow:getChildById('labelGroupValue')
    typeValueLabel = spelllistWindow:getChildById('labelTypeValue')
    cooldownValueLabel = spelllistWindow:getChildById('labelCooldownValue')
    levelValueLabel = spelllistWindow:getChildById('labelLevelValue')
    manaValueLabel = spelllistWindow:getChildById('labelManaValue')
    premiumValueLabel = spelllistWindow:getChildById('labelPremiumValue')
    descriptionValueLabel = spelllistWindow:getChildById('labelDescriptionValue')

    vocationBoxAny = spelllistWindow:getChildById('vocationBoxAny')
    vocationBoxOneHanded = spelllistWindow:getChildById('vocationBoxOneHanded')
    vocationBoxTwoHanded = spelllistWindow:getChildById('vocationBoxTwoHanded')
    vocationBoxCrossbow = spelllistWindow:getChildById('vocationBoxCrossbow')
    vocationBoxBow = spelllistWindow:getChildById('vocationBoxBow')

    groupBoxAny = spelllistWindow:getChildById('groupBoxAny')
    groupBoxAttack = spelllistWindow:getChildById('groupBoxAttack')
    groupBoxHealing = spelllistWindow:getChildById('groupBoxHealing')
    groupBoxSupport = spelllistWindow:getChildById('groupBoxSupport')

    premiumBoxAny = spelllistWindow:getChildById('premiumBoxAny')
    premiumBoxYes = spelllistWindow:getChildById('premiumBoxYes')
    premiumBoxNo = spelllistWindow:getChildById('premiumBoxNo')

    vocationRadioGroup = UIRadioGroup.create()
    vocationRadioGroup:addWidget(vocationBoxAny)
    vocationRadioGroup:addWidget(vocationBoxOneHanded)
    vocationRadioGroup:addWidget(vocationBoxTwoHanded)
    vocationRadioGroup:addWidget(vocationBoxCrossbow)
    vocationRadioGroup:addWidget(vocationBoxBow)

    groupRadioGroup = UIRadioGroup.create()
    groupRadioGroup:addWidget(groupBoxAny)
    groupRadioGroup:addWidget(groupBoxAttack)
    groupRadioGroup:addWidget(groupBoxHealing)
    groupRadioGroup:addWidget(groupBoxSupport)

    premiumRadioGroup = UIRadioGroup.create()
    premiumRadioGroup:addWidget(premiumBoxAny)
    premiumRadioGroup:addWidget(premiumBoxYes)
    premiumRadioGroup:addWidget(premiumBoxNo)

    premiumRadioGroup:selectWidget(premiumBoxAny)
    vocationRadioGroup:selectWidget(vocationBoxAny)
    groupRadioGroup:selectWidget(groupBoxAny)

    vocationRadioGroup.onSelectionChange = toggleFilter
    groupRadioGroup.onSelectionChange = toggleFilter
    premiumRadioGroup.onSelectionChange = toggleFilter

    spellList = spelllistWindow:getChildById('spellList')

    g_keyboard.bindKeyPress('Down', function()
        spellList:focusNextChild(KeyboardFocusReason)
    end, spelllistWindow)
    g_keyboard.bindKeyPress('Up', function()
        spellList:focusPreviousChild(KeyboardFocusReason)
    end, spelllistWindow)

    loadCustomSpells()
    initializeSpelllist()
    resizeWindow()

    if g_game.isOnline() then
        online()
    end
    Keybind.new("Windows", "Show/hide spell list", "Alt+L", "")
    Keybind.bind("Windows", "Show/hide spell list", {
      {
        type = KEY_DOWN,
        callback = toggle,
      }
    })
end

function terminate()
    disconnect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    spelllistWindow:destroy()
    if spelllistButton then
        spelllistButton:destroy()
        spelllistButton = nil
    end
    vocationRadioGroup:destroy()
    groupRadioGroup:destroy()
    premiumRadioGroup:destroy()
    Keybind.delete("Windows", "Show/hide spell list")
end

function initializeSpelllist()
    for i = 1, #CUSTOM_SPELL_ORDER do
        local spell = CUSTOM_SPELL_ORDER[i]
        local info = CUSTOM_SPELL_INFO[spell]

        local tmpLabel = g_ui.createWidget('SpellListLabel', spellList)
        tmpLabel:setId(spell)
        local formulaText = info.words and info.words ~= '' and ('\n\'' .. info.words .. '\'') or ''
        tmpLabel:setText(spell .. formulaText)
        tmpLabel:setPhantom(false)

        local iconId = tonumber(info.icon)
        if not iconId and SpellIcons[info.icon] then
            iconId = SpellIcons[info.icon][1]
        end

        if not (iconId) then
            iconId = 1
        end

        tmpLabel:setHeight(SpelllistSettings[SpelllistProfile].iconSize.height + 4)
        tmpLabel:setTextOffset(topoint((SpelllistSettings[SpelllistProfile].iconSize.width + 10) .. ' ' ..
                                           (SpelllistSettings[SpelllistProfile].iconSize.height - 32) / 2 + 3))
        tmpLabel:setImageSource(SpelllistSettings[SpelllistProfile].iconFile)
        tmpLabel:setImageClip(Spells.getImageClip(iconId, SpelllistProfile))
        tmpLabel:setImageSize(tosize(SpelllistSettings[SpelllistProfile].iconSize.width .. ' ' ..
                                         SpelllistSettings[SpelllistProfile].iconSize.height))
        tmpLabel.onClick = updateSpellInformation
    end

    connect(spellList, {
        onChildFocusChange = function(self, focusedChild)
            if focusedChild == nil then
                return
            end
            updateSpellInformation(focusedChild)
        end
    })
end

function changeSpelllistProfile(oldProfile)
    -- Delete old labels
    for i = 1, #CUSTOM_SPELL_ORDER do
        local spell = CUSTOM_SPELL_ORDER[i]
        local tmpLabel = spellList:getChildById(spell)

        if tmpLabel then
            tmpLabel:destroy()
        end
    end

    -- Create new spelllist and ajust window
    initializeSpelllist()
    resizeWindow()
    resetWindow()
end

function updateSpelllist()
    for i = 1, #CUSTOM_SPELL_ORDER do
        local spell = CUSTOM_SPELL_ORDER[i]
        local info = CUSTOM_SPELL_INFO[spell]
        local tmpLabel = spellList:getChildById(spell)

        local localPlayer = g_game.getLocalPlayer()
        if (not (filters.level) or info.level <= localPlayer:getLevel()) and
            (not (filters.vocation) or table.find(info.vocations, localPlayer:getVocation())) and
            (filters.vocationId == FILTER_VOCATION_ANY or table.find(info.vocations, filters.vocationId) or
                table.find(info.vocations, filters.vocationId + 4)) and
            (filters.groupId == FILTER_GROUP_ANY or info.group[filters.groupId]) and
            (filters.premium == FILTER_PREMIUM_ANY or (info.premium and filters.premium == FILTER_PREMIUM_YES) or
                (not (info.premium) and filters.premium == FILTER_PREMIUM_NO)) then
            tmpLabel:setVisible(true)
        else
            tmpLabel:setVisible(false)
        end
    end
end

function updateSpellInformation(widget)
    local spell = widget:getId()

    local name = ''
    local formula = ''
    local vocation = ''
    local group = ''
    local type = ''
    local cooldown = ''
    local level = ''
    local mana = ''
    local premium = ''
    local description = ''

    if CUSTOM_SPELL_INFO[spell] then
        local info = CUSTOM_SPELL_INFO[spell]

        name = spell
        formula = info.words

        for i = 1, #info.vocations do
            local vocationId = info.vocations[i]
            if vocationId <= 4 or not (table.find(info.vocations, (vocationId - 4))) then
                local weaponTypeName = WEAPON_TYPE_NAMES[vocationId] or VocationNames[vocationId]
                vocation = vocation .. (vocation:len() == 0 and '' or ', ') .. tr(weaponTypeName)
            end
        end

        cooldown = (info.exhaustion / 1000) .. 's'
        for groupId, groupName in ipairs(SpellGroups) do
            if info.group[groupId] then
                group = group .. (group:len() == 0 and '' or ' / ') .. groupName
                cooldown = cooldown .. ' / ' .. (info.group[groupId] / 1000) .. 's'
            end
        end

        type = info.type
        level = info.level
        mana = info.mana .. ' / ' .. info.soul
        premium = (info.premium and 'yes' or 'no')
        description = info.description or '-'
    end

    nameValueLabel:setText(name)
    formulaValueLabel:setText(formula)
    vocationValueLabel:setText(vocation)
    groupValueLabel:setText(group)
    typeValueLabel:setText(type)
    cooldownValueLabel:setText(cooldown)
    levelValueLabel:setText(level)
    manaValueLabel:setText(mana)
    premiumValueLabel:setText(premium)
    descriptionValueLabel:setText(description)
end

function toggle()
    if spelllistButton:isOn() then
        spelllistButton:setOn(false)
        spelllistWindow:hide()
    else
        spelllistButton:setOn(true)
        spelllistWindow:show()
        spelllistWindow:raise()
        spelllistWindow:focus()
    end
end

function toggleFilter(widget, selectedWidget)
    if widget == vocationRadioGroup then
        local boxId = selectedWidget:getId()
        if boxId == 'vocationBoxAny' then
            filters.vocationId = FILTER_VOCATION_ANY
        elseif boxId == 'vocationBoxOneHanded' then
            filters.vocationId = FILTER_VOCATION_ONE_HANDED
        elseif boxId == 'vocationBoxTwoHanded' then
            filters.vocationId = FILTER_VOCATION_TWO_HANDED
        elseif boxId == 'vocationBoxCrossbow' then
            filters.vocationId = FILTER_VOCATION_CROSSBOW
        elseif boxId == 'vocationBoxBow' then
            filters.vocationId = FILTER_VOCATION_BOW
        end
    elseif widget == groupRadioGroup then
        local boxId = selectedWidget:getId()
        if boxId == 'groupBoxAny' then
            filters.groupId = FILTER_GROUP_ANY
        elseif boxId == 'groupBoxAttack' then
            filters.groupId = FILTER_GROUP_ATTACK
        elseif boxId == 'groupBoxHealing' then
            filters.groupId = FILTER_GROUP_HEALING
        elseif boxId == 'groupBoxSupport' then
            filters.groupId = FILTER_GROUP_SUPPORT
        end
    elseif widget == premiumRadioGroup then
        local boxId = selectedWidget:getId()
        if boxId == 'premiumBoxAny' then
            filters.premium = FILTER_PREMIUM_ANY
        elseif boxId == 'premiumBoxNo' then
            filters.premium = FILTER_PREMIUM_NO
        elseif boxId == 'premiumBoxYes' then
            filters.premium = FILTER_PREMIUM_YES
        end
    else
        local id = widget:getId()
        if id == 'buttonFilterLevel' then
            filters.level = not (filters.level)
            widget:setOn(filters.level)
        elseif id == 'buttonFilterVocation' then
            filters.vocation = not (filters.vocation)
            widget:setOn(filters.vocation)
        end
    end

    updateSpelllist()
end

function resizeWindow()
    spelllistWindow:setWidth(SpelllistSettings[SpelllistProfile].spellWindowWidth +
                                 SpelllistSettings[SpelllistProfile].iconSize.width - 32)
    spellList:setWidth(
        SpelllistSettings[SpelllistProfile].spellListWidth + SpelllistSettings[SpelllistProfile].iconSize.width - 32)
end

function resetWindow()
    spelllistWindow:hide()
    if spelllistButton then
        spelllistButton:setOn(false)
    end

    -- Resetting filters
    filters.level = false
    filters.vocation = false

    local buttonFilterLevel = spelllistWindow:getChildById('buttonFilterLevel')
    buttonFilterLevel:setOn(filters.level)

    local buttonFilterVocation = spelllistWindow:getChildById('buttonFilterVocation')
    buttonFilterVocation:setOn(filters.vocation)

    vocationRadioGroup:selectWidget(vocationBoxAny)
    groupRadioGroup:selectWidget(groupBoxAny)
    premiumRadioGroup:selectWidget(premiumBoxAny)

    updateSpelllist()
end
