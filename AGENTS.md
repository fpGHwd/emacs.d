# AGENTS.md - Emacs Configuration

## Purpose

This document defines the execution contract for AI agents working in this Doom Emacs configuration repository. It establishes workflows, file organization, and integration with the Nix-based system environment.

## Non-Goals

- This is not a generic Emacs tutorial.
- This does not replace Doom Emacs or upstream package documentation.
- This does not manage external tool dependencies (those are in the Nix configuration).

## Documentation Boundary

`AGENTS.md` is for durable agent execution contracts: repository structure,
coding conventions, workflow requirements, safety rules, and project-wide
invariants that should shape future automated edits.

Ordinary documentation under `docs/` is for troubleshooting notes, incident
records, command transcripts, version compatibility findings, and operational
procedures. Link from `AGENTS.md` only when a document establishes an enduring
rule agents must follow.

## Repository Structure

```
~/.config/emacs.d/
├── init.el              # Doom module configuration (enable/disable modules)
├── config.el            # Main configuration entry point, loads all lisp/
├── packages.el          # Package declarations (package! forms)
├── custom.el            # Custom variables (auto-generated, avoid editing)
├── lisp/                # Feature-specific configuration modules (flat, single-responsibility)
│   ├── init-setup.el       # setup.el macro extensions (:defer/:hooks/:option/...)
│   ├── init-session.el     # credentials (auth-source), recentf, workspaces, identity
│   │  -- appearance & input --
│   ├── init-fonts.el       # required local fonts, doom-font, CJK fontset
│   ├── init-ui.el          # theme face tweaks, frame
│   ├── init-editor.el      # modal editing (meow), lispy
│   ├── init-rime.el        # input method (Rime)
│   │  -- dev tools --
│   ├── init-langs.el       # small language modes without their own file
│   ├── init-vcs.el         # magit / git-commit
│   ├── init-term.el        # vterm
│   ├── init-remote.el      # TRAMP, remote source-dir, envrc
│   ├── init-lookup.el      # lookup providers, dictionary, eldoc
│   │  -- org ecosystem --
│   ├── init-org.el         # org core (log/latex/babel/file-apps), agenda, capture, calendar/holidays, attach, publish
│   ├── init-biblio.el      # bibliography/citations (citar/reftex)
│   ├── init-roam.el        # org-roam + org-roam-ui
│   │  -- apps --
│   ├── init-schedule.el    # user scheduled tasks (org auto-commit)
│   ├── init-read.el        # reading (calibredb, nov, pdf-tools, org-noter)
│   ├── init-ledger.el      # finance (ledger-mode)
│   ├── init-llm.el         # AI (gptel, claude-code-ide)
│   ├── init-mail.el        # email (mu4e, non-mac)
│   ├── init-telega.el      # Telegram client
│   └── lib/                # Helper libraries (lib-<area>.el, loaded via :also-load)
└── snippets/            # Yasnippet snippets
```

Module layout is **flat** (no `core/`/`tools/`/`ui/` subdirectories) and each `init-<area>.el`
has a single cohesive responsibility. `config.el` requires them in the grouped order above.

## Configuration Rules

### File Placement

- **Doom modules**: Changes in `init.el` (enable/disable modules)
- **Package declarations**: Add `package!` forms in `packages.el`
- **Feature configuration**: one cohesive responsibility per `lisp/init-<area>.el`. Names are descriptive (no category prefixes); the layout stays flat. Split a module only when it exceeds ~one screen or mixes more than one concern (e.g. org is split into `init-org` / `init-roam` / `init-biblio`).
- **Helper functions**: heavier helpers go in `lib/lib-<area>.el`, loaded inside the owning feature's setup via `(:also-load lib-<area>)`. Move a defun there once it is unreferenced from / incidental to the init module.
- **Load order**: `config.el` requires modules in grouped order (infrastructure → appearance/input → dev tools → org ecosystem → apps). Global predicates/path constants (`*is-mac*`, `*org-path*`, …) stay at the top of `config.el`.

### Code Style

- Use `;;; filename.el --- description` header comment
- **Prefer `setup` macro**: Use `setup` macro from `init-setup.el` for configuration wherever possible; only fall back to `after!` or bare `setopt`/`setq` when `setup` cannot express the construct
- **Keep `setup :when-loaded` narrow**: Put plain `:option`, hooks, autoloads, and top-level `:also-load` outside `:when-loaded` whenever possible. Use `:when-loaded` only for code that needs loaded package definitions such as keymaps, functions, advices, or mode internals. Never nest `:also-load` inside `:when-loaded`; if a helper must load after the package, use an explicit `(require 'lib-...)` as the first form in that block.
- Use `after!` for package-specific configuration only when `setup` is insufficient
- When aggregating satellite package configuration under an owning `setup` block, use `:bind-into` for cross-feature keymap bindings and `:with-feature` for plain satellite options so option timing stays unchanged.
- Prefer `setopt` over `setq` for user options
- Add `(provide 'filename)` at end of files
- **Prefer defaults over explicit config**: If a setting matches the package or Doom default, delete the explicit override and rely on the default. Only write configuration that actually differs from the default.
- **Fonts are required local dependencies**: Font configuration in `lisp/init-fonts.el` should name the required installed fonts directly and fail loudly when they are absent. Do not add fallback font chains, download hints, or warning-only missing-font behavior.
- **Host gates**: active hosts are `nixos-nuc`, `macos-m1`, and `ubuntu2204`; `arch-nuc` and `macbook-m1-pro` are retired — remove their branches on sight, do not add new ones.
- **Guard `pcase`-derived paths before using in lists**: When a variable is set via `pcase system-name` and not all hosts are covered, the value may be `nil` on unmatched hosts. Never put such a value directly into a list (e.g. `(list (list var))`); wrap it with `(when var ...)` to avoid inserting `(nil)` entries that cause `wrong-type-argument` errors downstream.
- **Do not define config functions from personal Org Babel blocks at startup**: Functions used by Emacs configuration must live in `lisp/` or `lisp/lib/`; startup may hook or call them, but must not open personal org files and execute named source blocks just to define them.
- **Input methods follow editing state, not the reverse**: Subsystems like input methods (rime) should register themselves on editing-state hooks (e.g. `meow-insert-exit-hook`) in their own module (`init-rime.el`), not have the editor module manage them. The editor module (`init-editor.el`) must not depend on input-method packages.
- **Override Doom module defaults via `doom-after-modules-config-hook`**: Doom modules use `use-package! :config` which re-executes unconditionally on `doom/reload` — even after the package is already loaded. This means `setq`, `setup :option`, and `after!` in user config all run *before* the Doom module `:config` block and get overridden. To guarantee user values win, put the `setq` in `doom-after-modules-config-hook` (e.g. `(add-hook! 'doom-after-modules-config-hook (setq ...))`).
- **Use named hook and advice targets**: Keep package connection points (hooks, advices, key bindings) in `init-*.el`, but make targets named functions when they need stable reload, removal, or debugging behavior. Keep single-use implementation details local to the owning function instead of creating exported helper functions.
- **Do not pre-remove `define-advice` reload targets**: `define-advice` installs advice with a stable `name` property, and Emacs replaces existing advice with the same name on reload. Do not add manual `advice-remove` blocks before `define-advice` unless the change is intentionally removing or renaming an existing advice.
- **Defer Calibre document resolution to org-noter start**: Calibredb-created noter files should be structurally complete and include `CALIBRE_ID`, but leave `NOTER_DOCUMENT` empty until `org-noter` starts. Resolve the real local or downloaded document path from Calibre metadata at that point, then write the concrete path back to `NOTER_DOCUMENT` only on the heading that directly owns `CALIBRE_ID`.
- **Keep Calibre progress independent of `NOTER_DOCUMENT`**: `NOTER_DOCUMENT` is only for quickly opening the document file. Reading progress sync must never read it; derive source data from org-noter page markers for PDFs or from remote Calibre server progress for non-PDF formats.
- **Patch PDF annotations only on annotated copies**: Calibre source PDFs must not be modified in place by annotation sync. Create or update a sibling annotated copy (for example, ` - annotated.pdf`) in the same book directory and merge annotations only into that copy.

### Package Management

- Keep package recipes portable and declarative. For private Git package access, use `DOOMGITCONFIG` with cross-platform credential helpers such as `pass-git-helper`; do not encode credentials or macOS-only keychain helpers in synchronized package recipes.

```elisp
;; packages.el - Add new packages
(package! package-name)

;; packages.el - Pin to specific commit
(package! package-name :pin "commit-hash")

;; packages.el - From non-standard source
(package! package-name :recipe (:host github :repo "user/repo"))
```

## External Dependencies

This Emacs configuration depends on external tools managed through Nix:

| Tool | Purpose | Nix Location |
|------|---------|--------------|
| `ghc` | Haskell development | `~/.config/nix.d/modules/emacs.nix` |
| `cabal-install` | Haskell build | `~/.config/nix.d/modules/emacs.nix` |
| `haskell-language-server` | Haskell LSP | `~/.config/nix.d/modules/emacs.nix` |
| `ripgrep` | Search backend | `~/.config/nix.d/modules/emacs.nix` |
| `mu` | Email indexing | `~/.config/nix.d/modules/emacs.nix` |
| `ledger` | Finance tracking | `~/.config/nix.d/modules/emacs.nix` |
| `rime` | Input method | `~/.config/nix.d/modules/emacs.nix` |

**To add external tool dependencies**: Edit `~/.config/nix.d/modules/emacs.nix`, then run `sudo darwin-rebuild switch --flake ~/.config/nix.d#macos-m1` to apply.

## Common Workflows

### Add a New Package

1. Add `(package! package-name)` to `packages.el`
2. Create configuration in `lisp/init-<feature>.el` or existing file
3. Run `doom sync` in terminal
4. Restart Emacs or `M-x doom/reload`

### Modify Editor Behavior

1. Edit `lisp/init-editor.el` for editing-related settings (meow keybindings, cursor, lispy)
2. This config uses **meow** (not evil) as the modal system; configure it with `(setup meow (:when-loaded ...))`
3. Evaluate with `M-x eval-buffer` or `M-x doom/reload`

### Change UI/Theme

1. Theme/frame/splash settings in `lisp/init-ui.el`
2. Fonts (constants, `doom-font`, CJK fontset) in `lisp/init-fonts.el`
3. Run `M-x doom/reload` after changes

### Update Org Configuration

1. Org core (log/latex/babel/file-apps), agenda / capture / calendar, attach, publish: `lisp/init-org.el`
2. Bibliography / citations (citar/reftex): `lisp/init-biblio.el`
3. Org-roam: `lisp/init-roam.el`

## Doom Emacs Specifics

### Key Conventions

- `SPC` is the leader key
- `SPC h d h` - Doom documentation
- `SPC f e d` - Open Doom config (this directory)
- `SPC h r r` - Reload Doom configuration
- `M-x doom/reload` - Full reload

### Module Flags

In `init.el`, flags modify module behavior:
```elisp
(lang +lsp +tree-sitter)  ; Enable LSP and tree-sitter
(editor +everywhere)      ; Enable in all buffers
```

## Integration with Nix Configuration

### Workflow: Change External Tool Dependency

1. Edit `~/.config/nix.d/modules/emacs.nix`
2. Run `sudo darwin-rebuild switch --flake ~/.config/nix.d#macos-m1` (home-manager switch)
3. Verify tool is available: `which <tool>`
4. Restart Emacs if needed

### Workflow: Add Emacs Package Requiring External Tool

1. Add external tool to `~/.config/nix.d/modules/emacs.nix`
2. Run `sudo darwin-rebuild switch --flake ~/.config/nix.d#macos-m1`
3. Add `(package! package-name)` to `packages.el`
4. Add configuration in `lisp/`
5. Run `doom sync`
6. Restart Emacs

## Debugging and Troubleshooting

### Inspecting Live Emacs State

Use `emacsclient` to query a running Emacs instance during investigation — evaluate expressions, check variable values, and observe the effect of changes without restarting:

```bash
emacsclient -e '(some-elisp-expression)'
```

When debugging a problem, first find the call stack / error source before touching any code. Do not make speculative changes prior to identifying the root cause.

**Query live state before reading files**: All current Emacs state — keybindings, variable values, loaded features, active modes, keymap lookups — can and should be obtained via `emacsclient` first. Prefer `emacsclient -e '(expression)'` over guessing from source files, since runtime state may differ from what the code suggests (e.g. hooks may have modified things, packages may not have loaded, or advices may be in effect).

**Trace setting writers before patching symptoms**: When a variable or behavior changes unexpectedly across startup, reload, or mode activation, first search every relevant layer that can write it — this config, Doom modules/source, package source, Custom, hooks, and advices. Distinguish the upstream writer/order issue from downstream symptoms such as stale buffer names or unmanaged runtime state; patch the earliest confirmed override point, not the later symptom.

### Emacs Won't Start

1. Check `*Messages*` buffer: `emacs --debug-init`
2. Check `~/.config/emacs.d/custom.el` for issues
3. Run `doom doctor` for diagnostics

### Never start Emacs with bare `emacs --daemon`

The Emacs server is managed exclusively by the systemd user unit `emacs.service`
(which runs `emacs --fg-daemon`). Launching `emacs --daemon` directly — e.g. to
"restart" after `(kill-emacs)` during debugging — creates an orphan daemon
outside systemd's control that steals the server socket. The systemd unit then
fails with `Unable to start the daemon. Another instance of Emacs is running the
server`, exits 1, and enters a `Restart=on-failure` loop.

- To restart/recover the server: `systemctl --user restart emacs`
  (use `systemctl --user reset-failed emacs` first if it is stuck failing).
- To reload config in the running server: `emacsclient -e '(doom/reload)'`.
- Never run `emacs --daemon`, and never pair `(kill-emacs)` with a manual
  daemon relaunch.

### Package Not Loading

1. Verify in `packages.el`
2. Check `(after! package ...)` syntax
3. Check `*Messages*` for errors
4. Use `emacsclient --eval '(featurep \'package-name)'` to verify

### External Tool Not Found

1. Check `~/.config/nix.d/modules/emacs.nix` has the tool
2. Run `sudo darwin-rebuild switch --flake ~/.config/nix.d#macos-m1` to apply Nix changes
3. Verify with `which <tool>` in shell
4. Check `exec-path` in Emacs: `C-h v exec-path`

## Meow Modal Editing

This config uses `meow` (not evil). The active states and their roles:

| State | Indicator | Role |
|-------|-----------|------|
| Normal | `[N]` | Primary state: navigation, selection, text operations |
| Insert | `[I]` | Text input; entered via `i`/`a`/`c`, exited via `ESC` |
| Keypad | `[K]` | Leader-key sequences triggered by `SPC`; exits automatically |
| Motion | `[M]` | Auto-applied to special buffers (magit, dired, help); read-only nav |
| Beacon | `[B]` | Multi-cursor batch operations |
| Emacs  | `[E]` | Full Emacs key passthrough; toggle with `C-]` |

**Key bindings (qwerty layout, Normal state):** `h/j/k/l` move, `w/b/e` word motion, `x` select line, `d` delete, `s` kill, `c` change (→ Insert), `i`/`a` insert/append, `y` copy, `p` paste, `n` search, `f`/`t` find/till, `u` undo, `SPC` keypad/leader.

**Known pitfalls fixed in `lisp/init-editor.el`:**
- In GUI Emacs (macOS and Linux), Enter sends `<return>`, not `RET`, so Normal-state bindings must cover both. Currently `RET`/`<return>` and `DEL`/`<backspace>` are each bound to `ignore` in Normal state (see `init-editor.el`).
- Motion state is only used for special buffers (magit, dired, help); normal text files never enter Motion state, so no fixes are needed there.

## Skills

This repository includes an `emacs-client` skill for interacting with a running Emacs instance:

- Location: `.codebuddy/skills/emacs-client/`
- Usage: Invoke when needing to debug Emacs state, evaluate Elisp, or inspect configuration
- Scripts: `emacs-query.sh`, `emacs-debug.sh`

## Definition of Done

A configuration change is complete when:

- Correct file location (lisp/, packages.el, or init.el)
- `doom sync` completed without errors
- Emacs restarts successfully
- Feature works as expected
- No errors in `*Messages*` buffer
- External dependencies (if any) added to Nix and applied
- Before committing: verify `emacsclient -e '(doom/reload)'` reports "Config successfully reloaded!" and `*Messages*` contains no new errors. For structural changes (file renames, new requires, deleted files), also grep config.el and lisp/ for dangling `require` calls pointing to non-existent features.

## Default Agent Behavior

When instructions are ambiguous:

- Prefer `lisp/init-<feature>.el` for feature-specific code
- Use `after!` for package-specific configuration
- Add new packages to `packages.el`, not directly in init.el
- External tools go to Nix configuration, not shell commands
- Test changes with `M-x eval-buffer` before full reload
- After modifying an Elisp file, automatically reload it via `emacsclient -e '(load-file "path/to/file.el")'` and run relevant tests or sanity checks where possible.
- You can use emacsclient to observe the current Emacs state, execute commands, etc. When investigating issues, check Emacs execution results via emacsclient.
- When investigating issues, always find the call stack of the problem or error first, then fix it. Do not try random workarounds.
- Never modify code haphazardly before identifying the root cause. Before finding the root cause, only write temporary code — never make permanent changes.
- If you write new Elisp functions, you can load and test them directly using emacsclient.
- **Test before writing config**: Never write Elisp changes directly into config files. First test the code via `emacsclient -e` to confirm it works at runtime — keybindings resolve correctly, functions execute as expected, no errors. Only write the verified code into the config file. Emacs keymaps (especially meow's `emulation-mode-map-alists`), `setup` macro expansion, and package loading order can cause runtime behavior to differ significantly from what the source code appears to do.
- **Documentation target**: Unless the user explicitly says "update the project docs" or names a specific file under `docs/`, add troubleshooting notes and incident records to the relevant skill's `references/` directory (e.g. `.codebuddy/skills/emacs-utils/references/`). Do not write them into `docs/troubleshooting.md` or other project-level documentation without explicit direction.
