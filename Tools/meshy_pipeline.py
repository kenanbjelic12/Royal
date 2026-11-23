#!/usr/bin/env python3
"""Meshy AI pipeline for Royal Arena monsters.

Stages per monster: preview (geometry) -> refine (PBR textures) -> rig ->
animations -> download GLBs into Assets/Monsters/<id>/.
State (task ids, urls) is kept in Assets/Monsters/meshy_state.json so every
stage can be resumed without paying twice.

The API key is NOT stored here: it is read from MESHY_API_KEY (or injected by
the environment's network proxy).

Usage:
  python3 Tools/meshy_pipeline.py preview [id ...]
  python3 Tools/meshy_pipeline.py status
  python3 Tools/meshy_pipeline.py wait <stage>
  python3 Tools/meshy_pipeline.py refine [id ...]
  python3 Tools/meshy_pipeline.py rig [id ...]
  python3 Tools/meshy_pipeline.py animate <id> <action_id> <name>
  python3 Tools/meshy_pipeline.py download
  python3 Tools/meshy_pipeline.py balance
"""
import json
import os
import sys
import time
import urllib.request

API = "https://api.meshy.ai/openapi"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
STATE = os.path.join(ROOT, "Assets", "Monsters", "meshy_state.json")
KEY = os.environ.get("MESHY_API_KEY", "proxy-injected")

STYLE = ("stylized 3D mobile game character, cute but powerful, chibi proportions, oversized head, "
         "big expressive eyes, compact body, bright saturated colours, clean hand-painted look, "
         "unique readable silhouette, premium collectible game quality, full body, A-pose")

MONSTERS = {
    "fire_knight": {
        "prompt": "small brave fire knight in crimson red and gold armour, round red helmet with open face, "
                  "big brown eyes, determined eyebrows, confident grin, flame plume on top of the helmet, "
                  "short dark red cape, huge two-handed greatsword with glowing orange fire blade held in right hand",
        "texture": "crimson red lacquered armour with gold trims, glowing orange-yellow fire sword, warm skin, dark red cape",
        "height": 1.3, "rig": True},
    "shadow_assassin": {
        "prompt": "cool mysterious little ninja assassin, dark indigo hood with small fox ears, face hidden in shadow "
                  "except two big glowing cyan eyes, cloth mask over mouth, long magenta scarf, slim body, "
                  "two curved violet daggers in both hands, not scary",
        "texture": "deep indigo and navy cloth, magenta scarf and belt, glowing cyan eyes, violet glowing dagger blades",
        "height": 1.2, "rig": True},
    "stone_golem": {
        "prompt": "friendly lovable stone golem, cute and goofy not scary, huge round boulder body made of smooth slate "
                  "blue-grey rocks, small round head, big round happy amber eyes, wide friendly closed-mouth smile, "
                  "no teeth, no angry eyebrows, green moss on the shoulders with tiny pink flowers, glowing cyan crystals "
                  "on its back, gigantic round stone fists, short stubby legs, kids cartoon mascot",
        "texture": "slate blue-grey stone with cracks, bright green moss, glowing cyan crystals, amber eyes",
        "height": 2.2, "rig": True},
    "frost_dragon": {
        "prompt": "tiny chubby baby frost dragon, sky blue scales, pale cyan belly, huge round eyes, small white ice "
                  "horns, ice crystal spikes along the back, translucent blue bat wings spread open, crystal tip on the "
                  "tail, little fangs, cute but powerful, four short legs",
        "texture": "sky blue glossy scales, pale icy belly, white-cyan ice crystals and horns, light blue wing membranes",
        "height": 1.0, "rig": True},
    "poison_witch": {
        "prompt": "mischievous little witch, giant bent purple witch hat with a glowing green band, mint green hair, "
                  "cheeky grin, big green eyes, purple robe with glowing green trim, crooked wooden staff topped "
                  "with a bubbling green poison orb held in right hand, potion bottle on the belt",
        "texture": "rich purple robe and hat, neon green trims and poison orb, mint hair, warm skin, brown wooden staff",
        "height": 1.3, "rig": True},
    "thunder_mage": {
        "prompt": "cute young thunder mage boy, spiky electric blue hair, big bright yellow eyes, confident smile, "
                  "deep blue and gold wizard robe with lightning bolt patterns, short cape, small round hat with a "
                  "lightning feather, crackling energy around his hands",
        "texture": "deep royal blue robe with gold trims and yellow lightning bolt symbols, glowing electric blue hair, warm skin",
        "height": 1.3, "rig": True},
    "healing_fairy": {
        "prompt": "sweet little healing fairy girl, pink and white flower petal dress, big friendly green eyes, rosy cheeks, "
                  "short golden hair with a flower crown, four translucent butterfly wings on her back, "
                  "holding a small wand with a glowing star, kind smile",
        "texture": "soft pink and white petal dress, golden hair, pastel rainbow translucent wings, glowing pale yellow star",
        "height": 1.1, "rig": True},
    "goblin_gang": {
        "prompt": "small cheeky goblin warrior, bright green skin, huge pointy ears, big mischievous orange eyes, toothy grin, "
                  "leather armour with a rope belt, tiny iron helmet, bare feet, holding a short wooden spear, funny and cute",
        "texture": "bright lime green skin, brown leather armour, rusty iron helmet, orange eyes",
        "height": 0.9, "rig": True},
    "viking_berserker": {
        "prompt": "stocky chibi viking berserker, huge braided orange beard, horned iron helmet, big fierce but funny eyes, "
                  "bare muscular arms with blue war paint, fur cape and leather kilt, holding a big double-bladed battle axe",
        "texture": "orange braided beard, steel horned helmet, brown fur cape, blue war paint, polished steel axe",
        "height": 1.35, "rig": True},
    "bomb_pirate": {
        "prompt": "cheerful chubby pirate bomber, red bandana and eye patch, big grin with a gold tooth, striped red and "
                  "white shirt, blue pants, peg leg, belt full of round black bombs, holding a lit cartoon bomb",
        "texture": "red bandana, red and white striped shirt, navy pants, black bombs with orange fuses, gold tooth",
        "height": 1.25, "rig": True},
    "skeleton_squad": {
        "prompt": "tiny cute cartoon skeleton warrior, friendly not scary, big round skull with large glowing blue eyes "
                  "in the eye sockets, happy toothy grin, small chubby bones, little dented iron helmet, tiny round wooden "
                  "shield and a short rusty sword, kids game mascot",
        "texture": "clean ivory white bones, glowing cyan eyes, dented grey iron helmet, brown wooden shield with a blue rim",
        "height": 0.85, "rig": True},
}

# Reward chests: static props (no rig). The lid is split off in Godot
# (Tools/ChestImport.gd) and animated there, since Meshy animations need a
# humanoid rig.
PROP_STYLE = ("stylized 3D mobile game prop, cartoon, chunky rounded shapes, bright saturated colours, "
              "clean hand-painted look, premium collectible game quality, single object, closed lid, front view")
CHESTS = {
    "gold_chest": {
        "prompt": "cartoon treasure chest, warm brown wooden planks with thick shiny gold metal bands and gold corner "
                  "caps, rounded domed lid, big golden front lock plate with a keyhole and a small crown emblem",
        "texture": "warm brown wood planks, polished shiny gold bands and corners, gold lock with crown",
        "height": 1.0, "rig": False},
    "rare_chest": {
        "prompt": "cartoon rare treasure chest, royal blue painted wood with polished silver metal bands and corner "
                  "caps, rounded domed lid, glowing cyan diamond gem set in a silver front lock plate",
        "texture": "deep royal blue painted wood, polished silver bands and rivets, glowing cyan gem in the lock",
        "height": 1.0, "rig": False},
    "epic_chest": {
        "prompt": "cartoon epic treasure chest, deep purple magical wood with ornate gold filigree trims, glowing "
                  "magenta crystals on the four corners, rounded domed lid, big golden crown emblem lock plate",
        "texture": "deep violet wood, ornate shiny gold trims, glowing pink magenta crystals, golden crown lock",
        "height": 1.0, "rig": False},
}
MONSTERS.update(CHESTS)


def req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(API + path, data=data, method=method,
                               headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            return json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raise SystemExit("HTTP %d %s: %s" % (e.code, path, e.read().decode()[:500]))


def load():
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {}


def save(s):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        json.dump(s, f, indent=2)


def ids(args):
    return args or [k for k in MONSTERS if k not in CHESTS]


def task_path(stage):
    return {"preview": "/v2/text-to-3d/", "refine": "/v2/text-to-3d/", "rig": "/v1/rigging/"}.get(stage, "/v1/animations/")


def cmd_preview(args):
    s = load()
    for mid in ids(args):
        m = MONSTERS[mid]
        st = s.setdefault(mid, {})
        if st.get("preview"):
            print(mid, "preview exists", st["preview"])
            continue
        r = req("POST", "/v2/text-to-3d", {
            "mode": "preview", "prompt": m["prompt"] + ", " + (STYLE if m["rig"] else PROP_STYLE), "art_style": "realistic",
            "ai_model": "latest", "topology": "triangle", "target_polycount": 15000,
            "should_remesh": True, "symmetry_mode": "auto", "pose_mode": "a-pose" if m["rig"] else ""})
        st["preview"] = r.get("result") or r.get("id")
        print(mid, "preview", st["preview"], "credits", r.get("consumed_credits"))
        save(s)


def cmd_refine(args):
    s = load()
    for mid in ids(args):
        st = s.get(mid, {})
        if st.get("refine") or not st.get("preview"):
            continue
        r = req("POST", "/v2/text-to-3d", {
            "mode": "refine", "preview_task_id": st["preview"], "enable_pbr": True,
            "texture_prompt": MONSTERS[mid]["texture"] + ", stylized cartoon, vibrant"})
        st["refine"] = r.get("result") or r.get("id")
        print(mid, "refine", st["refine"], "credits", r.get("consumed_credits"))
        save(s)


def cmd_rig(args):
    s = load()
    for mid in ids(args):
        st = s.get(mid, {})
        if st.get("rig") or not st.get("refine") or not MONSTERS[mid]["rig"]:
            continue
        r = req("POST", "/v1/rigging", {"input_task_id": st["refine"], "height_meters": MONSTERS[mid]["height"]})
        st["rig"] = r.get("result") or r.get("id")
        print(mid, "rig", st["rig"], "credits", r.get("consumed_credits"))
        save(s)


def cmd_animate(args):
    mid, action, name = args[0], int(args[1]), args[2]
    s = load()
    st = s[mid]
    anims = st.setdefault("animations", {})
    if name in anims:
        print(mid, name, "exists")
        return
    r = req("POST", "/v1/animations", {"rig_task_id": st["rig"], "action_id": action})
    anims[name] = {"task": r.get("result") or r.get("id"), "action": action}
    print(mid, name, anims[name], "credits", r.get("consumed_credits"))
    save(s)


def get_task(stage, tid):
    return req("GET", task_path(stage) + tid)


def cmd_status(args):
    s = load()
    for mid, st in s.items():
        for stage in ("preview", "refine", "rig"):
            if st.get(stage):
                t = get_task(stage, st[stage])
                err = (t.get("task_error") or {}).get("message", "")
                print("%-16s %-8s %-11s %3s%% %s" % (mid, stage, t.get("status"), t.get("progress"), err))
        for name, a in st.get("animations", {}).items():
            t = get_task("anim", a["task"])
            print("%-16s %-8s %-11s %3s%% %s" % (mid, name, t.get("status"), t.get("progress"), (t.get("task_error") or {}).get("message", "")))


def cmd_wait(args):
    stage = args[0]
    s = load()
    pending = {mid: st[stage] for mid, st in s.items() if st.get(stage)}
    while pending:
        for mid, tid in list(pending.items()):
            t = get_task(stage, tid)
            if t.get("status") in ("SUCCEEDED", "FAILED", "CANCELED", "EXPIRED"):
                print(mid, stage, t.get("status"), (t.get("task_error") or {}).get("message", ""), flush=True)
                del pending[mid]
        if pending:
            time.sleep(15)


def fetch(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as r, open(path, "wb") as f:
        f.write(r.read())
    print("  saved", os.path.relpath(path, ROOT), os.path.getsize(path) // 1024, "KB")


def cmd_download(args):
    s = load()
    for mid in ids(args):
        st = s.get(mid, {})
        out = os.path.join(ROOT, "Assets", "Chests" if mid in CHESTS else "Monsters", mid)
        if st.get("refine"):
            t = get_task("refine", st["refine"])
            if t.get("status") == "SUCCEEDED":
                fetch(t["model_urls"]["glb"], os.path.join(out, mid + "_static.glb"))
                if t.get("thumbnail_url"):
                    fetch(t["thumbnail_url"], os.path.join(out, "meshy_thumbnail.png"))
        if st.get("rig"):
            t = get_task("rig", st["rig"])
            if t.get("status") == "SUCCEEDED":
                res = t.get("result", {})
                st["rig_result"] = res
                fetch(res["rigged_character_glb_url"], os.path.join(out, mid + "_rigged.glb"))
                for k, v in (res.get("basic_animations") or {}).items():
                    if k.endswith("glb_url") and v:
                        fetch(v, os.path.join(out, "anim_" + k.replace("_glb_url", "") + ".glb"))
        for name, a in st.get("animations", {}).items():
            t = get_task("anim", a["task"])
            if t.get("status") == "SUCCEEDED":
                url = (t.get("result") or {}).get("animation_glb_url")
                if url:
                    fetch(url, os.path.join(out, "anim_" + name + ".glb"))
        save(s)


def cmd_balance(_):
    print(req("GET", "/v1/balance"))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    globals()["cmd_" + sys.argv[1]](sys.argv[2:])
