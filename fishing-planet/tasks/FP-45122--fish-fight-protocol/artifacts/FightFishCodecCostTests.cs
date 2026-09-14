using System;
using System.Collections;
using System.Collections.Generic;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using ObjectModel;
using Photon.SocketServer;
using Photon.SocketServer.Rpc.Protocols;
using Photon.SocketServer.Rpc.ValueTypes;
using SocketProtocol = Photon.SocketServer.Protocol;

namespace Photon.LoadBalancing.Tests.Codec
{
    /// <summary>
    /// Measures what one fight message costs on the wire and in managed allocations under the encoding the game
    /// server speaks today (Photon GpBinary, a Hashtable of two-letter keys inside an operation request) against a
    /// packed fixed-layout DTO of the same content. The assertions guard the round trip so the measured bytes are
    /// real; the cost figures are reported, not asserted. Input for the Fish Fight Protocol v2 evaluation (FP-45122).
    /// </summary>
    [TestClass]
    public class FightFishCodecCostTests
    {
        private const int Iterations = 20000;

        // Operation and parameter codes as the fight wire uses them today: OperationCode.GameAction,
        // ParameterCode.GameActionCode / GameActionData, GameActionCode.FightFish.
        private const byte GameActionOperation = 193;
        private const byte GameActionCodeParameter = 186;
        private const byte GameActionDataParameter = 185;
        private const byte FightFishActionCode = 7;

        private static readonly Point3 PlayerPosition = new Point3(1234.5f, 12.25f, -987.75f);
        private static readonly Point3 TacklePosition = new Point3(1250.125f, -3.5f, -1010.0f);

        public TestContext TestContext { get; set; }

        [TestMethod]
        public void FightFishMessage_PhotonGpBinary_versus_PackedDto_costs()
        {
            SocketProtocol.AllowRawCustomValues = true;
            var protocol = SocketProtocol.GpBinaryV162;
            var cache = new CustomTypeCache();
            var request = BuildFightFishRequest();

            // Warm-up and round-trip guard.
            var wire = protocol.SerializeOperationRequest(request, cache);
            Assert.IsTrue(protocol.TryParseOperationRequest(wire, out var parsed, cache), "GpBinary parse failed");
            AssertRoundTrip(parsed);

            var packed = PackedFightFish.From(request);
            var packedBuffer = new byte[256];
            var packedLength = packed.Write(packedBuffer);
            var packedBack = PackedFightFish.Read(packedBuffer);
            Assert.AreEqual(packed, packedBack, "packed round trip failed");

            AppDomain.MonitoringIsEnabled = true;
            var gpSerialize = AllocatedBytesPerCall(() => protocol.SerializeOperationRequest(request, cache));
            var gpParse = AllocatedBytesPerCall(() =>
            {
                protocol.TryParseOperationRequest(wire, out var again, cache);
                return again;
            });
            var packedWrite = AllocatedBytesPerCall(() =>
            {
                packed.Write(packedBuffer);
                return null;
            });
            var packedRead = AllocatedBytesPerCall(() =>
            {
                PackedFightFish.Read(packedBuffer);
                return null;
            });

            Report($"FightFish, {((Hashtable)request.Parameters[GameActionDataParameter]).Count} keys, {Iterations} iterations per figure");
            Report($"Photon GpBinaryV162: wire bytes = {wire.Length}; serialize = {gpSerialize:F0} B/op; parse = {gpParse:F0} B/op");
            Report($"Packed DTO:          wire bytes = {packedLength}; write = {packedWrite:F0} B/op; read = {packedRead:F0} B/op");
            Report($"Ratio wire bytes GpBinary/packed = {(double)wire.Length / packedLength:F2}");
        }

        private static OperationRequest BuildFightFishRequest()
        {
            // The full FightFish set from the catalogue (sixteen fields) plus the three keys every message carries.
            // Today the client omits bool keys that are false; this is the full form, i.e. the upper bound.
            var data = new Hashtable
            {
                ["sN"] = (byte)2,
                ["fC"] = 15,
                ["iPt"] = true,
                ["cA"] = false,
                ["fF"] = 3.75f,
                ["hRdF"] = 41.5f,
                ["hRlF"] = 29.25f,
                ["hTf"] = 37.0f,
                ["iF"] = false,
                ["iPS"] = true,
                ["iR"] = true,
                ["l"] = false,
                ["lL"] = 62.5f,
                ["lTf"] = 11.125f,
                ["p"] = false,
                ["pP"] = new RawCustomValue((byte)'V', VectorSerializationHelper.SerializePoint3(PlayerPosition)),
                ["rS"] = 4,
                ["tP"] = new RawCustomValue((byte)'V', VectorSerializationHelper.SerializePoint3(TacklePosition)),
                ["wLn"] = false,
            };

            var parameters = new Dictionary<byte, object>
            {
                [GameActionCodeParameter] = FightFishActionCode,
                [GameActionDataParameter] = data,
            };
            return new OperationRequest(GameActionOperation, parameters);
        }

        private static void AssertRoundTrip(OperationRequest parsed)
        {
            Assert.AreEqual(GameActionOperation, parsed.OperationCode);
            Assert.AreEqual(FightFishActionCode, (byte)parsed.Parameters[GameActionCodeParameter]);
            var data = (Hashtable)parsed.Parameters[GameActionDataParameter];
            Assert.AreEqual(19, data.Count);
            Assert.AreEqual(41.5f, (float)data["hRdF"]);
            var raw = (RawCustomValue)data["pP"];
            Assert.AreEqual((byte)'V', raw.Code);
            var position = (Point3)VectorSerializationHelper.DeserializePoint3(raw.Data);
            Assert.AreEqual(PlayerPosition.X, position.X);
            Assert.AreEqual(PlayerPosition.Y, position.Y);
            Assert.AreEqual(PlayerPosition.Z, position.Z);
        }

        private static double AllocatedBytesPerCall(Func<object> call)
        {
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();
            var before = AppDomain.CurrentDomain.MonitoringTotalAllocatedMemorySize;
            for (var i = 0; i < Iterations; i++)
            {
                call();
            }
            var after = AppDomain.CurrentDomain.MonitoringTotalAllocatedMemorySize;
            return (double)(after - before) / Iterations;
        }

        private void Report(string line)
        {
            TestContext.WriteLine(line);
            Console.WriteLine(line);
        }

        /// <summary>
        /// The same content as a fixed-layout DTO: opcode, slot, cycle, one flag byte for the eight bools, six
        /// floats, the reel speed and two positions. Written into a caller-owned buffer; no allocation per message.
        /// </summary>
        private struct PackedFightFish : IEquatable<PackedFightFish>
        {
            public byte Slot;
            public int Cycle;
            public byte Flags;
            public float FrictionForce;
            public float HighRodForce;
            public float HighReelForce;
            public float HighTerminalTackleForce;
            public float LineLength;
            public float LowTerminalTackleForce;
            public byte ReelSpeed;
            public float PlayerX, PlayerY, PlayerZ;
            public float TackleX, TackleY, TackleZ;

            public static PackedFightFish From(OperationRequest request)
            {
                var data = (Hashtable)request.Parameters[GameActionDataParameter];
                var flags = 0;
                if ((bool)data["iPt"]) flags |= 1;
                if ((bool)data["cA"]) flags |= 2;
                if ((bool)data["iF"]) flags |= 4;
                if ((bool)data["iPS"]) flags |= 8;
                if ((bool)data["iR"]) flags |= 16;
                if ((bool)data["l"]) flags |= 32;
                if ((bool)data["p"]) flags |= 64;
                if ((bool)data["wLn"]) flags |= 128;
                var player = (Point3)VectorSerializationHelper.DeserializePoint3(((RawCustomValue)data["pP"]).Data);
                var tackle = (Point3)VectorSerializationHelper.DeserializePoint3(((RawCustomValue)data["tP"]).Data);
                return new PackedFightFish
                {
                    Slot = (byte)data["sN"],
                    Cycle = (int)data["fC"],
                    Flags = (byte)flags,
                    FrictionForce = (float)data["fF"],
                    HighRodForce = (float)data["hRdF"],
                    HighReelForce = (float)data["hRlF"],
                    HighTerminalTackleForce = (float)data["hTf"],
                    LineLength = (float)data["lL"],
                    LowTerminalTackleForce = (float)data["lTf"],
                    ReelSpeed = (byte)(int)data["rS"],
                    PlayerX = player.X, PlayerY = player.Y, PlayerZ = player.Z,
                    TackleX = tackle.X, TackleY = tackle.Y, TackleZ = tackle.Z,
                };
            }

            public int Write(byte[] buffer)
            {
                var offset = 0;
                buffer[offset++] = FightFishActionCode;
                buffer[offset++] = Slot;
                WriteInt(buffer, ref offset, Cycle);
                buffer[offset++] = Flags;
                VectorSerializationHelper.Serialize(FrictionForce, buffer, ref offset);
                VectorSerializationHelper.Serialize(HighRodForce, buffer, ref offset);
                VectorSerializationHelper.Serialize(HighReelForce, buffer, ref offset);
                VectorSerializationHelper.Serialize(HighTerminalTackleForce, buffer, ref offset);
                VectorSerializationHelper.Serialize(LineLength, buffer, ref offset);
                VectorSerializationHelper.Serialize(LowTerminalTackleForce, buffer, ref offset);
                buffer[offset++] = ReelSpeed;
                VectorSerializationHelper.Serialize(PlayerX, buffer, ref offset);
                VectorSerializationHelper.Serialize(PlayerY, buffer, ref offset);
                VectorSerializationHelper.Serialize(PlayerZ, buffer, ref offset);
                VectorSerializationHelper.Serialize(TackleX, buffer, ref offset);
                VectorSerializationHelper.Serialize(TackleY, buffer, ref offset);
                VectorSerializationHelper.Serialize(TackleZ, buffer, ref offset);
                return offset;
            }

            public static PackedFightFish Read(byte[] buffer)
            {
                var offset = 1; // opcode
                var result = new PackedFightFish { Slot = buffer[offset++] };
                result.Cycle = ReadInt(buffer, ref offset);
                result.Flags = buffer[offset++];
                VectorSerializationHelper.Deserialize(out result.FrictionForce, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.HighRodForce, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.HighReelForce, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.HighTerminalTackleForce, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.LineLength, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.LowTerminalTackleForce, buffer, ref offset);
                result.ReelSpeed = buffer[offset++];
                VectorSerializationHelper.Deserialize(out result.PlayerX, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.PlayerY, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.PlayerZ, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.TackleX, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.TackleY, buffer, ref offset);
                VectorSerializationHelper.Deserialize(out result.TackleZ, buffer, ref offset);
                return result;
            }

            private static void WriteInt(byte[] buffer, ref int offset, int value)
            {
                buffer[offset++] = (byte)value;
                buffer[offset++] = (byte)(value >> 8);
                buffer[offset++] = (byte)(value >> 16);
                buffer[offset++] = (byte)(value >> 24);
            }

            private static int ReadInt(byte[] buffer, ref int offset)
            {
                var value = buffer[offset] | (buffer[offset + 1] << 8) | (buffer[offset + 2] << 16) | (buffer[offset + 3] << 24);
                offset += 4;
                return value;
            }

            public bool Equals(PackedFightFish other)
            {
                return Slot == other.Slot && Cycle == other.Cycle && Flags == other.Flags
                    && FrictionForce == other.FrictionForce && HighRodForce == other.HighRodForce
                    && HighReelForce == other.HighReelForce && HighTerminalTackleForce == other.HighTerminalTackleForce
                    && LineLength == other.LineLength && LowTerminalTackleForce == other.LowTerminalTackleForce
                    && ReelSpeed == other.ReelSpeed
                    && PlayerX == other.PlayerX && PlayerY == other.PlayerY && PlayerZ == other.PlayerZ
                    && TackleX == other.TackleX && TackleY == other.TackleY && TackleZ == other.TackleZ;
            }

            public override bool Equals(object obj)
            {
                return obj is PackedFightFish other && Equals(other);
            }

            public override int GetHashCode()
            {
                return (Slot, Cycle, Flags, FrictionForce, HighRodForce, PlayerX, TackleX).GetHashCode();
            }
        }
    }
}
