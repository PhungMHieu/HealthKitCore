//
//  ContentView.swift
//  HealthAppTestSettingCodeYourselft
//
//  Created by iKame Elite Fresher 2025 on 21/8/25.
//

import SwiftUI
import HealthKit
import Charts

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    var body: some View {
        VStack {
            Text("Step Count Chart")
                .font(.title)
                .padding()
            
            if let stepDataDict = healthKitManager.aggregatedData[.stepCount] {
                let stepDataArray = stepDataDict.map { (date, steps) in
                    StepData(date: date, steps: steps)
                }
                .sorted { $0.date < $1.date }

                Chart(stepDataArray) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Steps", item.steps)
                    )
                    .foregroundStyle(.blue)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }
                .frame(height: 300)
                .padding()
            } else {
                Text("No data available")
            }
        }
        VStack {
            HStack {
                Text("Nhịp tim")
                Text("\(healthKitManager.quantityValues[.heartRate] ?? 0, specifier: "%.1f")")
            }
            HStack {
                Text("Huyết áp")
                Text("\(healthKitManager.quantityValues[.bloodPressureSystolic] ?? 0, specifier: "%.0f") / \(healthKitManager.quantityValues[.bloodPressureDiastolic] ?? 0, specifier: "%.0f") mmHg")
            }
            HStack {
                Text("Bước chạy")
                Text("\(healthKitManager.quantityValues[.stepCount] ?? 0, specifier: "%.0f")")
            }
            Button {
                healthKitManager.requestAuthorization()
            } label: {
                Text("Request authorization")
            }
            .padding()
            .background(.yellow)

        }
        .padding()
    }
}

// Struct dữ liệu chart
struct StepData: Identifiable {
    var id: String = UUID().uuidString
    var date: Date
    var steps: Double
}

#Preview {
    ContentView()
}
