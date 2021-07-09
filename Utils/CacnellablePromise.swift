//
//  CancellablePromise.swift
//  CancellablePromiseKit
//
//  Created by Johannes Dörr on 11.05.18.
//  Copyright © 2018 Johannes Dörr. All rights reserved.
//

import Foundation
import PromiseKit

internal class CancellablePromise<T> {

  /**
   Returns: True if this promise has been cancelled
   */
  public private(set) var isCancelled: Bool = false

  internal var subsequentCancels = [() -> Void]()

  private let promise: Promise<T>

  /**
   Returns the undelying promise
   */
  public func asPromise() -> Promise<T> {
    return promise
  }

  private let cancelPromise: Promise<Void>
  private let cancelResolver: Resolver<Void>
  private let cancelFunction: (() -> Void)

  /**
   Aborts the execution of the underlying task
   */
  public func cancel() {
    isCancelled = true
    subsequentCancels.forEach { $0() }
    if isPending {
      cancelFunction()
      // Let already scheduled promise blocks (like `then`) execute first, before rejecting:
      (conf.Q.map ?? DispatchQueue.main).async {
        self.cancelResolver.reject(CancellablePromiseError.cancelled)
      }
    }
  }

  fileprivate init(_ body: (_ cancelPromise: Promise<Void>) -> Promise<T>, cancel: @escaping () -> Void) {
    (self.cancelPromise, self.cancelResolver) = Promise<Void>.pending()
    self.promise = when(body(cancelPromise), while: cancelPromise)
    cancelFunction = cancel
  }

  public convenience init(using promise: Promise<T>, cancel: @escaping () -> Void) {
    self.init({ _ in promise }, cancel: cancel)
  }

  public convenience init(resolver body: (Resolver<T>) throws -> (() -> Void)) {
    let (promise, resolver) = Promise<T>.pending()
    do {
      let cancel = try body(resolver)
      self.init(using: promise, cancel: cancel)
    } catch let error {
      resolver.reject(error)
      self.init(using: promise, cancel: { })
    }
  }

  public convenience init(wrapper body: (_ cancelPromise: Promise<Void>) -> Promise<T>) {
    self.init(body, cancel: { })
  }

  deinit {
    // Prevent PromiseKit's warning that a pending promise has been deinited:
    let resolver = cancelResolver
    (conf.Q.map ?? DispatchQueue.main).async {
      resolver.fulfill(Void())
    }
  }

}

//swiftlint:disable identifier_name
extension CancellablePromise: Thenable, CatchMixin {
  func pipe(to: @escaping (Result<T>) -> Void) {
    asPromise().pipe(to: to)
  }

  var result: Result<T>? {
    return asPromise().result
  }
}

internal func cancelAll<T>(`in` array: [CancellablePromise<T>]) {
  array.forEach { (cancellablePromise) in
    cancellablePromise.cancel()
  }
}

internal extension CancellablePromise {

  func map<U>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping(T) throws -> U) -> CancellablePromise<U> {
    return CancellablePromise<U>(using: self.asPromise().map(on: on, transform), cancel: cancel)
  }

  func compactMap<U>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping (T) throws -> U?) -> CancellablePromise<U> {
    return CancellablePromise<U>(using: self.asPromise().compactMap(on: on, transform),
                                 cancel: cancel)
  }

  func asVoid() -> CancellablePromise<Void> {
    return map(on: nil) { _ in }
  }

}

/**
 Parameter cancellablePromises: The promises to wait for
 Parameter autoCancel: Specifies if the other provided promises should be cancelled when one of them fulfills, or when the returned promise is cancelled
 */
internal func race<T>(_ cancellablePromises: [CancellablePromise<T>], autoCancel: Bool) -> CancellablePromise<T> {
  return CancellablePromise { (cancelPromise) -> Promise<T> in
    let promise = race(cancellablePromises.map { $0.asPromise() })
    return when(promise, while: cancelPromise).ensure {
      if autoCancel {
        cancelAll(in: cancellablePromises)
      }
    }
  }
}

internal func race<T>(_ cancellablePromises: [CancellablePromise<T>]) -> CancellablePromise<T> {
  return race(cancellablePromises, autoCancel: false)
}

internal extension CancellablePromise {
  func then<V>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, line: UInt = #line, _     body: @escaping(T) throws -> CancellablePromise<V>) -> CancellablePromise<V> {
    let promise: Promise<V> = then { (value) -> Promise<V> in
      let cancellablePromise = try body(value)
      if self.isCancelled {
        cancellablePromise.cancel()
      }
      self.subsequentCancels.append(cancellablePromise.cancel)
      return cancellablePromise.asPromise()
    }
    let cancellablePromise = CancellablePromise<V>(using: promise, cancel: cancel)
    return cancellablePromise
  }
}

/**
 Wait for promise, but abort if conditionPromise fails
 */
internal func when<T>(_ promise: Promise<T>, while conditionPromise: Promise<Void>) -> Promise<T> {
  return when(fulfilled: [promise.asVoid(), race([promise.asVoid(), conditionPromise.asVoid()])]).map({ _ -> T in
    promise.value!
  })
}

internal func when<T>(_ cancellablePromise: CancellablePromise<T>, while conditionPromise: Promise<Void>, autoCancel: Bool = false) -> Promise<T> {
  return when(fulfilled: [cancellablePromise.asVoid(), race([cancellablePromise.asVoid(), conditionPromise.asVoid()])]).map({ _ -> T in
    cancellablePromise.value!
  }).ensure {
    if autoCancel {
      cancellablePromise.cancel()
    }
  }
}

/**
 Parameter cancellablePromises: The promises to wait for
 Parameter autoCancel: Specifies if the provided promises should be cancelled when one of them rejects, or when the returned promise is cancelled
 */
internal func when<T>(fulfilled cancellablePromises: [CancellablePromise<T>], autoCancel: Bool) -> CancellablePromise<[T]> {
  return CancellablePromise { (cancelPromise) -> Promise<[T]> in
    let promise = when(fulfilled: cancellablePromises.map { $0.asPromise() })
    return when(promise, while: cancelPromise).ensure {
      if autoCancel {
        cancelAll(in: cancellablePromises)
      }
    }
  }
}

internal func when<T>(fulfilled cancellablePromises: [CancellablePromise<T>]) -> CancellablePromise<[T]> {
  return when(fulfilled: cancellablePromises, autoCancel: false)
}

/**
 Parameter cancellablePromises: The promises to wait for
 Parameter autoCancel: Specifies if the provided promises should be cancelled when the returned promise is cancelled
 */
internal func when<T>(resolved cancellablePromises: [CancellablePromise<T>], autoCancel: Bool) -> CancellablePromise<[Result<T>]> {
  return CancellablePromise { (cancelPromise) -> Promise<[Result<T>]> in
    let guarantee = when(resolved: cancellablePromises.map { $0.asPromise() })
    let promise: Promise<[Result<T>]> = guarantee.mapValues({ $0 })
    return when(promise, while: cancelPromise).ensure {
      if autoCancel {
        cancelAll(in: cancellablePromises)
      }
    }
  }
}

internal func when<T>(resolved cancellablePromises: [CancellablePromise<T>]) -> CancellablePromise<[Result<T>]> {
  return when(resolved: cancellablePromises, autoCancel: false)
}

internal enum CancellablePromiseError: Swift.Error, CancellableError {
  case cancelled
}

internal extension CancellablePromiseError {

  var isCancelled: Bool {
    switch self {
    case .cancelled:
      return true
    }
  }

}

extension Promise {
  /**
   Returns a CancellablePromise.
   */
  func asCancellable() -> CancellablePromise<T> {
    return CancellablePromise(wrapper: { cancelPromise in
      return when(self, while: cancelPromise)
    })
  }
}

extension Guarantee {
  /**
   Returns a CancellablePromise.
   */
  func asCancellable() -> CancellablePromise<T> {
    return Promise(self).asCancellable()
  }
}
