# Техническое описание и план рефакторинга Oton.FM

## Оглавление
1. [Текущая архитектура](#текущая-архитектура)
2. [Технические проблемы](#технические-проблемы)
3. [Предлагаемые изменения](#предлагаемые-изменения)
4. [План рефакторинга](#план-рефакторинга)
5. [Примеры кода](#примеры-кода)

## Текущая архитектура

### Обзор
Oton.FM — радио-приложение для якутской диаспоры, построенное на SwiftUI с использованием модифицированной MVVM архитектуры.

### Технологический стек
- **UI Framework**: SwiftUI
- **Архитектурный паттерн**: MVVM с элементами Singleton
- **Управление состоянием**: @Published, @StateObject, Combine
- **Аудио**: AVFoundation, MediaPlayer
- **Монетизация**: RevenueCat SDK
- **Зависимости**: Swift Package Manager

### Компоненты приложения

#### 1. Entry Points
- `Oton_FMApp.swift` — SwiftUI App protocol entry point
- `AppDelegate.swift` — UIApplicationDelegate для lifecycle и RevenueCat

#### 2. Core Components
- `RadioPlayer` (384 строки) — монолитный singleton, объединяющий:
  - Управление аудио потоком (AVPlayer)
  - Сетевые запросы (API статуса, загрузка обложек)
  - Управление состоянием приложения
  - Обработка метаданных
  - Интеграция с Now Playing
  - Мониторинг буферизации

#### 3. Views
- `ContentView` (876 строк) — основной экран с плеером
- `SplashView` — экран загрузки
- `AnimatedDots` — компонент анимации
- `ConnectingText` — компонент статуса подключения

#### 4. Utilities
- `Config` — конфигурация приложения
- `YakutiaGradients` — тематические градиенты
- `UIImage+AverageColor` — извлечение доминирующего цвета
- `UIColor+IsLightColor` — определение яркости цвета
- `FontProviders` — конфигурация шрифтов для RevenueCat

### Архитектурная диаграмма текущего состояния

```
┌─────────────────┐
│   Oton_FMApp    │
│  (Entry Point)  │
└────────┬────────┘
         │
┌────────▼────────┐     ┌──────────────┐
│   AppDelegate   │     │    Config    │
│  (RevenueCat)   │     │ (Constants)  │
└────────┬────────┘     └──────────────┘
         │
┌────────▼────────────────────────────┐
│          ContentView                 │
│  ┌─────────────────────────────┐    │
│  │     RadioPlayer.shared      │    │
│  │  (Singleton - 384 lines)    │    │
│  │  • Audio Management         │    │
│  │  • Network Requests         │    │
│  │  • State Management         │    │
│  │  • Image Processing         │    │
│  │  • Metadata Handling        │    │
│  └─────────────────────────────┘    │
│                                      │
│  UI Components:                      │
│  • Player Controls                   │
│  • Track Info                        │
│  • Gradient Background               │
│  • Paywall Integration               │
└──────────────────────────────────────┘
```

## Технические проблемы

### 1. Нарушение принципов SOLID

#### Single Responsibility Principle (SRP)
- `RadioPlayer` выполняет 10+ различных обязанностей
- `ContentView` смешивает UI логику, бизнес-логику и анимации
- Отсутствие четкого разделения concerns

#### Open/Closed Principle (OCP)
- Добавление новых функций требует модификации существующих классов
- Невозможность расширения без изменения базового кода

#### Dependency Inversion Principle (DIP)
- Прямые зависимости от конкретных реализаций (singleton)
- Отсутствие абстракций для тестирования

### 2. Проблемы масштабируемости

#### Монолитная архитектура
```swift
// Текущее состояние: все в одном классе
class RadioPlayer: NSObject, ObservableObject {
    // 384 строки кода
    // Сетевые запросы
    // Управление аудио
    // Обработка изображений
    // Управление состоянием
    // ...
}
```

#### Сложность тестирования
- Невозможно протестировать компоненты изолированно
- Singleton паттерн усложняет mock-объекты
- Отсутствие dependency injection

### 3. Обработка ошибок

#### Текущее состояние
```swift
// Только print для отладки
if let error = error {
    print("❌ Ошибка получения статуса: \(error.localizedDescription)")
    return
}
```

#### Проблемы
- Пользователь не видит ошибки
- Нет механизма восстановления
- Отсутствие логирования для production

### 4. Управление состоянием

#### Смешанные подходы
- SwiftUI @State для UI
- @Published для бизнес-логики
- KVO для AVPlayer
- UserDefaults для персистентности

#### Отсутствие единого источника истины
- Состояние разбросано по компонентам
- Сложность отслеживания изменений

### 5. Сетевой слой

#### Проблемы
- Inline сетевые запросы в RadioPlayer
- Отсутствие абстракции для API
- Нет централизованной обработки ошибок
- Примитивное кэширование

## Предлагаемые изменения

### 1. Новая архитектура

#### Clean Architecture + MVVM + Coordinator

```
┌─────────────────────────────────────────────────┐
│                 Presentation Layer               │
│  ┌───────────┐  ┌───────────┐  ┌────────────┐  │
│  │   Views   │  │ViewModels │  │Coordinators│  │
│  └───────────┘  └───────────┘  └────────────┘  │
└─────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────┐
│                  Domain Layer                    │
│  ┌───────────┐  ┌───────────┐  ┌────────────┐  │
│  │ Use Cases │  │  Models   │  │ Interfaces │  │
│  └───────────┘  └───────────┘  └────────────┘  │
└─────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────┐
│                   Data Layer                     │
│  ┌───────────┐  ┌───────────┐  ┌────────────┐  │
│  │Repository │  │ Services  │  │   Cache    │  │
│  └───────────┘  └───────────┘  └────────────┘  │
└─────────────────────────────────────────────────┘
```

### 2. Разделение RadioPlayer на сервисы

#### AudioService
```swift
protocol AudioServiceProtocol {
    var isPlaying: AnyPublisher<Bool, Never> { get }
    var isBuffering: AnyPublisher<Bool, Never> { get }
    
    func play(url: URL) async throws
    func pause()
    func setBufferSize(_ seconds: TimeInterval)
}

final class AudioService: AudioServiceProtocol {
    private let player: AVPlayer
    private let bufferMonitor: BufferMonitor
    
    // Реализация только аудио-логики
}
```

#### NetworkService
```swift
protocol NetworkServiceProtocol {
    func fetchTrackStatus() async throws -> TrackInfo
    func fetchArtwork(url: URL) async throws -> UIImage
}

final class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    
    // Централизованная обработка сетевых запросов
}
```

#### MetadataService
```swift
protocol MetadataServiceProtocol {
    func updateNowPlaying(track: TrackInfo, artwork: UIImage?)
    func setupRemoteCommands(play: @escaping () -> Void, pause: @escaping () -> Void)
}
```

### 3. Proper ViewModels

#### RadioPlayerViewModel
```swift
final class RadioPlayerViewModel: ObservableObject {
    // UI State
    @Published var playerState: PlayerState = .stopped
    @Published var currentTrack: TrackInfo?
    @Published var artwork: UIImage?
    @Published var isBuffering: Bool = false
    
    // Dependencies (injected)
    private let audioService: AudioServiceProtocol
    private let networkService: NetworkServiceProtocol
    private let metadataService: MetadataServiceProtocol
    
    init(
        audioService: AudioServiceProtocol,
        networkService: NetworkServiceProtocol,
        metadataService: MetadataServiceProtocol
    ) {
        self.audioService = audioService
        self.networkService = networkService
        self.metadataService = metadataService
        
        setupBindings()
    }
    
    func play() {
        Task {
            do {
                playerState = .connecting
                try await audioService.play(url: Config.radioStreamURL)
                playerState = .playing
            } catch {
                playerState = .error(error)
            }
        }
    }
}
```

### 4. Error Handling

#### Error Types
```swift
enum RadioError: LocalizedError {
    case networkUnavailable
    case streamUnavailable
    case bufferingTimeout
    case invalidAudioFormat
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Нет подключения к интернету"
        case .streamUnavailable:
            return "Радиопоток временно недоступен"
        case .bufferingTimeout:
            return "Превышено время ожидания"
        case .invalidAudioFormat:
            return "Неподдерживаемый формат аудио"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Проверьте подключение к интернету"
        case .streamUnavailable, .bufferingTimeout:
            return "Попробуйте позже"
        case .invalidAudioFormat:
            return "Обратитесь в поддержку"
        }
    }
}
```

#### Error View
```swift
struct ErrorView: View {
    let error: RadioError
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text(error.errorDescription ?? "Произошла ошибка")
                .font(.headline)
            
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button("Повторить", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
```

### 5. Dependency Injection

#### DI Container
```swift
final class AppContainer {
    lazy var audioService: AudioServiceProtocol = AudioService()
    lazy var networkService: NetworkServiceProtocol = NetworkService()
    lazy var metadataService: MetadataServiceProtocol = MetadataService()
    lazy var cacheService: CacheServiceProtocol = CacheService()
    
    lazy var radioPlayerViewModel: RadioPlayerViewModel = {
        RadioPlayerViewModel(
            audioService: audioService,
            networkService: networkService,
            metadataService: metadataService
        )
    }()
}

// В App
@main
struct Oton_FMApp: App {
    let container = AppContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container.radioPlayerViewModel)
        }
    }
}
```

### 6. View Decomposition

#### Разделение ContentView
```swift
// ContentView становится координатором
struct ContentView: View {
    @EnvironmentObject var viewModel: RadioPlayerViewModel
    
    var body: some View {
        ZStack {
            BackgroundView(artwork: viewModel.artwork)
            
            VStack {
                HeaderView()
                ArtworkView(image: viewModel.artwork)
                TrackInfoView(track: viewModel.currentTrack)
                PlayerControlsView(
                    isPlaying: viewModel.playerState.isPlaying,
                    isBuffering: viewModel.isBuffering,
                    onPlay: viewModel.play,
                    onPause: viewModel.pause
                )
            }
        }
        .errorAlert(error: viewModel.error)
    }
}
```

## План рефакторинга

### Фаза 1: Подготовка (1-2 недели)
1. **Написание тестов для существующей функциональности**
   - UI тесты для критических user flows
   - Документирование текущего поведения

2. **Создание абстракций**
   - Протоколы для сервисов
   - Модели данных

### Фаза 2: Разделение сервисов (2-3 недели)
1. **Извлечение AudioService**
   - Вынести логику AVPlayer
   - Создать протокол AudioServiceProtocol
   - Покрыть тестами

2. **Извлечение NetworkService**
   - Централизовать сетевые запросы
   - Добавить proper error handling
   - Реализовать retry логику

3. **Извлечение MetadataService**
   - Now Playing управление
   - Remote commands

### Фаза 3: MVVM рефакторинг (2 недели)
1. **Создание proper ViewModels**
   - RadioPlayerViewModel
   - PaywallViewModel
   - Отделение бизнес-логики от UI

2. **Dependency Injection**
   - Создание DI Container
   - Удаление singleton зависимостей

### Фаза 4: UI декомпозиция (1 неделя)
1. **Разделение ContentView**
   - Извлечение компонентов
   - Создание reusable views

2. **Error handling UI**
   - Error states
   - Retry механизмы

### Фаза 5: Оптимизация (1 неделя)
1. **Производительность**
   - Профилирование
   - Оптимизация анимаций

2. **Кэширование**
   - Implement proper image cache
   - API response caching

### Приоритеты

#### Критические (блокирующие)
1. Разделение RadioPlayer — основной источник проблем
2. Error handling — UX критично
3. Тесты — для безопасного рефакторинга

#### Важные
1. Proper MVVM — улучшит поддерживаемость
2. DI — улучшит тестируемость
3. Network layer — централизация и стандартизация

#### Желательные
1. Координаторы — для будущей навигации
2. Анимации в отдельные компоненты
3. Логирование и аналитика

## Примеры кода

### Before: Монолитный RadioPlayer
```swift
class RadioPlayer: NSObject, ObservableObject {
    func playStream() {
        // 100+ строк смешанной логики
        // Сеть, аудио, UI обновления
    }
}
```

### After: Разделенная архитектура
```swift
// AudioService - только аудио
final class AudioService: AudioServiceProtocol {
    func play(url: URL) async throws {
        // Чистая аудио логика
    }
}

// ViewModel - координация
final class RadioPlayerViewModel: ObservableObject {
    func play() {
        Task {
            playerState = .connecting
            do {
                try await audioService.play(url: streamURL)
                playerState = .playing
            } catch {
                playerState = .error(error)
            }
        }
    }
}

// View - только UI
struct PlayerControlsView: View {
    let onPlay: () -> Void
    let onPause: () -> Void
    
    var body: some View {
        // Чистый UI код
    }
}
```

### Результаты рефакторинга

#### Ожидаемые улучшения
1. **Тестируемость**: от 0% до 80%+ покрытия
2. **Поддерживаемость**: легче добавлять функции
3. **Надежность**: proper error handling
4. **Производительность**: оптимизированное кэширование
5. **Масштабируемость**: готовность к новым функциям

#### Метрики успеха
- Уменьшение размера классов (max 200 строк)
- Увеличение test coverage (target 80%)
- Снижение crash rate
- Улучшение времени загрузки
- Упрощение добавления новых функций

## Заключение

Предложенный план рефакторинга поможет трансформировать Oton.FM из функционального MVP в production-ready приложение с чистой, масштабируемой архитектурой, соответствующей стандартам индустрии.