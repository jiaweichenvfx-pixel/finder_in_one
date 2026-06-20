import CoreGraphics

enum CardDragMath {
    static func worldTranslation(
        fromScreenTranslation translation: CGSize,
        viewportScale: CGFloat
    ) -> CGSize {
        let scale = viewportScale > 0 ? viewportScale : 1
        return CGSize(
            width: translation.width / scale,
            height: translation.height / scale
        )
    }
}
