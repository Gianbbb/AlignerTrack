import Foundation
import UIKit
import PDFKit

public class PDFReportGenerator {
    public static func generateReport(dataManager: AlignerDataManager) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "AlignerTrack",
            kCGPDFContextAuthor: "Paziente AlignerTrack",
            kCGPDFContextTitle: "Report Aderenza Trattamento Allineatori"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        // Dimensioni A4 standard (595.2 x 841.8 pt a 72 dpi)
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Report_AlignerTrack_\(dateStringFile()).pdf")

        do {
            try renderer.writePDF(to: tempURL) { context in
                context.beginPage()

                var currentY: CGFloat = 36.0
                let marginX: CGFloat = 40.0
                let contentWidth: CGFloat = pageWidth - (marginX * 2)

                // 1. Header & Titolo
                let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: UIColor(red: 0.0, green: 0.55, blue: 0.45, alpha: 1.0)
                ]
                let title = "ALIGNERTRACK • REPORT DI CONFORMITÀ"
                title.draw(at: CGPoint(x: marginX, y: currentY), withAttributes: titleAttributes)
                currentY += 28

                let subtitleFont = UIFont.systemFont(ofSize: 11, weight: .medium)
                let subtitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: subtitleFont,
                    .foregroundColor: UIColor.darkGray
                ]
                let subtitle = "Generato il \(formatDate(Date())) • Documento informativo per l'ortodontista curante"
                subtitle.draw(at: CGPoint(x: marginX, y: currentY), withAttributes: subtitleAttributes)
                currentY += 22

                // Linea divisoria verde acqua
                let path = UIBezierPath()
                path.move(to: CGPoint(x: marginX, y: currentY))
                path.addLine(to: CGPoint(x: pageWidth - marginX, y: currentY))
                path.lineWidth = 2
                UIColor(red: 0.0, green: 0.72, blue: 0.58, alpha: 1.0).setStroke()
                path.stroke()
                currentY += 16

                // 2. Riepilogo Paziente / Trattamento (Box a 3 colonne)
                let boxRect = CGRect(x: marginX, y: currentY, width: contentWidth, height: 75)
                let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 8)
                UIColor(white: 0.96, alpha: 1.0).setFill()
                boxPath.fill()

                let curCycle = dataManager.currentCycle
                let curNum = curCycle?.cycleNumber ?? 1
                let totalAl = dataManager.totalTreatmentAligners
                let targetH = Int(dataManager.dailyTargetWearHours)

                drawStatColumn(
                    title: "AVANZAMENTO PIANO",
                    value: "Mascherina #\(curNum) di \(totalAl)",
                    sub: "\(Int((Double(curNum)/Double(totalAl))*100))% completato",
                    x: marginX + 16,
                    y: currentY + 12
                )

                drawStatColumn(
                    title: "OBIETTIVO GIORNALIERO",
                    value: "\(targetH) ore / 24h",
                    sub: "Max 2h di pausa libera",
                    x: marginX + (contentWidth / 3) + 10,
                    y: currentY + 12
                )

                let totalRec = dataManager.cycles.reduce(0) { $0 + $1.recoveryDays }
                drawStatColumn(
                    title: "GIORNI RECUPERO",
                    value: "+\(totalRec) gg totali",
                    sub: "Aggiunti per deficit ore",
                    x: marginX + (contentWidth * 2 / 3) + 10,
                    y: currentY + 12
                )

                currentY += 92

                // 3. Statistiche Chiave di Aderenza
                let sectionTitleFont = UIFont.systemFont(ofSize: 14, weight: .bold)
                "ADERENZA CLINICA E ORE MEDIE".draw(
                    at: CGPoint(x: marginX, y: currentY),
                    withAttributes: [.font: sectionTitleFont, .foregroundColor: UIColor.black]
                )
                currentY += 20

                // Calcolo statistiche ultimi 30 giorni
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                var totalWornH: Double = 0
                var daysGoalMet = 0
                let checkDays = 14

                for offset in 0..<checkDays {
                    if let d = cal.date(byAdding: .day, value: -offset, to: today) {
                        let wornSec = dataManager.wornSeconds(for: d)
                        totalWornH += (wornSec / 3600.0)
                        if wornSec >= dataManager.dailyTargetWearSeconds {
                            daysGoalMet += 1
                        }
                    }
                }

                let avgWorn = totalWornH / Double(checkDays)
                let compliance = (Double(daysGoalMet) / Double(checkDays)) * 100.0

                let statText = "• Media ore giornaliere effettive (ultimi 14 gg): \(String(format: "%.1f ore", avgWorn))\n" +
                               "• Tasso di raggiungimento obiettivo 22h: \(String(format: "%.0f%%", compliance)) dei giorni\n" +
                               "• Numero totale pause/pasti registrati: \(dataManager.sessions.count)\n" +
                               "• Stato attuale mascherina: \(dataManager.isAlignerRemoved ? "Tolto (in pausa)" : "Indossato correttamente")"

                let bodyFont = UIFont.systemFont(ofSize: 10.5, weight: .regular)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 5
                statText.draw(
                    in: CGRect(x: marginX + 4, y: currentY, width: contentWidth, height: 80),
                    withAttributes: [
                        .font: bodyFont,
                        .foregroundColor: UIColor.darkGray,
                        .paragraphStyle: paragraphStyle
                    ]
                )
                currentY += 80

                // 4. Tabella Dettaglio Mascherine del Trattamento
                "STORICO DELLE MASCHERINE E CAMBI".draw(
                    at: CGPoint(x: marginX, y: currentY),
                    withAttributes: [.font: sectionTitleFont, .foregroundColor: UIColor.black]
                )
                currentY += 20

                // Header Tabella
                let headerRect = CGRect(x: marginX, y: currentY, width: contentWidth, height: 22)
                UIColor(red: 0.9, green: 0.94, blue: 0.93, alpha: 1.0).setFill()
                UIRectFill(headerRect)

                let thFont = UIFont.systemFont(ofSize: 9, weight: .bold)
                let thColor = UIColor(red: 0.0, green: 0.45, blue: 0.35, alpha: 1.0)
                "MASCHERINA".draw(at: CGPoint(x: marginX + 8, y: currentY + 5), withAttributes: [.font: thFont, .foregroundColor: thColor])
                "DATA INIZIO".draw(at: CGPoint(x: marginX + 90, y: currentY + 5), withAttributes: [.font: thFont, .foregroundColor: thColor])
                "DATA FINE".draw(at: CGPoint(x: marginX + 175, y: currentY + 5), withAttributes: [.font: thFont, .foregroundColor: thColor])
                "DURATA".draw(at: CGPoint(x: marginX + 260, y: currentY + 5), withAttributes: [.font: thFont, .foregroundColor: thColor])
                "RECUPERO".draw(at: CGPoint(x: marginX + 335, y: currentY + 5), withAttributes: [.font: thFont, .foregroundColor: thColor])
                "NOTE".draw(at: CGPoint(x: marginX + 410, y: currentY + 5), withAttributes: [.font: thFont, .foregroundColor: thColor])

                currentY += 24

                // Righe cicli
                let cellFont = UIFont.systemFont(ofSize: 9.5, weight: .regular)
                for (index, cycle) in dataManager.cycles.enumerated() {
                    if currentY > pageHeight - 120 { break } // evita overflow pagina

                    if index % 2 == 1 {
                        let rowRect = CGRect(x: marginX, y: currentY, width: contentWidth, height: 20)
                        UIColor(white: 0.97, alpha: 1.0).setFill()
                        UIRectFill(rowRect)
                    }

                    "M#\(cycle.cycleNumber)".draw(at: CGPoint(x: marginX + 8, y: currentY + 3), withAttributes: [.font: cellFont])
                    formatShort(cycle.startDate).draw(at: CGPoint(x: marginX + 90, y: currentY + 3), withAttributes: [.font: cellFont])
                    formatShort(cycle.calculatedEndDate).draw(at: CGPoint(x: marginX + 175, y: currentY + 3), withAttributes: [.font: cellFont])
                    "\(cycle.nominalDays) gg".draw(at: CGPoint(x: marginX + 260, y: currentY + 3), withAttributes: [.font: cellFont])
                    (cycle.recoveryDays > 0 ? "+\(cycle.recoveryDays) gg" : "0 gg").draw(at: CGPoint(x: marginX + 335, y: currentY + 3), withAttributes: [.font: cellFont])
                    (cycle.note.isEmpty ? "-" : cycle.note).draw(at: CGPoint(x: marginX + 410, y: currentY + 3), withAttributes: [.font: cellFont])

                    currentY += 21
                }

                currentY += 20

                // 5. Box Note / Firma Ortodontista
                let noteBoxRect = CGRect(x: marginX, y: currentY, width: contentWidth, height: 60)
                let notePath = UIBezierPath(roundedRect: noteBoxRect, cornerRadius: 6)
                UIColor.lightGray.withAlphaComponent(0.4).setStroke()
                notePath.lineWidth = 1
                notePath.stroke()

                "Note & Indicazioni dell'Ortodontista alla visita:".draw(
                    at: CGPoint(x: marginX + 8, y: currentY + 6),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: UIColor.gray]
                )

                // Footer
                let footer = "Documento redatto automaticamente da AlignerTrack (iOS) con misurazioni al secondo dei tempi di posa."
                footer.draw(
                    at: CGPoint(x: marginX, y: pageHeight - 40),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 8, weight: .regular), .foregroundColor: UIColor.lightGray]
                )
            }
            return tempURL
        } catch {
            print("Errore nella generazione PDF: \(error.localizedDescription)")
            return nil
        }
    }

    private static func drawStatColumn(title: String, value: String, sub: String, x: CGFloat, y: CGFloat) {
        title.draw(
            at: CGPoint(x: x, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 8.5, weight: .bold),
                .foregroundColor: UIColor.gray
            ]
        )
        value.draw(
            at: CGPoint(x: x, y: y + 14),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .heavy),
                .foregroundColor: UIColor.black
            ]
        )
        sub.draw(
            at: CGPoint(x: x, y: y + 34),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: UIColor(red: 0.0, green: 0.55, blue: 0.45, alpha: 1.0)
            ]
        )
    }

    private static func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMMM yyyy HH:mm"
        return f.string(from: d)
    }

    private static func formatShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d/M/yyyy"
        return f.string(from: d)
    }

    private static func dateStringFile() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f.string(from: Date())
    }
}
