#!/usr/bin/env python3
"""Generates original character voices and realistic SFX with the ElevenLabs
Sound Effects API into Assets/Audio/ (mp3). Existing files are skipped, so it
is safe to re-run. The key is read from ELEVENLABS_API_KEY or injected by the
environment's network proxy (header xi-api-key).

Usage: python3 Tools/elevenlabs_sfx.py [--only name_prefix] [--force]
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "Assets", "Audio")
KEY = os.environ.get("ELEVENLABS_API_KEY", "proxy-injected")
URL = "https://api.elevenlabs.io/v1/sound-generation"

CARTOON = "cartoon mobile game character voice, cute, expressive, short, no music, clean studio recording"

# name -> (prompt, seconds). Names with _1/_2/_3 are random variants.
SOUNDS = {
    # --- Fire Knight: small brave knight
    "fire_knight_deploy_1": ("small brave young knight shouts 'For the kingdom!' heroic battle cry, " + CARTOON, 1.5),
    "fire_knight_deploy_2": ("small brave knight shouts 'Charge!' energetic, " + CARTOON, 1.0),
    "fire_knight_attack_1": ("small knight effort grunt 'hyah!' while swinging a heavy sword, " + CARTOON, 0.6),
    "fire_knight_attack_2": ("small knight battle yell 'haaa!' heavy sword swing, " + CARTOON, 0.7),
    "fire_knight_death": ("small knight defeated groan 'ugh...' falling in armor, " + CARTOON, 1.0),
    "fire_knight_select": ("small knight confident laugh 'ha ha! ready!' with sword ring, " + CARTOON, 1.3),
    # --- Shadow Assassin: quick, cool ninja girl
    "shadow_assassin_deploy_1": ("cool young ninja girl whispers 'too slow' with a quick whoosh, " + CARTOON, 1.0),
    "shadow_assassin_deploy_2": ("ninja girl short playful laugh 'heh' and smoke puff, " + CARTOON, 0.8),
    "shadow_assassin_attack_1": ("ninja girl sharp short 'hah!' quick dagger strike, " + CARTOON, 0.5),
    "shadow_assassin_attack_2": ("ninja girl quick 'tsk!' with fast double dagger slash, " + CARTOON, 0.5),
    "shadow_assassin_death": ("ninja girl short surprised cry 'ah!' then poof of smoke, " + CARTOON, 0.9),
    "shadow_assassin_select": ("ninja girl spinning daggers whoosh and cool 'let's go', " + CARTOON, 1.2),
    # --- Stone Golem: big, goofy, lovable
    "stone_golem_deploy_1": ("huge friendly rock golem deep goofy roar 'hrrrooar' with rocks rumbling, " + CARTOON, 1.6),
    "stone_golem_deploy_2": ("giant stone creature deep happy grunt 'hmm-hm!' heavy footsteps, " + CARTOON, 1.3),
    "stone_golem_attack_1": ("giant golem deep effort grunt 'huuurgh' and massive rock slam on the ground, " + CARTOON, 1.0),
    "stone_golem_death": ("giant golem sad deep groan then rocks crumbling apart, " + CARTOON, 1.8),
    "stone_golem_select": ("giant golem pounding its stone chest twice and a goofy deep roar, " + CARTOON, 1.6),
    # --- Frost Dragon: tiny cute dragon
    "frost_dragon_deploy_1": ("tiny cute baby dragon chirpy roar with wing flaps, " + CARTOON, 1.2),
    "frost_dragon_deploy_2": ("small baby dragon happy squeak 'rawr!' and wing flutter, " + CARTOON, 1.0),
    "frost_dragon_attack_1": ("baby dragon breathes an icy blast, crystalline whoosh with a small roar, " + CARTOON, 0.9),
    "frost_dragon_death": ("baby dragon sad whimper and ice shattering, " + CARTOON, 1.2),
    "frost_dragon_select": ("baby dragon excited loop-de-loop wing flaps and cheerful roar, " + CARTOON, 1.4),
    # --- Poison Witch: mischievous
    "poison_witch_deploy_1": ("mischievous young witch cackle 'hehehe!' with bubbling potion, " + CARTOON, 1.4),
    "poison_witch_deploy_2": ("young witch sing-song 'time for a little poison~', " + CARTOON, 1.6),
    "poison_witch_attack_1": ("witch casting spell 'hah!' with magic zap and bubbling, " + CARTOON, 0.8),
    "poison_witch_death": ("young witch dramatic 'nooo!' fading with magic sparkle, " + CARTOON, 1.2),
    "poison_witch_select": ("young witch giggles and twirls a magic staff with sparkles, " + CARTOON, 1.4),
    # --- King, crowd and arena
    "king_wake": ("chubby king wakes up angry 'HEY!' grumpy, " + CARTOON, 1.0),
    "king_laugh": ("chubby cartoon king hearty laugh 'ho ho ho!' taunt, " + CARTOON, 1.6),
    "crowd_cheer": ("stadium crowd cheering burst, excited fans, short", 2.5),
    "crowd_victory": ("big crowd cheering and applause with a royal trumpet fanfare", 4.0),
    "crowd_defeat": ("crowd disappointed 'awww' groan", 2.0),
    "tower_destroyed": ("big stone tower collapsing, rocks crashing down, deep impact, realistic", 2.5),
    "fire_slash": ("heavy sword swing whoosh with fire burst crackle, realistic game sound", 0.8),
    "dagger": ("two quick dagger slashes, sharp metal swish, realistic", 0.6),
    "rock_slam": ("massive rock fist slamming the ground, deep thud with debris, realistic", 1.0),
    "ice_shot": ("magic ice shard shot, crystalline whoosh, game sound", 0.7),
    "ice_hit": ("ice shard shattering on impact, glassy crack, game sound", 0.7),
    "poison_cast": ("magic staff casting a bubbling poison orb, game sound", 0.8),
    "poison_hit": ("poison orb splashing with sizzling bubbles, game sound", 0.8),
    "arrow": ("bow string release and arrow whoosh, realistic", 0.6),
    "cannon": ("small medieval cannon firing, punchy boom, realistic", 1.0),
    "cannon_hit": ("cannonball impact explosion, short punchy", 0.8),
    "deploy": ("magical summon landing thump with sparkle shimmer, game sound", 0.8),
    "card_select": ("card flip and soft magical chime, mobile game ui", 0.5),
    "button": ("short satisfying mobile game button click pop", 0.5),
    "coin": ("gold coins jingle reward, mobile game", 0.8),
    "chest_open": ("treasure chest lid opening with magical reward shimmer", 1.6),
}


def generate(name, prompt, seconds):
    body = json.dumps({"text": prompt, "duration_seconds": max(0.5, seconds), "prompt_influence": 0.55}).encode()
    req = urllib.request.Request(URL + "?output_format=mp3_44100_128", data=body, method="POST",
                                 headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    with open(os.path.join(OUT, name + ".mp3"), "wb") as f:
        f.write(data)
    return len(data)


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    for name, (prompt, sec) in SOUNDS.items():
        if only and not name.startswith(only):
            continue
        if os.path.exists(os.path.join(OUT, name + ".mp3")) and not force:
            continue
        try:
            n = generate(name, prompt, sec)
            print("ok   %-28s %6d KB" % (name, n // 1024), flush=True)
        except urllib.error.HTTPError as e:
            raise SystemExit("HTTP %d for %s: %s" % (e.code, name, e.read().decode()[:300]))
