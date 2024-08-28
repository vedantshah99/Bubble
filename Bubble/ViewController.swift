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

class ViewController: UIViewController {
    
    // MARK: Properties
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var button: UIButton!
    
    let sceneManager = SceneManager()
    let speechRecognitionManager = SpeechRecognitionManager()
    var uiManager: UIManager?
    
    var textNode = SCNNode()
    var timer: Timer?
    
    
    //var originalOrientation: SCNVector3?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        
        speechRecognitionManager.onResult = { [weak self] text in
            self?.sceneManager.updateText(text: text, in: self!.sceneView)
        }
        let uiManager = UIManager(button: button)
        // Set the view's delegate
        sceneView.delegate = sceneManager
        
        uiManager.setupButtonConstraints(in: sceneView)
        uiManager.updateConstraints()
        
        
        
        
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.uiManager?.updateConstraints()
        })
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //speechRecognizer.delegate = speechRecognitionManager
        speechRecognitionManager.requestSpeechAuthorization(button: button)
        
    }
    

    
    // MARK: - SCNSceneRendererDelegate
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        //print(#function, sceneView.session.currentFrame)
        // Set the original orientation
        
        sceneManager.setOriginalOrientation(in: sceneView)
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
        speechRecognitionManager.enableOrDisable(button: button)
    }
}
