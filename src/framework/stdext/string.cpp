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

#include <algorithm>
#include <array>
#include <ranges>
#include <vector>
#include <charconv>

#include "exception.h"
#include "types.h"

#ifdef _MSC_VER
#pragma warning(disable:4267) // '?' : conversion from 'A' to 'B', possible loss of data
#endif

namespace stdext
{
    [[nodiscard]] std::string resolve_path(std::string_view filePath, std::string_view sourcePath) {
        if (filePath.starts_with("/"))
            return std::string(filePath);

        auto slashPos = sourcePath.find_last_of('/');
        if (slashPos == std::string::npos)
            throw std::runtime_error("Invalid source path '" + std::string(sourcePath) + "' for file '" + std::string(filePath) + "'");

        return std::string(sourcePath.substr(0, slashPos + 1)) + std::string(filePath);
    }

    [[nodiscard]] std::string date_time_string(const char* format) {
        std::time_t tnow = std::time(nullptr);
        std::tm ts{};

        // Platform-specific time handling
#ifdef _WIN32
        localtime_s(&ts, &tnow);
#else
        localtime_r(&tnow, &ts);
#endif

        char date[20];  // Reduce buffer size based on expected format
        if (std::strftime(date, sizeof(date), format, &ts) == 0)
            throw std::runtime_error("Failed to format date-time string");

        return std::string(date);
    }

    [[nodiscard]] std::string dec_to_hex(uint64_t num) {
        char buffer[17]; // 16 characters for a uint64_t in hex + null terminator
        auto [ptr, ec] = std::to_chars(buffer, buffer + sizeof(buffer) - 1, num, 16);
        *ptr = '\0'; // Null-terminate the string
        return std::string(buffer);
    }

    [[nodiscard]] uint64_t hex_to_dec(std::string_view str) {
        uint64_t num = 0;
        auto [ptr, ec] = std::from_chars(str.data(), str.data() + str.size(), num, 16);
        if (ec != std::errc())
            throw std::runtime_error("Invalid hexadecimal input");
        return num;
    }

    [[nodiscard]] bool is_valid_utf8(std::string_view src) {
        for (size_t i = 0; i < src.size();) {
            unsigned char c = src[i];
            size_t bytes = (c < 0x80) ? 1 : (c < 0xE0) ? 2 : (c < 0xF0) ? 3 : (c < 0xF5) ? 4 : 0;
            if (!bytes || i + bytes > src.size() || (bytes > 1 && (src[i + 1] & 0xC0) != 0x80))
                return false;
            i += bytes;
        }
        return true;
    }

    [[nodiscard]] std::string utf8_to_latin1(std::string_view src) {
        std::string out;
        out.reserve(src.size()); // Reserve memory to avoid multiple allocations
        for (size_t i = 0; i < src.size(); ++i) {
            uint8_t c = static_cast<uint8_t>(src[i]);
            if ((c >= 32 && c < 128) || c == 0x0d || c == 0x0a || c == 0x09) {
                out += c;
            } else if (c == 0xc2 || c == 0xc3) {
                if (i + 1 < src.size()) {
                    uint8_t c2 = static_cast<uint8_t>(src[++i]);
                    out += (c == 0xc2) ? c2 : (c2 + 64);
                }
            } else {
                // Skip multi-byte characters
                while (i + 1 < src.size() && (src[i + 1] & 0xC0) == 0x80) {
                    ++i;
                }
            }
        }
        return out;
    }

    [[nodiscard]] std::string utf8_to_cp1250(std::string_view src) {
        static constexpr std::pair<uint32_t, uint8_t> cp1250Characters[] = {
            { 0x20AC, 0x80 }, { 0x201A, 0x82 }, { 0x201E, 0x84 }, { 0x2026, 0x85 },
            { 0x2020, 0x86 }, { 0x2021, 0x87 }, { 0x2030, 0x89 }, { 0x0160, 0x8A },
            { 0x2039, 0x8B }, { 0x015A, 0x8C }, { 0x0164, 0x8D }, { 0x017D, 0x8E },
            { 0x0179, 0x8F }, { 0x2018, 0x91 }, { 0x2019, 0x92 }, { 0x201C, 0x93 },
            { 0x201D, 0x94 }, { 0x2022, 0x95 }, { 0x2013, 0x96 }, { 0x2014, 0x97 },
            { 0x2122, 0x99 }, { 0x0161, 0x9A }, { 0x203A, 0x9B }, { 0x015B, 0x9C },
            { 0x0165, 0x9D }, { 0x017E, 0x9E }, { 0x017A, 0x9F }, { 0x00A0, 0xA0 },
            { 0x02C7, 0xA1 }, { 0x02D8, 0xA2 }, { 0x0141, 0xA3 }, { 0x00A4, 0xA4 },
            { 0x0104, 0xA5 }, { 0x00A6, 0xA6 }, { 0x00A7, 0xA7 }, { 0x00A8, 0xA8 },
            { 0x00A9, 0xA9 }, { 0x015E, 0xAA }, { 0x00AB, 0xAB }, { 0x00AC, 0xAC },
            { 0x00AD, 0xAD }, { 0x00AE, 0xAE }, { 0x017B, 0xAF }, { 0x00B0, 0xB0 },
            { 0x00B1, 0xB1 }, { 0x02DB, 0xB2 }, { 0x0142, 0xB3 }, { 0x00B4, 0xB4 },
            { 0x00B5, 0xB5 }, { 0x00B6, 0xB6 }, { 0x00B7, 0xB7 }, { 0x00B8, 0xB8 },
            { 0x0105, 0xB9 }, { 0x015F, 0xBA }, { 0x00BB, 0xBB }, { 0x013D, 0xBC },
            { 0x02DD, 0xBD }, { 0x013E, 0xBE }, { 0x017C, 0xBF }, { 0x0154, 0xC0 },
            { 0x00C1, 0xC1 }, { 0x00C2, 0xC2 }, { 0x0102, 0xC3 }, { 0x00C4, 0xC4 },
            { 0x0139, 0xC5 }, { 0x0106, 0xC6 }, { 0x00C7, 0xC7 }, { 0x010C, 0xC8 },
            { 0x00C9, 0xC9 }, { 0x0118, 0xCA }, { 0x00CB, 0xCB }, { 0x011A, 0xCC },
            { 0x00CD, 0xCD }, { 0x00CE, 0xCE }, { 0x010E, 0xCF }, { 0x0110, 0xD0 },
            { 0x0143, 0xD1 }, { 0x0147, 0xD2 }, { 0x00D3, 0xD3 }, { 0x00D4, 0xD4 },
            { 0x0150, 0xD5 }, { 0x00D6, 0xD6 }, { 0x00D7, 0xD7 }, { 0x0158, 0xD8 },
            { 0x016E, 0xD9 }, { 0x00DA, 0xDA }, { 0x0170, 0xDB }, { 0x00DC, 0xDC },
            { 0x00DD, 0xDD }, { 0x0162, 0xDE }, { 0x00DF, 0xDF }, { 0x0155, 0xE0 },
            { 0x00E1, 0xE1 }, { 0x00E2, 0xE2 }, { 0x0103, 0xE3 }, { 0x00E4, 0xE4 },
            { 0x013A, 0xE5 }, { 0x0107, 0xE6 }, { 0x00E7, 0xE7 }, { 0x010D, 0xE8 },
            { 0x00E9, 0xE9 }, { 0x0119, 0xEA }, { 0x00EB, 0xEB }, { 0x011B, 0xEC },
            { 0x00ED, 0xED }, { 0x00EE, 0xEE }, { 0x010F, 0xEF }, { 0x0111, 0xF0 },
            { 0x0144, 0xF1 }, { 0x0148, 0xF2 }, { 0x00F3, 0xF3 }, { 0x00F4, 0xF4 },
            { 0x0151, 0xF5 }, { 0x00F6, 0xF6 }, { 0x00F7, 0xF7 }, { 0x0159, 0xF8 },
            { 0x016F, 0xF9 }, { 0x00FA, 0xFA }, { 0x0171, 0xFB }, { 0x00FC, 0xFC },
            { 0x00FD, 0xFD }, { 0x0163, 0xFE }, { 0x02D9, 0xFF }
        };

        std::string out;
        out.reserve(src.size());

        for (size_t i = 0; i < src.size();) {
            const auto first = static_cast<uint8_t>(src[i]);
            if (first < 0x80) {
                out.push_back(static_cast<char>(first));
                ++i;
                continue;
            }

            size_t sequenceLength = 0;
            uint32_t codePoint = 0;
            uint32_t minimumCodePoint = 0;
            if ((first & 0xE0) == 0xC0) {
                sequenceLength = 2;
                codePoint = first & 0x1F;
                minimumCodePoint = 0x80;
            } else if ((first & 0xF0) == 0xE0) {
                sequenceLength = 3;
                codePoint = first & 0x0F;
                minimumCodePoint = 0x800;
            } else if ((first & 0xF8) == 0xF0) {
                sequenceLength = 4;
                codePoint = first & 0x07;
                minimumCodePoint = 0x10000;
            }

            bool validSequence = sequenceLength > 0 && i + sequenceLength <= src.size();
            for (size_t offset = 1; validSequence && offset < sequenceLength; ++offset) {
                const auto next = static_cast<uint8_t>(src[i + offset]);
                if ((next & 0xC0) != 0x80) {
                    validSequence = false;
                } else {
                    codePoint = (codePoint << 6) | (next & 0x3F);
                }
            }

            validSequence = validSequence && codePoint >= minimumCodePoint && codePoint <= 0x10FFFF
                && !(codePoint >= 0xD800 && codePoint <= 0xDFFF);
            if (!validSequence) {
                // Keep legacy CP1250 bytes and malformed UTF-8 unchanged.
                out.push_back(static_cast<char>(first));
                ++i;
                continue;
            }

            const auto character = std::ranges::find_if(cp1250Characters, [codePoint](const auto& entry) {
                return entry.first == codePoint;
            });
            out.push_back(character != std::end(cp1250Characters) ? static_cast<char>(character->second) : '?');
            i += sequenceLength;
        }

        return out;
    }

    [[nodiscard]] std::string latin1_to_utf8(std::string_view src) {
        std::string out;
        out.reserve(src.size() * 2); // Reserve space to reduce allocations
        for (uint8_t c : src) {
            if ((c >= 32 && c < 128) || c == 0x0d || c == 0x0a || c == 0x09) {
                out += c; // Directly append ASCII characters
            } else {
                out.push_back(0xc2 + (c > 0xbf));
                out.push_back(0x80 + (c & 0x3f));
            }
        }
        return out;
    }

#ifdef WIN32
#include <winsock2.h>
#include <windows.h>

    std::wstring utf8_to_utf16(const std::string_view src)
    {
        constexpr size_t BUFFER_SIZE = 65536;

        std::wstring res;
        wchar_t out[BUFFER_SIZE];
        if (MultiByteToWideChar(CP_UTF8, 0, src.data(), -1, out, BUFFER_SIZE))
            res = out;
        return res;
    }

    std::string utf16_to_utf8(const std::wstring_view src)
    {
        constexpr size_t BUFFER_SIZE = 65536;

        std::string res;
        char out[BUFFER_SIZE];
        if (WideCharToMultiByte(CP_UTF8, 0, src.data(), -1, out, BUFFER_SIZE, nullptr, nullptr))
            res = out;
        return res;
    }

    std::wstring latin1_to_utf16(const std::string_view src) { return utf8_to_utf16(latin1_to_utf8(src)); }

    std::string utf16_to_latin1(const std::wstring_view src) { return utf8_to_latin1(utf16_to_utf8(src)); }
#endif

    void tolower(std::string& str) { std::ranges::transform(str, str.begin(), ::tolower); }

    void toupper(std::string& str) { std::ranges::transform(str, str.begin(), ::toupper); }

    void ltrim(std::string& s) { s.erase(s.begin(), std::ranges::find_if(s, [](unsigned char ch) { return !std::isspace(ch); })); }

    void rtrim(std::string& s) { s.erase(std::ranges::find_if(s | std::views::reverse, [](unsigned char ch) { return !std::isspace(ch); }).base(), s.end()); }

    void trim(std::string& s) { ltrim(s);       rtrim(s); }

    void ucwords(std::string& str) {
        bool capitalize = true;
        for (char& c : str) {
            if (std::isspace(static_cast<unsigned char>(c)))
                capitalize = true;
            else if (capitalize) {
                c = std::toupper(static_cast<unsigned char>(c));
                capitalize = false;
            }
        }
    }

    void replace_all(std::string& str, std::string_view search, std::string_view replacement) {
        size_t pos = 0;
        while ((pos = str.find(search, pos)) != std::string::npos) {
            str.replace(pos, search.length(), replacement);
            pos += replacement.length();
        }
    }

    void eraseWhiteSpace(std::string& str) { std::erase_if(str, isspace); }

    [[nodiscard]] std::vector<std::string> split(std::string_view str, std::string_view separators) {
        std::vector<std::string> result;

        const char* begin = str.data();
        const char* end = begin + str.size();
        const char* p = begin;

        while (p < end) {
            const char* token_start = p;
            while (p < end && separators.find(*p) == std::string_view::npos)
                ++p;

            if (p > token_start)
                result.emplace_back(token_start, p - token_start);

            while (p < end && separators.find(*p) != std::string_view::npos)
                ++p;
        }

        return result;
    }
}
