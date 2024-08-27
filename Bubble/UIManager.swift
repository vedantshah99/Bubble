//
//  UIManager.swift
//  Bubble
//
//  Created by Vedant Shah on 8/26/24.
//

import Foundation

import UIKit

class UIManager {
    
    var portraitConstraints: [NSLayoutConstraint] = []
    var landscapeConstraints: [NSLayoutConstraint] = []
    
    var button: UIButton
    
    init(button: UIButton) {
        self.button = button
    }
    
    func setupButtonConstraints(in view: UIView) {
        // Implementation for setting up button constraints
        
        button.isEnabled = false
        button.frame = CGRect(x: 141, y: 680, width: 100, height: 100) // Set the button's frame
        button.layer.cornerRadius = 50 // Half of the button's width or height
        button.clipsToBounds = true // This line is needed to make the cornerRadius take effect
        button.tintColor = UIColor(.gray)
        
        
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
    
    // Other UI related methods...
}
