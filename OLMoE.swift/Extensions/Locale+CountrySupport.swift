//
//  Locale+CountrySupport.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 3/5/25.
//

import Foundation

extension Locale {
    static let supportedCountries = ["US"]
    
    /// Check if the user's country supports server-side sharing
    static func isCountrySupported() -> Bool {
        let userCountry: String?
        if #available(iOS 16, *) {
            userCountry = Locale.current.region?.identifier
        } else {
            userCountry = Locale.current.regionCode
        }
        
        return userCountry.map { supportedCountries.contains($0) } ?? false
    }
}
