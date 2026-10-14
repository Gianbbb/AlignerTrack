import SwiftUI
import PhotosUI
import UIKit

public struct SmileComparisonView: View {
    @ObservedObject var dataManager: AlignerDataManager
    @State private var sliderPosition: CGFloat = 0.5
    @State private var selectedBeforeCycle: AlignerCycle? = nil
    @State private var selectedAfterCycle: AlignerCycle? = nil

    public init(dataManager: AlignerDataManager) {
        self.dataManager = dataManager
    }

    private var cyclesWithPhotos: [AlignerCycle] {
        dataManager.cycles.filter { $0.photoData != nil }
    }

    private var beforeCycle: AlignerCycle? {
        selectedBeforeCycle ?? cyclesWithPhotos.first
    }

    private var afterCycle: AlignerCycle? {
        selectedAfterCycle ?? cyclesWithPhotos.last
    }

    private var comparisonImages: (UIImage, UIImage)? {
        guard let b = beforeCycle, let a = afterCycle,
              let bd = b.photoData, let ad = a.photoData,
              let bi = UIImage(data: bd), let ai = UIImage(data: ad) else {
            return nil
        }
        return (bi, ai)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if cyclesWithPhotos.count >= 2,
                       let before = beforeCycle,
                       let after = afterCycle,
                       let images = comparisonImages {

                        // MARK: - Split-Screen Slider Card
                        SplitSliderCardView(
                            beforeCycle: before,
                            afterCycle: after,
                            beforeImage: images.0,
                            afterImage: images.1,
                            sliderPosition: $sliderPosition
                        )

                        // MARK: - Selettore Mascherine
                        ComparisonCyclePickerView(
                            cyclesWithPhotos: cyclesWithPhotos,
                            selectedBeforeCycle: $selectedBeforeCycle,
                            selectedAfterCycle: $selectedAfterCycle
                        )
                    } else {
                        // Empty Placeholder
                        EmptyPhotosPlaceholderView(dataManager: dataManager)
                    }

                    // MARK: - Galleria Cronologica
                    SmilePhotoGalleryGrid(cyclesWithPhotos: cyclesWithPhotos)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Confronto Sorriso")
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

// MARK: - Subview 1: Split Slider Card
struct SplitSliderCardView: View {
    let beforeCycle: AlignerCycle
    let afterCycle: AlignerCycle
    let beforeImage: UIImage
    let afterImage: UIImage
    @Binding var sliderPosition: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Confronto Split Sorriso")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Text("Trascina il cursore ↔")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height

                ZStack(alignment: .leading) {
                    // Immagine DOPO (sotto)
                    Image(uiImage: afterImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()

                    // Immagine PRIMA (sopra, mascherata dal cursore)
                    Image(uiImage: beforeImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: max(0, width * sliderPosition))
                                Spacer(minLength: 0)
                            }
                        )

                    // Linea cursore
                    ZStack {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 3)
                            .shadow(color: .black.opacity(0.3), radius: 3)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .shadow(color: .black.opacity(0.35), radius: 4)
                            .overlay(
                                HStack(spacing: 3) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 10, weight: .bold))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(Color.emeraldMint)
                            )
                    }
                    .position(x: max(18, min(width - 18, width * sliderPosition)), y: height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPos = max(0.05, min(0.95, value.location.x / width))
                                sliderPosition = newPos
                            }
                    )

                    // Badge sovrapposti PRIMA / ADESSO
                    VStack {
                        HStack {
                            Text("PRIMA (M#\(beforeCycle.cycleNumber))")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(6)

                            Spacer()

                            Text("ADESSO (M#\(afterCycle.cycleNumber))")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(6)
                        }
                        .padding(10)

                        Spacer()
                    }
                }
                .cornerRadius(18)
            }
            .frame(height: 320)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
        )
    }
}

// MARK: - Subview 2: Comparison Cycle Picker
struct ComparisonCyclePickerView: View {
    let cyclesWithPhotos: [AlignerCycle]
    @Binding var selectedBeforeCycle: AlignerCycle?
    @Binding var selectedAfterCycle: AlignerCycle?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seleziona Mascherine da Confrontare")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Foto Sinistra (Prima):")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Picker("Prima", selection: $selectedBeforeCycle) {
                        ForEach(cyclesWithPhotos) { c in
                            Text("Mascherina #\(c.cycleNumber)").tag(Optional(c))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Foto Destra (Dopo):")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Picker("Dopo", selection: $selectedAfterCycle) {
                        ForEach(cyclesWithPhotos) { c in
                            Text("Mascherina #\(c.cycleNumber)").tag(Optional(c))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Subview 3: Empty Photos Placeholder
struct EmptyPhotosPlaceholderView: View {
    @ObservedObject var dataManager: AlignerDataManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(Color.emeraldMint)

            Text("Confronto Prima & Dopo")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text("Per attivare il cursore di confronto, carica almeno 2 foto del sorriso nelle impostazioni delle mascherine (es. Mascherina #1 e mascherina attuale).")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            NavigationLink(destination: TreatmentManagementView(dataManager: dataManager)) {
                Text("Vai a caricare le foto")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.emeraldMint)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Subview 4: Smile Photo Gallery Grid
struct SmilePhotoGalleryGrid: View {
    let cyclesWithPhotos: [AlignerCycle]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Galleria Cronologica Sorriso (\(cyclesWithPhotos.count) foto)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            if cyclesWithPhotos.isEmpty {
                Text("Nessuna foto ancora registrata.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(cyclesWithPhotos) { c in
                        if let data = c.photoData, let img = UIImage(data: data) {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 120)
                                    .clipped()
                                    .cornerRadius(12)

                                HStack {
                                    Circle()
                                        .fill(Color(hex: c.colorHex))
                                        .frame(width: 8, height: 8)
                                    Text("Mascherina #\(c.cycleNumber)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
