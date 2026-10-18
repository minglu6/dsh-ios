import SwiftUI

/// Android `FeedbackCategorySheet` / desktop `feedback.dialog`: optional category + note.
struct FeedbackCategorySheet: View {
    var hint: String = L.feedbackHint()
    let onDismiss: () -> Void
    let onSubmit: (_ category: String?, _ note: String, _ complete: @escaping (Bool) -> Void) -> Void

    @State private var category: String?
    @State private var note = ""
    @State private var busy = false
    @State private var error = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L.feedbackCategory())
                        .font(.caption)
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 22)
                    VStack(spacing: 0) {
                        ForEach(Array(categoryList.enumerated()), id: \.element.id) { index, row in
                            Button {
                                guard !busy else { return }
                                category = category == row.id ? nil : row.id
                            } label: {
                                HStack {
                                    Text(row.label).foregroundStyle(T.ink)
                                    Spacer()
                                    if category == row.id {
                                        OfficialGlyph(
                                            kind: .checkOutline,
                                            size: 14,
                                            color: T.accent
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .disabled(busy)
                            if index < categoryList.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
                    .padding(.horizontal, 16)

                    Text(L.feedbackDetail())
                        .font(.caption)
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 22)
                    TextField(hint, text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .disabled(busy)
                        .padding(12)
                        .background(T.inputMajor, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 0.5))
                        .padding(.horizontal, 16)

                    if error {
                        Text(L.feedbackSubmitFailed())
                            .font(.footnote)
                            .foregroundStyle(T.err)
                            .padding(.horizontal, 22)
                    }

                    Button {
                        guard !busy else { return }
                        busy = true
                        error = false
                        onSubmit(category, note.trimmingCharacters(in: .whitespacesAndNewlines)) { success in
                            busy = false
                            error = !success
                            if success { onDismiss() }
                        }
                    } label: {
                        Text(L.submitFeedback())
                            .font(.body.weight(.medium))
                            .foregroundStyle(T.onPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(busy)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                }
                .padding(.top, 12)
            }
            .background(T.bg)
            .navigationTitle(L.submitFeedback())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel()) { if !busy { onDismiss() } }
                        .disabled(busy)
                }
            }
            .interactiveDismissDisabled(busy)
        }
    }

    private var categoryList: [(id: String, label: String)] { L.feedbackCategories() }
}
