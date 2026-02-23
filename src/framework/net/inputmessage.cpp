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

#include "inputmessage.h"
#include <framework/util/crypt.h>
#include <framework/stdext/string.h>

namespace {
bool looksLikeMojibake(std::string_view text)
{
    // Typical broken UTF-8 markers visible as Latin-1 glyphs.
    return text.find("Ã") != std::string_view::npos
        || text.find("Å") != std::string_view::npos
        || text.find("Ä") != std::string_view::npos
        || text.find("Ë") != std::string_view::npos
        || text.find("Â") != std::string_view::npos;
}

std::string utf8ToCp1250Polish(std::string_view text)
{
    std::string out;
    out.reserve(text.size());

    for (size_t i = 0; i < text.size(); ++i) {
        const uint8_t c = static_cast<uint8_t>(text[i]);
        if (c < 0x80) {
            out.push_back(static_cast<char>(c));
            continue;
        }

        if (i + 1 >= text.size()) {
            break;
        }

        const uint8_t c2 = static_cast<uint8_t>(text[i + 1]);
        if (c == 0xC3) {
            out.push_back(static_cast<char>(c2 + 64));
            ++i;
            continue;
        }

        if (c == 0xC4) {
            switch (c2) {
                case 0x84: out.push_back(static_cast<char>(0xA5)); ++i; continue; // Ą
                case 0x85: out.push_back(static_cast<char>(0xB9)); ++i; continue; // ą
                case 0x86: out.push_back(static_cast<char>(0xC6)); ++i; continue; // Ć
                case 0x87: out.push_back(static_cast<char>(0xE6)); ++i; continue; // ć
                case 0x98: out.push_back(static_cast<char>(0xCA)); ++i; continue; // Ę
                case 0x99: out.push_back(static_cast<char>(0xEA)); ++i; continue; // ę
                default: break;
            }
        } else if (c == 0xC5) {
            switch (c2) {
                case 0x81: out.push_back(static_cast<char>(0xA3)); ++i; continue; // Ł
                case 0x82: out.push_back(static_cast<char>(0xB3)); ++i; continue; // ł
                case 0x83: out.push_back(static_cast<char>(0xD1)); ++i; continue; // Ń
                case 0x84: out.push_back(static_cast<char>(0xF1)); ++i; continue; // ń
                case 0x9A: out.push_back(static_cast<char>(0x8C)); ++i; continue; // Ś
                case 0x9B: out.push_back(static_cast<char>(0x9C)); ++i; continue; // ś
                case 0xB9: out.push_back(static_cast<char>(0x8F)); ++i; continue; // Ź
                case 0xBA: out.push_back(static_cast<char>(0x9F)); ++i; continue; // ź
                case 0xBB: out.push_back(static_cast<char>(0xAF)); ++i; continue; // Ż
                case 0xBC: out.push_back(static_cast<char>(0xBF)); ++i; continue; // ż
                default: break;
            }
        }

        out.push_back('?');
        while (i + 1 < text.size() && (static_cast<uint8_t>(text[i + 1]) & 0xC0) == 0x80) {
            ++i;
        }
    }

    return out;
}
}

void InputMessage::reset()
{
    m_messageSize = 0;
    m_readPos = MAX_HEADER_SIZE;
    m_headerPos = MAX_HEADER_SIZE;
}

void InputMessage::setBuffer(const std::string& buffer)
{
    const int len = buffer.size();
    reset();
    checkWrite(len);
    memcpy(m_buffer + m_readPos, buffer.data(), len);
    m_readPos += len;
    m_messageSize += len;
}

uint8_t InputMessage::getU8()
{
    checkRead(1);
    const uint8_t v = m_buffer[m_readPos];
    m_readPos += 1;
    return v;
}

uint16_t InputMessage::getU16()
{
    checkRead(2);
    const uint16_t v = stdext::readULE16(m_buffer + m_readPos);
    m_readPos += 2;
    return v;
}

uint32_t InputMessage::getU32()
{
    checkRead(4);
    const uint32_t v = stdext::readULE32(m_buffer + m_readPos);
    m_readPos += 4;
    return v;
}

uint64_t InputMessage::getU64()
{
    checkRead(8);
    const uint64_t v = stdext::readULE64(m_buffer + m_readPos);
    m_readPos += 8;
    return v;
}

int64_t InputMessage::get64()
{
    checkRead(8);
    const int64_t v = stdext::readSLE64(m_buffer + m_readPos);
    m_readPos += 8;
    return v;
}

std::string InputMessage::getString()
{
    const uint16_t stringLength = getU16();
    checkRead(stringLength);
    const char* v = (char*)(m_buffer + m_readPos);
    m_readPos += stringLength;
    std::string text(v, stringLength);
    if (stdext::is_valid_utf8(text)) {
        // Fix common mojibake case where UTF-8 bytes were re-encoded once more
        // (e.g. "którym" -> "ktÃ³rym").
        if (looksLikeMojibake(text)) {
            auto maybeDoubleEncoded = stdext::utf8_to_latin1(text);
            if (stdext::is_valid_utf8(maybeDoubleEncoded)) {
                text = maybeDoubleEncoded;
            }
        }
        text = utf8ToCp1250Polish(text);
    }
    return text;
}

double InputMessage::getDouble()
{
    const uint8_t precision = getU8();
    const int32_t v = getU32() - INT_MAX;
    return (v / std::pow(10.f, precision));
}

bool InputMessage::decryptRsa(const int size)
{
    checkRead(size);
    g_crypt.rsaDecrypt(static_cast<uint8_t*>(m_buffer) + m_readPos, size);
    return (getU8() == 0x00);
}

void InputMessage::fillBuffer(const uint8_t* buffer, const uint16_t size)
{
    checkWrite(m_readPos + size);
    memcpy(m_buffer + m_readPos, buffer, size);
    m_messageSize += size;
}

void InputMessage::setHeaderSize(const uint16_t size)
{
    assert(MAX_HEADER_SIZE - size >= 0);
    m_headerPos = MAX_HEADER_SIZE - size;
    m_readPos = m_headerPos;
}

bool InputMessage::readChecksum()
{
    const uint32_t receivedCheck = getU32();
    const uint32_t checksum = stdext::adler32(m_buffer + m_readPos, getUnreadSize());
    return receivedCheck == checksum;
}

bool InputMessage::canRead(const int bytes) const
{
    if ((m_readPos - m_headerPos + bytes > m_messageSize) || (m_readPos + bytes > BUFFER_MAXSIZE))
        return false;
    return true;
}
void InputMessage::checkRead(const int bytes)
{
    if (!canRead(bytes))
        throw stdext::exception("InputMessage eof reached");
}

void InputMessage::checkWrite(const int bytes)
{
    if (bytes > BUFFER_MAXSIZE)
        throw stdext::exception("InputMessage max buffer size reached");
}
