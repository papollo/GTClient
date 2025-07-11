skillsWindow = nil
skillsButton = nil
skillsSettings = nil

local baseXpRate = 0
local staminaMultiplier = 0
local foodXpBoost = 0
local alchemyXpBoost = 0

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
        onMagicCircleSkillChange = onMagicCircleSkillChange,
        onAcrobaticSkillChange = onAcrobaticSkillChange
    })
    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    skillsButton = modules.game_mainpanel.addToggleButton('skillsButton', tr('Skills') .. ' (Alt+S)',
                                                                   '/images/options/button_skills', toggle, false, 1)
    skillsButton:setOn(true)
    skillsWindow = g_ui.loadUI('skills')

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
        onMagicCircleSkillChange = onMagicCircleSkillChange,
        onAcrobaticSkillChange = onAcrobaticSkillChange
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
end

function expForLevel(level)
    return math.floor((50 * level * level * level) / 3 - 100 * level * level + (850 * level) / 3 - 200)
end

function expToAdvance(currentLevel, currentExp)
    return expForLevel(currentLevel + 1) - currentExp
end

function resetSkillColor(id)
    local skill = skillsWindow:recursiveGetChildById(id)
    local widget = skill:getChildById('value')
    widget:setColor('#bbbbbb')
end

function toggleSkill(id, state)
    local skill = skillsWindow:recursiveGetChildById(id)
    skill:setVisible(state)
end

function setSkillBase(id, value, baseValue)
    if baseValue <= 0 or value < 0 then
        return
    end
    local skill = skillsWindow:recursiveGetChildById(id)
    local widget = skill:getChildById('value')

    if value > baseValue then
        widget:setColor('#008b00') -- green
        skill:setTooltip(baseValue .. ' +' .. (value - baseValue))
    elseif value < baseValue then
        widget:setColor('#e81a1a') -- red
        skill:setTooltip(baseValue .. ' ' .. (value - baseValue))
    else
        widget:setColor('#bbbbbb') -- default
        skill:removeTooltip()
    end
end

function setSkillValue(id, value)
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        local widget = skill:getChildById('value')
        if id == "skillId14" or id == "skillId15" or id == "skillId16" or id == "skillId18" or id == "skillId20" or id == "skillId21" or id == "skillId22" or id == "skillId23" then
            if g_game.getFeature(GameEnterGameShowAppearance) then
                value = value / 100
            end
            widget:setText(value .. "%")
        else
            widget:setText(value)
        end
    end
end

function setSkillColor(id, value)
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        local widget = skill:getChildById('value')
        widget:setColor(value)
    end
end

function setSkillTooltip(id, value)
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        local widget = skill:getChildById('value')
        widget:setTooltip(value)
    end
end

function setSkillPercent(id, percent, tooltip, color)
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
    local offlineTraining = skillsWindow:recursiveGetChildById('offlineTraining')
    if not g_game.getFeature(GameOfflineTrainingTime) then
        offlineTraining:hide()
    else
        offlineTraining:show()
    end

    local regenerationTime = skillsWindow:recursiveGetChildById('regenerationTime')
    if not g_game.getFeature(GamePlayerRegenerationTime) then
        regenerationTime:hide()
    else
        regenerationTime:show()
    end
end

function online()
    skillsWindow:setupOnStart() -- load character window configuration
    refresh()
    if g_game.getFeature(GameEnterGameShowAppearance) then
        skillsWindow:recursiveGetChildById('regenerationTime'):getChildByIndex(1):setText('Food')
    end
end

function refresh()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

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
    onMagicCircleSkillChange(player, player:getMagicCircleSkill())
    onAcrobaticSkillChange(player, player:getAcrobaticSkill())

    local hasAdditionalSkills = g_game.getFeature(GameAdditionalSkills)
    for i = Skill.Fist, Skill.Transcendence do
        onSkillChange(player, i, player:getSkillLevel(i), player:getSkillLevelPercent(i))

        if i > Skill.Hunting then
            local ativedAdditionalSkills = hasAdditionalSkills
            if ativedAdditionalSkills then
                if g_game.getClientVersion() >= 1281 then
	                if i == Skill.LifeLeechAmount or i == Skill.ManaLeechAmount then
                        ativedAdditionalSkills = false
                    elseif g_game.getClientVersion() < 1332 and Skill.Transcendence then
                        ativedAdditionalSkills = false
                    elseif i >= Skill.Fatal and player:getSkillLevel(i) <= 0 then
                        ativedAdditionalSkills = false
                    end
		        elseif g_game.getClientVersion() < 1281 and i >= Skill.Fatal then
                    ativedAdditionalSkills = false
	            end
            end

            toggleSkill('skillId' .. i, ativedAdditionalSkills)
        end
    end

    update()
    updateHeight()
end

function updateHeight()
    local maximumHeight = 8 -- margin top and bottom

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
                maximumHeight = maximumHeight + skillButton:getHeight() + skillButton:getMarginBottom()
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
    skillsWindow:setParent(nil, true)
    if expSpeedEvent then
        expSpeedEvent:cancel()
        expSpeedEvent = nil
    end
    g_settings.setNode('skills-hide', skillSettings)
end

function toggle()
    if skillsButton:isOn() then
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

    local skillWidget = skillsWindow:recursiveGetChildById('xpRate')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(total .. "%")

        if total > 150 then
            widget:setColor('#e5c300')
        elseif total > 100 then
            widget:setColor('#89F013')
        elseif total < 51 then
            widget:setColor('#e81a1a')
        else
            widget:setColor('#bbbbbb')        
        end

        skillWidget:setTooltip(tooltip)
    end
end

function onLevelChange(localPlayer, value, percent)
    setSkillValue('level', comma_value(value))
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

function onLockPickSkillChange(localPlayer, lockPickSkill)
    local skillWidget = skillsWindow:recursiveGetChildById('lockPickSkill')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(lockPickSkill .. "/3")
        skillWidget:setTooltip(tr("LockPickSkillFull"))
    end
end

function onBreakLockSkillChange(localPlayer, breakLockSkill)
    local skillWidget = skillsWindow:recursiveGetChildById('breakLockSkill')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(breakLockSkill .. "/3")
        skillWidget:setTooltip(tr("BreakLockSkillFull"))
    end
end

function onPickPocketSkillChange(localPlayer, pickPocketSkill)
    local skillWidget = skillsWindow:recursiveGetChildById('pickPocketSkill')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(pickPocketSkill .. "/3")
        skillWidget:setTooltip(tr("PickPocketSkillFull"))
    end
end

function onSmithSkillChange(localPlayer, smithSkill)
    local skillWidget = skillsWindow:recursiveGetChildById('smithSkill')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(smithSkill .. "/3")
        skillWidget:setTooltip(tr("SmithSkillFull"))
    end
end

function onMiningSkillChange(localPlayer, miningSkill)
    local skillWidget = skillsWindow:recursiveGetChildById('miningSkill')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(miningSkill .. "/3")
        skillWidget:setTooltip(tr("MiningSkillFull"))
    end
end

function onCookingSkillChange(localPlayer, cookingSkill)
    local skillWidget = skillsWindow:recursiveGetChildById('cookingSkill')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(cookingSkill .. "/3")
        skillWidget:setTooltip(tr("CookingSkillFull"))
    end
end

function onHuntingSkillChange(localPlayer, huntingSkill)
    local skillWidget = skillsWindow:recursiveGetChildById('huntingSkill')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(huntingSkill .. "/3")
        skillWidget:setTooltip(tr("HuntingSkillFull"))
    end
end

function onMagicCircleSkillChange(localPlayer, magicCircleSkill)
    local skillWidget = skillsWindow:recursiveGetChildById('magicCircleSkill')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(magicCircleSkill .. "/5")
        skillWidget:setTooltip(tr("MagicCircleSkillFull"))
    end
end

function onAcrobaticSkillChange(localPlayer, acrobaticSkill)
    local skillWidget = skillsWindow:recursiveGetChildById('acrobaticSkill')
    if skillWidget then
        local widget = skillWidget:getChildById('value')
        widget:setText(acrobaticSkill .. "/1")
        skillWidget:setTooltip(tr("AcrobaticSkillFull"))
    end
end

function onHealthChange(localPlayer, health, maxHealth)
    setSkillValue('health', health)
    checkAlert('health', health, maxHealth, 30)
end

function onManaChange(localPlayer, mana, maxMana)
    setSkillValue('mana', mana)
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

    onBaseSpeedChange(localPlayer, localPlayer:getBaseSpeed())
end

function onBaseSpeedChange(localPlayer, baseSpeed)
    setSkillBase('speed', localPlayer:getSpeed(), baseSpeed)
end

function onMagicLevelChange(localPlayer, magiclevel, percent)
    setSkillValue('magiclevel', magiclevel)
    setSkillPercent('magiclevel', percent, tr('You have %s percent to go', 100 - percent))

    onBaseMagicLevelChange(localPlayer, localPlayer:getBaseMagicLevel())
end

function onBaseMagicLevelChange(localPlayer, baseMagicLevel)
    setSkillBase('magiclevel', localPlayer:getMagicLevel(), baseMagicLevel)
end

function onSkillChange(localPlayer, id, level, percent)
    setSkillValue('skillId' .. id, level)
    setSkillPercent('skillId' .. id, percent, tr('You have %s percent to go', 100 - percent))

    onBaseSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))

    if id > Skill.ManaLeechAmount then
	    toggleSkill('skillId' .. id, level > 0)
    end
end

function onBaseSkillChange(localPlayer, id, baseLevel)
    setSkillBase('skillId' .. id, localPlayer:getSkillLevel(id), baseLevel)
end
