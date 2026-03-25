"""
TCGGO API Sync Script
=====================
Lädt alle Karten + Produkte von der TCGGO API und speichert
sie in einer optimierten SQLite-Datenbank.

Tabellen:
  episodes      – Sets (einmal gespeichert)
  artists       – Künstler (einmal gespeichert)
  cards         – ~20.000 Karten mit allen Preisfeldern
  products      – ~3.000 Sealed Produkte mit allen Preisfeldern
  price_history – täglicher Preisverlauf pro Karte

Modi:
  python tcggo_sync.py           → Erster Sync (lädt fehlende Episodes)
  python tcggo_sync.py --update  → Tägliches Preis-Update (alle bekannten Episodes)

Hartes Limit: 3.000 Requests / 24h
Tägliches Update: ~370 Requests
"""

import sqlite3
import requests
import time
import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

# ─────────────────────────────────────────────────────────────
# KONFIGURATION
# ─────────────────────────────────────────────────────────────
RAPIDAPI_KEY          = "973b910ce3msh50f372c62250143p1a6f6fjsnb7339db14509"
BASE_URL              = "https://cardmarket-api-tcg.p.rapidapi.com"
HEADERS               = {
    "X-RapidAPI-Key":  "973b910ce3msh50f372c62250143p1a6f6fjsnb7339db14509",
    "X-RapidAPI-Host": "cardmarket-api-tcg.p.rapidapi.com"
}

# Pfade – liegen neben dem Script
BASE_DIR          = Path(__file__).parent
DB_PATH           = BASE_DIR / "tcggo.db"
LOG_PATH          = BASE_DIR / "tcggo_sync.log"
REQUEST_LOG_PATH  = BASE_DIR / "request_count.json"

MAX_REQUESTS_PER_24H    = 3000
SLEEP_BETWEEN_REQUESTS  = 0.3   # Sekunden (verhindert Rate-Limit 429)


# ─────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────
def log(msg: str):
    ts   = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(line + "\n")


# ─────────────────────────────────────────────────────────────
# 24h REQUEST-LIMIT
# ─────────────────────────────────────────────────────────────
def _load_req() -> dict:
    if REQUEST_LOG_PATH.exists():
        with open(REQUEST_LOG_PATH) as f:
            return json.load(f)
    return {"count": 0, "window_start": datetime.now().isoformat()}

def _save_req(data: dict):
    with open(REQUEST_LOG_PATH, "w") as f:
        json.dump(data, f)

def check_limit() -> bool:
    """True = Request erlaubt. False = Limit erreicht → Abbruch."""
    data  = _load_req()
    start = datetime.fromisoformat(data["window_start"])
    if datetime.now() - start > timedelta(hours=24):
        data = {"count": 0, "window_start": datetime.now().isoformat()}
    if data["count"] >= MAX_REQUESTS_PER_24H:
        remaining = timedelta(hours=24) - (datetime.now() - start)
        log(f"!!! HARTES LIMIT: {MAX_REQUESTS_PER_24H} Requests erreicht. "
            f"Nächstes Fenster in {str(remaining).split('.')[0]}.")
        return False
    data["count"] += 1
    _save_req(data)
    return True

def requests_used() -> int:
    return _load_req().get("count", 0)


# ─────────────────────────────────────────────────────────────
# DATENBANK SETUP
# ─────────────────────────────────────────────────────────────
def setup_db(conn: sqlite3.Connection):
    c = conn.cursor()

    # ── episodes ────────────────────────────────────────────
    c.execute("""
        CREATE TABLE IF NOT EXISTS episodes (
            id                   INTEGER PRIMARY KEY,
            name                 TEXT NOT NULL,
            slug                 TEXT,
            code                 TEXT,
            released_at          TEXT,
            logo                 TEXT,
            cards_total          INTEGER DEFAULT 0,
            cards_printed_total  INTEGER DEFAULT 0,
            game_name            TEXT,
            series_name          TEXT,
            synced_at            TEXT
        )
    """)

    # ── artists ─────────────────────────────────────────────
    c.execute("""
        CREATE TABLE IF NOT EXISTS artists (
            id        INTEGER PRIMARY KEY,
            name      TEXT NOT NULL,
            slug      TEXT
        )
    """)

    # ── cards ───────────────────────────────────────────────
    c.execute("""
        CREATE TABLE IF NOT EXISTS cards (
            id                   INTEGER PRIMARY KEY,
            name                 TEXT NOT NULL,
            name_numbered        TEXT,
            slug                 TEXT,
            card_number          TEXT,
            hp                   INTEGER,
            rarity               TEXT,
            supertype            TEXT,
            tcgid                TEXT,
            cardmarket_id        INTEGER,
            tcgplayer_id         INTEGER,
            episode_id           INTEGER REFERENCES episodes(id),
            artist_id            INTEGER REFERENCES artists(id),
            image                TEXT,
            tcggo_url            TEXT,
            link_cardmarket      TEXT,
            link_tcgplayer       TEXT,
            -- Cardmarket Preise
            cm_lowest_nm         REAL,
            cm_lowest_nm_eu      REAL,
            cm_lowest_nm_de      REAL,
            cm_lowest_nm_de_eu   REAL,
            cm_lowest_nm_fr      REAL,
            cm_lowest_nm_es      REAL,
            cm_lowest_nm_it      REAL,
            cm_avg_30d           REAL,
            cm_avg_7d            REAL,
            -- TCGPlayer Preise
            tcp_market           REAL,
            tcp_mid              REAL,
            -- Graded Preise (eigene Felder für schnelle Queries)
            psa10                REAL,
            psa9                 REAL,
            psa8                 REAL,
            bgs9                 REAL,
            bgs8                 REAL,
            cgc10                REAL,
            cgc9                 REAL,
            cgc8                 REAL,
            synced_at            TEXT
        )
    """)

    # ── products ────────────────────────────────────────────
    c.execute("""
        CREATE TABLE IF NOT EXISTS products (
            id                   INTEGER PRIMARY KEY,
            name                 TEXT NOT NULL,
            slug                 TEXT,
            cardmarket_id        INTEGER,
            tcgplayer_id         INTEGER,
            episode_id           INTEGER REFERENCES episodes(id),
            image                TEXT,
            tcggo_url            TEXT,
            link_cardmarket      TEXT,
            -- Cardmarket Preise (andere Feldnamen als Karten!)
            cm_lowest            REAL,
            cm_lowest_eu         REAL,
            cm_lowest_de         REAL,
            cm_lowest_de_eu      REAL,
            cm_lowest_fr         REAL,
            cm_lowest_es         REAL,
            cm_lowest_it         REAL,
            synced_at            TEXT
        )
    """)

    # ── sync_log ─────────────────────────────────────────────
    c.execute("""
        CREATE TABLE IF NOT EXISTS sync_log (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at   TEXT,
            finished_at  TEXT,
            episodes     INTEGER DEFAULT 0,
            artists      INTEGER DEFAULT 0,
            cards        INTEGER DEFAULT 0,
            products     INTEGER DEFAULT 0,
            requests     INTEGER DEFAULT 0,
            status       TEXT
        )
    """)

    # ── price_history ─────────────────────────────────────────
    c.execute("""
        CREATE TABLE IF NOT EXISTS price_history (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            cardmarket_id  INTEGER NOT NULL,
            date           TEXT NOT NULL,
            cm_low         REAL,
            tcp_market     REAL
        )
    """)
    c.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_ph_card_date
        ON price_history (cardmarket_id, date)
    """)

    # ── Indexes für schnelle Suche in der App ────────────────
    c.execute("CREATE INDEX IF NOT EXISTS idx_cards_name       ON cards(name)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_cards_episode    ON cards(episode_id)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_cards_rarity     ON cards(rarity)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_cards_artist     ON cards(artist_id)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_products_name    ON products(name)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_products_episode ON products(episode_id)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_ph_cardmarket    ON price_history(cardmarket_id)")

    conn.commit()
    log("Datenbank bereit.")


# ─────────────────────────────────────────────────────────────
# API REQUESTS
# ─────────────────────────────────────────────────────────────
def api_get(endpoint: str, params: dict = {}) -> dict | None:
    if not check_limit():
        raise RuntimeError("Hartes 24h-Limit erreicht.")
    url = f"{BASE_URL}/{endpoint}"
    try:
        r = requests.get(url, headers=HEADERS, params=params, timeout=15)
        r.raise_for_status()
        time.sleep(SLEEP_BETWEEN_REQUESTS)
        return r.json()
    except requests.exceptions.HTTPError as e:
        log(f"  HTTP Fehler {r.status_code} bei {endpoint} params={params}: {e}")
        if r.status_code == 429:
            log("  Rate-Limit! Warte 10 Sekunden...")
            time.sleep(10)
        return None
    except requests.exceptions.RequestException as e:
        log(f"  Request Fehler bei {endpoint}: {e}")
        return None


def fetch_all_pages(endpoint: str, params: dict = {}) -> list:
    """Lädt alle Seiten eines paginierten Endpoints."""
    all_items = []
    page      = 1
    while True:
        data = api_get(endpoint, {**params, "page": page})
        if not data:
            break
        items = data.get("data", [])
        if not items:
            break
        all_items.extend(items)
        paging      = data.get("paging", {})
        total_pages = paging.get("total", 1)
        if page >= total_pages:
            break
        page += 1
    return all_items


# ─────────────────────────────────────────────────────────────
# HILFSFUNKTIONEN
# ─────────────────────────────────────────────────────────────
def _f(d: dict, *keys):
    """Sicheres Abrufen verschachtelter Felder. Gibt None zurück wenn nicht vorhanden."""
    val = d
    for k in keys:
        if not isinstance(val, dict):
            return None
        val = val.get(k)
    return val if not isinstance(val, dict) else None


def _graded(cm: dict, grader: str, grade: str):
    """Graded-Preis sicher auslesen."""
    g = cm.get("graded")
    if not isinstance(g, dict):
        return None
    return _f(g, grader, grade)


# ─────────────────────────────────────────────────────────────
# SPEICHERN
# ─────────────────────────────────────────────────────────────
def upsert_episode(conn: sqlite3.Connection, ep: dict):
    conn.execute("""
        INSERT OR REPLACE INTO episodes
            (id, name, slug, code, released_at, logo,
             cards_total, cards_printed_total,
             game_name, series_name, synced_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)
    """, (
        ep.get("id"),
        ep.get("name"),
        ep.get("slug"),
        ep.get("code"),
        ep.get("released_at"),
        ep.get("logo"),
        ep.get("cards_total", 0),
        ep.get("cards_printed_total", 0),
        _f(ep, "game", "name"),
        _f(ep, "series", "name"),
        datetime.now().isoformat()
    ))


def upsert_artist(conn: sqlite3.Connection, artist: dict | None):
    if not artist or not artist.get("id"):
        return
    conn.execute("""
        INSERT OR IGNORE INTO artists (id, name, slug)
        VALUES (?, ?, ?)
    """, (artist.get("id"), artist.get("name"), artist.get("slug")))


def upsert_card(conn: sqlite3.Connection, card: dict):
    prices = card.get("prices") or {}
    cm  = prices.get("cardmarket") or {}
    tcp = prices.get("tcg_player") or {}

    conn.execute("""
        INSERT OR REPLACE INTO cards (
            id, name, name_numbered, slug, card_number,
            hp, rarity, supertype, tcgid,
            cardmarket_id, tcgplayer_id,
            episode_id, artist_id,
            image, tcggo_url, link_cardmarket, link_tcgplayer,
            cm_lowest_nm, cm_lowest_nm_eu,
            cm_lowest_nm_de, cm_lowest_nm_de_eu,
            cm_lowest_nm_fr, cm_lowest_nm_es, cm_lowest_nm_it,
            cm_avg_30d, cm_avg_7d,
            tcp_market, tcp_mid,
            psa10, psa9, psa8,
            bgs9, bgs8,
            cgc10, cgc9, cgc8,
            synced_at
        ) VALUES (
            ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,
            ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?
        )
    """, (
        card.get("id"),
        card.get("name"),
        card.get("name_numbered"),
        card.get("slug"),
        card.get("card_number"),
        card.get("hp"),
        card.get("rarity"),
        card.get("supertype"),
        card.get("tcgid"),
        card.get("cardmarket_id"),
        card.get("tcgplayer_id"),
        _f(card, "episode", "id"),
        _f(card, "artist", "id"),
        card.get("image"),
        card.get("tcggo_url"),
        _f(card, "links", "cardmarket"),
        _f(card, "links", "tcgplayer"),
        # Cardmarket
        cm.get("lowest_near_mint"),
        cm.get("lowest_near_mint_EU_only"),
        cm.get("lowest_near_mint_DE"),
        cm.get("lowest_near_mint_DE_EU_only"),
        cm.get("lowest_near_mint_FR"),
        cm.get("lowest_near_mint_ES"),
        cm.get("lowest_near_mint_IT"),
        cm.get("30d_average"),
        cm.get("7d_average"),
        # TCGPlayer
        tcp.get("market_price"),
        tcp.get("mid_price"),
        # Graded
        _graded(cm, "psa", "psa10"),
        _graded(cm, "psa", "psa9"),
        _graded(cm, "psa", "psa8"),
        _graded(cm, "bgs", "bgs9"),
        _graded(cm, "bgs", "bgs8"),
        _graded(cm, "cgc", "cgc10"),
        _graded(cm, "cgc", "cgc9"),
        _graded(cm, "cgc", "cgc8"),
        datetime.now().isoformat()
    ))


def upsert_product(conn: sqlite3.Connection, product: dict):
    prices = product.get("prices") or {}
    cm = prices.get("cardmarket") or {}

    conn.execute("""
        INSERT OR REPLACE INTO products (
            id, name, slug,
            cardmarket_id, tcgplayer_id,
            episode_id,
            image, tcggo_url, link_cardmarket,
            cm_lowest, cm_lowest_eu,
            cm_lowest_de, cm_lowest_de_eu,
            cm_lowest_fr, cm_lowest_es, cm_lowest_it,
            synced_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    """, (
        product.get("id"),
        product.get("name"),
        product.get("slug"),
        product.get("cardmarket_id"),
        product.get("tcgplayer_id"),
        _f(product, "episode", "id"),
        product.get("image"),
        product.get("tcggo_url"),
        _f(product, "links", "cardmarket"),
        # Cardmarket (andere Feldnamen als Karten)
        cm.get("lowest"),
        cm.get("lowest_EU_only"),
        cm.get("lowest_DE"),
        cm.get("lowest_DE_EU_only"),
        cm.get("lowest_FR"),
        cm.get("lowest_ES"),
        cm.get("lowest_IT"),
        datetime.now().isoformat()
    ))


# ─────────────────────────────────────────────────────────────
# PREIS-HISTORY
# ─────────────────────────────────────────────────────────────
def save_price_history(conn: sqlite3.Connection, cardmarket_id: int,
                       cm_low: float | None, tcp_market: float | None,
                       date_str: str):
    """Speichert Preis in price_history (einmal pro Tag per INSERT OR IGNORE)."""
    if cardmarket_id is None:
        return
    conn.execute("""
        INSERT OR IGNORE INTO price_history (cardmarket_id, date, cm_low, tcp_market)
        VALUES (?, ?, ?, ?)
    """, (cardmarket_id, date_str, cm_low, tcp_market))


def update_episode_cards(conn: sqlite3.Connection, ep_id: int, ep_name: str,
                         date_str: str) -> tuple[int, int]:
    """
    Aktualisiert Preise aller Karten + Produkte einer Episode via API.
    Schreibt alten cm_low vor dem Update in price_history.
    Gibt (n_cards, n_products) zurück.
    """
    # ── Karten ──────────────────────────────────────────────
    cards = fetch_all_pages(f"pokemon/episodes/{ep_id}/cards")
    for card in cards:
        cardmarket_id = card.get("cardmarket_id")
        prices = card.get("prices") or {}
        cm  = prices.get("cardmarket") or {}
        tcp = prices.get("tcg_player") or {}

        cm_low     = cm.get("lowest_near_mint")
        tcp_market = tcp.get("market_price")

        # Alten Preis aus DB holen und in History sichern (vor Überschreiben)
        old = conn.execute(
            "SELECT cm_lowest_nm, tcp_market FROM cards WHERE cardmarket_id = ?",
            (cardmarket_id,)
        ).fetchone()
        if old and cardmarket_id:
            save_price_history(conn, cardmarket_id, old[0], old[1], date_str)

        upsert_artist(conn, card.get("artist"))
        upsert_card(conn, card)

    # ── Produkte ─────────────────────────────────────────────
    products = fetch_all_pages(f"pokemon/episodes/{ep_id}/products")
    for product in products:
        upsert_product(conn, product)

    conn.commit()
    return len(cards), len(products)


# ─────────────────────────────────────────────────────────────
# PREIS-HISTORY BACKFILL
# ─────────────────────────────────────────────────────────────
def fetch_history_prices(cardmarket_id: int, date_from: str, date_to: str) -> list[dict]:
    """Ruft historische Preise für eine Karte ab. Gibt Liste von {date, cm_low, tcp_market} zurück."""
    data = api_get("pokemon/history-prices", {
        "id":        cardmarket_id,
        "date_from": date_from,
        "date_to":   date_to,
    })
    if not data:
        return []
    items = data if isinstance(data, list) else data.get("data", [])
    result = []
    for item in items:
        date     = item.get("date") or item.get("created_at", "")[:10]
        cm_low   = (item.get("cardmarket") or {}).get("lowest_near_mint") \
                   or item.get("cm_low") or item.get("lowest_near_mint")
        tcp_mkt  = (item.get("tcg_player") or {}).get("market_price") \
                   or item.get("tcp_market") or item.get("market_price")
        if date:
            result.append({"date": date, "cm_low": cm_low, "tcp_market": tcp_mkt})
    return result


def run_history(min_price: float = 10.0, days_back: int = 365):
    """
    Lädt historische Preise für alle Karten mit Preis > min_price.
    Nutzt verbleibende Requests nach dem täglichen Update.
    Karten die bereits History haben werden übersprungen.
    Macht dort weiter wo der letzte Lauf aufgehört hat.
    """
    log("=" * 60)
    log(f"PREIS-HISTORY Backfill (min. {min_price}€, {days_back} Tage)")
    log(f"DB: {DB_PATH}")
    log("=" * 60)

    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    setup_db(conn)

    date_to   = datetime.now().strftime("%Y-%m-%d")
    date_from = (datetime.now() - timedelta(days=days_back)).strftime("%Y-%m-%d")

    # Alle Karten mit Preis > min_price, die noch keine History-Einträge haben
    candidates = conn.execute("""
        SELECT c.cardmarket_id, c.name, c.cm_lowest_nm_de, c.cm_lowest_nm
        FROM cards c
        WHERE c.cardmarket_id IS NOT NULL
          AND COALESCE(c.cm_lowest_nm_de, c.cm_lowest_nm, 0) >= ?
          AND NOT EXISTS (
              SELECT 1 FROM price_history ph
              WHERE ph.cardmarket_id = c.cardmarket_id
          )
        ORDER BY COALESCE(c.cm_lowest_nm_de, c.cm_lowest_nm, 0) DESC
    """, (min_price,)).fetchall()

    log(f"→ {len(candidates)} Karten ohne History (>{min_price}€)")

    if not candidates:
        log("Nichts zu tun.")
        conn.close()
        return

    done = 0
    for cardmarket_id, name, price_de, price_global in candidates:
        price_display = price_de or price_global or 0
        log(f"  [{done+1:>4}/{len(candidates)}] {name} ({price_display:.2f}€) – cm_id={cardmarket_id}")

        try:
            entries = fetch_history_prices(cardmarket_id, date_from, date_to)
        except RuntimeError as e:
            log(f"\n!!! LIMIT erreicht nach {done} Karten: {e}")
            break

        saved = 0
        for entry in entries:
            save_price_history(conn, cardmarket_id,
                               entry["cm_low"], entry["tcp_market"], entry["date"])
            saved += 1

        conn.commit()
        log(f"         → {saved} Einträge gespeichert ({date_from} – {date_to})")
        done += 1

    conn.close()
    log(f"\nHistory Backfill abgeschlossen: {done} Karten verarbeitet")


# ─────────────────────────────────────────────────────────────
# TÄGLICHES UPDATE
# ─────────────────────────────────────────────────────────────
def run_update():
    log("=" * 60)
    log("TCGGO Preis-Update gestartet")
    log(f"DB: {DB_PATH}")
    log("=" * 60)

    started_at = datetime.now().isoformat()
    req_start  = requests_used()
    date_str   = datetime.now().strftime("%Y-%m-%d")

    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    setup_db(conn)

    # Alle bekannten Episodes aus der DB laden
    episodes = conn.execute(
        "SELECT id, name FROM episodes ORDER BY id"
    ).fetchall()

    if not episodes:
        log("Keine Episodes in DB. Bitte zuerst python tcggo_sync.py ausführen.")
        conn.close()
        return

    log(f"→ {len(episodes)} Episodes werden aktualisiert")

    n_cards = n_products = 0

    try:
        for i, (ep_id, ep_name) in enumerate(episodes, 1):
            log(f"  [{i:>3}/{len(episodes)}] {ep_name} (ID {ep_id})")
            c, p = update_episode_cards(conn, ep_id, ep_name, date_str)
            n_cards    += c
            n_products += p
            log(f"         → {c} Karten, {p} Produkte")

    except RuntimeError as e:
        log(f"\n!!! ABGEBROCHEN: {e}")
        _write_sync_log(conn, started_at, len(episodes), 0,
                        n_cards, n_products,
                        requests_used() - req_start, "UPDATE_LIMIT")
        conn.close()
        return

    used = requests_used() - req_start
    _write_sync_log(conn, started_at, len(episodes), 0,
                    n_cards, n_products, used, "UPDATE_ERFOLG")

    db_size_mb = DB_PATH.stat().st_size / 1024 / 1024
    conn.close()

    log("\n" + "=" * 60)
    log("UPDATE ABGESCHLOSSEN")
    log(f"  Datum:        {date_str}")
    log(f"  Episodes:     {len(episodes)}")
    log(f"  Karten:       {n_cards:,}")
    log(f"  Produkte:     {n_products:,}")
    log(f"  Requests:     {used}")
    log(f"  DB-Größe:     {db_size_mb:.1f} MB")
    log("=" * 60)


# ─────────────────────────────────────────────────────────────
# HAUPT-SYNC
# ─────────────────────────────────────────────────────────────
def run_sync():
    log("=" * 60)
    log("TCGGO Sync gestartet")
    log(f"DB: {DB_PATH}")
    log("=" * 60)

    started_at    = datetime.now().isoformat()
    req_start     = requests_used()
    conn          = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")   # schnelleres Schreiben
    conn.execute("PRAGMA synchronous=NORMAL")
    setup_db(conn)

    n_episodes = n_artists = n_cards = n_products = 0

    try:
        # ── 1. Alle Episodes ────────────────────────────────
        log("\n[1/3] Lade Episodes...")
        all_episodes = fetch_all_pages("pokemon/episodes")
        for ep in all_episodes:
            upsert_episode(conn, ep)
        conn.commit()
        n_episodes = len(all_episodes)
        log(f"→ {n_episodes} Episodes gespeichert")

        # Nur Episodes mit Karten weiterverarbeiten
        valid = [ep for ep in all_episodes if ep.get("cards_total", 0) > 0]
        log(f"→ {len(valid)} Episodes mit Karten")

        # Bereits vollständig geladene Episodes ermitteln (Resume)
        done_cards = {
            row[0] for row in conn.execute(
                "SELECT DISTINCT episode_id FROM cards"
            )
        }
        done_products = {
            row[0] for row in conn.execute(
                "SELECT DISTINCT episode_id FROM products"
            )
        }

        # Vorhandene Karten/Produkte zählen
        n_cards    = conn.execute("SELECT COUNT(*) FROM cards").fetchone()[0]
        n_products = conn.execute("SELECT COUNT(*) FROM products").fetchone()[0]
        n_artists  = conn.execute("SELECT COUNT(*) FROM artists").fetchone()[0]

        skipped_c = len([e for e in valid if e["id"] in done_cards])
        skipped_p = len([e for e in valid if e["id"] in done_products])
        log(f"→ {skipped_c} Episodes bereits geladen (werden übersprungen)")

        # ── 2. Karten pro Episode ───────────────────────────
        log(f"\n[2/3] Lade Karten ({len(valid) - skipped_c} verbleibende Episodes)...")
        for i, ep in enumerate(valid, 1):
            ep_id, ep_name = ep["id"], ep["name"]
            if ep_id in done_cards:
                log(f"  [{i:>3}/{len(valid)}] SKIP {ep_name} (bereits geladen)")
                continue
            log(f"  [{i:>3}/{len(valid)}] {ep_name} (ID {ep_id})")

            cards = fetch_all_pages(f"pokemon/episodes/{ep_id}/cards")

            for card in cards:
                upsert_artist(conn, card.get("artist"))
                upsert_card(conn, card)

            conn.commit()
            n_cards  += len(cards)
            n_artists = conn.execute("SELECT COUNT(*) FROM artists").fetchone()[0]
            log(f"         → {len(cards)} Karten  (gesamt: {n_cards:,})")

        # ── 3. Produkte pro Episode ─────────────────────────
        log(f"\n[3/3] Lade Produkte ({len(valid) - skipped_p} verbleibende Episodes)...")
        for i, ep in enumerate(valid, 1):
            ep_id, ep_name = ep["id"], ep["name"]
            if ep_id in done_products:
                log(f"  [{i:>3}/{len(valid)}] SKIP {ep_name} (bereits geladen)")
                continue
            log(f"  [{i:>3}/{len(valid)}] {ep_name} (ID {ep_id})")

            products = fetch_all_pages(f"pokemon/episodes/{ep_id}/products")

            for product in products:
                upsert_product(conn, product)

            conn.commit()
            n_products += len(products)
            log(f"         → {len(products)} Produkte (gesamt: {n_products:,})")

    except RuntimeError as e:
        # Hartes Limit erreicht
        log(f"\n!!! ABGEBROCHEN: {e}")
        _write_sync_log(conn, started_at, n_episodes, n_artists,
                        n_cards, n_products,
                        requests_used() - req_start, "LIMIT_ERREICHT")
        conn.close()
        return

    # ── Fertig ───────────────────────────────────────────────
    used = requests_used() - req_start
    _write_sync_log(conn, started_at, n_episodes, n_artists,
                    n_cards, n_products, used, "ERFOLG")

    # DB-Größe ermitteln
    db_size_mb = DB_PATH.stat().st_size / 1024 / 1024

    conn.close()

    log("\n" + "=" * 60)
    log("SYNC ABGESCHLOSSEN")
    log(f"  Episodes:     {n_episodes}")
    log(f"  Artists:      {n_artists}")
    log(f"  Karten:       {n_cards:,}")
    log(f"  Produkte:     {n_products:,}")
    log(f"  Requests:     {used}")
    log(f"  DB-Größe:     {db_size_mb:.1f} MB")
    log(f"  Gespeichert:  {DB_PATH}")
    log("=" * 60)


def _write_sync_log(conn, started_at, episodes, artists,
                    cards, products, requests, status):
    conn.execute("""
        INSERT INTO sync_log
            (started_at, finished_at, episodes, artists,
             cards, products, requests, status)
        VALUES (?,?,?,?,?,?,?,?)
    """, (started_at, datetime.now().isoformat(),
          episodes, artists, cards, products, requests, status))
    conn.commit()


# ─────────────────────────────────────────────────────────────
# START
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if RAPIDAPI_KEY == "DEIN_RAPIDAPI_KEY_HIER":
        print("FEHLER: Bitte erst den RAPIDAPI_KEY in Zeile 24 eintragen!")
        exit(1)
    if "--update" in sys.argv:
        run_update()
    elif "--history" in sys.argv:
        # Optional: --min-price=15.0  --days=180
        min_price = 10.0
        days_back = 365
        for arg in sys.argv:
            if arg.startswith("--min-price="):
                min_price = float(arg.split("=")[1])
            if arg.startswith("--days="):
                days_back = int(arg.split("=")[1])
        run_history(min_price=min_price, days_back=days_back)
    else:
        run_sync()
