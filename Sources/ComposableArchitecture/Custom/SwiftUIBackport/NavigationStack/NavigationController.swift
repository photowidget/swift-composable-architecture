//
//  NavigationController.swift
//
//
//  Created by Sunghyun Kim on 2023/06/17.
//

import SwiftUI
import UIKit
import Combine

open class NavigationController<Data: Hashable, Root: View>: UINavigationController {
    
    /// 상태를 전달하기 위한 continuation
    private var dataContinuation: AsyncStream<[Data]>.Continuation?
    /// 상태를 전달하는 AsyncStream
    public lazy var dataStream: AsyncStream<[Data]> = {
        AsyncStream { dataContinuation = $0 }
    }()
    
    deinit {
        dataContinuation?.finish()
    }
    
    /// PathState
    private var data: [Data]  = []
    
    public let destinationHolder = DestinationBuilderHolder()
    
    /// 특정 vc가 navigationStack의 몇번째 화면인지 알 필요가 있음, 기존값에 접근하기 위해서, 이를 저장 함.
    /// -> UIKit에서는 setVC로 VC 배열을 대체하려고 할 때, path의 update가 필요하다. 때문에, 새로 대체된 vc가 기존 path와 매핑된 vc인지 확인이 필요함.
    private var dataIndex: [UIViewController: Int] = [:]
    
    private let rootVC: UIHostingController<EnvWrapper<Root>>?
    
    private var subs: Set<AnyCancellable> = []
    
    /// 상위에서 state가 변경되었을 때, send 함.
    /// 아래의 subscribe() 에서 사용 됨.
    public let updateQueue = PassthroughSubject<[Data], Never>()
    
    public init(rootView: Root) {
        let view = EnvWrapper(
            navigationController: nil,
            destinationHolder: destinationHolder,
            view: rootView)
        rootVC = UIHostingController(rootView: view)
        super.init(rootViewController: rootVC!)
        
        rootVC?.rootView.navigationController = self
        rootVC?.rootView.navigationController?.setNavigationBarHidden(true, animated: false)
        subscribe()
    }
    
    public override init(rootViewController: UIViewController) {
        rootVC = nil
        super.init(rootViewController: rootViewController)
        subscribe()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func subscribe() {
        
        // 아래에서 updateQueue는 두 번 subscribe된다. 하지만
        // filter를 사용하여 서로 반대되는 경우를 구분하여 처리한다.
        // 정말 그럴 일이 없겠지만, 혹시나, 아래의 코드에서 문제가 생길 수도 있기는 하다. 그런데 그게 뭔지 추론이 안됨.
        // 혹시 정말로 문제가 생겨서 뭔지 모르겠을 떄 의심 할 수 있는 부분 중 하나.
        
        // path의 수가 다르므로, navigation이 일어나는 경우.
        updateQueue
            .filter { [weak self] in $0.count != self?.data.count }
            .throttle(for: 0.6, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] data in
                self?.updatePath(data: data)
            }
            .store(in: &subs)
        
        // path.count는 같으므로, navigation은 일어나지 않음.
        // type이 변하거나, view의 State가 바뀌는 경우가 해당 함.
        updateQueue
            .filter { [weak self] in $0.count == self?.data.count }
            .sink { [weak self] data in
                Task { @MainActor in
                    self?.updateViewOnly(data: data)
                }
            }
            .store(in: &subs)
    }
    
    private func createEnvView<C: View>(_ view: C) -> EnvWrapper<C> {
        return EnvWrapper(
            navigationController: self,
            destinationHolder: destinationHolder,
            view: view
        )
    }
    
    func updateRootView(_ root: Root) {
        rootVC?.rootView = createEnvView(root)
    }
    
    private var isUpdating = false
    
    private func updatePath(data: [Data]) {
        dataIndex = [:]
        
        var newPath: [UIViewController] = [rootViewController]
        let pathViewControllers = pathViewControllers
        
        for (index, datum) in data.enumerated() {
            let key = key(for: datum)
            guard let view = destinationHolder.builders[key]?(datum) else {
                print("NavigationLink가 “\(key)” 유형의 값을 표시하려 했지만 일치하는 navigationDestination 선언이 없음. 링크를 활성화할 수 없음.")
                let view = AnyView(Text("⚠️"))
                let warning = UIHostingController(rootView: createEnvView(view))
                newPath.append(warning)
                dataIndex[warning] = index
                continue
            }
            
            // view의 추가가 아닌, 현재 view를 변경하는 동작을 실행시키는 조건문
            // path의 type은 같은데, 내부 state가 변경되어 UI를 다시그리는 경우가 이에 해당 할 것.
            // type이 다른경우에도 다시 그릴 것.
            // 이 때에, type이 같은 경우, view가 다시 init 된 것이 아니므로, onAppear가 실행되지 않는다.
            if
                pathViewControllers.count > index,
                let hosting = pathViewControllers[index] as? UIHostingController<EnvWrapper<AnyView>>
            {
                hosting.rootView = createEnvView(view)
                newPath.append(hosting)
                dataIndex[hosting] = index
            }
            // 새로 view를 init하여 push하는 경우. 기존 path의 Element.count보다, 새로 갱신된 data.count가 큰 경우에 해당.
            else {
                let hosting = UIHostingController(rootView: createEnvView(view))
                newPath.append(hosting)
                dataIndex[hosting] = index
            }
        }
        
        self.data = data
        
        // TODO: 기능상 작동을 위해, 코드의 아름다움을 배제하고 작성된 부분. 수정을 요한다.
        // 원작자가 제안하는 방법으로는, 바로 아래의 setViewControllers를 super.setViewControllers로 변경해 보는 것.
        isUpdating = true
        setViewControllers(newPath, animated: true)
        isUpdating = false
        // 해설: 상위의 state의 변경을 관찰하여, view를 변경한다. 이 때에, self.setViewControllers 내부에는
        // dataContinuation?.yield(data)구문이 있어, 상위에 state 변경을 유발한다.
        // 상위의 stat가 변경되어 view를 바꾸었는데, 다시 상위 state를 변경을 유발 하면 안되므로 이를 막기위한 코드 블록임.
    }
    
    private func updateViewOnly(data: [Data]) {
        
        for (datum, vc) in zip(data, pathViewControllers) {
            let key = key(for: datum)
            if
                let view = destinationHolder.builders[key]?(datum),
                let hosting = vc as? UIHostingController<EnvWrapper<AnyView>>
            {
                hosting.rootView = createEnvView(view)
            }
        }
    }
    
    /// 레거시 대응용이며, 이를 위해서 dataContinuation?.yield(data) 같은 코드를 통해서 dataStream으로 상태 변경을 촉구한다.
    public override func popViewController(animated: Bool) -> UIViewController? {
        guard let poppedVC = super.popViewController(animated: animated) else {
            return nil
        }
        let publishData: () -> Void = { [weak self] in
            guard let self else { return }
            if let index = dataIndex.removeValue(forKey: poppedVC) {
                data.remove(at: index)
                dataContinuation?.yield(data)
            }
        }
        if animated, let transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: nil) { context in
                if !context.isCancelled { publishData() }
            }
        } else {
            publishData()
        }
        return poppedVC
    }
    
    /// 레거시 대응용이며, 이를 위해서 dataContinuation?.yield(data) 같은 코드를 통해서 dataStream으로 상태 변경을 촉구한다.
    public override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        guard let poppedVCs = super.popToViewController(viewController, animated: animated) else {
            return nil
        }
        for poppedVC in poppedVCs.reversed() {
            if let index = dataIndex.removeValue(forKey: poppedVC) {
                data.remove(at: index)
            }
        }
        dataContinuation?.yield(data)
        return poppedVCs
    }
    
    /// 레거시 대응용이며, 이를 위해서 dataContinuation?.yield(data) 같은 코드를 통해서 dataStream으로 상태 변경을 촉구한다.
    public override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        guard let poppedVCs = super.popToRootViewController(animated: animated) else {
            return nil
        }
        dataIndex = [:]
        data = []
        dataContinuation?.yield(data)
        return poppedVCs
    }
    
    /// 레거시 대응용이며, 이를 위해서 dataContinuation?.yield(data) 같은 코드를 통해서 dataStream으로 상태 변경을 촉구한다.
    public override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        guard viewControllers.count > 1 else { return }
        var newData: [Data] = []
        for vc in viewControllers[1...] {
            if let index = dataIndex[vc] {
                newData.append(data[index])
            }
        }
        if !isUpdating {
            data = newData
            dataContinuation?.yield(data)
        }
    }
    
    private var rootViewController: UIViewController {
        viewControllers.first!
    }
    private var pathViewControllers: [UIViewController] {
        guard viewControllers.count > 1 else { return [] }
        return Array(viewControllers[1...])
    }
}
