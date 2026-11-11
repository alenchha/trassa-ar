import UIKit

/// Экспорт схемы комнаты в PDF для мебельщиков:
/// стр. 1 - превью, схема с зонами ±15 см, сводка; стр. 2+ - таблица трасс, фото штроб, заметки.
enum PDFExporter {
    // A4 в пунктах
    static let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    static let margin: CGFloat = 40

    struct Result {
        let url: URL
        let pageCount: Int
    }

    static func fileName(for room: Room) -> String {
        let safe = room.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: " ", with: "_")
        return "\(safe)_схема.pdf"
    }

    static func export(room: Room) throws -> Result {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: room))
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: {
            let f = UIGraphicsPDFRendererFormat()
            f.documentInfo = [kCGPDFContextTitle as String: "Схема трасс · \(room.name)",
                              kCGPDFContextCreator as String: "Трасса"]
            return f
        }())
        var pages = 0
        try renderer.writePDF(to: url) { ctx in
            pages += 1
            ctx.beginPage()
            drawSummaryPage(room: room, cg: ctx.cgContext)
            pages += drawTablePages(room: room, ctx: ctx)
        }
        return Result(url: url, pageCount: pages)
    }

    // MARK: - Страница 1

    private static func drawSummaryPage(room: Room, cg: CGContext) {
        UIColor(hex: 0xF2F1ED).setFill()
        cg.fill(page)
        let width = page.width - margin * 2
        var y = margin

        y += text("ТРАССА / СХЕМА КОМНАТЫ", font(10, .bold), gray, at: CGPoint(x: margin, y: y), width: width) + 10
        y += text(room.name, font(28, .bold), dark, at: CGPoint(x: margin, y: y), width: width) + 4
        let projectLine = [room.project?.name, room.project?.address].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        y += text(projectLine, font(12), gray, at: CGPoint(x: margin, y: y), width: width) + 18

        // Схема
        let schemeRect = CGRect(x: margin, y: y, width: width, height: 260)
        Schematic.draw(Schematic.layout(for: room, in: schemeRect.insetBy(dx: 12, dy: 12)), in: cg, rect: schemeRect, forPrint: true)
        y = schemeRect.maxY + 14

        y += text("±15 см от трассы - не сверлить", font(12, .semibold), UIColor(hex: 0xBA3333),
                  at: CGPoint(x: margin, y: y), width: width) + 8
        let summary = "\(Formatters.routes(room.routes.count)) · \(Formatters.meters(room.totalLength)) · \(Formatters.numeric.string(from: room.updatedAt))"
        y += text(summary, font(12), gray, at: CGPoint(x: margin, y: y), width: width) + 18

        // Превью-снимок из AR
        if let data = room.previewImageData, let image = UIImage(data: data) {
            let maxRect = CGRect(x: margin, y: y, width: width, height: page.height - margin - 40 - y)
            let fit = aspectFit(image.size, in: maxRect)
            let path = UIBezierPath(roundedRect: fit, cornerRadius: 8)
            cg.saveGState()
            path.addClip()
            image.draw(in: fit)
            cg.restoreGState()
        }

        text("Оценка по сохранённой AR-карте. Перед сверлением проверьте детектором.",
             font(10), gray, at: CGPoint(x: margin, y: page.height - margin - 12), width: width)
    }

    // MARK: - Таблица трасс

    /// Возвращает число дополнительных страниц
    private static func drawTablePages(room: Room, ctx: UIGraphicsPDFRendererContext) -> Int {
        var pages = 1
        ctx.beginPage()
        let cg = ctx.cgContext
        let width = page.width - margin * 2
        var y = margin

        func newPageIfNeeded(_ needed: CGFloat) {
            if y + needed > page.height - margin {
                ctx.beginPage()
                pages += 1
                y = margin
            }
        }

        y += text("Трассы · \(room.name)", font(20, .bold), dark, at: CGPoint(x: margin, y: y), width: width) + 16

        // Колонки: №, Тип, Назначение, Длина, Точек, Дата
        let cols: [(String, CGFloat)] = [("№", 24), ("Тип", 100), ("Назначение и заметка", 235), ("Длина", 55), ("Точек", 45), ("Дата", 56)]
        func row(_ values: [String], bold: Bool, color: UIColor? = nil, height: CGFloat) {
            var x = margin
            for (i, value) in values.enumerated() {
                let f = bold ? font(10, .bold) : font(10)
                text(value, f, i == 1 && color != nil ? color! : dark, at: CGPoint(x: x + (i == 1 && color != nil ? 12 : 0), y: y + 6),
                     width: cols[i].1 - 6 - (i == 1 && color != nil ? 12 : 0))
                x += cols[i].1
            }
            if let color {
                color.setFill()
                cg.fill(CGRect(x: margin + cols[0].1, y: y + 8, width: 8, height: 8))
            }
            y += height
            UIColor(hex: 0xD5D6D1).setFill()
            cg.fill(CGRect(x: margin, y: y, width: width, height: 0.5))
        }

        row(cols.map(\.0), bold: true, height: 24)
        for (i, route) in room.sortedRoutes.enumerated() {
            let desc = [route.title, route.note].filter { !$0.isEmpty }.joined(separator: " - ")
            let h = max(24, measure(desc.isEmpty ? "-" : desc, font(10), width: cols[2].1 - 6) + 12)
            newPageIfNeeded(h)
            row(["\(i + 1)", route.type.title, desc.isEmpty ? "-" : desc, Formatters.meters(route.length),
                 "\(route.points.count)", Formatters.numeric.string(from: route.createdAt)],
                bold: false, color: route.type.printColor, height: h)
        }

        // Фото штроб
        let photos = room.sortedRoutes.compactMap { r in r.photoData.flatMap(UIImage.init(data:)).map { (r, $0) } }
        if !photos.isEmpty {
            y += 24
            newPageIfNeeded(40)
            y += text("Фото штроб", font(14, .bold), dark, at: CGPoint(x: margin, y: y), width: width) + 10
            let cell = (width - 12) / 2
            for (i, item) in photos.enumerated() {
                if i % 2 == 0 { newPageIfNeeded(cell * 0.75 + 24) }
                let x = margin + CGFloat(i % 2) * (cell + 12)
                let rect = CGRect(x: x, y: y, width: cell, height: cell * 0.75)
                item.1.draw(in: aspectFit(item.1.size, in: rect))
                text("\(item.0.type.title) · \(item.0.displayTitle)", font(9), gray,
                     at: CGPoint(x: x, y: rect.maxY + 4), width: cell)
                if i % 2 == 1 || i == photos.count - 1 { y += cell * 0.75 + 24 }
            }
        }

        // Заметки
        if !room.notes.isEmpty {
            y += 16
            newPageIfNeeded(40)
            y += text("Заметки", font(14, .bold), dark, at: CGPoint(x: margin, y: y), width: width) + 8
            for note in room.sortedNotes {
                let line = "• \(note.text) (\(Formatters.numeric.string(from: note.createdAt)))"
                newPageIfNeeded(measure(line, font(11), width: width) + 6)
                y += text(line, font(11), dark, at: CGPoint(x: margin, y: y), width: width) + 6
            }
        }
        return pages
    }

    // MARK: - Помощники

    private static let dark = UIColor(hex: 0x101214)
    private static let gray = UIColor(hex: 0x5B6169)

    private static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        let name: String
        switch weight {
        case .bold: name = "Inter-Bold"
        case .semibold: name = "Inter-SemiBold"
        case .medium: name = "Inter-Medium"
        default: name = "Inter-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    @discardableResult
    private static func text(_ string: String, _ font: UIFont, _ color: UIColor, at point: CGPoint, width: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let height = measure(string, font, width: width)
        (string as NSString).draw(with: CGRect(x: point.x, y: point.y, width: width, height: height),
                                  options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        return height
    }

    private static func measure(_ string: String, _ font: UIFont, width: CGFloat) -> CGFloat {
        ceil((string as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                               options: [.usesLineFragmentOrigin], attributes: [.font: font], context: nil).height)
    }

    private static func aspectFit(_ size: CGSize, in rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let s = min(rect.width / size.width, rect.height / size.height)
        let w = size.width * s, h = size.height * s
        return CGRect(x: rect.minX + (rect.width - w) / 2, y: rect.minY, width: w, height: h)
    }
}
