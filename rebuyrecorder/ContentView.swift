//
//  ContentView.swift
//  rebuyrecorder
//
//  Created by test on 8/6/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var xanoService = XanoService()
    
    // Funkcja formatująca czas z sekund na MM:SS
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo aplikacji
            Image("recorder_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
            
            // Status nagrywania
            Text(audioRecorder.isRecording ? "Nagrywam..." : "Gotowy do nagrywania")
                .font(.title2)
                .foregroundColor(audioRecorder.isRecording ? .red : .gray)
            
            // Timer nagrania
            Text(formatTime(audioRecorder.recordingTime))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            
            // Przycisk nagrywania
            Button(action: {
                if audioRecorder.isRecording {
                    // Zatrzymaj nagrywanie
                    audioRecorder.stopRecording()
                } else {
                    // Rozpocznij nagrywanie
                    audioRecorder.startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(audioRecorder.isRecording ? Color.gray : Color.red)
                        .frame(width: 100, height: 100)
                    
                    if audioRecorder.isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Sekcja upload z progress
            VStack(spacing: 12) {
                // Progress bar (gdy upload w toku)
                if xanoService.isUploading {
                    VStack(spacing: 8) {
                        ProgressView(value: xanoService.uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 4)
                        
                        Text(xanoService.uploadMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Przycisk upload
                Button(action: {
                    if let lastRecording = audioRecorder.recordings.last {
                        Task {
                            await xanoService.uploadRecording(lastRecording)
                        }
                    }
                }) {
                    HStack {
                        if xanoService.isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "cloud.fill")
                        }
                        Text(xanoService.isUploading ? "Wysyłanie..." : "Prześlij ostatnie nagranie")
                    }
                    .padding()
                    .background(canUpload ? Color.blue.opacity(0.8) : Color.blue.opacity(0.3))
                    .foregroundColor(canUpload ? .white : .blue)
                    .cornerRadius(10)
                }
                .disabled(!canUpload)
                
                // Komunikat uploadu (sukces/błąd)
                if !xanoService.uploadMessage.isEmpty && !xanoService.isUploading {
                    Text(xanoService.uploadMessage)
                        .font(.caption)
                        .foregroundColor(xanoService.uploadMessage.contains("✅") ? .green : .red)
                        .padding(.horizontal)
                }
            }
            
            // Lista nagrań
            if !audioRecorder.recordings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Zapisane nagrania:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(audioRecorder.recordings) { recording in
                                RecordingRow(
                                    recording: recording,
                                    isLatest: recording.id == audioRecorder.recordings.last?.id,
                                    onUpload: {
                                        Task {
                                            await xanoService.uploadRecording(recording)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // Computed property sprawdzające czy można uploadować
    private var canUpload: Bool {
        !audioRecorder.recordings.isEmpty && !xanoService.isUploading
    }
}

// Komponent wyświetlający pojedyncze nagranie
struct RecordingRow: View {
    let recording: Recording
    let isLatest: Bool
    let onUpload: () -> Void
    
    var body: some View {
        HStack {
            // Ikona nagrania z oznaczeniem najnowszego
            HStack(spacing: 4) {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                if isLatest {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formatDate(recording.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Czas trwania
            Text(formatDuration(recording.duration))
                .font(.caption)
                .foregroundColor(.gray)
            
            // Przycisk upload dla tego nagrania
            Button(action: onUpload) {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            
            // Przycisk odtwarzania (na razie nieaktywny)
            Button(action: {
                print("Odtwarzanie: \(recording.name)")
            }) {
                Image(systemName: "play.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isLatest ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
