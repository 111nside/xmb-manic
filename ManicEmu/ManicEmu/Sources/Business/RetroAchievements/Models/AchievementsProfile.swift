//
//  AchievementsProfile.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/*
 {
   "user": "xelnia",
   "ulid": "00003EMFWR7XB8SDPEHB3K56ZQ",
   "memberSince": "2021-12-20 03:13:20",
   "lastActivity": {
     "id": 0,
     "timestamp": null,
     "lastupdate": null,
     "activitytype": null,
     "user": "xelnia",
     "data": null,
     "data2": null
   },
   "richPresenceMsg": "L=08-1 | 1 lives | 189300 points",
   "lastGameId": 15758,
   "contribCount": 0,
   "contribYield": 0,
   "totalPoints": 8317,
   "totalSoftcorePoints": 0,
   "totalTruePoints": 26760,
   "permissions": 1,
   "untracked": false,
   "id": 224958,
   "userWallActive": true,
   "motto": "",
   "rank": 4616,
   "recentlyPlayedCount": 1,
   "recentlyPlayed": [
     {
       "gameId": 15758,
       "consoleId": 27,
       "consoleName": "Arcade",
       "title": "Crazy Kong",
       "imageIcon": "/Images/068578.png",
       "imageTitle": "/Images/068579.png",
       "imageIngame": "/Images/068580.png",
       "imageBoxArt": "/Images/068205.png",
       "lastPlayed": "2023-03-09 08:20:34",
       "achievementsTotal": 43
     }
   ],
   "awarded": {
     "15758": {
       "numPossibleAchievements": 43,
       "possibleScore": 615,
       "numAchieved": 41,
       "scoreAchieved": 490,
       "numAchievedHardcore": 41,
       "scoreAchievedHardcore": 490
     }
   },
   "recentAchievements": {
     "15758": {
       "293505": {
         "id": 293505,
         "gameId": 15758,
         "gameTitle": "Crazy Kong",
         "title": "Prodigy of the Arcade",
         "description": "Score 200,000 points",
         "points": 25,
         "type": null,
         "badgeName": "325551",
         "isAwarded": true,
         "dateAwarded": "2023-03-09 08:20:34",
         "hardcoreAchieved": true
       },
       "293526": {
         "id": 293526,
         "gameId": 15758,
         "gameTitle": "Crazy Kong",
         "title": "Super Smasher III",
         "description": "Get 6 smashes with a single bottom hammer on any barrel board",
         "points": 10,
         "type": null,
         "badgeName": "325572",
         "isAwarded": true,
         "dateAwarded": "2023-03-09 08:19:37",
         "hardcoreAchieved": true
       }
     }
   },
   "lastGame": {
     "id": 15758,
     "title": "Crazy Kong",
     "consoleId": 27,
     "consoleName": "Arcade",
     "forumTopicId": 20415,
     "flags": 0,
     "imageIcon": "/Images/068578.png",
     "imageTitle": "/Images/068579.png",
     "imageIngame": "/Images/068580.png",
     "imageBoxArt": "/Images/068205.png",
     "publisher": "Falcon",
     "developer": "Falcon",
     "genre": "2D Platforming, Arcade",
     "released": "1981",
     "isFinal": 0
   },
   "userPic": "/UserPic/xelnia.png",
   "totalRanked": 45654,
   "status": "Offline"
 }
*/

struct AchievementsProfile {
    var userPic: String? = nil
    var user: String = ""
    var lastActivityTimestamp = ""
    var memberSince = ""
    var achievementCount = 0
    var totalSoftcorePoints = 0
    var totalHardcorePoints = 0
    var totalRanked = 0
}
