// FP-33074 incident log extraction - player Waz 10000 (a0fe2188-4eb0-46f3-94e0-1e96a1afa45b)
// Connection: [F2P] XB PROD Mongo, DB main2. Mongo < 4.4 (no $unionWith) -> run each query
// separately, export each result as JSON into artifacts/dump/ with the filename noted per query.
// I merge by Timestamp on my side.
// Window: 2026-06-24 00:00 .. 2026-06-25 06:00 UTC (covers the working evening session AND
// the broken midday session: join 13:09, "mornin" 16:04 not delivered, recovery 16:10).
// Each LogBase row carries RequestId = client per-op id (sequential within one connection).
//
// For Gonzo too: replace the UserId with 38aeb767-64db-4a52-ab7b-bc25fdecbfe8 and save into
// artifacts/dump/ with "gonzo-" instead of "waz-" (q5 chatLog is shared -> club6777-chat.json).

// === q1 sysLog: system events (chat-channel join/leave/expire, etc.)   -> save as: waz-sys.json ===
db.sysLog.find(
  { UserId: "a0fe2188-4eb0-46f3-94e0-1e96a1afa45b",
    Timestamp: { $gte: ISODate("2026-06-24T00:00:00Z"), $lte: ISODate("2026-06-25T06:00:00Z") } },
  { _id: 0, Timestamp: 1, RequestId: 1, Message: 1 }
).sort({ Timestamp: 1 })

// === q2 travelLog: pin selection / pond travel / back to globe        -> save as: waz-travel.json ===
db.travelLog.find(
  { UserId: "a0fe2188-4eb0-46f3-94e0-1e96a1afa45b",
    Timestamp: { $gte: ISODate("2026-06-24T00:00:00Z"), $lte: ISODate("2026-06-25T06:00:00Z") } },
  { _id: 0, Timestamp: 1, RequestId: 1, Message: 1 }
).sort({ Timestamp: 1 })

// === q3 securityLog: auth / reconnect / relog (session boundaries)    -> save as: waz-security.json ===
db.securityLog.find(
  { UserId: "a0fe2188-4eb0-46f3-94e0-1e96a1afa45b",
    Timestamp: { $gte: ISODate("2026-06-24T00:00:00Z"), $lte: ISODate("2026-06-25T06:00:00Z") } },
  { _id: 0, Timestamp: 1, RequestId: 1, Message: 1 }
).sort({ Timestamp: 1 })

// === q4 togetherLog: FT / co-op session events                        -> save as: waz-together.json ===
db.togetherLog.find(
  { UserId: "a0fe2188-4eb0-46f3-94e0-1e96a1afa45b",
    Timestamp: { $gte: ISODate("2026-06-24T00:00:00Z"), $lte: ISODate("2026-06-25T06:00:00Z") } },
  { _id: 0, Timestamp: 1, RequestId: 1, Message: 1 }
).sort({ Timestamp: 1 })

// === q5 chatLog club6777: messages broadcast to the club channel      -> save as: club6777-chat.json ===
db.chatLog.find(
  { Channel: "club6777",
    Timestamp: { $gte: ISODate("2026-06-24T00:00:00Z"), $lte: ISODate("2026-06-25T06:00:00Z") } },
  { _id: 0, Timestamp: 1, Channel: 1, Sender: 1, SenderName: 1, Data: 1, Message: 1 }
).sort({ Timestamp: 1 })

// === q6 cdLog: client-side debug log uploaded by the player           -> save as: waz-cd.json ===
db.cdLog.find(
  { UserId: "a0fe2188-4eb0-46f3-94e0-1e96a1afa45b",
    Timestamp: { $gte: ISODate("2026-06-24T00:00:00Z"), $lte: ISODate("2026-06-25T06:00:00Z") } }
).sort({ Timestamp: 1 })

// === q7 diagErrLog: client error stream (if empty, key isn't UserId)  -> save as: waz-diagerr.json ===
db.diagErrLog.find(
  { UserId: "a0fe2188-4eb0-46f3-94e0-1e96a1afa45b",
    Timestamp: { $gte: ISODate("2026-06-24T00:00:00Z"), $lte: ISODate("2026-06-25T06:00:00Z") } }
).sort({ Timestamp: 1 })
