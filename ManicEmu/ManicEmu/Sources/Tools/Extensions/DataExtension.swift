//
//  DataExtension.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/10.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import Accelerate
import CryptoKit

protocol Bufferable {
    var buffer: vImage_Buffer { get }
    var height: Int { get }
    var width: Int { get }
    var rowBytes: Int { get }
}

class RawBuffer: Bufferable {
    private(set) var bytes: Data

    // dimensions
    let width: Int
    let height: Int
    let rowBytes: Int

    init(data: Data, width: Int, height: Int, rowBytes: Int) {
        self.bytes = data
        self.width = width
        self.height = height
        self.rowBytes = rowBytes
    }

    var buffer: vImage_Buffer {
        // get bytes pointer
        
        let ptr = bytes.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> UnsafeMutablePointer<UInt8>? in
            guard let baseAddress = rawBufferPointer.baseAddress else {
                return nil
            }
            return UnsafeMutablePointer<UInt8>(mutating: baseAddress.assumingMemoryBound(to: UInt8.self))
        }


        return vImage_Buffer(data: ptr, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
    }
}

struct ThreeDSIcon {
    static func decode(srcBuffer: Bufferable) -> Bufferable? {
        let width = srcBuffer.width
        let height = srcBuffer.height
        
        // create empty data with proper count of bytes
        let rowBytes = width * 3
        let dstData = Data(count: height * rowBytes)
        let dstBuffer = RawBuffer(data: dstData, width: width, height: height, rowBytes: rowBytes)
        
        // mutate buffer
        var buffer565 = srcBuffer.buffer
        var buffer888 = dstBuffer.buffer
        
        // convert
        let error = vImageConvert_RGB565toRGB888(&buffer565, &buffer888, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        
        //
        return dstBuffer
    }
}

extension Data {
    func decodeRGB565(width: Int, height: Int) -> UIImage? {
        // create source buffer
        let srcBuffer = RawBuffer(data: self, width: width, height: height, rowBytes: width * 2)

        // decode
        guard let dstBuffer = ThreeDSIcon.decode(srcBuffer: srcBuffer)
            else { return nil }

        //
        var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 24, colorSpace: nil, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), version: 0, decode: nil, renderingIntent: .defaultIntent)

        //
        var buffer888 = dstBuffer.buffer
        var error: vImage_Error = 0
        let vImage = vImageCreateCGImageFromBuffer(&buffer888, &format, nil, nil, vImage_Flags(kvImageNoFlags), &error)
        guard error == kvImageNoError else { return nil }

        // create an UIImage
        return vImage.flatMap {
            UIImage(cgImage: $0.takeRetainedValue(), scale: 1.0, orientation: .up)
        }
    }
    
    var md5String: String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    func writeWithCompletePath(to path: String) throws {
        try writeWithCompletePath(to: URL(fileURLWithPath: path))
    }
    
    func writeWithCompletePath(to url: URL) throws {
        let parentUrl = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentUrl.path) {
            try FileManager.default.createDirectory(at: parentUrl, withIntermediateDirectories: true)
        }
        try write(to: url)
    }
}
