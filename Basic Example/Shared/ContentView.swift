//  Created by Ryan Cumley
//  MIT License
//  Copywright (c) Ryan Cumley

import SwiftUI
import routt


struct ContentView: View, ReactiveSwiftUIRenderer {
    typealias Model = StateManager.Model
    @ObservedObject var dataSource: AnySwiftUICompatibleComponent<StateManager.Model>
    
    func costumeSuggestion() -> some View {
        if case .some(let event) = dataSource.model {
            switch event.new {
            case .loading: return AnyView(Text("loading"))
            case .error: return AnyView(Text("error"))
            case .costume(let costume):
                switch costume {
                case .initialized: return AnyView(Text("loading"))
                case .child(let c): return AnyView(row(c))
                case .adult(let a): return AnyView(row(a))
                }
            }
        } else {
            return AnyView(Text("Starting up..."))
        }
    }
    
    func row(_ from: RandomHalloweenCostumeSpawner.HalloweenCostume.Costume) -> some View {
        return VStack{
            Text(from.name)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(from.themeColor)
                .frame(width: 300, height: 300)
        }
    }
    
    var body: some View {
        Spacer()
        Text("You should consider dressing up for Halloween as:")
        costumeSuggestion()
            .padding()
        Spacer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RandomHalloweenCostumeSpawner() ~>> StateManager() ~>> ContentView.self
    }
}
