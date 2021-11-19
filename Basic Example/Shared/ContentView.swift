//  Created by Ryan Cumley
//  MIT License
//  Copywright (c) Ryan Cumley

import SwiftUI
import rockslide

struct ContentView: View, ReactiveSwiftUIRenderer {
    typealias Model = StateManager.Model
    @ObservedObject var dataSource: AnySwiftUICompatibleComponent<StateManager.Model>
    
    func costumeName() -> some View {
        if case .some(let event) = dataSource.model {
            switch event.new {
            case .loading: return AnyView(Text("loading"))
            case .error: return AnyView(Text("error"))
            case .costume(let costume):
                switch costume {
                case .child(let c): return AnyView(Text(c.name))
                case .adult(let a): return AnyView(Text(a.name))
                }
            }
        } else {
            return AnyView(Text("Starting up..."))
        }
    }
    
    func costumeColor() -> some View {
        if case .some(let event) = dataSource.model {
            if case .costume(let costume) = event.new {
                switch costume {
                case .child(let c): return AnyView(Text(c.themeColor.description))
                case .adult(let a): return AnyView(Text(a.themeColor.description))
                }
            } else {
                return AnyView(Text("loading..."))
            }
        } else {
            return AnyView(Text("loading..."))
        }
    }
    
    var body: some View {
        
        Spacer()
        Text("You should consider dressing up for Halloween as:")
        costumeName()
        Spacer()
        Text("And for a costume theme color, try: ")
        costumeColor()
        Spacer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RandomHalloweenCostumeSpawner() ~>> StateManager() ~>> ContentView.self
    }
}

struct RandomHalloweenCostumeSpawner: ReactiveComponent {
    let state: Signal<HalloweenCostume> = Signal<HalloweenCostume>()
    
    typealias Model = HalloweenCostume
    typealias UpstreamModel = ()
    
    enum HalloweenCostume {
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
