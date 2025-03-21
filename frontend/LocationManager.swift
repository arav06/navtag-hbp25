//
//  LocationManager.swift
//  NAGTollApp
//
//  Created by Nathan Chen on 2/9/25.
//

import Foundation
import CoreLocation

// MARK: - Location Manager for tracking user location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private var locationManager: CLLocationManager = CLLocationManager()
    
    // Published location properties to track user location
    @Published var userLatitude: Double = 0.0
    @Published var userLongitude: Double = 0.0
    @Published var userLocationStatus: String = "Unknown"  // To show permission status updates
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // Best accuracy for precise location
    }
    
    // Request user permission to access location
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    // Start tracking user location
    func startTrackingLocation() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        } else {
            userLocationStatus = "Location services are disabled."
        }
    }

    // Stop tracking user location
    func stopTrackingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate Methods
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            userLocationStatus = "Requesting permission..."
        case .restricted:
            userLocationStatus = "Location access restricted."
        case .denied:
            userLocationStatus = "Permission denied."
        case .authorizedWhenInUse, .authorizedAlways:
            userLocationStatus = "Permission granted."
            startTrackingLocation()  // Start tracking as soon as permission is granted
        @unknown default:
            userLocationStatus = "Unknown status."
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLatitude = location.coordinate.latitude
        userLongitude = location.coordinate.longitude
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        userLocationStatus = "Failed to get location: \(error.localizedDescription)"
    }
}

