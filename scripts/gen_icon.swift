#!/usr/bin/env swift
// Generates the 1024x1024 app icon: dark ground, Cubi's chip and two eyes.
// Usage: swift scripts/gen_icon.swift [output.png]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Thaw/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

guard let cg = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("Cannot create bitmap context") }

func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

cg.setFillColor(color(0x0D2230))
cg.fill(CGRect(x: 0, y: 0, width: side, height: side))

// Design viewBox is 160x160 with y down; flip to match.
let scale = CGFloat(side) / 160
cg.translateBy(x: 0, y: CGFloat(side))
cg.scaleBy(x: scale, y: -scale)

let chip = CGMutablePath()
chip.move(to: CGPoint(x: 50, y: 30))
chip.addLine(to: CGPoint(x: 108, y: 30))
chip.addLine(to: CGPoint(x: 116, y: 41))
chip.addLine(to: CGPoint(x: 132, y: 46))
chip.addLine(to: CGPoint(x: 132, y: 108))
chip.addQuadCurve(to: CGPoint(x: 108, y: 132), control: CGPoint(x: 132, y: 132))
chip.addLine(to: CGPoint(x: 52, y: 132))
chip.addQuadCurve(to: CGPoint(x: 28, y: 108), control: CGPoint(x: 28, y: 132))
chip.addLine(to: CGPoint(x: 28, y: 54))
chip.addQuadCurve(to: CGPoint(x: 50, y: 30), control: CGPoint(x: 28, y: 30))
chip.closeSubpath()

cg.addPath(chip)
cg.setFillColor(color(0xD9EEF5))
cg.fillPath()
cg.addPath(chip)
cg.setStrokeColor(color(0x6FB7CF))
cg.setLineWidth(5)
cg.setLineJoin(.round)
cg.strokePath()

cg.setFillColor(color(0x0D2230))
for x in [64.0, 96.0] {
    cg.fillEllipse(in: CGRect(x: x - 9, y: 82 - 9, width: 18, height: 18))
}

guard let image = cg.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("Cannot create image destination") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("PNG encoding failed") }
