#!/usr/bin/env python3





# --- Config ---
APPNAME  = "Minecraft Splitscreen"
EXE      = '/home/deck/.local/share/PolyMC/minecraft.sh'
STARTDIR = "/home/deck/.local/share/PolyMC"

STEAMGRIDDB_IMAGES = {
    "p": "https://cdn2.steamgriddb.com/grid/a73027901f88055aaa0fd1a9e25d36c7.png",
    "":  "https://cdn2.steamgriddb.com/grid/e353b610e9ce20f963b4cca5da565605.jpg",
    "_hero": "https://cdn2.steamgriddb.com/hero/ecd812da02543c0269cfc2c56ab3c3c0.png",
    "_logo": "https://cdn2.steamgriddb.com/logo/90915208c601cc8c86ad01250ee90c12.png",
    "_icon": "https://cdn2.steamgriddb.com/icon/add7a048049671970976f3e18f21ade3.ico"
}





import os
import re
import struct
import zlib
import urllib.request


# --- Locate Steam shortcuts file ---
userdata = os.path.expanduser("~/.steam/steam/userdata")
user_id = next((d for d in os.listdir(userdata) if d.isdigit()), None)
if not user_id:
    print("❌ No Steam user found.")
    exit(1)
config_dir = os.path.join(userdata, user_id, "config")
shortcuts_file = os.path.join(config_dir, "shortcuts.vdf")


# --- Ensure shortcuts file exists ---
if not os.path.exists(shortcuts_file):
    with open(shortcuts_file, "wb") as f:
        f.write(b'\x00shortcuts\x00\x08\x08')  # empty VDF structure

# --- Read current shortcuts.vdf ---
with open(shortcuts_file, "rb") as f:
    data = f.read()

def get_latest_index(data):
    # Look for: \x00<index>\x00 followed by shortcut data
    matches = re.findall(rb'\x00(\d+)\x00', data)
    if matches:
        return int(matches[-1])
    return -1

# --- Determine next shortcut index ---
index = get_latest_index(data) + 1

# --- Create binary shortcut entry ---
def make_entry(index, appid, appname, exe, startdir):
    x00 = b'\x00'; x01 = b'\x01'; x02 = b'\x02'; x08 = b'\x08'
    b = b''
    b += x00 + str(index).encode() + x00
    b += x02 + b'appid' + x00 + struct.pack('<I', appid)
    b += x01 + b'appname' + x00 + appname.encode() + x00
    b += x01 + b'exe' + x00 + exe.encode() + x00
    b += x01 + b'StartDir' + x00 + startdir.encode() + x00
    b += x01 + b'icon' + x00 + config_dir.encode() + b'/grid/' + str(appid).encode() + b'_icon.ico' + x00
    b += x08
    return b

appid = 0x80000000 | zlib.crc32((APPNAME + EXE).encode("utf-8")) & 0xFFFFFFFF
entry = make_entry(index, appid, APPNAME, EXE, STARTDIR)

# --- Insert before last 2 \x08s ---
if data.endswith(b'\x08\x08'):
    new_data = data[:-2] + entry + b'\x08\x08'
    with open(shortcuts_file, "wb") as f:
        f.write(new_data)
    print(f"✅ Minecraft shortcut added with index {index} and appid {appid}")
else:
    print("❌ File structure not recognized. No changes made.")
    exit(1)

# --- Download SteamGridDB artwork ---
grid_dir = os.path.join(userdata, user_id, "config", "grid")
os.makedirs(grid_dir, exist_ok=True)

for suffix, url in STEAMGRIDDB_IMAGES.items():
    path = os.path.join(grid_dir, f"{appid}{suffix}.png" if not url.endswith(".ico") else f"{appid}{suffix}.ico")
    if os.path.exists(path):
        print(f"✅ Skipping {suffix} image — already exists.")
        continue
    try:
        print(f"Downloading: {url}")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as resp, open(path, "wb") as out:
            out.write(resp.read())
        print(f"✅ Saved {suffix} image.")
    except Exception as e:
        print(f"⚠️ Failed to download {suffix} image: {e}")

print("✅ All done. Launch Steam to see Minecraft in your Library.")
