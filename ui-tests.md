# UI Tests для Oton.FM

## Обзор
UI тесты для радио-приложения Oton.FM, учитывающие особенности работы с сетевым аудио и возможные задержки в воспроизведении.

## Настройка тестов

### Конфигурация
```swift
import XCTest

class OtonFMUITests: XCTestCase {
    let app = XCUIApplication()
    let timeout: TimeInterval = 15.0 // Увеличенный таймаут для сетевых запросов
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        
        // Ждем загрузки основного интерфейса
        let mainInterface = app.otherElements["MainPlayerInterface"]
        XCTAssertTrue(mainInterface.waitForExistence(timeout: 10.0))
    }
}
```

## Тест 1: Проверка запуска приложения и отображения основного интерфейса

```swift
func testAppLaunchAndMainInterface() throws {
    // Проверяем, что приложение запустилось
    XCTAssertTrue(app.exists)
    
    // Проверяем наличие основных элементов интерфейса
    let playButton = app.buttons["PlayButton"]
    let trackTitleLabel = app.staticTexts["TrackTitle"]
    let artworkView = app.images["ArtworkView"]
    
    // Ждем появления элементов с учетом возможной загрузки
    XCTAssertTrue(playButton.waitForExistence(timeout: timeout))
    XCTAssertTrue(trackTitleLabel.waitForExistence(timeout: timeout))
    XCTAssertTrue(artworkView.waitForExistence(timeout: timeout))
    
    // Проверяем, что кнопка воспроизведения в состоянии "Play"
    XCTAssertTrue(playButton.isEnabled)
    XCTAssertEqual(playButton.label, "Play")
}
```

## Тест 2: Тестирование воспроизведения аудио с учетом сетевых задержек

```swift
func testAudioPlaybackWithNetworkDelay() throws {
    let playButton = app.buttons["PlayButton"]
    
    // Нажимаем кнопку воспроизведения
    playButton.tap()
    
    // Ждем изменения состояния кнопки (может быть задержка из-за сетевого подключения)
    let connectingIndicator = app.activityIndicators["ConnectingIndicator"]
    if connectingIndicator.waitForExistence(timeout: 5.0) {
        // Если есть индикатор подключения, ждем его исчезновения
        XCTAssertFalse(connectingIndicator.waitForExistence(timeout: timeout))
    }
    
    // Проверяем, что кнопка изменилась на "Pause" (с учетом задержки)
    let pauseButton = app.buttons["PauseButton"]
    XCTAssertTrue(pauseButton.waitForExistence(timeout: timeout))
    
    // Проверяем, что появился индикатор буферизации или воспроизведения
    let bufferingIndicator = app.activityIndicators["BufferingIndicator"]
    let playingIndicator = app.images["PlayingIndicator"]
    
    // Ждем либо буферизации, либо начала воспроизведения
    let playbackStarted = bufferingIndicator.waitForExistence(timeout: 3.0) || 
                         playingIndicator.waitForExistence(timeout: 3.0)
    XCTAssertTrue(playbackStarted, "Воспроизведение не началось в течение ожидаемого времени")
    
    // Останавливаем воспроизведение
    pauseButton.tap()
    
    // Проверяем возврат к состоянию "Play"
    XCTAssertTrue(playButton.waitForExistence(timeout: 5.0))
}
```

## Тест 3: Тестирование обновления метаданных трека

```swift
func testTrackMetadataUpdate() throws {
    let trackTitleLabel = app.staticTexts["TrackTitle"]
    let artistLabel = app.staticTexts["ArtistName"]
    let artworkView = app.images["ArtworkView"]
    
    // Запоминаем начальные значения
    let initialTitle = trackTitleLabel.label
    let initialArtist = artistLabel.label
    
    // Запускаем воспроизведение
    let playButton = app.buttons["PlayButton"]
    playButton.tap()
    
    // Ждем изменения метаданных (может занять время из-за сетевых запросов)
    let metadataUpdateTimeout: TimeInterval = 30.0 // Увеличенный таймаут для обновления метаданных
    
    // Проверяем, что метаданные обновились
    let titleChanged = expectation(description: "Track title changed")
    let artistChanged = expectation(description: "Artist name changed")
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        if trackTitleLabel.label != initialTitle {
            titleChanged.fulfill()
        }
        if artistLabel.label != initialArtist {
            artistChanged.fulfill()
        }
    }
    
    // Ждем изменения хотя бы одного из метаданных
    wait(for: [titleChanged, artistChanged], timeout: metadataUpdateTimeout)
    
    // Проверяем, что обложка загрузилась (не дефолтная)
    let defaultArtwork = app.images["DefaultArtwork"]
    XCTAssertFalse(defaultArtwork.exists, "Отображается дефолтная обложка вместо загруженной")
}
```

## Тест 4: Тестирование Paywall функциональности

```swift
func testPaywallFunctionality() throws {
    // Находим кнопку премиум (подарок)
    let premiumButton = app.buttons["PremiumButton"]
    XCTAssertTrue(premiumButton.waitForExistence(timeout: 10.0))
    
    // Нажимаем на кнопку премиум
    premiumButton.tap()
    
    // Ждем появления Paywall
    let paywallView = app.otherElements["PaywallView"]
    XCTAssertTrue(paywallView.waitForExistence(timeout: 10.0))
    
    // Проверяем наличие элементов Paywall
    let closeButton = app.buttons["PaywallCloseButton"]
    let subscriptionOptions = app.buttons.matching(identifier: "SubscriptionOption")
    
    XCTAssertTrue(closeButton.exists)
    XCTAssertGreaterThan(subscriptionOptions.count, 0, "Нет доступных вариантов подписки")
    
    // Проверяем, что есть хотя бы один вариант подписки
    let firstSubscription = subscriptionOptions.element(boundBy: 0)
    XCTAssertTrue(firstSubscription.isEnabled)
    
    // Закрываем Paywall
    closeButton.tap()
    
    // Проверяем, что Paywall закрылся
    XCTAssertFalse(paywallView.waitForExistence(timeout: 5.0))
}
```

## Тест 5: Тестирование обработки ошибок сети

```swift
func testNetworkErrorHandling() throws {
    // Запускаем воспроизведение
    let playButton = app.buttons["PlayButton"]
    playButton.tap()
    
    // Ждем возможного появления ошибки сети
    let errorView = app.otherElements["ErrorView"]
    let retryButton = app.buttons["RetryButton"]
    
    // Проверяем, что либо воспроизведение началось, либо появилась ошибка
    let playbackStarted = app.buttons["PauseButton"].waitForExistence(timeout: 10.0)
    let errorOccurred = errorView.waitForExistence(timeout: 10.0)
    
    XCTAssertTrue(playbackStarted || errorOccurred, "Нет ни воспроизведения, ни ошибки")
    
    if errorOccurred {
        // Если появилась ошибка, проверяем наличие кнопки повтора
        XCTAssertTrue(retryButton.exists)
        
        // Нажимаем кнопку повтора
        retryButton.tap()
        
        // Ждем исчезновения ошибки
        XCTAssertFalse(errorView.waitForExistence(timeout: timeout))
        
        // Проверяем, что воспроизведение возобновилось
        let pauseButton = app.buttons["PauseButton"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: timeout))
    }
}
```

## Дополнительные утилиты для тестов

### Хелперы для работы с ожиданиями
```swift
extension XCTestCase {
    func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 10.0) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10.0) -> Bool {
        return !element.waitForExistence(timeout: timeout)
    }
    
    func waitForCondition(_ condition: @escaping () -> Bool, timeout: TimeInterval = 10.0) {
        let expectation = XCTestExpectation(description: "Condition met")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if condition() {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}
```

### Константы для тестов
```swift
struct UITestConstants {
    static let networkTimeout: TimeInterval = 15.0
    static let animationTimeout: TimeInterval = 3.0
    static let metadataUpdateTimeout: TimeInterval = 30.0
    static let errorHandlingTimeout: TimeInterval = 10.0
    
    struct AccessibilityIdentifiers {
        static let playButton = "PlayButton"
        static let pauseButton = "PauseButton"
        static let trackTitle = "TrackTitle"
        static let artistName = "ArtistName"
        static let artworkView = "ArtworkView"
        static let connectingIndicator = "ConnectingIndicator"
        static let bufferingIndicator = "BufferingIndicator"
        static let playingIndicator = "PlayingIndicator"
        static let premiumButton = "PremiumButton"
        static let paywallView = "PaywallView"
        static let paywallCloseButton = "PaywallCloseButton"
        static let subscriptionOption = "SubscriptionOption"
        static let errorView = "ErrorView"
        static let retryButton = "RetryButton"
    }
}
```

## Запуск тестов

### Командная строка
```bash
# Запуск всех UI тестов
xcodebuild test -project Oton.FM.xcodeproj -scheme Oton.FM -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' -only-testing:Oton.FMUITests

# Запуск конкретного теста
xcodebuild test -project Oton.FM.xcodeproj -scheme Oton.FM -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' -only-testing:Oton.FMUITests/OtonFMUITests/testAudioPlaybackWithNetworkDelay
```

### Через Xcode
1. Откройте проект в Xcode
2. Выберите схему Oton.FM
3. Перейдите в Test Navigator (⌘+6)
4. Запустите UI тесты

## Примечания

1. **Сетевые задержки**: Все тесты учитывают возможные задержки при работе с сетевым аудио
2. **Таймауты**: Использованы увеличенные таймауты для сетевых операций
3. **Обработка ошибок**: Тесты проверяют как успешные сценарии, так и обработку ошибок
4. **Accessibility**: Все элементы должны иметь правильные accessibility identifiers
5. **Стабильность**: Тесты написаны с учетом возможных нестабильностей сети

## Требования к приложению

Для корректной работы тестов приложение должно:
- Иметь правильные accessibility identifiers для всех элементов
- Корректно обрабатывать сетевые ошибки
- Показывать индикаторы загрузки и состояния
- Правильно обновлять UI при изменении состояния воспроизведения 