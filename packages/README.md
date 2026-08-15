# Package manifests

Regenerate both files with `../update.sh`, which runs:

```sh
pacman -Qqen > pacman-explicit.txt   # explicitly installed, from official repos
pacman -Qqem > aur.txt               # explicitly installed, foreign (AUR) origin
```

`-e` limits the list to packages you *asked* for, excluding the hundreds pulled
in as dependencies — those come back automatically when the explicit set is
installed. `-n`/`-m` split native from foreign, because they need different
installers.

## Restoring

```sh
sudo pacman -S --needed - < pacman-explicit.txt
yay      -S --needed - < aur.txt
```

`--needed` skips anything already present, so both commands are safe to re-run.
Install the native list first: several AUR builds depend on it.

If pacman rejects a name, the package was renamed or dropped from the repos
since the manifest was written. Remove that line and continue — the manifest is
a record of one machine at one moment, not a guarantee about the future.

## Caveats

- **Not a lockfile.** Versions are not pinned. You get whatever is current.
- **AUR needs a helper.** `yay` is itself in `aur.txt`; bootstrap it manually
  first (`git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si`).
- **Nothing here is required** for the dotfiles to deploy. `install.sh` only
  needs `git` and `stow`; the manifests exist so a new machine can reach
  feature parity, not so it can link configs.
