//
//  NavigationStack.swift
//  
//
//  Created by Sunghyun Kim on 2023/06/17.
//

import SwiftUI
import UIKit

/// PhotoWidgetPackage.TCA.NavigationStackStore의 body를 대체하는 View
public struct NavigationStack2<Data: Hashable, Root: View>: UIViewControllerRepresentable {
    
    @Binding public var path: [Data]
    public var root: Root
    
    public init(
        path: Binding<[Data]>,
        @ViewBuilder root: () -> Root
    ) {
        self._path = path
        self.root = root()
    }
    
    /// path의 Element를 제거 할 수 있게 하는 코드. dataStream을 통해서 상위로 전달한다.
    /// 이는 state 변경에 따른, view의 변경이 아닌,
    /// 사용자 interaction에 따라서, 아래에서 위로 올라가는 방향으로 state의 변경을 유발함.
    /// navigation을 swipe하여 pop하는 경우가 이에 해당 함.
    public func makeUIViewController(context: Context) -> NavigationController<Data, Root> {
        let nc = NavigationController<Data, Root>(rootView: root)
        Task { @MainActor in
            for await data in nc.dataStream {
                path = data
            }
        }
        return nc
    }
    
    /// 상위의 State인 path의 변경을 관찰하는 코드. path와 root의 변경에 따라서, view를 다시 그린다.
    public func updateUIViewController(_ navigationController: NavigationController<Data, Root>, context: Context) {
        navigationController.updateQueue.send(path)
        navigationController.updateRootView(root)
    }
}
