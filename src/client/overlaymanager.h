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

#pragma once

#include "position.h"
#include "declarations.h"

#include <framework/graphics/declarations.h>

#include <cstdint>
#include <string>
#include <unordered_map>

struct OverlayEntry
{
    Position pos;
    uint16_t typeId{ 0 };
    uint16_t effectId{ 0 };
    uint32_t durationMs{ 0 };
    uint16_t radius{ 0 };
    uint64_t expiresAtMs{ 0 };
    EffectPtr effect;
};

class OverlayManager
{
public:
    void addOverlay(const std::string& id, const Position& pos, uint16_t typeId, uint16_t effectId, uint32_t durationMs, uint16_t radius);
    void removeOverlay(const std::string& id);
    void clear();

    void pruneExpired();

    const std::unordered_map<std::string, OverlayEntry>& getOverlays() const { return m_overlays; }
    TexturePtr getTexture(uint16_t typeId);

private:
    std::unordered_map<std::string, OverlayEntry> m_overlays;
    std::unordered_map<uint16_t, TexturePtr> m_textures;
};

extern OverlayManager g_overlayManager;
