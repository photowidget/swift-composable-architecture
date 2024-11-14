//
//  EnvWrapper.swift
//  
//
//  Created by Sunghyun Kim on 2023/06/17.
//

import SwiftUI

/// 제공된 view에 navigationController와 DestinationHolder를 주입하는 것이 목적인 View
///
/// destinationHolder에 local, globalDestination을 연결하기 위해서, DestinationHolder가 필요하다.
/// 이 때에 연결점을 제공하기 위해서, destinationHolder가 필요함.
/// PhotoWidget에서 개발된 NavigationStack2를 사용하는 환경에서, 아래 view를 사용하여 계층을 구성하지 않으면, crash가 발생 할 것.
/// 하지만, 이미 정의된 개발 방법을 통해서 개발한다면, 아래 view를 사용하지 않아서 crash가 발생하는 경우는 없을 것.
struct EnvWrapper<C: View>: View {
    
    var navigationController: UINavigationController?
    var destinationHolder: DestinationBuilderHolder
    var view: C
    var onDeinit: () -> Void = { }
    
    var body: some View {
        view
            .environmentObject(NavigationControllerHolder(navigationController))
            .environmentObject(destinationHolder)
            .onDeinit(perform: onDeinit)
    }
}
