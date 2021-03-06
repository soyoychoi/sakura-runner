//
//  GameScene.swift
//  Sakura Runner
//
//  Created by Justin Angelastro on 11/18/19.
//  Copyright © 2019 NYU. All rights reserved.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    //**********BEGIN GENERAL VARIABLE DECLARATIONS**********//
    var isStarted = Bool(false)
    var isDead = Bool(false)
    var scoreLabel = SKLabelNode()
    let background = SKSpriteNode(imageNamed: "gameBackground")
    let ground = SKSpriteNode(imageNamed: "ground")
    var player: SKSpriteNode?
    var shurikenValsY = [Double]()
    var runningFrames = [SKTexture]()
    var firstJumpingFrames = [SKTexture]()
    var secondJumpingFrames = [SKTexture]()
    var slidingFrames = [SKTexture]()
    var reverseSlideFrames = [SKTexture]()
    var isPoweredUp = false
    var originSize: CGSize?
    var originPoint: CGPoint?
    let gameSpeedDefault = 4.0
    var gameSpeed = 4.0
    var sakuraLabel: SKLabelNode?
    
    let swipedUp = UISwipeGestureRecognizer()
    let swipedDown = UISwipeGestureRecognizer()
    let tappedOnce = UITapGestureRecognizer()
    var rawScore = 0
    var highScore = 0
    var score = Int(0) {
        didSet {
            scoreLabel.text = "\(score)m"
        }
    }
    //**********END GENERAL VARIABLE DECLARATIONS**********//

    struct PhysicsCategory {
        // helper struct for physics collisions
        static let none      : UInt32 = 0
        static let all       : UInt32 = UInt32.max
        static let pointy: UInt32 = 0b10 //spikes and shuriken
        static let sakura: UInt32 = 0b100
        static let player: UInt32 = 0b1000
    }
    
    override func didMove(to view: SKView) {
        // begin the game, but add in all necessary background and helper textures first.
        if isStarted == false {
            isStarted = true
        }
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        //**********BEGIN GESTURE RECOGNIZING DECLARATIONS**********//

        swipedUp.addTarget(self, action: #selector(GameScene.jump))
        swipedUp.direction = .up
        self.view!.addGestureRecognizer(swipedUp)
        
        swipedDown.addTarget(self, action: #selector(GameScene.slide))
        swipedDown.direction = .down
        self.view!.addGestureRecognizer(swipedDown)
        //**********END GESTURE RECOGNIZING DECLARATIONS**********//

        
        //**********BEGIN TEXTURE DECLARATIONS**********//
        let jumpAtlas = SKTextureAtlas(named: "Jumping")
        let jumpImages = jumpAtlas.textureNames.count
        for i in 0...jumpImages-1 {
            if i < 10 {
                let texture = "frame_0\(i)_delay-0.03s.png"
                firstJumpingFrames.append(jumpAtlas.textureNamed(texture))
            } else {
                let texture = "frame_\(i)_delay-0.03s.png"
                secondJumpingFrames.append(jumpAtlas.textureNamed(texture))
            }
        }
        
        let runAtlas = SKTextureAtlas(named: "Running")
        let runImages = runAtlas.textureNames.count
        for i in 0...runImages-1 {
            if i < 10 {
                let texture = "frame_0\(i)_delay-0.03s.png"
                runningFrames.append(runAtlas.textureNamed(texture))
            } else {
                let texture = "frame_\(i)_delay-0.03s.png"
                runningFrames.append(runAtlas.textureNamed(texture))
            }
        }
        
        let slidingAtlas = SKTextureAtlas(named: "Sliding")
        let slidingImages = jumpAtlas.textureNames.count
        for i in 0...slidingImages-1 {
            if i < 10 {
                let texture = "frame_0\(i)_delay-0.03s.png"
                slidingFrames.append(slidingAtlas.textureNamed(texture))
                reverseSlideFrames.append(slidingAtlas.textureNamed(texture))
            } else {
                let texture = "frame_\(i)_delay-0.03s.png"
                slidingFrames.append(slidingAtlas.textureNamed(texture))
            }
        }
        reverseSlideFrames = reverseSlideFrames.reversed()
        //**********END TEXTURE DECLARATIONS**********//
        
        //**********BEGIN GAME AESTHETIC DECLARATIONS**********//
        background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        background.size.height = frame.size.height
        background.size.width = frame.size.width
        background.position = CGPoint(x: frame.midX, y: frame.midY)
        background.zPosition = -2
        addChild(background)
        
        ground.size = CGSize(width: size.width, height: 5*size.height/32)
        ground.position = CGPoint(x: 0, y: -7*size.height/16)
        ground.zPosition = -1
        addChild(ground)
        
        originSize = CGSize(width: size.width/7, height: size.height/3)
        originPoint = CGPoint(x: originSize!.width-size.width/2, y: ground.position.y+ground.size.height+originSize!.height/4)
        
        scoreLabel = SKLabelNode(fontNamed: "Ninja Naruto")
        scoreLabel.text = "0m"
        scoreLabel.fontSize = 30
        scoreLabel.fontColor = SKColor.black
        scoreLabel.zPosition = 5
        scoreLabel.position = CGPoint(x: frame.midX-350, y: frame.midY+150)
        addChild(scoreLabel)
        
        highScore = UserDefaults.standard.object(forKey: "highScore") as? Int ?? 0
        //**********END GAME AESTHETIC DECLARATIONS**********//

        addRunner()
        
        let numPoints = 5
        let doubleH = Double(size.height)*2/3
        let fixed1 = Double(numPoints)
        let fixed2 = doubleH/fixed1
        for index in -numPoints/2+1...numPoints/2 {
                shurikenValsY.append(Double(index)*fixed2)
        }
        
        // the game sequence in its entirety
        run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run(spawnShuriken),
                SKAction.wait(forDuration: randomTime()),
                SKAction.run(spawnSpikes),
                SKAction.wait(forDuration: randomTime()),
                SKAction.run(spawnSakura),
                SKAction.wait(forDuration: TimeInterval(exactly: 0.5)!)
                ])
        ))
        
    }

    //**********BEGIN GENERATE RANDOM NUMBERS**********//
    func randomTime() -> Double {
        return Double.random(in: gameSpeed*2/5...gameSpeed*4/5)
    }
    
    func randomIndicator() -> Int {
        return Int.random(in: 0...1)
        //Key: 0 -> no spikes, 1 -> top spikes, 2 -> bottom spikes, 3 -> both spikes
    }
    
    func randomSakura() -> Int {
        return Int.random(in: 0...5)
    }
    
    func randomShurikenY() -> CGFloat {
        return CGFloat(shurikenValsY[Int.random(in: 0..<shurikenValsY.count)])
    }
    //**********END GENERATE RANDOM NUMBERS**********//
    
    func createSakuraLabel() {
        //create the "Sakura Power" label
        sakuraLabel = SKLabelNode(fontNamed: "Ninja Naruto")
        sakuraLabel?.text = "Sakura Power!"
        sakuraLabel?.fontSize = 64
        sakuraLabel?.fontColor = SKColor.magenta
        sakuraLabel?.zPosition = 5
        sakuraLabel?.position = CGPoint(x: frame.midX, y: frame.midY+frame.size.height/10)
        addChild(sakuraLabel!)
    }
    
    func spawnShuriken() {
        let i = randomIndicator()
        if i == 1 {
            spawnShurikenMain()
        }
    }
    
    func spawnSakura() {
        let i = randomSakura()
        if i == 1 && !isPoweredUp {
            spawnSakuraMain()
        }
    }
    
    func spawnSakuraMain() {
        //method for spawning the sakura flower and moving it across the screen
        if isPoweredUp {return}
        let sakura = SKSpriteNode(imageNamed: "flower")
        
        sakura.size = CGSize(width: size.height/10, height: size.height/10)
        
        let posY = randomShurikenY()
        sakura.position = CGPoint(x: size.width + sakura.size.width/2, y: posY)
        
        sakura.zPosition = 0
        
        sakura.physicsBody = SKPhysicsBody(rectangleOf: sakura.size)
        sakura.physicsBody?.isDynamic = true
        sakura.physicsBody?.categoryBitMask = PhysicsCategory.sakura
        sakura.physicsBody?.contactTestBitMask = PhysicsCategory.player
        sakura.physicsBody?.collisionBitMask = PhysicsCategory.player
        sakura.physicsBody?.usesPreciseCollisionDetection = true
        
        addChild(sakura)
        
        let duration = CGFloat(gameSpeed)
        
        let move = SKAction.move(to: CGPoint(x: -sakura.size.width/2-size.width/2, y: posY),
                                 duration: TimeInterval(duration))
        let remove = SKAction.removeFromParent()
        sakura.run(SKAction.sequence([move, remove]))
        
    }
    
    func spawnShurikenMain() {
        // spawns the shuriken node and moves it across the screen
        if isPoweredUp {return}
        let shur = SKSpriteNode(imageNamed: "shuriken")
        
        shur.size = CGSize(width: size.height/10, height: size.height/10)
        
        let posY = randomShurikenY()
        shur.position = CGPoint(x: size.width + shur.size.width/2, y: posY)
        
        shur.zPosition = 0
        
        shur.physicsBody = SKPhysicsBody(rectangleOf: shur.size)
        shur.physicsBody?.isDynamic = true
        shur.physicsBody?.categoryBitMask = PhysicsCategory.pointy
        shur.physicsBody?.contactTestBitMask = PhysicsCategory.player
        shur.physicsBody?.collisionBitMask = PhysicsCategory.player
        shur.physicsBody?.usesPreciseCollisionDetection = true
        
        addChild(shur)
        
        let duration = CGFloat(gameSpeed)
        
        let spin = SKAction.repeatForever(SKAction.rotate(byAngle: CGFloat(2*Double.pi), duration: 1.0))
        shur.run(spin)
        
        let move = SKAction.move(to: CGPoint(x: -shur.size.width/2-size.width/2, y: posY),
                                 duration: TimeInterval(duration))
        let remove = SKAction.removeFromParent()
        shur.run(SKAction.sequence([move, remove]))
        
    }
    
    func spawnSpikes() {
        // spawns the spike node and animates it across the screen
        if isPoweredUp {return}
        let duration = CGFloat(gameSpeed)
        
        let remove = SKAction.removeFromParent()
        
        let spikeNum = randomIndicator()
        
        if (spikeNum == 1) {
            let topSpike = SKSpriteNode(imageNamed: "free_spikes")
            topSpike.size = CGSize(width: size.width/15, height: size.height/15)
            topSpike.position = CGPoint(x: size.width + topSpike.size.width/2, y: ground.position.y+ground.size.height/2+topSpike.size.height/2)
            topSpike.zPosition = 0
            topSpike.physicsBody = SKPhysicsBody(rectangleOf: topSpike.size)
            topSpike.physicsBody?.isDynamic = true
            topSpike.physicsBody?.categoryBitMask = PhysicsCategory.pointy
            topSpike.physicsBody?.contactTestBitMask = PhysicsCategory.player
            topSpike.physicsBody?.collisionBitMask = PhysicsCategory.player
            topSpike.physicsBody?.usesPreciseCollisionDetection = true
            addChild(topSpike)
            
            let topMove = SKAction.move(to: CGPoint(x: -topSpike.size.width/2-size.width/2, y: topSpike.position.y), duration: TimeInterval(duration))
            topSpike.run(SKAction.sequence([topMove, remove]))
        }
        
    }
    
    func cleanScene() {
        // a clean up method for when the scene transitions
        if let game = self.view?.scene {
            self.children.forEach {
                $0.removeAllActions()
                $0.removeAllChildren()
                $0.removeFromParent()
            }
            game.removeAllActions()
            game.removeAllChildren()
            game.removeFromParent()
        }
    }
    
    override func willMove(from view: SKView) {
        // called when the scene is going to move
        cleanScene()
        self.removeAllChildren()
        self.removeAllActions()
        self.removeFromParent()
    }
    
    func addRunner() {
        //adds the default runner node
        let newPlayer = SKSpriteNode(texture: runningFrames[0])
        newPlayer.size = originSize!
        newPlayer.position = originPoint!
        newPlayer.zPosition = 0
        newPlayer.physicsBody = SKPhysicsBody(rectangleOf: newPlayer.size)
        newPlayer.physicsBody?.isDynamic = false
        newPlayer.physicsBody?.categoryBitMask = PhysicsCategory.player
        //newPlayer.physicsBody?.collisionBitMask = PhysicsCategory.platform
        newPlayer.physicsBody?.contactTestBitMask = PhysicsCategory.pointy
        addChild(newPlayer)
        player?.removeFromParent()
        player = newPlayer
        
        //now to animate
        playRunningAnimation()
    }
    
    func addSakuraPowerRunner() {
        //TODO: Change SKSpriteNode texture
        // adds the sakura power runner
        let newPlayer = SKSpriteNode(texture: runningFrames[0])
        newPlayer.size = CGSize(width: size.width/7, height: size.height/3)
        newPlayer.position = originPoint!
        newPlayer.zPosition = 0
        newPlayer.physicsBody = SKPhysicsBody(rectangleOf: newPlayer.size)
        newPlayer.physicsBody?.isDynamic = false
        newPlayer.physicsBody?.categoryBitMask = PhysicsCategory.none
        //newPlayer.physicsBody?.collisionBitMask = PhysicsCategory.platform
        newPlayer.physicsBody?.contactTestBitMask = PhysicsCategory.pointy
        addChild(newPlayer)
        player?.removeFromParent()
        player = newPlayer
        
        //now to animate
        playSakuraPowerRunningAnimation()
    }
    
    func playRunningAnimation() {
        //master method for playing the default running animation
        player!.removeAllActions()
        player!.run(runningAnimation(), withKey: "runningRunner")
    }
    
    func playSakuraPowerRunningAnimation() {
        // master method for playing the sakura power up animation
        player!.removeAllActions()
        player!.run(sakuraPowerRunningAnimation(), withKey: "sakuraPowerRunner")
    }
    
    func runningAnimation() -> SKAction {
        // the default running animation
        player!.size = CGSize(width: size.width/7, height: size.height/3)
        return SKAction.repeatForever(SKAction.animate(with: runningFrames, timePerFrame: 0.05, resize: false, restore: true))
    }
    
    func sakuraPowerRunningAnimation() -> SKAction {
        //TODO: Replace frames with sakura power frames
        // currently plays the sakura power up running animation
        player!.size = CGSize(width: size.width/7, height: size.height/3)
        let resetStatus = SKAction.run {
            self.isPoweredUp = false
            self.sakuraLabel!.removeAllActions()
            self.sakuraLabel!.removeFromParent()
            self.addRunner()
        }
        let animation = SKAction.repeat(SKAction.animate(with: runningFrames, timePerFrame: 0.02, resize: false, restore: true), count: 25)
        let seq = SKAction.sequence([animation, resetStatus])
        return seq
    }
    
    func addJumper() {
        //add the jumping player and play the animation
        let newPlayer = SKSpriteNode(texture: firstJumpingFrames[9])
        newPlayer.size = player!.size //CGSize(width: size.width/6, height: size.width/6)
        newPlayer.position = player!.position
        newPlayer.zPosition = 0
        let boundingBox = CGSize(width: newPlayer.size.width*2/3, height: newPlayer.size.height*2/3)
        newPlayer.physicsBody = SKPhysicsBody(rectangleOf: boundingBox)
        newPlayer.physicsBody?.isDynamic = false
        newPlayer.physicsBody?.categoryBitMask = PhysicsCategory.player
        //newPlayer.physicsBody?.collisionBitMask = PhysicsCategory.platform
        newPlayer.physicsBody?.contactTestBitMask = PhysicsCategory.pointy
        addChild(newPlayer)
        player!.removeFromParent()
        player = newPlayer
        
        //now to animate
        playJumpingAnimation()
    }
    
    func playJumpingAnimation() {
        // play the entire jumping animation
        let up = SKAction.moveBy(x: 0, y: size.height/2, duration: TimeInterval(exactly: 0.77)!)
        let down = SKAction.moveBy(x: 0, y: -size.height/2, duration: TimeInterval(exactly: 0.77)!)
        let animationUp = SKAction.animate(with: firstJumpingFrames, timePerFrame: 0.07, resize: false, restore: true)
        let animationDown = SKAction.animate(with: secondJumpingFrames, timePerFrame: 0.07, resize: false, restore: true)
        let animatedJumpUp = SKAction.group([up, animationUp])
        let animatedJumpDown = SKAction.group([down, animationDown])
        let totalAction = SKAction.sequence([animatedJumpUp, animatedJumpDown, runningAnimation()])
        player!.removeAllActions()
        player!.run(totalAction)
    }
    
    func addSlider() {
        //add the sliding guy and play the animation
        let newPlayer = SKSpriteNode(texture: slidingFrames[10])
        newPlayer.size = player!.size //CGSize(width: size.height/3, height: size.width/6)
        newPlayer.position = player!.position
        newPlayer.zPosition = 0
        newPlayer.physicsBody = SKPhysicsBody(rectangleOf: newPlayer.size)
        newPlayer.physicsBody?.isDynamic = false
        newPlayer.physicsBody?.categoryBitMask = PhysicsCategory.player
        newPlayer.physicsBody?.contactTestBitMask = PhysicsCategory.pointy
        addChild(newPlayer)
        player!.removeFromParent()
        player = newPlayer
        
        //now to animate
        playSlidingAnimation()
    }
    
    func playSlidingAnimation() {
        // play the entire sliding animation
        let down = SKAction.moveBy(x: 0, y: -player!.size.height/4, duration: TimeInterval(exactly: 1.0)!)
        let up = SKAction.moveBy(x: 0, y: player!.size.height/4, duration: TimeInterval(exactly: 0.5)!)
        //let slide = SKAction.sequence([down, up])
        let animation = SKAction.animate(with: slidingFrames, timePerFrame: 0.05, resize: false, restore: true)
        let animatedSlide = SKAction.group([down, animation])
        let reversedAnim = SKAction.animate(with: reverseSlideFrames, timePerFrame: 0.05, resize: false, restore: true)
        let reversedSlide = SKAction.group([up, reversedAnim])
        let totalAction = SKAction.sequence([animatedSlide, reversedSlide, runningAnimation()])
        player!.removeAllActions()
        player!.run(totalAction)
    }
    
    @objc func jump() {
        print("Jump")
        if abs(player!.position.x - originPoint!.x) < 1
            && abs(player!.position.y - originPoint!.y) < 1 && !isPoweredUp {
            if Sound.isVolumeOn {
                Sound.playJumpSound()
            }
            addJumper()
        }
        
    }
    
    @objc func slide() {
        print("Slide")
        if abs(player!.position.x - originPoint!.x) < 1
            && abs(player!.position.y - originPoint!.y) < 1 && !isPoweredUp {
            if Sound.isVolumeOn {
                Sound.playSlideSound()
            }
            addSlider()
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        if score <= Int(1000) {
            gameSpeed = gameSpeedDefault - Double(score/Int(500))
        } else {
            gameSpeed = 2.0
        }
        if isStarted == true{
            if isDead == false {
                if !isPoweredUp {
                    rawScore = rawScore+1
                } else {
                    rawScore = rawScore+2
                }
                score = Int(rawScore/6)
            }
        }
    }
}

//The below is the necessary collision detection extension for the GameScene
extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        print("CONTACT")
        var bodyHit: SKPhysicsBody
        var otherBody: SKPhysicsBody
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            bodyHit = contact.bodyA
            otherBody = contact.bodyB
        } else {
            bodyHit = contact.bodyB
            otherBody = contact.bodyA
        }
        
        // the player hits a dangerous object
        if ((bodyHit.categoryBitMask & PhysicsCategory.pointy != 0) && (otherBody.categoryBitMask & PhysicsCategory.player != 0)) {
            
            print("HIT POINTY")
            
            player?.removeAllActions()
            player?.removeFromParent()
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "highScore")
            }
            let gameOver = GameOverScene(size: self.size)
            gameOver.score = score
            self.view?.presentScene(gameOver)
        } else if ((bodyHit.categoryBitMask & PhysicsCategory.sakura != 0) && (otherBody.categoryBitMask & PhysicsCategory.player != 0)) {
            //the player has hit a sakura flower power up
            print("HIT SAKURA")
            
            if let sakura = bodyHit.node as? SKSpriteNode {
                sakura.removeFromParent()
            }
            isPoweredUp = true
            createSakuraLabel()
            addSakuraPowerRunner()
        }
    }
}
