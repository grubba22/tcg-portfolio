import Foundation

/// Lädt täglich die aktualisierte tcggo.db von GitHub herunter.
/// Wird beim App-Start aufgerufen – läuft im Hintergrund, blockiert die UI nicht.
actor DatabaseUpdateService {
    static let shared = DatabaseUpdateService()

    private let remoteURL = URL(string:
        "https://raw.githubusercontent.com/grubba22/tcg-portfolio/main/sync/tcggo.db"
    )!
    private let lastCheckKey = "dbLastUpdateCheck"
    private let docsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tcggo.db")
    }()

    /// Einmal pro Tag prüfen – sonst sofort zurückkehren.
    func updateIfNeeded() async {
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard !Calendar.current.isDateInToday(lastCheck) else {
            print("[DBUpdate] Heute bereits geprüft – überspringe")
            return
        }
        await download()
    }

    // MARK: - Privat

    private func download() async {
        print("[DBUpdate] Prüfe auf neue DB...")
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("[DBUpdate] ❌ HTTP-Fehler")
                return
            }

            let newSize = fileSize(tempURL)
            let oldSize = fileSize(docsURL)

            guard newSize > oldSize else {
                print("[DBUpdate] Keine neuere DB verfügbar (neu: \(newSize / 1024)KB, alt: \(oldSize / 1024)KB)")
                UserDefaults.standard.set(Date(), forKey: lastCheckKey)
                return
            }

            try? FileManager.default.removeItem(at: docsURL)
            try FileManager.default.moveItem(at: tempURL, to: docsURL)
            print("[DBUpdate] ✅ DB aktualisiert (\(oldSize / 1024)KB → \(newSize / 1024)KB)")

            // DB neu laden
            LocalCardDatabase.shared.reload()
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)

        } catch {
            print("[DBUpdate] ❌ Fehler: \(error)")
        }
    }

    private func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    }
}
