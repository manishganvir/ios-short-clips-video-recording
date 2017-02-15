//
//  ViewController.swift
//  Video-Recording-Example
//
//  Created by Ganvir, Manish on 2/14/17.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate{
    
    @IBOutlet weak var RecordingButton: UIButton!
    var startCalled = false
    var session:AVCaptureSession!
    var cameraAccess: Bool!
    var captureDevice : AVCaptureDevice?
    var captureLayer : AVCaptureVideoPreviewLayer!
    var avWriter1: AVAssetWriter?
    var avWriter2: AVAssetWriter?
    var avAudioInput1: AVAssetWriterInput?
    var avVideoInput1: AVAssetWriterInput?
    var avAudioInput2: AVAssetWriterInput?
    var avVideoInput2: AVAssetWriterInput?
    
    var avActiveWriter: AVAssetWriter?
    var avActiveAudioInput: AVAssetWriterInput?
    var avActiveVideoInput: AVAssetWriterInput?
    
    var outputURL1 : URL?
    var outputURL2 : URL?
    var isVideoFramesWritten: Bool?
    var fileName: String?
    var iCount: Int?
    
    var currentTime: Int64?
    
    var timer: Timer!
    var video_queue : DispatchQueue!
    var startTime: CMTime!
    var lastTime: CMTime!

    var bufferArray = [CMSampleBuffer]()
    var hasWritingStarted: Bool!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        cameraAccess = false;
        captureDevice = nil;
        isVideoFramesWritten = false
        currentTime = 0;
        iCount = 0;
        initializeSession()
        hasWritingStarted = false;
        video_queue = DispatchQueue(label: "com.Interval.video_queue")
        
        do {
            let content = try FileManager.default.contentsOfDirectory(atPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
            for file in content {
                // Create writer
                let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
                let url1 = documentsPath.appendingPathComponent(file)

                try FileManager.default.removeItem(at: url1!)
            }
        } catch _ {
        }
        

    }
    
    func runTimedCode() {
        // Check if 1 second has elapsed or not
        
            // Time to switch
            print("Time to switch")
            if (avActiveWriter == avWriter1)
            {
                print("Current recorder 1 ")
                
                avActiveWriter = avWriter2
                avActiveAudioInput = avAudioInput2
                avActiveVideoInput = avVideoInput2

                // do some task
                self.avAudioInput1?.markAsFinished()
                self.avVideoInput1?.markAsFinished()
                self.avWriter1?.endSession(atSourceTime: lastTime)
                // Finish writing for first one
                video_queue.async {
                                       print("finishWriting began at ", self.getCurrentMillis())

                    self.avWriter1?.finishWriting(completionHandler: {
                        if self.avWriter1?.status == AVAssetWriterStatus.failed {
                            // Handle error here
                            print( "Error : ", self.avWriter1?.error.debugDescription as Any)
                            return;
                        }
                        
                        
                    })
                    print("finishWriting ended at ", self.getCurrentMillis())

                    self.InitFirstWriter()
                    print("time after 2 ", self.getCurrentMillis())


                }
                
                
            }
            else
            {
                print("Current recorder 2 ")
                
                avActiveWriter = avWriter1
                avActiveAudioInput = avAudioInput1
                avActiveVideoInput = avVideoInput1
                // do some task
                self.avAudioInput2?.markAsFinished()
                self.avVideoInput2?.markAsFinished()
                self.avWriter2?.endSession(atSourceTime: startTime)
                // Finish writing for second one
               video_queue.async {
                
                    print("time before ", self.getCurrentMillis())
                print("finishWriting began at ", self.getCurrentMillis())

                    self.avWriter2?.finishWriting(completionHandler: {
                        if self.avWriter2?.status == AVAssetWriterStatus.failed {
                            // Handle error here
                            print( "Error : ", self.avWriter2?.error.debugDescription as Any)
                            return;
                        }
                    })
                print("finishWriting ended at ", self.getCurrentMillis())

                    self.InitSecondWriter()
                
                    print("time after 2 ", self.getCurrentMillis())


                }
                
            }
            
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func OnRecordingButtonPress(_ sender: Any) {
        
        if (!self.cameraAccess)
        {
            print(" Camera access needed in order to use the app ")
            initializeSession()
            return;
        }
        if (!startCalled)
        {
            startCalled = true;
            RecordingButton.setTitle("Stop Recording", for: .normal );
            startCamera();
        }
        else
        {
            startCalled = false;
            RecordingButton.setTitle("Start Recording", for: .normal );
            stopCamera();
        }
    }
    
    func initializeSession() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo,
                                          completionHandler: { (granted:Bool) -> Void in
                                            if granted {
                                                
                                                self.cameraAccess = true
                                            }
                                            else
                                            {
                                                print(" Access denied, cannot use the app ")
                                            }
            })
            break
        case .authorized:
            cameraAccess = true
            break
        case .denied, .restricted:
            break
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission( { (granted: Bool) -> Void in
            
        });
    }
    func InitFirstWriter()
    {
        iCount = iCount! + 1;
        fileName = String(iCount!) + ".mp4"

        // Create writer
        let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        outputURL1 = documentsPath.appendingPathComponent(fileName!)
        
        // Delete if it exists
        if FileManager.default.fileExists(atPath: outputURL1!.path) {
            do {
                try FileManager.default.removeItem(at: outputURL1!)
            } catch _ {
            }
        }
        
        // Writer
        avWriter1 = try? AVAssetWriter(outputURL: outputURL1!, fileType: AVFileTypeQuickTimeMovie)
        
        // Audio setting
        let audioOutputSettings: Dictionary<String, AnyObject> = [
            AVFormatIDKey : Int(kAudioFormatMPEG4AAC) as AnyObject,
            AVNumberOfChannelsKey : 2 as AnyObject,
            AVSampleRateKey : 44100 as AnyObject
        ]
        
        avAudioInput1 = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings)
        avAudioInput1?.expectsMediaDataInRealTime = true
        
        
        var height: NSNumber
        var width: NSNumber
        
        height = 1080;
        width = 1920;
        // Video Settings
        let videoOutputSettings: Dictionary<String, AnyObject> = [
            AVVideoCodecKey : AVVideoCodecH264 as AnyObject,
            AVVideoWidthKey : width as NSNumber,
            AVVideoHeightKey : height as NSNumber
        ]
        avVideoInput1 = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings:videoOutputSettings)
        avVideoInput1?.expectsMediaDataInRealTime = true
        
        avWriter1?.add(avAudioInput1!)
        avWriter1?.add(avVideoInput1!)
        
        
    }
    func InitSecondWriter()
    {
        iCount = iCount! + 1;
        // Audio setting
        let audioOutputSettings: Dictionary<String, AnyObject> = [
            AVFormatIDKey : Int(kAudioFormatMPEG4AAC) as AnyObject,
            AVNumberOfChannelsKey : 2 as AnyObject,
            AVSampleRateKey : 44100 as AnyObject
        ]
        fileName = String(iCount!) + ".mp4"
        let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        outputURL2 = documentsPath.appendingPathComponent(fileName!)
        avWriter2 = try? AVAssetWriter(outputURL: outputURL2!, fileType: AVFileTypeQuickTimeMovie)
        
        avAudioInput2 = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings)
        avAudioInput2?.expectsMediaDataInRealTime = true
        
        var height: NSNumber
        var width: NSNumber
        
        height = 1080;
        width = 1920;
        // Video Settings
        let videoOutputSettings: Dictionary<String, AnyObject> = [
            AVVideoCodecKey : AVVideoCodecH264 as AnyObject,
            AVVideoWidthKey : width as NSNumber,
            AVVideoHeightKey : height as NSNumber
        ]

        avVideoInput2 = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings:videoOutputSettings)
        avVideoInput2?.expectsMediaDataInRealTime = true
        
        avWriter2?.add(avAudioInput2!)
        avWriter2?.add(avVideoInput2!)
        

    }
    func startCamera()
    {
        // Get the device
        if (captureDevice == nil)
        {
            let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
            for device in devices!{
                if (device as AnyObject).position == AVCaptureDevicePosition.back{
                    captureDevice = device as? AVCaptureDevice
                }
            }
        }
        
        InitFirstWriter()
        InitSecondWriter()
        
        avActiveWriter = avWriter1
        avActiveAudioInput = avAudioInput1
        avActiveVideoInput = avVideoInput1

        
        // Create capture session
        session = AVCaptureSession()
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            session.addInput(input)
            
            let ainput =  try AVCaptureDeviceInput(device:AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio))
            session.addInput(ainput)
            
            let videoOutput = AVCaptureVideoDataOutput()
            let videoserialQueue = DispatchQueue(label: "videoQueue")
            videoOutput.setSampleBufferDelegate(self, queue: videoserialQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            let connectionVideo = videoOutput.connection(withMediaType: AVMediaTypeVideo)
            connectionVideo?.videoOrientation = AVCaptureVideoOrientation.portrait;
            if (session?.canAddOutput(videoOutput) != nil) {
                session?.addOutput(videoOutput)
            }
            
            captureLayer = AVCaptureVideoPreviewLayer(
                session: session)
            
            captureLayer!.frame = self.view.bounds
            captureLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
            
            self.view.layer.insertSublayer(captureLayer!, at: 0)
            
        }
        catch{
            print(error)
            return
        }
        
        let audioDataOutput = AVCaptureAudioDataOutput()
        let serialQueue = DispatchQueue(label: "audioQueue")
        audioDataOutput.setSampleBufferDelegate(self, queue: serialQueue)
        
        if (session?.canAddOutput(audioDataOutput) != nil) {
            session?.addOutput(audioDataOutput)
            print(" Audio output added ")
        }
        session.startRunning()
        
                timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
        
        
    }
    

    
    func merge()
    {
        
            let composition = AVMutableComposition()
            
            let videoTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            let audioTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            var time:Double = 0.0
            
            var i = 0;
            for i in 1 ..< iCount!
            {
                fileName = String(i) + ".mp4"
                let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
                let outputURL = documentsPath.appendingPathComponent(fileName!)
                print("URL: " , fileName!)
                
                let asset = AVAsset(url: outputURL!)
                var videoAssetTrack: AVAssetTrack!
                videoAssetTrack = nil
                if (asset.tracks(withMediaType: AVMediaTypeVideo).count > 0)
                {
                 videoAssetTrack = asset.tracks(withMediaType: AVMediaTypeVideo)[0]
                }
                var audioAssetTrack: AVAssetTrack!
                audioAssetTrack = nil;
                if (asset.tracks(withMediaType: AVMediaTypeAudio).count > 0)
                {
                    audioAssetTrack = asset.tracks(withMediaType: AVMediaTypeAudio)[0]
                }
                
                let timeScale = asset.duration.timescale
                
                let atTime = CMTime(seconds: time, preferredTimescale: timeScale)
                
                
                do{
                    if (videoAssetTrack != nil)
                    {
                        try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: videoAssetTrack, at: atTime)
                    }
                    if (audioAssetTrack != nil)
                    {
                        try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: audioAssetTrack, at: atTime)
                    }
                }
                    
                catch{
                    print("An error has occured")
                }
                
                
                time += asset.duration.seconds
            }
            
        
        let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])

            let path = documentsPath.appendingPathComponent("finalVideo.mp4")
        
            let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
            exporter?.outputURL = path
            exporter?.shouldOptimizeForNetworkUse = true
            exporter?.outputFileType = AVFileTypeMPEG4
            
            exporter?.exportAsynchronously(completionHandler: { 
                DispatchQueue.main.async {
                    print("export finished")
                    
                    UISaveVideoAtPathToSavedPhotosAlbum ((exporter?.outputURL?.path)!, self, nil, nil);

                }
                
            })
        
            
            
    }

    func stopCamera()
    {
        timer.invalidate()
        if (session.isRunning)
        {
            session.stopRunning()
        }
        captureLayer!.removeFromSuperlayer()
        
        avActiveAudioInput?.markAsFinished()
        avActiveVideoInput?.markAsFinished()
        avActiveWriter?.finishWriting(completionHandler: {
            if self.avActiveWriter?.status == AVAssetWriterStatus.failed {
                // Handle error here
                print( "Error : ", self.avActiveWriter?.error.debugDescription as Any)
                return;
            }
            
            //UISaveVideoAtPathToSavedPhotosAlbum ((self.outputURL?.path)!, self, nil, nil);
            self.merge();
            
        })
        
    }

    func getCurrentMillis()->Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        if (avWriter1?.status != nil)
        {
            print("Status of writer1 ", avWriter1?.status.rawValue)
        }
        else
        {
            print("Status of writer1 nil")

        }
        if (avWriter2?.status != nil)
        {
            print("Status of writer2 ", avWriter2?.status.rawValue)
        }
        else
        {
            print("Status of writer2 nil")
            
        }



        if CMSampleBufferDataIsReady(sampleBuffer) == false
        {
            // Handle error
            print("Data is not ready")
            return;
        }
        
        
        
        if let _ = captureOutput as? AVCaptureVideoDataOutput {
            
            startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if avActiveWriter?.status == AVAssetWriterStatus.unknown {
                if (bufferArray.count > 0)
                {
                    startTime = CMSampleBufferGetPresentationTimeStamp(bufferArray[0])
                    print("1::  PTS", startTime)

                }
                print(" Start writing and start session ")
                avActiveWriter?.startWriting()
                avActiveWriter?.startSession(atSourceTime: startTime)
                print("2::  PTS", startTime)

                print("1:: Startsession called at PTS", startTime)
                hasWritingStarted = true
                isVideoFramesWritten = false
                
            }
        }
        
        if avActiveWriter?.status != AVAssetWriterStatus.writing {
            print("Status not wrting ", avActiveWriter?.status)
            if (hasWritingStarted == false)
            {
             return;
            }

            var bufferCopy : CMSampleBuffer?
            CMSampleBufferCreateCopy(kCFAllocatorDefault, sampleBuffer, &bufferCopy);
            bufferArray.append(bufferCopy!);
            return;
        }
        if avActiveWriter?.status == AVAssetWriterStatus.failed {
            // Handle error here
            print( "Error AVAssetWriterStatus.failed : ", avActiveWriter?.error.debugDescription as Any)
            return;
        }
        
        
        if let _ = captureOutput as? AVCaptureVideoDataOutput {
            
            
            if (avActiveVideoInput?.isReadyForMoreMediaData == true){
                
                // Check if we had pending buffer
                if (bufferArray.count > 0)
                {
                    for buffer in bufferArray
                    {
                        let format = CMSampleBufferGetFormatDescription(buffer);
                        let type = CMFormatDescriptionGetMediaType(format!);
                        if (type == kCMMediaType_Video)
                        {
                            avActiveVideoInput?.append(buffer);
                            lastTime = CMSampleBufferGetPresentationTimeStamp(buffer)
                            print("1: Writng video frames at ", lastTime)

                            isVideoFramesWritten = true
                        }
                        else if (isVideoFramesWritten == true)
                        {
                            print("Status not wrting ", avActiveWriter?.status)

                            print("1: Writing audio frames ")

                            avActiveAudioInput?.append(buffer);
                        }
                        
                    }
                    bufferArray.removeAll()
                }
                avActiveVideoInput?.append(sampleBuffer)
                lastTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                print("2: Writng video frames at ", lastTime)

                isVideoFramesWritten = true
            }
            else
            {
                print("Skipping frames ")

            }
        }
        if let _ = captureOutput as? AVCaptureAudioDataOutput {
            if avActiveAudioInput?.isReadyForMoreMediaData == true && isVideoFramesWritten == true{
                // Check if we had pending buffer
                if (bufferArray.count > 0)
                {
                    for  buffer in bufferArray
                    {
                        let format = CMSampleBufferGetFormatDescription(buffer);
                        let type = CMFormatDescriptionGetMediaType(format!);
                        if (type == kCMMediaType_Video)
                        {
                            avActiveVideoInput?.append(buffer);
                            print("3: Writng video frames at ", lastTime)

                        }
                        else
                        {
                            avActiveAudioInput?.append(buffer);
                        }
                        
                    }
                    bufferArray.removeAll()
                }
                avActiveAudioInput?.append(sampleBuffer)
            }
            
        }
        
    }
}

