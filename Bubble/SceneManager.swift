//
//  SceneManager.swift
//  Bubble
//
//  Created by Vedant Shah on 8/26/24.
//

import SceneKit
import ARKit

class SceneManager: NSObject, ARSCNViewDelegate {
    
    private var originalOrientation: SCNVector3?
    private var textNode = SCNNode()
    
    func setOriginalOrientation(in sceneView: ARSCNView) {
        if let frame = sceneView.session.currentFrame {
            if originalOrientation == nil {
                let mat = SCNMatrix4(frame.camera.transform)
                originalOrientation = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)
            }
        }
    }
    
    func updateText(text: String, in sceneView: ARSCNView) {
        let (direction, _) = getUserVector(in: sceneView)
        let distance: Float = 2.0

        // Calculate position directly based on direction
        let position = SCNVector3(direction.x * distance, 0, direction.z * distance)

        // Create text geometry
        let textGeometry = SCNText(string: insertNewlines(string: text, every: 20), extrusionDepth: 1.0)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.black
        textGeometry.font = UIFont(name: "HelveticaNeue", size: 10) // Change to your desired font and size


        textNode.removeFromParentNode()
        textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)

        // Adjust pivot to the top-right corner
        let (min, max) = textNode.boundingBox
        let textWidth = max.x - min.x
        let textHeight = max.y - min.y
        textNode.pivot = SCNMatrix4MakeTranslation(textWidth / 2, textHeight / 2, 0)
        print("text width: \(textWidth), text height: \(textHeight)")

        // Set the text node's position
        textNode.position = position

        // Add a billboard constraint to make the text node always face the camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        textNode.constraints = [billboardConstraint]

        // Load the speech bubble model
        if let speechBubbleScene = SCNScene(named: "art.scnassets/bubble.scn"),
           let speechBubbleNode = speechBubbleScene.rootNode.childNode(withName: "bubble", recursively: true) {

            // Adjust pivot to the top-right corner for the speech bubble
            let (bubbleMin, bubbleMax) = speechBubbleNode.boundingBox
            let bubbleWidth = (bubbleMax.x - bubbleMin.x) * speechBubbleNode.scale.x
            let bubbleHeight = (bubbleMax.y - bubbleMin.y) * speechBubbleNode.scale.y
            speechBubbleNode.pivot = SCNMatrix4MakeTranslation(bubbleWidth / 2, bubbleHeight / 2, 0)
            
            // width: 1 hello = 25.92; 2 hello = 54.61; 3 hello = 83.3
            // height: 1 line = 8.84, 2 lines = 23.86; 3 lines = 38.86
            
            let yFactor = 8

            // Set the speech bubble's position to match the text node
            speechBubbleNode.position = SCNVector3((Int(textWidth) / 2), -1 * Int((0.5 * textHeight)), 0)
            print("pos: \(speechBubbleNode.position)")

            // Scale the speech bubble to fit the text
            let totalWidth = CGFloat(bubbleMax.x - bubbleMin.x)
            let totalHeight = CGFloat(bubbleMax.y - bubbleMin.y)
            speechBubbleNode.scale = SCNVector3(CGFloat(textWidth + 10) / totalWidth, CGFloat(textHeight + (0.85 * textHeight)) / totalHeight, 0.03)
            
            //print("scale: \(speechBubbleNode.scale.x) \(speechBubbleNode.scale.y)")
            print("width: \(Float(totalWidth) * speechBubbleNode.scale.x); height: \(Float(totalHeight) * speechBubbleNode.scale.y)\n")

            // Change the color of the speech bubble
            if let material = speechBubbleNode.geometry?.firstMaterial {
                material.diffuse.contents = UIColor.white // Change to the desired color
            }

            // Add the speech bubble as a child of the text node
            textNode.addChildNode(speechBubbleNode)
        }

        // Add the text node to the scene
        sceneView.scene.rootNode.addChildNode(textNode)
    }


    
    private func insertNewlines(string: String, every n: Int) -> String {
        var result = ""
        let words = string.split(separator: " ") // Split the string into words
        
        var currentLength = 0
        
        for word in words {
            if currentLength + word.count > n {
                result += "\n"
                currentLength = 0
            } else if !result.isEmpty {
                result += " "
                currentLength += 1
            }
            
            result += word
            currentLength += word.count
        }
        
        return result
    }
    
    private func getUserVector(in sceneView: ARSCNView) -> (SCNVector3, SCNVector3) { // (direction, position)
        if let frame = sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space

            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }

    private func angleBetweenVectors(vectorA: SCNVector3, vectorB: SCNVector3) -> Float {
        let dotProduct = vectorA.x * vectorB.x + vectorA.y * vectorB.y + vectorA.z * vectorB.z
        let magnitudeA = sqrt(vectorA.x * vectorA.x + vectorA.y * vectorA.y + vectorA.z * vectorA.z)
        let magnitudeB = sqrt(vectorB.x * vectorB.x + vectorB.y * vectorB.y + vectorB.z * vectorB.z)
        let cosineAngle = dotProduct / (magnitudeA * magnitudeB)
        return acos(cosineAngle)
    }

    private func crossProduct(vectorA: SCNVector3, vectorB: SCNVector3) -> SCNVector3 {
        let x = vectorA.y * vectorB.z - vectorA.z * vectorB.y
        let y = vectorA.z * vectorB.x - vectorA.x * vectorB.z
        let z = vectorA.x * vectorB.y - vectorA.y * vectorB.x
        return SCNVector3(x, y, z)
    }
    
    // Other methods related to SceneKit and ARKit...
}
