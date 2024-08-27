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
        textGeometry.firstMaterial?.diffuse.contents = UIColor.red

        textNode.removeFromParentNode()
        textNode = SCNNode(geometry: textGeometry)
        textNode.position = position
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)

        // Add a billboard constraint to make the text node always face the camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        textNode.constraints = [billboardConstraint]

        // Adjust bounding box and add background box node
        let (min, max) = textNode.boundingBox
        let boxWidth = CGFloat(max.x - min.x) + 5
        let boxHeight = CGFloat(max.y - min.y) + 3
        let box = SCNBox(width: boxWidth, height: boxHeight, length: CGFloat(max.z - min.z), chamferRadius: 0.0)
        box.firstMaterial?.diffuse.contents = UIColor.white

        let boxNode = SCNNode(geometry: box)
        boxNode.position = SCNVector3(0, 0, -0.01)
        textNode.addChildNode(boxNode)

        sceneView.scene.rootNode.addChildNode(textNode)
    }

    
    private func insertNewlines(string: String, every n: Int) -> String {
        var result = ""
        let characters = Array(string)
        for i in 0..<characters.count {
            if i % n == 0 && i != 0 {
                result += "\n"
            }
            result.append(characters[i])
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
