//
//  AdvisorView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct AdvisorView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case chat = "Чат"
        case idea = "Валідатор ідей"
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
                .padding(.horizontal)
                .padding(.bottom, 8)

                switch mode {
                case .chat: AdvisorChatView()
                case .idea: IdeaValidatorView()
                }
            }
            .background(AppBackground())
            .navigationTitle("Радник")
        }
    }
}

struct AdvisorChatView: View {
    @Environment(AppStore.self) private var store
    @State private var messages: [AdvisorMessage] = [
        AdvisorMessage(role: .advisor, text: "Привіт! Я ваш бізнес-радник. Знаю ваші цифри й податкові правила ФОП — питайте про податки, строки, групу, найм чи фінансування.")
    ]
    @State private var draft = ""
    @State private var isThinking = false
    @FocusState private var inputFocused: Bool

    private let advisor: any AdvisorEngine = LocalAdvisor()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if isThinking {
                            TypingIndicator()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("typing")
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) {
                    guard let last = messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }

            suggestions
            inputBar
        }
    }

    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LocalAdvisor.suggestions, id: \.self) { suggestion in
                    Button(suggestion) { send(suggestion) }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Запитайте щось…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onSubmit { send(draft) }
            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.brand, in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            .accessibilityLabel("Надіслати")
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @MainActor
    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking, let context = store.advisorContext else { return }
        draft = ""
        withAnimation(.spring) {
            messages.append(AdvisorMessage(role: .user, text: question))
            isThinking = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            let answer = await advisor.reply(to: question, context: context)
            withAnimation(.spring) {
                isThinking = false
                messages.append(AdvisorMessage(role: .advisor, text: answer))
            }
        }
    }
}

struct MessageBubble: View {
    let message: AdvisorMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) } else {
                IconBadge(systemName: "safari.fill", tint: Theme.blue, size: 30)
            }
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if isUser {
                        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.brand)
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial)
                    }
                }
                .textSelection(.enabled)
            if !isUser { Spacer(minLength: 32) }
        }
    }
}

struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.skyBlue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(phase == Double(index) ? 1.3 : 0.8)
                    .opacity(phase == Double(index) ? 1 : 0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Capsule())
        .padding(.leading, 38)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.easeInOut(duration: 0.25)) { phase = (phase + 1).truncatingRemainder(dividingBy: 3) }
            }
        }
    }
}

#Preview {
    AdvisorView()
        .environment(AppStore.preview)
}
