//
//  GlobalNavigationDestination.swift
//  
//
//  Created by Sunghyun Kim on 2023/06/17.
//

import SwiftUI

extension View {
    public func navigationDestination2<D, C>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View where D: Hashable, C: View {
        modifier(AddDestination(builder: destination))
    }
}

/// Stack-based Navigation에서 사용 함.
public struct AddDestination<Data: Hashable, C: View>: ViewModifier {
    
    public var builder: (Data) -> C
    public init(builder: @escaping (Data) -> C) {
        self.builder = builder
    }
    
    @EnvironmentObject private var ncHolder: NavigationControllerHolder
    @EnvironmentObject private var destinationHolder: DestinationBuilderHolder
    
    public func body(content: Content) -> some View {
        destinationHolder.addDestination(builder: builder)
        return content
            .environmentObject(ncHolder)
            .environmentObject(destinationHolder)
            .onDeinit {
                destinationHolder.removeDestination(data: Data.self)
            }
    }
}
