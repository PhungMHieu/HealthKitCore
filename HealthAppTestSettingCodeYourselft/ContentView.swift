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
    @State private var selectedInterval: HealthKitManager.ChartInterval = .week
    
    let startOfDay = Calendar.current.startOfDay(for: Date())
    var body: some View {
        VStack {
            Text("Step Count Chart")
                .font(.title)
                .padding()
            
            // Picker để chọn interval
            Picker("Chart Interval", selection: $selectedInterval) {
//                Text("Ngày").tag(HealthKitManager.ChartInterval.day)
                Text("Tuần").tag(HealthKitManager.ChartInterval.week)
                Text("Tháng").tag(HealthKitManager.ChartInterval.month)
//                Text("Năm").tag(HealthKitManager.ChartInterval.year)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedInterval) { _,newInterval in
                healthKitManager.updateChartInterval(for: .quantity(.stepCount), interval: newInterval)
            }
            
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
                    switch selectedInterval {
                    case .day:
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day().week())
                        }
                    case .week:
                        AxisMarks(values: .stride(by: .weekOfYear)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.week().month())
                        }
                    case .month:
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month().year())
                        }
                    case .year:
                        AxisMarks(values: .stride(by: .year)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.year())
                        }
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
                Text("\(healthKitManager.quantityStatistics[.stepCount] ?? 0, specifier: "%.0f")")
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
