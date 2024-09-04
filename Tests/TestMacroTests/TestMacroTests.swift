import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(TestMacroMacros)
import TestMacroMacros

let testMacros: [String: Macro.Type] = [
    "stringify": StringifyMacro.self,
]
#endif

final class TestMacroTests: XCTestCase {
    func testMacro() throws {
        #if canImport(TestMacroMacros)
        assertMacroExpansion(
            """
            #stringify(a + b)
            """,
            expandedSource: """
            (a + b, "a + b")
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithStringLiteral() throws {
        #if canImport(TestMacroMacros)
        assertMacroExpansion(
            #"""
            #stringify("Hello, \(name)")
            """#,
            expandedSource: #"""
            ("Hello, \(name)", #""Hello, \(name)""#)
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testInitializer() throws {
        assertMacroExpansion(
          """
          @ChanStorage
          struct Seungchan {
              let name: String
              let age: Int
          }
          """,
          expandedSource:
          """
          struct Seungchan {
              let name: String
              let age: Int
          
          public init(from decoder: Decoder) throws {
              let container = try.decoder.container(keyedBy: CodingKeys.self)
              let name = try container.decode(String.self, forKey: .name)
              let age = try container.decode(Int.self, forKey: .age)
            }
          }
          """,
          macros: ["ChanStorage": ChanStorage.self]
        )
    }
}
