# Legacy `.conf` configuration (archived)

These are the original Hyprland `.conf` files, archived on 2026-08-10 when the
config was migrated to the Lua format that Hyprland 0.57 requires.

Hyprland no longer reads anything in this directory. It is kept for reference
and rollback.

## Rollback

Hyprland prefers `hyprland.lua` over `hyprland.conf`, so restoring is a matter of
putting the `.conf` files back and removing the Lua entrypoint:

```sh
cd ~/.config/hypr
mv hyprland.lua lua-entrypoint.lua.bak      # Hyprland stops seeing the Lua config
cp legacy-conf/hyprland.conf .
cp legacy-conf/configs/*.conf configs/
cp legacy-conf/UserConfigs/*.conf UserConfigs/
cp legacy-conf/wallust/*.conf wallust/
hyprctl reload
```

You must also revert the two tool integrations:

```sh
# wallust: point the hypr template back at the .conf output
sed -i "s|hypr.template = 'colors-hyprland.lua'|hypr.template = 'colors-hyprland.conf'|; \
        s|hypr.target = '~/.config/hypr/lua/colors.lua'|hypr.target = '~/.config/hypr/wallust/wallust-hyprland.conf'|" \
    ~/.config/wallust/wallust.toml

# animation picker: revert to copying .conf presets
#   scripts/Animations.sh -> change *.lua back to *.conf and
#   $LuaConfigs/animations.lua back to $UserConfigs/UserAnimations.conf
```

A full pre-migration tarball also exists at
`~/.config/hypr-backup-20260810-223603.tar.gz`, which restores everything
including the tool integrations:

```sh
cd ~/.config && tar xzf hypr-backup-20260810-223603.tar.gz
```

## What was NOT archived, and why

| File | Reason it stayed in place |
|---|---|
| `monitors.conf`, `workspaces.conf` | nwg-displays writes these; `scripts/nwg-displays-to-lua.py` converts them into `lua/` |
| `UserConfigs/01-UserDefaults.conf` | still grepped by `Kool_Quick_Settings.sh`, `RofiSearch.sh`, `WaybarScripts.sh`, `WallpaperSelect.sh`, `WallpaperEffects.sh`, `sddm_wallpaper.sh` for `$term` / `$files` / `$Search_Engine` / `$edit` |
| `hypridle.conf`, `hyprlock.conf`, `hyprlock-2k.conf` | belong to hypridle and hyprlock, which are separate programs with their own parsers. The 0.57 change does not affect them. |
| `animations/*.conf` | kept next to the generated `animations/*.lua` for reference |
| `Monitor_Profiles/default.conf` | reference copy of the stock monitor layout |
| `configs/WindowRules-config-v3.conf`, `UserConfigs/WindowRules-old.conf`, `UserConfigs/WindowRules-v3.conf` | were never sourced by `hyprland.conf`; left untouched |
