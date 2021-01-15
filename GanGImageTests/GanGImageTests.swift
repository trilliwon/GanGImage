//
//  GanGImageTests.swift
//  GanGImageTests
//
//  Created by won on 2021/01/15.
//  Copyright © 2021 won. All rights reserved.
//

import XCTest
@testable import GanGImage

class GanGImageTests: XCTestCase {

    func test_pngInfoCreate() {
        let pngImage = UIImage(named: "small")
        XCTAssertNotNil(pngImage)
        guard let pngData = pngImage?.pngData() else {
            XCTFail()
            return
        }

        let pngDataMutablePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: pngData.count)
        pngData.copyBytes(to: pngDataMutablePointer, count: pngData.count)
        let uInt8Pointer = UnsafePointer<UInt8>(pngDataMutablePointer)
        let pngInfo = pngInfoCreate(data: uInt8Pointer, length: UInt32(pngData.count))
        XCTAssertGreaterThan(UInt32(pngData.count), 32)

        XCTAssertNotNil(pngInfo)
    }

    func test_fourCC() {
        let uint32 = fourCC(0x89, 0x50, 0x4E, 0x47)
        XCTAssertEqual(uint32, 1196314761)
        XCTAssertEqual(uint32, fourCC2(0x89, 0x50, 0x4E, 0x47))
    }

//    func test_yy_swap_endian_uint16() {
//        XCTAssertEqual(2560, yy_swap_endian_uint16(10))
//        XCTAssertEqual(2560, swapEndianUInt16(value: 10))
//
//        XCTAssertEqual(256, yy_swap_endian_uint16(1))
//        XCTAssertEqual(256, swapEndianUInt16(value: 1))
//    }
//
//    func test_yy_swap_endian_uint32() {
//        XCTAssertEqual(167772160, yy_swap_endian_uint32(10))
//        XCTAssertEqual(167772160, swapEndianUInt32(value: 10))
//
//        XCTAssertEqual(16777216, yy_swap_endian_uint32(1))
//        XCTAssertEqual(16777216, swapEndianUInt32(value: 1))
//
//        XCTAssertEqual(33554432, yy_swap_endian_uint32(2))
//        XCTAssertEqual(33554432, swapEndianUInt32(value: 2))
//    }
//
//    func test_yy_png_chunk_IHDR_read() {
//        var ihdr = yy_png_chunk_IHDR(
//            width: 0,
//            height: 0,
//            bit_depth: 0,
//            color_type: 0,
//            compression_method: 0,
//            filter_method: 0,
//            interlace_method: 0
//        )
//
//        var ihdr1 = PNGChunkIHDR(
//            width: 0,
//            height: 0,
//            bit_depth: 0,
//            color_type: 0,
//            compression_method: 0,
//            filter_method: 0,
//            interlace_method: 0
//        )
//
//        var data = "P".utf8.map { UInt8($0) }[0]
//        yy_png_chunk_IHDR_read(&ihdr, &data)
//
//        XCTAssertEqual(ihdr.width, 1358632992)
//        XCTAssertEqual(ihdr.height, 4286513152)
//
//        pngChunckIHDRRead(IHDR: &ihdr1, data: &data)
////        XCTAssertEqual(ihdr1.width, 1358632992)
////        XCTAssertEqual(ihdr1.height, 4286513152)
//    }
}
