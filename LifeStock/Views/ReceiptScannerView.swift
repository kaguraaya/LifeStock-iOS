import SwiftUI
import PhotosUI
import UIKit

/// 小票扫描：选图 → Vision 识别 → 解析金额 → 选择填入。
///
/// 作为 fullScreenCover 弹出，识别完成后通过 onPick 回调金额并关闭。
/// 识别全程在设备端完成，图片不上传。
struct ReceiptScannerView: View {

    @Environment(\.dismiss) private var dismiss
    var onPick: (Double) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var recognizedLines: [String] = []
    @State private var amounts: [Double] = []
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    pickerCard
                    if let image = image {
                        imagePreview(image)
                    }
                    if isProcessing {
                        ProgressView("识别中…")
                            .padding()
                    }
                    if !amounts.isEmpty {
                        amountsSection
                    }
                    if !recognizedLines.isEmpty && !isProcessing {
                        rawTextSection
                    }
                    if image == nil {
                        EmptyStateView(
                            symbol: "doc.text.viewfinder",
                            title: "扫描小票",
                            message: "选择一张购物小票或商品价签照片，LifeStock 会识别其中的金额，供你一键填入。",
                            actionTitle: nil
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(AppTheme.pad)
            }
            .background(AppTheme.bg)
            .navigationTitle("扫描小票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: 选图
    private var pickerCard: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            Label(image == nil ? "选择小票照片" : "重新选择", systemImage: "camera.viewfinder")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.accent)
        .onChange(of: photoItem) { _, newItem in
            handlePicked(newItem)
        }
    }

    private func imagePreview(_ img: UIImage) -> some View {
        Image(uiImage: img)
            .resizable().scaledToFit()
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
            .cardShadow()
    }

    // MARK: 金额选择
    private var amountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("识别到的金额（点击填入）")
                .font(.subheadline.weight(.semibold))
            ForEach(amounts, id: \.self) { amt in
                Button {
                    onPick(amt)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tag.fill").foregroundStyle(AppTheme.accent)
                        Text(String(format: "%.2f 元", amt))
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.caption)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .padding(AppTheme.pad)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
    }

    // MARK: 原始识别文本
    private var rawTextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("识别原文（仅供参考）")
                .font(.subheadline.weight(.semibold))
            ForEach(recognizedLines, id: \.self) { line in
                Text(line).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.pad)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
    }

    // MARK: 处理选图
    private func handlePicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        item.loadTransferable(type: Data.self) { result in
            if case .success(let data?) = result, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = uiImage
                    self.recognizedLines = []
                    self.amounts = []
                    self.isProcessing = true
                    Task { await self.runOCR(uiImage) }
                }
            }
        }
    }

    @MainActor
    private func runOCR(_ image: UIImage) async {
        let lines = await OCRService.recognize(image: image)
        let amts = OCRService.parseAmounts(from: lines)
        self.recognizedLines = lines
        self.amounts = amts
        self.isProcessing = false
    }
}
