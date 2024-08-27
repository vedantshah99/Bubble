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

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    // MARK: Properties
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var button: UIButton!
    
    let sceneManager = SceneManager()
    
    
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
    
    
    // images
    let earFill = UIImage(systemName: "ear.fill")
    let earEmpty = UIImage(systemName: "ear")
    
    
    var portraitConstraints: [NSLayoutConstraint] = []
    var landscapeConstraints: [NSLayoutConstraint] = []
    
    //var originalOrientation: SCNVector3?
    
    
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
        button.frame = CGRect(x: 141, y: 680, width: 100, height: 100) // Set the button's frame
        button.layer.cornerRadius = 50 // Half of the button's width or height
        button.clipsToBounds = true // This line is needed to make the cornerRadius take effect
        self.button.tintColor = UIColor(.gray)
        
        
        // adjust for autorotate
        button.translatesAutoresizingMaskIntoConstraints = false

        // Set up constraints
        portraitConstraints = [
            button.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
        ]

        landscapeConstraints = [
            button.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
        ]

        button.widthAnchor.constraint(equalToConstant: 100).isActive = true
        button.heightAnchor.constraint(equalToConstant: 100).isActive = true

        updateConstraints()
        
        // Set the view's delegate
        sceneView.delegate = sceneManager
        
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateConstraints()
        })
    }

    func updateConstraints() {
        if UIDevice.current.orientation.isLandscape {
            NSLayoutConstraint.deactivate(portraitConstraints)
            NSLayoutConstraint.activate(landscapeConstraints)
        } else {
            NSLayoutConstraint.deactivate(landscapeConstraints)
            NSLayoutConstraint.activate(portraitConstraints)
        }
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
                self.sceneManager.updateText(text: result.bestTranscription.formattedString, in: self.sceneView)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.button.isEnabled = true
                self.button.setImage(self.earEmpty, for: [])
                self.button.tintColor = UIColor(.gray)
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
    
    // MARK: - SCNSceneRendererDelegate
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        //print(#function, sceneView.session.currentFrame)
        // Set the original orientation
        
        sceneManager.setOriginalOrientation(in: sceneView)
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            button.isEnabled = true
            //button.setImage(earEmpty, for: [])
        } else {
            button.isEnabled = false
            //button.setImage(ear, for: .disabled)
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
    
    
    @IBAction func buttonPressed(_ sender: UIButton) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            button.isEnabled = false
            button.setImage(earEmpty, for: [])
            self.button.tintColor = UIColor(.gray)
            
            
        } else {
            do {
                try startRecording()
                button.setImage(earFill, for: [])
                self.button.tintColor = nil
            } catch {
                button.setImage(earEmpty, for: [])
                self.button.tintColor = UIColor(.gray)
            }
        }
    }
}
