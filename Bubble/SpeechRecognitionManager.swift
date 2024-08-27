//
//  SpeechRecognitionManager.swift
//  Bubble
//
//  Created by Vedant Shah on 8/26/24.
//

import Foundation
import Speech
import AVFoundation
import UIKit

class SpeechRecognitionManager: NSObject, SFSpeechRecognizerDelegate {
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // images
    let earFill = UIImage(systemName: "ear.fill")
    let earEmpty = UIImage(systemName: "ear")
    
    var onResult: ((String) -> Void)?
    
    // MARK: Custom LM Support
    @available(iOS 17, *)
    private var lmConfiguration: SFSpeechLanguageModel.Configuration {
        let outputDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dynamicLanguageModel = outputDir.appendingPathComponent("LM")
        let dynamicVocabulary = outputDir.appendingPathComponent("Vocab")
        
        return SFSpeechLanguageModel.Configuration(languageModel: dynamicLanguageModel, vocabulary: dynamicVocabulary)
    }
    
    override init() {
        super.init()
        speechRecognizer.delegate = self
    }
    
    func requestSpeechAuthorization(button: UIButton) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    if #available(iOS 17, *) {
                        Task.detached {
                            do {
                                guard let assetPath = Bundle.main.path(forResource: "CustomLMData", ofType: "bin", inDirectory: "customlm/en_US") else {
                                    fatalError("path not found")
                                }
                                
                                let assetUrl = URL(fileURLWithPath: assetPath)
                                
                                try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: assetUrl, clientIdentifier: "com.apple.SpokenWord", configuration: self.lmConfiguration)
                                
                            } catch {
                                NSLog("failed to prepare custom LM: \(error.localizedDescription)")
                            }
                            
                            await MainActor.run { button.isEnabled = true}
                        }
                    } else {
                        button.isEnabled = false
                    }
                case .denied:
                    button.isEnabled = false
                    button.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    button.isEnabled = false
                    button.setTitle("Speech recognition restricted on this device", for: .disabled)

                case .notDetermined:
                    button.isEnabled = false
                    button.setTitle("Speech recognition not yet authorized", for: .disabled)

                default:
                    button.isEnabled = false
                }
            }
        }
    }
    
    func startRecording() throws {
        
        // cancel previous task if still running
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        
        // retreive shared audio session object
        let audioSession = AVAudioSession.sharedInstance()
        
        // configures audio session for recording
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        
        // makes it the active session. lets system know that app needs microphone resource
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // current audio input path(microphone)
        let inputNode = audioEngine.inputNode
        
        
        // Create and configure the speech recog request
        
        // class that represents rqeust for spech recog to be performed
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("unable to create SFSpeechAudioBufferRecogRequest object")
        }
        recognitionRequest.shouldReportPartialResults = true
        
        
        // keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
            
            if #available(iOS 17, *) {
                recognitionRequest.customizedLanguageModel = self.lmConfiguration
            }
        }
        
        
        // Create recognition task for session
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            
            var isFinal = false
            
            if let result = result {
                // update text view
                self.onResult?(result.bestTranscription.formattedString)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                // ADD To UI MANAGER
//                self.button.isEnabled = true
//                self.button.setImage(self.earEmpty, for: [])
//                self.button.tintColor = UIColor(.gray)
            }
        }
        
        
        // configure microphone
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // way to access audio data flwoing through the node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            
            //  puts the audio data into recognitionRequestObject
            self.recognitionRequest?.append(buffer)
        }
        
        // allocates resources needed for audio engine to start
        audioEngine.prepare()
        
        // begins to pull audio data in through input node
        try audioEngine.start()
    }
    
    func enableOrDisable(button: UIButton) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            button.isEnabled = false
            button.setImage(earEmpty, for: [])
            button.tintColor = UIColor(.gray)
            
            
        } else {
            do {
                try startRecording()
                button.setImage(earFill, for: [])
                button.tintColor = nil
            } catch {
                button.setImage(earEmpty, for: [])
                button.tintColor = UIColor(.gray)
            }
        }
    }
    
    func stopRecording() {
        // Implementation of stopRecording() method
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {

    }
    
    // Other methods related to speech recognition...
}
