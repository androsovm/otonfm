# CLAUDE.md




Этот файл содержит рекомендации для работы с кодом репозитория Oton.FM.

## О проекте Oton.FM
Oton.FM — это радио-приложение для якутской диаспоры:
- Якутская и международная музыка
- Программы и шоу на якутском языке
- Культурный контент для якутского сообщества
- Прямой эфир и on-demand контент

## Архитектура (v2)
- **iOS 17+**, SwiftUI, **@Observable** (не ObservableObject)
- **async/await** с AsyncStream (не Combine/callbacks)
- **MVVM**: PlayerViewModel — основная view model
- **Protocol-based DI**: все сервисы имеют протоколы + Stub-реализации для тестов
- **AppEnvironment**: контейнер зависимостей, передаётся через SwiftUI Environment
- **Xcode 16**: PBXFileSystemSynchronizedRootGroup — автообнаружение Swift-файлов в папках

## Основные реализованные фичи
- **Современный UI в стиле Spotify**: темный градиентный фон, крупная обложка альбома (cornerRadius: 32, style: .continuous), плавные анимации
- **Буферизация аудио**: автоматический рестарт потока, индикация буферизации внутри кнопки Play
- **Умная загрузка обложек**: классификация по URL-паттернам + проверка aspect ratio изображения (w/h > 1.5 = station logo, не album art)
- **Анимированные градиенты Якутии**: 14 тематических градиентов с плавной сменой (10 сек интервал, 3 сек переход, случайный старт)
- **Анимированные фоны**: звёзды (мерцание, Canvas+TimelineView) для ночных градиентов, падающий снег для зимних, плавный кроссфейд между анимациями
- **Live Activity / Dynamic Island**: отображение трека, play/pause, обложка (сжатая до 80x80 JPEG для лимита 4KB)
- **Share Track**: кнопка «Поделиться» в верхней панели рядом с Gift
- **RevenueCat**: подписки через PaywallView, автопоказ на 3, 6 и 15 день
- **Тактильная обратная связь**: haptic feedback на все действия
- **UX-логика обложки**: если показана реальная обложка — дефолтная не затирает её до смены трека

## Build-команды
- Сборка: `xcodebuild -scheme "Oton.FM" -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Тесты: `xcodebuild test -scheme "Oton.FM" -destination 'platform=iOS Simulator,name=iPhone 15'`
- Widget Extension собирается автоматически вместе с основной схемой

## Code Style Guidelines
- PascalCase для типов, camelCase для свойств/методов
- Импорты по одному на строке, сначала SwiftUI
- @Observable вместо ObservableObject
- async/await вместо Combine
- Явное private для приватных свойств
- SwiftUI: модификаторы по одному на строке, анимации через `.animation(.easeInOut(duration:), value:)`
- Комментарии в финальном коде на английском

## Градиенты yakutiaGradients (14 шт.)

### Летние / тёплые (без анимации)
1. Тёплый закат над Туймаадой
2. Янтарное золото Якутии
3. Костёр на берегу Лены
4. Ысыах — золотое солнце лета
5. Алаас — зелёные луга Якутии
6. Ысыах луг — солнечный луг праздника
7. Кумыс — сливочное тепло
8. Осенняя лиственница в золоте
9. Розовый рассвет над тайгой

### Зимние (анимация: снег)
10. Морозное утро в Якутии
11. Голубой лёд реки Лены

### Ночные (анимация: звёзды)
12. Мягкое северное сияние
13. Лиловый вечер над Леной
14. Полярная заря — лавандовый рассвет

## Анимированные фоны
- **StarrySkyView**: 50 мерцающих звёзд, Canvas + TimelineView @30fps
- **FallingSnowView**: 30 снежинок трёх размеров с ветром, Canvas + TimelineView @30fps
- Кроссфейд между анимациями через `gradientAnimator.transition` (opacity-based)
- Тёплые градиенты показываются без анимации-оверлея

## Структура проекта
```
Oton.FM/
├── App/
│   ├── OtonFMApp.swift              # Точка входа, DI setup
│   └── AppEnvironment.swift         # Контейнер зависимостей
├── Core/
│   ├── Config.swift                 # URLs, station ID, API keys
│   ├── Constants.swift              # Все magic numbers (~40 констант)
│   └── Extensions/                  # UIImage+AverageColor, UIColor+IsLight, Color+Theme
├── Services/                        # 8 сервисов с протоколами
│   ├── Audio/                       # AudioEngine (AVPlayer, state machine)
│   ├── Network/                     # NetworkClient (URLSession)
│   ├── Metadata/                    # MetadataService (radio.co API)
│   ├── Artwork/                     # ArtworkService (загрузка, классификация, retry)
│   ├── NowPlaying/                  # NowPlayingService (MPNowPlayingInfoCenter)
│   ├── Haptics/                     # HapticService (UIImpactFeedbackGenerator)
│   ├── Subscription/                # SubscriptionService (RevenueCat)
│   └── LiveActivity/                # LiveActivityService (ActivityKit)
├── Features/
│   ├── Player/
│   │   ├── PlayerViewModel.swift    # Основная VM, координирует все сервисы
│   │   ├── PlayerView.swift         # Главный экран плеера
│   │   └── Components/              # ArtworkView, TrackInfoView, PlayerControlsView, AnimatedDots
│   ├── Splash/                      # SplashView
│   ├── Error/                       # ErrorView
│   └── Subscription/                # SubscriptionViewModel, PaywallContainer, PurchaseSuccess
├── UI/
│   ├── Theme/                       # AppColors, AppFonts
│   ├── Gradients/                   # YakutiaGradients, GradientAnimator
│   ├── Backgrounds/                 # StarrySkyView, FallingSnowView
│   └── Modifiers/                   # PulsationModifier
└── Assets.xcassets/                 # AppIcon, defaultArtwork, otonLogo

OtonFMWidgets/                       # Widget Extension (Live Activity / Dynamic Island)
├── OtonFMLiveActivity.swift
├── OtonFMWidgetsBundle.swift
└── NowPlayingAttributes.swift       # Копия из основного таргета
```

## Ключевые технические решения
- **Классификация обложек**: URL-паттерны ("station_logos", station ID, "oton") + aspect ratio > 1.5 → station logo
- **Live Activity artwork**: UIImage → 80x80 thumbnail → JPEG 0.5 quality (~2-3KB, лимит 4KB)
- **Тень обложки**: .clear для дефолтной обложки, artwork-based цвет для реальной
- **Углы обложки**: RoundedRectangle(cornerRadius: 32, style: .continuous) + aspectRatio(.fill)
- **Анимация градиентов**: GradientAnimator (@Observable) с Timer, lerp между UIColor
- **Анимации фонов**: TimelineView(.animation) + Canvas, opacity-based кроссфейд через transition value

## Потенциальные улучшения
- Таймер сна (Sleep Timer)
- Избранное (Favorites)
- История прослушанных треков
- Виджет "Сейчас играет" (Home Screen Widget)
- Анимация/визуализация звука
- Оптимизация энергопотребления
- Локальное кэширование обложек
