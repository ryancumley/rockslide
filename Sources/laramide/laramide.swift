//Created by Ryan Cumley
//MIT License
//Copyright (c) 2021 Ryan Cumley

import Combine
import SwiftUI

///Similar in most ways to `Element` in the Reactive Streams Specification, an `Event<T>` is the granular/discreet/individual package of data which is "streamed" through the components of a reactive system.
///
///While `Event<T>` is a value type, and allows us to realize the RSS's goal of a definitively sequencable series of events passed over asynchronous boundaries; `Event<T>` includes the ability to optionally attach the previously emitted value in the sequence along with the current one. This extra information can be useful in certain situations where the `difference` between current/previous is desired, but a subscriber does not wish to maintain state/history. For example, as a performance optimization where a subscriber only takes action when a value changes, and ignores the event if the new value is the same as the previous.
///
///Since this abstraction is still a singular value, we may still exercise all of our familiar Functional Programming toolkits to ensure that every Subscribing Component processes a `well-ordered` sequence of discreet events.
///
///However, a clever author could certainly compare what the publisher intended as `previous` with how the events actually arrived over the asynchronous boundary, and construct a valid alternate history/sequence/stream, allowing them to "break" the core abstraction of reactive programming: locally well-ordered sequences. In practice, this is unlikely to cause real problems.
public struct Event<T> {
    public let new: T
    public let previous: T
}

///Similar to PassthroughSubject and CurrentValueSubject, Signal<T> provides a bridge between the Imperative and Reactive worlds. The difference is where PassthroughSubject is ephemeral, and CurrentValueSubject is stateful with respect to a single value (ie. you can query CurrentValueSubject at any moment to learn the current 'state'), Signal remembers not just the current state, but the previous state as well, up to a time history depth of (t - 1)
///
///Signal also has the necessary hooks and features to be used by our composition operator `~>>`
///
///Signal<T> may be instantiated with only a current value, or a current & a previous value. In situations where a sensible initial value is not obvious, use of an `initialized` case/state is typically very effective.
///
///As a Publisher, Signal<T> will emit values every time `update(_ value)` is called, regardless of whether or not it was initialized with one or more values.
///
///Whether or not it's cheating to "remember" a portion of a stream's history (in this case merely the most recently emitted value alone), this abstraction still allows for Functional Programming purity, as the `Event<T>` emitted is a pure value type, eminently suitable for pure functional computation.
public final class Signal<T>: Publisher {
    public typealias Output = Event<T>
    public typealias Failure = Never
    
    private var subscribers: Array<AnySubscriber<Event<T>, Never>> = []
    public func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Event<T> == S.Input {
        subscribers.append(AnySubscriber(subscriber))
    }
    
    fileprivate(set) var currentValue: T
    fileprivate(set) var previousValue: T
    
    //syntax sugar for the ~>> operator overload impls
    fileprivate var c: T { return currentValue }
    fileprivate var p: T { return previousValue }
    
    public func update(_ newValue: T) {
        let event = Event<T>(new: newValue, previous: currentValue)
        
        subscribers.enumerated().forEach{
            _ = $0.element.receive(event)
            //Removing the backpressure mechanism temporarily for these core elements
        }
        
        self.previousValue = self.currentValue
        self.currentValue = newValue
    }
    
    public init(current: T, previous: T? = nil) {
        self.currentValue = current
        switch previous {
        case .none: self.previousValue = current
        case .some(let value): self.previousValue = value
        }
    }
    
    deinit {
        subscribers.forEach{ $0.receive(completion: .finished) }
        subscribers = []
        observations.removeAll()
    }
    
    public func combine<U>(_ next: Signal<U>) -> Signal<(T,U)> {
        let newCurrent: (T,U) = (self.currentValue, next.currentValue)
        let newPrevious: (T,U) = (self.previousValue, next.previousValue)
        let merged = Signal<(T,U)>(current: newCurrent, previous: newPrevious)
        
        //Unlike combineLatest, we know that we already have values at instantiation, so we can begin publishing new events as soon as either lhs/rhs publishes
        self.sink{ merged.update(($0.new, merged.currentValue.1))}
        .store(in: &merged.observations)
        
        next.sink{ merged.update((merged.currentValue.0, $0.new))}
        .store(in: &merged.observations)
        
        return merged
    }
    
    fileprivate var observations = Set<AnyCancellable>()
}

///The foundational unit of composition for a reactive system, a `ReactiveComponent` defines & publishes a stream of `Event<Model>`'s; and optionally defines an upstream `Event<Model>` which it subscribes to, as well as how to react to publications of that upstream `Event<Model>`
///
///You may use ReactiveComponent as the beginning/origin of a stream by declaring `typealias UpstreamModel = ()`, which makes your component satisfy the "Publisher" component spec from RSS. If both `Model` and `UpstreamModel` are defined, then your component satisfies the `Processor` component spec from RSS, and can be thought of as fitting into the "Middle" of a stream.
public protocol ReactiveComponent {
    associatedtype Model
    var state: Signal<Model> { get }
    
    associatedtype UpstreamModel
    func react(toNew: UpstreamModel)
    func react(toNew: UpstreamModel, withPrevious: UpstreamModel)
}

public extension ReactiveComponent {
    //The `Diffable` method signature had an empty default implementation to make it an `opt-in` feature
    func react(toNew: UpstreamModel, withPrevious: UpstreamModel) {}
    func erased() -> AnyComponent<Model> { return AnyComponent<Model>(state) }
    func erasedSwiftUI() -> AnySwiftUICompatibleComponent<Model> { return AnySwiftUICompatibleComponent<Model>(state) }
    
    //syntax sugar to make the tupple flatening operator overloads easier to read/write
    fileprivate var c: Model { return state.currentValue }
    fileprivate var p: Model { return state.previousValue }
}

//When you're the first component in a stream, you don't have to react to anybody
public extension ReactiveComponent where UpstreamModel == () {
    func react(toNew: UpstreamModel) {}
    func react(toNew: UpstreamModel, withPrevious: UpstreamModel) {}
}

///Type erasure to enable the operator methods to work
public class AnyComponent<T>: ReactiveComponent, ObservableObject {
    public typealias Model = T
    public typealias UpstreamModel = () //Type erasure actually erases our upstream type info too in our situation! kind of cool.
    public var state: Signal<Model>
    public init(_ state: Signal<Model>) { self.state = state }
}

///SwiftUI Flavored type-erased component to allow us to have a SwiftUI.View connect to our stream via the @Published propertyWrapper
public final class AnySwiftUICompatibleComponent<T>: ObservableObject {
    public typealias Model = T
    var state: Signal<Model>
    public init(_ state: Signal<Model>) {
        self.state = state
        connectComponents()
    }
    
    fileprivate func connectComponents() {
        state.sink{ [weak self] in
            self?.model = $0
        }
        .store(in: &state.observations)
    }
    
    //The SwiftUI.View mechanics are built on the `willSet` mechanics of the Published property wrapper
    //So we shadow that here specifically for SwiftUI interfaces.
    @Published public var model: Event<Model>?
}

///ReactiveRenderers define the "end" of a stream, subscribing to an upstream publisher of `Event<Model>`'s, but do not publish an events of their own.
///
///Defining your component as a ReactiveRenderer satisfies the `Subscriber` component spec from RSS
public protocol ReactiveSwiftUIRenderer: View {
    associatedtype Model
    var dataSource: AnySwiftUICompatibleComponent<Model> { get }
    init(dataSource: AnySwiftUICompatibleComponent<Model>)
}

//MARK: - The Stream Infix Operator ~>>
precedencegroup ReactiveStreamPrecedence {
    lowerThan: TernaryPrecedence
    higherThan: AssignmentPrecedence
    associativity: left
    assignment: false
}

infix operator ~>>: ReactiveStreamPrecedence

///Stream a ReactiveComponent into the next ReactiveComponent
public func ~>> <S: ReactiveComponent, C: ReactiveComponent>(lhs: S, rhs: C) -> AnyComponent<C.Model> where S.Model == C.UpstreamModel {
    lhs.state.sink{ event in
        rhs.react(toNew: event.new)
        rhs.react(toNew: event.new, withPrevious: event.previous)
    }
    .store(in: &rhs.state.observations)
    return rhs.erased()
}

///Terminate a stream into a SwiftUI Renderer
public func ~>> <S: ReactiveComponent, C: ReactiveSwiftUIRenderer>(lhs: S, rhs: C.Type) -> some View where S.Model == C.Model {
    return rhs.init(dataSource: lhs.erasedSwiftUI())
}

///Insert a transform/map function into a stream
public func ~>> <T,U,V: ReactiveComponent>(lhs: V, transform: @escaping (T) -> U) -> AnyComponent<U> where V.Model == T {
    let newSignal = Signal<U>(current: transform(lhs.state.currentValue), previous: transform(lhs.state.previousValue))
    lhs.state.sink{ newSignal.update(transform($0.new)) }
    .store(in: &newSignal.observations)
    return AnyComponent<U>(newSignal)
}

///Merge components into streamable tupples of their published values
public func ~>> <T: ReactiveComponent, U: ReactiveComponent>(lhs: T, rhs: U) -> AnyComponent<(T.Model, U.Model)> {
    return AnyComponent(lhs.state.combine(rhs.state))
}

//MARK: - Tupple flattening for merging signals up through arity 8
///<(J,K)> <U> ----> <(J,K,U)>
public func ~>> <T: ReactiveComponent, U: ReactiveComponent,J,K>(lhs: T, rhs: U) -> AnyComponent<(J,K,U.Model)> where T.Model == (J,K) {
    let m = Signal<(J,K,U.Model)>(
        current: (lhs.c.0, lhs.c.1, rhs.c),
        previous: (lhs.p.0, lhs.p.1, rhs.p)
        )
    lhs.state.sink{ m.update(($0.new.0, $0.new.1, m.c.2)) }
    .store(in: &m.observations)
    
    rhs.state.sink{ m.update((m.c.0, m.c.1, $0.new))}
    .store(in: &m.observations)
    
    return AnyComponent<(J,K,U.Model)>(m)
}

///<(J,K,L)> <U> ----> <(J,K,L,U)>
public func ~>> <T: ReactiveComponent, U: ReactiveComponent,J,K,L>(lhs: T, rhs: U) -> AnyComponent<(J,K,L,U.Model)> where T.Model == (J,K,L) {
    let m = Signal<(J,K,L,U.Model)>(
        current: (lhs.c.0, lhs.c.1, lhs.c.2, rhs.c),
        previous: (lhs.p.0, lhs.p.1, lhs.p.2, rhs.p)
        )
    lhs.state.sink{ m.update(($0.new.0, $0.new.1, $0.new.2, m.c.3)) }
    .store(in: &m.observations)
    
    rhs.state.sink{ m.update((m.c.0, m.c.1, m.c.2, $0.new))}
    .store(in: &m.observations)
    
    return AnyComponent<(J,K,L,U.Model)>(m)
}

///<(J,K,L,M)> <U> ----> <(J,K,L,M,U)>
public func ~>> <T: ReactiveComponent, U: ReactiveComponent,J,K,L,M>(lhs: T, rhs: U) -> AnyComponent<(J,K,L,M,U.Model)> where T.Model == (J,K,L,M) {
    let m = Signal<(J,K,L,M,U.Model)>(
        current: (lhs.c.0, lhs.c.1, lhs.c.2, lhs.c.3, rhs.c),
        previous: (lhs.p.0, lhs.p.1, lhs.p.2, lhs.p.3, rhs.p)
        )
    lhs.state.sink{ m.update(($0.new.0, $0.new.1, $0.new.2, $0.new.3, m.c.4)) }
    .store(in: &m.observations)
    
    rhs.state.sink{ m.update((m.c.0, m.c.1, m.c.2, m.c.3, $0.new))}
    .store(in: &m.observations)
    
    return AnyComponent<(J,K,L,M,U.Model)>(m)
}

///<(J,K,L,M,N)> <U> ----> <(J,K,L,M,N,U)>
public func ~>> <T: ReactiveComponent, U: ReactiveComponent,J,K,L,M,N>(lhs: T, rhs: U) -> AnyComponent<(J,K,L,M,N,U.Model)> where T.Model == (J,K,L,M,N) {
    let m = Signal<(J,K,L,M,N,U.Model)>(
        current: (lhs.c.0, lhs.c.1, lhs.c.2, lhs.c.3, lhs.c.4, rhs.c),
        previous: (lhs.p.0, lhs.p.1, lhs.p.2, lhs.p.3, lhs.p.4, rhs.p)
        )
    lhs.state.sink{ m.update(($0.new.0, $0.new.1, $0.new.2, $0.new.3, $0.new.4, m.c.5)) }
    .store(in: &m.observations)
    
    rhs.state.sink{ m.update((m.c.0, m.c.1, m.c.2, m.c.3, m.c.4, $0.new))}
    .store(in: &m.observations)
    
    return AnyComponent<(J,K,L,M,N,U.Model)>(m)
}

///<(J,K,L,M,N,O)> <U> ----> <(J,K,L,M,N,O,U)>
public func ~>> <T: ReactiveComponent, U: ReactiveComponent,J,K,L,M,N,O>(lhs: T, rhs: U) -> AnyComponent<(J,K,L,M,N,O,U.Model)> where T.Model == (J,K,L,M,N,O) {
    let m = Signal<(J,K,L,M,N,O,U.Model)>(
        current: (lhs.c.0, lhs.c.1, lhs.c.2, lhs.c.3, lhs.c.4, lhs.c.5, rhs.c),
        previous: (lhs.p.0, lhs.p.1, lhs.p.2, lhs.p.3, lhs.p.4, lhs.p.5, rhs.p)
        )
    lhs.state.sink{ m.update(($0.new.0, $0.new.1, $0.new.2, $0.new.3, $0.new.4, $0.new.5, m.c.6)) }
    .store(in: &m.observations)
    
    rhs.state.sink{ m.update((m.c.0, m.c.1, m.c.2, m.c.3, m.c.4, m.c.5, $0.new))}
    .store(in: &m.observations)
    
    return AnyComponent<(J,K,L,M,N,O,U.Model)>(m)
}

///<(J,K,L,M,N,O,P)> <U> ----> <(J,K,L,M,N,O,P,U)>
public func ~>> <T: ReactiveComponent, U: ReactiveComponent,J,K,L,M,N,O,P>(lhs: T, rhs: U) -> AnyComponent<(J,K,L,M,N,O,P,U.Model)> where T.Model == (J,K,L,M,N,O,P) {
    let m = Signal<(J,K,L,M,N,O,P,U.Model)>(
        current: (lhs.c.0, lhs.c.1, lhs.c.2, lhs.c.3, lhs.c.4, lhs.c.5, lhs.c.6, rhs.c),
        previous: (lhs.p.0, lhs.p.1, lhs.p.2, lhs.p.3, lhs.p.4, lhs.p.5, lhs.p.6, rhs.p)
        )
    lhs.state.sink{ m.update(($0.new.0, $0.new.1, $0.new.2, $0.new.3, $0.new.4, $0.new.5, $0.new.6, m.c.7)) }
    .store(in: &m.observations)
    
    rhs.state.sink{ m.update((m.c.0, m.c.1, m.c.2, m.c.3, m.c.4, m.c.5, m.c.6, $0.new))}
    .store(in: &m.observations)
    
    return AnyComponent<(J,K,L,M,N,O,P,U.Model)>(m)
}
