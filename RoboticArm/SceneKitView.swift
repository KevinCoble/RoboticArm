//
//  SceneKitView.swift
//  RoboticArm
//
//  Created by Kevin Coble on 11/14/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import SwiftUI
import SceneKit

public struct SceneView: NSViewControllerRepresentable {
    public typealias NSViewControllerType = SceneViewController
    
    let scene: SCNScene
    let viewData: ViewData
    
    public init(scene: SCNScene, viewData : ViewData) {
        self.scene = scene
        self.viewData = viewData
    }
    
    public func makeNSViewController(context: NSViewControllerRepresentableContext<SceneView>) -> SceneViewController {
        return SceneViewController(scene: scene, viewData: viewData)
    }
    
    public func updateNSViewController(_ nsViewController: SceneViewController, context: NSViewControllerRepresentableContext<SceneView>) {
    }
}

public class SceneViewController: SCNViewController, SCNSceneRendererDelegate {
    
    private var _scene: SCNScene?
    override public var scene: SCNScene? { _scene }
    let viewData: ViewData

    init(scene: SCNScene, viewData : ViewData) {
        self.viewData = viewData
        super.init(nibName: nil, bundle: nil, viewFrame: nil, viewOptions: nil)
        _scene = scene
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public required init(nibName: String?, bundle nibBundle: Bundle? = nil, viewFrame: CGRect?, viewOptions: [String : Any]? = [:]) {
        fatalError("init(nibName:bundle:viewFrame:viewOptions:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        scnView.scene = scene
        scnView.delegate = self
        scnView.showsStatistics = true
        scnView.rendersContinuously = true
        viewData.visualizationView = scnView
    }
        
    var lastSimulationTime : TimeInterval = 0.0
    public func renderer(_ aRenderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
      
       //  If we don't have a simulation time yet, store the time and return (updates will start next frame)
       if (lastSimulationTime == 0.0) {
           lastSimulationTime = time
           return
       }
        
        //  Calculate the elapsed time
        let elapsedTime = time - lastSimulationTime
        lastSimulationTime = time
        viewData.simulationTime =  time * 3600.0 * pow(10.0, viewData.simulationSpeed * 0.25)
        
        //  Update the simulation
        viewData.updateSimulation(elapsedTime: elapsedTime)
    }
}

open class SCNViewController : NSViewController {
    internal let _initViewFrame:CGRect
    internal let _initViewOptions:[String:Any]?
    
    /// Unfortunately, SCNView's API hasn't yet been fully updated for Swift, so if you use `viewOptions`s they need to be specified similar to the following:
    ///        viewOptions: [
    ///            SCNView.Option.preferredRenderingAPI.rawValue: NSNumber(value: SCNRenderingAPI.metal.rawValue),
    ///            SCNView.Option.preferredDevice.rawValue: MTLCreateSystemDefaultDevice()!,
    ///            SCNView.Option.preferLowPowerDevice.rawValue: NSNumber(value: true)
    ///        ]
    public required init(nibName:String?, bundle nibBundle:Bundle?=nil, viewFrame:CGRect?, viewOptions:[String:Any]?=[:])
    {
        if nibName == nil {
            _initViewFrame = viewFrame ?? CGRect.zero
            _initViewOptions = viewOptions
        } else {
            _initViewFrame = CGRect.zero
            _initViewOptions = nil
        }
        
        super.init(nibName: nibName, bundle: nibBundle)
        
    }
    
    public required init?(coder aDecoder:NSCoder) {
        _initViewFrame = CGRect.null
        _initViewOptions = nil
        
        super.init(coder: aDecoder)
    }
    
    public convenience init(viewFrame:CGRect?, viewOptions:[String:Any]? = [:]) {
        self.init(nibName: nil, bundle: nil, viewFrame: viewFrame, viewOptions: viewOptions)
    }
    
    @objc public var scnView: SCNView {
        return self.view as! SCNView
    }
    @objc open var scene: SCNScene? {
        return self.scnView.scene
    }
    
    public override func loadView()
    {
        self.view = {
            let view = SCNView(frame: _initViewFrame, options: _initViewOptions)
            view.backgroundColor = NSColor.white
            return view
        }()
    }
    
    public override func viewDidLoad()
    {
        self.scnView.scene = SCNScene()
        scnView.allowsCameraControl = true
        scnView.showsStatistics = true
        scnView.rendersContinuously = true
        
        super.viewDidLoad()
    }

}
