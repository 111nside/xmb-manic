//
//  WFC.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SmartCodable

fileprivate let DefaultWFCList = """
[
    {
        "name": "Wiimmfi",
        "dns": "167.235.229.36",
        "url": "https://wiimmfi.de/",
        "isSelect": true
    },
    {
        "name": "WiiLink WFC",
        "dns": "5.161.56.11",
        "url": "https://wfc.wiilink24.com/",
        "isSelect": false
    },
    {
        "name": "AltWFC",
        "dns": "172.104.88.237",
        "url": "https://github.com/barronwaffles/dwc_network_server_emulator/wiki",
        "isSelect": false
    },
    {
        "name": "PKMClassic",
        "dns": "178.62.43.212",
        "url": "https://pkmnclassic.net",
        "isSelect": false
    }
]
"""

struct WFC: SmartCodable {
    var name: String = ""
    var dns: String = ""
    var url: String = ""
    var isSelect: Bool = false
    
    struct WfcServers: SmartCodable {
        var version: Int = 1
        var popular = [WFC]()
        
        static func getWfcServers() -> WfcServers {
            if var wfcServers = WfcServers.deserialize(from: Settings.defalut.getExtraString(key: ExtraKey.wfc.rawValue)) {
                if !wfcServers.popular.contains(where: { $0.dns == "178.62.43.212" }) {
                    //如果服务器请求的server不包含PKMClassic 则加上
                    wfcServers.popular = wfcServers.popular + [WFC(name: "PKMClassic", dns: "178.62.43.212", url: "https://pkmnclassic.net", isSelect: false)]
                }
                return wfcServers
            } else {
                return WfcServers(version: 1, popular: [WFC].deserialize(from: DefaultWFCList)!)
            }
        }
    }
    
    static func getList() -> [WFC] {
        return WfcServers.getWfcServers().popular
    }
    
    static func refreshList(completion: @escaping ([WFC])->Void) {
        URLSession.shared.dataTask(with: R.URLs.WFC) { data, response, error in
            DispatchQueue.main.async {
                if var onlineWfcServers = WfcServers.deserialize(from: data), onlineWfcServers.popular.count > 0 {
                    if !onlineWfcServers.popular.contains(where: { $0.dns == "178.62.43.212" }) {
                        //如果服务器请求的server不包含PKMClassic 则加上
                        onlineWfcServers.popular = onlineWfcServers.popular + [WFC(name: "PKMClassic", dns: "178.62.43.212", url: "https://pkmnclassic.net", isSelect: false)]
                    }
                    if let localWfcServers = WfcServers.deserialize(from: Settings.defalut.getExtraString(key: ExtraKey.wfc.rawValue)),
                        onlineWfcServers.version != localWfcServers.version {
                        
                        //如果本地已经有选中的服务 则需要将本地选中的服务迁移到刚刚请求到的新服务列表上
                        var markSelect = false
                        if let localSelectWFC = localWfcServers.popular.first(where: { $0.isSelect == true }) {
                            for (index, onlineWFC) in onlineWfcServers.popular.enumerated() {
                                if onlineWFC.url == localSelectWFC.url {
                                    onlineWfcServers.popular[index].isSelect = true
                                    markSelect = true
                                    break
                                }
                            }
                        }

                        if !markSelect {
                            //如果本地没有选择过服务 则默认第一个选中
                            onlineWfcServers.popular[0].isSelect = true
                        }

                        //需要更新
                        if let jsonString = onlineWfcServers.toJSONString() {
                            Settings.defalut.updateExtra(key: ExtraKey.wfc.rawValue, value: jsonString)
                            completion(onlineWfcServers.popular)
                        } else {
                            completion(getList())
                        }
                    } else {
                        //直接返回本地的
                        completion(getList())
                    }
                } else {
                    //获取失败 直接返回本地的
                    completion(getList())
                }
            }
        }.resume()
    }
    
    static func selectWFC(_ withWfc: WFC) -> [WFC] {
        var wfcServers = WfcServers.getWfcServers()
        guard wfcServers.popular.count > 0 else { return wfcServers.popular }
        for (index, wfc) in wfcServers.popular.enumerated() {
            if wfc.url == withWfc.url {
                if wfc.isSelect == true {
                    //无需修改
                    return wfcServers.popular
                }
                wfcServers.popular[index].isSelect = true
            } else {
                wfcServers.popular[index].isSelect = false
            }
        }
        if !wfcServers.popular.allSatisfy({ $0.isSelect == false }), let jsonString = wfcServers.toJSONString() {
            Settings.defalut.updateExtra(key: ExtraKey.wfc.rawValue, value: jsonString)
        }
        return wfcServers.popular
    }
    
    static func resetWFC() {
//        UserDefaults.standard.removeObject(forKey: MelonDS.wfcIDUserDefaultsKey)
//        UserDefaults.standard.removeObject(forKey: MelonDS.wfcFlagsUserDefaultsKey)
    }
    
    static func currentDNS() -> String {
        let wfcs = getList()
        if let wfc = wfcs.first(where: { $0.isSelect == true }) {
            return wfc.dns
        }
        return wfcs.first?.dns ?? "0.0.0.0"
    }
}
