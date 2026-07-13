// FP-33074 - LIVE repro log extraction ("[Chat] messages disappear")
// Connection: [F2P] XB PROD Mongo, schema main2. MongoDB 4.2 -> plain find() only
//   (no $unionWith [4.4], no $dateDiff/$dateAdd [5.0]).
//
// HOW TO USE:
//   1. Set `from` to just BEFORE your repro attempt (UTC). Open upper bound = up to "now".
//   2. Run the whole file in one go (the `var from`/`var players` apply to every query),
//      or run the two var lines first, then each query block. Export each grid to a file.
//
// Players in club6777 (own / Waz / Gonzo):
var players = [
  "caa03b10-efce-45e3-a3d2-8f399224e067",   // own
  "a0fe2188-4eb0-46f3-94e0-1e96a1afa45b",   // Waz 10000
  "38aeb767-64db-4a52-ab7b-bc25fdecbfe8"    // Gonzo1964
];
var from = ISODate("2026-06-26T13:00:00Z");   // <-- EDIT THIS (UTC, just before the repro)

// WHAT TO LOOK FOR (cross-reference with chat-server Chat.log J/L/T):
//   - q1: leave->join gap per player. reqid HIGH on leave (last op of OLD connection),
//     reqid r4/r5 on join (NEW connection). Small gap = higher race chance.
//   - The bug shows when, at the symptom moment, the player is net-joined game-side (q1/q2)
//     yet club messages (q5) are not delivered to him (check Chat.log "T ...->him... Ok").

// === q1 sysLog: channel join/leave for club6777 (the leave->join gap) -> save: q1-sys-club.json ===
db.sysLog.find(
  { UserId: { $in: players }, Timestamp: { $gte: from }, Message: /club6777/ },
  { _id:0, Timestamp:1, UserId:1, RequestId:1, Message:1 }
).sort({ Timestamp: 1 });

// === q2 sysLog: full system trace (auth / transfer / disconnect / join / leave / pause)
//     -> node path + session boundaries                              save: q2-sys-full.json ===
db.sysLog.find(
  { UserId: { $in: players }, Timestamp: { $gte: from } },
  { _id:0, Timestamp:1, UserId:1, RequestId:1, Message:1 }
).sort({ Timestamp: 1 });

// === q3 securityLog: MASTER/GAME transfers (server IP = game node) + disconnects
//     -> which node each session lands on                            save: q3-security.json ===
db.securityLog.find(
  { UserId: { $in: players }, Timestamp: { $gte: from } },
  { _id:0, Timestamp:1, UserId:1, RequestId:1, Message:1 }
).sort({ Timestamp: 1 });

// === q4 travelLog: room/pond changes (lobby<->3D, room-type switches) save: q4-travel.json ===
db.travelLog.find(
  { UserId: { $in: players }, Timestamp: { $gte: from } },
  { _id:0, Timestamp:1, UserId:1, RequestId:1, Message:1 }
).sort({ Timestamp: 1 });

// === q5 chatLog club6777: everything broadcast to the club (ClubEvent catches + Text)
//     -> what SHOULD have reached everyone                           save: q5-club-chat.json ===
db.chatLog.find(
  { Channel: "club6777", Timestamp: { $gte: from } },
  { _id:0, Timestamp:1, Sender:1, SenderName:1, Data:1, Message:1 }
).sort({ Timestamp: 1 });

// === q6 chatLog club6777: human TEXT chat only. NOTE: club chat is persisted as a
//     Data:"ClubEvent" envelope with inner "Type":"Text" (field "Text" = the message);
//     catches/other club activity are other inner Type values. Match the inner type, NOT
//     a top-level Data:"Text".                                       save: q6-club-text.json ===
db.chatLog.find(
  { Channel: "club6777", Timestamp: { $gte: from }, Message: /"Type":"Text"/ },
  { _id:0, Timestamp:1, SenderName:1, Message:1 }
).sort({ Timestamp: 1 });
