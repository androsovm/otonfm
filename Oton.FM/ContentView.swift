//
//  ContentView.swift
//  Oton.FM
//
//  Created by Yuri on 23/04/2025.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit

class RadioPlayer: NSObject, ObservableObject {
    static let shared = RadioPlayer()
    private var player: AVPlayer?
    private let defaultArtwork = UIImage(named: "defaultArtwork")
    @Published var isPlaying = false
    @Published var currentTrackTitle: String = ""
    @Published var artworkImage: UIImage
    @Published var artworkId: UUID = UUID() // Добавляем ID для отслеживания изменений
    @Published var isConnecting: Bool = false
    private var hasLoadedArtworkOnce = false

    private override init() {
        self.artworkImage = UIImage(named: "defaultArtwork") ?? UIImage()
        super.init()
    }

    func playStream() {
        isConnecting = true
        guard let url = URL(string: "https://s4.radio.co/s696f24a77/listen") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        player = AVPlayer(url: url)
        player?.currentItem?.addObserver(self, forKeyPath: "timedMetadata", options: [.new, .initial], context: nil)
        player?.play()
        fetchArtworkFromStatusAPI()
        setupNowPlaying()
        setupRemoteCommandCenter()
    }

    private func fetchArtworkFromStatusAPI() {
        let statusURL = URL(string: "https://public.radio.co/stations/s696f24a77/status")!
        var request = URLRequest(url: statusURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // Создаем новую сессию без кэширования для обновления данных
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }
            
            print("🧩 Получены новые данные о треке")
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current_track"] as? [String: Any],
                  let artworkURLString = current["artwork_url_large"] as? String else { return }

            print("🎨 Получен artwork URL: \(artworkURLString)")
            
            // Принудительно добавляем timestamp к URL для избежания кэширования
            let timestamp = Date().timeIntervalSince1970
            let cacheBustingURLString = "\(artworkURLString)?nocache=\(timestamp)"
            guard let imageURL = URL(string: cacheBustingURLString) else { return }
            
            print("🔄 Запрос изображения: \(cacheBustingURLString)")
            
            // Новый запрос для изображения без кэширования
            var imageRequest = URLRequest(url: imageURL)
            imageRequest.cachePolicy = .reloadIgnoringLocalCacheData
            imageRequest.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
            
            session.dataTask(with: imageRequest) { imageData, imageResponse, imageError in
                print("📷 Получен ответ на запрос изображения")
                
                if let error = imageError {
                    print("❌ Ошибка загрузки изображения: \(error.localizedDescription)")
                    return
                }
                
                guard let imageData = imageData, !imageData.isEmpty else {
                    print("⚠️ Нет данных изображения")
                    return
                }
                
                if let image = UIImage(data: imageData) {
                    DispatchQueue.main.async {
                        print("📊 Детальный анализ URL обложки: \(artworkURLString)")
                let isStationLogo = artworkURLString.contains("station_logos") || artworkURLString.contains("s696f24a77") || artworkURLString.lowercased().contains("oton")
                print("🔍 Это логотип станции? \(isStationLogo ? "Да" : "Нет")")
                
                if isStationLogo {
                            // Если это логотип станции, используем дефолтное изображение
                            print("⚠️ Обнаружен логотип станции вместо обложки трека: \(artworkURLString)")
                            let imageToUse = self.defaultArtwork ?? image
                            self.artworkImage = imageToUse
                            
                            let artwork = MPMediaItemArtwork(boundsSize: imageToUse.size) { _ in imageToUse }
                            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = artwork
                            print("🎵 Установлено дефолтное изображение")
                        } else {
                            // Если это обложка трека, используем её
                            print("✅ Обнаружена настоящая обложка трека: \(artworkURLString)")
                            // Генерируем новый UUID, чтобы гарантировать обновление UI
                            let newImage = image.copy() as? UIImage ?? image
                            self.artworkImage = newImage
                            // Генерируем новый UUID для обновления анимаций в интерфейсе
                            self.artworkId = UUID()
                            print("🆔 Новый ID обложки: \(self.artworkId)")
                            
                            let artwork = MPMediaItemArtwork(boundsSize: newImage.size) { _ in newImage }
                            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = artwork
                            print("🎵 Обновлено изображение трека из URL: \(artworkURLString)")
                        }
                        self.hasLoadedArtworkOnce = true
                    }
                }
            }.resume()
        }
        task.resume()
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    private func setupNowPlaying() {
        let image = self.artworkImage
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

        let nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrackTitle.isEmpty ? "Oton.FM Radio" : currentTrackTitle,
            MPMediaItemPropertyArtist: "Live Stream",
            MPMediaItemPropertyArtwork: artwork
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playStream()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timedMetadata",
           let metadataItems = player?.currentItem?.timedMetadata {
            for item in metadataItems {
                if let value = item.value as? String {
                    print("📌 Новый трек: \(value)")
                    DispatchQueue.main.async {
                        // Сохраняем предыдущий трек для сравнения
                        let previousTrack = self.currentTrackTitle
                        let isNewTrack = previousTrack != value
                        
                        self.currentTrackTitle = value
                        self.isConnecting = false
                        self.isPlaying = true
                        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] = value
                        
                        // Загружаем обложку только если это действительно новый трек
                        if isNewTrack {
                            print("🆕 Обнаружен новый трек: \(value), предыдущий: \(previousTrack)")
                            
                            // Запрашиваем обложку напрямую без плейсхолдера,
                            // так как смена обложек создает мерцание
                            print("🔄 Запрашиваем обложку для трека: \(value)")
                            self.fetchArtworkFromStatusAPI()
                        } else {
                            print("ℹ️ Повторное уведомление о том же треке: \(value)")
                        }
                    }
                }
            }
        }
    }
}

struct SplashView: View {
    @State private var animate = false
    @Binding var isActive: Bool

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("otonLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(animate ? 1.2 : 0.8)
                .opacity(animate ? 0 : 1)
                .animation(.easeInOut(duration: 1.5), value: animate)
        }
        .onAppear {
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isActive = false
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var player = RadioPlayer.shared
    @State private var isInterfaceVisible = false
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            Image(uiImage: player.artworkImage)
                .resizable()
                .scaledToFill()
                .blur(radius: 50)
                .opacity(0.4)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: player.artworkId)

            if isInterfaceVisible {
                VStack(spacing: 20) {
                    Image("otonLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .padding(.bottom, -10)

                    Image(uiImage: player.artworkImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color(player.artworkImage.averageColor ?? .black).opacity(0.5), radius: 20, x: 0, y: 10)
                        .opacity(1.0)
                        .animation(.easeInOut(duration: 0.5), value: player.artworkId)

                    Group {
                        if player.isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: player.artworkImage.averageColor?.isLightColor == true ? .black : .white))
                                .frame(height: 40)
                        } else {
                            Text(player.currentTrackTitle)
                                .id(player.currentTrackTitle)
                                .font(.headline)
                                .foregroundColor(player.artworkImage.averageColor?.isLightColor == true ? .black : .white)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .padding(.horizontal)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.5), value: player.currentTrackTitle)
                        }
                    }


                    Button(action: {
                        if player.isPlaying {
                            player.pause()
                        } else {
                            player.playStream()
                        }
                    }) {
                        ZStack {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .resizable()
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color(red: 208/255, green: 0, blue: 0))
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(red: 208/255, green: 0, blue: 0).opacity(0.6), radius: 15, x: 0, y: 0)
                                .scaleEffect(isPressed ? 0.85 : 1.0)
                                .animation(.easeOut(duration: 0.2), value: isPressed)
                        }
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in isPressed = true }
                            .onEnded { _ in isPressed = false }
                    )
                }
                .padding()
                .transition(.opacity)
                .animation(.easeInOut(duration: 1.0), value: isInterfaceVisible)
            }
        }
        .onAppear {
            withAnimation {
                isInterfaceVisible = true
            }
        }
    }
}


@main
struct OtonFMApp: App {
    @State private var isSplashActive = true

    var body: some Scene {
        WindowGroup {
            if isSplashActive {
                SplashView(isActive: $isSplashActive)
            } else {
                ContentView()
            }
        }
    }
}

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extent = inputImage.extent
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        let parameters = [kCIInputExtentKey: CIVector(cgRect: extent)]
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: parameters) else { return nil }
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: CGFloat(bitmap[3]) / 255)
    }
}

extension UIColor {
    var isLightColor: Bool {
        var white: CGFloat = 0
        getWhite(&white, alpha: nil)
        return white > 0.7
    }
}


/*
struct AnimatedBackground: View {
    @State private var waveOffset: Angle = .degrees(0)

    var body: some View {
        GeometryReader { geo in
            WaveShape(offset: waveOffset)
                .fill(
                    LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .opacity(0.5)
                .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: waveOffset)
                .onAppear {
                    withAnimation {
                        self.waveOffset = .degrees(360)
                    }
                }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct WaveShape: Shape {
    var offset: Angle

    var animatableData: Angle.AnimatableData {
        get { offset.radians }
        set { offset = .radians(newValue) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveHeight: CGFloat = 20
        let wavelength = rect.width / 1.5

        path.move(to: CGPoint(x: 0, y: rect.midY))

        for x in stride(from: 0, through: rect.width, by: 1) {
            let angle = Angle(degrees: Double(x) / Double(wavelength) * 360).radians + offset.radians
            let y = rect.midY + sin(angle) * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}
*/
