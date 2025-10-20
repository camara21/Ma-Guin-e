from pathlib import Path

def fix_text(s: str) -> str:
    # Corrige les caractères mal encodés (DÃ©connectÃ©, â€” etc.)
    return s.encode("latin-1", errors="ignore").decode("utf-8", errors="ignore")

def fix_file(p: Path):
    raw = p.read_text(encoding="utf-8", errors="replace")
    fixed = fix_text(raw)
    if fixed != raw:
        p.write_text(fixed, encoding="utf-8")
        print(f"✅ Fichier corrigé : {p}")
    else:
        print(f"ℹ️ Aucun changement : {p}")

# --- Corrige le fichier main.dart ---
fix_file(Path("lib/main.dart"))
