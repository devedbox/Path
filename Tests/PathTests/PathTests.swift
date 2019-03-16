import XCTest
@testable import Path

final class PathTests: XCTestCase {
  static var allTests = [
    ("testEscaping", testEscaping),
  ]
  
  func testEscaping() {
    let path = Path("/usr/local/\\/bin")
    XCTAssertEqual(["usr", "local", "\\/bin"], path._components.map { $0.rawValue })
  }
  
  func testQuoting() {
    XCTAssertEqual(["usr", "local", "'/'bin"], Path("/usr/local/'/'bin")._components.map { $0.rawValue })
    XCTAssertEqual(["usr", "local", "\"/\"bin"], Path("/usr/local/\"/\"bin")._components.map { $0.rawValue })
  }
}
