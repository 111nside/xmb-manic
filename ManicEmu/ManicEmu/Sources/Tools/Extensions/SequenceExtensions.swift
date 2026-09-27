//
//  SequenceExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/4.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

extension Sequence {
    func grouped<Key: Hashable>(by keyForValue: (Element) -> Key) -> [[Element]] {
        var groups: [Key: [Element]] = [:]
        var order: [Key] = []
        for element in self {
            let key = keyForValue(element)
            if groups[key] == nil {
                order.append(key)
                groups[key] = []
            }
            groups[key]!.append(element)
        }
        return order.compactMap { groups[$0] }
    }
}
