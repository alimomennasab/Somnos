// UI
//      Light & face status tracking/notification (only need ui)
//      Confirmation of sound selection
//      Create animation for camera screen (low priority)
//Functionality
//      fix broken sounds (apex, default)
//      App runs in background
//      Fine tune values

import UIKit
import SideMenu
import SceneKit
import ARKit
import AVFoundation
import AudioToolbox

//MARK: Sound
public var selectedSound = "bleep"
public var player: AVAudioPlayer?

public func playSound() {
    guard let url = Bundle.main.url(forResource: selectedSound, withExtension: "mp3") else { return }
    
    do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        
        player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
        
        guard let player = player else { return }
        player.numberOfLoops = 1
        player.setVolume(85, fadeDuration: 1)
        
        player.play()
        
    } catch let error {
        print(error.localizedDescription)
    }
}

class ViewController: UIViewController, ARSCNViewDelegate, MenuListControllerDelegate {
    var recOn = false
    //menu variables
    var menu: SideMenuNavigationController?
    let changeRingtoneViewController = ChangeRingtoneViewController()
    let aboutViewController = AboutViewController()
    @IBOutlet weak var barButton: UIBarButtonItem!
    
    //declaring view & variables
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var driveStartButton: UIButton!
    @IBOutlet weak var youHaveBeenDrivingForLabel: UILabel!
    
   
    //DEBUGGERS
    @IBOutlet weak var testLabel: UILabel!
    
    
    
    //warning variables
    @IBOutlet weak var centerWarningImage: UIImageView!
    
    //blink detection variables
    var timestamp = NSDate().timeIntervalSince1970
    var queue: [Double] = []
    var TSCollection:[Double] = []
    var blink = false
    var acct: Float = 0.0
    
    //light status variables
    var light = true
    var onCooldown = false
    var blind = false
    
    //timer variables
    @IBOutlet weak var timerLabel: UILabel!
    var timer = Timer()
    var count = 0
    var timerCounting = false
    var timer1On = false
    var timer1: Float = 0.0
    var repCD = false
    
    private func addChildControllers() {
        addChild(changeRingtoneViewController)
        addChild(aboutViewController)
        
        view.addSubview(changeRingtoneViewController.view)
        view.addSubview(aboutViewController.view)
        
        changeRingtoneViewController.view.frame = view.bounds
        aboutViewController.view.frame = view.bounds
        
        changeRingtoneViewController.didMove(toParent: self)
        aboutViewController.didMove(toParent: self)
        
        changeRingtoneViewController.view.isHidden = true
        aboutViewController.view.isHidden = true
    }
    
    // MARK: UI Actions
    
    func didReposition (){
        
    }
    
    @IBAction func didTapMenu(){
        present(menu!, animated: true)
    }
    
    func didSelectItem(named: String) {
        menu?.dismiss(animated: true, completion: {
            
            self.title = named
            
            if named == "Home"{
                self.changeRingtoneViewController.view.isHidden = true
                self.aboutViewController.view.isHidden = true
                
            }else if named == "Change Ringtone" {
                self.changeRingtoneViewController.view.isHidden = false
                self.aboutViewController.view.isHidden = true
                
            } else if named == "About Somnos" {
                self.aboutViewController.view.isHidden = false
                self.changeRingtoneViewController.view.isHidden = true
            }
            
        })
        
    }
    
    @IBAction func driveButtonTapped(_ sender: Any) {
        if(timerCounting)
        {
            timerLabel.isHidden = true
            youHaveBeenDrivingForLabel.isHidden = true
            timerLabel.text = "00 : 00 : 00"
            timerCounting = false
            timer.invalidate()
            //count = 0
            driveStartButton.setTitle("START", for: .normal)
           
            let x1 = ((60 * Double(TSCollection.count) / TSCollection.sum()))
            //let x2 = String(x1 / (Double(self.count) / 60.0))
            self.testLabel.text = String(x1)
            
        }
        else
        {
            count = 0
            TSCollection = []
            timerLabel.isHidden = false
            youHaveBeenDrivingForLabel.isHidden = false
            timerCounting = true
            driveStartButton.setTitle("STOP", for: .normal)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                self.updateTimer()
            })
            
        }
    }
    
    //MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        sceneView.delegate = self
        guard ARFaceTrackingConfiguration.isSupported else {
            fatalError("Face tracking is not supported on this device.")
            
        }
        
        testLabel.isHidden = true
        
        timerLabel.text = "00 : 00 : 00"
        timerLabel.isHidden = true
        
        youHaveBeenDrivingForLabel.isHidden = true
        
        driveStartButton.layer.cornerRadius = 50
        driveStartButton.layer.masksToBounds = true
        driveStartButton.clipsToBounds = true
        
        centerWarningImage.isHidden = true
        centerWarningImage.layer.cornerRadius = 20
        centerWarningImage.layer.masksToBounds = true
        centerWarningImage.clipsToBounds = true
        
        testLabel.textColor = .black
        
        let sideMenu = MenuListController(with: ["Home",
                                                 "Change Ringtone",
                                                 "About Somnos"])
        sideMenu.delegate = self
        
        menu = SideMenuNavigationController(rootViewController: sideMenu)
        menu?.leftSide = true
        menu?.setNavigationBarHidden(true, animated: false)
        SideMenuManager.default.leftMenuNavigationController = menu
        SideMenuManager.default.addPanGestureToPresent(toView: self.view)
        addChildControllers()
        
        navigationController?.navigationBar.barTintColor = UIColor(red: 78/225.0, green: 128/225.0, blue: 185/225.0, alpha: 1)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    //Creates wireframe
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        recursive10s() //run recursive timer
        return node
    }
    
    //Updates wireframe
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            //print(sceneView.currentFrame.camera.trackingState)
            expression(anchor: faceAnchor)
        }
    }
    
    // MARK: - Blink Check Function
    func expression(anchor: ARFaceAnchor) {
        
        let b = faceStatus(anchor: anchor)
        if(b == "Reposition"){
            blind = true
        }else{
            blind = false
        }
        if (b == "Reposition" && !repCD) {
            blind = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if(self.blind){
                    print("reposition")
                // MARK: ergsdh
                    print(self.faceStatus(anchor: anchor) == "Reposition")
                    if(self.faceStatus(anchor: anchor) == "Reposition"){
                        self.centerWarningImage.isHidden = false
                        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                        playSound()
                    }
                    
                }
                self.repCD = false  
            }
            self.repCD = true
            
        }
        let blinkRight = anchor.blendShapes[.eyeBlinkLeft]
        let blinkLeft = anchor.blendShapes[.eyeBlinkRight]
        
        //blink check
        if (((blinkLeft?.decimalValue ?? 0.0 > 0.65) && (blinkRight?.decimalValue ?? 0.0 > 0.65)) && !blink){
            blink = true
            timer1On = true
            let newtimestamp = NSDate().timeIntervalSince1970
            let timestampDifference = abs(newtimestamp - timestamp)
            acct += Float(timestampDifference)
            timestamp = newtimestamp
            queue.append(timestampDifference)
            if(timerCounting){
                TSCollection.append(timestampDifference)
            }
            if (queue.count > 30){
                queue.remove(at: 0)
            }
            
        } else if (blinkLeft?.decimalValue ?? 0.0 < 0.65) && (blinkRight?.decimalValue ?? 0.0 < 0.65) {
            blink = false
            if(timer1On){
                timer1On = false
                timer1 = 0.0
                print("stopped timer")
            }
        }
        
    }
    //dispatch queue
    func recursive10s(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if(self.recOn){
                self.statistics()
                self.recursive10s()
            }
        }
    }

    // MARK: Statistics Function
    func statistics () {
        let x = 60 * 30 / queue.avg();
        print(queue.avg())
        if(x < 10.2){
            //sleepy (maybe have a temperary popup for now)
            print("You are sleepy")
            playSound()
        }
        if(x > 15){
            //they need to see a doctor
            //print("Seek a doctor")
        }
    }
    
    
    //MARK: Light & Face Status Func
    func faceStatus (anchor: ARFaceAnchor)  -> String  {
        self.centerWarningImage.isHidden = true
        // move the light estimation to another
        let frame = sceneView.session.currentFrame
        let lightEstimate = Int (frame?.lightEstimate?.ambientIntensity ?? 0)
        if (lightEstimate < 50) {
            light = false
        } else {
            light = true
        }
        if (!onCooldown){
            self.onCooldown = true
            let seconds = 2.5
           // let b = anchor.isTracked
            
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                if (!self.light){
                    print("It's too dark")
                    playSound()
                }/*
                if (!b) {
                    print("reposition")
                    // MARK: ergsdh
                    self.centerWarningImage.isHidden = false
                    playSound()
                }*/
                self.onCooldown = false
            }
        }
        return (anchor.isTracked ? "Tracking working" : "Reposition")
    }
    
    
    @objc func updateTimer() {
        print("TSCollection.count \(TSCollection.count)")
        print("TSCollection.avg \(TSCollection.avg())")
        count = count + 1
        //blink hold
        if(timer1On){
            timer1 = timer1 + 1.0
            if(timer1 > 3.0){
                //ALERT USER HERE
                timer1 = 0.0
                timer1On = false
                print("held blink for 3+s")
            }
        }
        let time = secondsToHoursMinutesSeconds(seconds: count)
        let timeString = makeTimeString(hours: time.0, minutes: time.1, seconds: time.2)
        timerLabel.text = timeString
        
    }
    
    func secondsToHoursMinutesSeconds(seconds: Int) -> (Int, Int, Int) {
        return ((seconds / 3600), ((seconds % 3600) / 60),((seconds % 3600) % 60))
    }
    
    func makeTimeString(hours: Int, minutes: Int, seconds : Int) -> String  {
        var timeString = ""
        timeString += String(format: "%02d", hours)
        timeString += " : "
        timeString += String(format: "%02d", minutes)
        timeString += " : "
        timeString += String(format: "%02d", seconds)
        return timeString
    }
}

//MARK: Menu

protocol MenuListControllerDelegate {
    func didSelectItem(named: String)
}

class MenuListController: UITableViewController{
    
    public var delegate: MenuListControllerDelegate?
    
    var items = ["Home", "Change Ringtone", "About Somnos"]
    let backgroundColor = UIColor(red: 78/225.0, green: 128/225.0, blue: 185/225.0, alpha: 1)
    
    init(with items: [String]) {
        self.items = items
        super.init(nibName: nil, bundle: nil)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell ")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = backgroundColor
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    override func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView (_ tableview: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row]
        cell.textLabel?.textColor = .white
        cell.backgroundColor = backgroundColor
        tableView.backgroundColor = backgroundColor
        return cell
    }
    
    override func tableView(_ tableview: UITableView, didSelectRowAt indexPath: IndexPath){
        tableView.deselectRow(at: indexPath, animated: true)
        //Relay to delegate about menu item selection
        let selectedItem = items[indexPath.row]
        delegate?.didSelectItem(named: selectedItem)
    }
    
}

//MARK: Extensions
extension Array where Element: FloatingPoint {
    
    func sum() -> Element {
        return self.reduce(0, +)
    }
    
    func avg() -> Element {
        return self.sum() / Element(self.count)
    }
    
    func std() -> Element {
        let mean = self.avg()
        let v = self.reduce(0, { $0 + ($1-mean)*($1-mean) })
        return sqrt(v / (Element(self.count) - 1))
    }
}
