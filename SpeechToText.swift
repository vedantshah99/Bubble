//
//  SpeechToText.swift
//  Bubble
//
//  Created by Vedant Shah on 8/19/24.
//

import Foundation
import AVFoundation
import Speech

class SpeechToText {
    private let audioRecorder: AVAudioRecorder
    private let speechRecognizer = SFSpeechRecognizer()

    init(audioURL: URL) {
        let recordingSettings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                 AVSampleRateKey: 12000.0,
                                 AVNumberOfChannelsKey: 1,
                      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue] as [String : Any]
        audioRecorder = try! AVAudioRecorder(url: audioURL, settings: recordingSettings)
    }

    func startRecording() {
        audioRecorder.record()
    }

    func stopRecording() {
        audioRecorder.stop()
    }

    func convertSpeechToText(completion: @escaping (String?) -> Void) {
        let request = SFSpeechURLRecognitionRequest(url: audioRecorder.url)
        speechRecognizer?.recognitionTask(with: request) { (result, error) in
            completion(result?.bestTranscription.formattedString)
        }
    }
}
