import SwiftUI

struct AnimatedDots: View {
    @State private var showingDots = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            Text(".")
                .opacity(showingDots >= 1 ? 1 : 0)
                .animation(.easeIn, value: showingDots)
            Text(".")
                .opacity(showingDots >= 2 ? 1 : 0)
                .animation(.easeIn, value: showingDots)
            Text(".")
                .opacity(showingDots >= 3 ? 1 : 0)
                .animation(.easeIn, value: showingDots)
        }
        .onReceive(timer) { _ in
            showingDots = (showingDots + 1) % 4
        }
    }
}

struct ConnectingText: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Холбонуу")
                .font(.system(size: 22, weight: .bold))
            AnimatedDots()
                .font(.system(size: 22, weight: .bold))
        }
        .foregroundColor(.white)
        .frame(height: 60, alignment: .leading)
    }
}

struct AnimatedDots_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            ConnectingText()
        }
    }
}
