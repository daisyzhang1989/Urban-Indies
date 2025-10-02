import SpriteKit
import AVFoundation
import UIKit

// MARK: - Note sprite
final class NoteNode: SKSpriteNode {
    enum NoteKind { case main, alt }   // main = PuffBoyNote, alt = PuffBoyNote1

    let time: Double
    let kind: NoteKind

    init(time: Double, textureName: String) {
        self.time = time
        self.kind = (textureName == "PuffBoyNote1") ? .alt : .main
        let tex = SKTexture(imageNamed: textureName)
        super.init(texture: tex, color: .clear, size: tex.size())

        let baseScale: CGFloat = (textureName == "PuffBoyNote1") ? 0.23 : 0.50
        setScale(baseScale)

        zPosition = 10
        xScale = -abs(xScale)

        // 悬浮动画
        let up = SKAction.moveBy(x: 0, y: 6, duration: 0.18)
        up.timingMode = .easeInEaseOut
        run(.repeatForever(.sequence([up, up.reversed()])))
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Beat generator
fileprivate func generateBeatTimes(
    bpm: Double, bars: Int, beatsPerBar: Int = 4,
    subdivision: Int = 1, pattern: Set<Int> = [], offset: Double = 0.0
) -> [Double] {
    let secPerBeat = 60.0 / bpm
    let totalSub = bars * beatsPerBar * subdivision
    return (0..<totalSub).compactMap {
        pattern.isEmpty || pattern.contains($0 % subdivision)
        ? Double($0) * (secPerBeat / Double(subdivision)) + offset
        : nil
    }
}

// MARK: - GameScene
final class GameScene: SKScene {

    // --- Character ---
    private var character: SKSpriteNode!
    private var idleTexture: SKTexture!
    private var hitTextureMain: SKTexture!   // Gorilla
    private var hitTextureAlt: SKTexture!    // Gorilla1
    private var characterSize: CGSize!
    private var characterSizeAlt: CGSize!    // Gorilla1 专用尺寸
    private var characterOffsetAltY: CGFloat = 80  // ✅ Gorilla1 垂直偏移量（可自由调整）

    // --- Background ---
    private var backgrounds: [SKSpriteNode] = []
    private var backgroundSpeed: CGFloat = 0.0
    private let repeatBGNames = ["AlleyBG1", "AlleyBG2"]
    private var repeatIndex = 0

    // --- Layout / Motion ---
    private var laneY: CGFloat { size.height * 0.5 }
    private var ppsX: CGFloat = 260
    private let hitThresholdX: CGFloat = 120

    // --- Timing ---
    private var lastUpdateTime: TimeInterval = 0
    private var startTime: TimeInterval = 0
    private let startDelay: Double = 0.6
    private let introFreeze: Double = 4.0
    private var isRunningPhase = false

    // --- Notes ---
    private var notes: [Double] = []
    private var alive: [NoteNode] = []
    private var spawnedTimes = Set<Double>()
    private var noteSpawnCount: Int = 0
    private let groupSize: Int = 3

    // --- Audio ---
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    // --- Close button ---
    private let closeButton = SKLabelNode(text: "×")

    // MARK: - didMove
    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupScrollingBackground()

        // 角色
        idleTexture = SKTexture(imageNamed: "GuitarKidIdle")
        hitTextureMain = SKTexture(imageNamed: "Gorilla")
        hitTextureAlt  = SKTexture(imageNamed: "Gorilla1")

        character = SKSpriteNode(texture: idleTexture)
        character.size = CGSize(width: 170, height: 130)
        characterSize = character.size
        characterSizeAlt = CGSize(width: 170, height: 280)  // ✅ Gorilla1 专用尺寸

        character.position = CGPoint(x: size.width * 0.5 - 270, y: laneY - 50)
        addChild(character)

        // 关闭按钮
        setupCloseButton()

        // 音频
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("Audio error:", error) }

        setupMusicAndNotes()

        // 延迟启动
        startTime = CACurrentMediaTime() + startDelay + introFreeze
        run(.sequence([
            .wait(forDuration: introFreeze),
            .run { [weak self] in self?.beginRunningPhase() }
        ]))
    }

    // MARK: - 右上角 X 按钮
    private func setupCloseButton() {
        closeButton.fontName = "Avenir-Heavy"
        closeButton.fontSize = 36
        closeButton.fontColor = .white
        closeButton.zPosition = 999
        closeButton.horizontalAlignmentMode = .right
        closeButton.verticalAlignmentMode = .top
        layoutCloseButton()
        addChild(closeButton)
    }

    private func layoutCloseButton() {
        let inset = view?.safeAreaInsets ?? .zero
        let marginX: CGFloat = 10
        let marginY: CGFloat = 10
        let x = size.width - marginX - inset.right
        let y = size.height - marginY - inset.top
        closeButton.position = CGPoint(x: x, y: y)
    }

    // MARK: - 开始背景滚动
    private func beginRunningPhase() {
        isRunningPhase = true
        backgroundSpeed = 140
    }

    // MARK: - 背景初始化
    private func setupScrollingBackground() {
        let names = ["AlleyBG", "AlleyBG1", "AlleyBG2"]
        backgrounds.removeAll()
        var x: CGFloat = 0
        for name in names {
            let bg = SKSpriteNode(texture: SKTexture(imageNamed: name))
            bg.zPosition = -100
            bg.anchorPoint = CGPoint(x: 0, y: 0)
            applyFillScale(to: bg)
            bg.position = CGPoint(x: x, y: 0)
            addChild(bg)
            backgrounds.append(bg)
            x += bg.size.width * bg.xScale
        }
    }

    @discardableResult
    private func applyFillScale(to node: SKSpriteNode) -> CGFloat {
        guard let tex = node.texture else { return 0 }
        let sx = size.width / tex.size().width
        let sy = size.height / tex.size().height
        let s = max(sx, sy)
        node.xScale = s
        node.yScale = s
        return tex.size().width * s
    }

    // MARK: - 背景滚动
    private func scrollBackground(deltaTime: TimeInterval) {
        guard backgroundSpeed > 0 else { return }
        let dx = backgroundSpeed * CGFloat(deltaTime)
        for bg in backgrounds { bg.position.x -= dx }
        for bg in backgrounds {
            let widthInScene = bg.size.width * bg.xScale
            if bg.position.x <= -widthInScene {
                let nextName = repeatBGNames[repeatIndex % repeatBGNames.count]
                repeatIndex += 1
                bg.texture = SKTexture(imageNamed: nextName)
                _ = applyFillScale(to: bg)
                if let rightmost = backgrounds.max(by: { $0.position.x < $1.position.x }) {
                    let rightWidth = rightmost.size.width * rightmost.xScale
                    bg.position.x = rightmost.position.x + rightWidth
                }
            }
        }
    }

    // MARK: - 音乐 + 节拍（前10秒BPM=70，之后BPM=120）
    private func setupMusicAndNotes() {
        let bpmPhase1 = 70.0
        let bpmPhase2 = 120.0
        let phaseChangeTime = 10.0   // 秒

        // 生成节拍
        let notesPhase1 = generateBeatTimes(bpm: bpmPhase1, bars: 4)
        let notesPhase2 = generateBeatTimes(bpm: bpmPhase2, bars: 12, offset: phaseChangeTime)
        notes = notesPhase1 + notesPhase2

        guard let url = Bundle.main.url(forResource: "Cloudy", withExtension: "mp3") else {
            print("❌ No audio file.")
            return
        }

        engine.attach(player)
        do {
            let file = try AVAudioFile(forReading: url)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            try engine.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + introFreeze) {
                self.player.scheduleFile(file, at: nil, completionHandler: nil)
                self.player.play()
                print("▶️ Audio started:", url.lastPathComponent)
            }
        } catch {
            print("❌ Audio error:", error)
        }
    }

    // MARK: - 更新循环
    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        if isRunningPhase { scrollBackground(deltaTime: dt) }

        let t = CACurrentMediaTime() - startTime
        if abs(t - 10.0) < 0.05 { print("🎵 BPM switched from 70 → 120") }

        let targetX = character.position.x
        let lead: Double = 2.4

        for s in notes where !spawnedTimes.contains(s) {
            if s >= t - 0.2, s <= t + lead {
                let groupIndex = (noteSpawnCount / groupSize) % 2
                let textureName = (groupIndex == 0) ? "PuffBoyNote" : "PuffBoyNote1"
                let n = NoteNode(time: s, textureName: textureName)

                let dtSpawn = s - t
                let baseY = laneY - 55
                let yOffset: CGFloat = (textureName == "PuffBoyNote1") ? 120 : 0
                n.position = CGPoint(x: targetX + CGFloat(dtSpawn) * ppsX, y: baseY + yOffset)

                addChild(n)
                alive.append(n)
                spawnedTimes.insert(s)
                noteSpawnCount += 1
            }
        }

        for n in alive {
            let dtMove = n.time - t
            n.position.x = targetX + CGFloat(dtMove) * ppsX
            if n.position.x < -60 { n.removeFromParent() }
        }
        alive.removeAll { $0.parent == nil }
    }

    // MARK: - 打击逻辑 + 关闭按钮
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if closeButton.contains(loc) {
            presentQuitAlert()
            return
        }

        guard let best = alive.enumerated().min(by: {
            abs($0.element.position.x - character.position.x)
            < abs($1.element.position.x - character.position.x)
        }) else { return }

        let (idx, note) = best
        let dx = abs(note.position.x - character.position.x)
        if dx <= hitThresholdX {
            _ = alive.remove(at: idx)

            character.removeAction(forKey: "swing")
            let toSwing = SKAction.run {
                if note.kind == .alt {
                    self.character.texture = self.hitTextureAlt
                    self.character.size = self.characterSizeAlt
                    self.character.position.y = self.laneY - 50 + self.characterOffsetAltY
                } else {
                    self.character.texture = self.hitTextureMain
                    self.character.size = self.characterSize
                    self.character.position.y = self.laneY - 50
                }
            }
            let wait = SKAction.wait(forDuration: 0.15)
            let backToIdle = SKAction.run {
                self.character.texture = self.idleTexture
                self.character.size = self.characterSize
                self.character.position.y = self.laneY - 50
            }
            let rotateFwd = SKAction.rotate(byAngle: .pi / 18, duration: 0.08)
            let rotateBack = SKAction.rotate(toAngle: 0, duration: 0.08)
            character.run(.sequence([toSwing, rotateFwd, wait, rotateBack, backToIdle]), withKey: "swing")

            let hop1 = SKAction.moveBy(x: 140, y: 60, duration: 0.18)
            hop1.timingMode = .easeOut
            let hop2 = SKAction.moveBy(x: 220, y: 30, duration: 0.25)
            hop2.timingMode = .easeIn
            let fadeOut = SKAction.fadeOut(withDuration: 0.25)
            note.run(.sequence([.group([hop1]), .group([hop2, fadeOut]), .removeFromParent()]))
        }
    }

    private func presentQuitAlert() {
        guard let view = self.view, let vc = view.window?.rootViewController else { return }
        let alert = UIAlertController(
            title: "終了しますか？",
            message: "アプリを終了します。よろしいですか？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "はい", style: .destructive, handler: { _ in
            self.quitApplication()
        }))
        vc.present(alert, animated: true)
    }

    private func quitApplication() {
        player.stop()
        engine.stop()
        engine.reset()
        do { try AVAudioSession.sharedInstance().setActive(false) } catch { }
        isPaused = true
        isUserInteractionEnabled = false
        view?.isPaused = true
        #if DEBUG
        exit(0)
        #endif
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard !backgrounds.isEmpty else { return }
        var x: CGFloat = 0
        for bg in backgrounds {
            applyFillScale(to: bg)
            bg.position = CGPoint(x: x, y: 0)
            x += bg.size.width * bg.xScale
        }
        layoutCloseButton()
    }
}
