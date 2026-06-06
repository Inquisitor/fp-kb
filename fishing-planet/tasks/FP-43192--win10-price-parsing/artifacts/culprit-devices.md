# Culprit devices - non-standard locale separators (UWP price-load, prod tradeLog)

Source: a one-off prod `main2.tradeLog` export (products #2230/#2190, grouped by format with user samples); raw export not retained (distilled here).
BROKEN = separator that the OLD parser mishandles (decimal dropped -> x100/x1000). Sample users capped at ~10/format.
nUsers = exact distinct-device count per format (the real exposure); device IDs below are a sample.

## Exposure by separator x currency (broken only)

| Separator              | Currency | Events | Devices (nUsers) |
|------------------------|----------|-------:|-----------------:|
| U+066B Arabic-decimal  | SAR      |    808 |               77 |
| U+066B Arabic-decimal  | USD      |    106 |               26 |
| U+066B Arabic-decimal  | IQD      |    322 |               12 |
| U+066B Arabic-decimal  | EGP      |     70 |               11 |
| U+066B Arabic-decimal  | JOD      |     94 |                6 |
| U+066B Arabic-decimal  | ILS      |     38 |                5 |
| U+066B Arabic-decimal  | KWD      |     12 |                4 |
| $ cifrao               | USD      |    148 |                3 |
| U+066B Arabic-decimal  | EUR      |      8 |                2 |
| U+066B Arabic-decimal  | OMR      |      4 |                2 |
| U+066B Arabic-decimal  | TRY      |    138 |                1 |
| U+066B Arabic-decimal  | GBP      |     28 |                1 |
| U+066B Arabic-decimal  | BHD      |      6 |                1 |
| U+00A0 NBSP-as-decimal | ZAR      |      4 |                1 |
| $ cifrao               | BRL      |      4 |                1 |
| U+066B Arabic-decimal  | MXN      |      2 |                1 |
| - dash                 | BRL      |      2 |                1 |

**Distinct sample devices across all broken formats: 87** (lower bound; true total is the sum of nUsers with overlap).

## Sample device IDs by separator class

### U+066B Arabic-decimal  (81 sample devices)
- 00a4bf0d-90da-40dd-9f7f-fc017e881868
- 0a84c5ca-6595-46ca-af78-5b7672bc3d13
- 0d2b0002-bd92-4e8f-9289-9aa6bd63515c
- 11c489f2-fa5b-464a-b46f-fb28641fad22
- 122023bd-ed0c-4bff-9082-6a79b62bd362
- 1c202f00-473f-4b47-91e2-b232c5571892
- 1cd52be4-d635-4f34-a928-a5fdaf0ac241
- 1d810ac1-48d6-4001-b6e9-d7b114bd82d6
- 1fdad447-decb-43df-84d7-b1b0bd26ce8a
- 2733aa54-9d7b-4162-814b-c219f4167819
- 27d1ac50-2da0-4f20-855f-18c022c36dc2
- 28c691a7-e7d0-4007-9842-fce0298f4259
- 2b02c0cd-42ec-41bb-bd58-314c4bdc066c
- 2f8d7450-b05b-4477-8fe9-c08a7dcd7465
- 31cff63c-3a04-4423-8d6d-24c35c92e573
- 340f6455-9921-4b08-bd24-185531afc1d0
- 36c626f6-413c-4879-8540-d5389110f798
- 3df15ecb-6dad-4535-b686-051f9552f823
- 42beaf64-0d54-4f8e-944a-435887087594
- 42cd6097-9742-4cea-8b60-9aab2250621c
- 482f0611-b318-40e3-afab-7d8de5ca7757
- 4ab5cad5-ba1f-42c1-a8f5-f90fb1336229
- 54b5f0c6-0072-4a74-8fb9-3f9b30c4c6b7
- 55485548-39db-47a7-bdd6-f58ef34f645f
- 5d22a802-4a3c-4adb-b06a-b87b39afd32c
- 602de0c8-ddc5-4929-86f3-4cb6fab3ee33
- 615c9986-220e-4bc4-bbab-159acaad7136
- 622e32fe-66e6-46ac-8d5a-b8217c6344de
- 6463d001-4543-4a8e-b8c2-6022e09308b2
- 6a41044a-5d91-4e99-9c5c-8908c576a8c5
- 6a6085c5-691d-467c-9568-ac6a4d69234c
- 6ad0b859-5bfa-4970-9a28-470f0d42f929
- 6cde5895-10fa-4f77-bbe4-69dfc24abc46
- 6e04bb35-fbbb-4f40-b911-83d9305cc7db
- 71886f7f-c382-4efe-925f-f1d8729cc765
- 73fece37-6ffd-4e9f-9c05-efe0367d25e4
- 7475e87f-49f5-4148-a62a-6920596666da
- 7beb0f79-eaf3-4ce4-9cd4-edf4f943a74c
- 7e39d761-c9d6-4cb1-b3b8-b308b1f6002d
- 7e429f44-e2ea-4d16-9de5-68dfe5724440
- 8050d247-9750-4d50-8d24-83abfb1bf8f8
- 816b7d4a-3914-43a6-8de9-5ae4fd9e489f
- 845a8620-fd59-44ca-a1f1-5f1465da52f2
- 846b0071-7806-4b2a-9250-1305e456c6ff
- 860b04ef-dbb3-4eb8-8e00-f5779ba267d9
- 86e940f2-ce6c-43d8-8dc7-450f36cdc4be
- 90ff05c7-66ba-40e2-8cc2-52d404c8f614
- 92483cfd-9134-4945-85ed-678a5a12784c
- 939a4349-767e-4f15-a0f8-595a9dcb0941
- 9601cfb1-03d7-4e5f-96c9-1ba71e5a9960
- 9f4c6f91-7af8-4d98-9288-db6d7d174e04
- 9f7cf2a0-01d0-4a5f-97af-219888a7cff4
- a03648b4-e536-4e15-812c-6ecdd077a5a5
- a80d7de9-1d0a-417f-bebc-8a6353ce9b28
- a8163a5d-8d36-46d2-a885-8b8e73ebbcc5
- acb912d9-8df9-4faf-92fa-2ee2cd62188f
- ae43f505-0ce9-4031-8445-075dc215185e
- b1827854-4c62-4850-a097-4a27b7e331f4
- b3e64949-4772-4a46-9392-d75760105928
- b3f62056-36fe-48f1-a3c2-0c7c840deddc
- b416f2df-7f0d-4dba-9b91-4e70b9ab008c
- b9c6ebda-349e-46c5-8aa6-06b156540ab4
- ba759911-688a-498c-b34b-96528d4a8f0d
- c4ab7f5e-b2d9-4746-b74c-8cca0d06fb78
- c4ad6857-3c7d-49e4-9055-8e300aafa78b
- c914a74d-6ff1-4654-b6ff-a73bb58b119f
- cc8fd7cb-9d8a-46cd-a152-1e0f84876e17
- cde1e0a3-f4d0-4b41-9095-c28365a6c1dd
- d17e1bbe-29a0-4b18-b013-1508ab3c2d07
- d287b5a4-bddc-411e-9090-7700a50c02ca
- d642bd56-e820-407f-89e6-2b59cb1b7af3
- dcc42e4a-351d-4912-909f-8cce7bf59773
- dd53c8e6-d683-4cf4-9fb8-352aaa18d324
- dee78903-6aec-438f-bb5a-587c5e1c6b0c
- e10d08e4-1a69-4b7e-95f9-d0ef3c1efce1
- e7815926-6164-4305-b63f-c39063cc30c6
- f30f0c5f-5268-47f7-b4cc-6c4f31c97feb
- f5c60bb1-09cc-4b5c-b4f8-b540ceb311ff
- f724f412-5784-4ea7-a600-7609d62d8d0f
- f8b91bd7-1ac6-4d03-a871-06d92fb7b0b0
- fcae4b0e-6e19-4716-baf9-f95160720606

### $ cifrao  (4 sample devices)
- 24e15dd0-5bde-47a0-ae59-f0112be010d2
- 3f4d5b4e-d188-4941-a18f-03af733ea4e1
- 69e2c9b8-9d3b-4bf9-be26-7bb5ce5d1204
- f696a9e0-9f26-4ebd-aa7a-ca0ce827dfb6

### U+00A0 NBSP-as-decimal  (1 sample devices)
- f93e13a5-10a3-4040-ad04-5dc909deba3c

### - dash  (1 sample devices)
- 659b4c44-96e8-4db0-bfa4-4a881a2053d9
