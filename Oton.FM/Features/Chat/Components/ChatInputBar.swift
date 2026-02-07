import SwiftUI

/// Text input bar at the bottom of the chat view.
/// Capsule-shaped text field with a circular send button.
/// Shows a brief cooldown indicator after sending.
struct ChatInputBar: View {
    @Binding var text: String
    let cooldownRemaining: TimeInterval
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && cooldownRemaining <= 0
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("", text: $text, prompt: Text(promptText)
                .foregroundStyle(AppColors.textSecondary))
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: Constants.Chat.inputHeight)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
                .onSubmit {
                    if canSend { onSend() }
                }

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(
                        width: Constants.Chat.sendButtonSize,
                        height: Constants.Chat.sendButtonSize
                    )
                    .background(
                        Circle()
                            .fill(AppColors.accentPrimary)
                    )
            }
            .buttonStyle(.plain)
            .opacity(canSend ? 1.0 : 0.3)
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.2), value: canSend)
        }
        .padding(.horizontal, Constants.Chat.messageHorizontalPadding)
        .padding(.vertical, 8)
    }

    private var promptText: String {
        if cooldownRemaining > 0 {
            return "Подождите \(Int(ceil(cooldownRemaining))) сек..."
        }
        return "Напишите в эфир..."
    }
}
