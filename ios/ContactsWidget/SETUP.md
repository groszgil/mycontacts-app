# הגדרת ווידג'ט מסך הבית

## שלבים ב-Xcode

### 1. פתח את הפרויקט
פתח `ios/Runner.xcworkspace` ב-Xcode.

### 2. הוסף Widget Extension Target
- **File → New → Target**
- בחר **Widget Extension**
- **Product Name:** `ContactsWidget`
- **Bundle Identifier:** `com.mycontacts.myContacts.ContactsWidget`
- בטל את הסימון **Include Configuration Intent**
- לחץ **Finish** (בחר **Cancel** כשישאל אם להפעיל scheme חדש)

### 3. החלף את קבצי Swift
- מחק את הקבצים שנוצרו אוטומטית (`ContactsWidget.swift` + Bundle)
- גרור מ-Finder לתוך ה-Target את:
  - `ios/ContactsWidget/ContactsWidget.swift`
  - `ios/ContactsWidget/ContactsWidgetBundle.swift`

### 4. הפעל App Groups בשני ה-Targets
עבור כל אחד מה-Targets (`Runner` ו-`ContactsWidget`):
- בחר את ה-Target
- לשונית **Signing & Capabilities**
- לחץ **+ Capability**
- הוסף **App Groups**
- הוסף Group ID: **`group.com.mycontacts.myContacts`**

### 5. עדכן את הווידג'ט אחרי כל שינוי
בפלאטר הווידג'ט מתעדכן אוטומטית כשאנשי קשר משתנים (StorageService._updateHomeWidget).

## הגדרת Deep Link (אופציונלי)
כדי שלחיצה על איש קשר בווידג'ט תחייג ישירות:
- ב-`AppDelegate.swift` הוסף טיפול ב-URL scheme `mycontacts://call/PHONE`
- הוסף ל-Info.plist תחת `CFBundleURLTypes` את scheme `mycontacts`
