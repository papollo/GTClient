-- Run from the repository root: lua tools/test_journal.lua
-- Headless regression checks; visual layout still requires the client.
dofile('modules/gamelib/const.lua')

local events = {}
function addEvent(callback)
    local event = { callback = callback }
    events[#events + 1] = event
    return event
end
function removeEvent(event) event.cancelled = true end
function signalcall(callback) if callback then callback() end end
local function flush()
    local pending = events
    events = {}
    for _, event in ipairs(pending) do
        if not event.cancelled then event.callback() end
    end
end
function tr(text, ...) return string.format(text, ...) end
function comma_value(value) return tostring(value) end
local features = {}
local version = 1098
g_game = {
    getFeature = function(feature) return features[feature] == true end,
    getClientVersion = function() return version end
}
g_settings = { setNode = function() end }
local warnings = {}
g_logger = { warning = function(message) warnings[#warnings + 1] = message end }

dofile('modules/game_skills/skilldata.lua')
dofile('modules/game_skills/skills.lua')
-- No Skills widgets: the journal data must still update without reading UI text.
skillsWindow = {
    recursiveGetChildById = function() return nil end,
    getParent = function() return nil end,
    setParent = function() end
}

local notifications = 0
SkillData.onChange = function() notifications = notifications + 1 end
local player = {
    getLevel = function() return 22 end,
    getExperience = function() return 146751 end,
    getSkillLevel = function(_, id) return id == Skill.Strength and 41 or 65 end,
    getSkillBaseLevel = function() return 40 end,
    getSkillLevelPercent = function() return 27 end,
    getMagicLevel = function() return 12 end,
    getBaseMagicLevel = function() return 10 end,
    getMagicLevelPercent = function() return 35 end
}

onExperienceChange(player, 146751)
onLevelChange(player, 22, 30)
onHealthChange(player, 400, 540)
onManaChange(player, 108, 222)
onLearningPointsChange(player, 43)
onSkillChange(player, Skill.Strength, 41, 0)
onOneHandedBonusSkillChange(player, 7)
onTwoHandedBonusSkillChange(player, 3)
onBowBonusSkillChange(player, 2)
onCrossbowBonusSkillChange(player, 1)
onMagicLevelBonusChange(player, 4)
onLockPickSkillChange(player, 2)
onMagicCircleSkillChange(player, 3)
onAcrobaticSkillChange(player, 1)
onResistsOpcode(nil, 201, { type = 'resists', res = { fire = 25, armor = 85, physical = 12 } })
onBaseXpRateChange(player, 100)
onStaminaMultiplierChange(player, 15)
onFoodXpBoostChange(player, 10)
onAlchemyXpBoostChange(player, 5)
assert(notifications == 0, 'Packet updates must be coalesced')
flush()
assert(notifications == 1)
local snapshot = SkillData.getSnapshot()
assert(snapshot.health.text == '400' and snapshot.health.maximum == 540)
assert(snapshot.mana.text == '108' and snapshot.mana.maximum == 222)
assert(snapshot.nextLevelExperience.text == tostring(expForLevel(23) - 146751))
assert(snapshot.learningPoints.text == '43')
assert(snapshot.skillId8.text == '41' and not snapshot.skillId8.hasProgress)
assert(snapshot.skillId2.text == '72' and snapshot.skillId2.percent == 27)
assert(snapshot.skillId1.text == '68' and snapshot.skillId3.text == '67' and snapshot.skillId4.text == '66')
assert(snapshot.magiclevel.text == '16' and snapshot.magiclevel.progressTooltip:find('Learned: 4', 1, true))
assert(snapshot.lockPickSkill.text == '2/3' and snapshot.magicCircleSkill.text == '3')
assert(snapshot.acrobaticSkill.text == '1/1')
assert(snapshot.lockPickSkill.specializationRank == 2)
assert(snapshot.magicCircleSkill.specializationRank == nil)
assert(snapshot.acrobaticSkill.specializationRank == 1)
assert(SkillData.specializationRankColors[0] == '#bbbbbb')
assert(SkillData.specializationRankColors[1] == '#5ba7e1')
assert(SkillData.specializationRankColors[2] == '#bd7fda')
assert(SkillData.specializationRankColors[3] == '#e6c832')
assert(snapshot.resistFire.text == '25%' and snapshot.totalArmor.text == '85')
assert(snapshot.xpRate.text == '165%')
snapshot.health.text = 'corrupt'
assert(SkillData.getSnapshot().health.text == '400', 'A consumer must not mutate shared values')

-- Story guild opcode 222 uses stable identifiers and must preserve the last valid state.
SkillData.ensureStoryGuild()
assert(SkillData.getSnapshot().guild.text == 'No data')
local storyGuilds = {
    none = {'No guild', 'none'},
    old_shadow = {'Shadow', 'old_camp'},
    old_guard = {'Guard', 'old_camp'},
    old_fire_novice = {'Novice of Fire', 'old_camp'},
    old_fire_mage = {'Fire Mage', 'old_camp'},
    new_scraper = {'Scraper', 'new_camp'},
    new_mercenary = {'Mercenary', 'new_camp'},
    new_water_novice = {'Novice of Water', 'new_camp'},
    new_water_mage = {'Water Mage', 'new_camp'},
    swamp_novice = {'Novice', 'swamp_camp'},
    swamp_templar = {'Templar', 'swamp_camp'},
    swamp_guru = {'Guru', 'swamp_camp'}
}
for guildId, expected in pairs(storyGuilds) do
    onStoryGuildOpcode(nil, 222, { action = 'state', guildId = guildId })
    local guild = SkillData.getSnapshot().guild
    assert(guild.text == expected[1] and guild.storyGuildId == guildId)
    assert(guild.storyCampId == expected[2])
end
onStoryGuildOpcode(nil, 222, { action = 'state', guildId = 'swamp_guru' })
onStoryGuildOpcode(nil, 222, { action = 'state', guildId = 'unknown' })
onStoryGuildOpcode(nil, 222, { action = 'other', guildId = 'old_shadow' })
onStoryGuildOpcode(nil, 222, { action = 'state' })
onStoryGuildOpcode(nil, 222, 'invalid')
local lastGuild = SkillData.getSnapshot().guild
assert(lastGuild.storyGuildId == 'swamp_guru' and #warnings == 4)
SkillData.ensureStoryGuild()
assert(SkillData.getSnapshot().guild.storyGuildId == 'swamp_guru', 'Refresh must preserve the received guild')

features[GameEnterGameShowAppearance] = true
features[GameAdditionalSkills] = true
onSkillChange(player, Skill.CriticalChance, 1250, 0)
onSkillChange(player, Skill.Momentum, 100, 0)
assert(SkillData.getSnapshot().skillId15.text == '12.5%')
assert(not SkillData.getSnapshot().skillId23.visible, 'Version-gated skills must stay hidden on live updates')
version = 1332
onSkillChange(player, Skill.Momentum, 100, 0)
assert(SkillData.getSnapshot().skillId23.visible)
onSkillChange(player, Skill.Momentum, 0, 0)
assert(not SkillData.getSnapshot().skillId23.visible)
update()
assert(not SkillData.getSnapshot().offlineTraining.visible)
features[GameOfflineTrainingTime] = true
update()
assert(SkillData.getSnapshot().offlineTraining.visible)

-- Logout cancels pending data notifications and clears previous-character bonuses.
local beforeLogout = notifications
offline()
assert(next(SkillData.getSnapshot()) == nil)
flush()
assert(notifications == beforeLogout + 1)
SkillData.ensureStoryGuild()
assert(SkillData.getSnapshot().guild.text == 'No data' and SkillData.getSnapshot().guild.storyGuildId == nil)
onOneHandedSkillChange(player)
assert(SkillData.getSnapshot().skillId2.text == '65')
onMagicLevelChange(player)
assert(SkillData.getSnapshot().magiclevel.text == '12')
onResistsOpcode(nil, 201, { type = 'resists', res = { ice = 10 } })
assert(SkillData.getSnapshot().resistFire.text == '0%')
assert(SkillData.getSnapshot().totalArmor.text == '0')
onResistsOpcode(nil, 201, { type = 'other', res = { fire = 90 } })
assert(SkillData.getSnapshot().resistFire.text == '0%')

-- Skills rows are represented once, except the general statistics kept only in Skills.
local skillsOnly = {
    xpRate = true, soul = true, capacity = true, speed = true,
    regenerationTime = true, stamina = true, offlineTraining = true
}
local ids = {}
for _, group in ipairs(SkillData.groups) do
    for _, row in ipairs(group.rows) do
        assert(not ids[row[1]], 'Duplicate row: ' .. row[1])
        ids[row[1]] = true
    end
end
local file = assert(io.open('modules/game_skills/skills.otui', 'r'))
local otui = file:read('*a')
file:close()
assert(not otui:find("tr('Specialization')", 1, true))
for _, title in ipairs({'Specialization', 'AttributesLabel', 'Critical Damage:', 'MagicLabel', 'Resistance:'}) do
    assert(not otui:find("tr('" .. title .. "')", 1, true), 'Section still visible in Skills: ' .. title)
end
for _, id in ipairs({
    'lockPickSkill', 'breakLockSkill', 'pickPocketSkill', 'smithSkill', 'miningSkill',
    'cookingSkill', 'huntingSkill', 'bowmasterSkill', 'acrobaticSkill', 'alchemySkill',
    'skillId8', 'skillId9', 'skillId15', 'skillId16', 'skillId22', 'totalArmor',
    'resistFire', 'resistIce', 'resistPoison', 'resistPhysical', 'magiclevel', 'magicCircleSkill',
    'learningPoints', 'health', 'mana', 'soul', 'capacity', 'speed'
}) do
    assert(not otui:find('id: ' .. id, 1, true), 'Removed row still visible in Skills: ' .. id)
end
for id in otui:gmatch('    [^\n]*SkillButton%s*\n%s*id: ([%w]+)') do
    assert(ids[id] or skillsOnly[id], 'Missing Skills row: ' .. id)
end
for id in otui:gmatch('    SkillButton%s*\n%s*margin%-top: [^\n]+\n%s*id: ([%w]+)') do
    assert(ids[id] or skillsOnly[id], 'Missing Skills row: ' .. id)
end
for id in pairs(skillsOnly) do
    assert(not ids[id], 'Skills-only row in journal: ' .. id)
end
print('PASS: journal data, bonuses, percentages, feature gates, logout, and Skills coverage')

-- Exercise the actual journal controller with a small headless widget tree.
local Widget = {}
local function node(children)
    local widget = setmetatable({ children = {}, visible = true, text = '', checked = false }, { __index = Widget })
    for id, child in pairs(children or {}) do
        child.id, child.parent = id, widget
        widget[id] = child
        table.insert(widget.children, child)
    end
    return widget
end
function Widget:getChildById(id)
    for _, child in ipairs(self.children) do if child.id == id then return child end end
end
function Widget:recursiveGetChildById(id)
    local direct = self:getChildById(id)
    if direct then return direct end
    for _, child in ipairs(self.children) do
        local found = child:recursiveGetChildById(id)
        if found then return found end
    end
end
function Widget:getChildren() return self.children end
function Widget:hasChildren() return #self.children > 0 end
function Widget:getFocusedChild() return self.focusedChild end
function Widget:setId(id) self.id = tostring(id) end
function Widget:getId() return self.id end
function Widget:setText(value) self.text = tostring(value) end
function Widget:getText() return self.text end
function Widget:clearText() self.text = '' end
function Widget:setVisible(value) self.visible = value end
function Widget:isVisible() return self.visible and (not self.parent or self.parent:isVisible()) end
function Widget:isExplicitlyVisible() return self.visible end
function Widget:show() self.visible = true end
function Widget:hide() self.visible = false end
function Widget:setOn(value) self.on = value end
function Widget:setColor(value) self.color = value end
function Widget:setPercent(value) self.percent = value end
function Widget:setValue(value) self.value = value end
function Widget:setBackgroundColor(value) self.background = value end
function Widget:getBackgroundColor() return self.background end
function Widget:setImageColor(value) self.imageColor = value end
function Widget:setTooltip(value) self.tooltip = value end
function Widget:setChecked(value)
    local changed = self.checked ~= value
    self.checked = value
    if changed and self.onCheckChange then self.onCheckChange(self, value) end
end
function Widget:isChecked() return self.checked end
function Widget:destroyChildren() self.children, self.focusedChild = {}, nil end
function Widget:moveChildToIndex(child, index)
    for i, existing in ipairs(self.children) do
        if existing == child then table.remove(self.children, i) break end
    end
    table.insert(self.children, index, child)
end
function Widget:addOption() end
function Widget:setCurrentOption() end
function Widget:centerIn() end
function Widget:raise() end
function Widget:focus() end
function Widget:setPhantom() end
function Widget:setFocusable() end
function Widget:setIcon() end

local journal = node({
    characterTab = node(), questsTab = node(), trackerButton = node(),
    characterPanel = node({left = node(), right = node(), leftScroll = node(), rightScroll = node()}),
    panelQuestLog = node({
        areaPanelQuestList = node({questList = node()}), comboBoxFilter = node(),
        textEditSearchQuest = node({SearchEdit = node()}),
        filterPanel = node({checkboxShowComplete = node(), checkboxShowShidden = node(),
            lblCompleteNumber = node(), lblHiddenNumber = node()})
    }),
    panelQuestLineSelected = node({ScrollAreaQuestList = node({questList = node()}),
        panelQuestInfo = node({questList = node()}), checkboxShowInQuestTracker = node()})
})
journal.panelQuestLog.filterPanel.checkboxShowComplete.checked = true
-- Use the real constructor and UI loader, including startup without a current module.
g_modules = { getCurrentModule = function() return nil end }
dofile('modules/modulelib/controller.lua')
function Controller:registerEvents(actor, callbacks)
    for name, callback in pairs(callbacks) do actor[name] = callback end
end
g_ui = {
    importStyle = function() end,
    getRootWidget = function() return nil end,
    loadUI = function(path)
        assert(path == '/game_questlog/journal', 'Unexpected journal UI path: ' .. tostring(path))
        return journal
    end,
    createWidget = function(style, parent)
        local widget
        if style == 'JournalStat' then widget = node({name = node(), value = node(), progress = node()})
        elseif style == 'JournalSection' then
            widget = node({title = node()})
            widget.isJournalSection = true
        elseif style == 'QuestLogLabel' then widget = node({iconPin = node(), iconShow = node()})
        else error('Unexpected widget (including unwanted tracker): ' .. style) end
        widget.parent = parent
        table.insert(parent.children, widget)
        return widget
    end
}
local journalButton = node()
modules = { game_skills = { SkillData = SkillData }, game_mainpanel = {
    addToggleButton = function() return journalButton end
} }
local keybindCallback
Keybind = { new = function() end, bind = function(_, _, callbacks) keybindCallback = callbacks[1].callback end }
KEY_DOWN = 1
local requests = 0
g_game.isOnline = function() return true end
g_game.getCharacterName = function() return 'Test character' end
g_game.requestQuestLog = function() requests = requests + 1 end
version = 1098
SkillData.reset()
SkillData.set('health', { text = '400', maximum = 540 })
SkillData.set('lockPickSkill', { text = '2/3', specializationRank = 2 })
dofile('modules/game_questlog/game_questlog.lua')
questLogController:onInit()
show()
assert(journal.characterPanel.visible and not journal.panelQuestLog.visible and requests == 0)
local healthRow = journal.characterPanel.left:recursiveGetChildById('health')
assert(healthRow.value.text == '400 / 540')
local specializationRow = journal.characterPanel.right:recursiveGetChildById('lockPickSkill')
assert(specializationRow.value.text == 'Expert')
assert(specializationRow.value.color == '#bd7fda')
onHealthChange(player, 250, 540)
flush()
assert(healthRow.value.text == '250 / 540')
assert(healthRow.parent.isJournalSection)
assert(healthRow.parent.title.text == 'AttributesLabel')
assert(journal.characterPanel.right.children[1].title.text == 'FightingLabel')
assert(journal.characterPanel.right.children[2].title.text == 'Additional combat statistics')
questLogController:selectTab('quests')
assert(requests == 1 and not journal.characterPanel.visible)
questLogController:selectTab('character')
local quests = {{1, 'Find [the letter]', false}, {2, 'Completed quest', true}}
g_game.onQuestLog(quests)
assert(journal.characterPanel.visible, 'A late quest response must not select the quests tab')
assert(journal.panelQuestLog.filterPanel.lblCompleteNumber.text == 'Completed: 1')
local list = journal.panelQuestLog.areaPanelQuestList.questList
local quest = list:getChildById('1')
quest.isPinned, quest.isHiddenQuestLog = true, true
g_game.onQuestLog(quests)
quest = list:getChildById('1')
assert(quest.isPinned and quest.isHiddenQuestLog and not quest.visible)
assert(list.children[1] == quest)
journal.panelQuestLog.filterPanel.checkboxShowShidden:setChecked(true)
filterQuestList('[')
assert(quest.visible and not list:getChildById('2').visible)
show('quests')
assert(requests == 2 and journal.panelQuestLog.visible and not journal.characterPanel.visible)
keybindCallback()
assert(not journal.visible and not journalButton.on)
keybindCallback()
assert(journal.visible and journal.panelQuestLog.visible and requests == 3)
questLogController:onGameEnd()
assert(#list.children == 0 and not journal.visible)
show()
assert(journal.characterPanel.visible and requests == 3)
g_game.onQuestLog({})
assert(journal.panelQuestLog.filterPanel.lblCompleteNumber.text == 'Completed: 0')
print('PASS: journal tabs, live updates, late/empty quest responses, filters, pins, shortcut, and session reset')
