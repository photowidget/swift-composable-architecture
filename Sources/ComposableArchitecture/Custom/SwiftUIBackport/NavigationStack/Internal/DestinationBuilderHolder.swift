//
//  DestinationBuilderHolder.swift
//
//
//  Created by Sunghyun Kim on 2023/06/17.
//

import SwiftUI

/// Hashable로써 전달된 PathState를 key로 사용하여, NavigationStackStore의 CaseLet에서 선언된 View를 반환하는 역할.
public final class DestinationBuilderHolder: ObservableObject {
    internal var builders: [String: (Any) -> AnyView?] = [:]
    
    public func addDestination<D: Hashable, C: View>(builder: @escaping (D) -> C) {
        let key = identifier(for: D.self)
        builders[key] = { data in
            if let typedData = data as? D {
                return AnyView(builder(typedData))
            } else {
                return nil
            }
        }
    }
    
    public func removeDestination<D: Hashable>(data: D.Type) {
        let key = identifier(for: D.self)
        builders[key] = nil
    }
}
