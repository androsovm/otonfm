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
    @Published var isDefaultArtworkShown: Bool = true // Флаг для отслеживания дефолтной обложки
    private var hasLoadedArtworkOnce = false
    private var hasLoadedRealArtworkOnce = false // Новый флаг: была ли хоть раз реальная обложка
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
        if let defaultImg = UIImage(named: "defaultArtwork") {
            let renderer = UIGraphicsImageRenderer(size: defaultImg.size)
            let roundedImage = renderer.image { context in
                let rect = CGRect(origin: .zero, size: defaultImg.size)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: defaultImg.size.width * 0.062)
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
        request.timeoutInterval = 15
        
        // Добавляем случайный параметр для предотвращения кэширования
        let uniqueURL = URL(string: "\(statusURL.absoluteString)?nocache=\(Date().timeIntervalSince1970)")!
        request = URLRequest(url: uniqueURL)
        
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
                  let artworkURLString = current["artwork_url_large"] as? String,
                  let title = current["title"] as? String else {
                print("⚠️ Не удалось получить URL обложки или название трека")
                return
            }
            
            // Проверяем, соответствует ли текущий трек тому, для которого обновляем обложку
            if !self.currentTrackTitle.isEmpty && title != self.currentTrackTitle && title != self.lastTrackTitle {
                print("⚠️ Обнаружено несоответствие названий треков: API вернул \(title), текущий: \(self.currentTrackTitle)")
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
                        // Если это логотип станции:
                        if isStationLogo {
                            if !self.hasLoadedRealArtworkOnce {
                                self.setDefaultArtwork()
                            } // иначе ничего не делаем, не затираем реальную обложку
                        } else {
                            self.setTrackArtwork(image)
                            self.hasLoadedRealArtworkOnce = true
                        }
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
                self.isDefaultArtworkShown = true
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
            // Проверяем, не дефолтная ли это обложка (или логотип станции)
            var isDefault = false
            if let defaultImg = self.defaultArtwork,
               let data1 = defaultImg.pngData(),
               let data2 = image.pngData(),
               data1 == data2 {
                isDefault = true
            }
            // Если это дефолтная — оставляем флаг true, иначе false
            self.isDefaultArtworkShown = isDefault ? true : false
            print("🆔 Новый ID обложки: \(self.artworkId), isDefaultArtworkShown = \(self.isDefaultArtworkShown)")
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
                            // Сброс флага при смене трека
                            self.hasLoadedRealArtworkOnce = false
                            // Отменяем предыдущую задачу загрузки, если она есть
                            self.artworkLoadingTask?.cancel()
                            self.lastTrackTitle = value
                            
                            // Запрашиваем новую обложку
                            print("🔄 Запрашиваем обложку для трека: \(value)")
                            // Делаем первый запрос сразу, а второй с небольшой задержкой,
                            // т.к. API иногда сначала возвращает старую обложку
                            self.fetchArtworkFromStatusAPI()
                            
                            // Дополнительный запрос через 2 секунды для получения обновленной обложки
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                // Проверяем, что трек не сменился за время задержки
                                if self.currentTrackTitle == value {
                                    print("🔄 Повторный запрос обложки для: \(value)")
                                    self.fetchArtworkFromStatusAPI()
                                }
                            }
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
                Image("otonLogo-Light")
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
    @State private var isPremiumUser = false
    // --- Градиенты Якутии ---
    @State private var currentGradientIndex: Int = Int.random(in: 0..<yakutiaGradients.count)
    @State private var nextGradientIndex: Int = 0
    @State private var gradientTransition: Double = 0.0
    @State private var gradientTimer: Timer? = nil
    
    // Spotify-inspired colors
    private let spotifyGreen = Color(UIColor(red: 0.81, green: 0.17, blue: 0.17, alpha: 1.00))
    private let spotifyBlack = Color(red: 18/255, green: 18/255, blue: 18/255)
    private let spotifyDarkGray = Color(red: 40/255, green: 40/255, blue: 40/255)
    
    // Проверяем статус премиум-подписки при запуске
    private func checkPremiumStatus() {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            if let customerInfo = customerInfo, !customerInfo.entitlements.all.isEmpty {
                self.isPremiumUser = true
                print("Пользователь имеет премиум-подписку")
            } else {
                self.isPremiumUser = false
                print("Пользователь не имеет премиум-подписки")
            }
        }
    }
    
    // Проверяем условия для показа paywall
    private func checkAndShowPaywall() {
        // Сначала проверяем статус премиум-подписки
        checkPremiumStatus()
        
        // Если пользователь не премиум, проверяем условия для показа paywall по дням
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !self.isPremiumUser && AppDelegate.shouldShowPaywall() {
                self.showingPaywall = true
                AppDelegate.markPaywallAsDisplayed()
                print("Показываем paywall на \(AppDelegate.daysSinceFirstLaunch()) день использования")
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Фон: если дефолтная обложка — анимированный градиент, иначе — averageColor
            Group {
                if player.isDefaultArtworkShown {
                    interpolatedGradient()
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.8), value: currentGradientIndex)
                } else {
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
                }
            }
            // Окно успешной покупки
            if showPurchaseSuccess {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(spotifyGreen)
                    
                    Text("Көмөҥ иһин барҕа махтал!")
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
                // Используем ZStack для фиксированного позиционирования элементов
                ZStack {
                    // Структура с фиксированными элементами внизу экрана
                    VStack(spacing: 0) {
                        // Top bar with premium button
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                // Показываем paywall или переключаем режим тестирования при длинном нажатии
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
                            // Добавляем длинное нажатие для активации режима тестирования
                            .onLongPressGesture(minimumDuration: 1.5) {
                                if AppDelegate.isPaywallTestModeEnabled() {
                                    AppDelegate.disablePaywallTestMode()
                                    // Показываем уведомление о выключении режима тестирования
                                    playHapticFeedback(.heavy)
                                } else {
                                    AppDelegate.enablePaywallTestMode()
                                    // Активируем режим тестирования и показываем paywall
                                    playHapticFeedback(.heavy)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        showingPaywall = true
                                    }
                                }
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
                                // Проверяем статус подписки
                                Purchases.shared.getCustomerInfo { (info, _) in
                                    if let info = info, !info.entitlements.all.isEmpty {
                                        self.isPremiumUser = true
                                    }
                                }
                            }) {
                                PaywallView(
                                    fonts: RoundedFontProvider(), 
                                    displayCloseButton: true
                                )
                            }
                        }
                        .padding(.horizontal, UIScreen.main.bounds.width * 0.075)
                        .padding(.top, 20)
                        
                        Spacer()
                        
                        // Центральная часть с обложкой (фиксированный размер)
                        Image(uiImage: player.artworkImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: UIScreen.main.bounds.width * 0.85, height: UIScreen.main.bounds.width * 0.85)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color(player.artworkImage.averageColor ?? .black).opacity(0.6), radius: 25, x: 0, y: 10)
                            .scaleEffect(player.isPlaying && pulsateAnimation ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulsateAnimation)
                            .animation(.easeInOut(duration: 0.6), value: player.artworkId)
                        
                        Spacer()
                        
                        // Нижняя панель с фиксированной высотой для названия трека и кнопки
                        VStack(spacing: 30) {
                            // Название трека - фиксированная высота, поднято на 40pt вверх
                            VStack(alignment: .leading) {
                                ZStack(alignment: .leading) {
                                    if player.isConnecting {
                                        ConnectingText()
                                            .lineLimit(2)
                                            .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                                    } else if player.isPlaying && !player.currentTrackTitle.isEmpty {
                                        Text(player.currentTrackTitle)
                                            .id(player.currentTrackTitle)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(2)
                                            .frame(height: 60, alignment: .leading)
                                            .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                                    } else {
                                        Text("OTON FM")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(2)
                                            .frame(height: 60, alignment: .leading)
                                            .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                                    }
                                }
                                .animation(.easeInOut(duration: 0.5), value: player.isConnecting)
                                .animation(.easeInOut(duration: 0.5), value: player.currentTrackTitle)
                                .animation(.easeInOut(duration: 0.5), value: player.isPlaying)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, UIScreen.main.bounds.width * 0.075)
                            .offset(y: -40) // Поднимаем текст на 40pt вверх
                            
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
                                        
                                        if player.isBuffering && player.isPlaying {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: spotifyBlack))
                                                .scaleEffect(1.2)
                                        } else {
                                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                                .font(.system(size: 30, weight: .bold))
                                                .foregroundColor(spotifyBlack)
                                                .offset(x: player.isPlaying ? 0 : 2)
                                        }
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
                            .padding(.bottom, 30)
                        }
                    }
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
            // Проверяем и показываем paywall если нужно
            checkAndShowPaywall()
            // Запускаем таймер градиентов если дефолтная обложка
            if player.isDefaultArtworkShown {
                startGradientTimer()
            }
        }
        .onChange(of: player.isPlaying) { isPlaying in
            pulsateAnimation = isPlaying
        }
        .onChange(of: player.currentTrackTitle) { _ in
            playHapticFeedback(.medium)
        }
        .onChange(of: player.isDefaultArtworkShown) { isDefault in
            if isDefault {
                // При каждом новом показе дефолтной обложки — случайный стартовый градиент
                let randomIndex = Int.random(in: 0..<yakutiaGradients.count)
                currentGradientIndex = randomIndex
                nextGradientIndex = (randomIndex + 1) % yakutiaGradients.count
                gradientTransition = 0.0
                startGradientTimer()
            } else {
                stopGradientTimer()
            }
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
    
    // --- Методы для смены градиентов ---
    private func startGradientTimer() {
        stopGradientTimer()
        nextGradientIndex = (currentGradientIndex + 1) % yakutiaGradients.count
        gradientTransition = 0.0
        gradientTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 3.0)) {
                gradientTransition = 1.0
            }
            // Через 3 секунды (длительность анимации) переключаем индексы
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                currentGradientIndex = nextGradientIndex
                nextGradientIndex = (currentGradientIndex + 1) % yakutiaGradients.count
                gradientTransition = 0.0
            }
        }
    }
    
    private func stopGradientTimer() {
        gradientTimer?.invalidate()
        gradientTimer = nil
    }
    
    // Получить плавно интерполированный градиент между двумя наборами цветов
    private func interpolatedGradient() -> LinearGradient {
        let from = yakutiaGradients[currentGradientIndex]
        let to = yakutiaGradients[nextGradientIndex]
        
        func lerp(_ a: CGFloat, _ b: CGFloat, t: Double) -> CGFloat {
            return a + (b - a) * CGFloat(t)
        }
        
        func lerpColor(_ a: UIColor, _ b: UIColor, t: Double) -> Color {
            var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
            b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
            return Color(
                red: Double(lerp(ar, br, t: gradientTransition)),
                green: Double(lerp(ag, bg, t: gradientTransition)),
                blue: Double(lerp(ab, bb, t: gradientTransition)),
                opacity: Double(lerp(aa, ba, t: gradientTransition))
            )
        }
        
        let top = lerpColor(from.topColor, to.topColor, t: gradientTransition)
        let bottom = lerpColor(from.bottomColor, to.bottomColor, t: gradientTransition)
        return LinearGradient(
            gradient: Gradient(colors: [top, bottom]),
            startPoint: .top,
            endPoint: .bottom
        )
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

// --- yakutiaGradients ---
fileprivate let yakutiaGradients: [(topColor: UIColor, bottomColor: UIColor, name: String, description: String)] = [
    (UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0), UIColor(red: 0.34, green: 0.71, blue: 0.29, alpha: 1.0), "summerDay", "Летний день в Якутии"),
    (UIColor(red: 0.99, green: 0.55, blue: 0.24, alpha: 1.0), UIColor(red: 0.53, green: 0.27, blue: 0.47, alpha: 1.0), "tundraSunset", "Закат в бескрайней тундре"),
    (UIColor(red: 0.98, green: 0.74, blue: 0.47, alpha: 1.0), UIColor(red: 0.67, green: 0.82, blue: 0.98, alpha: 1.0), "lenaSunrise", "Рассвет над рекой Леной"),
    (UIColor(red: 0.03, green: 0.05, blue: 0.15, alpha: 1.0), UIColor(red: 0.07, green: 0.08, blue: 0.22, alpha: 1.0), "starryNight", "Звездное небо Якутии"),
    (UIColor(red: 0.10, green: 0.20, blue: 0.40, alpha: 1.0), UIColor(red: 0.17, green: 0.54, blue: 0.46, alpha: 1.0), "northernLights", "Северное сияние над якутскими просторами"),
    (UIColor(red: 0.83, green: 0.89, blue: 0.97, alpha: 1.0), UIColor(red: 0.66, green: 0.78, blue: 0.91, alpha: 1.0), "frostyMorning", "Морозное зимнее утро в Якутии"),
    (UIColor(red: 0.24, green: 0.53, blue: 0.24, alpha: 1.0), UIColor(red: 0.18, green: 0.32, blue: 0.14, alpha: 1.0), "summerForest", "Тайга в летнюю пору"),
    (UIColor(red: 0.96, green: 0.87, blue: 0.62, alpha: 1.0), UIColor(red: 0.72, green: 0.55, blue: 0.30, alpha: 1.0), "ysyakh", "Ысыах - праздник лета в Якутии"),
    (UIColor(red: 0.70, green: 0.75, blue: 0.78, alpha: 1.0), UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1.0), "verkhoyansk", "Горы Верхоянского хребта"),
    (UIColor(red: 0.89, green: 0.45, blue: 0.15, alpha: 1.0), UIColor(red: 0.65, green: 0.30, blue: 0.10, alpha: 1.0), "autumnTuymaada", "Осенние краски долины Туймаада"),
    (UIColor(red: 0.25, green: 0.32, blue: 0.45, alpha: 1.0), UIColor(red: 0.16, green: 0.19, blue: 0.28, alpha: 1.0), "yakutianGems", "Драгоценные камни Якутии"),
    (UIColor(red: 0.85, green: 0.88, blue: 0.90, alpha: 1.0), UIColor(red: 0.65, green: 0.70, blue: 0.75, alpha: 1.0), "lenaFog", "Утренний туман над рекой Леной"),
    // Новые градиенты:
    (UIColor(red: 0.99, green: 0.99, blue: 0.85, alpha: 1.0), UIColor(red: 0.60, green: 0.80, blue: 0.98, alpha: 1.0), "polarDay", "Полярный день — светлое небо и холодный воздух"),
    (UIColor(red: 0.60, green: 0.80, blue: 1.0, alpha: 1.0), UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0), "iceFairyTale", "Ледяная сказка — морозные узоры и голубой лёд"),
    (UIColor(red: 0.98, green: 0.80, blue: 0.60, alpha: 1.0), UIColor(red: 0.60, green: 0.30, blue: 0.18, alpha: 1.0), "warmChum", "Тёплый чум — уют и тепло в зимней ночи"),
    (UIColor(red: 0.60, green: 0.80, blue: 0.60, alpha: 1.0), UIColor(red: 0.30, green: 0.50, blue: 0.70, alpha: 1.0), "summerRain", "Летний дождь — свежесть зелени и прохлада воды"),
    (UIColor(red: 0.40, green: 0.60, blue: 0.30, alpha: 1.0), UIColor(red: 0.80, green: 0.95, blue: 0.70, alpha: 1.0), "fairyForest", "Сказочный лес — мягкая зелень и солнечные лучи"),
    (UIColor(red: 0.98, green: 0.70, blue: 0.30, alpha: 1.0), UIColor(red: 0.60, green: 0.30, blue: 0.10, alpha: 1.0), "amberEvening", "Янтарный вечер — тёплый свет заката"),
    (UIColor(red: 0.98, green: 0.60, blue: 0.80, alpha: 1.0), UIColor(red: 0.60, green: 0.80, blue: 0.98, alpha: 1.0), "pinkDawn", "Розовый рассвет — нежные облака и голубое небо"),
    (UIColor(red: 0.70, green: 0.90, blue: 1.0, alpha: 1.0), UIColor(red: 0.30, green: 0.60, blue: 0.80, alpha: 1.0), "blueIce", "Голубой лёд — прозрачность и свежесть зимы"),
    (UIColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1.0), UIColor(red: 0.98, green: 0.80, blue: 0.60, alpha: 1.0), "ornament", "Традиционный орнамент — красные и золотые мотивы"),
    (UIColor(red: 0.98, green: 0.60, blue: 0.30, alpha: 1.0), UIColor(red: 0.30, green: 0.10, blue: 0.05, alpha: 1.0), "cozyFire", "Уютный костёр — тепло и свет в зимнем лесу")
]


