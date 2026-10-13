# 🦷 AlignerTrack - Guida di Configurazione Xcode (iOS 17+)

Questa guida ti accompagna passo-passo nella creazione del progetto in **Xcode** su macOS per compilare ed eseguire l'applicazione e il relativo **Widget interattivo**.

---

## 1. Struttura del Progetto

I file sorgente Swift creati sono organizzati in:

```text
AlignerTrack/
├── iOS/
│   ├── AlignerTrackApp.swift              # Entry point App SwiftUI
│   ├── Models/
│   │   └── AlignerModel.swift             # Modelli dati (Sessioni, Cicli 14gg, Palette colori)
│   ├── Services/
│   │   └── AlignerDataManager.swift       # Logica di business, calcolo ore perse, suggerimenti recupero
│   ├── Views/
│   │   ├── ContentView.swift              # TabView di navigazione principale
│   │   ├── TodayDashboardView.swift       # Schermata Oggi con anello live e toggle
│   │   ├── CalendarView.swift             # Calendario a colori per ciclo e date di cambio
│   │   ├── RecoveryManagementView.swift   # Gestione recupero, ore saltate e Start Nuovo Ciclo
│   │   ├── StatsView.swift                # Statistiche e grafici ore tenuto/tolto
│   │   └── CycleHistoryView.swift         # Storico mascherine passate e attive
│   └── Widget/
│       ├── AlignerAppIntent.swift         # AppIntent per pulsante interattivo iOS 17
│       ├── AlignerWidget.swift            # Vista Widget Piccolo (e Medio) con timer live
│       └── AlignerWidgetBundle.swift      # Entry point Widget Extension
```

---

## 2. Creazione del Progetto in Xcode

1. Apri **Xcode** (15 o superiore, consigliato Xcode 16).
2. Seleziona **File > New > Project...**
3. Scegli **iOS > App** e clicca **Next**.
4. Configura:
   - **Product Name**: `AlignerTrack`
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage**: `None` (usiamo il data manager integrato condiviso).
5. Seleziona la cartella dove salvare il progetto.

---

## 3. Aggiunta del Widget Extension

1. Con il progetto aperto in Xcode, vai su **File > New > Target...**
2. Seleziona **iOS > Widget Extension** e clicca **Next**.
3. Configura:
   - **Product Name**: `AlignerWidgetExtension`
   - **Include Live Activity**: Opzionale
   - Deseleziona *Include Configuration App Intent* (usiamo `StaticConfiguration` con il nostro `AppIntent` interattivo).
4. Clicca **Finish** e accetta l'eventuale prompt "Activate AlignerWidgetExtension scheme?".

---

## 4. Configurazione App Groups (Condivisione Dati App ↔ Widget)

Per consentire al Widget di alternare istantaneamente lo stato tra "Tolto" e "Rimesso" e sincronizzare il timer con l'App principale:

1. Seleziona il progetto principale nel navigatore a sinistra.
2. Vai sul target principale **AlignerTrack**:
   - Clicca sul tab **Signing & Capabilities**.
   - Clicca su **+ Capability** e seleziona **App Groups**.
   - Aggiungi un nuovo gruppo: `group.com.alignertrack.app` e spuntalo.
3. Vai sul target **AlignerWidgetExtension**:
   - Clicca sul tab **Signing & Capabilities**.
   - Clicca su **+ Capability** e seleziona **App Groups**.
   - Spunta lo stesso gruppo: `group.com.alignertrack.app`.

> 💡 *Nota*: Se desideri cambiare l'identificatore del gruppo (es. con il tuo bundle ID `group.com.tuonome.alignertrack`), modificalo anche in `AlignerModel.swift` nella costante `AppGroupConstants.groupIdentifier`.

---

## 5. Target Membership dei File Swift

Assicurati che i file condivisi siano inclusi in entrambi i target (**AlignerTrack** e **AlignerWidgetExtension**):

| File | Target: AlignerTrack | Target: AlignerWidgetExtension |
|---|:---:|:---:|
| `AlignerModel.swift` | ✅ | ✅ |
| `AlignerAppIntent.swift` | ✅ | ✅ |
| `AlignerDataManager.swift` | ✅ | ✅ |
| `AlignerWidget.swift` | ❌ | ✅ |
| `AlignerWidgetBundle.swift` | ❌ | ✅ |
| Tutte le View in `Views/` | ✅ | ❌ |
| `AlignerTrackApp.swift` | ✅ | ❌ |

*(Per verificare o modificare il Target Membership, seleziona il file in Xcode e controlla la colonna di destra "Inspectors > Target Membership").*

---

## 6. Funzionamento del Widget Interattivo su iOS 17+

- Il widget utilizza **AppIntents (`ToggleAlignerIntent`)**: quando premi **"Tolto"** o **"Rimesso"** direttamente dalla schermata Home, il sistema esegue l'intent in background senza dover aprire forzatamente l'app.
- L'intent aggiorna il container condiviso `UserDefaults(suiteName: "group.com.alignertrack.app")` e chiama `WidgetCenter.shared.reloadAllTimelines()`.
- Quando l'apparecchio è tolto, il widget avvia un timer nativo ad altissima efficienza energetica tramite `Text(startTime, style: .timer)`.
- Quando viene rimesso, calcola la durata, archivia la sessione e mostra il tempo rimanente di pausa consentito per il giorno (max 2h per raggiungere l'obiettivo di 22h).

---

## 7. Funzionamento del Calcolo Giorni di Recupero

L'app applica la formula ortodontica:
- **Obiettivo giornaliero**: 22 ore (1320 minuti).
- **Tempo pausa massimo consentito**: 2 ore (120 minuti).
- **Ciclo base mascherina**: 14 giorni.
- **Deficit accumulato**: $\sum \max(0, 22\text{h} - \text{ore indossate})$.
- **Suggerimento giorni di recupero**: $\lceil \frac{\text{Deficit accumulato}}{22\text{h}} \rceil$ giorni.
- L'utente può visualizzare il suggerimento, cliccare **"Applica"** oppure modificare con i pulsanti `+` e `-` il numero di giorni desiderati.
- Il calendario aggiorna immediatamente la data di fine mascherina e l'inizio della successiva, contrassegnando con un colore distintivo ogni singolo ciclo.
