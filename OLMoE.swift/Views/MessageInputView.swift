//
//  MessageInputView.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 11/19/24.
//


import SwiftUI

struct MessageInputView: View {
    @Binding var input: String
    @Binding var isGenerating: Bool
    @Binding var stopSubmitted: Bool
    @FocusState.Binding var isTextEditorFocused: Bool
    let isInputDisabled: Bool
    let hasValidInput: Bool
    let respond: () -> Void
    let stop: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            TextField(
                UIDevice.current.userInterfaceIdiom == .mac ?
                    String(localized: "Message OLMoE (Press Return to send)") :
                    String(localized: "Message OLMoE"),
                text: $input,
                axis: .vertical
            )
                .scrollContentBackground(.hidden)
                .multilineTextAlignment(.leading)
                .lineLimit(10)
                .foregroundColor(Color("TextColor"))
                .font(.body())
                .focused($isTextEditorFocused)
                .onChange(of: isTextEditorFocused) { _, isFocused in
                    if !isFocused {
                        hideKeyboard()
                    }
                }
                .disabled(isInputDisabled)
                .opacity(isInputDisabled ? 0.6 : 1)
                .padding(12)
                .onSubmit {
                    #if targetEnvironment(macCatalyst)
                    if hasValidInput {
                        respond()
                    }
                    #endif
                }
                .submitLabel(.send)

            ZStack {
                if isGenerating && !stopSubmitted {
                    Button(action: stop) {
                        Image("StopIcon")
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: respond) {
                        Image("SendIcon")
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasValidInput)
                    .opacity(hasValidInput ? 1 : 0.5)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .onTapGesture {
                isTextEditorFocused = false
            }
            .font(.system(size: 24))
            .frame(width: 40, height: 40)
            .padding(.top, 4)
            .padding(.trailing, 4)

        }
        .padding([.leading, .trailing], 8)
        .frame(maxWidth: .infinity)
        .frame(minHeight: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 40)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color("Surface"))
                .foregroundStyle(.thinMaterial)
        )
    }
}

#Preview {
    @FocusState var isTextEditorFocused: Bool

    MessageInputView(
        input: .constant("Message"),
        isGenerating: .constant(false),
        stopSubmitted: .constant(false),
        isTextEditorFocused: $isTextEditorFocused,
        isInputDisabled: false,
        hasValidInput: true,
        respond: {
            print("Send")
        },
        stop: {
            print("Stop")
        }
    )
    .preferredColorScheme(.dark)
}
