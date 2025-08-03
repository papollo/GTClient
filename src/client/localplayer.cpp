/*
 * Copyright (c) 2010-2025 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "localplayer.h"
#include "game.h"
#include "map.h"
#include "tile.h"
#include <framework/core/eventdispatcher.h>

void LocalPlayer::lockWalk(const uint16_t millis)
{
    m_walkLockExpiration = std::max<ticks_t>(m_walkLockExpiration, g_clock.millis() + millis);
}

bool LocalPlayer::canWalk(const bool ignoreLock)
{
    // Prevent movement if the player is dead
    if (isDead())
        return false;

    // Prevent movement if walking is locked, unless ignored
    if (isWalkLocked() && !ignoreLock)
        return false;

    // Ensure movement synchronization with the server
    if (g_game.getWalkMaxSteps() > 0) {
        if (m_preWalks.size() > g_game.getWalkMaxSteps())
            return false;
    } else if (getPosition() != getServerPosition())
        return false;

    // Handle ongoing movement cases
    if (isWalking()) {
        if (isAutoWalking()) return true;  // Allow auto-walking
        if (isPreWalking()) return false;  // Prevent pre-walk interruptions
    }

    // allow only if walk done, ex. diagonals may need additional ticks before taking another step
    return m_walkTimer.ticksElapsed() >= getStepDuration();
}

void LocalPlayer::walk(const Position& oldPos, const Position& newPos)
{
    m_autoWalkRetries = 0;

    if (isPreWalking() && newPos == m_preWalks.front()) {
        m_preWalks.pop_front();
        return;
    }

    cancelAjustInvalidPosEvent();
    m_preWalks.clear();
    m_serverWalk = true;

    Creature::walk(oldPos, newPos);
}

void LocalPlayer::preWalk(Otc::Direction direction)
{
    m_lastMapDuration = -1;

    const auto& oldPos = getPosition();
    Creature::walk(oldPos, m_preWalks.emplace_back(oldPos.translatedToDirection(direction)));

    cancelAjustInvalidPosEvent();
    m_ajustInvalidPosEvent = g_dispatcher.scheduleEvent([this, self = asLocalPlayer()] {
        m_preWalks.clear();
        g_game.resetMapUpdatedAt();
        m_ajustInvalidPosEvent = nullptr;
    }, std::min<int>(std::max<int>(getStepDuration(), g_game.getPing()) + 100, 1000));
}

void LocalPlayer::onWalking() {
    if (isPreWalking()) {
        if (const auto& tile = g_map.getTile(getPosition())) {
            for (const auto& creature : tile->getWalkingCreatures()) {
                // Cancel pre-walk movement if the local player tries to walk on an unwalkable tile.
                if (creature.get() != this && creature->getPosition() == getPosition()) {
                    cancelWalk();
                    g_map.notificateTileUpdate(getPosition(), asLocalPlayer(), Otc::OPERATION_CLEAN);
                    break;
                }
            }
        }
    }
}

void LocalPlayer::cancelAjustInvalidPosEvent() {
    if (!m_ajustInvalidPosEvent) return;
    m_ajustInvalidPosEvent->cancel();
    m_ajustInvalidPosEvent = nullptr;
}

bool LocalPlayer::retryAutoWalk()
{
    if (!m_autoWalkDestination.isValid()) {
        return false;
    }

    g_game.stop();

    if (m_autoWalkRetries <= 3) {
        if (m_autoWalkContinueEvent)
            m_autoWalkContinueEvent->cancel();

        m_autoWalkContinueEvent = g_dispatcher.scheduleEvent(
            [thisPtr = asLocalPlayer(), autoWalkDest = m_autoWalkDestination] { thisPtr->autoWalk(autoWalkDest, true); }, 200
        );

        m_autoWalkRetries += 1;

        return true;
    }

    m_autoWalkDestination = {};
    return false;
}

void LocalPlayer::cancelWalk(const Otc::Direction direction)
{
    // only cancel client side walks
    if (isWalking() && isPreWalking())
        stopWalk();

    g_map.notificateCameraMove(m_walkOffset);

    if (m_ajustInvalidPosEvent) {
        m_ajustInvalidPosEvent->execute();
    }

    lockWalk();
    if (retryAutoWalk()) return;

    // turn to the cancel direction
    if (direction != Otc::InvalidDirection)
        setDirection(direction);

    callLuaField("onCancelWalk", direction);
}

bool LocalPlayer::autoWalk(const Position& destination, const bool retry)
{
    // reset state
    m_autoWalkDestination = {};
    m_lastAutoWalkPosition = {};
    if (m_autoWalkContinueEvent)
        m_autoWalkContinueEvent->cancel();
    m_autoWalkContinueEvent = nullptr;

    if (!retry)
        m_autoWalkRetries = 0;

    if (destination == m_position)
        return true;

    m_autoWalkDestination = destination;

    g_map.findPathAsync(m_position, destination, [self = asLocalPlayer()](const auto& result) {
        if (self->m_autoWalkDestination != result->destination)
            return;

        if (result->status != Otc::PathFindResultOk) {
            if (self->m_autoWalkRetries > 0 && self->m_autoWalkRetries <= 3) { // try again in 300, 700, 1200 ms if canceled by server
                self->m_autoWalkContinueEvent = g_dispatcher.scheduleEvent([self, capture0 = result->destination] { self->autoWalk(capture0, true); }, 200 + self->m_autoWalkRetries * 100);
                return;
            }
            self->m_autoWalkDestination = {};
            self->callLuaField("onAutoWalkFail", result->status);
            return;
        }

        if (result->path.size() > 127)
            result->path.resize(127);

        if (result->path.empty()) {
            self->m_autoWalkDestination = {};
            self->callLuaField("onAutoWalkFail", result->status);
            return;
        }

        if (self->m_autoWalkDestination != result->destination) {
            self->m_lastAutoWalkPosition = result->destination;
        }

        g_game.autoWalk(result->path, result->start);
    });

    if (!retry)
        lockWalk();

    return true;
}

void LocalPlayer::stopAutoWalk()
{
    m_autoWalkDestination = {};
    m_lastAutoWalkPosition = {};
    m_knownCompletePath = false;

    if (m_autoWalkContinueEvent)
        m_autoWalkContinueEvent->cancel();
}

void LocalPlayer::terminateWalk()
{
    Creature::terminateWalk();
    m_serverWalk = false;
    callLuaField("onWalkFinish");
}

void LocalPlayer::onPositionChange(const Position& newPos, const Position& oldPos)
{
    Creature::onPositionChange(newPos, oldPos);

    if (newPos == m_autoWalkDestination)
        stopAutoWalk();
    else if (m_autoWalkDestination.isValid() && newPos == m_lastAutoWalkPosition)
        autoWalk(m_autoWalkDestination);

    m_serverWalk = false;
}

void LocalPlayer::setStates(const uint32_t states)
{
    if (m_states == states)
        return;

    const uint32_t oldStates = m_states;
    m_states = states;

    if (isParalyzed())
        m_walkTimer.update(-getStepDuration());

    callLuaField("onStatesChange", states, oldStates);
}

void LocalPlayer::setSkill(const Otc::Skill skillId, const uint16_t level, const uint16_t levelPercent)
{
    if (skillId >= Otc::LastSkill) {
        g_logger.traceError("invalid skill");
        return;
    }

    auto& skill = m_skills[skillId];

    const uint16_t oldLevel = skill.level;
    const uint16_t oldLevelPercent = skill.levelPercent;

    if (level == oldLevel && levelPercent == oldLevelPercent)
        return;

    skill.level = level;
    skill.levelPercent = levelPercent;

    callLuaField("onSkillChange", skillId, level, levelPercent, oldLevel, oldLevelPercent);
}

void LocalPlayer::setBaseSkill(const Otc::Skill skill, const uint16_t baseLevel)
{
    if (skill >= Otc::LastSkill) {
        g_logger.traceError("invalid skill");
        return;
    }

    const uint16_t oldBaseLevel = m_skills[skill].baseLevel;
    if (baseLevel == oldBaseLevel)
        return;

    m_skills[skill].baseLevel = baseLevel;

    callLuaField("onBaseSkillChange", skill, baseLevel, oldBaseLevel);
}

void LocalPlayer::setHealth(const uint32_t health, const uint32_t maxHealth)
{
    if (m_health != health || m_maxHealth != maxHealth) {
        const uint32_t oldHealth = m_health;
        const uint32_t oldMaxHealth = m_maxHealth;
        m_health = health;
        m_maxHealth = maxHealth;

        callLuaField("onHealthChange", health, maxHealth, oldHealth, oldMaxHealth);

        if (isDead()) {
            if (isPreWalking())
                stopWalk();
            lockWalk();
        }
    }
}

void LocalPlayer::setFreeCapacity(const uint32_t freeCapacity)
{
    if (m_freeCapacity == freeCapacity)
        return;

    const uint32_t oldFreeCapacity = m_freeCapacity;
    m_freeCapacity = freeCapacity;

    callLuaField("onFreeCapacityChange", freeCapacity, oldFreeCapacity);
}

void LocalPlayer::setTotalCapacity(const uint32_t totalCapacity)
{
    if (m_totalCapacity == totalCapacity)
        return;

    const uint32_t oldTotalCapacity = m_totalCapacity;
    m_totalCapacity = totalCapacity;

    callLuaField("onTotalCapacityChange", totalCapacity, oldTotalCapacity);
}

void LocalPlayer::setExperience(const uint64_t experience)
{
    if (m_experience == experience)
        return;

    const uint64_t oldExperience = m_experience;
    m_experience = experience;

    callLuaField("onExperienceChange", experience, oldExperience);
}

void LocalPlayer::setBaseXpRate(uint16_t rate) {
	if (m_baseXpRate == rate)
		return;

	const uint16_t oldBaseXpRate = m_baseXpRate;
    m_baseXpRate = rate;

	callLuaField("onBaseXpRateChange", rate, oldBaseXpRate);
}

void LocalPlayer::setStaminaMultiplier(uint16_t multiplier) {
    if (m_staminaMultiplier == multiplier)
        return;

    const uint16_t oldStaminaMultiplier= m_staminaMultiplier;
    m_staminaMultiplier = multiplier;

    callLuaField("onStaminaMultiplierChange", multiplier, oldStaminaMultiplier);
}

void LocalPlayer::setFoodXpBoost(uint16_t foodBoost) {
    if (m_foodXpBoost == foodBoost)
        return;

    const uint16_t oldFoodXpBoost = m_foodXpBoost;
    m_foodXpBoost = foodBoost;

    callLuaField("onFoodXpBoostChange", foodBoost, oldFoodXpBoost);
}

void LocalPlayer::setAlchemyXpBoost(uint16_t alchemyBoost) {
    if (m_alchemyXpBoost == alchemyBoost)
        return;

    const uint16_t oldAlchemyXpBoost = m_alchemyXpBoost;
    m_alchemyXpBoost = alchemyBoost;

    callLuaField("onAlchemyXpBoostChange", alchemyBoost, oldAlchemyXpBoost);
}

void LocalPlayer::setLearningPoints(uint16_t learningPoints) {
    if (m_learningPoints == learningPoints)
        return;

    const uint16_t oldLearningPoints = m_learningPoints;
    m_learningPoints = learningPoints;

    callLuaField("onLearningPointsChange", learningPoints, oldLearningPoints);
}

void LocalPlayer::setMagicLevelBonusSkill(uint8_t magicLevelBonusSkill)
{
	if (m_magicLevelBonusSkill == magicLevelBonusSkill)
		return;

    const uint8_t oldMagicLevelBonusSkill = m_magicLevelBonusSkill;
	m_magicLevelBonusSkill = magicLevelBonusSkill;

    callLuaField("onMagicLevelBonusChange", magicLevelBonusSkill, oldMagicLevelBonusSkill);
}

void LocalPlayer::setOneHandedBonusSkill(uint8_t oneHandedBonusSkill)
{
	if (m_oneHandedBonusSkill == oneHandedBonusSkill)
		return;

    const uint8_t oldOneHandedBonusSkill = m_oneHandedBonusSkill;
	m_oneHandedBonusSkill = oneHandedBonusSkill;

    callLuaField("onOneHandedBonusSkillChange", oneHandedBonusSkill, oldOneHandedBonusSkill);
}

void LocalPlayer::setTwoHandedBonusSkill(uint8_t twoHandedBonusSkill)
{
	if (m_twoHandedBonusSkill == twoHandedBonusSkill)
		return;

    const uint8_t oldTwoHandedBonusSkill = m_twoHandedBonusSkill;
	m_twoHandedBonusSkill = twoHandedBonusSkill;

    callLuaField("onTwoHandedBonusSkillChange", twoHandedBonusSkill, oldTwoHandedBonusSkill);
}

void LocalPlayer::setBowBonusSkill(uint8_t bowBonusSkill)
{
	if (m_bowBonusSkill == bowBonusSkill)
		return;

    const uint8_t oldBowBonusSkill = m_bowBonusSkill;
	m_bowBonusSkill = bowBonusSkill;

    callLuaField("onBowBonusSkillChange", bowBonusSkill, oldBowBonusSkill);
}

void LocalPlayer::setCrossbowBonusSkill(uint8_t crossbowBonusSkill)
{
	if (m_crossbowBonusSkill == crossbowBonusSkill)
		return;

    const uint8_t oldCrossbowBonusSkill = m_crossbowBonusSkill;
	m_crossbowBonusSkill = crossbowBonusSkill;

    callLuaField("onCrossbowBonusSkillChange", crossbowBonusSkill, oldCrossbowBonusSkill);
}

void LocalPlayer::setLockPickSkill(uint8_t lockPickSkill)
{
	if (m_lockPickSkill == lockPickSkill)
		return;

    const uint8_t oldLockPickSkill = m_lockPickSkill;
	m_lockPickSkill = lockPickSkill;
	
    callLuaField("onLockPickSkillChange", lockPickSkill, oldLockPickSkill);
}

void LocalPlayer::setBreakLockSkill(uint8_t breakLockSkill) 
{
	if (m_breakLockSkill == breakLockSkill)
		return;

	const uint8_t oldBreakLockSkill = m_breakLockSkill;
	m_breakLockSkill = breakLockSkill;

	callLuaField("onBreakLockSkillChange", breakLockSkill, oldBreakLockSkill);
}

void LocalPlayer::setPickPocketSkill(uint8_t pickPocketSkill)
{
	if (m_pickPocketSkill == pickPocketSkill)
		return;

	const uint8_t oldPickPocketSkill = m_pickPocketSkill;
	m_pickPocketSkill = pickPocketSkill;

	callLuaField("onPickPocketSkillChange", pickPocketSkill, oldPickPocketSkill);
}

void LocalPlayer::setSmithSkill(uint8_t smithSkill)
{
	if (m_smithSkill == smithSkill)
		return;

	const uint8_t oldSmithSkill = m_smithSkill;
	m_smithSkill = smithSkill;
	
    callLuaField("onSmithSkillChange", smithSkill, oldSmithSkill);
}

void LocalPlayer::setMiningSkill(uint8_t miningSkill)
{
	if (m_miningSkill == miningSkill)
		return;

    const uint8_t oldMiningSkill = m_miningSkill;
	m_miningSkill = miningSkill;
	
    callLuaField("onMiningSkillChange", miningSkill, oldMiningSkill);
}

void LocalPlayer::setCookingSkill(uint8_t cookingSkill)
{
	if (m_cookingSkill == cookingSkill)
		return;

    const uint8_t oldCookingSkill = m_cookingSkill;
	m_cookingSkill = cookingSkill;
	
    callLuaField("onCookingSkillChange", cookingSkill, oldCookingSkill);
}

void LocalPlayer::setHuntingSkill(uint8_t huntingSkill)
{
	if (m_huntingSkill == huntingSkill)
		return;

    const uint8_t oldHuntingSkill = m_huntingSkill;
	m_huntingSkill = huntingSkill;
	
    callLuaField("onHuntingSkillChange", huntingSkill, oldHuntingSkill);
}

void LocalPlayer::setMagicCircleSkill(uint8_t magicCircleSkill)
{
	if (m_magicCircleSkill == magicCircleSkill)
		return;

    const uint8_t oldMagicCircleSkill = m_magicCircleSkill;
	m_magicCircleSkill = magicCircleSkill;
	
    callLuaField("onMagicCircleSkillChange", magicCircleSkill, oldMagicCircleSkill);
}

void LocalPlayer::setAcrobaticSkill(uint8_t acrobaticSkill)
{
	if (m_acrobaticSkill == acrobaticSkill)
		return;

    const uint8_t oldAcrobaticSkill = m_acrobaticSkill;
	m_acrobaticSkill = acrobaticSkill;
	
    callLuaField("onAcrobaticSkillChange", acrobaticSkill, oldAcrobaticSkill);
}

void LocalPlayer::setLevel(const uint16_t level, const uint8_t levelPercent)
{
    if (m_level == level && m_levelPercent == levelPercent)
        return;

    const uint16_t oldLevel = m_level;
    const uint8_t oldLevelPercent = m_levelPercent;

    m_level = level;
    m_levelPercent = levelPercent;

    callLuaField("onLevelChange", level, levelPercent, oldLevel, oldLevelPercent);
}

void LocalPlayer::setMana(const uint32_t mana, const uint32_t maxMana)
{
    if (m_mana == mana && m_maxMana == maxMana)
        return;

    const uint32_t oldMana = m_mana;
    const uint32_t oldMaxMana = m_maxMana;
    m_mana = mana;
    m_maxMana = maxMana;

    callLuaField("onManaChange", mana, maxMana, oldMana, oldMaxMana);
}

void LocalPlayer::setMagicLevel(const uint16_t magicLevel, const uint16_t magicLevelPercent)
{
    if (m_magicLevel == magicLevel && m_magicLevelPercent == magicLevelPercent)
        return;

    const uint16_t oldMagicLevel = m_magicLevel;
    const uint16_t oldMagicLevelPercent = m_magicLevelPercent;

    m_magicLevel = magicLevel;
    m_magicLevelPercent = magicLevelPercent;

    callLuaField("onMagicLevelChange", magicLevel, magicLevelPercent, oldMagicLevel, oldMagicLevelPercent);
}

void LocalPlayer::setBaseMagicLevel(const uint16_t baseMagicLevel)
{
    if (m_baseMagicLevel == baseMagicLevel)
        return;

    const uint16_t oldBaseMagicLevel = m_baseMagicLevel;
    m_baseMagicLevel = baseMagicLevel;

    callLuaField("onBaseMagicLevelChange", baseMagicLevel, oldBaseMagicLevel);
}

void LocalPlayer::setSoul(const uint8_t soul)
{
    if (m_soul == soul)
        return;

    const uint8_t oldSoul = m_soul;
    m_soul = soul;

    callLuaField("onSoulChange", soul, oldSoul);
}

void LocalPlayer::setStamina(const uint16_t stamina)
{
    if (m_stamina == stamina)
        return;

    const uint16_t oldStamina = m_stamina;
    m_stamina = stamina;

    callLuaField("onStaminaChange", stamina, oldStamina);
}

void LocalPlayer::setInventoryItem(const Otc::InventorySlot inventory, const ItemPtr& item)
{
    if (inventory >= Otc::LastInventorySlot) {
        g_logger.traceError("invalid slot");
        return;
    }

    if (m_inventoryItems[inventory] == item)
        return;

    const auto& oldItem = m_inventoryItems[inventory];
    m_inventoryItems[inventory] = item;

    callLuaField("onInventoryChange", inventory, item, oldItem);
}

void LocalPlayer::setVocation(const uint8_t vocation)
{
    if (m_vocation == vocation)
        return;

    const uint8_t oldVocation = m_vocation;
    m_vocation = vocation;

    callLuaField("onVocationChange", vocation, oldVocation);
}

void LocalPlayer::setPremium(const bool premium)
{
    if (m_premium == premium)
        return;

    m_premium = premium;

    callLuaField("onPremiumChange", premium);
}

void LocalPlayer::setRegenerationTime(const uint16_t regenerationTime)
{
    if (m_regenerationTime == regenerationTime)
        return;

    const uint16_t oldRegenerationTime = m_regenerationTime;
    m_regenerationTime = regenerationTime;

    callLuaField("onRegenerationChange", regenerationTime, oldRegenerationTime);
}

void LocalPlayer::setOfflineTrainingTime(const uint16_t offlineTrainingTime)
{
    if (m_offlineTrainingTime == offlineTrainingTime)
        return;

    const uint16_t oldOfflineTrainingTime = m_offlineTrainingTime;
    m_offlineTrainingTime = offlineTrainingTime;

    callLuaField("onOfflineTrainingChange", offlineTrainingTime, oldOfflineTrainingTime);
}

void LocalPlayer::setSpells(const std::vector<uint16_t>& spells)
{
    if (m_spells == spells)
        return;

    const std::vector<uint16_t> oldSpells = m_spells;
    m_spells = spells;

    callLuaField("onSpellsChange", spells, oldSpells);
}

void LocalPlayer::setBlessings(const uint16_t blessings)
{
    if (blessings == m_blessings)
        return;

    const uint16_t oldBlessings = m_blessings;
    m_blessings = blessings;

    callLuaField("onBlessingsChange", blessings, oldBlessings);
}

void LocalPlayer::takeScreenshot(const uint8_t type)
{
    g_lua.callGlobalField("LocalPlayer", "onTakeScreenshot", type);
}

void LocalPlayer::setResourceBalance(const Otc::ResourceTypes_t type, const uint64_t value)
{
    const uint64_t oldBalance = getResourceBalance(type);
    if (value == oldBalance)
        return;

    m_resourcesBalance[type] = value;
    g_lua.callGlobalField("g_game", "onResourcesBalanceChange", value, oldBalance, type);
}

bool LocalPlayer::hasSight(const Position& pos)
{
    return m_position.isInRange(pos, g_map.getAwareRange().left - 1, g_map.getAwareRange().top - 1);
}