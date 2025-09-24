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
#include <charconv>
#include <cctype>
#include <ranges>
#include <unordered_map>
#include <vector>

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

    namespace
    {
        constexpr char32_t REPLACEMENT_CHARACTER = 0xFFFD;

        struct CharsetDefinition
        {
            std::array<char32_t, 128> forward{};
            std::unordered_map<char32_t, uint8_t> reverse;
        };

        CharsetDefinition makeCharsetDefinition(const std::array<char32_t, 128>& forward)
        {
            CharsetDefinition def;
            def.forward = forward;
            for (size_t i = 0; i < forward.size(); ++i) {
                const char32_t codepoint = forward[i];
                if (codepoint != REPLACEMENT_CHARACTER && codepoint != 0)
                    def.reverse.emplace(codepoint, static_cast<uint8_t>(i + 128));
            }
            return def;
        }

        const CharsetDefinition& fetchCharsetDefinition(const std::string_view charset)
        {
            static const CharsetDefinition CP1250 = makeCharsetDefinition({
                0x20AC, 0xFFFD, 0x201A, 0xFFFD, 0x201E, 0x2026, 0x2020, 0x2021,
                0xFFFD, 0x2030, 0x0160, 0x2039, 0x015A, 0x0164, 0x017D, 0x0179,
                0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
                0xFFFD, 0x2122, 0x0161, 0x203A, 0x015B, 0x0165, 0x017E, 0x017A,
                0x00A0, 0x02C7, 0x02D8, 0x0141, 0x00A4, 0x0104, 0x00A6, 0x00A7,
                0x00A8, 0x00A9, 0x015E, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x017B,
                0x00B0, 0x00B1, 0x02DB, 0x0142, 0x00B4, 0x00B5, 0x00B6, 0x00B7,
                0x00B8, 0x0105, 0x015F, 0x00BB, 0x013D, 0x02DD, 0x013E, 0x017C,
                0x0154, 0x00C1, 0x00C2, 0x0102, 0x00C4, 0x0139, 0x0106, 0x00C7,
                0x010C, 0x00C9, 0x0118, 0x00CB, 0x011A, 0x00CD, 0x00CE, 0x010E,
                0x0110, 0x0143, 0x0147, 0x00D3, 0x00D4, 0x0150, 0x00D6, 0x00D7,
                0x0158, 0x016E, 0x00DA, 0x0170, 0x00DC, 0x00DD, 0x0162, 0x00DF,
                0x0155, 0x00E1, 0x00E2, 0x0103, 0x00E4, 0x013A, 0x0107, 0x00E7,
                0x010D, 0x00E9, 0x0119, 0x00EB, 0x011B, 0x00ED, 0x00EE, 0x010F,
                0x0111, 0x0144, 0x0148, 0x00F3, 0x00F4, 0x0151, 0x00F6, 0x00F7,
                0x0159, 0x016F, 0x00FA, 0x0171, 0x00FC, 0x00FD, 0x0163, 0x02D9,
            });

            static const CharsetDefinition CP1252 = makeCharsetDefinition({
                0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
                0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
                0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
                0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178,
                0x00A0, 0x00A1, 0x00A2, 0x00A3, 0x00A4, 0x00A5, 0x00A6, 0x00A7,
                0x00A8, 0x00A9, 0x00AA, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00AF,
                0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7,
                0x00B8, 0x00B9, 0x00BA, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x00BF,
                0x00C0, 0x00C1, 0x00C2, 0x00C3, 0x00C4, 0x00C5, 0x00C6, 0x00C7,
                0x00C8, 0x00C9, 0x00CA, 0x00CB, 0x00CC, 0x00CD, 0x00CE, 0x00CF,
                0x00D0, 0x00D1, 0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x00D6, 0x00D7,
                0x00D8, 0x00D9, 0x00DA, 0x00DB, 0x00DC, 0x00DD, 0x00DE, 0x00DF,
                0x00E0, 0x00E1, 0x00E2, 0x00E3, 0x00E4, 0x00E5, 0x00E6, 0x00E7,
                0x00E8, 0x00E9, 0x00EA, 0x00EB, 0x00EC, 0x00ED, 0x00EE, 0x00EF,
                0x00F0, 0x00F1, 0x00F2, 0x00F3, 0x00F4, 0x00F5, 0x00F6, 0x00F7,
                0x00F8, 0x00F9, 0x00FA, 0x00FB, 0x00FC, 0x00FD, 0x00FE, 0x00FF,
            });

            static const CharsetDefinition EMPTY = makeCharsetDefinition({});

            if (charset == "cp1250")
                return CP1250;
            if (charset == "cp1252" || charset == "latin1")
                return CP1252;
            return EMPTY;
        }

        inline std::string normalizeCharset(std::string_view charset)
        {
            std::string normalized(charset);
            std::ranges::transform(normalized, normalized.begin(), [](const unsigned char c) { return static_cast<char>(std::tolower(c)); });
            return normalized;
        }

        inline char32_t decodeUtf8Char(const std::string_view src, size_t& index)
        {
            const uint8_t lead = static_cast<uint8_t>(src[index]);
            if (lead < 0x80) {
                ++index;
                return lead;
            }

            size_t extraBytes = 0;
            char32_t codepoint = 0;
            if ((lead & 0xE0) == 0xC0) {
                extraBytes = 1;
                codepoint = lead & 0x1F;
            } else if ((lead & 0xF0) == 0xE0) {
                extraBytes = 2;
                codepoint = lead & 0x0F;
            } else if ((lead & 0xF8) == 0xF0) {
                extraBytes = 3;
                codepoint = lead & 0x07;
            } else {
                ++index;
                return '?';
            }

            if (index + extraBytes >= src.size()) {
                index = src.size();
                return '?';
            }

            for (size_t i = 1; i <= extraBytes; ++i) {
                const uint8_t byte = static_cast<uint8_t>(src[index + i]);
                if ((byte & 0xC0) != 0x80) {
                    index += i;
                    return '?';
                }
                codepoint = (codepoint << 6) | (byte & 0x3F);
            }
            index += extraBytes + 1;
            return codepoint;
        }

        inline void appendUtf8(std::string& out, char32_t codepoint)
        {
            if (codepoint <= 0x7F) {
                out.push_back(static_cast<char>(codepoint));
            } else if (codepoint <= 0x7FF) {
                out.push_back(static_cast<char>(0xC0 | (codepoint >> 6)));
                out.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
            } else if (codepoint <= 0xFFFF) {
                out.push_back(static_cast<char>(0xE0 | (codepoint >> 12)));
                out.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
                out.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
            } else {
                out.push_back(static_cast<char>(0xF0 | (codepoint >> 18)));
                out.push_back(static_cast<char>(0x80 | ((codepoint >> 12) & 0x3F)));
                out.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
                out.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
            }
        }
    }

    [[nodiscard]] std::string utf8_to_charset(const std::string_view src, const std::string_view charset)
    {
        const std::string normalized = normalizeCharset(charset);
        if (normalized.empty() || normalized == "utf-8" || normalized == "utf8")
            return std::string(src);

        const auto& definition = fetchCharsetDefinition(normalized);
        std::string out;
        out.reserve(src.size());

        for (size_t i = 0; i < src.size();) {
            const char32_t codepoint = decodeUtf8Char(src, i);
            if (codepoint < 128) {
                out.push_back(static_cast<char>(codepoint));
                continue;
            }

            const auto it = definition.reverse.find(codepoint);
            out.push_back(static_cast<char>(it != definition.reverse.end() ? it->second : '?'));
        }

        return out;
    }

    [[nodiscard]] std::string charset_to_utf8(const std::string_view src, const std::string_view charset)
    {
        const std::string normalized = normalizeCharset(charset);
        if (normalized.empty() || normalized == "utf-8" || normalized == "utf8")
            return std::string(src);

        const auto& definition = fetchCharsetDefinition(normalized);
        std::string out;
        out.reserve(src.size() * 2);

        for (const uint8_t c : src) {
            char32_t codepoint = c;
            if (c >= 128) {
                const char32_t mapped = definition.forward[c - 128];
                codepoint = mapped == REPLACEMENT_CHARACTER || mapped == 0 ? '?' : mapped;
            }
            appendUtf8(out, codepoint);
        }

        return out;
    }

    [[nodiscard]] std::string utf8_to_latin1(std::string_view src) { return utf8_to_charset(src, "cp1252"); }

    [[nodiscard]] std::string latin1_to_utf8(std::string_view src) { return charset_to_utf8(src, "cp1252"); }

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