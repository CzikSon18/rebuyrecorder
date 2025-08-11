import Foundation

class XanoService: ObservableObject {
    
    // Tutaj wklej swój URL endpoint z XANO
    // Przykład: https://x8ki-letl-twmt.n7.xano.io/api:abcdef/recordings
    private let baseURL = "https://xsfg-jr8d-0fqm.f2.xano.io/api:aZHHYZgn/Upload_recording"
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadMessage = ""
    
    // Funkcja uploadująca plik audio do XANO
    func uploadRecording(_ recording: Recording) async {
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
            uploadMessage = "Przygotowywanie uploadu..."
        }
        
        do {
            // Przygotowanie danych
            let audioData = try Data(contentsOf: recording.url)
            
            await MainActor.run {
                uploadProgress = 0.3
                uploadMessage = "Wysyłanie pliku..."
            }
            
            // Przygotowanie request
            guard let url = URL(string: baseURL) else {
                throw XanoError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            // Tworzenie multipart/form-data
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let httpBody = createMultipartBody(
                audioData: audioData,
                recording: recording,
                boundary: boundary
            )
            
            await MainActor.run {
                uploadProgress = 0.6
                uploadMessage = "Przetwarzanie..."
            }
            
            // Wysłanie request
            let (data, response) = try await URLSession.shared.upload(for: request, from: httpBody)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    await MainActor.run {
                        uploadProgress = 1.0
                        uploadMessage = "✅ Upload zakończony!"
                        isUploading = false
                    }
                    print("✅ Upload successful")
                } else {
                    throw XanoError.serverError(httpResponse.statusCode)
                }
            }
            
        } catch {
            await MainActor.run {
                uploadMessage = "❌ Błąd: \(error.localizedDescription)"
                isUploading = false
            }
            print("❌ Upload error: \(error)")
        }
        
        // Reset po 3 sekundach
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.uploadMessage = ""
            self.uploadProgress = 0.0
        }
    }
    
    // Tworzenie multipart/form-data body
    private func createMultipartBody(audioData: Data, recording: Recording, boundary: String) -> Data {
        var body = Data()
        
        // TYLKO plik audio - bez żadnych innych pól!
        let fileName = "audio_\(Int(Date().timeIntervalSince1970)).m4a"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Zamknięcie
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}

// Enum dla błędów
enum XanoError: Error, LocalizedError {
    case invalidURL
    case noData
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Nieprawidłowy URL XANO"
        case .noData:
            return "Brak danych do wysłania"
        case .serverError(let code):
            return "Błąd serwera: \(code)"
        }
    }
}
