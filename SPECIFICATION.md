# Oton.FM - Техническая спецификация

> Полная спецификация приложения Oton.FM для использования при перезаписи с нуля.
> Документ основан на анализе исходного кода текущей версии (v1).

---

## 1. Обзор приложения

### Что такое Oton.FM
Oton.FM -- радио-приложение для iOS, созданное для якутской диаспоры. Приложение транслирует прямой эфир интернет-радиостанции через платформу radio.co, обеспечивая доступ к якутской и международной музыке, программам и шоу на якутском языке.

### Целевая аудитория
- Представители якутской (саха) диаспоры по всему миру
- Слушатели якутской музыки и культурного контента
- Носители якутского языка, интересующиеся аудиоконтентом на родном языке

### Ценностное предложение
- Единственное специализированное приложение для якутского радио
- Прямой эфир 24/7
- Современный UI, сопоставимый с ведущими музыкальными приложениями
- Культурная идентичность через визуальное оформление (градиенты Якутии)

### Платформа и требования
- **Платформа**: iOS (SwiftUI)
- **Минимальная версия iOS**: определяется Xcode-проектом
- **Язык разработки**: Swift
- **UI-фреймворк**: SwiftUI
- **Архитектура**: MVVM с сервисным слоем
- **Менеджер зависимостей**: Swift Package Manager (SPM)

---

## 2. Полный реестр функций

### 2.1 Радиостриминг (прямой эфир)

**Описание**: Воспроизведение прямого аудиопотока через платформу radio.co.

**Реализация**:
- Источник потока: `https://s4.radio.co/s696f24a77/listen`
- Используется `AVPlayer` с `AVPlayerItem` для воспроизведения
- Аудиосессия настраивается с категорией `.playback`, режимом `.default`
- Параметр `automaticallyWaitsToMinimizeStalling` установлен в `true`
- `preferredForwardBufferDuration` = 10.0 секунд

**Управление воспроизведением**:
- Play: создает новый `AVPlayerItem` с URL потока, запускает воспроизведение
- Pause: останавливает воспроизведение через `player.pause()`
- Stop: полностью освобождает ресурсы -- удаляет наблюдателей, обнуляет player и playerItem

**Синглтон-паттерн**: `RadioPlayer.shared` -- единственный экземпляр плеера на все приложение.

### 2.2 Буферизация аудио и логика переподключения

**Конфигурация буфера**:
- `defaultBufferDuration`: 10.0 секунд (предпочтительная длительность буфера)
- `bufferCheckInterval`: 0.5 секунд (частота проверки состояния буфера)
- `reconnectDelay`: 2.0 секунды (задержка перед попыткой переподключения)
- `maxReconnectAttempts`: 3 (максимальное количество попыток переподключения)

**Мониторинг буфера**:
- Таймер проверяет состояние буфера каждые 0.5 секунд
- Отслеживает `loadedTimeRanges` для расчета прогресса буферизации
- Формула: `progress = (bufferedTime - currentTime) / defaultBufferDuration`, ограничен [0, 1]

**Наблюдатели AVPlayerItem**:
- `isPlaybackBufferEmpty` -- когда буфер пуст, устанавливается `isBuffering = true`
- `isPlaybackLikelyToKeepUp` -- когда буфер достаточен, `isBuffering = false`; если состояние было `.connecting`, переключается на `.playing`
- `AVPlayerItemFailedToPlayToEndTime` -- обработка ошибок воспроизведения
- `AVPlayerItemPlaybackStalled` -- обработка зависания воспроизведения

**Логика переподключения при ошибке**:
1. При ошибке воспроизведения: состояние переходит в `.error(.streamUnavailable)`
2. Если `reconnectAttempts < 3`:
   - Инкрементировать счетчик попыток
   - Ждать 2.0 секунды
   - Повторить `play(url:)` с тем же URL
3. Если попытки исчерпаны: состояние переходит в `.error(.bufferingTimeout)`

**Логика при зависании (stalled)**:
1. Устанавливается `isBuffering = true`
2. Через 2.0 секунды: если `isPlaying == true`, вызывается `player.play()` повторно

### 2.3 Получение и отображение метаданных трека

**Источник метаданных -- потоковые (timed metadata)**:
- KVO-наблюдатель на `playerItem.timedMetadata`
- Обрабатываются элементы `AVMetadataItem`
- Приоритет извлечения названия трека:
  1. `item.identifier == .commonIdentifierTitle` -> `item.stringValue`
  2. Фолбэк: `item.value as? String`
- При получении нового названия:
  - Обновляется `currentTrackTitle` и `lastTrackTitle`
  - Обновляется Now Playing Info
  - Сбрасывается `retryCount` для загрузки обложки
  - Вызывается haptic feedback (`.medium`)

**Специальная обработка OtonFM**:
- Если название трека содержит "OtonFM":
  - Пытается загрузить изображение "stationLogo" из ассетов
  - Если не найдено -- использует "defaultArtwork"
  - Обложка помечается как `isStationLogo: true`
- Иначе: запускается загрузка обложки через Status API

**Источник метаданных -- Status API (polling)**:
- URL: `https://public.radio.co/stations/s696f24a77/status`
- Ручной вызов при смене трека (не периодический polling)
- Cache-busting: `?nocache=<timestamp>` добавляется к URL
- URLSession настроена без кэширования: `requestCachePolicy = .reloadIgnoringLocalCacheData`, `urlCache = nil`
- Таймаут запроса: 10 секунд

**Парсинг ответа Status API**:
```
JSON -> current_track -> {
    title: String,
    artwork_url_large: String
}
```

**Валидация соответствия трека**:
- Если `currentTrackTitle` не пуст и `title` из API не совпадает ни с `currentTrackTitle`, ни с `lastTrackTitle` -- обложка не обновляется (защита от рассинхронизации)

### 2.4 Загрузка обложки альбома

**Двойной запрос (two-step)**:
1. Первый запрос -- получение JSON с URL обложки из Status API
2. Второй запрос -- загрузка самого изображения по полученному URL

**Cache-busting для изображения**:
- К URL изображения добавляется `?nocache=<timestamp>`
- Заголовок `Cache-Control: no-cache`
- `cachePolicy = .reloadIgnoringLocalCacheData`
- Таймаут: 10 секунд

**Retry-логика для загрузки изображения**:
- Максимум `maxRetries = 3` попытки
- Задержка между попытками: `retryCount * 2.0` секунд (2с, 4с, 6с)
- После исчерпания попыток -- `retryCount` сбрасывается

**Обработка загруженного изображения**:
- Скругление углов: `cornerRadius = image.size.width * 0.062`
- Используется `UIGraphicsImageRenderer` для отрисовки скругленного изображения

**Определение логотипа станции**:
- URL проверяется на наличие подстрок:
  - `"station_logos"`
  - `Config.radioStationID` (= `"s696f24a77"`)
  - `"oton"` (регистронезависимо)
- Если совпадение найдено -- изображение считается логотипом станции

**UX-логика дефолтной обложки (`isDefaultArtworkShown`)**:
- Флаг `hasLoadedRealArtworkOnce` -- был ли хоть раз показан реальный artwork
- При обновлении обложки:
  - Если это **не** логотип станции:
    - `hasLoadedRealArtworkOnce = true`
    - `isDefaultArtworkShown = false`
  - Если это логотип станции:
    - `isDefaultArtworkShown = !hasLoadedRealArtworkOnce`
    - То есть: если реальная обложка уже была показана -- логотип станции не затирает её
- **Дефолтная обложка при инициализации**: изображение "defaultArtwork" из ассетов, со скругленными углами (`cornerRadius = width * 0.062`)

### 2.5 Анимированные градиенты Якутии

**Количество градиентов**: 25 тем

**Полный список градиентов** (индекс, англ. имя, описание):

| # | Имя | Описание |
|---|-----|----------|
| 0 | northernLights | Северное сияние над Якутией |
| 1 | yakutskSunset | Закат над Якутском |
| 2 | forestTwilight | Сумерки в якутской тайге |
| 3 | lenaSunrise | Рассвет над рекой Лена |
| 4 | frozenLena | Зимняя Лена в сумерках |
| 5 | yakutianGems | Самоцветы Якутии |
| 6 | summerEvening | Летний вечер в Якутии |
| 7 | polarStar | Полярная звезда в ясную ночь |
| 8 | winterMorning | Зимнее утро в Якутии |
| 9 | purpleEvening | Лиловый вечер на Лене |
| 10 | ancientLegends | Древние легенды якутов |
| 11 | amberSunset | Янтарный закат над тундрой |
| 12 | winterTaiga | Зимняя тайга в снегу |
| 13 | yakutianCrystals | Кристаллы якутского льда |
| 14 | starryNight | Звездное небо Якутии |
| 15 | springBloom | Цветение весны в долине Туймаада |
| 16 | olonkhoNight | Ночь Эпоса Олонхо |
| 17 | diamondSky | Алмазное небо Якутии |
| 18 | tundraSummer | Летняя тундра в цвету |
| 19 | autumnColors | Осенние краски Якутии |
| 20 | yakutianMeadow | Якутский луг в разгар лета |
| 21 | midnightSun | Полуночное солнце в Якутии |
| 22 | yakutianLakes | Голубые озёра Якутии |
| 23 | yakutianFlowers | Яркие цветы якутской тундры |
| 24 | ysyakhCelebration | Праздник Ысыах в разгар лета |

**Структура каждого градиента** (`YakutiaGradient`):
- `topColor: UIColor` -- верхний цвет (LinearGradient, startPoint: .top)
- `bottomColor: UIColor` -- нижний цвет (LinearGradient, endPoint: .bottom)
- `name: String` -- англоязычное программное имя
- `description: String` -- русскоязычное описание

**Точные цвета каждого градиента (RGBA)**:
- #0 northernLights: top=(0.15, 0.30, 0.70, 1.0), bottom=(0.40, 0.18, 0.50, 1.0)
- #1 yakutskSunset: top=(0.95, 0.48, 0.22, 1.0), bottom=(0.30, 0.12, 0.30, 1.0)
- #2 forestTwilight: top=(0.22, 0.15, 0.35, 1.0), bottom=(0.40, 0.25, 0.48, 1.0)
- #3 lenaSunrise: top=(0.50, 0.68, 0.85, 1.0), bottom=(0.15, 0.35, 0.60, 1.0)
- #4 frozenLena: top=(0.12, 0.15, 0.28, 1.0), bottom=(0.22, 0.26, 0.40, 1.0)
- #5 yakutianGems: top=(0.35, 0.14, 0.50, 1.0), bottom=(0.65, 0.15, 0.40, 1.0)
- #6 summerEvening: top=(0.85, 0.60, 0.30, 1.0), bottom=(0.50, 0.20, 0.15, 1.0)
- #7 polarStar: top=(0.20, 0.10, 0.40, 1.0), bottom=(0.40, 0.20, 0.60, 1.0)
- #8 winterMorning: top=(0.85, 0.90, 0.95, 1.0), bottom=(0.60, 0.75, 0.90, 1.0)
- #9 purpleEvening: top=(0.28, 0.20, 0.35, 1.0), bottom=(0.45, 0.15, 0.50, 1.0)
- #10 ancientLegends: top=(0.25, 0.20, 0.30, 1.0), bottom=(0.40, 0.30, 0.45, 1.0)
- #11 amberSunset: top=(0.95, 0.52, 0.20, 1.0), bottom=(0.60, 0.20, 0.05, 1.0)
- #12 winterTaiga: top=(0.15, 0.25, 0.35, 1.0), bottom=(0.30, 0.40, 0.45, 1.0)
- #13 yakutianCrystals: top=(0.30, 0.20, 0.50, 1.0), bottom=(0.50, 0.30, 0.65, 1.0)
- #14 starryNight: top=(0.12, 0.15, 0.45, 1.0), bottom=(0.25, 0.10, 0.55, 1.0)
- #15 springBloom: top=(0.85, 0.65, 0.85, 1.0), bottom=(0.50, 0.25, 0.65, 1.0)
- #16 olonkhoNight: top=(0.35, 0.10, 0.40, 1.0), bottom=(0.50, 0.15, 0.55, 1.0)
- #17 diamondSky: top=(0.20, 0.30, 0.50, 1.0), bottom=(0.35, 0.45, 0.60, 1.0)
- #18 tundraSummer: top=(0.20, 0.40, 0.35, 1.0), bottom=(0.35, 0.55, 0.45, 1.0)
- #19 autumnColors: top=(0.70, 0.20, 0.10, 1.0), bottom=(0.90, 0.60, 0.30, 1.0)
- #20 yakutianMeadow: top=(0.10, 0.75, 0.45, 1.0), bottom=(0.60, 0.95, 0.20, 1.0)
- #21 midnightSun: top=(0.95, 0.78, 0.20, 1.0), bottom=(0.98, 0.50, 0.30, 1.0)
- #22 yakutianLakes: top=(0.20, 0.80, 0.90, 1.0), bottom=(0.10, 0.45, 0.80, 1.0)
- #23 yakutianFlowers: top=(0.95, 0.25, 0.45, 1.0), bottom=(0.98, 0.60, 0.15, 1.0)
- #24 ysyakhCelebration: top=(0.70, 0.95, 0.55, 1.0), bottom=(0.15, 0.65, 0.30, 1.0)

**Логика анимации градиентов**:
- Градиенты показываются только когда `isDefaultArtworkShown == true`
- Интервал смены: **10.0 секунд** (таймер `Timer.scheduledTimer`)
- Длительность перехода: **3.0 секунды** (`withAnimation(.easeInOut(duration: 3.0))`)
- Стартовый градиент выбирается **случайно** при каждом новом показе дефолтной обложки
- Порядок смены -- последовательный (`nextGradientIndex = (current + 1) % count`)

**Механизм плавного перехода (интерполяция)**:
- Переменная `gradientTransition` анимируется от 0.0 до 1.0
- Функция `lerpColor` интерполирует RGBA-компоненты между текущим и следующим градиентом
- Результат -- `LinearGradient` с двумя интерполированными цветами (top, bottom)
- После завершения перехода (3с): индексы обновляются, `gradientTransition` сбрасывается в 0.0

**Управление таймером**:
- `startGradientTimer()` -- запускает таймер (с предварительной остановкой предыдущего)
- `stopGradientTimer()` -- инвалидирует таймер
- Таймер запускается при `onAppear` (если дефолтная обложка) и при переключении `isDefaultArtworkShown` на `true`
- Таймер останавливается при переключении `isDefaultArtworkShown` на `false`

### 2.6 Темный UI в стиле Spotify

**Цветовая палитра (константы)**:
- `spotifyBlack`: RGB(18/255, 18/255, 18/255) -- основной фон
- `spotifyGreen` (в ContentView): UIColor(red: 0.81, green: 0.17, blue: 0.17, alpha: 1.00) -- акцентный цвет (фактически красный, несмотря на название)
- `spotifyDarkGray`: RGB(40/255, 40/255, 40/255)
- Кнопка Play/Pause: белый круг, иконка цвета `spotifyBlack` RGB(24/255, 24/255, 24/255)

**Общая цветовая схема**:
- Всегда используется `.preferredColorScheme(.dark)`
- Текст: белый (`.white`), вторичный серый (`.gray`)
- Фон: динамический -- либо градиент Якутии (дефолтная обложка), либо градиент от среднего цвета обложки к черному

**Адаптивный фон на основе обложки**:
- Когда реальная обложка показана:
  - `LinearGradient` от `artworkImage.averageColor` (opacity 0.8) до `spotifyBlack`
  - Направление: top -> bottom
- Анимация перехода: `.easeInOut(duration: 0.8)`

### 2.7 Интеграция RevenueCat (подписки и покупки)

**Зависимость**: `purchases-ios-spm` v5.22.2

**Инициализация**:
- В `AppDelegate.didFinishLaunchingWithOptions`:
  - `Purchases.logLevel = .debug`
  - `Purchases.configure(withAPIKey: Config.revenueCatAPIKey)`

**Проверка премиум-статуса**:
- `Purchases.shared.getCustomerInfo`
- Пользователь считается премиумом если `customerInfo.entitlements.all` не пуст

**Автоматический показ Paywall**:
- Проверяется при `onAppear` в `ContentView`
- Задержка 1.0 секунда перед проверкой (ожидание ответа о статусе подписки)
- Целевые дни для показа: **3, 6, 15** день после первого запуска
- Paywall показывается максимум 1 раз в день (проверяется `lastPaywallDisplayDate`)
- При показе paywall вызывается `AppDelegate.markPaywallAsDisplayed()`

**Расчет дней с первого запуска**:
- Дата первого запуска сохраняется в `UserDefaults` (ключ `"firstLaunchDate"`)
- `Calendar.current.dateComponents([.day], from: firstLaunchDate, to: Date())`

**Компонент PaywallView**:
- Используется `PaywallView` из RevenueCatUI
- Параметры: `fonts: RoundedFontProvider()`, `displayCloseButton: true`
- Представляется как `.sheet`

**Обработка после закрытия Paywall (onDismiss)**:
1. Проверка: была ли совершена покупка в последние 10 секунд
   - `customerInfo.nonSubscriptions.last?.purchaseDate.timeIntervalSinceNow > -10`
2. Если да -- показать экран успешной покупки (с задержкой 0.3с)
3. Независимо от покупки: обновить статус `isPremiumUser`

**Экран успешной покупки**:
- Иконка: `checkmark.circle.fill` (80x80, цвет `spotifyGreen`)
- Текст (якутский): "Kомонг иhин баргfа махтал!" (размер 24, bold)
- Подтекст (русский): "Спасибо за покупку!" (размер 16, серый)
- Кнопка "Продолжить": текст черный, фон `spotifyGreen`, форма капсулы
- Фон: черный с opacity 0.7, скругленный прямоугольник (cornerRadius: 20)
- Тень: black opacity 0.5, radius 20, y: 10
- Анимация: `.scale.combined(with: .opacity)`

**Кнопка Premium (иконка подарка)**:
- SF Symbol: `gift.fill`
- Стиль: белый фон, черная иконка, форма капсулы
- Размер иконки: 18pt, bold
- Padding: horizontal 12, vertical 8
- Расположение: правый верхний угол, horizontal padding = ширина экрана * 0.075
- Padding top: 20pt

### 2.8 Тестовый режим Paywall

**Активация**: длинное нажатие (1.5 секунды) на иконку подарка

**Поведение**:
- Если режим **выключен**: включить (`enablePaywallTestMode()`), haptic feedback `.heavy`, через 0.5с показать paywall
- Если режим **включен**: выключить (`disablePaywallTestMode()`), haptic feedback `.heavy`
- Хранение состояния: `UserDefaults`, ключ `"paywallTestMode"`
- Когда режим активен: `shouldShowPaywall()` всегда возвращает `true`

### 2.9 Тактильная обратная связь (Haptic Feedback)

**Простой тактильный отклик** (`playHapticFeedback`):
- Использует `UIImpactFeedbackGenerator` с указанным стилем
- Применяется при:
  - Смене трека: стиль `.medium`
  - Нажатии кнопки Play/Pause: стиль `.light` (при нажатии и отпускании)
  - Активации/деактивации тестового режима: стиль `.heavy`

**Сложный тактильный паттерн** (`playComplexHaptic` в ContentView):
- Использует `CHHapticEngine`
- Паттерн:
  1. `hapticTransient`: intensity=1.0, sharpness=0.7, время=0
  2. `hapticContinuous`: intensity=0.5, sharpness=0.5, время=0.1, длительность=0.2

**Сложный тактильный паттерн** (`playComplexHaptic` в PlayerControlsView):
- Более простая реализация:
  1. `UIImpactFeedbackGenerator(style: .heavy)` -- сразу
  2. `UIImpactFeedbackGenerator(style: .light)` -- через 0.1с

**Подготовка**: `CHHapticEngine` инициализируется в `prepareHaptics()` при `onAppear`.

### 2.10 Now Playing (Control Center / Lock Screen)

**Начальная настройка** (при `playStream()`):
- `MPMediaItemPropertyTitle`: текущий трек или "Oton.FM Radio"
- `MPMediaItemPropertyArtist`: "Live Stream"
- `MPMediaItemPropertyArtwork`: текущее изображение обложки

**Обновление при смене трека** (`updateNowPlayingInfo`):
- `MPMediaItemPropertyTitle`: текущий трек или "Oton.FM"
- `MPMediaItemPropertyArtist`: "Oton FM"
- `MPNowPlayingInfoPropertyIsLiveStream`: `true`
- `MPMediaItemPropertyArtwork`: обновленное изображение

**Remote Command Center**:
- `playCommand` -> вызывает `playStream()`
- `pauseCommand` -> вызывает `pause()`
- Оба команды `isEnabled = true`

### 2.11 Фоновое воспроизведение

**Настройка**:
- `Info.plist`: `UIBackgroundModes` = `["audio"]`
- Аудиосессия: категория `.playback`

### 2.12 Splash Screen (загрузочный экран)

**Структура** (`SplashView`):
- Фон: `LinearGradient` от `spotifyBlack` RGB(18/255, 18/255, 18/255) до RGB(25/255, 20/255, 20/255), top -> bottom
- Декоративный эффект: `RadialGradient` -- красный RGB(208/255, 0, 0) с opacity 0.3, центрирован
  - Пульсация: scaleEffect анимируется между 1.0 и 1.2, opacity между 0.3 и 0.7
  - Анимация: `.easeInOut(duration: 1.0).repeatForever(autoreverses: true)`
- Логотип: "otonLogo-Light" из ассетов, 100x100pt
  - Анимация появления: scaleEffect от 0.9 до 1.1, opacity от 0.8 до 1.0
  - Длительность: 1.2с, `.repeatCount(1, autoreverses: false)`

**Таймер отображения**: 2.0 секунды, затем `isActive = false` с анимацией `.easeInOut(duration: 0.5)`

**Цветовая схема**: `.preferredColorScheme(.dark)`

**Launch Screen (системный)**:
- Цвет фона: `launchScreenBackground` = RGB(0.070, 0.070, 0.070) (почти черный, одинаковый для light/dark)

### 2.13 Обработка ошибок с возможностью повтора

**Типы ошибок** (`RadioError`):

| Ошибка | Описание | Рекомендация |
|--------|----------|-------------|
| `networkUnavailable` | "Нет подключения к интернету" | "Проверьте подключение к интернету" |
| `streamUnavailable` | "Радиопоток временно недоступен" | "Попробуйте позже" |
| `bufferingTimeout` | "Превышено время ожидания" | "Попробуйте позже" |
| `invalidAudioFormat` | "Неподдерживаемый формат аудио" | "Обратитесь в поддержку" |
| `unknownError(String)` | Произвольное сообщение | "Попробуйте перезапустить приложение" |

**ErrorView**:
- Иконка: `exclamationmark.triangle.fill` (50pt, красный)
- Заголовок: описание ошибки (headline, белый)
- Рекомендация: (subheadline, белый opacity 0.7)
- Кнопка "Повторить": 16pt semibold, черный текст на белом фоне, форма капсулы
- Фон: черный opacity 0.9, cornerRadius 20
- Padding: 40pt внутренний, 40pt внешний горизонтальный

### 2.14 Анимированные точки "Холбонуу..."

**Компонент AnimatedDots**:
- 3 точки, каждая появляется последовательно
- Таймер: `Timer.publish(every: 0.4)` -- каждые 0.4 секунды
- Цикл: 0 -> 1 -> 2 -> 3 -> 0 (4 состояния)
  - 0: все точки скрыты
  - 1: первая точка видна
  - 2: первая и вторая видны
  - 3: все три видны
- Анимация opacity: `.easeIn`
- Spacing: 2pt между точками

**ConnectingText**:
- Текст: "Холбонуу" (якутское слово, означающее "Подключение")
- Шрифт: system, 22pt, bold, белый
- Высота фрейма: 60pt, выравнивание `.leading`
- AnimatedDots использует тот же шрифт

### 2.15 Адаптивная цветовая схема на основе обложки

**Определение среднего цвета** (`UIImage.averageColor`):
- Использует `CIFilter("CIAreaAverage")` для вычисления среднего цвета изображения
- Рендерится в `RGBA8` bitmap (1x1 пиксель)
- Возвращает `UIColor?`

**Определение светлости** (`UIColor.isLightColor`):
- Метод `getWhite(_:alpha:)` извлекает значение яркости
- Цвет считается светлым если `white > 0.7`

**Применение**:
- Средний цвет обложки используется для верхней части фонового градиента (opacity 0.8)
- Тень под обложкой использует средний цвет обложки (opacity 0.6)

---

## 3. Пользовательские сценарии

### 3.1 Первый запуск приложения
1. Отображается системный Launch Screen (темный фон launchScreenBackground)
2. Инициализируется `AppDelegate`:
   - Настраивается RevenueCat
   - Сохраняется дата первого запуска в `UserDefaults`
3. Показывается `SplashView` с анимированным логотипом (2 секунды)
4. Переход на `ContentView` с анимацией fade-out
5. Интерфейс появляется с opacity-анимацией
6. Отображается дефолтная обложка с анимированными градиентами Якутии
7. Текст "OTON FM" (22pt bold, белый)
8. Кнопка Play (белый круг) по центру
9. Кнопка подарка (premium) в правом верхнем углу

### 3.2 Начало прослушивания
1. Пользователь нажимает кнопку Play
2. Haptic feedback: сложный паттерн (heavy + light через 0.1с)
3. Состояние переходит в "connecting"
4. Текст меняется на "Холбонуу..." с анимированными точками
5. В кнопке Play отображается индикатор буферизации (ProgressView)
6. Начинается воспроизведение потока
7. Запрашивается обложка через Status API
8. Настраивается Now Playing Info
9. Настраивается Remote Command Center
10. Когда буфер заполнен -- состояние "playing"
11. Иконка в кнопке меняется на Pause
12. Обложка начинает пульсировать (scaleEffect 1.0 <-> 1.02)
13. Когда получены метаданные трека -- отображается название
14. Haptic feedback `.medium` при получении названия трека
15. Если загружена реальная обложка -- градиентный фон меняется на адаптивный

### 3.3 Смена трека во время прослушивания
1. AVPlayer получает новые timed metadata
2. Извлекается новое название трека
3. Haptic feedback `.medium`
4. Обновляется текст названия трека с анимацией `.easeInOut(0.5)`
5. Сбрасывается retryCount для загрузки обложки
6. Если название содержит "OtonFM" -- показывается логотип станции
7. Иначе -- запрашивается новая обложка через Status API
8. Если трек отличается -- `hasLoadedRealArtworkOnce` может вернуться к `false` (зависит от логики смены)
9. Обновляется Now Playing Info

### 3.4 Пауза и возобновление
1. Пользователь нажимает Pause
2. Haptic feedback
3. Воспроизведение останавливается (`player.pause()`)
4. Иконка меняется на Play
5. Пульсация обложки прекращается
6. Мониторинг буфера останавливается
7. При возобновлении (нажатие Play):
   - Полный перезапуск потока (`playStream()`)
   - Новый `AVPlayerItem`, новая сессия
   - Повторная настройка Now Playing и Remote Commands

### 3.5 Потеря интернет-соединения
1. AVPlayerItem сообщает об ошибке
2. Состояние: `.error(.streamUnavailable)`
3. Автоматическая попытка переподключения (до 3 раз, с задержкой 2с)
4. Если восстановлено -- возобновление воспроизведения
5. Если не восстановлено -- состояние `.error(.bufferingTimeout)`
6. Отображается ErrorView с кнопкой "Повторить"

### 3.6 Показ Paywall
1. На 3, 6 или 15 день после первого запуска:
   - Проверяется премиум-статус
   - Если не премиум и paywall не показывался сегодня:
     - Через 1 секунду после появления ContentView показывается PaywallView
2. По нажатию на иконку подарка:
   - Показывается PaywallView немедленно
3. После покупки:
   - Закрытие PaywallView
   - Проверка покупки (последние 10 секунд)
   - Показ экрана благодарности

### 3.7 Активация тестового режима Paywall
1. Длинное нажатие (1.5с) на иконку подарка
2. Haptic feedback `.heavy`
3. Если режим был выключен -- включается, через 0.5с показывается paywall
4. Если режим был включен -- выключается

---

## 4. Техническая архитектура

### 4.1 Общая структура (MVVM)

```
App Layer:
  Oton_FMApp (@main) -> SplashView / ContentView

ViewModel Layer:
  RadioPlayer (ObservableObject, singleton)
    - Управление состоянием воспроизведения
    - Загрузка и кэширование обложек
    - Обработка метаданных
    - Now Playing Info

Service Layer:
  AudioServiceWrapper -> AudioService (AudioServiceProtocol)
    - AVPlayer management
    - Buffer monitoring
    - Reconnection logic
    - Metadata observation (KVO)

View Layer:
  ContentView
    |- ArtworkView
    |- TrackInfoView
    |- PlayerControlsView
    |- PaywallView (RevenueCatUI)
  SplashView
  ErrorView
  AnimatedDots / ConnectingText

Model Layer:
  PlayerState (enum)
  TrackInfo (Codable struct)
  RadioError (LocalizedError enum)
  YakutiaGradient (struct)

Utility Layer:
  UIImage+AverageColor
  UIColor+IsLightColor
  RoundedFontProvider (PaywallFontProvider)
  Config (enum, static constants)
  AppDelegate (lifecycle, RevenueCat, paywall logic)
```

### 4.2 Поток данных

```
AVPlayer
  |-- KVO: timedMetadata -> AudioService (delegate) -> AudioServiceWrapper (callback)
  |       -> RadioPlayer.onMetadataReceived -> обновление UI
  |-- Combine: isPlaybackBufferEmpty -> AudioService._isBuffering
  |       -> AudioServiceWrapper.onBufferingStateChanged -> RadioPlayer.isBuffering
  |-- Combine: isPlaybackLikelyToKeepUp -> AudioService._isBuffering
  |       -> аналогично
  |-- Combine: playerState -> AudioServiceWrapper.onConnectingStateChanged
  |       -> RadioPlayer.isConnecting

RadioPlayer (@Published):
  isPlaying -------> ContentView (пульсация, иконка, текст)
  currentTrackTitle -> TrackInfoView, Now Playing
  artworkImage -----> ArtworkView, фон, тень, Now Playing
  artworkId --------> анимация перехода обложки
  isConnecting -----> ConnectingText с AnimatedDots
  isBuffering ------> ProgressView в кнопке
  isDefaultArtworkShown -> градиент Якутии / адаптивный фон
```

### 4.3 Сервисный слой AudioService

**AudioServiceProtocol**:
```swift
protocol AudioServiceProtocol {
    var isPlaying: AnyPublisher<Bool, Never> { get }
    var isBuffering: AnyPublisher<Bool, Never> { get }
    var playerState: AnyPublisher<PlayerState, Never> { get }
    var bufferProgress: AnyPublisher<Float, Never> { get }
    var delegate: AudioServiceDelegate? { get set }
    func play(url: URL)
    func pause()
    func stop()
    func setBufferSize(_ seconds: TimeInterval)
}
```

**AudioServiceDelegate**:
```swift
protocol AudioServiceDelegate: AnyObject {
    func audioService(_ service: AudioServiceProtocol, didUpdateMetadata metadata: [AVMetadataItem])
}
```

**AudioServiceWrapper** -- мост между AudioService (Combine) и RadioPlayer (callbacks):
- Подписывается на `audioService.isPlaying/isBuffering/playerState`
- Прокидывает через `onPlaybackStateChanged/onBufferingStateChanged/onConnectingStateChanged/onError`
- Реализует `AudioServiceDelegate` для прокидывания метаданных через `onMetadataReceived`

### 4.4 Модели данных

**PlayerState**:
```swift
enum PlayerState: Equatable {
    case stopped
    case connecting
    case playing
    case paused
    case buffering
    case error(RadioError)
}
```
Вычисляемые свойства: `isPlaying`, `isConnecting`, `isBuffering`.

**TrackInfo**:
```swift
struct TrackInfo: Codable, Equatable {
    let title: String
    let artworkUrl: String?       // "artwork_url"
    let artworkUrlLarge: String?  // "artwork_url_large"
    var bestArtworkUrl: String?   // artworkUrlLarge ?? artworkUrl
}
```

**RadioStatusResponse**:
```swift
struct RadioStatusResponse: Codable {
    let currentTrack: TrackInfo?  // "current_track"
    let history: [TrackInfo]?
}
```
Примечание: В текущей реализации `RadioStatusResponse` и `TrackInfo` определены, но `RadioPlayer` парсит JSON вручную через `JSONSerialization`, а не через `Codable`.

---

## 5. API-контракты

### 5.1 Radio.co Stream URL

**Endpoint**: `https://s4.radio.co/s696f24a77/listen`
- **Метод**: GET (аудиопоток)
- **Формат**: аудиопоток (обрабатывается AVPlayer)
- **Метаданные**: передаются inline через ICY metadata (timed metadata)

### 5.2 Radio.co Status API

**Endpoint**: `https://public.radio.co/stations/s696f24a77/status`
- **Метод**: GET
- **Формат ответа**: JSON

**Используемые поля ответа**:
```json
{
    "current_track": {
        "title": "Artist - Song Name",
        "artwork_url_large": "https://..."
    }
}
```

**Cache-busting**: `?nocache=<unix_timestamp>` добавляется к URL

**Таймауты**:
- `timeoutIntervalForRequest`: 10 секунд
- `timeoutIntervalForResource`: 10 секунд

### 5.3 Загрузка обложки (artwork)

**Endpoint**: URL из поля `artwork_url_large` ответа Status API
- **Метод**: GET
- **Cache-busting**: `?nocache=<unix_timestamp>`
- **Заголовки**: `Cache-Control: no-cache`
- **Формат ответа**: Image data (PNG/JPEG)
- **Таймаут**: 10 секунд

---

## 6. Ассеты и брендинг

### 6.1 Изображения (Assets.xcassets)

| Имя ассета | Использование | Масштабы |
|------------|--------------|----------|
| `AppIcon` | Иконка приложения | 1x-3x, iPhone, iPad, Watch |
| `defaultArtwork` | Дефолтная обложка (файлы: defaultAsset.png) | 1x, 2x, 3x |
| `otonLogo` | Логотип (неиспользуемый?) | - |
| `otonLogo-Light` | Логотип на splash screen | - |
| `stationLogo` | Логотип станции (используется при OtonFM в названии трека) | - |

### 6.2 Цвета (Assets.xcassets)

| Имя | RGBA | Использование |
|-----|------|--------------|
| `launchScreenBackground` | (0.070, 0.070, 0.070, 1.0) | Системный launch screen |

### 6.3 Шрифты

Приложение использует системные шрифты:
- **Основной текст названия трека**: system, 22pt, bold
- **Кнопка Play/Pause иконка**: system, 30pt, bold
- **Кнопка подарка**: system, 18pt, bold
- **PaywallView**: `.rounded` design через `RoundedFontProvider`

**RoundedFontProvider** маппинг:

| TextStyle | Size | Weight | Design |
|-----------|------|--------|--------|
| largeTitle | 34 | bold | rounded |
| title | 28 | bold | rounded |
| title2 | 22 | bold | rounded |
| title3 | 20 | semibold | rounded |
| headline | 17 | semibold | rounded |
| body | 17 | regular | rounded |
| callout | 16 | regular | rounded |
| subheadline | 15 | regular | rounded |
| footnote | 13 | regular | rounded |
| caption | 12 | regular | rounded |
| caption2 | 11 | regular | rounded |

---

## 7. UI-компоненты (детальная спецификация)

### 7.1 ContentView (основной экран)

**Структура**:
```
ZStack {
    // Слой 1: Фон (градиент Якутии или адаптивный)
    // Слой 2: Экран успешной покупки (условный)
    // Слой 3: Основной интерфейс (условный, isInterfaceVisible)
    VStack(spacing: 0) {
        HStack { Spacer; [Кнопка подарка] }  // Top bar
        Spacer
        ArtworkView                            // Центральная обложка
        Spacer
        VStack(spacing: 30) {
            TrackInfoView                      // Название трека
            PlayerControlsView                 // Кнопка Play/Pause
                .padding(.bottom, 30)
        }
    }
}
```

### 7.2 ArtworkView

**Размеры**: ширина и высота = `UIScreen.main.bounds.width * 0.85`
**Скругление**: `RoundedRectangle(cornerRadius: 10)`
**Тень**: цвет = средний цвет обложки (opacity 0.6), radius=25, y=10
**Пульсация при воспроизведении**: scaleEffect 1.0 <-> 1.02
  - Анимация: `.easeInOut(duration: 1.5).repeatForever(autoreverses: true)`
**Анимация смены обложки**: `.easeInOut(duration: 0.6)`, привязана к `artworkId`

### 7.3 TrackInfoView

**Три состояния**:
1. `isConnecting == true` -> `ConnectingText` ("Холбонуу...")
2. `isPlaying && !trackTitle.isEmpty` -> название трека
3. Иначе -> "OTON FM"

**Стиль текста**: system, 22pt, bold, белый, максимум 2 строки
**Высота фрейма**: 60pt, alignment: `.leading`
**Transition**: `.opacity.combined(with: .move(edge: .bottom))`
**Анимации**: `.easeInOut(duration: 0.5)` для `isConnecting`, `trackTitle`, `isPlaying`
**Horizontal padding**: `UIScreen.main.bounds.width * 0.075`
**Offset**: y = -40pt (поднято вверх)

### 7.4 PlayerControlsView

**Кнопка Play/Pause**:
- Размер: круг 64x64pt, белый фон
- Состояние буферизации: `ProgressView(CircularProgressViewStyle)`, tint=spotifyBlack, scale 1.2
- Состояние Play: `play.fill`, 30pt bold, цвет spotifyBlack, offset x=+2
- Состояние Pause: `pause.fill`, 30pt bold, цвет spotifyBlack
- Анимация нажатия: scaleEffect 0.9 при нажатии, `.easeOut(duration: 0.2)`
- `buttonStyle(.plain)`
- Обработка нажатия: `DragGesture(minimumDistance: 0)` для отслеживания pressed state

**Расположение**: по центру экрана (HStack с Spacer по бокам)

---

## 8. Конфигурация

### 8.1 Config.swift

```swift
enum Config {
    static let revenueCatAPIKey = "appl_SUEUYjngtLhXGzXaOeHnovfAmfS"
    static let radioStreamURL = "https://s4.radio.co/s696f24a77/listen"
    static let radioStatusURL = "https://public.radio.co/stations/s696f24a77/status"
    static let radioStationID = "s696f24a77"
}
```

### 8.2 Info.plist (Oton-FM-Info.plist)

| Ключ | Значение | Описание |
|------|---------|----------|
| `ITSAppUsesNonExemptEncryption` | `false` | Не используется нестандартное шифрование |
| `UIBackgroundModes` | `["audio"]` | Фоновое воспроизведение аудио |
| `UILaunchScreen.UIColorName` | `"launchScreenBackground"` | Цвет фона launch screen |

### 8.3 Entitlements (Oton_FM.entitlements)

| Ключ | Значение |
|------|---------|
| `com.apple.security.app-sandbox` | `true` |
| `com.apple.security.files.user-selected.read-only` | `true` |

### 8.4 Зависимости (SPM)

| Пакет | Версия | Источник |
|-------|--------|----------|
| purchases-ios-spm (RevenueCat) | 5.22.2 | https://github.com/RevenueCat/purchases-ios-spm.git |

### 8.5 UserDefaults ключи

| Ключ | Тип | Описание |
|------|-----|----------|
| `"firstLaunchDate"` | Date | Дата первого запуска приложения |
| `"lastPaywallDisplayDate"` | Date | Дата последнего показа paywall |
| `"paywallTestMode"` | Bool | Режим тестирования paywall |

---

## 9. Структура файлов проекта

```
Oton.FM/
├── Oton_FMApp.swift              # @main точка входа, SplashView/ContentView routing
├── AppDelegate.swift             # UIApplicationDelegate, RevenueCat init, paywall логика
├── Config.swift                  # Конфигурация (API keys, URLs)
├── ConfigExample.swift           # Пример конфигурации (без реальных ключей)
├── ContentView.swift             # RadioPlayer (ViewModel) + SplashView + ContentView
├── YakutiaGradients.swift        # 25 градиентов Якутии (YakutiaGradient, YakutiaGradients)
├── FontProviders.swift           # RoundedFontProvider для PaywallView
├── UIImage+AverageColor.swift    # Extension: средний цвет изображения
├── UIColor+IsLightColor.swift    # Extension: определение светлости цвета
├── Models/
│   ├── PlayerState.swift         # Enum состояний плеера
│   ├── TrackInfo.swift           # Модель трека + RadioStatusResponse
│   └── RadioError.swift          # Enum ошибок с описаниями
├── Views/
│   ├── Player/
│   │   ├── ArtworkView.swift     # Обложка с пульсацией и тенью
│   │   ├── TrackInfoView.swift   # Название трека / "Холбонуу..." / "OTON FM"
│   │   └── PlayerControlsView.swift  # Кнопка Play/Pause с haptic feedback
│   └── Components/
│       ├── AnimatedDots.swift    # AnimatedDots + ConnectingText
│       └── ErrorView.swift       # Экран ошибки с кнопкой повтора
├── Services/
│   ├── AudioServiceProtocol.swift  # Протокол + делегат
│   ├── AudioService.swift          # Реализация: AVPlayer, буферизация, KVO
│   └── AudioServiceWrapper.swift   # Мост: Combine -> callbacks
├── Assets.xcassets/
│   ├── AppIcon.appiconset/       # Иконки (iPhone, iPad, Watch, Marketing)
│   ├── defaultArtwork.imageset/  # Дефолтная обложка (defaultAsset.png)
│   ├── otonLogo.imageset/        # Логотип
│   ├── otonLogo-Light.imageset/  # Логотип (светлый, для splash screen)
│   └── launchScreenBackground.colorset/  # Цвет фона launch screen
└── Oton_FM.entitlements          # App sandbox, file access
```

---

## 10. Известные проблемы и технический долг

### 10.1 Архитектурные проблемы

1. **RadioPlayer как God Object**: `RadioPlayer` совмещает функции ViewModel, сервиса загрузки обложек, менеджера Now Playing и менеджера метаданных. Нарушает Single Responsibility Principle.

2. **RadioPlayer в ContentView.swift**: Класс ViewModel определен в том же файле, что и View. Затрудняет навигацию и поддержку.

3. **Дублирование haptic feedback**: `playComplexHaptic()` реализован дважды с разной логикой -- в `ContentView` (с CHHapticEngine) и в `PlayerControlsView` (с UIImpactFeedbackGenerator). Используется только версия из PlayerControlsView.

4. **Смешанная модель данных**: `TrackInfo` и `RadioStatusResponse` определены как Codable-модели, но `RadioPlayer.fetchArtworkFromStatusAPI()` парсит JSON через `JSONSerialization` вместо использования этих моделей.

5. **AudioServiceWrapper как промежуточный слой**: Wrapper конвертирует Combine publishers в callbacks. При полном переписывании можно использовать Combine напрямую или @Observable.

6. **Синглтон RadioPlayer.shared**: Затрудняет тестирование и подмену зависимостей.

### 10.2 Проблемы с состоянием

7. **hasLoadedRealArtworkOnce не сбрасывается**: Флаг не сбрасывается при смене трека. Если первый трек имел обложку, логотип станции для последующих треков никогда не будет показан как дефолтный.

8. **Рассинхронизация метаданных и обложки**: Timed metadata из потока и Status API могут возвращать информацию о разных треках. Текущая проверка по `title` -- частичное решение.

9. **Нет обработки ошибки сети при загрузке обложки**: Если Status API недоступен, обложка просто не обновляется, без уведомления пользователя.

### 10.3 UI-проблемы

10. **Жестко закодированные размеры**: `UIScreen.main.bounds.width * 0.85`, `UIScreen.main.bounds.width * 0.075`, offset `y: -40` -- не адаптивны для разных размеров экранов и landscape-режима.

11. **Нет поддержки landscape**: Интерфейс рассчитан только на portrait-ориентацию.

12. **Цвет spotifyGreen на самом деле красный**: В `ContentView` переменная `spotifyGreen` содержит красный цвет (0.81, 0.17, 0.17) -- вводящее в заблуждение именование.

13. **ErrorView не подключен к UI**: `ErrorView` определен, но нигде не используется в `ContentView`. Ошибки обрабатываются только на уровне `AudioService`, но не отображаются пользователю.

### 10.4 Производительность

14. **CIFilter для каждого обновления обложки**: `averageColor` пересчитывается при каждом обращении к свойству (нет кэширования).

15. **UIGraphicsImageRenderer для скругления**: Каждая обложка скругляется программно вместо использования SwiftUI `.clipShape`.

16. **Новая URLSession для каждого запроса**: В `fetchArtworkFromStatusAPI` создается новая `URLSession(configuration:)` при каждом вызове вместо переиспользования.

### 10.5 Безопасность

17. **API-ключ RevenueCat в коде**: `Config.swift` содержит реальный API-ключ. Есть `ConfigExample.swift` для шаблона, но `Config.swift` не добавлен в `.gitignore` (присутствует в репозитории).

### 10.6 Недостающая функциональность

18. **Нет обработки прерываний аудиосессии**: Не обрабатываются события типа входящего звонка, Siri, подключения наушников.

19. **Нет индикации качества соединения**: Пользователь не видит текущее состояние буфера.

20. **Нет таймера сна (Sleep Timer)**: Часто запрашиваемая фича для радио-приложений.

21. **Нет возможности поделиться треком**: Отсутствует функция шаринга.

22. **Нет истории треков**: Нет записи прослушанных треков.

23. **Нет виджета**: Отсутствует виджет "Сейчас играет".

24. **setBufferSize не реализован**: Метод протокола `AudioServiceProtocol.setBufferSize(_:)` имеет пустую реализацию.

---

## 11. Константы и магические числа (сводная таблица)

| Константа | Значение | Местоположение | Описание |
|-----------|---------|----------------|----------|
| Скругление обложки (runtime) | `width * 0.062` | ContentView.swift:42 | Radius скругления для UIImage |
| Скругление обложки (SwiftUI) | 10 | ArtworkView.swift:21 | cornerRadius для ClipShape |
| Размер обложки | `screenWidth * 0.85` | ArtworkView.swift:20 | Ширина и высота обложки |
| Horizontal padding | `screenWidth * 0.075` | TrackInfoView.swift:44 | Отступы текста |
| Track title offset | -40pt | TrackInfoView.swift:45 | Смещение текста вверх |
| Play button size | 64pt | PlayerControlsView.swift:35 | Диаметр кнопки |
| Play icon size | 30pt | PlayerControlsView.swift:43 | Размер иконки |
| Play icon offset | +2pt x | PlayerControlsView.swift:45 | Визуальная центровка Play |
| Buffer duration | 10.0с | AudioService.swift:41 | Предпочтительный буфер |
| Buffer check interval | 0.5с | AudioService.swift:42 | Частота проверки буфера |
| Reconnect delay | 2.0с | AudioService.swift:43 | Задержка переподключения |
| Max reconnect attempts | 3 | AudioService.swift:44 | Максимум попыток |
| Artwork retry max | 3 | ContentView.swift:31 | Попытки загрузки обложки |
| Artwork retry delay | `count * 2.0`с | ContentView.swift:145 | Нарастающая задержка |
| Gradient change interval | 10.0с | ContentView.swift:669 | Интервал смены градиента |
| Gradient transition duration | 3.0с | ContentView.swift:670 | Длительность перехода |
| Splash duration | 2.0с | ContentView.swift:368 | Время показа splash |
| Splash fade-out | 0.5с | ContentView.swift:369 | Длительность fade-out |
| AnimatedDots interval | 0.4с | AnimatedDots.swift:5 | Скорость анимации точек |
| Pulsation scale | 1.02 | ArtworkView.swift:23 | Масштаб пульсации |
| Pulsation duration | 1.5с | ArtworkView.swift:24 | Период пульсации |
| Artwork transition | 0.6с | ArtworkView.swift:25 | Переход обложки |
| Text transition | 0.5с | TrackInfoView.swift:39-41 | Переход текста |
| Press scale | 0.9 | PlayerControlsView.swift:48 | Масштаб нажатия |
| Press animation | 0.2с | PlayerControlsView.swift:49 | Анимация нажатия |
| Long press duration | 1.5с | ContentView.swift:510 | Длинное нажатие (test mode) |
| Logo size (splash) | 100pt | ContentView.swift:354 | Размер логотипа |
| Logo scale range | 0.9 - 1.1 | ContentView.swift:355 | Анимация логотипа |
| Paywall target days | 3, 6, 15 | AppDelegate.swift:54 | Дни показа paywall |
| API timeout | 10с | ContentView.swift:78 | Таймаут HTTP-запросов |
| Paywall delay | 1.0с | ContentView.swift:416 | Задержка перед проверкой |
| Purchase success delay | 0.3с | ContentView.swift:534 | Задержка показа success |
| Test mode paywall delay | 0.5с | ContentView.swift:519 | Задержка после активации |
| Artwork shadow radius | 25 | ArtworkView.swift:22 | Радиус тени |
| Artwork shadow opacity | 0.6 | ArtworkView.swift:22 | Прозрачность тени |
| Artwork shadow offset y | 10 | ArtworkView.swift:22 | Смещение тени |
| Background opacity (artwork) | 0.8 | ContentView.swift:436 | Прозрачность верхнего цвета фона |
| Background animation | 0.8с | ContentView.swift:443 | Переход фона |
| Track height | 60pt | TrackInfoView.swift:28 | Высота области названия |
| Bottom spacing | 30pt | ContentView.swift:569, 579 | VStack spacing и padding |
| Top bar padding top | 20pt | ContentView.swift:554 | Отступ сверху |

---

## 12. Рекомендации для перезаписи

### Что сохранить
- Все 25 градиентов Якутии с точными цветами
- Логику интерполяции градиентов (lerp)
- Тайминги анимаций (10с смена, 3с переход)
- UX-логику дефолтной обложки (hasLoadedRealArtworkOnce)
- Текст "Холбонуу..." с анимированными точками
- Haptic feedback паттерны
- Логику показа paywall на 3, 6, 15 день
- Тестовый режим paywall через длинное нажатие
- Cache-busting для обложек
- Now Playing Info с пометкой isLiveStream

### Что улучшить
- Разделить RadioPlayer на отдельные сервисы (ArtworkService, MetadataService, NowPlayingService)
- Использовать Codable-модели вместо ручного парсинга JSON
- Использовать @Observable (iOS 17+) вместо ObservableObject
- Переиспользовать URLSession
- Кэшировать средний цвет обложки
- Подключить ErrorView к отображению ошибок
- Добавить обработку прерываний аудиосессии
- Исправить именование spotifyGreen -> акцентный цвет
- Убрать API-ключ из репозитория
- Добавить адаптивность для разных размеров экрана
- Использовать SwiftUI clipShape вместо программного скругления UIImage
