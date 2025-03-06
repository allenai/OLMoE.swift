//
//  FeatureFlags.swift
//  OLMoE.swift
//
//  Created by Thomas Jones on 11/15/24.
//

import DeviceCheck

public enum FeatureFlags {

    static let allowDeviceBypass = false

    static let serverSideSharing: Bool = {
        let appAttestService = DCAppAttestService()
        return Locale.isCountrySupported() && appAttestService.isSupported
    }()

    static let allowMockedModel = false

    static let useLLMCaching = true


}
