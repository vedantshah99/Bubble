//
//  ViewController.swift
//  Bubble
//
//  Created by Vedant Shah on 8/19/24.
//

import UIKit
import SceneKit
import ARKit
import Speech

class ViewController: UIViewController, ARSCNViewDelegate, SFSpeechRecognizerDelegate {
    
    // MARK: Properties
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var button: UIButton!
    
    var textNode = SCNNode()
    var timer: Timer?
    
    // class that provides speech recognition services. responcible for performign the speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    // used to pass audio data inro speech recogniation object
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    // speech recognition session
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // used to retreive microphone input
    private let audioEngine = AVAudioEngine()
    
    
    // MARK: Custom LM Support
    @available(iOS 17, *)
    private var lmConfiguration: SFSpeechLanguageModel.Configuration {
        let outputDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dynamicLanguageModel = outputDir.appendingPathComponent("LM")
        let dynamicVocabulary = outputDir.appendingPathComponent("Vocab")
        
        return SFSpeechLanguageModel.Configuration(languageModel: dynamicLanguageModel, vocabulary: dynamicVocabulary)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        button.isEnabled = false
        
        // Set the view's delegate
        sceneView.delegate = self
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        speechRecognizer.delegate = self
        
        
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
                            
                            await MainActor.run { self.button.isEnabled = true}
                        }
                    } else {
                        self.button.isEnabled = false
                    }
                case .denied:
                    self.button.isEnabled = false
                    self.button.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.button.isEnabled = false
                    self.button.setTitle("Speech recognition restricted on this device", for: .disabled)

                case .notDetermined:
                    self.button.isEnabled = false
                    self.button.setTitle("Speech recognition not yet authorized", for: .disabled)

                default:
                    self.button.isEnabled = false
                }
            }
        }
    }
    
    private func startRecording() throws {
        
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
                self.updateText(text: result.bestTranscription.formattedString, atPosition: SCNVector3(0, 0, -1))
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.button.isEnabled = true
                self.button.setTitle("StartRecording", for: [])
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
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            button.isEnabled = true
            button.setTitle("start recording", for: [])
        } else {
            button.isEnabled = false
            button.setTitle("recognition not available", for: .disabled)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func updateText(text: String, atPosition position: SCNVector3) {
        let textGeometry = SCNText(string: text, extrusionDepth: 1.0)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.red

        textNode.removeFromParentNode()

        textNode = SCNNode(geometry: textGeometry)
        textNode.position = SCNVector3(position.x, position.y + 0.01, position.z)
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)

        // Create a box that will act as a background for the text
        let (min, max) = textNode.boundingBox
        
        let boxWidth = CGFloat(max.x - min.x) + 5
        let boxHeight = CGFloat(max.y - min.y) + 3
        let box = SCNBox(width: boxWidth, height: boxHeight, length: CGFloat(max.z - min.z), chamferRadius: 0.0)
        box.firstMaterial?.diffuse.contents = UIColor.white
        
        print(boxHeight * 0.45)

        // Create a node for the box and position it behind the text
        let boxNode = SCNNode(geometry: box)
        boxNode.position = SCNVector3(CGFloat(textNode.position.x) + (boxWidth * 0.45) , CGFloat(textNode.position.y) + 6.3, -0.01) // Adjust the z-position to move the box behind the text

        // Add the box node as a child of the text node
        textNode.addChildNode(boxNode)

        sceneView.scene.rootNode.addChildNode(textNode)
    }
    
    @IBAction func buttonPressed(_ sender: UIButton) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            button.isEnabled = false
            button.setTitle("stopping", for: .disabled)
            
        } else {
            do {
                try startRecording()
                button.setTitle("stop recording", for: [])
            } catch {
                button.setTitle("not available", for: [])
            }
        }
    }
}
