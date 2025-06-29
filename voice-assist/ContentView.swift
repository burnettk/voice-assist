//
//  ContentView.swift
//  voice-assist
//
//  Created by Kevin Mast Burnett on 6/28/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isThrobbig = false

    var body: some View {
        VStack {
            Button(action: {
                speechRecognizer.recordButtonTapped()
            }) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .padding(30)
                    .background(speechRecognizer.isRecording ? Color.red : Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 10)
                    .scaleEffect(isThrobbig ? 1.1 : 1.0)
            }
        }
        .padding()
        .onChange(of: speechRecognizer.isRecording) { isRecording in
            if isRecording {
                // Start throbbing animation
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isThrobbig = true
                }
            } else {
                // Stop throbbing animation
                withAnimation(.spring()) {
                    isThrobbig = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
