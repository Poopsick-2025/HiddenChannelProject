# HiddenChannelProject

Private experimental repository for hidden Roblox communication channels.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Poopsick-2025/HiddenChannelProject/main/fastscript.luau"))()
```

Requires the local WS server (`HiddenChannelProject/server/ws_server.py`) at `ws://127.0.0.1:8767`.

## Structure

- `CORE/` — ENV, WS, ZIP, chunker, P2P, snapshots
- `MICUP-TTS/` — HTS1 TTS channel
- `AnimDATA/` — AnimationSpeed fallback
- `HIDDEN-CHAT/` — Hidden channel UI + FileExplorer
- `docs/RU-RU`, `docs/EN-US`
