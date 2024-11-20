import SwiftUI

struct ModalView<Content: View>: View {
    let content: Content
    @Binding var isPresented: Bool
    let showCloseButton: Bool
    let allowOutsideTapDismiss: Bool

    init(isPresented: Binding<Bool>,
        showCloseButton: Bool = true,
        allowOutsideTapDismiss: Bool = true,
        @ViewBuilder content: () -> Content) {
        self.content = content()
        self._isPresented = isPresented
        self.showCloseButton = showCloseButton
        self.allowOutsideTapDismiss = allowOutsideTapDismiss
    }

    func calculateWidth(screenWidth: CGFloat) -> CGFloat {
        let minWidth: CGFloat = 300
        let maxWidth: CGFloat = 600
        let margin: CGFloat = 24
        let idealWidth = screenWidth - 2 * margin
        return max(minWidth, min(idealWidth, maxWidth))
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        if allowOutsideTapDismiss {
                            isPresented = false
                        }
                    }
                
                VStack(spacing: 0) {
                    if showCloseButton {
                        HStack {
                            Spacer()
                            Button(action: { isPresented = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color("TextColor"))
                            }
                        }
                        .padding()
                        .background(Color("Surface"))
                    }
                    
                    ScrollView {
                        content
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color("Surface"))
                }
                .frame(maxWidth: calculateWidth(screenWidth: proxy.size.width), maxHeight: 600)
                .background(Color("Surface"))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview("Basic Modal") {
    ModalView(isPresented: .constant(true)) {
      VStack(spacing: 16) {
        Text("Sample Title")
            .font(.title)
        Text("This is a sample modal content with some text that might wrap to multiple lines.")
            .padding()
      }
    }
}

#Preview("Complex Modal") {
    ModalView(isPresented: .constant(true)) {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)

            Text("Complex Title")
                .font(.title)

            Text("This is a more complex modal with multiple elements.")

            Button("Sample Action") { }
                .buttonStyle(.PrimaryButton)
        }
        .padding()
    }
}

#Preview("Modal with No Close Button") {
    ModalView(
        isPresented: .constant(true),
        showCloseButton: false,
        allowOutsideTapDismiss: false
    ) {
      VStack(spacing: 16) {
          Text("Complex Title")
                .font(.title)
        Text("This modal can only be closed programmatically")
            .padding()
        }
    }
}
