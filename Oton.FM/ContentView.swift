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
import CoreHaptics

class RadioPlayer: NSObject, ObservableObject {
    static let shared = RadioPlayer()
    private var player: AVPlayer?
    private let defaultArtwork = UIImage(named: "defaultArtwork") // Исходное изображение заставки без обработки
    @Published var isPlaying = false
    @Published var currentTrackTitle: String = ""
    @Published var artworkImage: UIImage
    @Published var artworkId: UUID = UUID() // Добавляем ID для отслеживания изменений
    @Published var isConnecting: Bool = false
    @Published var isBuffering: Bool = false // Новое свойство для отображения состояния буферизации
    private var hasLoadedArtworkOnce = false
    private var artworkLoadingTask: URLSessionDataTask?
    private var lastTrackTitle: String = ""
    private var retryCount = 0
    private let maxRetries = 3
    private var bufferObservers: [NSKeyValueObservation] = []
    private var bufferingRestartWorkItem: DispatchWorkItem? = nil
    private var autoRestartAttempts = 0
    private let maxAutoRestartAttempts = 3
    private let bufferingTimeout: TimeInterval = 8.0

    private override init() {
        // Создаем копию дефолтного изображения и добавляем обработку чтобы правильно отображались углы
        if let defaultImg = UIImage(named: "defaultArtwork") {
            let renderer = UIGraphicsImageRenderer(size: defaultImg.size)
            let roundedImage = renderer.image { context in
                let rect = CGRect(origin: .zero, size: defaultImg.size)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: defaultImg.size.width * 0.062) // ~16 для изображения 260x260
                path.addClip()
                defaultImg.draw(in: rect)
            }
            self.artworkImage = roundedImage
        } else {
            self.artworkImage = UIImage()
        }
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
        // Настройка буфера: 20 секунд
        player?.currentItem?.preferredForwardBufferDuration = 20
        // Удаляем старые наблюдатели
        bufferObservers.forEach { $0.invalidate() }
        bufferObservers.removeAll()
        // Добавляем KVO на буферизацию
        if let item = player?.currentItem {
            let obs1 = item.observe(\AVPlayerItem.isPlaybackBufferEmpty, options: [.new, .initial]) { [weak self] item, change in
                DispatchQueue.main.async {
                    if item.isPlaybackBufferEmpty {
                        self?.isBuffering = true
                        print("[Buffer] Буфер пуст, начинается буферизация...")
                        self?.scheduleBufferingRestart()
                    }
                }
            }
            let obs2 = item.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp, options: [.new, .initial]) { [weak self] item, change in
                DispatchQueue.main.async {
                    if item.isPlaybackLikelyToKeepUp {
                        self?.isBuffering = false
                        print("[Buffer] Буфер наполнен, продолжаем воспроизведение.")
                        self?.cancelBufferingRestart()
                        self?.autoRestartAttempts = 0 // Сброс попыток при восстановлении
                    }
                }
            }
            bufferObservers.append(contentsOf: [obs1, obs2])
        }
        player?.currentItem?.addObserver(self, forKeyPath: "timedMetadata", options: [.new, .initial], context: nil)
        player?.play()
        fetchArtworkFromStatusAPI()
        setupNowPlaying()
        setupRemoteCommandCenter()
        
        // Установка isPlaying в true до получения метаданных
        // чтобы активировать пульсацию сразу
        DispatchQueue.main.async {
            self.isPlaying = true
        }
    }

    private func fetchArtworkFromStatusAPI() {
        let statusURL = URL(string: "https://public.radio.co/stations/s696f24a77/status")!
        var request = URLRequest(url: statusURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15 // Увеличиваем таймаут до 10 секунд
        
        // Создаем новую сессию без кэширования для обновления данных
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        let session = URLSession(configuration: config)
        
        // Отменяем предыдущую задачу, если она есть
        artworkLoadingTask?.cancel()
        
        artworkLoadingTask = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Ошибка получения статуса: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("⚠️ Нет данных статуса")
                return
            }
            
            print("🧩 Получены новые данные о треке")
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current_track"] as? [String: Any],
                  let artworkURLString = current["artwork_url_large"] as? String else {
                print("⚠️ Не удалось получить URL обложки")
                return
            }

            print("🎨 Получен artwork URL: \(artworkURLString)")
            
            // Принудительно добавляем timestamp к URL для избежания кэширования
            let timestamp = Date().timeIntervalSince1970
            let cacheBustingURLString = "\(artworkURLString)?nocache=\(timestamp)"
            guard let imageURL = URL(string: cacheBustingURLString) else {
                print("⚠️ Неверный URL обложки")
                return
            }
            
            print("🔄 Запрос изображения: \(cacheBustingURLString)")
            
            // Новый запрос для изображения без кэширования
            var imageRequest = URLRequest(url: imageURL)
            imageRequest.cachePolicy = .reloadIgnoringLocalCacheData
            imageRequest.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
            imageRequest.timeoutInterval = 10
            
            let imageTask = session.dataTask(with: imageRequest) { [weak self] imageData, imageResponse, imageError in
                guard let self = self else { return }
                
                print("📷 Получен ответ на запрос изображения")
                
                if let error = imageError {
                    print("❌ Ошибка загрузки изображения: \(error.localizedDescription)")
                    
                    if self.retryCount < self.maxRetries {
                        self.retryCount += 1
                        print("🔄 Повторная попытка загрузки (\(self.retryCount)/\(self.maxRetries))")
                        
                        let delay = Double(self.retryCount) * 2.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.fetchArtworkFromStatusAPI()
                        }
                    } else {
                        print("⚠️ Превышено максимальное количество попыток загрузки")
                        self.retryCount = 0
                    }
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
                        
                        // Обновляем обложку в любом случае
                        self.setTrackArtwork(image)
                        self.retryCount = 0
                    }
                }
            }
            imageTask.resume()
        }
        artworkLoadingTask?.resume()
    }

    private func setDefaultArtwork() {
        DispatchQueue.main.async {
            if let defaultImg = self.defaultArtwork {
                let renderer = UIGraphicsImageRenderer(size: defaultImg.size)
                let roundedImage = renderer.image { context in
                    let rect = CGRect(origin: .zero, size: defaultImg.size)
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: defaultImg.size.width * 0.062)
                    path.addClip()
                    defaultImg.draw(in: rect)
                }
                self.artworkImage = roundedImage
                self.artworkId = UUID()
                
                let artwork = MPMediaItemArtwork(boundsSize: roundedImage.size) { _ in roundedImage }
                MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = artwork
                print("🎵 Установлено дефолтное изображение")
            }
        }
    }
    
    private func setTrackArtwork(_ image: UIImage) {
        DispatchQueue.main.async {
            let renderer = UIGraphicsImageRenderer(size: image.size)
            let roundedImage = renderer.image { context in
                let rect = CGRect(origin: .zero, size: image.size)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: image.size.width * 0.062)
                path.addClip()
                image.draw(in: rect)
            }
            
            self.artworkImage = roundedImage
            self.artworkId = UUID()
            print("🆔 Новый ID обложки: \(self.artworkId)")
            
            let artwork = MPMediaItemArtwork(boundsSize: roundedImage.size) { _ in roundedImage }
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = artwork
            print("🎵 Обновлено изображение трека")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        isBuffering = false
        cancelBufferingRestart()
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
                            
                            // Отменяем предыдущую задачу загрузки, если она есть
                            self.artworkLoadingTask?.cancel()
                            
                            // Запрашиваем новую обложку
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

    private func scheduleBufferingRestart() {
        cancelBufferingRestart()
        guard autoRestartAttempts < maxAutoRestartAttempts else {
            print("[Buffer] Достигнут лимит автоматических попыток рестарта потока.")
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.isBuffering {
                self.autoRestartAttempts += 1
                print("[Buffer] Автоматический рестарт потока (попытка \(self.autoRestartAttempts)/\(self.maxAutoRestartAttempts))...")
                self.player?.pause()
                self.playStream()
            }
        }
        bufferingRestartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + bufferingTimeout, execute: workItem)
    }

    private func cancelBufferingRestart() {
        bufferingRestartWorkItem?.cancel()
        bufferingRestartWorkItem = nil
    }

    deinit {
        bufferObservers.forEach { $0.invalidate() }
        bufferObservers.removeAll()
        cancelBufferingRestart()
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
    @State private var pulsateAnimation = false
    @State private var hapticEngine: CHHapticEngine?
    
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
                        .frame(width: 300, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(player.artworkImage.averageColor ?? .black).opacity(0.5), radius: 20, x: 0, y: 10)
                        .scaleEffect(player.isPlaying && pulsateAnimation ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulsateAnimation)
                        .opacity(1.0)
                        .animation(.easeInOut(duration: 0.5), value: player.artworkId)

                    Group {
                        if player.isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: player.artworkImage.averageColor?.isLightColor == true ? .black : .white))
                                .frame(height: 50)
                        } else {
                            Text(player.currentTrackTitle)
                                .id(player.currentTrackTitle)
                                .font(.headline)
                                .foregroundColor(player.artworkImage.averageColor?.isLightColor == true ? .black : .white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 50)
                                .padding(.horizontal)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.5), value: player.currentTrackTitle)
                        }
                    }

                    Button(action: {
                        playComplexHaptic()
                        
                        if player.isPlaying {
                            player.pause()
                        } else {
                            player.playStream()
                        }
                        pulsateAnimation = player.isPlaying
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(player.artworkImage.averageColor ?? .white).opacity(0.5))
                                .blur(radius: 20)
                                .frame(width: 120, height: 120)
                                .scaleEffect(player.isPlaying ? 1.3 : 1.0)
                                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: player.isPlaying)
                            
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
                            .onChanged { _ in 
                                isPressed = true
                                playHapticFeedback(.light)
                            }
                            .onEnded { _ in 
                                isPressed = false
                                playHapticFeedback(.light)
                            }
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
            pulsateAnimation = player.isPlaying
        }
        .onChange(of: player.isPlaying) { isPlaying in
            pulsateAnimation = isPlaying
        }
        .onChange(of: player.currentTrackTitle) { _ in
            playHapticFeedback(.medium)
        }
        .onAppear(perform: prepareHaptics)
    }
    
    // Подготавливаем haptic engine
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Ошибка при создании haptic engine: \(error.localizedDescription)")
        }
    }
    
    // Воспроизводим простой тактильный отклик
    private func playHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // Воспроизводим более сложный паттерн тактильного отклика
    private func playComplexHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }
        
        // Создаем интенсивность события
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
        
        // Создаем события
        let event1 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        let event2 = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        ], relativeTime: 0.1, duration: 0.2)
        
        do {
            let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Не удалось воспроизвести тактильный паттерн: \(error.localizedDescription)")
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


