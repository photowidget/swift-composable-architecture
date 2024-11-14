//
//  LocalNavigationDestination.swift
//  
//
//  Created by Sunghyun Kim on 2023/06/17.
//

import SwiftUI

extension View {
    @inlinable
    public func navigationDestination2<V: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: () -> V
    ) -> some View {
        modifier(LocalNavigationDestination(
            isPresented: isPresented,
            destination: destination()
        ))
    }
}

/// Tree-based navigation에서 사용 함. 순서를 보장해야만 하고, 제한된 컨트롤을 해야 할 때, Tree-based navigation을 고려 할 수 있다.
/// 이 떄에, 내부적으로 사용되는 것이 해당 struct
public struct LocalNavigationDestination<Destination: View>: ViewModifier {
    
    @Binding public var isPresented: Bool
    public var destination: Destination
    
    public init(
        isPresented: Binding<Bool>,
        destination: Destination
    ) {
        self._isPresented = isPresented
        self.destination = destination
    }
    
    @State private var firstAppear = true
    @StateObject private var parent = VCHolder()
    @StateObject private var destVC = VCHolder()
    @EnvironmentObject private var navigationControllerHolder: NavigationControllerHolder
    @EnvironmentObject private var destinationHolder: DestinationBuilderHolder
    
    private var navigationController: UINavigationController? {
        navigationControllerHolder.navigationController
    }
    
    public func body(content: Content) -> some View {
        updateNavigation(isPresented: isPresented, destination: destination, isFirst: false)
        if let vc = destVC.vc as? UIHostingController<EnvWrapper<Destination>> {
            vc.rootView = createEnvView(destination)
        }
        return content
            .environmentObject(navigationControllerHolder)
            .environmentObject(destinationHolder)
            .onAppear {
                if firstAppear {
                    firstAppear = false
                    parent.vc = navigationController?.topViewController
                    updateNavigation(isPresented: isPresented, destination: destination, isFirst: true)
                }
            }
    }
    
    
    
    private func updateNavigation(isPresented: Bool, destination: Destination, isFirst: Bool) {
        if isPresented {
            push(destination: destination, isFirst: isFirst)
        } else {
            pop()
        }
    }
    
    private func push(destination: Destination, isFirst: Bool) {
        guard
            destVC.vc == nil,
            let parent = parent.vc
        else { return }
        
        let hosting = UIHostingController(rootView: createEnvView(destination))
        destVC.vc = hosting
        
        if navigationController?.topViewController != parent {
            var vcs = navigationController?.viewControllers ?? []
            let firstIndex = vcs.firstIndex(of: parent) ?? vcs.count
            vcs.removeLast(vcs.count - firstIndex - 1)
            vcs.append(hosting)
            Task { @MainActor in
                navigationController?.setViewControllers(vcs, animated: true)
            }
            
        } else {
            if isFirst {
                Task { @MainActor in
                    navigationController?.pushViewController(hosting, animated: true)
                }
            } else {
                navigationController?.pushViewController(hosting, animated: true)
            }
        }
    }
    
    private func createEnvView(_ dest: Destination) -> EnvWrapper<Destination> {
        EnvWrapper(
            navigationController: navigationController,
            destinationHolder: destinationHolder,
            view: dest,
            onDeinit: { isPresented = false }
        )
    }
    
    private func pop() {
        guard
            destVC.vc != nil,
            let parent = parent.vc,
            navigationController?.topViewController != parent
        else { return }
        
        navigationController?.popToViewController(parent, animated: true)
        destVC.vc = nil
    }
}

fileprivate final class VCHolder: ObservableObject {
    weak var vc: UIViewController?
}
