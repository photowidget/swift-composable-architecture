//
//  OnDeinit.swift
//  
//
//  Created by Sunghyun Kim on 2023/06/17.
//

import SwiftUI

extension View {
    func onDeinit(perform action: @escaping () -> Void) -> some View {
        modifier(DeinitObserver(deinitAction: action))
    }
}

struct DeinitObserver: ViewModifier {
    
    var deinitAction: () -> Void
    
    func body(content: Content) -> some View {
        content
            .background {
                DeinitObserveView(deinitAction: deinitAction)
            }
    }
}

fileprivate struct DeinitObserveView: UIViewRepresentable {
    
    var deinitAction: () -> Void
    
    func makeUIView(context: Context) -> DeinitObservingView {
        DeinitObservingView(deinitAction: deinitAction)
    }
    
    func updateUIView(_ uiView: DeinitObservingView, context: Context) {
        uiView.deinitAction = deinitAction
    }
    
}

fileprivate final class DeinitObservingView: UIView {
    
    var deinitAction: () -> Void
    
    init(deinitAction: @escaping () -> Void) {
        self.deinitAction = deinitAction
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        deinitAction()
    }
}
