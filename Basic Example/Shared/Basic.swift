import Foundation
import SwiftUI
import DequeModule
import routt

struct RandomHalloweenCostumeSpawner: ReactiveComponent {
    let state: Signal<HalloweenCostume> = Signal<HalloweenCostume>(current: .initialized)
    
    typealias Model = HalloweenCostume
    typealias UpstreamModel = ()
    
    enum HalloweenCostume {
        case initialized
        case child(Costume)
        case adult(Costume)
        
        struct Costume {
            let name: String
            let themeColor: Color
        }
    }
    
    init() {
        broadcastNewCostumeIdea()
    }
    
    func broadcastNewCostumeIdea() {
        let new = costumeIdea()
        state.update(new)
        
        let someTime = Double.random(in: 2..<5)
        DispatchQueue.main.asyncAfter(deadline: .now() + someTime){
            broadcastNewCostumeIdea() // <--- relevant xkcd: https://xkcd.com/1270/
        }
    }
    
    private func costumeIdea() -> HalloweenCostume {
        let pre = prefix.randomElement() ?? "Friendly"
        let child = cleanIdentities.randomElement() ?? "Toothpaste Tube"
        let adult = adultIdentities.randomElement() ?? "Velociraptor"
        let suffix = Bool.random() ? (" " + (suffix.randomElement() ?? " from up north")) : ""
        
        let color = colors.randomElement() ?? .blue
        
        switch Bool.random() {
        case true:
            return HalloweenCostume.child(.init(
                name: pre + " " + child + suffix,
                themeColor: color)
            )
        case false:
            return HalloweenCostume.adult(.init(
                name: pre + " " + adult + suffix,
                themeColor: color)
            )
        }
    }
}

fileprivate let prefix: [String] = ["Dr.", "Oversized", "The Infamous", "Pedantic", "Overblown", "Evil"]
fileprivate let cleanIdentities: [String] = ["Marching Band Conductor", "Zookeeper", "Underwater Ninja", "Pizza Crust Inspector"]
fileprivate let adultIdentities: [String] = ["Middle Manager", "Angsty Traffic Cop", "Wal-Mart Greeter", "Nursing Home Orderly", "Axe Juggler", "Politician"]
fileprivate let suffix: [String] = ["of Doom", "now with 33% less MSG", "as seen on T.V.", "of the forest", "with a raging case of the giggles", "the Destroyer"]
fileprivate let colors: [Color] = [.blue, .brown, .cyan, .gray, .green, .indigo, .mint, .orange, .pink, .purple, .red, .teal, .yellow, .black]

struct StateManager: ReactiveComponent {
    enum Model {
        case loading
        case costume(RandomHalloweenCostumeSpawner.HalloweenCostume)
        case error
    }
    let state = Signal<Model>(current: .loading)
    typealias UpstreamModel = RandomHalloweenCostumeSpawner.HalloweenCostume
    
    func react(toNew: RandomHalloweenCostumeSpawner.HalloweenCostume) {
        state.update(.costume(toNew))
    }
}


//MARK: - two source merge example

struct Letters: ReactiveComponent {
    enum Model: String {
        case a, b, c, d, error
    }
    typealias UpstreamModel = ()
    let state = Signal<Model>(current: .a)
    
    init() {
        randomTimer()
    }
    
    func randomTimer() {
        let delay = Double.random(in: 1...3)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay){ publishLetter() }
    }
    
    func publishLetter() {
        let newLetter: Model
        switch Int.random(in: 0...3) {
        case 0: newLetter = .a
        case 1: newLetter = .b
        case 2: newLetter = .c
        case 3: newLetter = .d
        default: newLetter = .error
        }
        state.update(newLetter)
        
        randomTimer()
    }
}

struct Numbers: ReactiveComponent {
    enum Model: String {
       case one, two, three, four, error
    }
    typealias UpstreamModel = ()
    let state = Signal<Model>(current: .one)
    
    init() {
        randomTimer()
    }
    
    func randomTimer() {
        let delay = Double.random(in: 1...3)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay){ publishNumber() }
    }
    
    func publishNumber() {
        let newNumber: Model
        switch Int.random(in: 0...3) {
        case 0: newNumber = .one
        case 1: newNumber = .two
        case 2: newNumber = .three
        case 3: newNumber = .four
        default: newNumber = .error
        }
        state.update(newNumber)
        
        randomTimer()
    }
}

struct HelpfulSuggestionWizard: ReactiveComponent {
    var state = Signal<Model>(current: .initialized)
    enum Model {
        case initialized
        case error
        case loading
        case suggestion(String)
    }
    typealias UpstreamModel = (Numbers.Model, Letters.Model)
    
    init() {
        state.update(.loading)
    }
    
    func react(toNew: (Numbers.Model, Letters.Model)) {
        switch toNew {
        case (.error, _), (_, .error):
            state.update(.error)
        case(let n, let l):
            let suggestion = "\(l.rawValue) \(n.rawValue)"
            state.update(.suggestion(suggestion))
        }
    }
}

func viewMapping(_ input: HelpfulSuggestionWizard.Model) -> DoubleTrouble.Model {
    switch input {
    case .initialized: return .initialized
    case .loading: return .loading
    case .error: return .error
    case .suggestion(let message): return .data(message)
    }
}

struct DoubleTrouble: View, ReactiveSwiftUIRenderer {
    enum Model {
        case initialized
        case loading
        case error
        case data(String)
    }
    @ObservedObject var dataSource: AnySwiftUICompatibleComponent<Model>
    
    func someText() -> some View {
        if case .some(let event) = dataSource.model {
            switch event.new {
            case .initialized:
                return AnyView(Text("...initializing"))
            case .loading:
                return AnyView(Text("loading!"))
            case .error:
                return AnyView(Text("something went wrong"))
            case .data(let message):
                return AnyView(Text(message))
            }
        } else {
            return AnyView(Text("something went wrong"))
        }
    }
    
    var body: some View {
       someText()
    }
}
