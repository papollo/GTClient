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

#include "mouse.h"
#include <framework/core/resourcemanager.h>
#include <framework/platform/platformwindow.h>
#include <framework/ui/uiwidget.h>

Mouse g_mouse;

void Mouse::init() {}

void Mouse::terminate()
{
    m_cursors.clear();
}

void Mouse::loadCursors(const std::string& filename)
{
    const auto& path = g_resources.guessFilePath(filename, "otml");
    try {
        const auto& doc = OTMLDocument::parse(path);
        const auto& cursorsNode = doc->at("Cursors");

        for (const auto& cursorNode : cursorsNode->children())
            addCursor(cursorNode->tag(),
                      stdext::resolve_path(cursorNode->valueAt("image"), cursorNode->source()),
                      cursorNode->valueAt<Point>("hot-spot"));
    } catch (stdext::exception& e) {
        g_logger.error("unable to load cursors file: {}", e.what());
    }
}

void Mouse::addCursor(const std::string& name, const std::string& file, const Point& hotSpot)
{
    const int cursorId = g_window.loadMouseCursor(file, hotSpot);
    if (cursorId >= 0) {
        m_cursors[name] = cursorId;
    } else
        g_logger.error("unable to load cursor {}", name);
}

bool Mouse::pushCursor(const std::string& name)
{
    const auto it = m_cursors.find(name);
    if (it == m_cursors.end())
        return false;

    const int cursorId = it->second;
    g_window.setMouseCursor(cursorId);
    m_cursorStack.push_back(cursorId);
    return true;
}

void Mouse::popCursor(const std::string& name)
{
    if (m_cursorStack.empty())
        return;

    if (name.empty() || !m_cursors.contains(name))
        m_cursorStack.pop_back();
    else {
        const int cursorId = m_cursors[name];
        int index = -1;
        for (uint32_t i = 0; i < m_cursorStack.size(); ++i) {
            if (m_cursorStack[i] == cursorId)
                index = i;
        }
        if (index >= 0)
            m_cursorStack.erase(m_cursorStack.begin() + index);
        else
            return;
    }

    if (!m_cursorStack.empty())
        g_window.setMouseCursor(m_cursorStack.back());
    else
        g_window.restoreMouseCursor();
}

bool Mouse::isCursorChanged()
{
    return !m_cursorStack.empty();
}

bool Mouse::isPressed(const Fw::MouseButton mouseButton)
{
    return g_window.isMouseButtonPressed(mouseButton);
}

void Mouse::checkStackSize()
{
    if (m_cursorStack.size() > 5) {
        g_logger.error("mouse cursor stack is too long");
        m_cursorStack.pop_front();
    }
}