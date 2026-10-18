import AppKit

struct IconutilError: Error {
    let status: Int32
    let stderr: Data
}

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fail("usage: \(arguments[0]) <output.icns>")
}

let outputURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL

func bitmap(pixels: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fail("could not allocate \(pixels)x\(pixels) bitmap")
    }
    rep.size = NSSize(width: CGFloat(pixels), height: CGFloat(pixels))
    return rep
}

func withContext(_ rep: NSBitmapImageRep, _ body: (NSGraphicsContext) -> Void) {
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fail("could not create graphics context")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.interpolationQuality = .high
    context.cgContext.setShouldAntialias(true)
    body(context)
    NSGraphicsContext.restoreGraphicsState()
}

func masterImage() -> NSBitmapImageRep {
    let rep = bitmap(pixels: 1024)
    withContext(rep) { _ in
        NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.08, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

        NSColor.white.setFill()
        for degrees: CGFloat in [40, -40] {
            let arm = NSBezierPath(
                roundedRect: NSRect(x: -46, y: -300, width: 92, height: 600),
                xRadius: 46,
                yRadius: 46
            )
            // Appended rotation is applied before the translation, so the arm rotates about its center.
            var transform = AffineTransform.identity
            transform.translate(x: 512, y: 512)
            transform.rotate(byDegrees: degrees)
            arm.transform(using: transform)
            arm.fill()
        }
    }
    return rep
}

func scaledImage(from master: NSBitmapImageRep, pixels: Int) -> NSBitmapImageRep {
    if pixels == master.pixelsWide, pixels == master.pixelsHigh {
        return master
    }
    let rep = bitmap(pixels: pixels)
    withContext(rep) { _ in
        let hints: [NSImageRep.HintKey: Any] = [
            .interpolation: NSNumber(value: NSImageInterpolation.high.rawValue),
        ]
        let drawn = master.draw(
            in: NSRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels)),
            from: NSRect(origin: .zero, size: master.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: hints
        )
        if !drawn {
            fail("could not downsample to \(pixels)px")
        }
    }
    return rep
}

func pngData(_ rep: NSBitmapImageRep, name: String) -> Data {
    guard let data = rep.representation(using: .png, properties: [:]), !data.isEmpty else {
        fail("could not encode \(name)")
    }
    return data
}

func writeIcon(to outputURL: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let application = NSApplication.shared
    _ = application.setActivationPolicy(.prohibited)

    let master = masterImage()
    let icons: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    let pngs = icons.map { name, pixels in
        (name, pngData(scaledImage(from: master, pixels: pixels), name: name))
    }

    let iconset = fileManager.temporaryDirectory
        .appendingPathComponent("xmac-\(UUID().uuidString).iconset", isDirectory: true)
    try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: iconset) }

    for (name, data) in pngs {
        try data.write(to: iconset.appendingPathComponent(name), options: .atomic)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", outputURL.path]
    let errorPipe = Pipe()
    process.standardError = errorPipe
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        throw IconutilError(status: process.terminationStatus, stderr: data)
    }
}

do {
    try writeIcon(to: outputURL)
} catch let error as IconutilError {
    if error.stderr.isEmpty {
        fputs("iconutil failed with status \(error.status)\n", stderr)
    } else {
        FileHandle.standardError.write(error.stderr)
    }
    exit(1)
} catch {
    fail(error.localizedDescription)
}
