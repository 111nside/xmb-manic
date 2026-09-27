//
//  Bimap.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation

/// A bidirectional map where both keys and values are unique.
///
/// `BiMap` maintains the invariant:
///
///     key -> value
///     value -> key
///
/// Both directions provide average O(1) lookup.
///
/// - Important:
///   Both `Key` and `Value` must conform to `Hashable`.
public struct BiMap<Key: Hashable, Value: Hashable> {

    // MARK: - Storage

    private var keyToValue: [Key: Value]
    private var valueToKey: [Value: Key]

    // MARK: - Initialization

    
    public init() {
        self.keyToValue = [:]
        self.valueToKey = [:]
    }

    
    public init(minimumCapacity: Int) {
        self.keyToValue = Dictionary(minimumCapacity: minimumCapacity)
        self.valueToKey = Dictionary(minimumCapacity: minimumCapacity)
    }

    /// Creates a BiMap from a sequence of key-value pairs.
    ///
    /// - Returns: `nil` if either a key or a value occurs more than once.
    
    public init?<S: Sequence>(_ elements: S)
    where S.Element == (Key, Value) {
        let capacity = elements.underestimatedCount
        var keyToValue = Dictionary<Key, Value>(
            minimumCapacity: capacity
        )
        var valueToKey = Dictionary<Value, Key>(
            minimumCapacity: capacity
        )

        for (key, value) in elements {
            guard keyToValue[key] == nil,
                  valueToKey[value] == nil else {
                return nil
            }

            keyToValue[key] = value
            valueToKey[value] = key
        }

        self.keyToValue = keyToValue
        self.valueToKey = valueToKey
    }

    /// Creates a BiMap from a dictionary.
    ///
    /// Since Dictionary already guarantees unique keys, this only
    /// fails if multiple keys contain the same value.
    ///
    /// Do not forward to `init?(_: Sequence)`: Dictionary is a Sequence,
    /// and this unlabeled overload is preferred, causing infinite recursion.
    
    public init?(_ dictionary: [Key: Value]) {
        var valueToKey = Dictionary<Value, Key>(
            minimumCapacity: dictionary.count
        )

        for (key, value) in dictionary {
            guard valueToKey[value] == nil else {
                return nil
            }
            valueToKey[value] = key
        }

        self.keyToValue = dictionary
        self.valueToKey = valueToKey
    }

    // MARK: - Properties

    
    public var count: Int {
        keyToValue.count
    }

    
    public var isEmpty: Bool {
        keyToValue.isEmpty
    }

    /// All keys in the map.
    public var keys: Dictionary<Key, Value>.Keys {
        keyToValue.keys
    }

    /// All values in the map.
    public var values: Dictionary<Key, Value>.Values {
        keyToValue.values
    }

    // MARK: - Lookup

    /// Returns the value associated with `key`.
    ///
    /// Average complexity: O(1)
    
    public func value(forKey key: Key) -> Value? {
        keyToValue[key]
    }

    /// Returns the key associated with `value`.
    ///
    /// Average complexity: O(1)
    
    public func key(forValue value: Value) -> Key? {
        valueToKey[value]
    }

    
    public func contains(key: Key) -> Bool {
        keyToValue[key] != nil
    }

    
    public func contains(value: Value) -> Bool {
        valueToKey[value] != nil
    }

    // MARK: - Mutation

    /// Inserts a new key-value pair.
    ///
    /// Returns `false` if either the key or value already exists.
    ///
    /// Average complexity: O(1)
    @discardableResult
    
    public mutating func insert(
        key: Key,
        value: Value
    ) -> Bool {

        guard keyToValue[key] == nil,
              valueToKey[value] == nil else {
            return false
        }

        keyToValue[key] = value
        valueToKey[value] = key

        return true
    }

    /// Inserts a key-value pair, replacing any existing pair that
    /// conflicts with either the key or the value.
    ///
    /// Example:
    ///
    ///     A -> 1
    ///     B -> 2
    ///
    ///     upsert(B, 1)
    ///
    /// Results in:
    ///
    ///     B -> 1
    ///
    /// `A -> 1` and `B -> 2` are removed.
    ///
    /// Average complexity: O(1)
    
    public mutating func upsert(
        key: Key,
        value: Value
    ) {
        if keyToValue[key] == value {
            return
        }

        // Remove existing pair for this key.
        if let oldValue = keyToValue.removeValue(forKey: key) {
            valueToKey.removeValue(forKey: oldValue)
        }

        // Remove existing pair for this value.
        if let oldKey = valueToKey.removeValue(forKey: value) {
            keyToValue.removeValue(forKey: oldKey)
        }

        keyToValue[key] = value
        valueToKey[value] = key
    }

    /// Removes the pair associated with `key`.
    ///
    /// Average complexity: O(1)
    @discardableResult
    
    public mutating func remove(key: Key) -> Value? {
        guard let value = keyToValue.removeValue(forKey: key) else {
            return nil
        }

        valueToKey.removeValue(forKey: value)

        return value
    }

    /// Removes the pair associated with `value`.
    ///
    /// Average complexity: O(1)
    @discardableResult
    
    public mutating func remove(value: Value) -> Key? {
        guard let key = valueToKey.removeValue(forKey: value) else {
            return nil
        }

        keyToValue.removeValue(forKey: key)

        return key
    }

    /// Removes all elements.
    
    public mutating func removeAll(
        keepingCapacity: Bool = false
    ) {
        keyToValue.removeAll(keepingCapacity: keepingCapacity)
        valueToKey.removeAll(keepingCapacity: keepingCapacity)
    }

    // MARK: - Subscript

    /// Looks up a value by key.
    ///
    /// Assignment upserts: any existing pair that conflicts with the
    /// key or the value is replaced. Setting `nil` removes the pair.
    public subscript(key key: Key) -> Value? {
        get {
            keyToValue[key]
        }
        set {
            if let value = newValue {
                upsert(key: key, value: value)
            } else {
                remove(key: key)
            }
        }
    }

    /// Looks up a key by value.
    ///
    /// Assignment upserts: any existing pair that conflicts with the
    /// key or the value is replaced. Setting `nil` removes the pair.
    public subscript(value value: Value) -> Key? {
        get {
            valueToKey[value]
        }
        set {
            if let key = newValue {
                upsert(key: key, value: value)
            } else {
                remove(value: value)
            }
        }
    }

    // MARK: - Update

    /// Replaces the value associated with an existing key.
    ///
    /// If the new value already belongs to another key, the operation
    /// fails and the map remains unchanged.
    ///
    /// Average complexity: O(1)
    @discardableResult
    
    public mutating func update(
        key: Key,
        value: Value
    ) -> Bool {

        guard let oldValue = keyToValue[key] else {
            return false
        }

        // Same mapping — nothing to do.
        if oldValue == value {
            return true
        }

        // Value belongs to another key.
        if valueToKey[value] != nil {
            return false
        }

        keyToValue[key] = value
        valueToKey.removeValue(forKey: oldValue)
        valueToKey[value] = key

        return true
    }

    /// Replaces the key associated with an existing value.
    ///
    /// If the new key already belongs to another value, the operation
    /// fails and the map remains unchanged.
    ///
    /// Average complexity: O(1)
    @discardableResult
    
    public mutating func update(
        value: Value,
        key: Key
    ) -> Bool {

        guard let oldKey = valueToKey[value] else {
            return false
        }

        if oldKey == key {
            return true
        }

        if keyToValue[key] != nil {
            return false
        }

        valueToKey[value] = key
        keyToValue.removeValue(forKey: oldKey)
        keyToValue[key] = value

        return true
    }

    // MARK: - Validation

    /// Validates the internal bidirectional invariant.
    ///
    /// This is intended for assertions/debugging, not normal operation.
    
    public func validate() -> Bool {
        guard keyToValue.count == valueToKey.count else {
            return false
        }

        for (key, value) in keyToValue {
            guard valueToKey[value] == key else {
                return false
            }
        }

        return true
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension BiMap: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (Key, Value)...) {
        var keyToValue = Dictionary<Key, Value>(
            minimumCapacity: elements.count
        )

        var valueToKey = Dictionary<Value, Key>(
            minimumCapacity: elements.count
        )

        for (key, value) in elements {
            precondition(
                keyToValue[key] == nil,
                "BiMap: duplicate key: \(key)"
            )

            precondition(
                valueToKey[value] == nil,
                "BiMap: duplicate value: \(value)"
            )

            keyToValue[key] = value
            valueToKey[value] = key
        }

        self.keyToValue = keyToValue
        self.valueToKey = valueToKey
    }
}

// MARK: - Sequence

extension BiMap: Sequence {

    public typealias Element = (key: Key, value: Value)

    public func makeIterator()
        -> Dictionary<Key, Value>.Iterator
    {
        keyToValue.makeIterator()
    }
}

// MARK: - Equatable

extension BiMap: Equatable {

    public static func == (
        lhs: BiMap<Key, Value>,
        rhs: BiMap<Key, Value>
    ) -> Bool {
        lhs.keyToValue == rhs.keyToValue
    }
}

// MARK: - Hashable

extension BiMap: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyToValue)
    }
}

// MARK: - CustomStringConvertible

extension BiMap: CustomStringConvertible {

    public var description: String {
        keyToValue.description
    }
}
