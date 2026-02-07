# Oton.FM — Firebase Contract для Android

## Проект
- **Firebase Project ID**: `oton-fm`
- **Console**: https://console.firebase.google.com/project/oton-fm

## Подключение
- Firebase Android SDK (BOM)
- Модули: **Firebase Auth**, **Firebase Firestore**, **Firebase Messaging**
- `google-services.json` — скачать из Console → Project Settings → Android app

---

## 1. Authentication

**Метод**: Anonymous Auth (единственный включённый)

```kotlin
FirebaseAuth.getInstance().signInAnonymously()
```

- UID сохраняется между сессиями автоматически
- Анонимный вход выполняется **до** любых обращений к Firestore
- Профиль (имя, флаг) хранится локально + синкается в Firestore `users/{uid}`

---

## 2. Firestore — Коллекции

### `users/{uid}`

Создаётся при онбординге (первая отправка сообщения в чат).

| Поле | Тип | Описание | Кто пишет |
|------|-----|----------|-----------|
| `displayName` | string | Имя пользователя | Клиент |
| `countryFlag` | string | Флаг-эмодзи (напр. "🇷🇺") | Клиент |
| `isAdmin` | boolean | Админ-флаг | **Только Console** |
| `isPremium` | boolean | Премиум-флаг | **Только Console** |
| `lastMessageAt` | timestamp | Время последнего сообщения | Клиент |
| `createdAt` | timestamp | Дата регистрации | Клиент |

**Правила**:
- Читать/писать можно **только свой** документ (`uid == auth.uid`)
- Клиент **не может** менять `isAdmin` и `isPremium`
- `setData(..., merge: true)` при создании — чтобы не затирать поля, выставленные админом

### `messages/{auto-id}`

| Поле | Тип | Описание |
|------|-----|----------|
| `text` | string | Текст сообщения (1–500 символов) |
| `type` | string | `"userMessage"` или `"songRequest"` |
| `authorId` | string | Firebase UID автора |
| `authorName` | string | Имя (денормализовано) |
| `authorFlag` | string | Флаг-эмодзи |
| `authorIsAdmin` | boolean | Админ-флаг на момент отправки |
| `authorIsPremium` | boolean | Премиум-флаг |
| `songTitle` | string? | Название песни (для songRequest) |
| `songArtist` | string? | Исполнитель (для songRequest) |
| `isPinned` | boolean | Закреплено |
| `isUrgent` | boolean | Срочное |
| `createdAt` | timestamp | `FieldValue.serverTimestamp()` |

**Правила**:
- **read**: любой авторизованный пользователь
- **create**: авторизованный, `authorId == auth.uid`, `type` только `userMessage`/`songRequest`, `text` 1–500 символов
- **update/delete**: запрещено

**Запросы**:
- Последние 50: `.orderBy("createdAt", descending).limit(50)` → реверс на клиенте
- Real-time listener: `.orderBy("createdAt").whereGreaterThan("createdAt", now)` — только новые

### `admin_status/current` (один документ)

| Поле | Тип | Описание |
|------|-----|----------|
| `text` | string | Текст статуса |
| `type` | string | `"normal"` или `"urgent"` |
| `isActive` | boolean | Показывать или нет |
| `updatedAt` | timestamp | Когда обновлён |

**Правила**:
- **read**: любой авторизованный
- **write**: запрещено (только через Firebase Console)

**Listener**: `addSnapshotListener` на `admin_status/current`. Если `isActive == false` — скрывать баннер.

---

## 3. FCM Push-уведомления

- При получении FCM token → `FirebaseMessaging.getInstance().subscribeToTopic("all_users")`
- Пуши отправляются через Firebase Console → Cloud Messaging → topic `all_users`
- Foreground: показывать как notification (banner + sound)

---

## 4. Онбординг (UX-контракт)

Онбординг показывается **при первой попытке отправить сообщение** в чат, а не при запуске приложения.

Поля:
- **Имя** (текстовое поле)
- **Страна** (флаг-эмодзи). Приоритетные: 🇷🇺 🇰🇿 🇺🇸 🇫🇷 🇩🇪 🇨🇾, затем остальные

После заполнения:
1. Сохранить в локальное хранилище (SharedPreferences)
2. `users/{uid}.setData(...)` в Firestore
3. Отправить отложенное сообщение

`isOnboarded` = имя не пустое в локальном хранилище.

---

## 5. Client-side ограничения

- **Cooldown**: 10 секунд между сообщениями (блокировка кнопки + обратный отсчёт в placeholder)
- **Длина текста**: макс. 500 символов (валидация на клиенте + enforced в rules)
- **Тип сообщения**: клиент может отправить только `userMessage` или `songRequest`

---

## 6. Цвет имени в чате

Детерминированный по хешу имени из палитры 8 цветов:

```
#F27A38  // warm orange
#D9A6D9  // soft purple
#80ADD9  // sky blue
#F28533  // amber
#33CCE6  // cyan
#D99A4D  // golden
#1ABF73  // emerald
#F24073  // rose
```

`color = palette[abs(name.hashCode()) % 8]`

---

## 7. Типы сообщений в чате

| type | Кто создаёт | Описание |
|------|------------|----------|
| `userMessage` | Клиент | Обычное сообщение |
| `songRequest` | Клиент | Заявка на песню (+ songTitle, songArtist) |
| `adminAnnouncement` | Console | Объявление от админа (может быть pinned) |
| `system` | Console | Системное сообщение |

Клиент **отображает** все 4 типа, но **создавать** может только первые два.

---

## 8. Firestore Security Rules

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    match /messages/{messageId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && request.resource.data.authorId == request.auth.uid
        && request.resource.data.type in ['userMessage', 'songRequest']
        && request.resource.data.text is string
        && request.resource.data.text.size() > 0
        && request.resource.data.text.size() <= 500;
      allow update, delete: if false;
    }

    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null
        && request.auth.uid == userId
        && request.resource.data.isAdmin == false
        && request.resource.data.isPremium == false;
      allow update: if request.auth != null
        && request.auth.uid == userId
        && (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['isAdmin', 'isPremium']));
      allow delete: if false;
    }

    match /admin_status/{docId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

---

## 9. Настройка Firebase Console (ручные действия)

1. Authentication → Sign-in method → Anonymous → **Enabled**
2. Firestore → `admin_status/current` — документ уже создан
3. Cloud Messaging → загрузить APNs key (.p8) для iOS
4. Назначить админа: Firestore → `users/{uid}` → `isAdmin: true`
5. Пуши: Cloud Messaging → New campaign → Topic: `all_users`
6. Admin status: Firestore → `admin_status/current` → изменить `text`, `type`, `isActive`
