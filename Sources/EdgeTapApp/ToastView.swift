import SwiftUI

struct ToastView: View {
    let message: String
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Iridescent Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3), .cyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .blur(radius: isVisible ? 0 : 4)
            .scaleEffect(isVisible ? 1 : 0.8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(Localization.get("GESTURE_DETECTION_ENABLED"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(message)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            ZStack {
                // Liquid Glass - Main Body
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark) // Force dark glass look
                
                // Content-driven glow
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        EllipticalGradient(
                            colors: [.blue.opacity(0.15), .purple.opacity(0.1), .clear],
                            center: .center,
                            startRadiusFraction: 0,
                            endRadiusFraction: 1
                        )
                    )
                
                // Iridescent Border (Refraction)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.6),
                                .blue.opacity(0.3),
                                .purple.opacity(0.3),
                                .white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.overlay)
            }
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                isVisible = true
            }
        }
    }
}
