import AppKit
// App icon: a brain (memory) with a small "history" badge, on the app's indigo-purple gradient.
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowBlurRadius = 30; shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3); shadow.set()
NSGradient(colors: [NSColor(red: 0.36, green: 0.42, blue: 0.98, alpha: 1), NSColor(red: 0.62, green: 0.33, blue: 0.95, alpha: 1)])!.draw(in: path, angle: -45)
NSGraphicsContext.current?.restoreGraphicsState()

func draw(_ name: String, pointSize: CGFloat, color: NSColor, center: NSPoint) {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium).applying(.init(paletteColors: [color]))
    guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
    let s = sym.size
    sym.draw(in: NSRect(x: center.x - s.width/2, y: center.y - s.height/2, width: s.width, height: s.height))
}

// brain
draw("brain", pointSize: 400, color: .white, center: NSPoint(x: 492, y: 530))

// badge
let badge = NSRect(x: 610, y: 175, width: 250, height: 250)
NSGraphicsContext.current?.saveGraphicsState()
let bs = NSShadow(); bs.shadowBlurRadius = 18; bs.shadowOffset = NSSize(width: 0, height: -6)
bs.shadowColor = NSColor.black.withAlphaComponent(0.25); bs.set()
NSColor.white.setFill(); NSBezierPath(ovalIn: badge).fill()
NSGraphicsContext.current?.restoreGraphicsState()
draw("clock.arrow.circlepath", pointSize: 140, color: NSColor(red: 0.50, green: 0.36, blue: 0.97, alpha: 1),
     center: NSPoint(x: badge.midX, y: badge.midY))

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
