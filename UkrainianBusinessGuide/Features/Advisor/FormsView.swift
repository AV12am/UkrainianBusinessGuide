//
//  FormsView.swift
//  UkrainianBusinessGuide
//
//  Довідник документів: що, коли й де подавати, з урахуванням групи ФОП.
//

import SwiftUI

struct FormsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL

    private var forms: [BusinessForm] { FormsCatalog.forms(for: store.profile) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text(intro)
                    .font(.body)
                    .foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(BusinessForm.Stage.allCases) { stage in
                    let items = forms.filter { $0.stage == stage }
                    if !items.isEmpty {
                        LedgerSection(title: stage.title) {
                            ForEach(items) { form in
                                formRow(form)
                            }
                        }
                    }
                }

                Text("Правила звірено \(OpportunityCatalog.verifiedOn.shortUkrainian) \(String(Calendar.kyiv.component(.year, from: OpportunityCatalog.verifiedOn))) року. Строки сплати з сумами дивіться в календарі на вкладці «Податки».")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
    }

    private var intro: String {
        if let group = store.profile?.fopGroup {
            return "Документи, які подає ФОП на \(group.title.lowercased()). Натисніть на документ, щоб відкрити сервіс, де його подають."
        }
        return "Документи, які подає ФОП на єдиному податку. Натисніть на документ, щоб відкрити сервіс, де його подають."
    }

    private func formRow(_ form: BusinessForm) -> some View {
        Button {
            openURL(form.url)
        } label: {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(form.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(Theme.accent)
                    }
                    detail("Коли", form.when)
                    detail("Де", form.whereToFile)
                    if let note = form.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                Rule()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func detail(_ label: String, _ text: String) -> some View {
        (Text("\(label): ").fontWeight(.medium).foregroundColor(Theme.ink) + Text(text).foregroundColor(Theme.inkMuted))
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    FormsView()
        .environment(AppStore.preview)
}
