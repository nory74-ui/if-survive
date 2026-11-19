#!/usr/bin/env python3
"""Generate 21 character part-voice clips for IF: SURVIVE Episode 01 via Gemini 3.8 TTS."""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import wave
from typing import Any


VOICE_SPECS: list[dict[str, str]] = [
    {
        "key": "voice_nobunaga_umu",
        "voice": "Algenib",
        "text": "……うむ。",
        "style": "Japanese Sengoku warlord, deep gravelly intimidating male voice, slow deliberate authoritative tone",
    },
    {
        "key": "voice_nobunaga_nani",
        "voice": "Algenib",
        "text": "何っ！？",
        "style": "Japanese Sengoku warlord, deep gravelly male voice, sharp fierce surprise and suspicion, crisp delivery",
    },
    {
        "key": "voice_nobunaga_rage",
        "voice": "Algenib",
        "text": "戯れ言を！",
        "style": "Japanese Sengoku warlord, deep gravelly male voice, intense commanding rage, powerful projection",
    },
    {
        "key": "voice_nobunaga_laugh",
        "voice": "Algenib",
        "text": "……ふっ。ハハハハッ！",
        "style": "Japanese Sengoku warlord, deep gravelly male voice, dry fearless dark chuckle turning into bold laugh",
    },
    {
        "key": "voice_nobunaga_quiet",
        "voice": "Algenib",
        "text": "……そうか。",
        "style": "Japanese Sengoku warlord, deep gravelly male voice, quiet somber weary tone with subtle grief",
    },
    {
        "key": "voice_ranmaru_urgent",
        "voice": "Puck",
        "text": "上様っ！",
        "style": "Young noble Japanese samurai page in late teens, urgent desperate warning shout, breathless",
    },
    {
        "key": "voice_ranmaru_resolve",
        "voice": "Puck",
        "text": "ここは私が！",
        "style": "Young noble Japanese samurai page in late teens, fierce unwavering loyalty and resolve, crisp voice",
    },
    {
        "key": "voice_ranmaru_smile",
        "voice": "Puck",
        "text": "……上様。",
        "style": "Young noble Japanese samurai page in late teens, gentle bittersweet farewell smile in voice, soft",
    },
    {
        "key": "voice_yasuke_loyal",
        "voice": "Charon",
        "text": "承知した。",
        "style": "Towering loyal samurai warrior, very deep resonant calm baritone male voice, steadfast and dignified",
    },
    {
        "key": "voice_yasuke_urgent",
        "voice": "Charon",
        "text": "上様、こちらへ！",
        "style": "Towering loyal samurai warrior, deep resonant baritone male voice, urgent protective combat command",
    },
    {
        "key": "voice_yasuke_quiet",
        "voice": "Charon",
        "text": "……上様。",
        "style": "Towering loyal samurai warrior, deep warm baritone male voice, quiet empathy and gentle concern",
    },
    {
        "key": "voice_yasuke_joy",
        "voice": "Charon",
        "text": "お見事にございます！",
        "style": "Towering loyal samurai warrior, deep warm baritone male voice, bright hopeful liberated cheer",
    },
    {
        "key": "voice_mitsuhide_calm",
        "voice": "Iapetus",
        "text": "上様……。",
        "style": "Intellectual refined 50-year-old Japanese general, calm composed cool mid-low male voice, dignified",
    },
    {
        "key": "voice_mitsuhide_resolve",
        "voice": "Iapetus",
        "text": "お止めせねば……。",
        "style": "Intellectual Japanese general, quiet intense tragic resolve, restrained emotion, dignified delivery",
    },
    {
        "key": "voice_mitsuhide_sorrow",
        "voice": "Iapetus",
        "text": "……お斬りくだされ。",
        "style": "Intellectual Japanese general, weary sorrowful resignation, quiet breathy noble dignity",
    },
    {
        "key": "voice_hideyoshi_tears",
        "voice": "Fenrir",
        "text": "上様ぁっ！",
        "style": "Cunning expressive 40-year-old Japanese general, overly dramatic emotional tearful cry, slightly theatrical",
    },
    {
        "key": "voice_hideyoshi_shock",
        "voice": "Fenrir",
        "text": "なっ……！？",
        "style": "Cunning expressive 40-year-old Japanese general, sudden genuine shock and disbelief, caught off guard",
    },
    {
        "key": "voice_hideyoshi_cunning",
        "voice": "Fenrir",
        "text": "お任せくだされ。",
        "style": "Cunning expressive 40-year-old Japanese general, humble nimble voice hiding sharp ambition beneath",
    },
    {
        "key": "voice_sokyu_calm",
        "voice": "Umbriel",
        "text": "一服、どうぞ。",
        "style": "Wise wealthy 60-year-old Japanese tea master and merchant, calm unhurried refined elderly male voice",
    },
    {
        "key": "voice_sokyu_smirk",
        "voice": "Umbriel",
        "text": "ふふ……。",
        "style": "Wise wealthy 60-year-old Japanese merchant mastermind, quiet shrewd amused chuckle, enigmatic",
    },
    {
        "key": "voice_ieyasu_resolve",
        "voice": "Orus",
        "text": "ならぬ！",
        "style": "Steadfast 40-year-old Japanese warlord, firm resolute sturdy male voice, unyielding determination",
    },
]

PROJECT_ROOT = Path(__file__).resolve().parent.parent
VOICE_DIR = PROJECT_ROOT / "episodes" / "01_nobunaga" / "assets" / "voice"
SCENARIO_PATH = PROJECT_ROOT / "episodes" / "01_nobunaga" / "scenario.json"


def _ensure_wav_container(raw_audio: bytes, sample_rate: int = 24000) -> bytes:
    """Return valid RIFF/WAV bytes, wrapping headerless L16 PCM if needed."""
    if raw_audio[:4] == b"RIFF" and len(raw_audio) > 44:
        return raw_audio
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(raw_audio)
    return buf.getvalue()


def _extract_audio_bytes(interaction: Any) -> bytes:
    """Extract raw audio bytes from a Gemini Interactions API response."""
    out_audio = getattr(interaction, "output_audio", None)
    raw_data = getattr(out_audio, "data", None) if out_audio is not None else None

    if raw_data is None:
        steps = getattr(interaction, "steps", None) or []
        for step in reversed(steps):
            if getattr(step, "type", None) != "model_output":
                continue
            for item in reversed(getattr(step, "content", None) or []):
                if getattr(item, "type", None) == "audio" and getattr(item, "data", None) is not None:
                    raw_data = item.data
                    break
            if raw_data is not None:
                break

    if raw_data is None:
        raise RuntimeError("Interaction response did not contain output_audio data.")

    if isinstance(raw_data, (bytes, bytearray)):
        decoded = bytes(raw_data)
    elif isinstance(raw_data, str):
        decoded = base64.b64decode(raw_data)
    else:
        raise TypeError(f"Unsupported output_audio.data type: {type(raw_data)!r}")

    if not decoded:
        raise RuntimeError("Decoded audio payload is empty.")
    return _ensure_wav_container(decoded)


def _synthesize_with_interactions(
    clients: dict[str, Any],
    spec: dict[str, str],
) -> tuple[bytes, str, bool]:
    """Try primary gemini-3.8-flash-tts (v1beta), then v1 and gemini-3.8-flash-lite-tts."""
    attempts = [
        ("v1beta", "gemini-3.8-flash-tts", False),
        ("v1", "gemini-3.8-flash-tts", True),
        ("v1beta", "gemini-3.8-flash-lite-tts", True),
        ("v1", "gemini-3.8-flash-lite-tts", True),
    ]
    errors: list[str] = []
    for api_ver, model_id, is_fallback in attempts:
        client = clients[api_ver]
        try:
            interaction = client.interactions.create(
                model=model_id,
                input=[
                    {
                        "type": "user_input",
                        "content": [
                            {
                                "type": "text",
                                "text": spec["text"],
                                "annotations": [
                                    {
                                        "type": "speech_metadata",
                                        "style": spec["style"],
                                    }
                                ],
                            }
                        ],
                    }
                ],
                response_format={"type": "audio"},
                generation_config={
                    "speech_config": [
                        {"voice": spec["voice"]},
                    ]
                },
            )
            wav_bytes = _extract_audio_bytes(interaction)
            return wav_bytes, f"{model_id}@{api_ver}", is_fallback
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{model_id}@{api_ver}: {exc}")

    raise RuntimeError(
        f"All Gemini TTS attempts failed for {spec['key']}: " + " | ".join(errors)
    )


def _ffmpeg_has_libvorbis(ffmpeg_path: str | None) -> bool:
    if not ffmpeg_path:
        return False
    try:
        res = subprocess.run(
            [ffmpeg_path, "-hide_banner", "-encoders"],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return False
    return bool(re.search(r"^\s*A[^\n]*\blibvorbis\b", res.stdout or "", re.MULTILINE))


def _save_voice_file(
    wav_bytes: bytes, key: str, ffmpeg_path: str | None, use_ogg: bool
) -> Path:
    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    tmp_wav = VOICE_DIR / f"{key}.tmp.wav"
    out_ogg = VOICE_DIR / f"{key}.ogg"
    out_wav = VOICE_DIR / f"{key}.wav"

    if ffmpeg_path:
        try:
            tmp_wav.write_bytes(wav_bytes)
            if use_ogg:
                subprocess.run(
                    [
                        ffmpeg_path,
                        "-y",
                        "-hide_banner",
                        "-loglevel",
                        "error",
                        "-i",
                        str(tmp_wav),
                        "-af",
                        "loudnorm=I=-14:TP=-1.5:LRA=7",
                        "-ac",
                        "1",
                        "-ar",
                        "44100",
                        "-c:a",
                        "libvorbis",
                        "-q:a",
                        "5",
                        str(out_ogg),
                    ],
                    check=True,
                )
                return out_ogg
            subprocess.run(
                [
                    ffmpeg_path,
                    "-y",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-i",
                    str(tmp_wav),
                    "-map_metadata",
                    "-1",
                    "-fflags",
                    "+bitexact",
                    "-af",
                    "loudnorm=I=-14:TP=-1.5:LRA=7",
                    "-ac",
                    "1",
                    "-ar",
                    "24000",
                    "-c:a",
                    "pcm_s16le",
                    str(out_wav),
                ],
                check=True,
            )
            return out_wav
        except subprocess.CalledProcessError as exc:
            print(
                f"  [WARN] ffmpeg conversion failed for {key} ({exc}); saving raw Gemini WAV.",
                file=sys.stderr,
            )
            out_wav.write_bytes(wav_bytes)
            return out_wav
        finally:
            tmp_wav.unlink(missing_ok=True)
    else:
        out_wav.write_bytes(wav_bytes)
        return out_wav


def _find_existing_voice_file(key: str) -> Path | None:
    for ext in (".ogg", ".wav"):
        candidate = VOICE_DIR / f"{key}{ext}"
        if candidate.is_file():
            return candidate
    return None


def _verify_all() -> int:
    print(f"Verifying voice assets in: {VOICE_DIR}")
    missing: list[str] = []
    too_small: list[tuple[str, int]] = []
    found_rows: list[tuple[str, str, int]] = []

    for spec in VOICE_SPECS:
        key = spec["key"]
        path = _find_existing_voice_file(key)
        if path is None:
            missing.append(key)
            continue
        size = path.stat().st_size
        found_rows.append((key, path.name, size))
        if size < 1024:
            too_small.append((path.name, size))

    with SCENARIO_PATH.open("r", encoding="utf-8") as fh:
        scenario = json.load(fh)

    scenario_voices: set[str] = set()
    for sid, sc in scenario.get("scenes", {}).items():
        for idx, line in enumerate(sc.get("lines", [])):
            v = line.get("voice", "")
            if v:
                scenario_voices.add(str(v))
                if _find_existing_voice_file(str(v)) is None:
                    missing.append(f"{sid}[{idx}]->{v}")

    for key, fname, size in found_rows:
        print(f"  OK  {fname:30s}  {size:8d} bytes  ({key})")

    if missing or too_small:
        print(f"VERIFY FAILED: missing={missing}, too_small={too_small}", file=sys.stderr)
        return 1

    print(
        f"VERIFY PASSED: {len(found_rows)}/{len(VOICE_SPECS)} voice files >= 1KB, "
        f"{len(scenario_voices)} scenario voice keys verified."
    )
    return 0


_PLACEHOLDER_API_KEYS = {
    "",
    "your-gemini-api-key-here",
    "<your-api-key>",
    "your_api_key_here",
}


def _load_dotenv(dotenv_path: Path) -> bool:
    """Load key=value pairs from .env without overriding non-empty env vars."""
    if not dotenv_path.is_file():
        return False
    for raw_line in dotenv_path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].lstrip()
        if "=" not in line:
            continue
        key, _, raw_val = line.partition("=")
        key = key.strip()
        val = raw_val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
            val = val[1:-1]
        elif " #" in val:
            val = val.split(" #", 1)[0].rstrip()
        if key and val and not os.environ.get(key):
            os.environ[key] = val
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate 21 Episode-01 voice clips using Gemini 3.8 Flash TTS."
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate files even if .ogg or .wav already exists.",
    )
    parser.add_argument(
        "--only",
        nargs="+",
        metavar="VOICE_KEY",
        help="Generate only the specified voice key(s).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview targets and skip status without calling Gemini API.",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Verify all 21 files (>=1KB) and scenario.json voice references.",
    )
    args = parser.parse_args()

    if args.verify:
        return _verify_all()

    dotenv_path = PROJECT_ROOT / ".env"
    dotenv_loaded = _load_dotenv(dotenv_path)

    spec_by_key = {spec["key"]: spec for spec in VOICE_SPECS}
    if args.only:
        unknown = [k for k in args.only if k not in spec_by_key]
        if unknown:
            print(f"ERROR: Unknown voice key(s): {', '.join(unknown)}", file=sys.stderr)
            return 2
        targets = [spec_by_key[k] for k in args.only]
    else:
        targets = VOICE_SPECS

    ffmpeg_path = shutil.which("ffmpeg")
    use_ogg = _ffmpeg_has_libvorbis(ffmpeg_path)
    target_ext = ".ogg" if use_ogg else ".wav"
    if not ffmpeg_path:
        ffmpeg_note = "not found (raw .wav)"
    elif use_ogg:
        ffmpeg_note = f"{ffmpeg_path} (libvorbis -> .ogg)"
    else:
        ffmpeg_note = f"{ffmpeg_path} (no libvorbis; loudnorm -> .wav)"
    print(f"Output directory : {VOICE_DIR}")
    print(f".env             : {'found' if dotenv_loaded else 'not found'} ({dotenv_path})")
    print(f"ffmpeg           : {ffmpeg_note}")
    print(f"Target count     : {len(targets)} / {len(VOICE_SPECS)}")

    if args.dry_run:
        for spec in targets:
            existing = _find_existing_voice_file(spec["key"])
            action = "REGEN" if (args.force or existing is None) else f"SKIP ({existing.name})"
            print(f"  [DRY-RUN] {spec['key']:26s} | {spec['voice']:8s} | {target_ext} | {action}")
        return 0

    api_key = (os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY") or "").strip()
    if api_key in _PLACEHOLDER_API_KEYS:
        print(
            "ERROR: GEMINI_API_KEY is not configured (missing or still a placeholder).\n"
            "Create `.env` in the project root from `.env.example` and set your key:\n"
            "  cp .env.example .env\n"
            "  # edit .env -> GEMINI_API_KEY=your-real-key\n"
            "  python3 tools/generate_voices.py",
            file=sys.stderr,
        )
        return 1

    try:
        from google import genai
    except ImportError as exc:
        print(
            "ERROR: google-genai package not found. Install via:\n"
            "  pip install \"google-genai>=2.25.0\"",
            file=sys.stderr,
        )
        raise SystemExit(1) from exc

    clients = {
        "v1beta": genai.Client(api_key=api_key, http_options={"api_version": "v1beta"}),
        "v1": genai.Client(api_key=api_key),
    }

    generated_count = 0
    skipped_count = 0
    fallback_count = 0
    made_api_call = False

    for idx, spec in enumerate(targets, start=1):
        key = spec["key"]
        existing = _find_existing_voice_file(key)
        if existing is not None and not args.force:
            print(f"[{idx:02d}/{len(targets):02d}] SKIP {existing.name} (already exists)")
            skipped_count += 1
            continue

        if made_api_call:
            time.sleep(1.0)

        wav_bytes, used_route, used_fallback = _synthesize_with_interactions(clients, spec)
        made_api_call = True
        if used_fallback:
            fallback_count += 1

        if args.force:
            for ext in (".ogg", ".wav"):
                old = VOICE_DIR / f"{key}{ext}"
                if old.exists():
                    old.unlink()

        saved_path = _save_voice_file(wav_bytes, key, ffmpeg_path, use_ogg)
        size = saved_path.stat().st_size
        fb_note = " [FALLBACK]" if used_fallback else ""
        print(
            f"[{idx:02d}/{len(targets):02d}] OK   {saved_path.name:28s} "
            f"{size:7d} B via {used_route}{fb_note}"
        )
        generated_count += 1

    print(
        f"Done: generated={generated_count}, skipped={skipped_count}, fallbacks={fallback_count}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
