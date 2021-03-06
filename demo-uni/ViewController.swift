
import UIKit
import ARKit
import UserNotifications
import ZIPFoundation
import SceneKit.ModelIO
import AssetImportKit
import Alamofire



/*
 NOTES someone @Nanxia suggested that this fixed things....
 
 https://github.com/dmsurti/AssimpKit/issues/101
 B4
 public func makeAnimationScenes() {
     for animSceneKey in self.animations.allKeys {
         if let animSceneKey = animSceneKey as? String {
             if let assimpAnim = animations.value(forKey: animSceneKey) as? AssetImporterAnimation {
                 let animScene = SCNScene()
                 animScene.rootNode.addChildNode(skeletonNode.clone())
                 addAnimation(assimpAnimation: assimpAnim,
                              to: animScene)
                 animationScenes.setValue(animScene,
                                          forKey: animSceneKey)
             }
         }
     }
 }
 
 
 AFTER
 public func makeAnimationScenes() {
     for animSceneKey in self.animations.allKeys {
         if let animSceneKey = animSceneKey as? String {
             if let assimpAnim = animations.value(forKey: animSceneKey) as? AssetImporterAnimation {
                 let animScene = SCNScene()
                 animScene.rootNode.addChildNode(skeletonNode.clone())
                 addAnimation(assimpAnimation: assimpAnim,to: self.modelScene!)
                 animationScenes.setValue( self.modelScene!,
                                          forKey: animSceneKey)
             }
         }
     }
 }
 
 */
class ViewController: UIViewController, ARSCNViewDelegate, CAAnimationDelegate {
    
    var settings = AssetImporterAnimSettings()
    var robotNode:SCNNode? = nil
    @IBOutlet weak var addButtonOutlet: UIButton!
    
    
    
//    The gist is: 1. you load the model scene,
//    2. then load the animations (from the scene you just loaded or another scene if they are defined externally)
//    3. and add the animation to the model scene. The above docs referred to use the same scenarios.
    @IBAction func loadFBX() {

        if let pathToObject = Bundle.main.path(forResource: "ely", ofType: "fbx") {
            
            let scaleFactor:Float = 0.0025
            
            do {
                // 1. you load the model scene
                let assimpScene = try SCNScene.assimpScene(filePath: pathToObject, postProcessSteps:[.defaultQuality]) //realtimeFast realtimeQuality realtimeMaxQuality  [.optimizeGraph,
                
                // ( add the model to the scene / scale it down / is this wrong?)
                let modelScene = assimpScene.modelScene!
                modelScene.rootNode.childNodes.forEach {
                    $0.position =   $0.position * scaleFactor
                    $0.scale = $0.scale * scaleFactor
                    sceneView.scene.rootNode.addChildNode($0) // the robot is added - it has a root - below it fails to add animation due to  no root: nil nil
                    self.robotNode = $0
                }
                
                
//                print("skeletonNode:",assimpScene.skeletonNode)
//                print("animations:",assimpScene.animations)
//                print("animationKeys:",assimpScene.animationScenes.allKeys)
                //assimpScene.makeAnimationScenes()
//                for animSceneKey in assimpScene.animations.allKeys {
//                    if let animSceneKey = animSceneKey as? String {
//                        if let assimpAnim = assimpScene.animations.value(forKey: animSceneKey) as? AssetImporterAnimation {
//                            let animScene = SCNScene()
//                            animScene.rootNode.addChildNode(assimpScene.skeletonNode.clone())
//                            assimpScene.addAnimation(assimpAnimation: assimpAnim,to: assimpScene.modelScene!)
//                            assimpScene.animationScenes.setValue( assimpScene.modelScene!,forKey: animSceneKey)
//                        }
//                    }
//                }
//
                // 2. then load the animations
                // either these lines are wrong... OR
                for (_,animScene) in assimpScene.animationScenes{
                    print("animScene:",animScene)
                    if animScene is SCNScene{
                        let animation = assimpScene.animations["ely-1"] as! AssetImporterAnimation
                         print("animation:",animation)
//                        3. and add the animation to the model scene.
//                        assimpScene.modelScene!.rootNode.addAnimationScene(animation, forKey: "ely-1", with: settings) // FAILS
//                        self.robotNode?.parent?.addAnimationScene(animation, forKey: "ely-1", with: settings) // FAILS
//                        self.robotNode?.addAnimationScene(animation, forKey: "ely-1", with: settings) // FAILS
//                        sceneView.scene.rootNode.addAnimationScene(animation, forKey: "ely-1", with: settings) // FAILS
                        
                        // just attempt to hijack view and coerce the animation scene to sceneView.scene
                        sceneView.scene = animScene as! SCNScene // FAILS
                        
                    }
                    
                }

                sceneView.isPlaying = true
                sceneView.showsStatistics = true
                
            }catch let error{
                print("error:",error)
            }
        }
    }
    
    
    @IBOutlet weak var unzipOutlet: UIButton!{
        didSet {
            unzipOutlet.isHidden = true
            
        }
    }
    ////////
    
    
    enum CatalogState {
        case expanded
        case collapsed
    }
    
    var catalogViewController: CatalogViewController!
    
    
    var catalogHeight:CGFloat!
    let catalogHandleAreaHeight:CGFloat = 65
    
    
    
    var catalogVisible = false
    var nextState:CatalogState {
        return catalogVisible ? .collapsed : .expanded
    }
    
    var runningAnimations = [UIViewPropertyAnimator]()
    var animationProgressWhenInterrupted:CGFloat = 0
    
    var isWallTapped = false
    
    @IBAction func doneScene(_ sender: Any) {
        if(isWallTapped) {
            catalogViewController.view.frame = CGRect(x: 0, y: self.view.frame.height - catalogHandleAreaHeight, width: self.view.bounds.width, height: catalogHeight)
            
        }
        else
        {
            wallChainsSet.addChainSet()
            isWallTapped = true
        }
    }
    
    
    
    
    
    @IBOutlet weak var sceneView: ARSCNView!
    
    lazy var interactions = ARInteractions(sceneView: sceneView)
    lazy var wallChainsSet = WallChainsSet(sceneView: sceneView)
    var buildingInProgress = true
    var planeAnchore:ARPlaneAnchor!
    var isPlaneDetected = false
    
    
    /////////////////DOWNLOAD
    private var alert: UIAlertController!
    private let dataProvider = DataProvider()
    private var filePath: String?
    private var fileSavePath: URL?
    
    
    @IBAction func downloadTap(_ sender: UIButton) {
        showAlert()
        dataProvider.startDownload()
    }
    
    ////////////////
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        catalogHeight = self.view.frame.height * 0.85
        //setupCatalog()
        //        setupConstraintButton()
        let configuration = ARWorldTrackingConfiguration();
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration);
        self.sceneView.autoenablesDefaultLighting = true
        sceneView.delegate = self
        
        // Settings taken from https://assimpkit.readthedocs.io/en/latest/user/tutorial.html#load-skeletal-animations
        settings.delegate = self
        settings.repeatCount = 60
        let eventBlock: SCNAnimationEventBlock = { animation, animatedObject, playingBackwards in
            print("Animation Event triggered")
        }
        
        let animEvent = SCNAnimationEvent.init(keyTime: 0.9, block: eventBlock)
        let animEvents = [animEvent]
        settings.animationEvents = animEvents
        
        
        
        
    }
    
    @IBAction func plusButton(_ sender: Any) {
        //  catalogViewController.view.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
//         wallChainsSet.addPointer()
        isWallTapped = false
        loadFBX()
    }
    
    @IBAction func continueButton(_ sender: Any) {
       // wallChainsSet.addChainSet()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        interactions.trackObject(node: wallChainsSet.curentPointer)
    }
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if(!isPlaneDetected) {
            guard anchor is ARPlaneAnchor else {return}
            interactions.planeAnchor = (anchor as! ARPlaneAnchor)
            isPlaneDetected = true
            wallChainsSet.addPointer()
        }
    }
    
    
    
    
    func setupCatalog() {

        
        catalogViewController = CatalogViewController(nibName:"CatalogViewController", bundle:nil)
        catalogViewController.onSelectFurniture = { furniture in
            self.selectFurniture(furniture: furniture)
        }
        catalogViewController.onSelectTexture = { texture in
            self.selectTexture(texture: texture)
        }
        
        self.addChild(catalogViewController)
        self.view.addSubview(catalogViewController.view)
        
        catalogViewController.view.frame = CGRect(x: 0, y: self.view.frame.height - catalogHandleAreaHeight, width: self.view.bounds.width, height: catalogHeight)

        
        self.catalogViewController.view.layer.cornerRadius = 12
        catalogViewController.view.clipsToBounds = true
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleCardTap))
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleCardPan))
        
        catalogViewController.handleArea.addGestureRecognizer(tapGestureRecognizer)
        catalogViewController.handleArea.addGestureRecognizer(panGestureRecognizer)
        
        
    }
    private func selectTexture(texture: CardModel) {
        wallChainsSet.textureWalls(textureLength: 1, textureWidth: 1, textureImage: UIImage(named: texture.modelPath))
    }
    private func selectFurniture(furniture: CardModel) {
        
        let hitTest = sceneView!.hitTest(sceneView.center, types: .existingPlane)
        let result = hitTest.last
        guard let transform = result?.worldTransform else {return}
        let thirdColumn = transform.columns.3
        
        let sofaScene = SCNScene(named: furniture.modelPath)
        let furnitureNode = Furniture()
        furnitureNode.position = SCNVector3(thirdColumn.x, thirdColumn.y, thirdColumn.z)
        furnitureNode.name = furniture.cardName
        sofaScene?.rootNode.childNodes.forEach{
            $0.scale = $0.scale * 0.001
            $0.position = $0.position * 0.001
            furnitureNode.addChildNode($0)
        }
        print("place")
        self.sceneView.scene.rootNode.addChildNode(furnitureNode)
    }
    
    @objc
    func handleCardTap(recognzier:UITapGestureRecognizer) {
        switch recognzier.state {
        case .ended:
            animateTransitionIfNeeded(state: nextState, duration: 0.9)
        default:
            break
        }
    }
    
    @objc
    func handleCardPan (recognizer:UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            startInteractiveTransition(state: nextState, duration: 0.9)
        case .changed:
            let translation = recognizer.translation(in: self.catalogViewController.handleArea)
            var fractionComplete = translation.y / catalogHeight
            fractionComplete = catalogVisible ? fractionComplete : -fractionComplete
            updateInteractiveTransition(fractionCompleted: fractionComplete)
        case .ended:
            continueInteractiveTransition()
        default:
            break
        }
    }
    
    func animateTransitionIfNeeded (state: CatalogState, duration:TimeInterval) {
        if runningAnimations.isEmpty {
            let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
                switch state {
                case .expanded:
                    self.catalogViewController.view.frame.origin.y = self.view.frame.height - self.catalogHeight
                case .collapsed:
                    self.catalogViewController.view.frame.origin.y = self.view.frame.height - self.catalogHandleAreaHeight
                }
            }
            
            frameAnimator.addCompletion { _ in
                self.catalogVisible = !self.catalogVisible
                self.runningAnimations.removeAll()
            }
            
            frameAnimator.startAnimation()
            runningAnimations.append(frameAnimator)
            
            
            let cornerRadiusAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear) {
                switch state {
                case .expanded:
                    self.catalogViewController.view.layer.cornerRadius = 12
                case .collapsed:
                    self.catalogViewController.view.layer.cornerRadius = 12
                }
            }
            
            cornerRadiusAnimator.startAnimation()
            runningAnimations.append(cornerRadiusAnimator)
            
            
        }
    }
    
    func startInteractiveTransition(state: CatalogState, duration:TimeInterval) {
        if runningAnimations.isEmpty {
            animateTransitionIfNeeded(state: state, duration: duration)
        }
        for animator in runningAnimations {
            animator.pauseAnimation()
            animationProgressWhenInterrupted = animator.fractionComplete
        }
    }
    
    func updateInteractiveTransition(fractionCompleted:CGFloat) {
        for animator in runningAnimations {
            animator.fractionComplete = fractionCompleted + animationProgressWhenInterrupted
        }
    }
    
    func continueInteractiveTransition (){
        for animator in runningAnimations {
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
        }
    }
    
    
    //    button custom
    
    func setupConstraintButton() {
        
        print("setupConstraintButton")
        
        //        huemouo
        //        addButtonOutlet.translatesAutoresizingMaskIntoConstraints = false
        //        addButtonOutlet.centerXAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        //        addButtonOutlet.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        //        addButtonOutlet.widthAnchor.constraint(equalToConstant: 100).isActive = true
        //        addButtonOutlet.heightAnchor.constraint(equalToConstant: 100).isActive = true
    }
    /////////DOWNLOAD
    private func unzipFile() {
        
        let fileManager = FileManager()
        
        var separatorPath = filePath!.components(separatedBy: "/")
        let directoryName = separatorPath[separatorPath.count - 1].components(separatedBy: ".")[0]
        let fileName = separatorPath[separatorPath.count - 1]
        separatorPath.remove(at: separatorPath.count - 1)
        
        let currentWorkingPath = String(separatorPath.joined(separator: "/"))
        
        
        var sourceURL = URL(fileURLWithPath: currentWorkingPath)
        sourceURL.appendPathComponent(fileName)
        
        var destinationURL = URL(fileURLWithPath: currentWorkingPath)
        destinationURL.appendPathComponent(directoryName)
        
        
        do {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            try fileManager.unzipItem(at: sourceURL, to: destinationURL)
            
            self.postNotification(path: destinationURL.absoluteString, fileName: fileName)
            self.fileSavePath = destinationURL
            
        } catch {
            print("Extraction of ZIP archive failed with error:\(error.localizedDescription)")
        }
        
        
    }
    
    private func showAlert() {
        
        alert = UIAlertController(title: "Downloading...", message: "0%", preferredStyle: .alert)
        
        let height = NSLayoutConstraint(item: alert.view,
                                        attribute: .height,
                                        relatedBy: .equal,
                                        toItem: nil,
                                        attribute: .notAnAttribute,
                                        multiplier: 0,
                                        constant: 170)
        
        alert.view.addConstraint(height)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .destructive) { (action) in
            
            self.dataProvider.stopDownload()
        }
        
        alert.addAction(cancelAction)
        present(alert, animated: true) {
            
            let size = CGSize(width: 40, height: 40)
            let point = CGPoint(x: self.alert.view.frame.width / 2 - size.width / 2,
                                y: self.alert.view.frame.height / 2 - size.height / 2)
            
            let activityIndicator = UIActivityIndicatorView(frame: CGRect(origin: point, size: size))
            activityIndicator.color = .gray
            activityIndicator.startAnimating()
            
            let progressView = UIProgressView(frame: CGRect(x: 0,
                                                            y: self.alert.view.frame.height - 44,
                                                            width: self.alert.view.frame.width,
                                                            height: 2))
            progressView.tintColor = .blue
            
            self.dataProvider.onProgress = { (progress) in
                
                progressView.progress = Float(progress)
                self.alert.message = String(Int(progress * 100)) + "%"
            }
            
            self.alert.view.addSubview(activityIndicator)
            self.alert.view.addSubview(progressView)
        }
    }
    
    
}

//////////DOWNLOAD


extension ViewController {
    
    private func registerForNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (_, _) in
            
        }
    }
    
    private func postNotification() {
        
        let content = UNMutableNotificationContent()
        content.title = "Download complete!"
        content.body = "Your background transfer has completed. File path: \(filePath!)"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        
        let request = UNNotificationRequest(identifier: "TransferComplete", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    private func postNotification(path: String, fileName: String) {
        
        let content = UNMutableNotificationContent()
        content.title = "Unzip complete!"
        content.body = "Unzip file \(fileName). Files path: \(path)"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        
        let request = UNNotificationRequest(identifier: "TransferComplete", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

