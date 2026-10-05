import SwiftUI

/// 来源截图的全屏查看器：双指缩放、拖动平移、双击切换缩放。
struct ImageZoomViewer: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 8

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnifyGesture.simultaneously(with: dragGesture))
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.25)) {
                        if scale > 1 {
                            resetZoom()
                        } else {
                            scale = 2.5
                        }
                    }
                }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .padding(16)
                    }
                }
                Spacer()
                Text("双指缩放 · 拖动平移 · 双击放大/还原")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 24)
                    .opacity(scale > 1 ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: scale)
            }
        }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(baseScale * value.magnification, minScale), maxScale)
            }
            .onEnded { _ in
                baseScale = scale
                if scale <= minScale {
                    withAnimation(.spring(duration: 0.25)) { resetZoom() }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1 else {
                    withAnimation(.spring(duration: 0.25)) { resetZoom() }
                    return
                }
                baseOffset = offset
            }
    }

    private func resetZoom() {
        scale = 1
        baseScale = 1
        offset = .zero
        baseOffset = .zero
    }
}
