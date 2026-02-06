# Oton.FM v2 -- Архитектурный документ

> Архитектура нового приложения Oton.FM, основанная на анализе текущей версии и её технического долга.
> Целевая платформа: iOS 17+. Язык: Swift. UI-фреймворк: SwiftUI.

---

## 1. Принципы архитектуры

### Почему нужна новая архитектура

Текущая версия Oton.FM накопила значительный технический долг:

1. **God Object `RadioPlayer`** -- один класс совмещает функции ViewModel, сервиса загрузки обложек, менеджера Now Playing, менеджера метаданных и обработчика хаптиков. Это нарушает Single Responsibility Principle и делает код трудным для тестирования и поддержки.

2. **Смешение слоёв** -- `RadioPlayer` определён внутри `ContentView.swift`, ViewModel и View живут в одном файле.

3. **Синглтон `RadioPlayer.shared`** -- затрудняет тестирование и подмену зависимостей.

4. **Лишний промежуточный слой `AudioServiceWrapper`** -- конвертирует Combine publishers в callbacks, что является артефактом миграции, а не осознанным архитектурным решением.

5. **Устаревшие паттерны** -- `ObservableObject` + `@Published` + `@StateObject` вместо современного `@Observable` (iOS 17+). KVO для timed metadata вместо async/await.

6. **Ручной парсинг JSON** -- `JSONSerialization` вместо `Codable`-моделей, которые уже определены, но не используются.

7. **Отсутствие обработки ошибок в UI** -- `ErrorView` создан, но не подключён к основному экрану.

8. **Проблемы с безопасностью** -- API-ключ RevenueCat захардкожен в коде и закоммичен в репозиторий.

### Ключевые принципы новой архитектуры

| Принцип | Описание |
|---------|----------|
| **Single Responsibility** | Каждый сервис отвечает за одну задачу. Никаких God Object. |
| **Dependency Injection** | Зависимости передаются через SwiftUI Environment -- легко подменять для тестов. |
| **@Observable (iOS 17+)** | Современный observation framework вместо ObservableObject/Combine. |
| **async/await** | Современная конкурентность вместо callbacks и DispatchQueue.main.asyncAfter. |
| **State Machine** | Явный конечный автомат для состояний аудио -- предсказуемые переходы, невозможность невалидных состояний. |
| **Typed Errors** | Строго типизированные ошибки с recovery actions. |
| **Testability** | Протоколы для всех сервисов, mock-реализации для тестов. |
| **Feature Modules** | Код организован по фичам, а не по типам файлов. |

---

## 2. Минимальная версия iOS

**iOS 17.0+**

Обоснование:
- `@Observable` macro -- замена ObservableObject, меньше boilerplate, автоматическое отслеживание зависимостей
- `NavigationStack` -- современная навигация (на будущее, если появятся дополнительные экраны)
- `onChange(of:)` с новой сигнатурой (без deprecated старого варианта)
- `.sensoryFeedback()` -- декларативные хаптики прямо в SwiftUI
- `PhaseAnimator` / `KeyframeAnimator` -- мощные анимации без ручных Timer
- `ShapeStyle` improvements -- упрощённая работа с градиентами
- Swift Concurrency полностью стабилен
- По данным Apple, iOS 17+ покрывает более 90% активных устройств в 2025 году

---

## 3. Структура проекта

```
OtonFM/
├── App/
│   ├── OtonFMApp.swift              # @main точка входа
│   ├── AppDelegate.swift            # UIApplicationDelegate (RevenueCat init)
│   └── AppEnvironment.swift         # DI-контейнер, настройка Environment
│
├── Core/
│   ├── Config.swift                 # Конфигурация (URLs, station ID)
│   ├── Constants.swift              # Все магические числа в одном месте
│   ├── Extensions/
│   │   ├── UIImage+AverageColor.swift
│   │   ├── UIColor+IsLight.swift
│   │   └── Color+Theme.swift        # Цветовая палитра приложения
│   └── Protocols/
│       └── ServiceProtocols.swift   # Базовые протоколы сервисов
│
├── Features/
│   ├── Player/
│   │   ├── PlayerViewModel.swift    # @Observable, логика экрана плеера
│   │   ├── PlayerView.swift         # Основной экран плеера (бывший ContentView)
│   │   ├── Components/
│   │   │   ├── ArtworkView.swift    # Обложка с пульсацией и тенью
│   │   │   ├── TrackInfoView.swift  # Название трека / "Холбонуу..."
│   │   │   ├── PlayerControlsView.swift  # Кнопка Play/Pause
│   │   │   └── AnimatedDots.swift   # Компонент анимированных точек
│   │   └── Models/
│   │       └── PlayerDisplayState.swift  # UI-модель состояния плеера
│   │
│   ├── Subscription/
│   │   ├── SubscriptionViewModel.swift
│   │   ├── PaywallContainerView.swift   # Обёртка над RevenueCatUI PaywallView
│   │   ├── PurchaseSuccessView.swift    # Экран благодарности за покупку
│   │   └── Models/
│   │       └── PaywallConfig.swift      # Логика показа paywall (дни, тест-режим)
│   │
│   ├── Splash/
│   │   └── SplashView.swift         # Загрузочный экран
│   │
│   └── Error/
│       └── ErrorView.swift          # Экран ошибки с кнопкой повтора
│
├── Services/
│   ├── Audio/
│   │   ├── AudioEngine.swift        # AVPlayer, state machine, буферизация
│   │   ├── AudioEngineProtocol.swift # Протокол для DI и тестов
│   │   └── AudioState.swift         # Enum состояний + переходы
│   │
│   ├── Metadata/
│   │   ├── MetadataService.swift    # Timed metadata + Status API polling
│   │   ├── MetadataServiceProtocol.swift
│   │   └── MetadataModels.swift     # TrackInfo, RadioStatusResponse (Codable)
│   │
│   ├── Artwork/
│   │   ├── ArtworkService.swift     # Загрузка, кэширование, определение типа
│   │   ├── ArtworkServiceProtocol.swift
│   │   └── ArtworkModels.swift      # ArtworkResult, ArtworkType
│   │
│   ├── NowPlaying/
│   │   ├── NowPlayingService.swift  # MPNowPlayingInfoCenter + Remote Commands
│   │   └── NowPlayingServiceProtocol.swift
│   │
│   ├── Subscription/
│   │   ├── SubscriptionService.swift    # RevenueCat обёртка
│   │   └── SubscriptionServiceProtocol.swift
│   │
│   ├── Haptics/
│   │   ├── HapticService.swift      # Все haptic-паттерны в одном месте
│   │   └── HapticServiceProtocol.swift
│   │
│   └── Network/
│       ├── NetworkClient.swift      # Единый URLSession, async/await
│       └── NetworkClientProtocol.swift
│
├── UI/
│   ├── Theme/
│   │   ├── AppColors.swift          # Цветовая палитра (spotifyBlack -> otonBlack)
│   │   └── AppFonts.swift           # Типографика + RoundedFontProvider
│   ├── Gradients/
│   │   ├── YakutiaGradients.swift   # 25 градиентов с точными цветами
│   │   └── GradientAnimator.swift   # Логика интерполяции и таймера
│   └── Modifiers/
│       └── PulsationModifier.swift  # ViewModifier для пульсации обложки
│
├── Resources/
│   ├── Assets.xcassets/             # Изображения, цвета, иконка
│   ├── Localizable.xcstrings        # Локализация (якутский, русский)
│   └── Oton-FM-Info.plist
│
└── Tests/
    ├── UnitTests/
    │   ├── Services/
    │   │   ├── AudioEngineTests.swift
    │   │   ├── MetadataServiceTests.swift
    │   │   ├── ArtworkServiceTests.swift
    │   │   └── SubscriptionServiceTests.swift
    │   ├── ViewModels/
    │   │   ├── PlayerViewModelTests.swift
    │   │   └── SubscriptionViewModelTests.swift
    │   └── Mocks/
    │       ├── MockAudioEngine.swift
    │       ├── MockMetadataService.swift
    │       ├── MockArtworkService.swift
    │       ├── MockNowPlayingService.swift
    │       ├── MockSubscriptionService.swift
    │       └── MockNetworkClient.swift
    ├── IntegrationTests/
    │   └── AudioMetadataIntegrationTests.swift
    └── SnapshotTests/
        ├── PlayerViewSnapshotTests.swift
        └── SplashViewSnapshotTests.swift
```

---

## 4. Архитектурный паттерн

### Modern SwiftUI с @Observable

Архитектура использует паттерн **Modern SwiftUI** с чётким разделением на слои:

```
┌─────────────────────────────────────────────────────┐
│                    View Layer                        │
│  (SwiftUI Views -- чистое отображение)               │
│  PlayerView, ArtworkView, TrackInfoView, ...        │
└────────────────────┬────────────────────────────────┘
                     │ @Observable
┌────────────────────▼────────────────────────────────┐
│                ViewModel Layer                       │
│  (Бизнес-логика экрана, координация сервисов)       │
│  PlayerViewModel, SubscriptionViewModel             │
└────────────────────┬────────────────────────────────┘
                     │ protocols (DI)
┌────────────────────▼────────────────────────────────┐
│                Service Layer                         │
│  (Независимые сервисы, каждый -- одна ответственность)│
│  AudioEngine, MetadataService, ArtworkService, ...  │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│              Infrastructure Layer                    │
│  (AVFoundation, URLSession, MediaPlayer, RevenueCat)│
└─────────────────────────────────────────────────────┘
```

### @Observable вместо ObservableObject

```swift
// БЫЛО (v1): ObservableObject + @Published + @StateObject
class RadioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrackTitle = ""
    // ... 15+ @Published свойств в одном классе
}

struct ContentView: View {
    @StateObject private var player = RadioPlayer.shared
}

// СТАЛО (v2): @Observable + разделение на ViewModel + Services
@Observable
final class PlayerViewModel {
    // Свойства отслеживаются автоматически
    var isPlaying = false
    var currentTrackTitle = ""
    var artworkImage: UIImage?
    var displayState: PlayerDisplayState = .idle

    private let audioEngine: AudioEngineProtocol
    private let metadataService: MetadataServiceProtocol
    private let artworkService: ArtworkServiceProtocol

    init(
        audioEngine: AudioEngineProtocol,
        metadataService: MetadataServiceProtocol,
        artworkService: ArtworkServiceProtocol
    ) {
        self.audioEngine = audioEngine
        self.metadataService = metadataService
        self.artworkService = artworkService
    }
}

struct PlayerView: View {
    @State private var viewModel: PlayerViewModel

    init(viewModel: PlayerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
}
```

### Dependency Injection через Environment

```swift
// Контейнер зависимостей
@Observable
final class AppEnvironment {
    let audioEngine: AudioEngineProtocol
    let metadataService: MetadataServiceProtocol
    let artworkService: ArtworkServiceProtocol
    let nowPlayingService: NowPlayingServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol
    let hapticService: HapticServiceProtocol
    let networkClient: NetworkClientProtocol

    init() {
        // Production dependencies
        let network = NetworkClient()
        self.networkClient = network
        self.audioEngine = AudioEngine()
        self.metadataService = MetadataService(networkClient: network)
        self.artworkService = ArtworkService(networkClient: network)
        self.nowPlayingService = NowPlayingService()
        self.subscriptionService = SubscriptionService()
        self.hapticService = HapticService()
    }

    // Для тестов
    init(
        audioEngine: AudioEngineProtocol,
        metadataService: MetadataServiceProtocol,
        artworkService: ArtworkServiceProtocol,
        nowPlayingService: NowPlayingServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        hapticService: HapticServiceProtocol,
        networkClient: NetworkClientProtocol
    ) {
        self.audioEngine = audioEngine
        self.metadataService = metadataService
        self.artworkService = artworkService
        self.nowPlayingService = nowPlayingService
        self.subscriptionService = subscriptionService
        self.hapticService = hapticService
        self.networkClient = networkClient
    }
}

// Точка входа
@main
struct OtonFMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var environment = AppEnvironment()
    @State private var isSplashActive = true

    var body: some Scene {
        WindowGroup {
            if isSplashActive {
                SplashView(isActive: $isSplashActive)
            } else {
                PlayerView(
                    viewModel: PlayerViewModel(
                        audioEngine: environment.audioEngine,
                        metadataService: environment.metadataService,
                        artworkService: environment.artworkService
                    )
                )
                .environment(environment)
            }
        }
    }
}
```

---

## 5. Диаграмма потока данных

### Основной поток: от нажатия Play до отображения трека

```
Пользователь
    │
    │ нажимает Play
    ▼
┌──────────────────┐
│   PlayerView     │ ─── вызывает viewModel.play()
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     ┌───────────────────┐
│ PlayerViewModel  │────▶│  HapticService    │ (тактильный отклик)
│                  │     └───────────────────┘
│  координирует:   │
│                  │     ┌───────────────────┐
│  1. Запуск аудио │────▶│  AudioEngine      │
│                  │     │  .play(url)       │
│                  │     │                   │
│                  │◀────│  state: .connecting│──▶ AVPlayer
│                  │◀────│  state: .playing  │    │
│                  │◀────│  state: .error    │    │ ICY metadata
│                  │     └───────────────────┘    │
│                  │                               │
│  2. Метаданные   │     ┌───────────────────┐    │
│                  │◀────│ MetadataService   │◀───┘
│                  │     │  timed metadata   │
│                  │     │  + Status API     │──▶ radio.co/status
│                  │     └───────────────────┘
│                  │
│  3. Обложка      │     ┌───────────────────┐
│                  │────▶│  ArtworkService   │──▶ загрузка изображения
│                  │◀────│  image + type     │
│                  │     └───────────────────┘
│                  │
│  4. Now Playing  │     ┌───────────────────┐
│                  │────▶│ NowPlayingService │──▶ MPNowPlayingInfoCenter
│                  │     │  title + artwork  │──▶ MPRemoteCommandCenter
│                  │     └───────────────────┘
│                  │
│  обновляет:      │
│  - isPlaying     │
│  - trackTitle    │
│  - artworkImage  │
│  - displayState  │
└────────┬─────────┘
         │ @Observable (автоматическое обновление)
         ▼
┌──────────────────┐
│   PlayerView     │
│   ├─ ArtworkView │ (обложка + тень + пульсация)
│   ├─ TrackInfoView│ (название / "Холбонуу..." / "OTON FM")
│   ├─ PlayerControlsView │ (кнопка Play/Pause)
│   └─ GradientBackground │ (Якутия / адаптивный)
└──────────────────┘
```

### Поток метаданных (детально)

```
AVPlayer (ICY stream)
    │
    │ timed metadata (KVO / AsyncSequence)
    ▼
┌──────────────────────┐
│   MetadataService    │
│                      │
│  1. Извлечь title    │
│     из AVMetadataItem│
│                      │
│  2. Если "OtonFM" -> │──▶ ArtworkService.loadStationLogo()
│     иначе ->         │──▶ ArtworkService.loadFromAPI(title:)
│                      │         │
│  3. Emit TrackUpdate │         │
└──────────┬───────────┘         │
           │                     ▼
           │              ┌──────────────────────┐
           │              │   ArtworkService     │
           │              │                      │
           │              │  1. GET /status       │
           │              │     ?nocache=ts       │
           │              │                      │
           │              │  2. Проверка title    │
           │              │     match             │
           │              │                      │
           │              │  3. GET artwork_url   │
           │              │     ?nocache=ts       │
           │              │                      │
           │              │  4. Определить тип:   │
           │              │     stationLogo /     │
           │              │     realArtwork       │
           │              │                      │
           │              │  5. Вернуть           │
           │              │     ArtworkResult     │
           │              └──────────┬────────────┘
           │                         │
           ▼                         ▼
    ┌──────────────────────────────────┐
    │       PlayerViewModel            │
    │                                  │
    │  Обновить:                       │
    │  - currentTrackTitle             │
    │  - artworkImage                  │
    │  - isDefaultArtworkShown         │
    │  - hasLoadedRealArtworkOnce      │
    │  - фоновый градиент             │
    │                                  │
    │  Вызвать:                        │
    │  - NowPlayingService.update()    │
    │  - HapticService.trackChanged()  │
    └──────────────────────────────────┘
```

---

## 6. Сервисный слой

### 6.1 AudioEngine

Отвечает за: управление AVPlayer, буферизация, переподключение, аудиосессия.

```swift
protocol AudioEngineProtocol: Sendable {
    var state: AudioState { get }
    var stateStream: AsyncStream<AudioState> { get }
    var metadataStream: AsyncStream<[AVMetadataItem]> { get }

    func play(url: URL) async
    func pause()
    func stop()
}
```

**Ключевые отличия от v1:**
- Нет синглтона -- создаётся через DI
- `AsyncStream` вместо Combine publishers и callbacks
- Встроенная state machine (см. раздел 7)
- Обработка прерываний аудиосессии (входящий звонок, Siri, наушники)
- `AVAudioSession.interruptionNotification` -- пауза при прерывании, возобновление после
- `AVAudioSession.routeChangeNotification` -- пауза при отключении наушников

### 6.2 MetadataService

Отвечает за: извлечение метаданных трека из timed metadata и Status API.

```swift
protocol MetadataServiceProtocol: Sendable {
    func trackTitle(from metadata: [AVMetadataItem]) -> String?
    func fetchCurrentTrack() async throws -> TrackInfo
}
```

**Модели:**
```swift
struct TrackInfo: Codable, Equatable, Sendable {
    let title: String
    let artworkUrlLarge: String?

    enum CodingKeys: String, CodingKey {
        case title
        case artworkUrlLarge = "artwork_url_large"
    }
}

struct RadioStatusResponse: Codable, Sendable {
    let currentTrack: TrackInfo?

    enum CodingKeys: String, CodingKey {
        case currentTrack = "current_track"
    }
}
```

**Ключевые отличия от v1:**
- Использует `Codable` вместо `JSONSerialization`
- `async throws` вместо callbacks
- Переиспользует единый `NetworkClient`

### 6.3 ArtworkService

Отвечает за: загрузка обложек, кэширование, определение типа (логотип станции / реальная обложка).

```swift
protocol ArtworkServiceProtocol: Sendable {
    func loadArtwork(for track: TrackInfo) async -> ArtworkResult
    func loadStationLogo() -> ArtworkResult
    var defaultArtwork: UIImage { get }
}

struct ArtworkResult: Sendable {
    let image: UIImage
    let type: ArtworkType
    let averageColor: UIColor?
}

enum ArtworkType: Sendable {
    case realArtwork       // Реальная обложка трека
    case stationLogo       // Логотип станции (OtonFM)
    case defaultArtwork    // Дефолтная обложка из ассетов
}
```

**Ключевые отличия от v1:**
- Кэширование среднего цвета -- `averageColor` вычисляется один раз при загрузке и сохраняется в `ArtworkResult`
- Retry-логика: до 3 попыток с нарастающей задержкой (2с, 4с, 6с) через `async` sleep
- Cache-busting через `?nocache=<timestamp>`
- Определение типа обложки вынесено в отдельную логику
- Скругление через SwiftUI `.clipShape(RoundedRectangle)` вместо `UIGraphicsImageRenderer`

### 6.4 NowPlayingService

Отвечает за: обновление информации в Control Center / Lock Screen, обработка Remote Commands.

```swift
protocol NowPlayingServiceProtocol {
    func configure(playAction: @escaping () -> Void, pauseAction: @escaping () -> Void)
    func update(title: String, artist: String, artwork: UIImage?, isLiveStream: Bool)
    func clear()
}
```

**Ключевые отличия от v1:**
- Выделен из `RadioPlayer` в отдельный сервис
- Remote Commands настраиваются один раз при инициализации
- `isLiveStream: true` всегда устанавливается

### 6.5 SubscriptionService

Отвечает за: обёртка над RevenueCat, проверка премиум-статуса, логика показа paywall.

```swift
protocol SubscriptionServiceProtocol {
    var isPremium: Bool { get }
    func checkPremiumStatus() async -> Bool
    func shouldShowPaywall() -> Bool
    func markPaywallDisplayed()

    // Тестовый режим
    var isTestModeEnabled: Bool { get }
    func setTestMode(_ enabled: Bool)
}
```

**Ключевые отличия от v1:**
- Вся логика paywall (дни показа, тест-режим, `UserDefaults`) -- в одном сервисе
- Вынесено из `AppDelegate` -- чище разделение ответственностей
- `async` для проверки статуса

### 6.6 HapticService

Отвечает за: все тактильные паттерны приложения, единое место.

```swift
protocol HapticServiceProtocol {
    func playTrackChanged()       // .medium impact
    func playButtonPress()        // heavy + light через 0.1с
    func playButtonRelease()      // .light impact
    func playTestModeToggle()     // .heavy impact
    func prepare()                // подготовка CHHapticEngine
}
```

**Ключевые отличия от v1:**
- Устранено дублирование `playComplexHaptic()` (было 2 разных реализации)
- Все паттерны именованы семантически
- Единая точка для всех хаптиков

### 6.7 NetworkClient

Отвечает за: HTTP-запросы, переиспользование URLSession.

```swift
protocol NetworkClientProtocol: Sendable {
    func fetch<T: Decodable>(_ type: T.Type, from url: URL, cacheBusting: Bool) async throws -> T
    func fetchImage(from url: URL, cacheBusting: Bool) async throws -> UIImage
}
```

**Ключевые отличия от v1:**
- Единый `URLSession` вместо создания нового при каждом запросе
- `async throws` вместо callbacks
- Встроенный cache-busting
- Обобщённый `fetch<T: Decodable>` для типобезопасного парсинга

---

## 7. State Machine для аудио

### Диаграмма переходов состояний

```
                           play(url:)
            ┌──────────────────────────────────────┐
            │                                      │
            ▼                                      │
    ┌───────────────┐                      ┌───────┴───────┐
    │               │   буфер заполнен     │               │
    │  .connecting  │─────────────────────▶│   .playing    │
    │               │                      │               │
    └───────┬───────┘                      └──┬─────┬──────┘
            │                                 │     │
            │ ошибка                    pause()│     │ буфер пуст
            │                                 │     │
            ▼                                 ▼     ▼
    ┌───────────────┐                 ┌──────────┐  ┌────────────┐
    │               │                 │          │  │            │
    │    .error     │                 │ .paused  │  │ .buffering │
    │   (RadioError)│                 │          │  │            │
    └───────┬───────┘                 └──────────┘  └──────┬─────┘
            │                                              │
            │ retry (< maxAttempts)     буфер восстановлен │
            │                                              │
            ▼                                              │
    ┌───────────────┐                                      │
    │               │◀─────────────────────────────────────┘
    │  .connecting  │
    │  (reconnect)  │
    └───────────────┘


    Из любого состояния:

        stop() ──────▶  .idle
        play(url:) ──▶  .connecting
```

### Определение состояний

```swift
enum AudioState: Equatable, Sendable {
    case idle                          // Начальное состояние, плеер не активен
    case connecting                    // Установка соединения, буферизация начальных данных
    case playing                       // Активное воспроизведение
    case buffering                     // Воспроизведение приостановлено из-за пустого буфера
    case paused                        // Пользователь поставил на паузу
    case error(AudioError)             // Ошибка с информацией для восстановления

    var isActive: Bool {
        switch self {
        case .playing, .buffering, .connecting:
            return true
        default:
            return false
        }
    }
}

enum AudioError: Equatable, Sendable {
    case networkUnavailable
    case streamUnavailable
    case bufferingTimeout
    case audioSessionInterrupted
    case unknownError(String)
}
```

### Правила переходов

| Из состояния | Событие | В состояние | Действие |
|---|---|---|---|
| `.idle` | `play(url:)` | `.connecting` | Создать AVPlayerItem, начать воспроизведение |
| `.connecting` | буфер заполнен | `.playing` | -- |
| `.connecting` | ошибка | `.error(...)` | Попытка reconnect |
| `.playing` | `pause()` | `.paused` | `player.pause()`, остановить мониторинг |
| `.playing` | буфер пуст | `.buffering` | Показать индикатор |
| `.playing` | stalled | `.buffering` | Повторить `player.play()` через 2с |
| `.playing` | ошибка | `.error(...)` | Попытка reconnect |
| `.buffering` | буфер восстановлен | `.playing` | -- |
| `.buffering` | таймаут | `.error(.bufferingTimeout)` | Показать ErrorView |
| `.paused` | `play(url:)` | `.connecting` | Полный перезапуск потока |
| `.error(...)` | retry (< 3) | `.connecting` | Задержка 2с, повторить play |
| `.error(...)` | retry исчерпаны | `.error(.bufferingTimeout)` | Показать ErrorView |
| любое | `stop()` | `.idle` | Освободить ресурсы |

---

## 8. Обработка ошибок

### Typed Errors

```swift
enum AudioError: LocalizedError, Equatable, Sendable {
    case networkUnavailable
    case streamUnavailable
    case bufferingTimeout
    case audioSessionInterrupted
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Нет подключения к интернету"
        case .streamUnavailable:
            return "Радиопоток временно недоступен"
        case .bufferingTimeout:
            return "Превышено время ожидания"
        case .audioSessionInterrupted:
            return "Воспроизведение прервано"
        case .unknownError(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Проверьте подключение к интернету"
        case .streamUnavailable, .bufferingTimeout:
            return "Попробуйте позже"
        case .audioSessionInterrupted:
            return "Нажмите Play для возобновления"
        case .unknownError:
            return "Попробуйте перезапустить приложение"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .streamUnavailable, .bufferingTimeout, .audioSessionInterrupted:
            return true
        case .unknownError:
            return false
        }
    }
}

enum NetworkError: LocalizedError, Sendable {
    case noData
    case decodingFailed
    case httpError(statusCode: Int)
    case timeout
    case cancelled
}

enum ArtworkError: LocalizedError, Sendable {
    case networkError(NetworkError)
    case invalidImageData
    case trackMismatch        // API вернул данные для другого трека
}
```

### Стратегия обработки

```
AudioEngine ошибка
    │
    ├─ isRetryable == true?
    │   ├─ reconnectAttempts < 3
    │   │   └─ Автоматический retry через 2с
    │   └─ reconnectAttempts >= 3
    │       └─ Передать в PlayerViewModel
    │
    └─ isRetryable == false?
        └─ Передать в PlayerViewModel
                │
                ▼
        PlayerViewModel
            │
            ├─ Обновить displayState = .error(...)
            └─ PlayerView показывает ErrorView
                    │
                    └─ Кнопка "Повторить"
                        └─ viewModel.retry()
                            └─ AudioEngine.play(url:)
```

**Ключевое отличие от v1:** `ErrorView` теперь реально подключён к UI и показывается пользователю при ошибках.

---

## 9. Тестирование

### Стратегия

| Уровень | Что тестируем | Инструменты |
|---------|--------------|-------------|
| **Unit Tests** | Сервисы, ViewModels, модели, state machine | XCTest |
| **Integration Tests** | Взаимодействие AudioEngine + MetadataService | XCTest |
| **Snapshot Tests** | Визуальное соответствие UI | swift-snapshot-testing |
| **UI Tests** | E2E сценарии | XCUITest (опционально) |

### Unit Tests -- что покрываем

**AudioEngine:**
- Все переходы state machine (idle -> connecting -> playing -> paused -> idle)
- Retry-логика (3 попытки, затем .error)
- Обработка stalled
- Обработка прерываний аудиосессии

**MetadataService:**
- Извлечение title из AVMetadataItem
- Парсинг ответа Status API (через Codable)
- Обработка невалидного JSON
- Cache-busting параметры

**ArtworkService:**
- Загрузка реальной обложки
- Определение типа: stationLogo vs realArtwork
- Retry-логика (3 попытки с нарастающей задержкой)
- Проверка соответствия title
- Кэширование averageColor

**PlayerViewModel:**
- Координация сервисов при play/pause/stop
- UX-логика дефолтной обложки (hasLoadedRealArtworkOnce)
- Обработка ошибок и показ ErrorView
- Логика градиентов

**SubscriptionService:**
- Логика показа paywall на 3, 6, 15 день
- Тестовый режим
- Ограничение "1 раз в день"

### Mock-реализации

Каждый протокол сервиса имеет mock-версию:

```swift
final class MockAudioEngine: AudioEngineProtocol {
    var state: AudioState = .idle

    // Для проверки вызовов
    var playCallCount = 0
    var lastPlayedURL: URL?
    var pauseCallCount = 0
    var stopCallCount = 0

    // Управление потоками для тестов
    private let stateContinuation: AsyncStream<AudioState>.Continuation
    let stateStream: AsyncStream<AudioState>

    private let metadataContinuation: AsyncStream<[AVMetadataItem]>.Continuation
    let metadataStream: AsyncStream<[AVMetadataItem]>

    init() {
        (stateStream, stateContinuation) = AsyncStream.makeStream()
        (metadataStream, metadataContinuation) = AsyncStream.makeStream()
    }

    func play(url: URL) async {
        playCallCount += 1
        lastPlayedURL = url
        state = .connecting
        stateContinuation.yield(.connecting)
    }

    func pause() { pauseCallCount += 1; state = .paused }
    func stop() { stopCallCount += 1; state = .idle }

    // Методы для тестов
    func simulateStateChange(_ newState: AudioState) {
        state = newState
        stateContinuation.yield(newState)
    }
}
```

### Snapshot Tests

Покрываем ключевые визуальные состояния:

- PlayerView в состоянии idle (дефолтная обложка + градиент Якутии)
- PlayerView в состоянии playing (реальная обложка + адаптивный фон)
- PlayerView в состоянии connecting ("Холбонуу..." + анимированные точки)
- PlayerView в состоянии error (ErrorView)
- SplashView
- PurchaseSuccessView

---

## 10. Зависимости

### SPM-пакеты

| Пакет | Версия | Назначение |
|-------|--------|------------|
| [purchases-ios-spm](https://github.com/RevenueCat/purchases-ios-spm) | ~> 5.22 | RevenueCat SDK -- подписки и покупки |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | ~> 1.17 | Snapshot-тесты UI (только для тестов) |

**Минимальный набор зависимостей:**
- RevenueCat -- обязательная зависимость для монетизации
- swift-snapshot-testing -- только test target, не влияет на размер приложения

**Отказ от дополнительных зависимостей:**
- Нет Kingfisher/SDWebImage -- загрузка обложек реализуется через встроенный URLSession + async/await (одна обложка за раз, нет необходимости в сложном кэшировании)
- Нет сторонних аудио-библиотек -- AVFoundation полностью покрывает потребности
- Нет сторонних навигационных фреймворков -- одноэкранное приложение

---

## 11. Потенциальные расширения

### watchOS Companion App

```
OtonFM Watch/
├── OtonFMWatchApp.swift
├── NowPlayingView.swift          # Компактный UI плеера
└── WatchConnectivity/
    └── PhoneSessionManager.swift  # WCSession для связи с iPhone
```

- Компактный UI: обложка + название трека + кнопка Play/Pause
- `WCSession` для синхронизации состояния с iPhone
- Самостоятельное воспроизведение через `AVAudioSession` на watchOS (опционально)

### CarPlay

```
OtonFM CarPlay/
├── CarPlaySceneDelegate.swift
└── CarPlayTemplates/
    ├── NowPlayingTemplate.swift
    └── TabBarTemplate.swift
```

- `CPNowPlayingTemplate` -- встроенный шаблон CarPlay для аудио
- Минимальная реализация: кнопки Play/Pause + название трека
- Использует тот же `AudioEngine` через shared service container

### Widgets (iOS 17+)

```
OtonFM Widget/
├── OtonFMWidget.swift
├── NowPlayingWidget.swift        # "Сейчас играет"
├── QuickPlayWidget.swift         # Быстрый запуск воспроизведения
└── WidgetModels/
    └── SharedTrackInfo.swift      # App Group для обмена данными
```

- **NowPlayingWidget** -- текущий трек + обложка (обновление через `WidgetCenter`)
- **QuickPlayWidget** -- одна кнопка для запуска воспроизведения через App Intent
- `App Group` для обмена данными между приложением и виджетом
- `ActivityKit` (Live Activity) -- информация о текущем треке на экране блокировки

### Будущие фичи

| Фича | Сложность | Зависимости |
|------|-----------|-------------|
| Таймер сна (Sleep Timer) | Низкая | AudioEngine + Timer |
| Кнопка "Поделиться" треком | Низкая | UIActivityViewController |
| История треков | Средняя | SwiftData / UserDefaults |
| Индикация качества соединения | Средняя | NWPathMonitor |
| Анимация/визуализация звука | Средняя | AVAudioEngine tap |
| Локальное кэширование обложек | Средняя | NSCache + FileManager |
| Локализация (якутский/русский/англ.) | Средняя | Localizable.xcstrings |
| Offline-режим (подкасты) | Высокая | AVAssetDownloadURLSession |

---

## Приложение A: Миграция констант

Все магические числа из v1 собраны в `Constants.swift`:

```swift
enum Constants {
    enum Audio {
        static let bufferDuration: TimeInterval = 10.0
        static let bufferCheckInterval: TimeInterval = 0.5
        static let reconnectDelay: TimeInterval = 2.0
        static let maxReconnectAttempts = 3
        static let maxArtworkRetries = 3
        static let apiTimeout: TimeInterval = 10.0
    }

    enum Animation {
        static let gradientChangeInterval: TimeInterval = 10.0
        static let gradientTransitionDuration: TimeInterval = 3.0
        static let splashDuration: TimeInterval = 2.0
        static let splashFadeOut: TimeInterval = 0.5
        static let artworkTransition: TimeInterval = 0.6
        static let textTransition: TimeInterval = 0.5
        static let backgroundTransition: TimeInterval = 0.8
        static let pressAnimation: TimeInterval = 0.2
        static let pulsationDuration: TimeInterval = 1.5
        static let dotsInterval: TimeInterval = 0.4
    }

    enum Layout {
        static let artworkSizeRatio: CGFloat = 0.85
        static let horizontalPaddingRatio: CGFloat = 0.075
        static let trackInfoOffset: CGFloat = -40
        static let playButtonSize: CGFloat = 64
        static let playIconSize: CGFloat = 30
        static let playIconOffset: CGFloat = 2
        static let artworkCornerRadius: CGFloat = 10
        static let artworkShadowRadius: CGFloat = 25
        static let artworkShadowOpacity: Double = 0.6
        static let artworkShadowOffsetY: CGFloat = 10
        static let pulsationScale: CGFloat = 1.02
        static let pressScale: CGFloat = 0.9
        static let logoSplashSize: CGFloat = 100
        static let bottomSpacing: CGFloat = 30
        static let topBarPaddingTop: CGFloat = 20
    }

    enum Paywall {
        static let targetDays = [3, 6, 15]
        static let checkDelay: TimeInterval = 1.0
        static let purchaseSuccessDelay: TimeInterval = 0.3
        static let testModePaywallDelay: TimeInterval = 0.5
        static let longPressDuration: TimeInterval = 1.5
    }
}
```

## Приложение B: Именование цветов

Исправление вводящих в заблуждение имён из v1:

| v1 (текущее) | v2 (новое) | Значение |
|---|---|---|
| `spotifyGreen` (в ContentView, красный!) | `AppColors.accent` | Акцентный цвет (красный 0.81, 0.17, 0.17) |
| `spotifyBlack` | `AppColors.background` | Основной фон (18, 18, 18) |
| `spotifyDarkGray` | `AppColors.surfaceSecondary` | Вторичная поверхность (40, 40, 40) |
| `spotifyGreen` (в SplashView, зелёный) | Удалить | Не используется в UI |
