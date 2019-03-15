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
  var positioning: String = String()
  
  func advance() {
    defer {
      positioning.removeAll()
    }
    components.append(positioning)
  }
  
  func read(_ char: Character) {
    positioning.append(char)
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
    case "/"  where isAdvancable(): advance()
    case "\"" where isQuotable():   isQuoted = true; read(char)
    case "'"  where isQuotable():   isQuoted = true; read(char)
    case "\"" where isUnQuotable(): isQuoted = false; read(char)
    case "'"  where isUnQuotable(): isQuoted = false; read(char)
    case "\\" where isEscapable():  isEscaping = true; read(char)
    default: read(char)
    }
  }
  
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
//  private enum
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
