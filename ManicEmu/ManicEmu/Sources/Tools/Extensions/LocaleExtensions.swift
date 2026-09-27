//
//  LocaleExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

extension Locale {
    static var isRTLLanguage: Bool {
        guard let languageCode = Locale.current.languageCode else { return false }
        return Locale.characterDirection(forLanguage: languageCode) == .rightToLeft
    }
    
    /**
     "af",       // Afrikaans
     "am",       // Amharic
     "ar",       // Arabic
     "az",       // Azerbaijani
     "be",       // Belarusian
     "bg",       // Bulgarian
     "bn",       // Bengali
     "bs",       // Bosnian
     "ca",       // Catalan
     "cs",       // Czech
     "cy",       // Welsh
     "da",       // Danish
     "de",       // German
     "el",       // Greek
     "en",       // English
     "eo",       // Esperanto
     "es",       // Spanish
     "et",       // Estonian
     "eu",       // Basque
     "fa",       // Persian
     "fi",       // Finnish
     "fil",      // Filipino
     "fr",       // French
     "ga",       // Irish
     "gl",       // Galician
     "gu",       // Gujarati
     "he",       // Hebrew
     "hi",       // Hindi
     "hr",       // Croatian
     "hu",       // Hungarian
     "hy",       // Armenian
     "id",       // Indonesian
     "is",       // Icelandic
     "it",       // Italian
     "ja",       // Japanese
     "jv",       // Javanese
     "ka",       // Georgian
     "kk",       // Kazakh
     "km",       // Khmer
     "kn",       // Kannada
     "ko",       // Korean
     "ky",       // Kyrgyz
     "lo",       // Lao
     "lt",       // Lithuanian
     "lv",       // Latvian
     "mk",       // Macedonian
     "ml",       // Malayalam
     "mn",       // Mongolian
     "mr",       // Marathi
     "ms",       // Malay
     "my",       // Burmese
     "ne",       // Nepali
     "nl",       // Dutch
     "no",       // Norwegian
     "pa",       // Punjabi
     "pl",       // Polish
     "ps",       // Pashto
     "pt",       // Portuguese
     "ro",       // Romanian
     "ru",       // Russian
     "si",       // Sinhala
     "sk",       // Slovak
     "sl",       // Slovenian
     "sq",       // Albanian
     "sr",       // Serbian
     "sv",       // Swedish
     "sw",       // Swahili
     "ta",       // Tamil
     "te",       // Telugu
     "th",       // Thai
     "tl",       // Tagalog
     "tr",       // Turkish
     "uk",       // Ukrainian
     "ur",       // Urdu
     "uz",       // Uzbek
     "vi",       // Vietnamese
     "zh",       // Chinese (generic)
     "zh-Hans",  // Chinese Simplified
     "zh-Hant",  // Chinese Traditional
     */
    ///是否更倾向于中国大陆
    static var prefersCN: Bool {
        // 1. 判断用户是否偏好中文
        let prefersChinese: Bool = {
            Locale.preferredLanguages.contains { lang in
                lang.lowercased().hasPrefix("zh") // 匹配简体、繁体或其他中文变种
            }
        }()
        
        // 2. 获取设备设置的地区代码（如 CN/TW/HK/US）
        let regionCode = Locale.current.regionCode?.uppercased() ?? ""
        
        // 3. 核心判断逻辑
        if prefersChinese && regionCode == "CN" {
            return true          // 中国大陆中文用户
        } else {
            return false    // 其他所有情况（包括台湾、香港、非中文用户等）
        }
    }
    
    ///是否更倾向于美国
    static var prefersUS: Bool {
        // 1. 判断用户是否偏好英文
        let prefersEnglish: Bool = {
            Locale.preferredLanguages.contains { lang in
                lang.lowercased().hasPrefix("en")
            }
        }()
        
        // 2. 获取设备设置的地区代码（如 CN/TW/HK/US）
        let regionCode = Locale.current.regionCode?.uppercased() ?? ""
        
        // 3. 核心判断逻辑
        if prefersEnglish && regionCode == "US" {
            return true
        } else {
            return false
        }
    }
    
    static func getSystemLanguageDisplayName(preferredLanguage: String?) -> String {
        guard let preferredLanguage = preferredLanguage ?? Locale.preferredLanguages.first else {
            return "Unknown"
        }
        
        // 拆分语言代码（如 "zh-Hans-CN" → ["zh", "Hans", "CN"]）
        let components = preferredLanguage.components(separatedBy: "-")
        let baseComponents = Array(components.prefix(2)) // 取前两部分（语言 + 脚本/地区）
        let baseLanguageCode = baseComponents.joined(separator: "-")
        
        // 构造 Locale 的 identifier（如 "zh_Hans"）
        let localeIdentifier = baseComponents.joined(separator: "_")
        let locale = Locale(identifier: localeIdentifier)
        
        // 获取本地化语言名称
        guard let displayName = locale.localizedString(forLanguageCode: baseLanguageCode) else {
            return baseLanguageCode
        }
        return displayName
    }
}
