//
//  ToDomainMacro.swift
//
//
//  Created by MEGA_Mac on 9/13/24.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ToDomainMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return []
        }

        let entityTypeName = structDecl.name.text

        let domainTypeName = entityTypeName.replacingOccurrences(of: "Entity", with: "Model")

        let properties = structDecl.memberBlock.members.compactMap { member -> String? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
            return varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        }

        let toDomainMethod: DeclSyntax = """
        public func toDomain() -> \(raw: domainTypeName) {
            return .init(\(raw: properties.map { "\($0): \($0)" }.joined(separator: ", ")))
        }
        """

        return [toDomainMethod]
    }
}
