import XCTest
@testable import Path

// MARK: - TestUtils.

private func _path(_ path: Path, componentsEqualTo components: [String]) -> Bool {
  return path._components.map { $0.rawValue } == components
}

// MARK: - PathTests.

final class PathTests: XCTestCase {
  static var allTests = [
    ("testEscaping", testEscaping),
  ]
  
  func testEscaping() {
    XCTAssertTrue(_path(Path("/usr/local/\\/bin"), componentsEqualTo: ["usr", "local", "\\/bin"]))
  }
  
  func testQuoting() {
    XCTAssertTrue(_path(Path("/usr/local/'/'bin"), componentsEqualTo: ["usr", "local", "'/'bin"]))
    XCTAssertTrue(_path(Path("/usr/local/\"/\"bin"), componentsEqualTo: ["usr", "local", "\"/\"bin"]))
  }
}
