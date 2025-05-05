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
import RevenueCat
import RevenueCatUI

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
    @State private var pulseAnimation = false
    @Binding var isActive: Bool
    
    // Spotify-inspired colors
    private let spotifyBlack = Color(red: 18/255, green: 18/255, blue: 18/255)
    private let spotifyGreen = Color(red: 30/255, green: 215/255, blue: 96/255)

    var body: some View {
        ZStack {
            // Dark gradient background like Spotify
            LinearGradient(
                gradient: Gradient(colors: [
                    spotifyBlack,
                    Color(red: 25/255, green: 20/255, blue: 20/255)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Optional: subtle radial gradient around the logo
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 208/255, green: 0, blue: 0).opacity(0.3),
                    Color.clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 180
            )
            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
            .opacity(pulseAnimation ? 0.7 : 0.3)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: pulseAnimation
            )

            VStack(spacing: 20) {
                Image("otonLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .scaleEffect(animate ? 1.1 : 0.9)
                    .opacity(animate ? 1 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 1.2)
                            .repeatCount(1, autoreverses: false),
                        value: animate
                    )
                
                Text("OTON.FM")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(5)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 10)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .delay(0.3),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
            pulseAnimation = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isActive = false
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ContentView: View {
    @StateObject private var player = RadioPlayer.shared
    @State private var isInterfaceVisible = false
    @State private var isPressed = false
    @State private var pulsateAnimation = false
    @State private var hapticEngine: CHHapticEngine?
    @State private var showingPaywall = false
    @State private var showPurchaseSuccess = false
    
    // Spotify-inspired colors
    private let spotifyGreen = Color(red: 30/255, green: 215/255, blue: 96/255)
    private let spotifyBlack = Color(red: 18/255, green: 18/255, blue: 18/255)
    private let spotifyDarkGray = Color(red: 40/255, green: 40/255, blue: 40/255)
    
    var body: some View {
        ZStack {
            // Gradient background like Spotify
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(player.artworkImage.averageColor ?? UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1.0)).opacity(0.8),
                    spotifyBlack
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: player.artworkId)
            
            // Окно успешной покупки
            if showPurchaseSuccess {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(spotifyGreen)
                    
                    Text("Спасибо за покупку!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Спасибо за покупку!")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        withAnimation {
                            showPurchaseSuccess = false
                        }
                    }) {
                        Text("Продолжить")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(spotifyGreen)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 10)
                }
                .padding(30)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }

            if isInterfaceVisible {
                VStack(spacing: 0) {
                    // Top bar with premium button
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showingPaywall = true
                        }) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .sheet(isPresented: $showingPaywall, onDismiss: {
                            // Проверяем статус подписок после закрытия Paywall
                            Purchases.shared.getCustomerInfo { (customerInfo, error) in
                                if error == nil {
                                    let hasChanged = customerInfo?.entitlements.active.count ?? 0 > 0 && 
                                                    customerInfo?.nonSubscriptions.count ?? 0 > 0 &&
                                                    customerInfo?.nonSubscriptions.last?.purchaseDate.timeIntervalSinceNow ?? 0 > -10
                                    
                                    if hasChanged {
                                        // Показываем экран успешной покупки только если покупка была только что совершена
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showPurchaseSuccess = true
                                        }
                                    }
                                }
                            }
                        }) {
                            PaywallView(
                                fonts: RoundedFontProvider(), 
                                displayCloseButton: true
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Artwork - large, like Spotify
                    Image(uiImage: player.artworkImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: UIScreen.main.bounds.width * 0.85, height: UIScreen.main.bounds.width * 0.85)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color(player.artworkImage.averageColor ?? .black).opacity(0.6), radius: 25, x: 0, y: 10)
                        .scaleEffect(player.isPlaying && pulsateAnimation ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulsateAnimation)
                        .padding(.bottom, 50)
                        .animation(.easeInOut(duration: 0.6), value: player.artworkId)
                    
                    Spacer()
                    
                    // Title and station info section
                    VStack(alignment: .leading, spacing: 10) {
                        if player.isConnecting {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                    .frame(height: 60)
                                Spacer()
                            }
                        } else {
                            Text(player.currentTrackTitle)
                                .id(player.currentTrackTitle)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.5), value: player.currentTrackTitle)
                            
                            Text("Oton.FM Live")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 25)
                    
                    // Player controls section (Spotify styled)
                    VStack(spacing: 25) {
                        // Buffer indicator
                        if player.isBuffering {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.0)
                                Text("Буферизация...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.bottom, 5)
                        }
                        
                        // Play/Pause button
                        HStack {
                            Spacer()
                            
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
                                        .fill(Color.white)
                                        .frame(width: 64, height: 64)
                                    
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(spotifyBlack)
                                        .offset(x: player.isPlaying ? 0 : 2)
                                }
                                .scaleEffect(isPressed ? 0.9 : 1.0)
                                .animation(.easeOut(duration: 0.2), value: isPressed)
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
                            
                            Spacer()
                        }
                        
                        // Devices/Cast button (like Spotify)
                        HStack {
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
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
        .preferredColorScheme(.dark) // Spotify всегда использует темную тему
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

// Font provider для PaywallView
struct RoundedFontProvider: PaywallFontProvider {
    func font(for textStyle: Font.TextStyle) -> Font {
        switch textStyle {
        case .largeTitle:
            return Font.system(size: 34, weight: .bold, design: .rounded)
        case .title:
            return Font.system(size: 28, weight: .bold, design: .rounded)
        case .title2:
            return Font.system(size: 22, weight: .bold, design: .rounded)
        case .title3:
            return Font.system(size: 20, weight: .semibold, design: .rounded)
        case .headline:
            return Font.system(size: 17, weight: .semibold, design: .rounded)
        case .body:
            return Font.system(size: 17, weight: .regular, design: .rounded)
        case .callout:
            return Font.system(size: 16, weight: .regular, design: .rounded)
        case .subheadline:
            return Font.system(size: 15, weight: .regular, design: .rounded)
        case .footnote:
            return Font.system(size: 13, weight: .regular, design: .rounded)
        case .caption:
            return Font.system(size: 12, weight: .regular, design: .rounded)
        case .caption2:
            return Font.system(size: 11, weight: .regular, design: .rounded)
        @unknown default:
            return Font.system(size: 17, weight: .regular, design: .rounded)
        }
    }
}


