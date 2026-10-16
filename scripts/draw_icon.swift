import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Impossible de créer le contexte de dessin")
}
let cream = CGColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
let green = CGColor(red: 0.17, green: 0.34, blue: 0.28, alpha: 1)
let sage = CGColor(red: 0.62, green: 0.73, blue: 0.61, alpha: 1)
let peach = CGColor(red: 0.94, green: 0.65, blue: 0.47, alpha: 1)
context.setFillColor(cream)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setFillColor(CGColor(red: 0.88, green: 0.90, blue: 0.82, alpha: 1))
context.fillEllipse(in: CGRect(x: 150, y: 165, width: 724, height: 724))
func house(_ x: CGFloat, _ y: CGFloat, width: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: width, height: width * 0.72), cornerWidth: 34, cornerHeight: 34, transform: nil)); context.fillPath()
    context.beginPath(); context.move(to: CGPoint(x:x-26,y:y+width*0.60)); context.addLine(to:CGPoint(x:x+width/2,y:y+width*1.04)); context.addLine(to:CGPoint(x:x+width+26,y:y+width*0.60))
    context.setLineWidth(48); context.setLineCap(.round); context.setLineJoin(.round); context.setStrokeColor(color); context.strokePath()
    context.setFillColor(cream); context.addPath(CGPath(roundedRect: CGRect(x:x+width*0.38,y:y-2,width:width*0.24,height:width*0.45),cornerWidth:14,cornerHeight:14,transform:nil)); context.fillPath()
}
house(248,260,width:310,color:green)
house(492,260,width:270,color:sage)
context.beginPath(); context.move(to:CGPoint(x:512,y:590))
context.addCurve(to:CGPoint(x:435,y:675),control1:CGPoint(x:480,y:620),control2:CGPoint(x:435,y:640))
context.addCurve(to:CGPoint(x:512,y:707),control1:CGPoint(x:435,y:725),control2:CGPoint(x:483,y:740))
context.addCurve(to:CGPoint(x:589,y:675),control1:CGPoint(x:541,y:740),control2:CGPoint(x:589,y:725))
context.addCurve(to:CGPoint(x:512,y:590),control1:CGPoint(x:589,y:640),control2:CGPoint(x:544,y:620))
context.setFillColor(peach); context.fillPath()
let output = CommandLine.arguments.dropFirst().first ?? "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("Impossible d’exporter l’icône") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Échec de l’export PNG") }
print("Wrote \(output)")
