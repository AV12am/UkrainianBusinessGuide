//
//  AdvisorView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct AdvisorView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case chat = "Питання"
        case idea = "Оцінка ідеї"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .chat

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Режим", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 8)

                switch mode {
                case .chat: AdvisorChatView()
                case .idea: IdeaValidatorView()
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Радник")
        }
    }
}

struct AdvisorChatView: View {
    @Environment(AppStore.self) private var store
    @State private var messages: [AdvisorMessage] = [
        AdvisorMessage(role: .advisor, text: "Питайте про податки, строки сплати, вибір групи, найм чи фінансування. Відповіді враховують цифри вашого бізнесу.")
    ]
    @State private var draft = ""
    @State private var isThinking = false
    @FocusState private var inputFocused: Bool

    private let advisor: any AdvisorEngine = LocalAdvisor()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .transition(.opacity)
                        }
                        if isThinking {
                            Text("Радник рахує…")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkMuted)
                                .id("thinking")
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) {
                    guard let last = messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }

            Rule()
            suggestions
            inputBar
        }
    }

    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LocalAdvisor.suggestions, id: \.self) { suggestion in
                    Button(suggestion) { send(suggestion) }
                        .buttonStyle(.outline)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 10)
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ваше питання", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.rule))
                .onSubmit { send(draft) }
            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 44, height: 44)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            .accessibilityLabel("Надіслати")
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 10)
    }

    @MainActor
    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking, let context = store.advisorContext else { return }
        draft = ""
        withAnimation {
            messages.append(AdvisorMessage(role: .user, text: question))
            isThinking = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            let answer = await advisor.reply(to: question, context: context)
            withAnimation {
                isThinking = false
                messages.append(AdvisorMessage(role: .advisor, text: answer))
            }
        }
    }
}

/// Відповідь радника — звичайний текст на папері; питання користувача — у рамці праворуч.
struct MessageView: View {
    let message: AdvisorMessage

    var body: some View {
        switch message.role {
        case .advisor:
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Радник", color: Theme.accent)
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .user:
            HStack {
                Spacer(minLength: 56)
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.rule))
            }
        }
    }
}

#Preview {
    AdvisorView()
        .environment(AppStore.preview)
}
