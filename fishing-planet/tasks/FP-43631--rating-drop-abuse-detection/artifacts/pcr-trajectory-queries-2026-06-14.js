// FP-43631 week-6 — Tournament-log trajectory dump queries
// =============================================================================
// One aggregate per UserId. Window: 2026-05-25T00:00:00Z -> 2026-06-14T23:59:59Z
// (3 weeks: ~2 weeks pre-context + the week-6 detection window 06-08 -> 06-14).
//
// Result rows are a single string per entry: "<ISO timestamp>\t<verbatim Message>".
// MCP datagrip / mongo shell show only the projected field; $concat keeps the join
// on one line so output is greppable.
//
// Save each query's output to the filename in its comment header — that name is
// `<UserId>-<slug>.txt`. Run each section against the matching Mongo PROD instance.
// Subsequent collector agent reads these files and renders proper trajectory cards.

// ============================================================================
// [F2P] STEAM PROD Mongo (8 queries)
// ============================================================================

// File: 314450b3-d521-45c6-a14b-958cc34b0ed1-vm-npwp.txt          (VM_NPWP)
db.tournamentLog.aggregate([
  { $match: { UserId: "314450b3-d521-45c6-a14b-958cc34b0ed1", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: 47fee9fa-c9e6-4dbe-8742-63b56558d890-laccfarro.txt        (LaccFarro)
db.tournamentLog.aggregate([
  { $match: { UserId: "47fee9fa-c9e6-4dbe-8742-63b56558d890", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: 222bbe9d-3557-4280-b854-cbef2ae48707-monsterfish-fuark.txt (MonsterFish_fuark)
db.tournamentLog.aggregate([
  { $match: { UserId: "222bbe9d-3557-4280-b854-cbef2ae48707", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: 702cdd67-82e7-40ec-bfeb-d57fb7ceae1f-vm-vigor.txt         (VM_Vigor)
db.tournamentLog.aggregate([
  { $match: { UserId: "702cdd67-82e7-40ec-bfeb-d57fb7ceae1f", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: 07782225-67bf-4863-a1a2-eb2fab29cbfd-artem209.txt         (ArTeM209)
db.tournamentLog.aggregate([
  { $match: { UserId: "07782225-67bf-4863-a1a2-eb2fab29cbfd", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: 41c022cf-88c4-43f0-a8e5-c1f6f4963242-kacumi.txt           (Kacumi)
db.tournamentLog.aggregate([
  { $match: { UserId: "41c022cf-88c4-43f0-a8e5-c1f6f4963242", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: b187e932-866f-454b-b455-a9f5f3240af3-jialin0720.txt       (JIALIN0720)
db.tournamentLog.aggregate([
  { $match: { UserId: "b187e932-866f-454b-b455-a9f5f3240af3", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: c77a50fb-1c16-4ca8-8011-487c3ebc498a-ifc-baysemperor.txt  (IFC_BaysEmperor)
db.tournamentLog.aggregate([
  { $match: { UserId: "c77a50fb-1c16-4ca8-8011-487c3ebc498a", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);


// ============================================================================
// [F2P] PS PROD Mongo (6 queries)
// ============================================================================

// File: e25c082e-8a19-4236-aa8b-c345137e9ea3-stari40k-yt.txt      (STARI40K_YT)
db.tournamentLog.aggregate([
  { $match: { UserId: "e25c082e-8a19-4236-aa8b-c345137e9ea3", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: 78c4a65f-ef45-482a-a125-88d71973013b-mr-crimson-21.txt    (Mr-crimson-21)
db.tournamentLog.aggregate([
  { $match: { UserId: "78c4a65f-ef45-482a-a125-88d71973013b", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: 8f36f30f-ade0-4d9a-bc88-765ae61e5384-iigot-smoked.txt     (IIGot-_-Smoked)
db.tournamentLog.aggregate([
  { $match: { UserId: "8f36f30f-ade0-4d9a-bc88-765ae61e5384", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: d8cde1ee-38b7-4cd1-ad46-a8b093491c6c-ttv-s4muka019.txt    (Ttv_s4muka019)
db.tournamentLog.aggregate([
  { $match: { UserId: "d8cde1ee-38b7-4cd1-ad46-a8b093491c6c", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: b879ab80-43e5-455f-a045-b5a28480af04-rabolio41100.txt     (rabolio41100)
db.tournamentLog.aggregate([
  { $match: { UserId: "b879ab80-43e5-455f-a045-b5a28480af04", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);

// File: 4e9f05e9-6210-49b6-96fc-a03eaed8473e-mingocai-10.txt      (mingocai_10)
db.tournamentLog.aggregate([
  { $match: { UserId: "4e9f05e9-6210-49b6-96fc-a03eaed8473e", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);


// ============================================================================
// [F2P] XB PROD Mongo (1 query)
// ============================================================================

// File: bafeab96-ea5f-4394-8790-43c9da456046-mikeikemoon.txt      (MikeikeMOON)
db.tournamentLog.aggregate([
  { $match: { UserId: "bafeab96-ea5f-4394-8790-43c9da456046", Timestamp: { $gte: ISODate("2026-05-25T00:00:00.000Z"), $lte: ISODate("2026-06-14T23:59:59.000Z") } } },
  { $sort: { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [ { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message" ] } } }
]);
