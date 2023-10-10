const std = @import("std");
const secp256k1 = @import("../secp256k1/secp256k1.zig");
const utils = @import("../utils.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn generateMasterPrivateKey(seed: [64]u8, masterPrivateKey: *[32]u8, masterChainCode: *[32]u8) void {
    var I: [std.crypto.auth.hmac.sha2.HmacSha512.mac_length]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha512.create(I[0..], &seed, "Bitcoin seed");

    masterPrivateKey[0..32].* = I[0..32].*;
    masterChainCode[0..32].* = I[32..].*;
}

pub fn toWif(key: [32]u8) void {
    _ = key;
}

pub fn generateCompressedPublicKey(privateKey: [32]u8) ![33]u8 {
    const k = std.mem.readIntBig(u256, &privateKey);
    var point = secp256k1.Point{ .x = secp256k1.BASE_POINT.x, .y = secp256k1.BASE_POINT.y };
    point.multiply(k);

    var strCompressedPublicKey: [66]u8 = undefined;
    if (@mod(point.y, 2) == 0) {
        _ = try std.fmt.bufPrint(&strCompressedPublicKey, "02{x}", .{point.x});
    } else {
        _ = try std.fmt.bufPrint(&strCompressedPublicKey, "03{x}", .{point.x});
    }

    const intCompressedPublicKey = try std.fmt.parseInt(u264, &strCompressedPublicKey, 16);
    const compressedPublicKey: [33]u8 = @bitCast(intCompressedPublicKey);

    return compressedPublicKey;
}

pub fn generateUncompressedPublicKey(privateKey: [32]u8) ![65]u8 {
    const k = std.mem.readIntBig(u256, &privateKey);
    var point = secp256k1.Point{ .x = secp256k1.BASE_POINT.x, .y = secp256k1.BASE_POINT.y };
    point.multiply(k);

    var strUncompressedPublicKey: [130]u8 = undefined;
    _ = try std.fmt.bufPrint(&strUncompressedPublicKey, "04{x}{x}", .{ point.x, point.y });

    std.debug.print("Str uncompressed public key {s}\n", .{strUncompressedPublicKey});

    const intUncompressedPublicKey = try std.fmt.parseInt(u520, &strUncompressedPublicKey, 16);
    const uncompressedPublicKey: [65]u8 = @bitCast(intUncompressedPublicKey);
    return uncompressedPublicKey;
}

pub fn deriveAddressFromCompressedPublicKey(publicKey: [33]u8) !void {
    var buffer: [66]u8 = undefined;
    const udata: u264 = std.mem.readIntNative(u264, &publicKey);
    try utils.intToHexStr(u264, udata, &buffer);
    var hashed: [32]u8 = undefined;

    var bytes: [33]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, &buffer);

    std.crypto.hash.sha2.Sha256.hash(&bytes, &hashed, .{});
    const uHashed = std.mem.readIntBig(u256, &hashed);
    std.debug.print("Hashed {x}\n", .{uHashed});
}

pub fn deriveChild(privateKey: [32]u8, publicKey: [33]u8, chainCode: [32]u8, index: u32, childPrivateKey: *[32]u8, childChainCode: *[32]u8) !void {
    assert(index >= 0);
    assert(index <= 2147483647);
    const indexBytes: [4]u8 = @bitCast(index);

    const data: [37]u8 = indexBytes ++ publicKey;
    const udata: u296 = std.mem.readIntNative(u296, &data);

    // 74 = 37 * 2 (2 hex characters per byte)
    var bufdata: [74]u8 = undefined;
    try utils.intToHexStr(u296, udata, &bufdata);

    const uchaincode: u256 = std.mem.readIntBig(u256, &chainCode);
    var bufchaincode: [64]u8 = undefined;
    try utils.intToHexStr(u256, uchaincode, &bufchaincode);

    var bytesData: [37]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytesData, &bufdata);
    var bytesChainCode: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytesChainCode, &bufchaincode);

    var I: [std.crypto.auth.hmac.sha2.HmacSha512.mac_length]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha512.create(I[0..], &bytesData, &bytesChainCode);

    childChainCode[0..32].* = I[32..].*;
    const res = std.mem.readIntBig(u512, I[0..]);

    const uprivate: u256 = std.mem.readIntBig(u256, &privateKey);
    const random: u256 = std.mem.readIntBig(u256, I[0..32]);
    const k: u256 = @intCast(@mod(@as(u512, uprivate) + random, secp256k1.NUMBER_OF_POINTS));
    std.debug.print("K {d}\n", .{k});
    childPrivateKey[0..32].* = @bitCast(k);

    std.debug.print("HMAC res {x}\n", .{res});
}

pub fn deriveChildHardened(privateKey: [32]u8, chainCode: [32]u8, index: u32, childPrivateKey: *[32]u8, childChainCode: *[32]u8) !void {
    assert(index >= 2147483647);
    assert(index <= 4294967295);

    const indexBytes: [4]u8 = @bitCast(index);
    const data: [36]u8 = indexBytes ++ privateKey;
    const udata: u288 = std.mem.readIntNative(u288, &data);

    var bufdata: [72]u8 = undefined;
    try utils.intToHexStr(u288, udata, &bufdata);

    const uchaincode: u256 = std.mem.readIntBig(u256, &chainCode);
    var bufchaincode: [64]u8 = undefined;
    try utils.intToHexStr(u256, uchaincode, &bufchaincode);

    var bytesData: [37]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytesData, &bufdata);
    var bytesChainCode: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytesChainCode, &bufchaincode);

    var I: [std.crypto.auth.hmac.sha2.HmacSha512.mac_length]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha512.create(I[0..], &bytesData, &bytesChainCode);

    childChainCode[0..32].* = I[32..].*;
    const res = std.mem.readIntBig(u512, I[0..]);

    const uprivate: u256 = std.mem.readIntBig(u256, &privateKey);
    const random: u256 = std.mem.readIntBig(u256, I[0..32]);
    const k: u256 = @intCast(@mod(@as(u512, uprivate) + random, secp256k1.NUMBER_OF_POINTS));
    childPrivateKey[0..32].* = @bitCast(k);

    std.debug.print("HMAC res {x}\n", .{res});
}

test "generateMasterPrivateKey" {
    const seed = [64]u8{ 0b00100110, 0b11101001, 0b01110101, 0b11101100, 0b01100100, 0b01000100, 0b00100011, 0b11110100, 0b10100100, 0b11000100, 0b11110100, 0b00100001, 0b01011110, 0b11110000, 0b10011011, 0b01001011, 0b11010111, 0b11101111, 0b10010010, 0b01001110, 0b10000101, 0b11010001, 0b11010001, 0b01111100, 0b01001100, 0b11110011, 0b11110001, 0b00110110, 0b11000010, 0b10000110, 0b00111100, 0b11110110, 0b11011111, 0b00001010, 0b01000111, 0b01010000, 0b01000101, 0b01100101, 0b00101100, 0b01010111, 0b11101011, 0b01011111, 0b10110100, 0b00010101, 0b00010011, 0b11001010, 0b00101010, 0b00101101, 0b01100111, 0b01110010, 0b00101011, 0b01110111, 0b11101001, 0b01010100, 0b10110100, 0b10110011, 0b11111100, 0b00010001, 0b11110111, 0b01011001, 0b00000100, 0b01001001, 0b00011001, 0b00011101 };
    var masterPrivateKey: [32]u8 = undefined;
    var masterChainCode: [32]u8 = undefined;
    generateMasterPrivateKey(seed, &masterPrivateKey, &masterChainCode);

    const mi = std.mem.readIntBig(u256, &masterPrivateKey);
    const mc = std.mem.readIntBig(u256, &masterChainCode);

    const actualMasterPrivateKey: u256 = 83708698721082954555187515680589715112564529485085597027431858654736703376481;
    const actualMasterChainCode: u256 = 81368020368549252319622804490134865780945683298038298120975729975949991701395;

    try std.testing.expectEqual(actualMasterPrivateKey, mi);
    try std.testing.expectEqual(actualMasterChainCode, mc);
}

test "generateCompressedPublicKey" {
    const masterPrivateKey = [32]u8{ 0b10111001, 0b00010001, 0b01110001, 0b11001001, 0b10011111, 0b01110000, 0b10010111, 0b11111101, 0b01110101, 0b01001011, 0b01001000, 0b11110010, 0b01010010, 0b00010001, 0b00110011, 0b10100001, 0b11100000, 0b10100110, 0b10010100, 0b10111000, 0b01101110, 0b10100101, 0b11011110, 0b01101011, 0b10111010, 0b01100000, 0b00000100, 0b01011011, 0b00001111, 0b00100101, 0b01001100, 0b01100001 };
    const compressedPublicKey = try generateCompressedPublicKey(masterPrivateKey);
    const intCompressedPublicKey: u264 = std.mem.readIntNative(u264, &compressedPublicKey);
    try std.testing.expectEqual(intCompressedPublicKey, 371021088148843091519123278369699840892534340640782334706731698887367669696056);
}

test "generateUncompressedPublicKey" {
    const masterPrivateKey = [32]u8{ 0b10111001, 0b00010001, 0b01110001, 0b11001001, 0b10011111, 0b01110000, 0b10010111, 0b11111101, 0b01110101, 0b01001011, 0b01001000, 0b11110010, 0b01010010, 0b00010001, 0b00110011, 0b10100001, 0b11100000, 0b10100110, 0b10010100, 0b10111000, 0b01101110, 0b10100101, 0b11011110, 0b01101011, 0b10111010, 0b01100000, 0b00000100, 0b01011011, 0b00001111, 0b00100101, 0b01001100, 0b01100001 };
    const uncompressedPublicKey = try generateUncompressedPublicKey(masterPrivateKey);
    const intUncompressedPublicKey: u520 = std.mem.readIntNative(u520, &uncompressedPublicKey);
    try std.testing.expectEqual(intUncompressedPublicKey, 56369114877799594661188296746717703076673813647934040365584748932532373788020011766136440806660229408156383305013228873759763532598787701125186219479120245);
}
