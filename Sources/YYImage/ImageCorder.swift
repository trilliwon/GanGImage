//
//  ImageCorder.swift
//  GanGImage
//
//  Created by won on 2020/12/28.
//  Copyright © 2020 won. All rights reserved.
//

import Foundation

////////////////////////////////////////////////////////////////////////////////
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

/*
typedef enum {
    YY_PNG_ALPHA_TYPE_PALEETE = 1 << 0,
    YY_PNG_ALPHA_TYPE_COLOR = 1 << 1,
    YY_PNG_ALPHA_TYPE_ALPHA = 1 << 2,
} yy_png_alpha_type;
*/

enum PNGDisposeOp: Int {
    case none = 0
    case background = 1
    case previous = 2
}

/*
typedef enum {
    YY_PNG_DISPOSE_OP_NONE = 0,
    YY_PNG_DISPOSE_OP_BACKGROUND = 1,
    YY_PNG_DISPOSE_OP_PREVIOUS = 2,
} yy_png_dispose_op;
*/

struct PGNChuckIHDR {
    let width: UInt32            ///< pixel count, should not be zero
    let height: UInt32           ///< pixel count, should not be zero
    let bitDepth: UInt8          ///< expected: 1, 2, 4, 8, 16
    let colorType: UInt8         ///< see yy_png_alpha_type
    let compressionMethod: UInt8 ///< 0 (deflate/inflate)
    let filterMethod: UInt8      ///< 0 (adaptive filtering with five basic filter types)
    let interlaceMethod: UInt8   ///< 0 (no interlace) or 1 (Adam7 interlace)
}
/*
typedef struct {
    uint32_t width;             ///< pixel count, should not be zero
    uint32_t height;            ///< pixel count, should not be zero
    uint8_t bit_depth;          ///< expected: 1, 2, 4, 8, 16
    uint8_t color_type;         ///< see yy_png_alpha_type
    uint8_t compression_method; ///< 0 (deflate/inflate)
    uint8_t filter_method;      ///< 0 (adaptive filtering with five basic filter types)
    uint8_t interlace_method;   ///< 0 (no interlace) or 1 (Adam7 interlace)
} yy_png_chunk_IHDR;
*/
