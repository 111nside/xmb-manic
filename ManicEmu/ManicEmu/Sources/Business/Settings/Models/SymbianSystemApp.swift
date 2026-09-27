//
//  SymbianSystemApp.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/19.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

/**
 /*
  Symbian OS          S60 Platform             Common names       Devices
  ──────────────────  ───────────────────────  ─────────────────  ──────────────────
  Symbian 6.1         S60 1st Edition (V1)     S60 V1             Nokia 7650, N-Gage
  Symbian 7.0s        S60 2nd Edition (V2)     S60 V2 / FP1       Nokia 6600, 7610
  Symbian 8.0a / 8.1a S60 2nd Edition FP2/FP3  S60 V2 FP2 / FP3   N70, N90
  Symbian 9.1         S60 3rd Edition          S60 V3             N73, E50, 3250
  Symbian 9.2         S60 3rd Edition FP1      S60 V3 FP1         N95, E71
  Symbian 9.3         S60 3rd Edition FP2      S60 V3 FP2         N78, E72
  Symbian 9.4         S60 5th Edition          S60 V5 / Symbian^1 5800XM, N97
  Symbian^2           No standalone naming     Symbian^2          N8
  Symbian^3           S60 5.2                 Symbian^3          N8, E7, C7
  Symbian Anna        Symbian^3 Updated ver    Anna               X7, E6
  Symbian Belle       Symbian^3 Subsequent ver Belle              808 PureView
 */
 */
enum SymbianOS: Int {
    case S60v1
    case S60v2
    case S60v3
    case S60v5
    case Symbian3
    
    var title: String {
        switch self {
        case .S60v1:
            "S60v1/N-Gage 1.0"
        case .S60v2:
            "S60v2"
        case .S60v3:
            "S60v3"
        case .S60v5:
            "S60v5"
        case .Symbian3:
            "Symbian^3"
        }
    }
    
    var recommendDevice: String {
        switch self {
        case .S60v1:
            "NEM-4/RH-29"
        case .S60v2:
            "Nokia N70"
        case .S60v3:
            "Nokia 5320"
        case .S60v5:
            "Nokia 5800"
        case .Symbian3:
            "nNokia X7"
        }
    }
    
    /// Raw `eka2l1::epocver` integer from `CoresSources/EKA2L1/src/emu/common/include/common/types.h`.
    private enum EpocVer: Int {
        case eka1 = 0
        case epocu6 = 1
        case epoc6 = 2
        case epoc7 = 3
        case epoc80 = 4
        case epoc81a = 5
        case eka2 = 6
        case epoc81b = 7
        case epoc93fp1 = 8
        case epoc93fp2 = 9
        case epoc94 = 10
        case epoc95 = 11
        case epoc10 = 12
    }
    
    /// Maps an installed firmware to a UI platform bucket via epocver, then OS major/minor.
    static func getOS(by device: LibretroSymbianDevice) -> Self {
        if let epocVer = EpocVer(rawValue: Int(device.epocVersion)) {
            switch epocVer {
            case .eka1, .epocu6, .epoc6:
                return .S60v1
            case .epoc7, .epoc80, .epoc81a, .eka2, .epoc81b:
                return .S60v2
            case .epoc93fp1, .epoc93fp2:
                return .S60v3
            case .epoc94:
                return .S60v5
            case .epoc95, .epoc10:
                return .Symbian3
            }
        }
        
        switch device.symbianOsMajor {
        case 5, 6:
            return .S60v1
        case 7, 8:
            return .S60v2
        case 9:
            switch device.symbianOsMinor {
            case 0...3:
                return .S60v3
            case 4:
                return .S60v5
            default:
                return .Symbian3
            }
        case 10...:
            return .Symbian3
        default:
            return .S60v3
        }
    }
}

struct SymbianSystemApp {
    var uid: String
    var deviceIndex: Int
    var os: SymbianOS
}
