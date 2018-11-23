
import UIKit
import Speech

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    // MARK: Properties
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    private let stringStart = "Start"
    
    private let stringStop = "Stop"
    
    private let sentences = ["How are you today", "Five days a week", "The University of Chicago", "The ring is on the wrong finger", "blah blah blah blah"]
    
    private var currentSentenceIndex = 0

    
//    @IBOutlet var textView: UITextView!
    
    @IBOutlet var previousButton: UIButton!
    
    @IBOutlet var nextButton: UIButton!
    
    @IBOutlet var recordButton: UIButton!
    
    @IBOutlet var segmentView: UITextView!
    
    @IBOutlet var gradeView: UILabel!
    
    @IBOutlet var gradeLabelView: UILabel!
    
    @IBOutlet var sentenceView: UITextView!
    
    
//    sentenceView.textContainer.heightTracksTextView = true
//    sentenceView.isScrollEnabled = false
    
//    @IBOutlet weak var audioView: SwiftSiriWaveformView!
    
    let synthesizer = AVSpeechSynthesizer()

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        selectSentence()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer.delegate = self
        
        // Make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in

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
    
    private func selectSentence()
    {
        sentenceView.text = "\"" + sentences[currentSentenceIndex] + "\""
        segmentView.text = ""
        
        self.gradeView.isHidden = true
        self.gradeLabelView.isHidden = true
    }
    
    
    private func startRecording() throws {
        
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
                
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            let coloredSentence = NSMutableAttributedString()
            var grade = "N/A"
            
            if let result = result {
                // Update the text view with the results.
//                print (result.bestTranscription.segments as Any)
//                print (result.transcriptions.last?.segments.last?.substring as Any)
//                print (result.transcriptions.last?.segments.last?.confidence as Any)
//                print("------------------------------------")
                
//                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                
                
                for t in result.bestTranscription.segments
                {
                    coloredSentence.append(self.wordColor(word: t.substring, score: t.confidence))
                    
                }
                if result.bestTranscription.formattedString.lowercased() == self.sentences[self.currentSentenceIndex].lowercased()
                {
                    self.audioEngine.stop()
                    self.recognitionRequest?.endAudio()
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Stopping", for: .disabled)
                        
                    isFinal = true
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
                        case _ where minConfidence > 0.8: grade = "A+"
                        case _ where minConfidence > 0.7: grade = "A"
                        case _ where minConfidence > 0.6: grade = "A-"
                        case _ where minConfidence > 0.5: grade = "B+"
                        case _ where minConfidence > 0.4: grade = "B-"
                        case _ where minConfidence > 0.3: grade = "C"
                        default: grade = "D"
                    }
                    
                    if result.bestTranscription.formattedString.lowercased() != self.sentences[self.currentSentenceIndex].lowercased()
                    {
                        grade = "F"
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
        
        segmentView.textColor = UIColor.gray
        segmentView.text = "(Listening...)"
    }
    
    public func wordColor(word:String, score:Float) -> NSAttributedString
    {
        var color = UIColor.black
        switch score {
            case _ where score == 0: color = UIColor.gray
            case _ where score < 0.1: color = UIColor.red
            case _ where score < 0.5: color = UIColor.orange
            default: color = UIColor.green
        }
        
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color, .font: UIFont.systemFont(ofSize: 40)]
        let attributedWord = NSAttributedString(string: word+" ", attributes: attributes)
        
        return attributedWord
    }
    
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            gradeLabelView.isHidden = true
            gradeView.isHidden = true
            recordButton.isEnabled = true
            previousButton.isEnabled = true
            nextButton.isEnabled = true
            recordButton.setTitle(stringStart, for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
//            previousButton.isEnabled = false
//            nextButton.isEnabled = false
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                try startRecording()
                recordButton.setTitle(stringStop, for: [])
                gradeView.isHidden = true
                gradeLabelView.isHidden = true
                
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
    
    @IBAction func speechButtonTapped()
    {
        textToSpeech()
    }
        
    private func textToSpeech()
    {
        let utterance = AVSpeechUtterance(string: sentences[currentSentenceIndex])
//        utterance.rate = 0.4
        
        synthesizer.speak(utterance)
        
    }
    
    @IBAction func previousButtonTapped()
    {
        currentSentenceIndex = max(currentSentenceIndex - 1,0)
        selectSentence()
    }
    
    @IBAction func nextButtonTapped()
    {
        currentSentenceIndex = min(sentences.count - 1, currentSentenceIndex + 1)
        selectSentence()
    }
    
    
}

