import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/fazilp/SwiftUI-Project/new 1%/Task-app/Task-app/ContentView.swift", line: 1)
//
//  ContentView.swift
//  Task-app
//
//  Created by Fazil P on 28/04/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: __designTimeString("#10846_0", fallback: "globe"))
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(__designTimeString("#10846_1", fallback: "Hello, world!"))
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
