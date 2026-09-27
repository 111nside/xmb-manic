//
//  ESRP.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

enum ESRP: Int, CaseIterable {
    /// Early Childhood
    case EC
    /// Kids to Adults
    case K_A
    /// Everyone
    case E
    /// Everyone 10+
    case E10
    /// Teen
    case T
    /// Mature
    case M
    /// Adults Only
    case AO
    /// Rating Pending
    case RP
    /// Rating Pending — Likely Mature 17+
    case RP17
    
    var desc: String {
        switch self {
        case .EC:
            return "Early Childhood (3+). Suitable for young children and contains no material generally considered inappropriate."
            
        case .K_A:
            return "Kids to Adults (6+). The original name of the Everyone rating; replaced by E (Everyone) in 1998."
            
        case .E:
            return "Everyone (6+). Generally suitable for all ages, with only minimal cartoon, fantasy, or mild violence and infrequent mild language."
            
        case .E10:
            return "Everyone 10+ (10+). May contain more cartoon, fantasy, or mild violence, mild language, and minimal suggestive themes. Introduced in 2005."
            
        case .T:
            return "Teen (13+). May contain violence, suggestive themes, crude humor, minimal blood, simulated gambling, or infrequent strong language."
            
        case .M:
            return "Mature (17+). May contain intense violence, blood and gore, sexual content, or strong language."
            
        case .AO:
            return "Adults Only (18+). Intended only for adults and may contain prolonged intense violence, graphic sexual content, or real-money gambling."
            
        case .RP:
            return "Rating Pending. A final ESRB rating has not yet been assigned; used for promotional materials and replaced once the game receives its final rating."
            
        case .RP17:
            return "Rating Pending — Likely Mature 17+. A final rating has not yet been assigned, but the game is anticipated to receive an M (Mature 17+) rating."
        }
    }
    
    var abbr: String {
        switch self {
        case .EC:
            return "EC"
        case .K_A:
            return "K-A"
        case .E:
            return "E"
        case .E10:
            return "E10+"
        case .T:
            return "T"
        case .M:
            return "M"
        case .AO:
            return "AO"
        case .RP:
            return "RP"
        case .RP17:
            return "RP 17+"
        }
    }
    
    var age: Int? {
        switch self {
        case .EC:
            return 3
        case .K_A, .E:
            return 6
        case .E10:
            return 10
        case .T:
            return 13
        case .M:
            return 17
        case .AO:
            return 18
        case .RP, .RP17:
            return nil
        }
    }
    
    var icon: ASIcon {
        switch self {
        case .EC:
            return .image(R.image.esrp_EC())
        case .K_A:
            return .image(R.image.esrp_KA())
        case .E:
            return .image(R.image.esrp_E())
        case .E10:
            return .image(R.image.esrp_E10())
        case .T:
            return .image(R.image.esrp_T())
        case .M:
            return .image(R.image.esrp_M())
        case .AO:
            return .image(R.image.esrp_AO())
        case .RP:
            return .image(R.image.esrp_RP())
        case .RP17:
            return .image(R.image.esrp_RP17())
        }
    }
    
    /// 与 GameMetadata.ratingId / DB extras 对齐的写入值
    var ratingId: Int {
        switch self {
        case .T:
            return 1
        case .M:
            return 2
        case .K_A:
            return 3
        case .E10:
            return 4
        case .E:
            return 5
        case .EC:
            return 7
        case .AO:
            return 8
        case .RP:
            return 9
        case .RP17:
            return 10
        }
    }
}
