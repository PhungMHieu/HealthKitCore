//
//  HealthKitManager.swift
//  HealthAppTestSettingCodeYourselft
//
//  Created by iKame Elite Fresher 2025 on 21/8/25.
//

import Foundation
import HealthKit


class HealthKitManager : ObservableObject {
    @Published var bloodPressure: (systolic: Double, diastolic: Double)?
    @Published var heartRate: Double?
    
    let healthStore = HKHealthStore()
    init() {
        enableBackgroundDelivery(types: dataTypes)
    }
    private var anchors: [HKSampleType: HKQueryAnchor] = [:]
    
    var shareTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
        HKObjectType.correlationType(forIdentifier: .bloodPressure)!
    ]
    
    var readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKObjectType.correlationType(forIdentifier: .bloodPressure)!
    ]
    
    let dataTypes: [HealthDataTypeIdentifier] = [
        .quantity(.heartRate),
        .correlation(.bloodPressure)
    ]
    
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
    
    func checkAuthorizationStatues(allTypes: [HKObjectType])->Bool {
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
    
    func fetchValueQuantity(typeIndentifier: HealthDataTypeIdentifier) {
        guard let sampleType = typeIndentifier.toSampleType() else {
                fatalError("*** Unable to get the sample type ***")
            }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { query, completion, error in
            if let error = error {
                print("Observer error: \(error.localizedDescription)")
                return
            }
            
            self.fetchLatestValueWithAnchor(typeIdentifier: typeIndentifier)
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
    
    func runAnchoredQuery(for sampleType: HKSampleType) {
        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: nil,
            anchor: anchors[sampleType], // mỗi sampleType có anchor riêng
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
                        let value = quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        print("Quantity [\(sampleType.identifier)]: \(value) at \(quantitySample.startDate)")

                    case let categorySample as HKCategorySample:
                        print("Category [\(sampleType.identifier)]: \(categorySample.value) at \(categorySample.startDate)")

                    case let workout as HKWorkout:
                        print("Workout: \(workout.workoutActivityType.rawValue) duration: \(workout.duration)")

                    default:
                        print("Unhandled sample: \(sample)")
                    }
                }
            }
        }

        healthStore.execute(query)
    }
    func requestAuthorization() {
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
            if success {
                if(self.checkAuthorizationStatus(type:))
                self.fetchValueQuantity(typeIndentifier: .quantity(.heartRate))
                
            } else {
                print("errors")
            }
        }
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
}
