//
//  ContentView.swift
//  BonBonBan
//
//  Created by Zhang Mengyao on 2025/10/02.
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    var scene: SKScene {
        let s = GameScene(size: CGSize(width: 390, height: 844)) 
        s.scaleMode = .resizeFill
        return s
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
