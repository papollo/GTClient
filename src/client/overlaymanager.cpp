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

#include "overlaymanager.h"

#include "effect.h"
#include "thingtypemanager.h"

#include <framework/core/clock.h>
#include <framework/graphics/texturemanager.h>

OverlayManager g_overlayManager;

namespace {
constexpr const char* kGlowTexture = "/images/icons/icon_magic_circle";
constexpr const char* kArrowTexture = "/images/ui/arrow_vertical";
constexpr const char* kSparksTexture = "/images/icons/icon_magic";
constexpr const char* kQuestTexture = "/images/game/npcicons/icon_quest";
}

void OverlayManager::addOverlay(const std::string& id, const Position& pos, const uint16_t typeId, const uint16_t effectId, const uint32_t durationMs, const uint16_t radius)
{
    OverlayEntry entry;
    if (const auto it = m_overlays.find(id); it != m_overlays.end())
        entry = it->second;

    entry.pos = pos;
    entry.typeId = typeId;
    entry.effectId = effectId;
    entry.durationMs = durationMs;
    entry.radius = radius;
    if (durationMs > 0) {
        entry.expiresAtMs = g_clock.millis() + durationMs;
    } else {
        entry.expiresAtMs = 0;
    }

    if (effectId > 0 && g_things.isValidDatId(effectId, ThingCategoryEffect)) {
        if (!entry.effect || entry.effectId != effectId) {
            entry.effect = std::make_shared<Effect>();
            entry.effect->setId(effectId);
        }

        if (entry.effect)
            entry.effect->setPosition(pos);
    } else {
        entry.effect.reset();
        entry.effectId = 0;
    }

    m_overlays[id] = entry;
}

void OverlayManager::removeOverlay(const std::string& id)
{
    m_overlays.erase(id);
}

void OverlayManager::clear()
{
    m_overlays.clear();
}

void OverlayManager::pruneExpired()
{
    if (m_overlays.empty())
        return;

    const uint64_t now = g_clock.millis();
    for (auto it = m_overlays.begin(); it != m_overlays.end();) {
        if (it->second.expiresAtMs > 0 && it->second.expiresAtMs <= now) {
            it = m_overlays.erase(it);
        } else {
            ++it;
        }
    }
}

TexturePtr OverlayManager::getTexture(const uint16_t typeId)
{
    if (const auto it = m_textures.find(typeId); it != m_textures.end())
        return it->second;

    const char* path = nullptr;
    switch (typeId) {
        case 1: path = kGlowTexture; break;
        case 2: path = kArrowTexture; break;
        case 3: path = kSparksTexture; break;
        case 4: path = kQuestTexture; break;
        default: break;
    }

    TexturePtr texture;
    if (path)
        texture = g_textures.getTexture(path);

    m_textures[typeId] = texture;
    return texture;
}
