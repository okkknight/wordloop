#!/usr/bin/env python3
"""Build sentence-level learning clips from a bilingual ASS subtitle file.

The script intentionally keeps each subtitle cue intact. Cues containing
multiple speakers or fragments are marked for review instead of being split
with guesses that could damage the audio/text alignment.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path


ASS_TIME = re.compile(r"^(\d+):(\d{2}):(\d{2})\.(\d{2})$")
TAG = re.compile(r"\{[^}]*\}")
STAGE_DIRECTION = re.compile(r"^\s*\[[^]]+\]\s*$")
SPEAKER_SEPARATOR = re.compile(r"(^|\s)-\s")
LOW_VALUE = {"uh", "um", "hmm", "hm", "oh", "ah", "wow", "yeah", "yes", "no", "okay", "ok"}
CHARACTER_NAMES = {
    "alex", "brenda", "cam", "cameron", "claire", "dylan", "feldman", "gloria",
    "haley", "jay", "joe", "josh", "lily", "luke", "manny", "mitch", "mitchell",
    "pepper", "phil", "pritchett", "ryan",
}
SHORT_KEEP = {
    "come on", "excuse me", "who's that", "what's wrong with it", "not really",
    "oh god", "hang on one second", "what's the word", "you two broke up",
    "we adopted a baby", "of course it is", "it's supposed to hurt",
}
LOW_VALUE_EXACT = {
    "kids breakfast", "yes the murders", "there be free", "and do what",
    "yes you are", "no you're not", "i've done my job", "i've done our job",
    "we're very different", "that's cool", "i know", "that's not",
    "phil dunphy yo", "one hat", "my dad", "i mean seriously",
    "yeah it was her head okay okay", "yes yes i know", "doggy doggy here doggy",
    "okay there you go", "okay all right thank you thanks that helps okay okay",
    "june found a stick", "girls who play in university orchestras",
    "niagara falls and log rides", "who's a dancing queen huh", "where's where's doggy",
    "i knew it we both knew it", "he got his jaunty butt kicked",
    "it was a wig actually sort of a ghetto fabulous afro thing",
    "you thought ghetto fabulous might be medically relevant",
    "we don't have a lot of pho there", "that was a joke", "oh geez look at that",
    "what's wrong with me", "hey uh alex you", "emergency assistance this is trina",
    "daddy wins do you believe in miracles", "kind of the best job in the world",
    "parking ticket from the mall",
    "the two bedroom cottage with the indoor outdoor family room",
    "we caravanned that house great deck", "no who is coconuts enough to divorce you",
    "heard she already slept with two dads from the school",
    "hey hey hey nice bike sally", "come on he looks like little bo peep on that thing",
    "thats too damn bad", "yes whos excited huh", "wow paisley and pink",
    "was there something wrong with the fishnet tank top",
    "obviously not im wearing it underneath", "fine you know what",
    "i usually wear nothing when im in a hot tub", "like fog at an airport",
    "limo gets here at", "in my culture men take great pride in doing physical labor",
    "i know thats why i hire people from your culture", "dont make us look like jerks here",
    "have like three butt loads of fun", "thats when my dads picking me up",
    "im gonna tie a noose on this thing", "the ceiling fan is the cart",
    "my dads taking me on space mountain", "wow how bout that",
    "was the bear sittin in the passenger seat", "we can skip that",
    "nobodys gonna get shocked", "one time my dad was struck by lightning",
    "thats why he can drink as much as he wants", "manny thinks his dad is like superman",
    "the truth hes a total flake", "i just dont want this to become an episode of the cam show",
    "bet youre lovin that steam shower", "we caravanned that house great uh deck",
    "dance us in tyler", "no slapping your own butt", "what do we got here",
    "i mean am i attracted to her yes", "would i ever act on it no no way",
    "not while my wife is still alive", "yeah its a candle",
    "ay but have some fun with your father okay", "look at you two with your private jokes already",
    "youre a regular salazar and el oso", "its a very big comedy team in colombia",
    "look at those queens i would have killed with this crowd",
    "okay its time for parents dance", "everybody dance for your baby",
    "make that horsey move go ahead", "i dont know i dont know",
    "riley morton coming up now", "kelly at second started the inning with a double",
    "chillin with dylan the villain", "the box says and up",
    "how do you say in english", "once on a dare he even boxed with an alligator",
    "you cant box with alligators", "how would they get the gloves on those little claws",
    "official slogan for snobs", "who says city mouse", "yeah maybe a little bit",
    "huh confetti and crosscut", "oh my god amazing", "papa ape wants to stop all that but he cant",
    "the enemy is poachers", "oh hey i got the toothpaste and the soap",
    "good now we can open that general store", "we met at one of peppers legendary game nights",
    "wait theres a wine section", "look how cheap they are", "you want to buy a diaper shed",
    "were those guys now the guys with a diaper shed", "im in the applesauce aisle",
    "he plays the piano he speaks french", "yeah im sort of like costco",
    "no no and yes", "why you dont want to wear a dress",
    "you are haley just years older", "the cute busboy doesnt know that youre smart",
    "why do you think we are the only people with bread", "so you ever kiss another girl",
    "clear the way coming through ow", "coming through easy easy fella ow",
    "little accident nothing big", "thats the painkiller talking", "hes a little loopy",
    "i have seen you thread the needle a million times", "what are you made of china",
    "actually this is called an aileron", "only the greatest store on earth",
    "stay still say cheese", "i think i strained something",
    "i told him that it was his twin sister who died",
    "miss mary mack mack mack", "all down her back back back",
    "you know honey theres a gun in the footlocker in the garage", "i want you to use it on me",
    "nanna got totally wasted", "take your hands off me", "kiss me oh hey kiss me",
    "his uncle is uncle toby", "oh uncle toby ill be sure to include that in my amber alert",
    "your mom needs your help to make love to her new man chas",
    "i just cant give myself to him sexually", "i cant be intimate with him",
    "we do things to each other", "all like east coast west coast you feelin me",
    "i call it peerenting", "hello i was a hall raiser",
    "rich girl just spoke to me", "were just a couple of friends kickin it in a juice bar",
    "whats a juice bar", "okay a malt shop whatever", "hey just in the hood",
    "oh my little comet", "wow wow mom what were you and ricky doing",
    "she set a kids bike on fire", "yes yes my mom dad", "my mom would be less scary",
    "oh you were in a band", "he may burn your house down",
    "so make a note bitches", "its not a good color on you",
    "i got gloria", "dede and you know it", "this is actually a song i wrote for haley",
    "its called in the moonlight", "never good at harmonizing",
}
NON_ENGLISH_PATTERNS = (
    re.compile(r"\bvamos\b", re.IGNORECASE),
    re.compile(r"\ba\s+la\s+derecha\b", re.IGNORECASE),
    re.compile(r"\bmentira\b", re.IGNORECASE),
    re.compile(r"\bay\W+miren\b", re.IGNORECASE),
    re.compile(r"\bmi\s+ni(?:n|ñ)?o\s+peque(?:n|ñ)?o\b", re.IGNORECASE),
    re.compile(r"\blindo\b", re.IGNORECASE),
    re.compile(r"\bmiamor\b", re.IGNORECASE),
    re.compile(r"\bmi\s+amigo\b", re.IGNORECASE),
    re.compile(r"^\s*ay\W+but\b", re.IGNORECASE),
    re.compile(r"^\s*ay\b", re.IGNORECASE),
)


def timestamp(value: str) -> float:
    match = ASS_TIME.match(value)
    if not match:
        raise ValueError(f"Unsupported ASS timestamp: {value}")
    hours, minutes, seconds, centiseconds = map(int, match.groups())
    return hours * 3600 + minutes * 60 + seconds + centiseconds / 100


def clean_bilingual_text(raw: str) -> tuple[str, str, bool]:
    pieces = []
    translations = []
    mixed_caption = False
    for piece in raw.split(r"\N"):
        piece = TAG.sub("", piece).strip()
        if re.search(r"[A-Za-z]", piece):
            if re.search(r"[\u3400-\u9fff]", piece):
                mixed_caption = True
            pieces.append(piece)
        elif piece:
            translations.append(piece)
    return (
        re.sub(r"\s+", " ", " ".join(pieces)).strip(),
        re.sub(r"\s+", " ", " ".join(translations)).strip(),
        mixed_caption,
    )


def classify(text: str, mixed_caption: bool) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    words = re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?", text.lower())
    normalized = " ".join(words)
    normalized_without_apostrophes = normalized.replace("'", "")
    if not words:
        reasons.append("no-english-text")
    if STAGE_DIRECTION.fullmatch(text):
        reasons.append("stage-direction")
    if mixed_caption:
        reasons.append("mixed-language-caption")
    if len(words) <= 1:
        reasons.append("too-short")
    if len(words) < 4 and normalized not in SHORT_KEEP:
        reasons.append("short-low-context")
    if normalized in LOW_VALUE_EXACT or normalized_without_apostrophes in LOW_VALUE_EXACT:
        reasons.append("low-value-utterance")
    # Repeated acknowledgements or emotional interjections do not form useful
    # sentence practice, even when the cue contains several repeated words.
    if len(words) > 0 and all(word in LOW_VALUE for word in words):
        reasons.append("low-value-utterance")
    if SPEAKER_SEPARATOR.search(text):
        reasons.append("multiple-speakers")
    if words and all(word in CHARACTER_NAMES for word in words):
        reasons.append("name-only")
    if any(pattern.search(text) for pattern in NON_ENGLISH_PATTERNS):
        reasons.append("non-english-utterance")
    first_letter = re.search(r"[A-Za-z]", text)
    if first_letter and text[first_letter.start()].islower():
        reasons.append("sentence-fragment")
    terminal = text.rstrip().rstrip('"\'”')
    if (
        terminal.endswith("...")
        or not terminal.endswith((".", "!", "?"))
        or re.search(r"[A-Za-z]-\s", text)
        or text.lower().startswith(("and ", "but ", "or ", "to ", "with ", "which ", "if "))
    ):
        reasons.append("sentence-fragment")
    if len(set(words)) == 1 and len(words) > 1:
        reasons.append("repetitive-utterance")
    blocking = {
        "no-english-text", "stage-direction", "mixed-language-caption", "too-short",
        "short-low-context", "low-value-utterance", "multiple-speakers", "name-only",
        "non-english-utterance", "sentence-fragment", "repetitive-utterance",
    }
    return not any(reason in blocking for reason in reasons), reasons


def parse_ass(path: Path, episode: str) -> list[dict[str, object]]:
    text = path.read_text(encoding="utf-16")
    entries: list[dict[str, object]] = []
    for line in text.splitlines():
        if not line.startswith("Dialogue:"):
            continue
        fields = line.split(",", 9)
        if len(fields) != 10:
            continue
        start = timestamp(fields[1])
        end = timestamp(fields[2])
        sentence, translation, mixed_caption = clean_bilingual_text(fields[9])
        if not sentence:
            continue
        learnable, reasons = classify(sentence, mixed_caption)
        entries.append({
            "id": f"{episode.lower()}-{len(entries) + 1:04d}",
            "episode": episode,
            "start": start,
            "end": end,
            "duration": round(end - start, 2),
            "text": sentence,
            "translation": translation,
            "learnable": learnable,
            "reviewReasons": reasons,
        })
    return entries


def cut_audio(audio: Path, output_dir: Path, entries: list[dict[str, object]]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for entry in entries:
        if not entry["learnable"]:
            continue
        output = output_dir / f"{entry['id']}.m4a"
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-ss", str(entry["start"]), "-i", str(audio),
            "-t", str(entry["duration"]), "-vn", "-ac", "1", "-c:a", "aac", "-b:a", "48k", str(output),
        ], check=True)
        entry["audio"] = str(output.relative_to(output_dir.parent))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subtitle", type=Path, required=True)
    parser.add_argument("--audio", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--episode", default="S01E01", help="Episode code, for example S01E02")
    parser.add_argument("--no-audio", action="store_true", help="Only write the manifest")
    args = parser.parse_args()

    episode = args.episode.upper()
    if not re.fullmatch(r"S\d{2}E\d{2}", episode):
        raise ValueError("Episode must use the format S01E02")
    entries = parse_ass(args.subtitle, episode)
    args.output.mkdir(parents=True, exist_ok=True)
    if not args.no_audio:
        cut_audio(args.audio, args.output / "audio", entries)
    manifest = {
        "courseId": f"modern-family-{episode.lower()}",
        "episode": episode,
        "sourceAudio": str(args.audio),
        "sourceSubtitle": str(args.subtitle),
        "entries": entries,
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({
        "entries": len(entries),
        "learnable": sum(1 for entry in entries if entry["learnable"]),
        "review_or_filtered": sum(1 for entry in entries if not entry["learnable"]),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
