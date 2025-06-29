import AVFoundation
import Foundation
import Speech
import SwiftUI
import os

class SpeechRecognizer: ObservableObject {
    private let logger = Logger(subsystem: "com.notkeepingitreal.voice-assist", category: "SpeechRecognizer")

    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer:
                return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize:
                return "Not authorized to recognize speech"
            case .notPermittedToRecord:
                return "Not permitted to record audio"
            case .recognizerIsUnavailable:
                return "Recognizer is unavailable"
            }
        }
    }
    
    @Published var isRecording = false
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    init() {
        recognizer = SFSpeechRecognizer()
        
        Task(priority: .background) {
            do {
                guard recognizer != nil else {
                    throw RecognizerError.nilRecognizer
                }
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                logError(error)
            }
        }
    }
    
    deinit {
        reset()
    }
    
    func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }
    
    func recordButtonTapped() {
        if isRecording {
            stopTranscribing()
        } else {
            transcribe()
        }
    }
    
    private func transcribe() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            self.logError(RecognizerError.recognizerIsUnavailable)
            return
        }
        
        do {
            let (audioEngine, request) = try Self.prepareEngine()
            self.audioEngine = audioEngine
            self.request = request
            
            self.task = recognizer.recognitionTask(with: request) { result, error in
                // The completion handler is called on a background thread.
                // We need to stop the engine and update state on the main thread.
                
                let receivedFinalResult = result?.isFinal ?? false
                let receivedError = error != nil
                
                if receivedFinalResult || receivedError {
                    audioEngine.stop()
                    audioEngine.inputNode.removeTap(onBus: 0)
                }
                
                if let result = result {
                    self.logTranscript(result.bestTranscription.formattedString)
                }
                
                if receivedFinalResult || receivedError {
                    DispatchQueue.main.async {
                        self.isRecording = false
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            self.reset()
            self.logError(error)
            DispatchQueue.main.async {
                self.isRecording = false
            }
        }
    }
    
    private func stopTranscribing() {
        request?.endAudio()
    }

    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
    
    private func logTranscript(_ message: String) {
        logger.log("Transcribed: \"\(message)\"")
    }
    
    private func logError(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        logger.error("Error: \(errorMessage)")
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
