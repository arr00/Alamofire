//
//  Mutex+Protector.swift
//
//  Copyright (c) 2014-2017 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation


/// A `pthread_mutex` wrapper, inspired by ProcedureKit.
final public class Mutex {
    private var mutex = pthread_mutex_t()
    
    public init() {
        let result = pthread_mutex_init(&mutex, nil)
        precondition(result == 0, "Failed to create pthread mutex")
    }
    
    deinit {
        let result = pthread_mutex_destroy(&mutex)
        assert(result == 0, "Failed to destroy mutex")
    }
    
    fileprivate func lock() {
        let result = pthread_mutex_lock(&mutex)
        assert(result == 0, "Failed to lock mutex")
    }
    
    fileprivate func unlock() {
        let result = pthread_mutex_unlock(&mutex)
        assert(result == 0, "Failed to unlock mutex")
    }

    /// Execute a value producing closure while aquiring the mutex.
    ///
    /// - Parameter closure: The closure to run.
    /// - Returns:           The value the closure generated.
    public func around<T>(closure: () -> T) -> T {
        lock(); defer { unlock() }
        return closure()
    }
    
    /// Execute a closure while aquiring the mutex.
    ///
    /// - Parameter closure: The closure to run.
    public func around(closure: () -> Void) {
        lock(); defer { unlock() }
        return closure()
    }
}

/// A thread-safe wrapper around a value.
public final class Protector<T> {
    private let mutex = Mutex()
    private var ward: T

    public init(_ ward: T) {
        self.ward = ward
    }

    /// The contained value. Unsafe for anything more than direct read or write.
    public var unsafeValue: T {
        get { return mutex.around { ward } }
        set { mutex.around { ward = newValue } }
    }

    /// Synchronously read or transform the contained value.
    ///
    /// - Parameter closure: The closure to execute.
    /// - Returns:           The return value of the closure passed.
    public func read<U>(_ closure: (T) -> U) -> U {
        return mutex.around { closure(self.ward) }
    }

    /// Synchronously modify the protected value.
    ///
    /// - Parameter closure: The closure to execute.
    /// - Returns:           The modified value.
    @discardableResult
    public func write<U>(_ closure: (inout T) -> U) -> U {
        return mutex.around { closure(&self.ward) }
    }
}

public extension Protector where T: RangeReplaceableCollection {

    func append(_ newElement: T.Iterator.Element) {
        write { (ward: inout T) in
            ward.append(newElement)
        }
    }

    func append<S: Sequence>(contentsOf newElements: S) where S.Iterator.Element == T.Iterator.Element {
        write { (ward: inout T) in
            ward.append(contentsOf: newElements)
        }
    }

    func append<C: Collection>(contentsOf newElements: C) where C.Iterator.Element == T.Iterator.Element {
        write { (ward: inout T) in
            ward.append(contentsOf: newElements)
        }
    }
}

public extension Protector where T: Strideable {

    func advance(by stride: T.Stride) {
        write { (ward: inout T) in
            ward = ward.advanced(by: stride)
        }
    }
}
