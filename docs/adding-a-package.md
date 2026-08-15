# Adding, moving and removing configs

## Adding a config that is not yet tracked

Say you start using `zathura` and want `~/.config/zathura` in the repo. It
belongs in the existing `cli` package:

```sh
mv ~/.config/zathura ~/dotfiles/cli/.config/
stow -d ~/dotfiles -t ~ -R cli          # -R restows: heals the whole package
ls -l ~/.config/zathura                 # confirm it is now a symlink
~/dotfiles/update.sh -m "track zathura config"
```

The `mv` then `stow` order matters. Stow refuses to overwrite a real file, so
the target must be vacant before linking.

## Creating a new package

Only worth it for something large enough to deploy on its own. The layout
inside a package mirrors `$HOME` exactly:

```sh
mkdir -p ~/dotfiles/emacs/.config
mv ~/.config/emacs ~/dotfiles/emacs/.config/
stow -d ~/dotfiles -t ~ -R emacs
```

`install.sh` and `uninstall.sh` discover packages automatically — any top-level
directory containing a dot-entry, excluding `templates`, `docs` and `packages`.
No list to update.

## Removing a config from the repo

```sh
stow -d ~/dotfiles -t ~ -D cli                  # unlink the whole package
mv ~/dotfiles/cli/.config/zathura ~/.config/    # take the real files back
stow -d ~/dotfiles -t ~ -R cli                  # relink what remains
~/dotfiles/update.sh -m "stop tracking zathura"
```

## Marking something machine-specific

When a file should be deployed but must differ per machine:

1. Add its repo-relative path to `.gitignore`, under the machine-specific
   section, with a comment saying why.
2. Add a `templates/<name>.example` with placeholder values and a header
   explaining what to fill in.
3. Add a `seed` call in `install.sh` §1 so a fresh clone gets a working copy.

Step 3 is not optional when something `require()`s the file — Hyprland refuses
to start if `hyprland.lua` requires a module that does not exist.

## Marking something secret

Never gitignore a config file just because one value in it is sensitive: the
whole file then stops being shared. Instead extract the value.

1. Add `export MY_TOKEN=…` to `~/.config/secrets.env` (gitignored).
2. Add the same key with a placeholder to `templates/secrets.env.example`.
3. Source it at the point of use and reference the variable:

   ```sh
   [ -f "$HOME/.config/secrets.env" ] && . "$HOME/.config/secrets.env"
   myapp --token "$MY_TOKEN"
   ```

Guard the source with `[ -f … ]` so the script still runs on a machine where
the file has not been filled in.

`update.sh` greps staged content for credential-shaped strings before every
commit. It is a safety net, not a substitute for doing the above.

## Checking what git will actually see

```sh
git -C ~/dotfiles status --short
git -C ~/dotfiles check-ignore -v ~/dotfiles/hypr/.config/hypr/lua/colors.lua
```

The second command names the exact `.gitignore` line responsible when a file
you expected to be tracked is not.
