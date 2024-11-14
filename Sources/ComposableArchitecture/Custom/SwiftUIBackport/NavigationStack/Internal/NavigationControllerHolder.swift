//
//  NavigationControllerHolder.swift
//  
//
//  Created by Sunghyun Kim on 2023/06/17.
//

import SwiftUI

final class NavigationControllerHolder: ObservableObject {
    weak var navigationController: UINavigationController?
    init(_ navigationController: UINavigationController? = nil) {
        self.navigationController = navigationController
    }
}
