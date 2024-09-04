import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `stringify` macro, which takes an expression
/// of any type and produces a tuple containing the value of that expression
/// and the source code that produced the value. For example
///
///     #stringify(x + y)
///
///  will expand to
///
///     (x + y, "x + y")
public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        guard let argument = node.argumentList.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return "(\(argument), \(literal: argument.description))"
    }
}

@main
struct TestMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StringifyMacro.self,
        InitDecodable.self
    ]
}

public struct InitDecodable: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let memberList = declaration.memberBlock.members
        let storedMemberBindingList = memberList
            .compactMap {
                $0.decl.as(VariableDeclSyntax.self)?.bindings.first
            }
            .filter {
                $0.accessorBlock == nil
            }

        guard !storedMemberBindingList.isEmpty else { return [] }

        let assignmentStmts = storedMemberBindingList
            .compactMap { binding -> String? in
                guard let nameToken = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                    return nil
                }

                guard let typeToken = binding.typeAnnotation?.as(TypeAnnotationSyntax.self)?.type else {
                    return nil
                }

                if let optionalTyped = typeToken.as(OptionalTypeSyntax.self) {
                    let optionalType = optionalTyped.wrappedType.as(IdentifierTypeSyntax.self)?.name.text ?? "Unknown"
                    return #"self.\#(nameToken) = try container.decodeIfPresent(\#(optionalType).self, forKey: .\#(nameToken))"#
                } else if let simpleType = typeToken.as(IdentifierTypeSyntax.self)?.name.text {
                    return #"self.\#(nameToken) = try container.decode(\#(simpleType).self, forKey: .\#(nameToken))"#
                }

                return nil
            }

        let result: DeclSyntax =
        """
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            \(raw: assignmentStmts.joined(separator: "\n"))
        }
        """
        return [
            result
        ]
    }
}

extension InitDecodable: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        return [try ExtensionDeclSyntax("extension \(type): Codable {}")]
    }
}

