//
//  WebPDecoder.swift
//  GanGImage
//
//  Created by won on 2021/01/18.
//  Copyright © 2021 won. All rights reserved.
//

import libwebp
import CoreImage
import Foundation
import QuartzCore
import Accelerate

public class WebPDecoder {

    enum DecodingError: Error {
        case unknown
    }

    var width: Int = 0
    var height: Int = 0
    var loopCount: Int = 0
    var frameCount: Int = 0
    var frames = [ImageDecoderFrame]()
    var needBlend: Bool = false

    var semaphore = DispatchSemaphore(value: 1)
    var webpSource: OpaquePointer?
    var blendCanvas: CGContext?

    init() {
        try? updateSourceWebP()
        let decoderFrame = frame(at: 0)
        print(decoderFrame ?? "decoderFrame is nil")
    }

    func updateSourceWebP() throws {
        let dataPath = Bundle.main.path(forResource: "heart", ofType: "webp")
        let fileData = try! Data(contentsOf: URL(fileURLWithPath: dataPath!))

        var webPData = WebPData(bytes: fileData.bytes, size: fileData.count)

        /*
         https://developers.google.com/speed/webp/docs/api
         The documentation said we can use WebPIDecoder to decode webp progressively,
         but currently it can only returns an empty image (not same as progressive jpegs),
         so we don't use progressive decoding.

         When using WebPDecode() to decode multi-frame webp, we will get the error
         "VP8_STATUS_UNSUPPORTED_FEATURE", so we first use WebPDemuxer to unpack it.
         */
        let demuxer = WebPDemux(&webPData)
        let webpFrameCount: UInt32 = WebPDemuxGetI(demuxer, WEBP_FF_FRAME_COUNT)
        let webpLoopCount: UInt32 = WebPDemuxGetI(demuxer, WEBP_FF_LOOP_COUNT)
        var canvasWidth: UInt32 = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_WIDTH)
        var canvasHeight: UInt32 = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_HEIGHT)

        guard webpFrameCount != .zero else {
            WebPDemuxDelete(demuxer)
            throw DecodingError.unknown
        }
        // TODO: check other values

        var frames = [ImageDecoderFrame]()
        var needBlend = false
        var iteratorIndex: UInt32 = 0
        var lastBlendIndex: UInt32 = 0
        var iterator: WebPIterator = .init()

        let demuxFrame = WebPDemuxGetFrame(demuxer, 1, &iterator)
        guard demuxFrame == 1 else { return }

        repeat {
            var frame = ImageDecoderFrame()

            if iterator.dispose_method == WEBP_MUX_DISPOSE_BACKGROUND {
                frame.dispose = .background
            }

            if iterator.blend_method == WEBP_MUX_BLEND {
                frame.blend = .over
            }
            canvasWidth = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_WIDTH)
            canvasHeight = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_HEIGHT)

            frame.index = Int(iteratorIndex)
            frame.duration = Double(iterator.duration) / 1000.0
            frame.width = Int(iterator.width)
            frame.height = Int(iterator.height)
            frame.hasAlpha = (iterator.has_alpha != 0)
            frame.offsetX = Int(iterator.x_offset)
            frame.offsetY = Int(Int32(canvasHeight) - iterator.y_offset - iterator.height)

            let sizeEqualsToCanvas = iterator.width == canvasWidth && iterator.height == canvasHeight
            let offsetIsZeo = iterator.x_offset == .zero && iterator.y_offset == .zero
            frame.isFullSize = sizeEqualsToCanvas && offsetIsZeo

            if (frame.blend != .none || !frame.hasAlpha) && frame.isFullSize {
                lastBlendIndex = iteratorIndex
                frame.blendFromIndex = Int(iteratorIndex)
            } else {
                if frame.dispose == .background && frame.isFullSize {
                    frame.blendFromIndex = Int(lastBlendIndex)
                    lastBlendIndex = iteratorIndex + 1
                } else {
                    frame.blendFromIndex = Int(lastBlendIndex)
                }
            }

            if frame.index != frame.blendFromIndex {
                needBlend = true
            }
            iteratorIndex += 1
            frames.append(frame)
        } while (WebPDemuxNextFrame(&iterator) != 0)

        /// Release Iterator
        WebPDemuxReleaseIterator(&iterator)

        if frames.count != webpFrameCount {
            WebPDemuxDelete(demuxer)
            return
        }

        width = Int(canvasWidth)
        height = Int(canvasHeight)
        frameCount = frames.count
        loopCount = Int(webpLoopCount)
        self.needBlend = needBlend
        webpSource = demuxer
        self.webpSource = demuxer

        semaphore.wait()
        self.frames = frames
        semaphore.signal()
    }

    func frame(at index: Int, decodeForDisplay: Bool = true) -> ImageDecoderFrame? {
        guard index < frames.count else { return nil }
        let frame = frames[index]
        print("🚀🚀🚀 ", frame)
        _ = false
        _ = false

        if needBlend == false {
//            newUnblendedImage(at: index, extendToCanvas: false, decoded: false)
            // return image
        }
        guard let blendCanvas = createBlendContextIfNeeded() else { return nil }
        self.blendCanvas = blendCanvas

        var _: CGImage?

        if blendFrameIndex + 1 == frame.index {
            // TODO
            blendFrameIndex = frame.index
        } else {
            blendFrameIndex = 0
            blendCanvas.clear(CGRect(x: 0, y: 0, width: width, height: height))

            if blendFrameIndex == frame.index {
                let image = newUnblendedImage(at: 1, extendToCanvas: false, decoded: false)
                print(">>>>>>>>>>>>> ", image?.width ?? -1, image?.height ?? -1)
            }
        }



        return nil
    }

    var blendFrameIndex: Int = 0

    func createBlendContextIfNeeded() -> CGContext? {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Host)

        let cgContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        )

        return cgContext
    }

    /// Returns byte-aligned size.
    func imageByteAlign(size: size_t, alignment: size_t) -> size_t {
        return ((size + (alignment - 1)) / alignment) * alignment;
    }

    var source: CGImageSource?

    func newUnblendedImage(at index: Int, extendToCanvas: Bool, decoded: Bool) -> CGImage? {
        guard let webpSource = webpSource else { return nil }

        var iter: WebPIterator = .init()
        // demux webp frame data
        guard WebPDemuxGetFrame(webpSource, Int32(index + 1), &iter) != 0 else { return nil }
        // frame numbers are one-based in webp -----------^

        guard iter.width > 0 && iter.height > 0 else { return nil }

        let width = extendToCanvas ? Int32(self.width) : iter.width
        let height = extendToCanvas ? Int32(self.height) : iter.height

        let payload: UnsafePointer<UInt8> = iter.fragment.bytes
        let payloadSize = iter.fragment.size

        var config: WebPDecoderConfig = .init()
        guard WebPInitDecoderConfig(&config) != 0 else {
            WebPDemuxReleaseIterator(&iter)
            return nil
        }

        guard WebPGetFeatures(payload , payloadSize, &config.input) == VP8_STATUS_OK else {
            WebPDemuxReleaseIterator(&iter);
            return nil
        }

        let bitsPerComponent: size_t = 8
        let bitsPerPixel: size_t = 32
        let bytesPerRow: size_t = imageByteAlign(size: bitsPerPixel / 8 * Int(width), alignment: 32)
        let length: size_t = bytesPerRow * Int(height)

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
            .union(.byteOrder32Host)

        guard let pixels = calloc(1, length) else {
            WebPDemuxReleaseIterator(&iter)
            return nil
        }

        config.output.colorspace = MODE_bgrA
        config.output.is_external_memory = 1;
        config.output.u.RGBA.rgba = pixels.bindMemory(to: UInt8.self, capacity: 1)
        config.output.u.RGBA.stride = Int32(bytesPerRow)
        config.output.u.RGBA.size = length

        let result = WebPDecode(payload, payloadSize, &config) // decode
        if (result != VP8_STATUS_OK) && (result != VP8_STATUS_NOT_ENOUGH_DATA) {
            WebPDemuxReleaseIterator(&iter)
            free(pixels)
            return nil
        }
        WebPDemuxReleaseIterator(&iter);

        if extendToCanvas && (iter.x_offset != 0 || iter.y_offset != 0) {
            guard let temp = calloc(1, length) else { return nil }

            var source = vImage_Buffer(
                data: pixels,
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: bytesPerRow
            )

            var destination = vImage_Buffer(
                data: temp,
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: bytesPerRow
            )

            var transform = vImage_CGAffineTransform(
                a: 1,
                b: 0,
                c: 0,
                d: 1,
                tx: Double(iter.x_offset), ty: -Double(iter.y_offset)
            )

            var backColor: [UInt8] = [0, 0, 0, 0]

            let error = vImageAffineWarpCG_ARGB8888(
                &source,
                &destination,
                nil,
                &transform,
                &backColor,
                vImage_Flags(kvImageBackgroundColorFill)
            )

            if error == kvImageNoError {
                memcpy(pixels, temp, length)
            }
            free(temp)
        }

        guard let provider = CGDataProvider(
                dataInfo: pixels,
                data: pixels,
                size: length,
                releaseData: { (info, data, size) in
                    if let info = info {
                        free(info)
                    }
                }) else {
            return nil
        }

        let image = CGImage(
            width: Int(width),
            height: Int(height),
            bitsPerComponent: Int(bitsPerComponent),
            bitsPerPixel: Int(bitsPerPixel),
            bytesPerRow: Int(bytesPerRow),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )

        return image
    }

    func createDecodedCopy(cgImage: CGImage, decodeForDisplay: Bool = false) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height

        if width == 0 || height == 0 { return nil }

        /// Decode with redraw (may lose some precision)
        if decodeForDisplay {

            let alphaInfo = CGImageAlphaInfo(rawValue: cgImage.alphaInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)

            let hasAlpha: Bool = alphaInfo == .premultipliedLast
                || alphaInfo == .premultipliedFirst
                || alphaInfo == .last
                || alphaInfo == .first

            // BGRA8888 (premultiplied) or BGRX8888
            // same as UIGraphicsBeginImageContext() and -[UIView drawRect:]
            let bitmapInfo = CGBitmapInfo(
                rawValue: hasAlpha ?
                    CGImageAlphaInfo.premultipliedFirst.rawValue :
                    CGImageAlphaInfo.noneSkipFirst.rawValue
            )
            .union(.byteOrder32Host)

            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            )
            guard let ctx = context else { return nil }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return ctx.makeImage()
        } else {

            let bitsPerComponent = cgImage.bitsPerComponent
            let bitsPerPixel = cgImage.bitsPerPixel
            let bytesPerRow = cgImage.bytesPerRow
            let bitmapInfo = cgImage.bitmapInfo
            if bytesPerRow == 0 {
                return nil
            }

            guard let dataProvider = cgImage.dataProvider else { return nil }
            guard let data = dataProvider.data else { return nil }
            guard let newProvider = CGDataProvider(data: data) else { return nil }

            guard let space = cgImage.colorSpace else { return nil }
            let newImage = CGImage(
                width: cgImage.width,
                height: cgImage.height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerPixel,
                bytesPerRow: bytesPerRow,
                space: space,
                bitmapInfo: bitmapInfo,
                provider: newProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )

            return newImage
        }
    }
}

struct ImageDecoderFrame {
    var index: Int = 0
    var width: Int = 0
    var height: Int = 0
    var offsetX: Int = 0
    var offsetY: Int = 0
    var duration: TimeInterval = 0
    var dispose: DisposeMethod = .none
    var blend: BlendOperation = .none
    var image: UIImage?
    var hasAlpha: Bool = false
    var isFullSize: Bool = false
    var blendFromIndex: Int = 0
}

public extension CGBitmapInfo {
    static var byteOrder16Host: CGBitmapInfo {
        CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) ? .byteOrder16Little : .byteOrder16Big
    }

    static var byteOrder32Host: CGBitmapInfo {
        CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) ? .byteOrder32Little : .byteOrder32Big
    }
}
