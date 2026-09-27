//
//  IniFile.swift
//  IniFile
//
//  Created by Heaven Chou on 2020/2/28.
//  Copyright © 2020 CBETA. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/*
 INI 範例檔案

 inifile.ini
 =================
 ; 分號開頭是註解
 # 這行是無法處理的資料，儲存時依然會保留
 ; 底下這一組是最上層資料，section 指定為空字串即可處理
 key=value
 
 [Section]
 key1=value1
 key2=value2
 
 [Section2]
 key3=value3
 
 =================
 
 CIniFile 使用方法
 預設 encoding 為 utf8

 let myIni = try CIniFile(fileName = "inifile.ini", encoding = .utf8)
 
 讀取資料
 若 section 為空字串，表示讀取最上層無 section 的資料
 若讀取失敗，則傳回 defaultVal
 
 let str = myIni.readString(section, key, defaultVal)
 let int = myIni.readInt(section, key, defaultVal)
 let bool = myIni.readBool(section, key, defaultVal)
 
 設定資料
 
 myIni.writeString(section, key, str)
 myIni.writeInt(section, key, int)
 myIni.writeBool(section, key, bool)
 
 儲存至原來的檔案
 儲存時會儘量依原始資料的順序與保存註解和無法處理的內容
 
 myIni.writeFile()
 
 儲存至指定檔案
 
 myIni.writeFile("newinifile.ini")
 
 注意：
 
 布林值以下為真
 1, yes, on, true
 以下為假
 0, no, off, false
 其他則視為無法判斷。
 以上不區別大小寫，不過寫入時，請以這二個變數為主
 defaultBoolTrue, defaultBoolFalse
 但這只用在執行時有修改的布林值，不影響原始資料。
 也就是若原本是寫
 key=yes
 若 key 沒有修改，則不會變成 0 或 1 (依變數設定)，依然是 yes
*/

import Foundation

class INIFile {
    
    // 成員變數
    // 預設的 Section
    private let defaultSection = "_DEFAULT_"
    // 預設可判斷的布林值
    private let boolTrueSet: Set = ["1","on","yes","true"]
    private let boolFalseSet: Set = ["0","off","no","false"]
    // 預設布林值 True 與 False 寫入字串，目前不是當成可修改參數
    private let defaultBoolTrue = "1"
    private let defaultBoolFalse = "0"
    
    private var fileName = ""
    private var encoding: String.Encoding = .utf8
    
    // MARK: 資料結構
    // content 是一個 section 指向一組字典，字典內部是 key=val
    private var content: [String: [String: String]] = [:]
    // sectionList 是記錄 section 順序，希望寫回時儘量依原始的順序
    var sectionList: [String] = []
    // keyList 是記錄各組 section 中 key 的順序，希望寫回時儘量依原始的順序
    var keyList: [String: [String]] = [:]
    
    // Section 之前的空白與註解
    private var sectionNote: [String: String] = [:]
    // Key 之前的空白與註解
    private var keyNote: [String: [String: String]] = [:]
    // 目前遇到的註解
    private var thisNote = ""
    /* 例:
        ; 這是 Section 之前的註解
        [AAA]
        ; 這是 Key 之前的註解
        Key1=Value1
        Key2=Value2
        [BBB]
        Key3=Value3
     
        資料結構為
        sectionList = [defaultSection, "AAA", "BBB"]
        keyList =
            [defaultSection: [],
            "AAA": ["Key1", "Key2"]
            "BBB": ["Key3"]]
        content =
            [defaultSection: [:],
            "AAA": ["Key1": "Value1",
                    "Key2": "Value2"],
            "BBB": ["Key3": "Value3"]]
        sectionNote =
            [defaultSection: [:],
             "AAA": "; 這是 Section 之前的註解\n",
             "BBB": ""]
        keyNote =
            [defaultSection: [:],
             "AAA": ["Key1": "; 這是 Key 之前的註解\n"]
             "BBB": [:]]
    */
    
    
    // 建構式
    init (fileName: String, encoding: String.Encoding = .utf8) throws {
        self.fileName = fileName
        self.encoding = encoding
  
        // 沒有 Section 的預設值
        var sectionName = defaultSection
        checkIfNewSection(sectionName)
        // defaultSection 要給註解初值，否則會自動加一行空白
        sectionNote[defaultSection] = ""
        
        if !FileManager.default.fileExists(atPath: fileName) {
            return
        }
        
        let file = try String(contentsOfFile: fileName, encoding: encoding)
        let lines = file.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })

        // 逐行分析
        for line in lines {
            let line = line.trimmingCharacters(in: .whitespaces)
            // 空白行
            if line == "" {
                thisNote += "\n"
                continue
            }
            // ; 開頭為註解
            if line.first == ";" || line.first == "#" {
                thisNote += line + "\n"
                continue
            }
            // [...] 為 section
            if line.hasPrefix("[") && line.hasSuffix("]") {
                sectionName = getSectionName(line)
                checkIfNewSection(sectionName)
                sectionNote[sectionName] = thisNote
                thisNote = ""
            } else if let (key, val) = getKeyValue(line) {
                // key=val 為內容
                content[sectionName]![key] = val
                if !keyList[sectionName]!.contains(key) {
                    keyList[sectionName]!.append(key)
                }
                keyNote[sectionName]![key] = thisNote
                thisNote = ""
            } else {
                // 無法處理的，也當成註解記錄下來好了
                thisNote += ";-" + line + "\n"
            }
        }
    }
    
    // 分析 [Section]
    private func getSectionName(_ line: String) -> String {
        let begin = line.index(after: line.startIndex)
        let end = line.index(before: line.endIndex)
        return String(line[begin..<end])
    }
    
    // 分析 key=value
    private func getKeyValue(_ line: String) -> (String, String)? {
        let parts = line.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let val = String(parts[1]).trimmingCharacters(in: .whitespaces)
            return (key, val)
        } else if parts.count == 1 {
            // 沒有內容的項目
            // item=
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let val = ""
            return (key, val)
        }
        return nil
    }
    
    // 檢查是不是新的 Section
    // 若是，則加上 content, sectionList, keyList
    private func checkIfNewSection(_ section: String) {
        if content[section] == nil {
            content[section] = [:]
            sectionList.append(section)
            keyList[section] = []
            keyNote[section] = [:]
        }
    }
    
    // 檢查是不是新的 Key
    // 若是，則加上 content, sectionList, keyList
    private func checkIfNewKey(_ section: String, _ key: String) {
        if key != "" {
            if content[section]![key] == nil {
                keyList[section]!.append(key)
            }
        }
    }
    
    // =========================================
    // MARK: 公開的成員函式
    // =========================================
    
    func writeBool(_ sec: String, _ key: String, _ val: Bool) {
        // 處理 section
        var section = sec
        if section == "" { section = defaultSection }
        checkIfNewSection(section)
        // 檢查 key
        if key == "" { return }
        checkIfNewKey(section, key)
        // 處理 value
        var value: String
        if val { value = defaultBoolTrue }
        else { value = defaultBoolFalse }
        
        content[section]![key] = value
    }

    func readBool(_ sec: String, _ key: String, _ defaultVal: Bool) -> Bool {
        // 處理 section
        var section = sec
        if section == "" { section = defaultSection }
        
        if let b = content[section]?[key] {
            switch b.lowercased() {
                case let b where boolTrueSet.contains(b): return true
                case let b where boolFalseSet.contains(b): return false
            default:
                return defaultVal
            }
        } else {
            return defaultVal
        }
    }
       
    func writeString(_ sec: String, _ key: String, _ val: String) {
        // 處理 section
        var section = sec
        if section == "" { section = defaultSection }
        checkIfNewSection(section)
        // 檢查 key
        if key == "" { return }
        checkIfNewKey(section, key)

        content[section]![key] = val
    }

    func readString(_ sec: String, _ key: String, _ defaultVal: String) -> String {
        // 處理 section
        var section = sec
        if section == "" { section = defaultSection }
        
        if let str = content[section]?[key] {
            return str
        }
        return defaultVal
    }
    
    func writeInt(_ sec: String, _ key: String, _ val: Int) {
        // 處理 section
        var section = sec
        if section == "" { section = defaultSection }
        checkIfNewSection(section)
        // 檢查 key
        if key == "" { return }
        checkIfNewKey(section, key)

        content[section]![key] = String(val)
    }
    
    func readInt(_ sec: String, _ key: String, _ defaultVal: Int) -> Int {
        // 處理 section
        var section = sec
        if section == "" { section = defaultSection }
        
        if let str = content[section]?[key] {
            if let i = Int(str) {
                return i
            }
        }
        return defaultVal
    }
    
    func readSecton(_ sec: String) -> [String: String] {
        // 處理 section
        var section = sec
        if section == "" { section = defaultSection }
        
        return content[section] ?? [:]
    }
    
    func readAll() -> [String: [String: String]] {
        return content
    }
    
    func readKeyNote(_ sec: String, _ key: String) -> String? {
        return keyNote[sec]?[key]
    }
    
    func writeFile(_ fileName: String = "") throws {
        var fileName = fileName
        if fileName == "" {
            fileName = self.fileName
        }
        
        var lines = ""
        
        for sec in sectionList {
            // 加在 Section 之前的註解
            if let note = sectionNote[sec] {
                lines += note
            } else {
                lines += "\n"   // 沒註解的新增 section 要加上換行
            }
            // 加上 [Section]
            if sec != defaultSection {
                lines += "[\(sec)]\n"
            }
            for key in keyList[sec]! {
                // 加在 Key 之前的註解
                if let note = keyNote[sec]![key] {
                    lines += note
                }
                // 加上 Key＝Value
                lines += "\(key)=\(content[sec]![key]!)\n"
            }
        }
        lines += thisNote.trimmingCharacters(in: .newlines)
        
        try lines.writeWithCompletePath(to: URL(fileURLWithPath: fileName))
    }
}
