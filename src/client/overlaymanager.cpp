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

#include "map.h"
#include "thing.h"

#include <framework/core/clock.h>

OverlayManager g_overlayManager;

void OverlayManager::addOverlay(const std::string& id, const Position& pos, const uint16_t intervalMs, const uint16_t effectId, const uint32_t durationMs, const uint16_t radius)
{
    OverlayEntry entry;
    if (const auto it = m_overlays.find(id); it != m_overlays.end())
        entry = it->second;

    entry.pos = pos;
    entry.intervalMs = intervalMs;
    entry.effectId = effectId;
    entry.durationMs = durationMs;
    entry.radius = radius;
    entry.nextTriggerMs = g_clock.millis();
    if (durationMs > 0) {
        entry.expiresAtMs = g_clock.millis() + durationMs;
    } else {
        entry.expiresAtMs = 0;
    }

    m_overlays[id] = entry;
}

void OverlayManager::removeOverlay(const std::string& id)
{
    const auto it = m_overlays.find(id);
    if (it == m_overlays.end())
        return;

    for (const auto& effect : it->second.activeEffects) {
        if (effect)
            g_map.removeThing(std::static_pointer_cast<Thing>(effect));
    }

    m_overlays.erase(it);
}

void OverlayManager::clear()
{
    for (const auto& [id, overlay] : m_overlays) {
        (void)id;
        for (const auto& effect : overlay.activeEffects) {
            if (effect)
                g_map.removeThing(std::static_pointer_cast<Thing>(effect));
        }
    }
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
