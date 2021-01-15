//
//  WebPDecoderTests.swift
//  GanGImageTests
//
//  Created by won on 2021/01/18.
//  Copyright © 2021 won. All rights reserved.
//

import XCTest
@testable import GanGImage

class WebPDecoderTests: XCTestCase {

    var sut: WebPDecoder!

    override func setUpWithError() throws {
        sut = WebPDecoder()
    }

    func test_inital_setup() {
        sut.updateSourceWebP()
    }
}
