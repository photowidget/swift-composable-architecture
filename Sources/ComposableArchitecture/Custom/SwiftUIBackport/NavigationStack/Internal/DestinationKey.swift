//
//  DestinationKey.swift
//  
//
//  Created by Sunghyun Kim on 2023/06/17.
//

import Foundation

internal func identifier(for type: Any.Type) -> String {
    String(reflecting: type)
}

internal func key<T>(for typedData: T) -> String {
    let base = (typedData as? AnyHashable)?.base
    let type = type(of: base ?? typedData)
    return identifier(for: type)
}
