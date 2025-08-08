
import AVFoundation
import SwiftUI

// Struktura reprezentująca pojedyncze nagranie
struct Recording: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let date: Date
    let duration: TimeInterval
}

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    
    @Published var isRecording = false
    @Published var recordingTime = 0
    @Published var hasPermission = false
    @Published var recordings: [Recording] = []
    
    override init() {
        super.init()
        requestMicrophonePermission()
        loadExistingRecordings()
    }
    
    // Funkcja sprawdzająca i prosząca o uprawnienia
    func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            // Nowy sposób dla iOS 17+
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                    if granted {
                        print("✅ Uprawnienia do mikrofonu przyznane")
                    } else {
                        print("❌ Uprawnienia do mikrofonu odrzucone")
                    }
                }
            }
        } else {
            // Stary sposób dla starszych wersji iOS
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                    if granted {
                        print("✅ Uprawnienia do mikrofonu przyznane")
                    } else {
                        print("❌ Uprawnienia do mikrofonu odrzucone")
                    }
                }
            }
        }
    }
    
    // MARK: - Funkcje nagrywania
    
    func startRecording() {
        guard hasPermission else {
            print("❌ Brak uprawnień do nagrywania")
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            // Ustawienia nagrywania - format MP3-podobny
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Ścieżka do pliku
            let audioURL = getRecordingURL()
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            startTimer()
            
            print("✅ Rozpoczęto nagrywanie")
            
        } catch {
            print("❌ Błąd podczas nagrywania: \(error)")
        }
    }
    
    func stopRecording() {
        guard let recorder = audioRecorder else { return }
        
        let recordingURL = recorder.url
        let recordingDuration = TimeInterval(recordingTime)
        
        recorder.stop()
        isRecording = false
        stopTimer()
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false)
        
        // Dodaj nagranie do listy
        let newRecording = Recording(
            url: recordingURL,
            name: "Nagranie \(recordings.count + 1)",
            date: Date(),
            duration: recordingDuration
        )
        
        recordings.append(newRecording)
        
        print("⏹️ Zatrzymano nagrywanie: \(newRecording.name)")
        print("📁 Zapisano: \(recordingURL.lastPathComponent)")
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.recordingTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Helper functions
    
    private func getRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        return audioURL
    }
    
    // Ładuje istniejące nagrania z dysku
    private func loadExistingRecordings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let audioFiles = fileURLs.filter { $0.pathExtension == "m4a" }
            
            for (index, url) in audioFiles.enumerated() {
                let recording = Recording(
                    url: url,
                    name: "Nagranie \(index + 1)",
                    date: getFileDate(url: url),
                    duration: 0 // Na razie 0, później możemy dodać prawdziwą długość
                )
                recordings.append(recording)
            }
            
            print("📁 Załadowano \(recordings.count) nagrań")
            
        } catch {
            print("❌ Błąd podczas ładowania nagrań: \(error)")
        }
    }
    
    // Pobiera datę utworzenia pliku
    private func getFileDate(url: URL) -> Date {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.creationDate] as? Date ?? Date()
        } catch {
            return Date()
        }
    }
}
