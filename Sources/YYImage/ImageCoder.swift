//
//  ImageCoder.swift
//  GanGImage
//
//  Created by won on 2021/01/14.
//  Copyright © 2021 won. All rights reserved.
//

import Foundation
import libwebp

enum ImageType: Int {
    case unknown    ///< unknown
    case jpeg       ///< jpeg, jpg
    case jpeg2000   ///< jp2
    case tiff       ///< tiff, tif
    case bmp        ///< bmp
    case ico        ///< ico
    case icns       ///< icns
    case gif        ///< gif
    case png        ///< png
    case webP       ///< webp
    case other      ///< other image format
}

/// Dispose method specifies how the area used by the current frame is to be treated
/// before rendering the next frame on the canvas.
enum DisposeMethod: Int {
    /// No disposal is done on this frame before rendering the next;
    /// the contents of the canvas are left as is.
    case none

    /// The frame's region of the canvas is to be cleared to fully transparent black
    /// before rendering the next frame.
    case background

    /// The frame's region of the canvas is to be reverted to the previous contents
    /// before rendering the next frame.
    case previous
}

/// Blend operation specifies how transparent pixels of the current frame are
/// blended with those of the previous canvas.
enum BlendOperation: Int {
    /// All color components of the frame, including alpha, overwrite the current
    /// contents of the frame's canvas region.
    case none

    /// The frame should be composited onto the output buffer based on its alpha.
    case over
}

// MARK: - Endianness

@inlinable func swapEndianUInt16(value: UInt16) -> UInt16 {
    ((value & 0x00FF) << 8) | ((value & 0xFF00) >> 8)
}

@inlinable func swapEndianUInt32(value: UInt32) -> UInt32 {
    ((value & 0x000000FF) << 24) |
    ((value & 0x0000FF00) <<  8) |
    ((value & 0x00FF0000) >>  8) |
    ((value & 0xFF000000) >> 24)
}

// MARK: - APNG

/*
 PNG  spec: http://www.libpng.org/pub/png/spec/1.2/PNG-Structure.html
 APNG spec: https://wiki.mozilla.org/APNG_Specification

 ===============================================================================
 PNG format:
 header (8): 89 50 4e 47 0d 0a 1a 0a
 chunk, chunk, chunk, ...

 ===============================================================================
 chunk format:
 length (4): uint32_t big endian
 fourcc (4): chunk type code
 data   (length): data
 crc32  (4): uint32_t big endian crc32(fourcc + data)

 ===============================================================================
 PNG chunk define:

 IHDR (Image Header) required, must appear first, 13 bytes
 width              (4) pixel count, should not be zero
 height             (4) pixel count, should not be zero
 bit depth          (1) expected: 1, 2, 4, 8, 16
 color type         (1) 1<<0 (palette used), 1<<1 (color used), 1<<2 (alpha channel used)
 compression method (1) 0 (deflate/inflate)
 filter method      (1) 0 (adaptive filtering with five basic filter types)
 interlace method   (1) 0 (no interlace) or 1 (Adam7 interlace)

 IDAT (Image Data) required, must appear consecutively if there's multiple 'IDAT' chunk

 IEND (End) required, must appear last, 0 bytes

 ===============================================================================
 APNG chunk define:

 acTL (Animation Control) required, must appear before 'IDAT', 8 bytes
 num frames     (4) number of frames
 num plays      (4) number of times to loop, 0 indicates infinite looping

 fcTL (Frame Control) required, must appear before the 'IDAT' or 'fdAT' chunks of the frame to which it applies, 26 bytes
 sequence number   (4) sequence number of the animation chunk, starting from 0
 width             (4) width of the following frame
 height            (4) height of the following frame
 x offset          (4) x position at which to render the following frame
 y offset          (4) y position at which to render the following frame
 delay num         (2) frame delay fraction numerator
 delay den         (2) frame delay fraction denominator
 dispose op        (1) type of frame area disposal to be done after rendering this frame (0:none, 1:background 2:previous)
 blend op          (1) type of frame area rendering for this frame (0:source, 1:over)

 fdAT (Frame Data) required
 sequence number   (4) sequence number of the animation chunk
 frame data        (x) frame data for this frame (same as 'IDAT')

 ===============================================================================
 `dispose_op` specifies how the output buffer should be changed at the end of the delay
 (before rendering the next frame).

 * NONE: no disposal is done on this frame before rendering the next; the contents
    of the output buffer are left as is.
 * BACKGROUND: the frame's region of the output buffer is to be cleared to fully
    transparent black before rendering the next frame.
 * PREVIOUS: the frame's region of the output buffer is to be reverted to the previous
    contents before rendering the next frame.

 `blend_op` specifies whether the frame is to be alpha blended into the current output buffer
 content, or whether it should completely replace its region in the output buffer.

 * SOURCE: all color components of the frame, including alpha, overwrite the current contents
    of the frame's output buffer region.
 * OVER: the frame should be composited onto the output buffer based on its alpha,
    using a simple OVER operation as described in the "Alpha Channel Processing" section
    of the PNG specification
 */

enum PNGAlphaType: Int {
    case paleete = 1
    case color = 2
    case alpha = 4
}

enum PNGDisposeOp: Int {
    case none = 0
    case background = 1
    case previous = 2
}

enum PNGBlendOp: Int {
    case source = 0
    case over = 1
}

struct PNGChunkIHDR {
    var width: UInt32             ///< pixel count, should not be zero
    var height: UInt32            ///< pixel count, should not be zero
    var bit_depth: UInt8           ///< expected: 1, 2, 4, 8, 16
    var color_type: UInt8          ///< see yy_png_alpha_type
    var compression_method: UInt8  ///< 0 (deflate/inflate)
    var filter_method: UInt8       ///< 0 (adaptive filtering with five basic filter types)
    var interlace_method: UInt8    ///< 0 (no interlace) or 1 (Adam7 interlace)
}

struct PNGChunkFcTL {
    let sequence_number: UInt32  ///< sequence number of the animation chunk, starting from 0
    let width: UInt32            ///< width of the following frame
    let height: UInt32           ///< height of the following frame
    let x_offset: UInt32         ///< x position at which to render the following frame
    let y_offset: UInt32         ///< y position at which to render the following frame
    let delay_num: UInt16        ///< frame delay fraction numerator
    let delay_den: UInt16        ///< frame delay fraction denominator
    let dispose_op: UInt8        ///< see yy_png_dispose_op
    let blend_op: UInt8          ///< see yy_png_blend_op
}

struct PNGChunkInfo {
    let offset: UInt32 ///< chunk offset in PNG data
    let fourcc: UInt32 ///< chunk fourcc
    let length: UInt32 ///< chunk data length
    let crc32: UInt32  ///< chunk crc32
}

struct PNGFrameInfo {
    let chunk_index: UInt32 ///< the first `fdAT`/`IDAT` chunk index
    let chunk_num: UInt32   ///< the `fdAT`/`IDAT` chunk count
    let chunk_size: UInt32  ///< the `fdAT`/`IDAT` chunk bytes
    var frame_control: PNGChunkFcTL
}

struct PNGInfo {
    var header: PNGChunkIHDR   ///< png header
    var chunks: PNGChunkInfo      ///< chunks
    let chunk_num: UInt32          ///< count of chunks

    var apng_frames: PNGFrameInfo ///< frame info, NULL if not apng
    let apng_frame_num: UInt32     ///< 0 if not apng
    let apng_loop_num: UInt32      ///< 0 indicates infinite looping

    var apng_shared_chunk_indexs: UInt32 ///< shared chunk index
    let apng_shared_chunk_num: UInt32     ///< shared chunk count
    let apng_shared_chunk_size: UInt32    ///< shared chunk bytes
    let apng_shared_insert_index: UInt32  ///< shared chunk insert index
    let apng_first_frame_is_cover: Bool     ///< the first frame is same as png (cover)
}

func pngChunckIHDRRead(IHDR: inout PNGChunkIHDR, data: UnsafePointer<UInt8>) {
    IHDR.width = swapEndianUInt32(value: UInt32(data.pointee))
    IHDR.height = swapEndianUInt32(value: UInt32(data.pointee + 4))
    IHDR.bit_depth = data[8]
    IHDR.color_type = data[9]
    IHDR.compression_method = data[10]
    IHDR.filter_method = data[11]
    IHDR.interlace_method = data[12]
}

func pngChunckIHDRwrite(IHDR: PNGChunkIHDR, data: UnsafeMutablePointer<UInt8>) {
    let dataPointer = UnsafeMutableRawPointer(data).bindMemory(to: UInt32.self, capacity: 1)

    var width = swapEndianUInt32(value: (UInt32(IHDR.width)))
    var height = swapEndianUInt32(value: UInt32(IHDR.height))
    dataPointer.assign(from: &width, count: 1)
    (dataPointer + 4).assign(from: &height, count: 1)

    data[8] = IHDR.bit_depth
    data[9] = IHDR.color_type
    data[10] = IHDR.compression_method
    data[11] = IHDR.filter_method
    data[12] = IHDR.interlace_method
}

func pngChunkFcTLRead(fcTL: inout PNGChunkFcTL, data: UnsafePointer<UInt8>) {
    fatalError("Does not Implemented")
}

func pngChunkFcTLWrite(fcTL: PNGChunkFcTL, data: UnsafeMutablePointer<UInt8>) {
    fatalError("Does not Implemented")
}

func pngDelayToFraction(duration: Double, num: UnsafeMutablePointer<UInt16>, den: UnsafeMutablePointer<UInt16>) {
    if (duration >= 0xFF) { // duration >= 255
        num[0] = 0xFF
        den[0] = 1
    } else if (duration <= 1.0 / Double(0xFF)) {

    }
    fatalError("Does not Implemented")
}

func pngDelayToSeconds(num: UInt16, den: UInt16) -> Double {
    fatalError("Does not Implemented")
}

func pngValidateAnimationChunkOrder(
    chunks: PNGChunkInfo,
    chunkNum: UInt32,
    firstIdatIndex: UnsafePointer<UInt32>,
    first_frame_is_cover: UnsafePointer<Bool>
) -> Bool {
    fatalError("Does not Implemented")
}

func pngInfoRelease(info: PNGInfo) {
    // Free memory, maybe does not needed
}

func fourCC(_ c1: UInt32, _ c2: UInt32, _ c3: UInt32, _ c4: UInt32) -> UInt32 {
    UInt32((c4 << 24) | (c3 << 16) | (c2 << 8) | c1)
}

func twoCC(_ c1: UInt8, _ c2: UInt8) -> UInt16 {
    UInt16((c2 << 8) | c1)
}

extension Data {
    var bytes: UnsafePointer<UInt8> {
        let pngDataMutablePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        copyBytes(to: pngDataMutablePointer, count: count)
        return UnsafePointer<UInt8>(pngDataMutablePointer)
    }
}

/// Create a png info from a png file. See struct png_info for more information.
///  A PNG always starts with 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
/// - Parameters:
///   - data: png/apng file data.
///   - length: the data's length in bytes.
/// - Returns: A png info object, you may call yy_png_info_release() to release it.
func pngInfoCreate(data: UnsafePointer<UInt8>, length: UInt32) -> Int? {
    guard length >= 32 else { return nil }
    var uint32Pointer = UnsafeRawPointer(data).bindMemory(to: UInt32.self, capacity: 1)

    guard uint32Pointer.pointee == fourCC(0x89, 0x50, 0x4E, 0x47) else { return nil }

    uint32Pointer = UnsafeRawPointer(data + 4).bindMemory(to: UInt32.self, capacity: 1)
    guard uint32Pointer.pointee == fourCC(0x0D, 0x0A, 0x1A, 0x0A) else { return nil }

    return 1
}


func detectImageType() {

}
