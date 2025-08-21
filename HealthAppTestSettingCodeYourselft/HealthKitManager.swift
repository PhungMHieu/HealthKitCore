//
//  HealthKitManager.swift
//  HealthAppTestSettingCodeYourselft
//
//  Created by iKame Elite Fresher 2025 on 21/8/25.
//

import Foundation
import HealthKit


class HealthKitManager : ObservableObject {
//    @Published var bloodPressure: (systolic: Double, diastolic: Double)?
    @Published var correlationValues: [HKCorrelationTypeIdentifier: [HKCorrelation]] = [:]
    @Published var quantityValues: [HKQuantityTypeIdentifier: Double] = [:]
    @Published var categorySamples: [HKCategoryTypeIdentifier: [HKCategorySample]] = [:]
    @Published var workouts: [HKWorkoutActivityType: [HKWorkout]] = [:]
    // Gộp steps theo interval
    @Published var aggregatedData: [HKQuantityTypeIdentifier: [Date: Double]] = [:]
    
    
    let healthStore = HKHealthStore()
    static let shared = HealthKitManager()
    private var anchors: [HKSampleType: HKQueryAnchor] = [:]
    
    var shareTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!
    ]
    
    var readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!
    ]
    
    let dataTypes: [HealthDataTypeIdentifier] = [
        .quantity(.heartRate),
        .quantity(.bloodPressureSystolic),
        .quantity(.bloodPressureDiastolic),
        .quantity(.stepCount)
    ]
    
    private init() {
        DispatchQueue.main.async{
            self.enableBackgroundDelivery(types: self.dataTypes)
        }
    }
    
    func enableBackgroundDelivery(types: [HealthDataTypeIdentifier]) {
        for type in types {
            if let hkType = type.toHKObjectType() {
                healthStore.enableBackgroundDelivery(for: hkType, frequency: .immediate) { success, error in
                    if success {
                        print("Enabled background delivery for \(hkType.identifier)")
                    } else if let error = error {
                        print("Failed to enable background delivery for \(hkType.identifier): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func requestAuthorization() {
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
            if success {
                let types: [HKQuantityType] = [HKQuantityType(.heartRate),HKQuantityType(.bloodPressureSystolic), HKQuantityType(.bloodPressureDiastolic)]
                if(self.checkAuthorizationStatuses(allTypes: types)){
                    let queueGlobal = DispatchQueue.global(qos: .userInitiated)
                    queueGlobal.async {
                        self.startObserver(typeIndentifier: .quantity(.heartRate), isStatisTiced: false)
                    }
                    queueGlobal.async {
                        self.startObserver(typeIndentifier: .quantity(.bloodPressureDiastolic), isStatisTiced: false)
                    }
                    queueGlobal.async {
                        self.startObserver(typeIndentifier: .quantity(.bloodPressureSystolic), isStatisTiced: false)
                    }
                    queueGlobal.async {
                        self.startObserver(typeIndentifier: .quantity(.stepCount), isStatisTiced: true,interval: ChartInterval.day)
                    }

                }
            } else {
                print("errors")
            }
        }
    }
    
    func checkAuthorizationStatuses(allTypes: [HKObjectType])->Bool {
        let allAuthorized = allTypes.allSatisfy { type in
            let status = healthStore.authorizationStatus(for: type)
            return status == .sharingAuthorized
        }
        return allAuthorized
    }
    
    func checkAuthorizationStatus(type: HKObjectType)->Bool {
        let status = healthStore.authorizationStatus(for: type)
        return status == .sharingAuthorized
    }
    
    func startObserver(typeIndentifier: HealthDataTypeIdentifier, isStatisTiced: Bool, interval:ChartInterval? = nil) {
        guard let sampleType = typeIndentifier.toSampleType() else {
                fatalError("*** Unable to get the sample type ***")
            }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { query, completion, error in
            if let error = error {
                print("Observer error: \(error.localizedDescription)")
                return
            }
            
            self.fetchLatestValueWithAnchor(typeIdentifier: typeIndentifier)
            if(isStatisTiced){
                guard let interval = interval else { return }
                let startDate:Date
                let calendar = Calendar.current
                switch interval {
                case .day:
                    startDate = calendar.date(byAdding: .day, value: -7, to: Date())!
                case .week:
                    startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
                case .month:
                    startDate = calendar.date(byAdding: .month, value: -1, to: Date())!
                case .year:
                    startDate = calendar.date(byAdding: .year, value: -1, to: Date())!
                }
                if let samepleType = typeIndentifier.toSampleType() as? HKQuantityType{
                    self.fetchValueForChart(type: samepleType, interval: interval, startDate: startDate)
                }
                
            }
            print("Có thay đổi mới cho \(sampleType)")
            completion()
        }
        healthStore.execute(query)
    }
    
    
    func fetchLatestValuesWithAnchor(typeIdentifiers: [HealthDataTypeIdentifier]) {
        for identifier in typeIdentifiers {
            guard let sampleType = identifier.toSampleType() else { continue }
            runAnchoredQuery(for: sampleType)
        }
    }
    
    func fetchLatestValueWithAnchor(typeIdentifier: HealthDataTypeIdentifier) {
        guard let sampleType = typeIdentifier.toSampleType() else { return }
        runAnchoredQuery(for: sampleType)
    }
    
    func fetchValueForChart(type: HKQuantityType, interval: ChartInterval, startDate: Date) {
        let endDate = Date()
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval.dateComponents
        )
        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }
            
            var newData: [Date: Double] = [:]
            results.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                if let sum = stat.sumQuantity() {
                    newData[stat.startDate] = sum.doubleValue(for: .count())
                }
            }
            
            DispatchQueue.main.async {
                let stringId = type.identifier
                let identifier = HKQuantityTypeIdentifier(rawValue: stringId)
                self.aggregatedData[identifier] = newData
            }
        }
        
        healthStore.execute(query)
    }
    
    func runAnchoredQuery(for sampleType: HKSampleType) {
        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: nil,
            anchor: anchors[sampleType] ?? nil, // mỗi sampleType có anchor riêng
            limit: HKObjectQueryNoLimit
        ) { [weak self] (_, samplesOrNil, _, newAnchor, errorOrNil) in
            if let error = errorOrNil {
                print("Anchored query error (\(sampleType)): \(error.localizedDescription)")
                return
            }

            // cập nhật anchor cho sampleType này
            self?.anchors[sampleType] = newAnchor

            // xử lý dữ liệu mới
            if let samples = samplesOrNil {
                for sample in samples {
                    switch sample {
                    case let quantitySample as HKQuantitySample:
                        let stringId = quantitySample.quantityType.identifier
                        let identifier = HKQuantityTypeIdentifier(rawValue: stringId)
                        let unit: HKUnit
                        switch identifier {
                        case .heartRate:
                            unit = HKUnit.count().unitDivided(by: .minute())
                        case .stepCount:
                            unit = HKUnit.count()
                        case .distanceWalkingRunning:
                            unit = HKUnit.meter()
                        case .bloodPressureSystolic, .bloodPressureDiastolic:
                            unit = HKUnit.millimeterOfMercury()
                        default:
                            unit = HKUnit.count()
                        }
                        let value = quantitySample.quantity.doubleValue(for: unit)
                        DispatchQueue.main.async{
                            self?.quantityValues[identifier] = value
                        }
                    case let correlationSample as HKCorrelation:
                        let stringId = correlationSample.correlationType.identifier
                        let identifier = HKCorrelationTypeIdentifier(rawValue: stringId)
                        var list = self?.correlationValues[identifier] ?? []
                        list.append(correlationSample)
                        DispatchQueue.main.async{
                            self?.correlationValues[identifier] = list
                        }
                        
                    case let categorySample as HKCategorySample:
                        let stringId = categorySample.categoryType.identifier
                        let identifier = HKCategoryTypeIdentifier(rawValue: stringId)
                        var list = self?.categorySamples[identifier] ?? []
                        list.append(categorySample)
                        DispatchQueue.main.async{
                            self?.categorySamples[identifier] = list
                        }
                        
                    case let workout as HKWorkout:
                        let type = workout.workoutActivityType
                        var list = self?.workouts[type] ?? []
                        list.append(workout)
                        self?.workouts[type] = list
                    default:
                        print("Unhandled sample: \(sample)")
                    }
                }
            }
        }

        healthStore.execute(query)
    }
    
}


extension HealthKitManager {
    enum HealthDataTypeIdentifier:Hashable {
        case quantity(HKQuantityTypeIdentifier)
        case category(HKCategoryTypeIdentifier)
        case correlation(HKCorrelationTypeIdentifier)
        case workout
        func toHKObjectType() -> HKObjectType? {
            switch self {
            case .quantity(let id):
                return HKObjectType.quantityType(forIdentifier: id)
            case .category(let id):
                return HKObjectType.categoryType(forIdentifier: id)
            case .correlation(let id):
                return HKObjectType.correlationType(forIdentifier: id)
            case .workout:
                return HKObjectType.workoutType()
            }
        }
        func toSampleType() -> HKSampleType? {
            switch self {
            case .category(let identifier):
                return HKObjectType.categoryType(forIdentifier: identifier)

            case .quantity(let identifier):
                return HKObjectType.quantityType(forIdentifier: identifier)

            case .correlation(let identifier):
                return HKObjectType.correlationType(forIdentifier: identifier)

            case .workout:
                return HKObjectType.workoutType()
            }
        }
    }
    
    enum ChartInterval {
        case day
        case week
        case month
        case year
        
        var dateComponents: DateComponents {
            switch self {
            case .day: return DateComponents(day: 1)
            case .week: return DateComponents(day: 7)
            case .month: return DateComponents(month: 1)
            case .year: return DateComponents(year: 1)
            }
        }
    }
}
