// Draws the app icon from the app's own look: black glass, the Today ring of days, light from the bottom edge.
// Usage: swift Scripts/make-icon.swift <out.png>   (make-icon.sh turns it into AppIcon.icns)
import SwiftUI
import AppKit

struct Icon: View {
    let green = Color(red: 0x34 / 255, green: 0xD3 / 255, blue: 0x99 / 255)
    let cyan = Color(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xEE / 255)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 185, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Color(white: 0.09), .black], startPoint: .top, endPoint: .bottom))
            // The edge light, as on every screen.
            Ellipse()
                .fill(LinearGradient(colors: [green, cyan], startPoint: .leading, endPoint: .trailing))
                .frame(width: 700, height: 260)
                .blur(radius: 90)
                .opacity(0.55)
                .offset(y: 400)
            ring
            shape.strokeBorder(.white.opacity(0.1), lineWidth: 4)
        }
        .clipShape(shape)
        .frame(width: 824, height: 824)
        .frame(width: 1024, height: 1024)
    }

    /// 31 days: gone ones lit, today bright, paydays green and cyan, the rest faint.
    var ring: some View {
        ZStack {
            ForEach(0..<31, id: \.self) { day in
                let angle = Angle.degrees(Double(day) / 31 * 360 - 90)
                let today = day == 18, gone = day < 18
                let colour: Color = day == 0 ? green : day == 19 ? cyan : today ? .white : gone ? .white.opacity(0.8) : .white.opacity(0.16)
                let size: CGFloat = today ? 54 : day == 0 || day == 19 ? 34 : 24
                Circle()
                    .fill(colour)
                    .frame(width: size, height: size)
                    .shadow(color: today ? .white.opacity(0.6) : .clear, radius: 18)
                    .offset(x: 290 * cos(angle.radians), y: 290 * sin(angle.radians))
            }
        }
    }
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = 1
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        fatalError("could not draw the icon")
    }
    try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
