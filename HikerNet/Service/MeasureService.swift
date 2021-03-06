
import CoreData
import CoreLocation
import CoreTelephony
import Network
import UIKit

class MeasureService: NSObject, CLLocationManagerDelegate, ObservableObject {
    let managedContext = PersistenceController.shared.container.viewContext
    let networkMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
    let queue = DispatchQueue(label: "HNNetworkMonitor")
    let locationManager = CLLocationManager()
    let measureInterval = 30
    
    var hike: Hike?
    var currentDate = Date()
    var currentLocation = CLLocation()
    var locationPoints = [CLLocation]()
    var firstLocationRequest = true
    var connected = false
    var batteryLevel = 0

    @Published var startTime = Date()
    @Published var distance = 0.0
    @Published var inService = false
    @Published var saveInProgress = false
    @Published var recording = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(batterLevelDidChange), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        
        networkMonitor.pathUpdateHandler = { path in
            self.connected = path.status == .satisfied
        }
        networkMonitor.start(queue: queue)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if (recording && !(manager.authorizationStatus == .authorizedAlways)) {
            stopUpdates()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        updateServiceState()
        if (firstLocationRequest) {
            currentLocation = locations.last!
            currentDate = currentLocation.timestamp
            firstLocationRequest = false
            saveFeature()
        } else if ((Int(currentDate.timeIntervalSinceNow.rounded()) * -1) >= measureInterval) {
            currentLocation = locations.last!
            currentDate = Date()
            saveFeature()
        }
        updateDistance(location: currentLocation)
        updateHike()
    }
    
    @objc func batterLevelDidChange() {
        batteryLevel = Int(UIDevice.current.batteryLevel * 100)
    }
    
    func startUpdates() {
        recording = true
        startHike()
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdates() {
        recording = false
        stopHike()
        locationManager.stopUpdatingLocation()
    }
    
    func startHike() {
        startTime = Date()
        batteryLevel = Int(UIDevice.current.batteryLevel * 100)
        connected = networkMonitor.currentPath.status == .satisfied
        
        let entity = NSEntityDescription.entity(forEntityName: "Hike", in: managedContext)!
        hike = Hike(entity: entity, insertInto: managedContext)
        hike!.setValue(startTime, forKey: "start")
        hike!.setValue(UserDefaultsManager.getCarrier(), forKey: "carrier")
        hike!.setValue("Apple", forKey: "manufacturer")
        hike!.setValue(UIDevice.current.systemVersion, forKey: "os")
        
        saveContext()
    }
    
    func stopHike() {
        updateHike()
        firstLocationRequest = true
        locationPoints.removeAll()
        distance = 0.0
        
        ApiManager.postHikes { res in
            switch res {
            case .success(.Success):
                DatabaseManager.clearCache()
            case .failure(let err):
                print(err.localizedDescription)
            }
        }
    }
    
    private func updateHike() {
        let endTime = Date()
        let timeElapsed = (endTime.timeIntervalSince1970 - hike!.start!.timeIntervalSince1970).rounded()
        hike!.setValue(Int64(timeElapsed), forKey: "duration")
        hike!.setValue(distance/1000, forKey: "distance")
        hike!.setValue(endTime, forKey: "end")
        saveContext()
    }
    
    func saveFeature() {
        saveInProgress = true

        let entity = NSEntityDescription.entity(forEntityName: "Feature", in: managedContext)!
        let feature = Feature(entity: entity, insertInto: managedContext)
        
        feature.setValue(Date(), forKey: "timestamp")
        feature.setValue(Int16(batteryLevel), forKey: "battery")
        feature.setValue(getNetworkType(), forKey: "network")
        feature.setValue(inService, forKey: "service")
        feature.setValue(inService ? connected : false, forKey: "connected")
        feature.setValue(currentLocation.coordinate.latitude, forKey: "lon")
        feature.setValue(currentLocation.coordinate.longitude, forKey: "lat")
        feature.setValue(currentLocation.horizontalAccuracy, forKey: "accuracy")
        feature.setValue(currentLocation.speed, forKey: "speed")
        feature.setValue(hike, forKey: "origin")
        
        saveContext()
        saveInProgress = false
    }
    
    private func updateServiceState() {
        inService = getServiceState()
    }
    
    private func updateDistance(location: CLLocation) {
        if (locationPoints.count > 0) {
            distance += location.distance(from: locationPoints[locationPoints.count-1])
        }
        locationPoints.append(location)
    }
    
    private func saveContext() {
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
}

extension MeasureService {
    
    private func getServiceState() -> Bool {
        let carriers = CTTelephonyNetworkInfo().serviceSubscriberCellularProviders!
        for (_, carrier) in carriers {
            if carrier.carrierName != nil && carrier.mobileCountryCode != nil {
                return true
            }
        }
        return false
    }
    
    private func getNetworkType() -> String {
        let networkInfo = CTTelephonyNetworkInfo()
        let radioTech = networkInfo.serviceCurrentRadioAccessTechnology!
        if radioTech.count > 0 {
            for (_, val) in radioTech {
                switch(val) {
                case CTRadioAccessTechnologyLTE: return Constants.RadioTech.LTE
                case CTRadioAccessTechnologyGPRS: return Constants.RadioTech.GPRS
                case CTRadioAccessTechnologyCDMA1x: return Constants.RadioTech.CDMA1x
                case CTRadioAccessTechnologyEdge: return Constants.RadioTech.EDGE
                case CTRadioAccessTechnologyWCDMA: return Constants.RadioTech.WCDMA
                case CTRadioAccessTechnologyHSDPA: return Constants.RadioTech.HSDPA
                case CTRadioAccessTechnologyHSUPA: return Constants.RadioTech.HSUPA
                case CTRadioAccessTechnologyCDMAEVDORev0: return Constants.RadioTech.CDMAEVDOREV0
                case CTRadioAccessTechnologyCDMAEVDORevA: return Constants.RadioTech.CDMAEVDOREVA
                case CTRadioAccessTechnologyCDMAEVDORevB: return Constants.RadioTech.CDMAEVDOREVB
                case CTRadioAccessTechnologyeHRPD: return Constants.RadioTech.EHRPD
                case CTRadioAccessTechnologyNRNSA: return Constants.RadioTech.NRNSA
                case CTRadioAccessTechnologyNR: return Constants.RadioTech.NR
                default: return Constants.RadioTech.UKNOWN
                }
            }
        }
        return "NULL"
    }
    
    private func printHikes(hikes: [HikePost]) {
        var hikeCounter = 1
        var featureCounter = 1
        for hike in hikes {
            print()
            print("Hike #\(hikeCounter)")
            print("-------------------------------------------------")
            print("Carrier\t\t\t\t \(hike.carrier)")
            print("Duration\t\t\t \(hike.duration) seconds")
            print("Distance\t\t\t \(hike.distance) km")
            print("Start Time\t\t\t \(hike.start)")
            print("End Time\t\t\t \(hike.end)")
            print("Manufacturer\t\t \(hike.manufacturer)")
            print("OS Version\t\t\t \(hike.os)")
            print()
            hikeCounter += 1
            for feature in hike.features {
                print("Feature #\(featureCounter)")
                print("--------------------")
                print("Timestamp\t\t\t \(feature.timestamp)")
                print("Battery\t\t\t\t \(feature.battery) %")
                print("Network Type\t\t \(feature.network)")
                print("Service State\t\t \(feature.service)")
                print("Connected\t\t\t \(feature.connected)")
                print("Latitude\t\t\t \(feature.lat)")
                print("Longitude\t\t\t \(feature.lon)")
                print("Speed\t\t\t\t \(feature.speed) m/s")
                print("Accuracy\t\t\t \(feature.accuracy)")
                print()
                featureCounter += 1
            }
            featureCounter = 1
        }
    }
}