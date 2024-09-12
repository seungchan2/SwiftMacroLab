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
                $0.accessorBlock == nil // Computed properties가 아닌 저장된 프로퍼티만 필터링
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

                // Optional 타입 처리
                if let optionalTyped = typeToken.as(OptionalTypeSyntax.self) {
                    let optionalType = optionalTyped.wrappedType.as(IdentifierTypeSyntax.self)?.name.text ?? "Unknown"
                    return #"self.\#(nameToken) = try container.decodeIfPresent(\#(optionalType).self, forKey: .\#(nameToken))"#
                }
                // 일반 타입 처리
                else if let simpleType = typeToken.as(IdentifierTypeSyntax.self)?.name.text {
                    return #"self.\#(nameToken) = try container.decode(\#(simpleType).self, forKey: .\#(nameToken))"#
                }

                return nil
            }
        
        let codingKeys = storedMemberBindingList
            .compactMap { binding -> String? in
                guard let nameToken = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                    return nil
                }
                return #"case \#(nameToken) = "\#(nameToken)""#
            }
        
        // 생성된 코드를 DeclSyntax로 반환
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
