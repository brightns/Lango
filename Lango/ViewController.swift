/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The root view controller that provides a button to start and stop recording, and which displays the speech recognition results.
*/

import UIKit
import Speech

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    // MARK: Properties
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    private let stringStart = "Pronounce"
    
    private let stringStop = "Stop Listening"

    
//    @IBOutlet var textView: UITextView!
    
    @IBOutlet var recordButton: UIButton!
    
    @IBOutlet var segmentView: UITextView!
    
    @IBOutlet var gradeView: UILabel!
    
    @IBOutlet var gradeLabelView: UILabel!
    
    @IBOutlet weak var audioView: SwiftSiriWaveformView!
    
    // MARK: UIViewController
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer.delegate = self
        
        // Make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in

            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
                
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            let coloredSentence = NSMutableAttributedString()
            var grade = "N/A"
            
            if let result = result {
                // Update the text view with the results.
                print (result.bestTranscription.segments as Any)
//                print (result.transcriptions.last?.segments.last?.substring as Any)
//                print (result.transcriptions.last?.segments.last?.confidence as Any)
                print("------------------------------------")
                
//                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                
                for t in result.bestTranscription.segments
                {
                    coloredSentence.append(self.wordColor(word: t.substring, score: t.confidence))
                }
                
                if isFinal
                {
                    var minConfidence:Float = 1
                    
                    for s in result.bestTranscription.segments
                    {
                        minConfidence = min(minConfidence, s.confidence)

                    }
                    
                    switch minConfidence
                    {
                        case _ where minConfidence > 0.9: grade = "A+"
                        case _ where minConfidence > 0.8: grade = "A-"
                        case _ where minConfidence > 0.7: grade = "B+"
                        case _ where minConfidence > 0.6: grade = "B-"
                        case _ where minConfidence > 0.4: grade = "C"
                        default: grade = "F"
                    }
                
                    self.gradeView.isHidden = false
                    self.gradeLabelView.isHidden = false
                    self.gradeView.text = grade
                }
            
                
//                self.segmentView.text = segments.joined(separator: " ")
                
                self.segmentView.attributedText = coloredSentence
                
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isEnabled = true
                self.recordButton.setTitle(self.stringStart, for: [])
                
            }
        }

        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Let the user know to start talking.
//        textView.text = "(Go ahead, I'm listening)"
    }
    
    public func wordColor(word:String, score:Float) -> NSAttributedString
    {
        var color = UIColor.black
        switch score {
            case _ where score == 0: color = UIColor.gray
            case _ where score < 0.3: color = UIColor.red
            case _ where score < 0.8: color = UIColor.orange
            default: color = UIColor.black
        }
        
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color, .font: UIFont.systemFont(ofSize: 36)]
        let attributedWord = NSAttributedString(string: word+" ", attributes: attributes)
        
        return attributedWord
    }
    
    // MARK: SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            gradeLabelView.isHidden = true
            gradeView.isHidden = true
            recordButton.isEnabled = true
            recordButton.setTitle(stringStart, for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                try startRecording()
                recordButton.setTitle(stringStop, for: [])
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
}

