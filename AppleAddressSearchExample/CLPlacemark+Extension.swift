//
//  CLPlacemark+Extension.swift
//  AppleAddressSearchExample
//
//  Created by Daisuke TONOSAKI on 2020/08/21.
//  Copyright © 2020 Daisuke TONOSAKI. All rights reserved.
//

import CoreLocation

extension CLPlacemark {
    
    var text: String {
        var text = ""
        
        if let name = self.name {
            text += "name[\(name)]"
        }
        if let country = self.country {
            text += " country[\(country)]"
        }
        if let administrativeArea = self.administrativeArea {
            text += " administrativeArea[\(administrativeArea)]"
        }
        if let subAdministrativeArea = self.subAdministrativeArea {
            text += " subAdministrativeArea[\(subAdministrativeArea)]"
        }
        if let locality = self.locality {
            text += " locality[\(locality)]"
        }
        if let subLocality = self.subLocality {
            text += " subLocality[\(subLocality)]"
        }
        if let thoroughfare = self.thoroughfare {
            text += " thoroughfare[\(thoroughfare)]"
        }
        if let subThoroughfare = self.subThoroughfare {
            text += " subThoroughfare[\(subThoroughfare)]"
        }
        
        return text
    }
    
}
