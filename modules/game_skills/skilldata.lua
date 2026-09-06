-- Shared presentation data. Neither consumer reads values from the other view.
SkillData = { values = {} }
local changeEvent

SkillData.specializationRanks = {
    [0] = 'None',
    [1] = 'Adept',
    [2] = 'Expert',
    [3] = 'Master'
}

-- Text variants of the blue, purple and yellow item-rarity palette.
SkillData.specializationRankColors = {
    [0] = '#bbbbbb',
    [1] = '#5ba7e1',
    [2] = '#bd7fda',
    [3] = '#e6c832'
}

-- Story guilds are separate from the standard TFS guild membership system.
-- The identifiers and camp metadata mirror the server contract for opcode 222.
SkillData.storyGuilds = {
    none = { label = 'No guild', campId = 'none' },
    old_shadow = { label = 'Shadow', campId = 'old_camp' },
    old_guard = { label = 'Guard', campId = 'old_camp' },
    old_fire_novice = { label = 'Novice of Fire', campId = 'old_camp' },
    old_fire_mage = { label = 'Fire Mage', campId = 'old_camp' },
    new_scraper = { label = 'Scraper', campId = 'new_camp' },
    new_mercenary = { label = 'Mercenary', campId = 'new_camp' },
    new_water_novice = { label = 'Novice of Water', campId = 'new_camp' },
    new_water_mage = { label = 'Water Mage', campId = 'new_camp' },
    swamp_novice = { label = 'Novice', campId = 'swamp_camp' },
    swamp_templar = { label = 'Templar', campId = 'swamp_camp' },
    swamp_guru = { label = 'Guru', campId = 'swamp_camp' }
}

SkillData.groups = {
    { title = 'Character', column = 'left', rows = {
        {'characterName', 'Name'}, {'guild', 'Guild'}, {'level', 'Level'},
        {'experience', 'Experience'}, {'nextLevelExperience', 'Experience to next level'},
        {'learningPoints', 'LearningPoints'}
    }},
    { title = 'AttributesLabel', column = 'left', rows = {
        {'skillId8', 'Strength'}, {'skillId9', 'Agility'},
        {'health', 'Hit Points'}, {'mana', 'Mana'}
    }},
    { title = 'Resistance:', column = 'left', rows = {
        {'totalArmor', 'Armor:'}, {'resistFire', 'Fire:'}, {'resistIce', 'Ice:'},
        {'resistPoison', 'Poison:'}, {'resistPhysical', 'Damage:'}, {'skillId22', 'Dodge Chance:'}
    }},
    { title = 'FightingLabel', column = 'right', rows = {
        {'skillId0', 'Fist Fighting'}, {'skillId2', 'One handed'}, {'skillId1', 'Two handed'},
        {'skillId3', 'Bow Fighting'}, {'skillId4', 'Crossbow Fighting'}, {'skillId5', 'Shielding'}
    }},
    { title = 'Additional combat statistics', column = 'right', rows = {
        {'skillId15', 'Critical hit chance'}, {'skillId16', 'Critical hit damage'},
        {'skillId17', 'Life Leech Chance'}, {'skillId18', 'Life Leech Amount'},
        {'skillId19', 'Mana Leech Chance'}, {'skillId20', 'Mana Leech Amount'},
        {'skillId21', 'Fatal'}, {'skillId23', 'Momentum'}, {'skillId24', 'Transcendence'}
    }},
    { title = 'MagicLabel', column = 'right', rows = {
        {'magiclevel', 'Magic Level'}, {'magicCircleSkill', 'MagicCircleSkill'}
    }},
    { title = 'Specialization', column = 'right', rows = {
        {'lockPickSkill', 'LockPickSkill'}, {'breakLockSkill', 'BreakLockSkill'},
        {'pickPocketSkill', 'PickPocketSkill'}, {'smithSkill', 'SmithSkill'},
        {'miningSkill', 'MiningSkill'}, {'cookingSkill', 'CookingSkill'},
        {'huntingSkill', 'HuntingSkill'}, {'bowmasterSkill', 'BowmasterSkill'},
        {'acrobaticSkill', 'AcrobaticSkill'}, {'alchemySkill', 'AlchemySkill'}
    }},
    { title = 'SkillExperience', column = 'right', rows = {
        {'skillId6', 'Fishing'}, {'skillId7', 'Mining'}, {'skillId10', 'Cooking'},
        {'skillId11', 'Alchemy'}, {'skillId12', 'Smithing'}, {'skillId13', 'Hunting'},
        {'skillId14', 'Bowmastery'}
    }}
}

local hiddenByDefault = {
    skillId0 = true, skillId5 = true, skillId17 = true, skillId18 = true,
    skillId19 = true, skillId20 = true
}
local progressRows = {
    level = true, magiclevel = true, stamina = true, offlineTraining = true
}
for id = Skill.Fist, Skill.Bowmastery do
    if id ~= Skill.Strength and id ~= Skill.Agility then
        progressRows['skillId' .. id] = true
    end
end

function SkillData.set(id, changes)
    local state = SkillData.values[id] or {
        text = '', color = '#bbbbbb', visible = not hiddenByDefault[id],
        hasProgress = progressRows[id] == true,
        progressColor = (id == 'level' or id == 'stamina' or id == 'offlineTraining') and 'red' or '#008b00'
    }
    local changed = SkillData.values[id] == nil
    for key, value in pairs(changes) do
        if state[key] ~= value then
            state[key] = value
            changed = true
        end
    end
    SkillData.values[id] = state
    if changed and not changeEvent then
        -- Coalesce the value, colour and progress changes of a single packet.
        changeEvent = addEvent(function()
            changeEvent = nil
            signalcall(SkillData.onChange)
        end)
    end
    return state
end

function SkillData.getSnapshot()
    local snapshot = {}
    for id, state in pairs(SkillData.values) do
        snapshot[id] = {}
        for key, value in pairs(state) do
            snapshot[id][key] = value
        end
    end
    return snapshot
end

function SkillData.ensureStoryGuild()
    if not SkillData.values.guild then
        SkillData.set('guild', { text = tr('No data') })
    end
end

function SkillData.setStoryGuild(guildId)
    local definition = SkillData.storyGuilds[guildId]
    if not definition then
        return false
    end

    SkillData.set('guild', {
        text = tr(definition.label),
        storyGuildId = guildId,
        storyCampId = definition.campId
    })
    return true
end

function SkillData.reset()
    if changeEvent then
        removeEvent(changeEvent)
        changeEvent = nil
    end
    SkillData.values = {}
    signalcall(SkillData.onChange)
end
