//
//  Path.swift
//  Path
//
//  Created by devedbox on 2019/3/15.
//

#if os(macOS)
import Darwin
#else
import Glibc
#endif

// POSIX.1-2017 General Concepts: http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap04.html#tag_04_13
//
// 4.13 Pathname Resolution

private func _parsePathRawString<S: StringProtocol>(_ string: S) -> [String] {
  var isEscaping = false // Indicates the following char is escaping.
  var isQuoted = false   // Indicates the beginning of quotation.
  var components: [String] = []
  var positioning: String?
  
  func advance() {
    defer {
      positioning = nil
    }
    
    if let val = positioning {
      components.append(val)
    }
  }
  
  func read(_ char: Character, readonly: Bool = false) {
    positioning == nil ? positioning = "" : ()
    positioning?.append(char)
    
    guard !readonly else {
      return
    }
    
    isEscaping ? isEscaping.toggle() : ()
  }
  
  func isAdvancable() -> Bool { return !isEscaping && !isQuoted }
  func isEscapable()  -> Bool { return isAdvancable() }
  func isQuotable()   -> Bool { return !isQuoted && !isEscaping }
  func isUnQuotable() -> Bool { return isQuoted }
  func isReadable()   -> Bool { return false }
  
  var iterator = string.makeIterator()
  while let char = iterator.next() {
    switch char {
    case Path._pathComponentsDelimiter  where isAdvancable(): advance()
    case "\"" where isQuotable():   isQuoted = true; read(char)
    case "'"  where isQuotable():   isQuoted = true; read(char)
    case "\"" where isUnQuotable(): isQuoted = false; read(char)
    case "'"  where isUnQuotable(): isQuoted = false; read(char)
    case "\\" where isEscapable():  isEscaping = true; read(char, readonly: true)
    default: read(char)
    }
  }
  
  advance()
  
  return components
}

extension Path {
  /// The component of the path.
  public enum Component: RawRepresentable {
    public typealias RawValue = String
    
    case current
    case parent
    case empty
    case item(named: String)
    
    public var rawValue: String {
      switch self {
      case .current: return "."
      case .parent:  return ".."
      case .empty:   return ""
      case .item(named: let value): return value
      }
    }
    
    public init(rawValue rawString: String) {
      switch rawString {
      case ".":  self = .current
      case "..": self = .parent
      case "":   self = .empty
      default:   self = .item(named: rawString)
      }
    }
  }
}

extension Path {
  fileprivate static let _pathComponentsDelimiter: Character = "/"
}

public struct Path {
  internal let _components: [Component]
  
  public init<T: StringProtocol>(_ string: T) {
    _components = _parsePathRawString(string).map { Component(rawValue: $0) }
  }
}

extension Path: ExpressibleByStringLiteral {
  public typealias StringLiteralType = String
  
  public init(stringLiteral value: String) {
    self.init(value)
  }
}

extension Path {
  public func absolutize() {
    
  }
}

// MARK: - Path: RawRepresentable.

extension Path: RawRepresentable {
  public typealias RawValue = String
  
  public var rawValue: String {
    return _components.map { $0.rawValue }.joined(separator: String(Path._pathComponentsDelimiter))
  }
  
  public init(rawValue value: String) {
    self.init(value)
  }
}

// MARK: - Trimming.

extension Path {
  public struct Trimming: OptionSet {
    public typealias RawValue = UInt8
    
    fileprivate struct _IdenticalFilter: Equatable, Hashable {
      let rawValue: RawValue
      let filter: (Component) -> Bool
      
      public var hashValue: Int {
        return Int(rawValue)
      }
      
      static func ==(left: _IdenticalFilter, right: _IdenticalFilter) -> Bool {
        return left.rawValue == right.rawValue
      }
      
      static func `default`(rawValue: RawValue) -> _IdenticalFilter {
        return _IdenticalFilter(rawValue: rawValue, filter: { _ in false })
      }
    }
    
    public static let emptiness = Trimming(rawValue: 1 << 0, filters: [_IdenticalFilter(rawValue: 1 << 0, filter: { $0 != .empty })])
    public static let `self`    = Trimming(rawValue: 1 << 1, filters: [_IdenticalFilter(rawValue: 1 << 1, filter: { $0 != .current })])
    public static let parent    = Trimming(rawValue: 1 << 2, filters: [_IdenticalFilter(rawValue: 1 << 2, filter: { $0 == $0 })])
    
    private var _filters: [_IdenticalFilter]
    private let _rawValue: RawValue
    
    public var rawValue: RawValue {
      return _rawValue
    }
    
    public init(rawValue: RawValue) {
      self.init(rawValue: rawValue, filters: [.default(rawValue: rawValue)])
    }
    
    private init(
      rawValue: RawValue,
      filters: [_IdenticalFilter])
    {
      _rawValue = rawValue
      _filters = filters
    }
    
    internal func filter(_ comp: Component) -> Bool {
      return _filters.reduce(true) { $0 && $1.filter(comp) }
    }

    /// Adds the elements of the given set to the set.
    ///
    /// In the following example, the elements of the `visitors` set are added to
    /// the `attendees` set:
    ///
    ///     var attendees: Set = ["Alicia", "Bethany", "Diana"]
    ///     let visitors: Set = ["Diana", "Marcia", "Nathaniel"]
    ///     attendees.formUnion(visitors)
    ///     print(attendees)
    ///     // Prints "["Diana", "Nathaniel", "Bethany", "Alicia", "Marcia"]"
    ///
    /// If the set already contains one or more elements that are also in
    /// `other`, the existing members are kept.
    ///
    ///     var initialIndices = Set(0..<5)
    ///     initialIndices.formUnion([2, 3, 6, 7])
    ///     print(initialIndices)
    ///     // Prints "[2, 4, 6, 7, 0, 1, 3]"
    ///
    /// - Parameter other: A set of the same type as the current set.
    public mutating func formUnion(_ other: Trimming) {
      let filters = self._filters
      self = Trimming(
        rawValue: _rawValue | other._rawValue,
        filters: Array(Set(filters).union(Set(other._filters)))
      )
    }
    /// Removes the elements of this set that aren't also in the given set.
    ///
    /// In the following example, the elements of the `employees` set that are
    /// not also members of the `neighbors` set are removed. In particular, the
    /// names `"Alicia"`, `"Chris"`, and `"Diana"` are removed.
    ///
    ///     var employees: Set = ["Alicia", "Bethany", "Chris", "Diana", "Eric"]
    ///     let neighbors: Set = ["Bethany", "Eric", "Forlani", "Greta"]
    ///     employees.formIntersection(neighbors)
    ///     print(employees)
    ///     // Prints "["Bethany", "Eric"]"
    ///
    /// - Parameter other: A set of the same type as the current set.
    public mutating func formIntersection(_ other: Trimming) {
      let filters = self._filters
      self = Trimming(
        rawValue: _rawValue & other.rawValue,
        filters: Array(Set(filters).intersection(Set(other._filters)))
      )
    }
    /// Removes the elements of the set that are also in the given set and adds
    /// the members of the given set that are not already in the set.
    ///
    /// In the following example, the elements of the `employees` set that are
    /// also members of `neighbors` are removed from `employees`, while the
    /// elements of `neighbors` that are not members of `employees` are added to
    /// `employees`. In particular, the names `"Bethany"` and `"Eric"` are
    /// removed from `employees` while the name `"Forlani"` is added.
    ///
    ///     var employees: Set = ["Alicia", "Bethany", "Diana", "Eric"]
    ///     let neighbors: Set = ["Bethany", "Eric", "Forlani"]
    ///     employees.formSymmetricDifference(neighbors)
    ///     print(employees)
    ///     // Prints "["Diana", "Forlani", "Alicia"]"
    ///
    /// - Parameter other: A set of the same type.
    public mutating func formSymmetricDifference(_ other: Trimming) {
      let filters = self._filters
      self = Trimming(
        rawValue: _rawValue ^ other._rawValue,
        filters: Array(Set(filters).symmetricDifference(Set(other._filters)))
      )
    }
  }
}

extension Path {
  public func rawValue(trimming: Trimming) -> RawValue {
    var components: [Component] = []
    
    _components.filter(trimming.filter).forEach {
      if
        trimming.contains(.parent),
        $0 == .parent,
        let index = components.lastIndex(where: { $0 == .item(named: "") })
      {
        components.remove(at: index)
      } else {
        components.append($0)
      }
    }
    
    return components.map { $0.rawValue }.joined(separator: String(Path._pathComponentsDelimiter))
  }
}
