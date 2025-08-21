//
//  ContentView.swift
//  HealthAppTestSettingCodeYourselft
//
//  Created by iKame Elite Fresher 2025 on 21/8/25.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    var body: some View {
        VStack {
            HStack {
                Text("Nhịp tim")
                Text("..........")
            }
            HStack {
                Text("Huyết áp")
                Text("..........")
            }
            HStack {
                Text("Bước chạy")
                Text("..........")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
