skillsWindow = nil
skillsButton = nil
skillsSettings = nil

local baseXpRate = 0
local staminaMultiplier = 0
local foodXpBoost = 0
local alchemyXpBoost = 0

local magicLevelBonusSkill = 0
local oneHandedBonusSkill = 0
local twoHandedBonusSkill = 0
local bowBonusSkill = 0
local crossbowBonusSkill = 0
local RESIST_OPCODE = 201
local STORY_GUILD_OPCODE = 222
local relogWindowState = nil
local resistValues = {
    fire = 0,
    ice = 0,
    physical = 0,
    poison = 0,
    armor = 0
}

function init()
    connect(LocalPlayer, {
        onExperienceChange = onExperienceChange,
        onBaseXpRateChange = onBaseXpRateChange,
        onStaminaMultiplierChange = onStaminaMultiplierChange,
        onFoodXpBoostChange = onFoodXpBoostChange,
        onAlchemyXpBoostChange = onAlchemyXpBoostChange,
        onLearningPointsChange = onLearningPointsChange,
        onLevelChange = onLevelChange,
        onHealthChange = onHealthChange,
        onManaChange = onManaChange,
        onSoulChange = onSoulChange,
        onFreeCapacityChange = onFreeCapacityChange,
        onTotalCapacityChange = onTotalCapacityChange,
        onStaminaChange = onStaminaChange,
        onOfflineTrainingChange = onOfflineTrainingChange,
        onRegenerationChange = onRegenerationChange,
        onSpeedChange = onSpeedChange,
        onBaseSpeedChange = onBaseSpeedChange,
        onMagicLevelChange = onMagicLevelChange,
        onBaseMagicLevelChange = onBaseMagicLevelChange,
        onSkillChange = onSkillChange,
        onBaseSkillChange = onBaseSkillChange,
        onLockPickSkillChange = onLockPickSkillChange,
        onBreakLockSkillChange = onBreakLockSkillChange,
        onPickPocketSkillChange = onPickPocketSkillChange,
        onSmithSkillChange = onSmithSkillChange,
        onMiningSkillChange = onMiningSkillChange,
        onCookingSkillChange = onCookingSkillChange,
        onHuntingSkillChange = onHuntingSkillChange,
        onBowmasterSkillChange = onBowmasterSkillChange,
        onMagicCircleSkillChange = onMagicCircleSkillChange,
        onAcrobaticSkillChange = onAcrobaticSkillChange,
        onAlchemySkillChange = onAlchemySkillChange ,
        onMagicLevelBonusChange = onMagicLevelBonusChange,
        onOneHandedBonusSkillChange = onOneHandedBonusSkillChange,
        onTwoHandedBonusSkillChange = onTwoHandedBonusSkillChange,
        onBowBonusSkillChange = onBowBonusSkillChange,
        onCrossbowBonusSkillChange = onCrossbowBonusSkillChange
    })
    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    skillsButton = modules.game_mainpanel.addToggleButton('skillsButton', tr('Skills') .. ' (Alt+S)',
                                                                   '/images/options/button_skills', toggle, false, 1)
    skillsButton:setOn(true)
    skillsWindow = g_ui.loadUI('skills')
    ProtocolGame.registerExtendedJSONOpcode(RESIST_OPCODE, onResistsOpcode)
    ProtocolGame.registerExtendedJSONOpcode(STORY_GUILD_OPCODE, onStoryGuildOpcode)

    Keybind.new("Windows", "Show/hide skills windows", "Alt+S", "")
    Keybind.bind("Windows", "Show/hide skills windows", {
      {
        type = KEY_DOWN,
        callback = toggle,
      }
    })

    skillSettings = g_settings.getNode('skills-hide')
    if not skillSettings then
        skillSettings = {}
    end

    refresh()
    skillsWindow:setup()
    if g_game.isOnline() then
        skillsWindow:setupOnStart()
    end
end

function terminate()
    disconnect(LocalPlayer, {
        onExperienceChange = onExperienceChange,
        onBaseXpRateChange = onBaseXpRateChange,
        onStaminaMultiplierChange = onStaminaMultiplierChange,
        onFoodXpBoostChange = onFoodXpBoostChange,
        onAlchemyXpBoostChange = onAlchemyXpBoostChange,
        onLearningPointsChange = onLearningPointsChange,
        onLevelChange = onLevelChange,
        onHealthChange = onHealthChange,
        onManaChange = onManaChange,
        onSoulChange = onSoulChange,
        onFreeCapacityChange = onFreeCapacityChange,
        onTotalCapacityChange = onTotalCapacityChange,
        onStaminaChange = onStaminaChange,
        onOfflineTrainingChange = onOfflineTrainingChange,
        onRegenerationChange = onRegenerationChange,
        onSpeedChange = onSpeedChange,
        onBaseSpeedChange = onBaseSpeedChange,
        onMagicLevelChange = onMagicLevelChange,
        onBaseMagicLevelChange = onBaseMagicLevelChange,
        onSkillChange = onSkillChange,
        onBaseSkillChange = onBaseSkillChange,
        onLockPickSkillChange = onLockPickSkillChange,
        onBreakLockSkillChange = onBreakLockSkillChange,
        onPickPocketSkillChange = onPickPocketSkillChange,
        onSmithSkillChange = onSmithSkillChange,
        onMiningSkillChange = onMiningSkillChange,
        onCookingSkillChange = onCookingSkillChange,
        onHuntingSkillChange = onHuntingSkillChange,
        onBowmasterSkillChange = onBowmasterSkillChange,
        onMagicCircleSkillChange = onMagicCircleSkillChange,
        onAcrobaticSkillChange = onAcrobaticSkillChange,
        onAlchemySkillChange = onAlchemySkillChange ,
        onMagicLevelBonusChange = onMagicLevelBonusChange,
        onOneHandedBonusSkillChange = onOneHandedBonusSkillChange,
        onTwoHandedBonusSkillChange = onTwoHandedBonusSkillChange,
        onBowBonusSkillChange = onBowBonusSkillChange,
        onCrossbowBonusSkillChange = onCrossbowBonusSkillChange
    })
    disconnect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    Keybind.delete("Windows", "Show/hide skills windows")
    skillsWindow:destroy()
    skillsButton:destroy()

    skillsWindow = nil
    skillsButton = nil

    pcall(ProtocolGame.unregisterExtendedJSONOpcode, RESIST_OPCODE)
    pcall(ProtocolGame.unregisterExtendedJSONOpcode, STORY_GUILD_OPCODE)
    if expSpeedEvent then
        expSpeedEvent:cancel()
        expSpeedEvent = nil
    end
    SkillData.reset()
end

function expForLevel(level)
    return math.floor((50 * level * level * level) / 3 - 100 * level * level + (850 * level) / 3 - 200)
end

function expToAdvance(currentLevel, currentExp)
    return expForLevel(currentLevel + 1) - currentExp
end

function resetSkillColor(id)
    setSkillColor(id, '#bbbbbb')
end

function toggleSkill(id, state)
    SkillData.set(id, { visible = state })
    local skill = skillsWindow:recursiveGetChildById(id)
    if not skill then
        return
    end
    skill:setVisible(state)
end

function setSkillBase(id, value, baseValue, bonus)
    if baseValue < 0 or value < 0 then
        return
    end
    bonus = bonus or 0
    if value > baseValue then
        setSkillColor(id, '#008b00') -- green

        local tooltip = baseValue .. ' + ' .. (value - baseValue)
        if bonus > 0 then
          tooltip = tooltip .. ' + ' .. bonus
        end

        setSkillRowTooltip(id, tooltip)
    elseif value < baseValue then
        setSkillColor(id, '#e81a1a') -- red
        setSkillRowTooltip(id, baseValue .. ' ' .. (value - baseValue))
    else
        resetSkillColor(id)
        setSkillRowTooltip(id, '')
    end
end

function setSkillValue(id, value)
    if id == 'skillId15' or id == 'skillId16' or id == 'skillId17' or id == 'skillId19'
        or id == 'skillId21' or id == 'skillId22' or id == 'skillId23' or id == 'skillId24' then
        if g_game.getFeature(GameEnterGameShowAppearance) then
            value = value / 100
        end
        value = value .. '%'
    end
    SkillData.set(id, { text = tostring(value) })
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        local widget = skill:getChildById('value')
        widget:setText(value)
    end
end

local function setResistValue(id, value)
    setSkillValue(id, value .. '%')
end

local function setArmorValue(id, value)
    setSkillValue(id, value)
end

local function updateResistWidgets()
    setResistValue('resistFire', resistValues.fire)
    setResistValue('resistIce', resistValues.ice)
    setResistValue('resistPoison', resistValues.poison)
    setResistValue('resistPhysical', resistValues.physical)
    setArmorValue('totalArmor', resistValues.armor)
end

function onResistsOpcode(protocol, opcode, data)
    if type(data) ~= 'table' or data.type ~= 'resists' then
        return
    end

    local res = data.res
    if type(res) ~= 'table' then
        return
    end

    if type(res.fire) == 'number' then
        resistValues.fire = res.fire
    end
    if type(res.ice) == 'number' then
        resistValues.ice = res.ice
    end
    if type(res.physical) == 'number' then
        resistValues.physical = res.physical
    end
    resistValues.poison = type(res.poison) == 'number' and res.poison or 0
    if type(res.armor) == 'number' then
        resistValues.armor = res.armor
    end

    updateResistWidgets()
end

-- Opcode 222, story guild domain, server -> client.
-- Expected state response: { action = 'state', guildId = 'old_shadow' }.
function onStoryGuildOpcode(protocol, opcode, data)
    if type(data) ~= 'table' then
        g_logger.warning('[Story guild] Ignoring invalid opcode payload.')
        return
    end
    if data.action ~= 'state' then
        g_logger.warning('[Story guild] Ignoring unknown action: ' .. tostring(data.action))
        return
    end
    if type(data.guildId) ~= 'string' then
        g_logger.warning('[Story guild] Ignoring state without a valid guildId.')
        return
    end
    if not SkillData.setStoryGuild(data.guildId) then
        g_logger.warning('[Story guild] Ignoring unknown guildId: ' .. data.guildId)
    end
end

function setSkillColor(id, value)
    SkillData.set(id, { color = value })
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        local widget = skill:getChildById('value')
        widget:setColor(value)
    end
end

function setSkillTooltip(id, value)
    SkillData.set(id, { valueTooltip = value or '' })
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        local widget = skill:getChildById('value')
        widget:setTooltip(value)
    end
end

function setSkillRowTooltip(id, value)
    SkillData.set(id, { tooltip = value or '' })
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        if value and value ~= '' then
            skill:setTooltip(value)
        else
            skill:removeTooltip()
        end
    end
end

function setSkillPercent(id, percent, tooltip, color)
    SkillData.set(id, { percent = math.floor(percent), progressTooltip = tooltip, progressColor = color })
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        local widget = skill:getChildById('percent')
        if widget then
            widget:setPercent(math.floor(percent))

            if tooltip then
                widget:setTooltip(tooltip)
            end

            if color then
                widget:setBackgroundColor(color)
            end
        end
    end
end

function checkAlert(id, value, maxValue, threshold, greaterThan)
    if greaterThan == nil then
        greaterThan = false
    end
    local alert = false

    -- maxValue can be set to false to check value and threshold
    -- used for regeneration checking
    if type(maxValue) == 'boolean' then
        if maxValue then
            return
        end

        if greaterThan then
            if value > threshold then
                alert = true
            end
        else
            if value < threshold then
                alert = true
            end
        end
    elseif type(maxValue) == 'number' then
        if maxValue < 0 then
            return
        end

        local percent = math.floor((value / maxValue) * 100)
        if greaterThan then
            if percent > threshold then
                alert = true
            end
        else
            if percent < threshold then
                alert = true
            end
        end
    end

    if alert then
        setSkillColor(id, '#e81a1a') -- red
    else
        resetSkillColor(id)
    end
end

function update()
    toggleSkill('offlineTraining', g_game.getFeature(GameOfflineTrainingTime))
    toggleSkill('regenerationTime', g_game.getFeature(GamePlayerRegenerationTime))
    SkillData.set('regenerationTime', {
        label = g_game.getFeature(GameEnterGameShowAppearance) and 'Food' or 'Regeneration Time'
    })
end

function online()
    local characterName = g_game.getCharacterName()
    local restoredAfterRelog = false

    if relogWindowState and relogWindowState.characterName == characterName then
        local parent = rootWidget:recursiveGetChildById(relogWindowState.parentId)
        if parent then
            if parent:getClassName() == 'UIMiniWindowContainer' then
                local index = relogWindowState.index or parent:getChildCount() + 1
                index = math.max(1, math.min(index, parent:getChildCount() + 1))
                parent:insertChild(index, skillsWindow)
            else
                skillsWindow:setParent(parent, true)
                if relogWindowState.position then
                    skillsWindow:setPosition(relogWindowState.position)
                end
            end

            if relogWindowState.visible then
                skillsWindow:open(true)
            else
                skillsWindow:close(true)
            end
            skillsButton:setOn(relogWindowState.visible)
            restoredAfterRelog = true
        end
    end

    relogWindowState = nil
    if not restoredAfterRelog then
        skillsWindow:setupOnStart() -- load character window configuration
    end
    refresh()
    if g_game.getFeature(GameEnterGameShowAppearance) then
        skillsWindow:recursiveGetChildById('regenerationTime'):getChildByIndex(1):setText('Food')
    end
end

local function isAdditionalSkillVisible(id, level)
    if not g_game.getFeature(GameAdditionalSkills) then
        return false
    end
    if id >= Skill.LifeLeechChance and id <= Skill.ManaLeechAmount then
        return false
    end
    if id == Skill.Dodge then
        return true
    end
    if id >= Skill.Fatal then
        return g_game.getClientVersion() >= 1332 and level > 0
    end
    return true
end

function refresh()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    SkillData.set('characterName', { text = player:getName() })
    SkillData.ensureStoryGuild()

    if expSpeedEvent then
        expSpeedEvent:cancel()
    end
    expSpeedEvent = cycleEvent(checkExpSpeed, 30 * 1000)

    onExperienceChange(player, player:getExperience())
    onBaseXpRateChange(player, player:getBaseXpRate())
    onStaminaMultiplierChange(player, player:getStaminaMultiplier())
    onFoodXpBoostChange(player, player:getFoodXpBoost())
    onAlchemyXpBoostChange(player, player:getAlchemyXpBoost())
    onLearningPointsChange(player, player:getLearningPoints())
    onLevelChange(player, player:getLevel(), player:getLevelPercent())
    onHealthChange(player, player:getHealth(), player:getMaxHealth())
    onManaChange(player, player:getMana(), player:getMaxMana())
    onSoulChange(player, player:getSoul())
    onFreeCapacityChange(player, player:getFreeCapacity())
    onStaminaChange(player, player:getStamina())
    onMagicLevelChange(player, player:getMagicLevel(), player:getMagicLevelPercent())
    onOfflineTrainingChange(player, player:getOfflineTrainingTime())
    onRegenerationChange(player, player:getRegenerationTime())
    onSpeedChange(player, player:getSpeed())
    onLockPickSkillChange(player, player:getLockPickSkill())
    onBreakLockSkillChange(player, player:getBreakLockSkill())
    onPickPocketSkillChange(player, player:getPickPocketSkill())
    onSmithSkillChange(player, player:getSmithSkill())
    onMiningSkillChange(player, player:getMiningSkill())
    onCookingSkillChange(player, player:getCookingSkill())
    onHuntingSkillChange(player, player:getHuntingSkill())
    onBowmasterSkillChange(player, player:getBowmasterSkill())
    onMagicCircleSkillChange(player, player:getMagicCircleSkill())
    onAcrobaticSkillChange(player, player:getAcrobaticSkill())
    onAlchemySkillChange(player, player:getAlchemySkill())
    onMagicLevelBonusChange(player, player:getMagicLevelBonusSkill())
    onOneHandedBonusSkillChange(player, player:getOneHandedBonusSkill())
    onTwoHandedBonusSkillChange(player, player:getTwoHandedBonusSkill())
    onBowBonusSkillChange(player, player:getBowBonusSkill())
    onCrossbowBonusSkillChange(player, player:getCrossbowBonusSkill())
    updateResistWidgets()

    for i = Skill.Fist, Skill.Transcendence do

        if i == 2 then
            onOneHandedSkillChange(player)
        elseif i == 1 then
            onTwoHandedSkillChange(player)
        elseif i == 3 then
            onBowSkillChange(player)
        elseif i == 4 then
            onCrossbowSkillChange(player)
        else
            onSkillChange(player, i, player:getSkillLevel(i), player:getSkillLevelPercent(i))
        end

        if i > Skill.Bowmastery then
            toggleSkill('skillId' .. i, isAdditionalSkillVisible(i, player:getSkillLevel(i)))
        end
    end

    update()
    updateHeight()
end

function updateHeight()
    local maximumHeight = 0

    if g_game.isOnline() then
        local char = g_game.getCharacterName()

        if not skillSettings[char] then
            skillSettings[char] = {}
        end

        local skillsButtons = skillsWindow:recursiveGetChildById('experience'):getParent():getChildren()

        for _, skillButton in pairs(skillsButtons) do
            local percentBar = skillButton:getChildById('percent')

            if skillButton:isVisible() then
                if percentBar then
                    showPercentBar(skillButton, skillSettings[char][skillButton:getId()] ~= 1)
                end
                maximumHeight = maximumHeight + skillButton:getMarginTop() + skillButton:getHeight() +
                                    skillButton:getMarginBottom()
            end
        end
    else
        maximumHeight = 390
    end

    local contentsPanel = skillsWindow:getChildById('contentsPanel')
    skillsWindow:setContentMinimumHeight(44)
    skillsWindow:setContentMaximumHeight(maximumHeight)
end

function offline()
    local parent = skillsWindow:getParent()
    if parent then
        relogWindowState = {
            characterName = g_game.getCharacterName(),
            parentId = parent:getId(),
            visible = skillsWindow:isExplicitlyVisible(),
            position = skillsWindow:getPosition()
        }

        if parent:getClassName() == 'UIMiniWindowContainer' then
            relogWindowState.index = parent:getChildIndex(skillsWindow)
        end

        skillsWindow:saveParent(parent)
        skillsWindow:setSettings({
            closed = not relogWindowState.visible
        })
    else
        relogWindowState = nil
    end

    skillsWindow:setParent(nil, true)
    if expSpeedEvent then
        expSpeedEvent:cancel()
        expSpeedEvent = nil
    end
    g_settings.setNode('skills-hide', skillSettings)
    resistValues = { fire = 0, ice = 0, physical = 0, poison = 0, armor = 0 }
    baseXpRate, staminaMultiplier, foodXpBoost, alchemyXpBoost = 0, 0, 0, 0
    magicLevelBonusSkill, oneHandedBonusSkill, twoHandedBonusSkill, bowBonusSkill, crossbowBonusSkill = 0, 0, 0, 0, 0
    SkillData.reset()
end

function toggle()
    if skillsWindow:getParent() and skillsWindow:isExplicitlyVisible() then
        skillsWindow:close()
        skillsButton:setOn(false)
    else
        if not skillsWindow:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(skillsWindow, skillsWindow:getMinimumHeight())
            if not panel then
                return
            end

            panel:addChild(skillsWindow)
        end
        skillsWindow:open()
        skillsButton:setOn(true)
        updateHeight()
    end
end

function checkExpSpeed()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local currentExp = player:getExperience()
    local currentTime = g_clock.seconds()
    if player.lastExps ~= nil then
        player.expSpeed = (currentExp - player.lastExps[1][1]) / (currentTime - player.lastExps[1][2])
        onLevelChange(player, player:getLevel(), player:getLevelPercent())
    else
        player.lastExps = {}
    end
    table.insert(player.lastExps, {currentExp, currentTime})
    if #player.lastExps > 30 then
        table.remove(player.lastExps, 1)
    end
end

function onMiniWindowOpen()
    skillsButton:setOn(true)
end

function onMiniWindowClose()
    skillsButton:setOn(false)
end

function onSkillButtonClick(button)
    local percentBar = button:getChildById('percent')
    local skillIcon = button:getChildById('icon')
    if percentBar and skillIcon then
        showPercentBar(button, not percentBar:isVisible())
        skillIcon:setVisible(true)

        local char = g_game.getCharacterName()
        if percentBar:isVisible() then
            skillsWindow:modifyMaximumHeight(6)
            skillSettings[char][button:getId()] = 0
        else
            skillsWindow:modifyMaximumHeight(-6)
            skillSettings[char][button:getId()] = 1
        end
    end     
end

function showPercentBar(button, show)
    local percentBar = button:getChildById('percent')
    local skillIcon = button:getChildById('icon')
    if percentBar and skillIcon then
        percentBar:setVisible(show)
        skillIcon:setVisible(true)
        if show then
            button:setHeight(21)
        else
            button:setHeight(21 - 6)
        end
    end
end

function onExperienceChange(localPlayer, value)
    setSkillValue('experience', comma_value(value))
    SkillData.set('nextLevelExperience', {
        text = comma_value(math.max(0, expToAdvance(localPlayer:getLevel(), value)))
    })
end

function onBaseXpRateChange(LocalPlayer, value)
    baseXpRate = value
    updateXpRate()
end

function onStaminaMultiplierChange(LocalPlayer, value)
    staminaMultiplier = value
    updateXpRate()
end

function onFoodXpBoostChange(LocalPlayer, value)
    foodXpBoost = value
    updateXpRate()
end

function onAlchemyXpBoostChange(LocalPlayer, value)
    alchemyXpBoost = value
    updateXpRate()
end

function updateXpRate()
    local total = ( baseXpRate * ( staminaMultiplier / 10.0) ) + foodXpBoost + alchemyXpBoost
    local tooltip = tr('XP Rate Breakdown:\n') ..
                    tr('(Base * stamina) + food + alchemy\n') ..
                    tr('Base: %d%%\n', baseXpRate) ..
                    tr('Stamina: %.1fx\n', staminaMultiplier / 10.0) ..
                    tr('Food: %d%%\n', foodXpBoost) ..
                    tr('Alchemy: %d%%', alchemyXpBoost)

    setSkillValue('xpRate', total .. '%')
    local color = total > 150 and '#e5c300' or total > 100 and '#89F013' or total < 51 and '#e81a1a' or '#bbbbbb'
    setSkillColor('xpRate', color)
    setSkillRowTooltip('xpRate', tooltip)
end

function onLevelChange(localPlayer, value, percent)
    setSkillValue('level', comma_value(value))
    SkillData.set('nextLevelExperience', {
        text = comma_value(math.max(0, expToAdvance(value, localPlayer:getExperience())))
    })
    local text = tr('You have %s percent to go', 100 - percent) .. '\n' ..
                     tr('%s of experience left', expToAdvance(localPlayer:getLevel(), localPlayer:getExperience()))

    if localPlayer.expSpeed ~= nil then
        local expPerHour = math.floor(localPlayer.expSpeed * 3600)
        if expPerHour > 0 then
            local nextLevelExp = expForLevel(localPlayer:getLevel() + 1)
            local hoursLeft = (nextLevelExp - localPlayer:getExperience()) / expPerHour
            local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft)) * 60)
            hoursLeft = math.floor(hoursLeft)
            text = text .. '\n' .. tr('%s of experience per hour', comma_value(expPerHour))
            text = text .. '\n' .. tr('Next level in %d hours and %d minutes', hoursLeft, minutesLeft)
        end
    end

    setSkillPercent('level', percent, text)
end

function onLearningPointsChange(player, learningPoints)
    setSkillValue('learningPoints', learningPoints)
end

local function setSpecializationValue(id, level, maximum)
    setSkillValue(id, level .. '/' .. maximum)
    SkillData.set(id, { specializationRank = level })
end

function onLockPickSkillChange(localPlayer, lockPickSkill)
    setSpecializationValue('lockPickSkill', lockPickSkill, 3)
    setSkillRowTooltip('lockPickSkill', tr('LockPickSkillFull'))
end

function onBreakLockSkillChange(localPlayer, breakLockSkill)
    setSpecializationValue('breakLockSkill', breakLockSkill, 3)
    setSkillRowTooltip('breakLockSkill', tr('BreakLockSkillFull'))
end

function onPickPocketSkillChange(localPlayer, pickPocketSkill)
    setSpecializationValue('pickPocketSkill', pickPocketSkill, 3)
    setSkillRowTooltip('pickPocketSkill', tr('PickPocketSkillFull'))
end

function onSmithSkillChange(localPlayer, smithSkill)
    setSpecializationValue('smithSkill', smithSkill, 3)
    setSkillRowTooltip('smithSkill', tr('SmithSkillFull'))
end

function onMiningSkillChange(localPlayer, miningSkill)
    setSpecializationValue('miningSkill', miningSkill, 3)
    setSkillRowTooltip('miningSkill', tr('MiningSkillFull'))
end

function onCookingSkillChange(localPlayer, cookingSkill)
    setSpecializationValue('cookingSkill', cookingSkill, 3)
    setSkillRowTooltip('cookingSkill', tr('CookingSkillFull'))
end

function onHuntingSkillChange(localPlayer, huntingSkill)
    setSpecializationValue('huntingSkill', huntingSkill, 3)
    setSkillRowTooltip('huntingSkill', tr('HuntingSkillFull'))
end

function onBowmasterSkillChange(localPlayer, bowmasterSkill)
    setSpecializationValue('bowmasterSkill', bowmasterSkill, 3)
    setSkillRowTooltip('bowmasterSkill', tr('BowmasterSkillFull'))
end

function onMagicCircleSkillChange(localPlayer, magicCircleSkill)
    setSkillValue('magicCircleSkill', magicCircleSkill)
    setSkillRowTooltip('magicCircleSkill', tr('MagicCircleSkillFull'))
end

function onAcrobaticSkillChange(localPlayer, acrobaticSkill)
    setSpecializationValue('acrobaticSkill', acrobaticSkill, 1)
    setSkillRowTooltip('acrobaticSkill', tr('AcrobaticSkillFull'))
end

function onAlchemySkillChange(localPlayer, alchemySkill)
    setSpecializationValue('alchemySkill', alchemySkill, 3)
    setSkillRowTooltip('alchemySkill', tr('AlchemySkillFull'))
end

function onHealthChange(localPlayer, health, maxHealth)
    setSkillValue('health', health)
    SkillData.set('health', { maximum = maxHealth })
    checkAlert('health', health, maxHealth, 30)
end

function onManaChange(localPlayer, mana, maxMana)
    setSkillValue('mana', mana)
    SkillData.set('mana', { maximum = maxMana })
    checkAlert('mana', mana, maxMana, 30)
end

function onSoulChange(localPlayer, soul)
    setSkillValue('soul', soul)
end

function onFreeCapacityChange(localPlayer, freeCapacity)
    setSkillValue('capacity', freeCapacity)
    checkAlert('capacity', freeCapacity, localPlayer:getTotalCapacity(), 20)
end

function onTotalCapacityChange(localPlayer, totalCapacity)
    checkAlert('capacity', localPlayer:getFreeCapacity(), totalCapacity, 20)
end

function onStaminaChange(localPlayer, stamina)
    local hours = math.floor(stamina / 60)
    local minutes = stamina % 60
    if minutes < 10 then
        minutes = '0' .. minutes
    end
    local percent = math.floor(100 * stamina / (42 * 60)) -- max is 42 hours --TODO not in all client versions

    setSkillValue('stamina', hours .. ':' .. minutes)

    -- TODO not all client versions have premium time
    if stamina > 2400 and g_game.getClientVersion() >= 1038 and localPlayer:isPremium() then
        local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
                         tr('Now you will gain 50%% more experience')
        setSkillPercent('stamina', percent, text, 'green')
    elseif stamina > 2400 and g_game.getClientVersion() >= 1038 and not localPlayer:isPremium() then
        local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' .. tr(
                         'You will not gain 50%% more experience because you aren\'t premium player, now you receive only 1x experience points')
        setSkillPercent('stamina', percent, text, '#89F013')
    elseif stamina >= 2400 and g_game.getClientVersion() < 1038 then
        local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
                         tr('If you are premium player, you will gain 50%% more experience')
        setSkillPercent('stamina', percent, text, 'green')
    elseif stamina < 2400 and stamina > 840 then
        setSkillPercent('stamina', percent, tr('You have %s hours and %s minutes left', hours, minutes), 'orange')
    elseif stamina <= 840 and stamina > 0 then
        local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
                         tr('You gain only 50%% experience and you don\'t may gain loot from monsters')
        setSkillPercent('stamina', percent, text, 'red')
    elseif stamina == 0 then
        local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
                         tr('You don\'t may receive experience and loot from monsters')
        setSkillPercent('stamina', percent, text, 'black')
    end
end

function onOfflineTrainingChange(localPlayer, offlineTrainingTime)
    if not g_game.getFeature(GameOfflineTrainingTime) then
        return
    end
    local hours = math.floor(offlineTrainingTime / 60)
    local minutes = offlineTrainingTime % 60
    if minutes < 10 then
        minutes = '0' .. minutes
    end
    local percent = 100 * offlineTrainingTime / (12 * 60) -- max is 12 hours

    setSkillValue('offlineTraining', hours .. ':' .. minutes)
    setSkillPercent('offlineTraining', percent, tr('You have %s percent', percent))
end

function onRegenerationChange(localPlayer, regenerationTime)
    if not g_game.getFeature(GamePlayerRegenerationTime) or regenerationTime < 0 then
        return
    end
    local hours = math.floor(regenerationTime / 3600)
    local minutes = math.floor(regenerationTime / 60)
    local seconds = regenerationTime % 60
    if seconds < 10 then
        seconds = '0' .. seconds
    end
    if minutes < 10 then
        minutes = '0' .. minutes
    end
    if hours < 10 then
        hours = '0' .. hours
    end
    local fmt = ""
    local alert = 300
    if g_game.getFeature(GameEnterGameShowAppearance) then
        fmt = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        alert = 0
    else
        fmt = string.format("%02d:%02d", minutes, seconds)
    end
    setSkillValue('regenerationTime', fmt)
    checkAlert('regenerationTime', regenerationTime, false, alert)
    if g_game.getFeature(GameEnterGameShowAppearance) then
        modules.game_interface.StatsBar.onHungryChange(regenerationTime, alert)
    end
end

function onSpeedChange(localPlayer, speed)
    setSkillValue('speed', speed)

    onBaseSpeedChange(localPlayer, localPlayer:getBaseSpeed(), 0)
end

function onBaseSpeedChange(localPlayer, baseSpeed, bonus)
    setSkillBase('speed', localPlayer:getSpeed(), baseSpeed, bonus)
end

local function createTooltip(skillValue, base, learnedValue, percent)
    return 
        tr("Base: %s", base) .. '\n' .. 
        tr("Bonus: %s", skillValue - base) .. '\n' ..
        tr("Learned: %s", learnedValue) .. '\n\n' ..
        tr("You have %s percent to go", 100 - percent)
end

local function updateMagicLevelWidget(localPlayer)
    local skillValue = localPlayer:getMagicLevel()
    local skillBase = localPlayer:getBaseMagicLevel()
    local percent = localPlayer:getMagicLevelPercent()

    setSkillValue('magiclevel', skillValue + magicLevelBonusSkill)

    local tooltip = createTooltip(skillValue, skillBase, magicLevelBonusSkill, percent)
    setSkillPercent('magiclevel', percent, tooltip)

    onBaseMagicLevelChange(localPlayer, skillBase, magicLevelBonusSkill)
end

function onMagicLevelChange(localPlayer, magiclevel, percent)
    updateMagicLevelWidget(localPlayer)
end

function onMagicLevelBonusChange(localPlayer, bonusMagicLevelSkill)
    magicLevelBonusSkill = bonusMagicLevelSkill
    updateMagicLevelWidget(localPlayer)
end

local function getBaseValue(player, skillId)
    local base = player:getSkillBaseLevel(skillId)

    if base == 0 then
        return 10
    else
        return base
    end
end

local function updateSkillWidget(localPlayer, skillId, bonus)
    local skillValue = localPlayer:getSkillLevel(skillId)
    local skillBase = getBaseValue(localPlayer, skillId)
    local percent = localPlayer:getSkillLevelPercent(skillId)

    setSkillValue('skillId' .. skillId, skillValue + bonus)
    
    local tooltip = createTooltip(skillValue, skillBase, bonus, percent)
    setSkillPercent('skillId' .. skillId, percent, tooltip)

    onBaseSkillChange(localPlayer, skillId, skillBase, bonus)
end

function onOneHandedSkillChange(localPlayer)
    updateSkillWidget(localPlayer, 2, oneHandedBonusSkill)
end

function onOneHandedBonusSkillChange(localPlayer, bonusOneHandedSkill)
    oneHandedBonusSkill = bonusOneHandedSkill
    updateSkillWidget(localPlayer, 2, oneHandedBonusSkill)
end

function onTwoHandedSkillChange(localPlayer)
    updateSkillWidget(localPlayer, 1, twoHandedBonusSkill)
end

function onTwoHandedBonusSkillChange(localPlayer, bonusTwoHandedSkill)
    twoHandedBonusSkill = bonusTwoHandedSkill
    updateSkillWidget(localPlayer, 1, twoHandedBonusSkill)
end

function onBowSkillChange(localPlayer)
    updateSkillWidget(localPlayer, 3, bowBonusSkill)
end

function onBowBonusSkillChange(localPlayer, bonusBowSkill)
    bowBonusSkill = bonusBowSkill
    updateSkillWidget(localPlayer, 3, bowBonusSkill)
end

function onCrossbowSkillChange(localPlayer)
    updateSkillWidget(localPlayer, 4, crossbowBonusSkill)
end

function onCrossbowBonusSkillChange(localPlayer, bonusCrossbowSkill)
    crossbowBonusSkill = bonusCrossbowSkill
    updateSkillWidget(localPlayer, 4, crossbowBonusSkill)
end

function onBaseMagicLevelChange(localPlayer, baseMagicLevel, bonus)
    setSkillBase('magiclevel', localPlayer:getMagicLevel(), baseMagicLevel, bonus)
end

function onSkillChange(localPlayer, id, level, percent)


    if id == 2 then
        onOneHandedSkillChange(localPlayer)
    elseif id == 1 then
        onTwoHandedSkillChange(localPlayer)
    elseif id == 3 then
        onBowSkillChange(localPlayer)
    elseif id == 4 then
        onCrossbowSkillChange(localPlayer)
    else
        setSkillValue('skillId' .. id, level)
        setSkillPercent('skillId' .. id, percent, tr('You have %s percent to go', 100 - percent))

        onBaseSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id), 0)
    end

    if id > Skill.Bowmastery then
        toggleSkill('skillId' .. id, isAdditionalSkillVisible(id, level))
    end
end

function onBaseSkillChange(localPlayer, id, baseLevel, bonus)
    setSkillBase('skillId' .. id, localPlayer:getSkillLevel(id), baseLevel, bonus)
end
