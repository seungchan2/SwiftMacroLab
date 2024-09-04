//
//  File.swift
//
//
//  Created by MEGA_Mac on 9/4/24.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
        
        let codingKeys = storedMemberBindingList
            .compactMap { binding -> String? in
                guard let nameToken = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                    return nil
                }
                
                guard let typeToken = binding.typeAnnotation?.as(TypeAnnotationSyntax.self)?.type else {
                    return nil
                }
                
                if let optionalTyped = typeToken.as(OptionalTypeSyntax.self) {
                    let optionalType = optionalTyped.wrappedType.as(IdentifierTypeSyntax.self)?.name.text ?? "Unknown"
                    return #"case \#(nameToken) = "\#(nameToken)""#
                } else if let simpleType = typeToken.as(IdentifierTypeSyntax.self)?.name.text {
                    return #"case \#(nameToken) = "\#(nameToken)""#
                }
                
                return nil
                
            }
        
        let result: DeclSyntax =
        """
        enum CodingKeys: String, CodingKey {
            \(raw: codingKeys.joined(separator: "\n"))
        }
        
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

