//
//  Trigger.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/10/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import RealmSwift

import IceCream

extension Trigger: CKRecordConvertible & CKRecordRecoverable {}
extension TriggerItem: CKRecordConvertible & CKRecordRecoverable {}

class TriggerItem: Object {
    ///样式
    ///skeuomorphism 仿真风格
    ///flat 扁平风格
    ///custom 自定义按钮
    enum Style: Int, PersistableEnum {
        case classic, flat, custom
        
        func getFont(buttonSize: CGSize) -> UIFont {
            switch self {
            case .classic:
                UIFont.monospacedDigitSystemFont(ofSize: buttonSize.height*0.375, weight: .bold)
            case .flat:
                UIFont.monospacedDigitSystemFont(ofSize: buttonSize.height*0.4, weight: .medium)
            case .custom:
                R.Font.LargeTitle(emphasis: true)
            }
        }
        
        var defaultSize: CGSize {
            switch self {
            case .classic:
                    .init(80)
            case .flat:
                    .init(60)
            case .custom:
                    .init(60)
            }
        }
        
        var sizeRange: (min: Float, max: Float) {
            switch self {
            case .classic:
                (40, 100)
            case .flat, .custom:
                (32, 80)
            }
        }
        
        var cellHeight: CGFloat {
            if self == .custom {
                427
            } else {
                357
            }
        }
        
        var name: String {
            switch self {
            case .classic:
                R.string.localizable.classic()
            case .flat:
                R.string.localizable.flat()
            case .custom:
                R.string.localizable.custom()
            }
        }
    }
    
    ///simple: 简单按压
    ///hold: 长按
    ///combo: 连招(顺序按压)
    enum Action: Int, PersistableEnum {
        case simple, hold, combo
        
        var desc: String {
            switch self {
            case .simple:
                R.string.localizable.simpleActionDesc()
            case .hold:
                R.string.localizable.holdActionDesc()
            case .combo:
                R.string.localizable.comboActionDesc()
            }
        }
        
        var name: String {
            switch self {
            case .simple:
                R.string.localizable.simple()
            case .hold:
                R.string.localizable.hold()
            case .combo:
                R.string.localizable.combo()
            }
        }
    }
    ///主键 由创建时间戳ms来生成
    @Persisted(primaryKey: true) var id: Int = PersistedKit.incrementID
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
    ///样式
    @Persisted var style: Style = .classic
    ///自定义样式的图片资源
    @Persisted var customImage: CreamAsset?
    ///按钮的文案
    @Persisted var buttonText: String = "M"
    ///按钮在iPhone的X坐标
    @Persisted var iphoneButtonX: Double?
    ///按钮在iPhone的Y坐标
    @Persisted var iphoneButtonY: Double?
    ///按钮在iPad的X坐标
    @Persisted var ipadButtonX: Double?
    ///按钮在iPad的Y坐标
    @Persisted var ipadButtonY: Double?
    ///设置的时候 需要确保该实例不是数据库实例，否则set的时候会闪退
    var position: CGPoint? {
        get {
            if UIDevice.isPhone, let iphoneButtonX, let iphoneButtonY {
                return CGPoint(x: iphoneButtonX, y: iphoneButtonY)
            } else if let ipadButtonX, let ipadButtonY {
                return CGPoint(x: ipadButtonX, y: ipadButtonY)
            }
            return nil
        }
        set {
            if let newValue {
                if UIDevice.isPhone {
                    iphoneButtonX = Double(newValue.x)
                    iphoneButtonY = Double(newValue.y)
                } else {
                    ipadButtonX = Double(newValue.x)
                    ipadButtonY = Double(newValue.y)
                }
            }
        }
    }
    ///按钮的width
    @Persisted var buttonWidth: Double = Style.classic.defaultSize.width
    ///按钮的height
    @Persisted var buttonHeight: Double = Style.classic.defaultSize.height
    ///按钮的size
    var buttonSize: CGSize { .init(width: buttonWidth, height: buttonHeight) }
    ///按钮透明度 0-1
    @Persisted var buttonOpacity: Double = 1
    ///按钮圆角 百分比 0是矩形 100是圆形
    @Persisted var buttonCornerRadiusRatio: Double = 100.0
    var buttonCornerRadius: CGFloat {
        if style == .custom {
            return (buttonCornerRadiusRatio/100)*(buttonHeight/2)
        } else {
            return 0
        }
    }
    ///映射列表
    @Persisted var mappings: List<String>
    ///动作类型
    @Persisted var action: Action = .simple
    ///简单类型 是否重复点击
    @Persisted var simpleActionRepeat: Bool = false
    ///简单类型 重复点击的间隔时间 默认0.1s
    @Persisted var simpleActionRepeatInterval: Double = 0.1
    ///长按类型 长按是否自动停止
    @Persisted var holdActionAutoStop: Bool = false
    ///长按类型 长按自动停止的持续时间 默认5秒
    @Persisted var holdActionDuration: Double = 5
    ///连招类型 每个键的按压持续时间 默认50ms
    @Persisted var comboActionPressDurationPerKey: Double = 50
    ///连招类型 每个键的按压间隔时间 默认100ms
    @Persisted var comboActionIntervalPerKey: Double = 100
    
    var desc: String {
        var result = "\(R.string.localizable.buttonStyle()): \(style.name)\n"
        if UIDevice.isPhone {
            result += "\(R.string.localizable.position()): (x: \(iphoneButtonX ?? -1) y: \(iphoneButtonY ?? -1))\n"
        } else {
            result += "\(R.string.localizable.position()): (x: \(ipadButtonX ?? -1) y: \(ipadButtonY ?? -1))\n"
        }
        result += "\(R.string.localizable.size()): (width: \(buttonWidth) height: \(buttonHeight))\n"
        result += "\(R.string.localizable.action()): \(action.name)\n"
        if action == .simple {
            result += "\(R.string.localizable.repeatTrigger()): \(simpleActionRepeat)\n"
            result += "\(R.string.localizable.repeatInterval()): \(simpleActionRepeatInterval)s\n"
        } else if action == .hold {
            result += "\(R.string.localizable.autoStop()): \(holdActionAutoStop)\n"
            result += "\(R.string.localizable.holdDuration()): \(holdActionDuration)s\n"
        } else if action == .combo {
            result += "\(R.string.localizable.pressDurationPerKey()): \(comboActionPressDurationPerKey)ms\n"
            result += "\(R.string.localizable.intervalPerKey()): \(comboActionIntervalPerKey)ms\n"
        }
        if mappings.count > 0 {
            result += "\(R.string.localizable.mapping()): \(mappings.reduce("", { $0 + " (\($1))" }))"
        }
        return result
    }
    
    func isCompleteEqual(triggerItem: TriggerItem) -> Bool {
        if id == triggerItem.id &&
            style == triggerItem.style &&
            iphoneButtonX == triggerItem.iphoneButtonX &&
            iphoneButtonY == triggerItem.iphoneButtonY &&
            ipadButtonX == triggerItem.ipadButtonX &&
            ipadButtonY == triggerItem.ipadButtonY &&
            buttonSize == triggerItem.buttonSize &&
            buttonOpacity == triggerItem.buttonOpacity &&
            buttonCornerRadiusRatio == triggerItem.buttonCornerRadiusRatio &&
            mappings == triggerItem.mappings &&
            action == triggerItem.action {
            switch style {
            case .classic, .flat:
                if buttonText != triggerItem.buttonText {
                    return false
                }
            case .custom:
                if customImage?.storedData() != triggerItem.customImage?.storedData() {
                    return false
                }
            }
            switch action {
            case .simple:
                if simpleActionRepeat == triggerItem.simpleActionRepeat &&
                    simpleActionRepeatInterval == triggerItem.simpleActionRepeatInterval {
                    return true
                }
            case .hold:
                if holdActionAutoStop == triggerItem.holdActionAutoStop &&
                    holdActionDuration == triggerItem.holdActionDuration {
                    return true
                }
            case .combo:
                if comboActionIntervalPerKey == triggerItem.comboActionIntervalPerKey && comboActionPressDurationPerKey == triggerItem.comboActionPressDurationPerKey {
                    return true
                }
            }
        }
        return false
    }
}

class Trigger: Object, ObjectUpdatable {
    ///主键 由创建时间戳ms来生成
    @Persisted(primaryKey: true) var id: Int = PersistedKit.incrementID
    ///游戏平台类型
    @Persisted var gameType: GameType
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
    ///额外数据备用
    @Persisted var extras: Data?
    ///名称 如果名称为空 则使用 TriggerPro-25-11-1
    @Persisted var name: String?
    ///items
    @Persisted var items: List<TriggerItem>
    
    var triggerProName: String {
        if let name, !name.isEmpty {
            return name
        } else {
            return defaultName
        }
    }
    
    var defaultName: String {
        "TriggerPro " + Date(timeIntervalSince1970: TimeInterval(id/1000)).dateTimeString(ofStyle: .short)
    }
    
    func getExtra(key: String) -> Any? {
        if let extras {
            return Self.getExtra(extras: extras, key: key)
        }
        return nil
    }
    
    func updateExtra(key: String, value: Any?) {
        if let extras, let data = Self.updateExtra(extras: extras, key: key, value: value) {
            Self.change { realm in
                self.extras = data
            }
        } else if let data = [key: value].jsonData() {
            Self.change { realm in
                self.extras = data
            }
        }
    }
    
    func copyTrigger(newId: Bool = false) -> Trigger {
        let trigger = Trigger()
        trigger.id = newId ? PersistedKit.incrementID : id
        trigger.gameType = gameType
        trigger.extras = extras
        trigger.name = name
        trigger.items = List<TriggerItem>()
        for (index, item) in items.enumerated() {
            let triggerItem = TriggerItem()
            triggerItem.id = newId ? PersistedKit.incrementID + index : item.id
            triggerItem.isDeleted = item.isDeleted
            triggerItem.style = item.style
            triggerItem.customImage = item.customImage
            triggerItem.buttonText = item.buttonText
            triggerItem.iphoneButtonX = item.iphoneButtonX
            triggerItem.iphoneButtonY = item.iphoneButtonY
            triggerItem.ipadButtonX = item.ipadButtonX
            triggerItem.ipadButtonY = item.ipadButtonY
            triggerItem.buttonWidth = item.buttonWidth
            triggerItem.buttonHeight = item.buttonHeight
            triggerItem.buttonOpacity = item.buttonOpacity
            triggerItem.buttonCornerRadiusRatio = item.buttonCornerRadiusRatio
            triggerItem.mappings = item.mappings
            triggerItem.action = item.action
            triggerItem.simpleActionRepeat = item.simpleActionRepeat
            triggerItem.simpleActionRepeatInterval = item.simpleActionRepeatInterval
            triggerItem.holdActionAutoStop = item.holdActionAutoStop
            triggerItem.holdActionDuration = item.holdActionDuration
            triggerItem.comboActionPressDurationPerKey = item.comboActionPressDurationPerKey
            triggerItem.comboActionIntervalPerKey = item.comboActionIntervalPerKey
            trigger.items.append(triggerItem)
        }
        return trigger
    }
    
    func isCompleteEqual(trigger: Trigger) -> Bool {
        if id == trigger.id &&
            gameType == trigger.gameType &&
            extras == trigger.extras &&
            name == trigger.name &&
            items.count == trigger.items.count {
            for (index, item) in items.enumerated() {
                let newItem = trigger.items[index]
                if !item.isCompleteEqual(triggerItem: newItem) {
                    return false
                }
            }
            return true
        }
        return false
    }
    
    func update(realm: Realm, trigger: Trigger) {
        try? realm.write {
            gameType = trigger.gameType
            extras = trigger.extras
            name = trigger.name
            realm.delete(items)
            items = trigger.items
        }
    }
    
    static func supportTriggers(gameType: GameType) -> [Trigger] {
        let realm = Database.realm
        let triggers = realm.objects(Trigger.self).where({ $0.gameType == gameType && !$0.isDeleted}).sorted(by: \Trigger.id, ascending: true)
        var results: [Trigger] = []
        results.append(contentsOf: triggers)
        return results
    }
    
    static func nextTriggerID(gameType: GameType, currentID: Int?) -> Int? {
        let triggers = supportTriggers(gameType: gameType)
        if triggers.count > 0 {
            //配置存在
            if let currentID, let currentIndex = triggers.firstIndex(where: { $0.id == currentID }) {
                //找到配置的index
                if currentIndex + 1 >= triggers.count {
                    //目前已经使用了最后一个配置
                    return nil
                } else {
                    //获取下一个配置的id
                    return triggers[currentIndex+1].id
                }
            } else {
                //没找到配置，但是存在配置，直接返回第一个配置ID
                return triggers[0].id
            }
        } else {
            return nil
        }
    }
}
