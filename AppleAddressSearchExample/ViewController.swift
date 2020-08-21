//
//  ViewController.swift
//  AppleAddressSearchExample
//
//  Created by Daisuke TONOSAKI on 2020/08/20.
//  Copyright © 2020 Daisuke TONOSAKI. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import Contacts

class ViewController: UIViewController {
    
    // MARK: - Outlet
    @IBOutlet weak var searchBar: UISearchBar?
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var indicatorView: UIActivityIndicatorView?
    
    
    // MARK: - Constants / Enum
    enum Mode: Int, CaseIterable {
        case GeocoderAddressString  // CLGeocoder.geocodeAddressString()
        case GeocoderPostalAddress  // CLGeocoder.geocodePostalAddress()
        case LocalSearch            // MKLocalSearch
    }
    
    
    // MARK: - Property
    let locationManager = CLLocationManager()
    var latestLocation = CLLocation()
    var latestSearchText = ""
    var reservedSearchText: String?
    var isSearching: Bool = false
    var placemarkMap: [Mode: [CLPlacemark]] = [Mode.GeocoderAddressString: [],
                                               Mode.GeocoderPostalAddress: [],
                                               Mode.LocalSearch: []
    ]
    var placemarkMapTemporary: [Mode: [CLPlacemark]] = [Mode.GeocoderAddressString: [],
                                                        Mode.GeocoderPostalAddress: [],
                                                        Mode.LocalSearch: []
    ]
    var hasGeocorderRequestLimitOccurs = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView?.dataSource = self
        tableView?.allowsSelection = false
        tableView?.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        searchBar?.delegate = self
        
        indicatorView?.hidesWhenStopped = true
        
        initLocationManager()
    }
    
}


// MARK: - CLLocationManager
extension ViewController {
    
    func initLocationManager() {
        guard CLLocationManager.locationServicesEnabled() else {
            return
        }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
}


// MARK: - CLLocationManagerDelegate
extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let location = locations.last else {
            return
        }
        
        latestLocation = location
    }
    
}


// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Mode.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let array = placemarkMap[Mode(rawValue: section) ?? Mode.GeocoderAddressString],
            array.count > 0 else {
            // Dummy content for empty.
            return 1
        }
        
        return array.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let mode = Mode(rawValue: section) else {
            return ""
        }
        
        
        let map = [Mode.GeocoderAddressString: "CLGeocoder.geocodeAddressString()",
                   Mode.GeocoderPostalAddress: "CLGeocoder.geocodePostalAddress()",
                   Mode.LocalSearch: "MKLocalSearch"
        ]
        
        return map[mode]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = ""
        cell.detailTextLabel?.text = ""
        
        
        let mode = Mode(rawValue: indexPath.section) ?? Mode.GeocoderAddressString
        
        guard let array = placemarkMap[mode],
            array.count > 0 else {
                // Dummy content for empty.
                if hasGeocorderRequestLimitOccurs &&
                    (mode == .GeocoderAddressString || mode == .GeocoderPostalAddress) {
                    cell.textLabel?.text = "😵 CLGeocoder request limit occurred."
                }
                else {
                    cell.textLabel?.text = "No placemarks."
                }
                return cell
        }
        
        
        let item = array[indexPath.row]
        
        cell.textLabel?.text = item.text
        cell.detailTextLabel?.text = ""
        
        
        return cell
    }
    
}


// MARK: - UITableViewDelegate
extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    
}


// MARK: - UISearchBarDelegate
extension ViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        search(searchText: searchText)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        search(searchText: "")
    }
    
}


// MARK: - Search
extension ViewController {
    
    private static let postalAddressPropertyKeyPaths = [
        \CNMutablePostalAddress.street,
//        \CNMutablePostalAddress.subLocality,
//        \CNMutablePostalAddress.city,
//        \CNMutablePostalAddress.subAdministrativeArea,
//        \CNMutablePostalAddress.state,
//        \CNMutablePostalAddress.country,
    ]
    
    
    func search(searchText: String) {
        guard latestSearchText != searchText else {
            return
        }
        
        guard !isSearching else {
            reservedSearchText = searchText
            return
        }
        
        print("search [\(searchText)]")
        
        isSearching = true
        indicatorView?.startAnimating()
        latestSearchText = searchText
        hasGeocorderRequestLimitOccurs = false
        
        placemarkMapTemporary = [Mode.GeocoderAddressString: [],
                                 Mode.GeocoderPostalAddress: [],
                                 Mode.LocalSearch: []
        ]
        
        searchGeocodeAddressString(searchText: searchText)
    }
    
    func searchGeocodeAddressString(searchText: String) {
        CLGeocoder().geocodeAddressString(searchText) { (placemarks, error) in
            defer {
                self.searchGeocodePostalAddress(keyPathIndex: 0, searchText: searchText)
            }
            
            
            if let error = error as? CLError {
                if error.errorCode == CLError.Code.network.rawValue {
                    // Request limit occurs
                    // https://developer.apple.com/documentation/corelocation/clgeocoder
                    self.hasGeocorderRequestLimitOccurs = true
                    self.searchLocalSearch(searchText: searchText)
                    return
                }
                
                return
            }
            
            guard let placemarks = placemarks else {
                return
            }
            
            
            self.placemarkMapTemporary[Mode.GeocoderAddressString] = placemarks
        }
    }
    
    
    func searchGeocodePostalAddress(keyPathIndex: Int, searchText: String) {
        
        guard keyPathIndex < ViewController.postalAddressPropertyKeyPaths.count else {
            searchLocalSearch(searchText: searchText)
            return
        }
        
        
        let postalAddress = CNMutablePostalAddress()
        let keyPath = ViewController.postalAddressPropertyKeyPaths[keyPathIndex]
        postalAddress[keyPath: keyPath] = searchText
        
        CLGeocoder().geocodePostalAddress(postalAddress) { (placemarks, error) in
            defer {
                self.searchGeocodePostalAddress(keyPathIndex: keyPathIndex + 1, searchText: searchText)
            }
            
            guard error == nil,
                let placemarks = placemarks else {
                return
            }
            
            
            for placemark in placemarks {
                let isContains = !self.placemarkMapTemporary[Mode.GeocoderPostalAddress]!.filter {
                    $0.text == placemark.text
                }.isEmpty
                
                if isContains {
                    continue
                }
                
                self.placemarkMapTemporary[Mode.GeocoderPostalAddress]!.append(placemark)
            }
        }
    }
    
    
    func searchLocalSearch(searchText: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        // Set a wide range.
        request.region = MKCoordinateRegion(center: latestLocation.coordinate,
                                            latitudinalMeters: 10000000,
                                            longitudinalMeters: 10000000)
        
        let localSearch = MKLocalSearch(request: request)
        localSearch.start { (response, error) in
            defer {
                self.searchComplete(searchText: searchText)
            }
            
            guard error == nil,
                let items = response?.mapItems else {
                return
            }
            
            
            self.placemarkMapTemporary[Mode.LocalSearch] = items.map {
                $0.placemark
            }
        }
        
    }
    
    
    func searchComplete(searchText: String) {
        print("searchComplete [\(searchText)]")
        
        indicatorView?.stopAnimating()
                
        placemarkMap = placemarkMapTemporary
        
        tableView?.reloadData()
        
        isSearching = false
        
        guard let searchTextNext = reservedSearchText else {
            return
        }
        
        reservedSearchText = nil
        search(searchText: searchTextNext)
    }
    
}
