# AGENTS.md - Emacs Configuration

## Purpose

This document defines the execution contract for AI agents working in this Doom Emacs configuration repository. It establishes workflows, file organization, and integration with the Nix-based system environment.

## Non-Goals

- This is not a generic Emacs tutorial.
- This does not replace Doom Emacs or upstream package documentation.
- This does not manage external tool dependencies (those are in the Nix configuration).

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
│   ├── init-fonts.el       # font constants, doom-font, CJK fontset/guardrails
│   ├── init-ui.el          # theme face tweaks, frame, splash, gif-screencast
│   ├── init-editor.el      # modal editing (meow), lispy
│   ├── init-rime.el        # input method (Rime)
│   │  -- dev tools --
│   ├── init-langs.el       # small language modes without their own file
│   ├── init-vcs.el         # magit / git-commit
│   ├── init-term.el        # vterm
│   ├── init-tramp.el       # TRAMP, remote source-dir, envrc
│   ├── init-lookup.el      # lookup providers, dictionary, eldoc
│   │  -- org ecosystem --
│   ├── init-org.el         # org core (log/latex/babel/file-apps), attach, deft, publish
│   ├── init-org-agenda.el  # agenda, capture, calendar/holidays, work-mode
│   ├── init-biblio.el      # bibliography/citations (citar/reftex)
│   ├── init-roam.el        # org-roam + org-roam-ui
│   │  -- apps --
│   ├── init-read.el        # reading (calibredb, nov, pdf-tools, org-noter)
│   ├── init-ledger.el      # finance (ledger-mode)
│   ├── init-llm.el         # AI (gptel, aidermacs, claude-code-ide)
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
- **Feature configuration**: one cohesive responsibility per `lisp/init-<area>.el`. Names are descriptive (no category prefixes); the layout stays flat. Split a module only when it exceeds ~one screen or mixes more than one concern (e.g. org is split into `init-org` / `init-org-agenda` / `init-biblio`).
- **Helper functions**: heavier helpers go in `lib/lib-<area>.el`, loaded inside the owning feature's setup via `(:also-load lib-<area>)`. Move a defun there once it is unreferenced from / incidental to the init module.
- **Load order**: `config.el` requires modules in grouped order (infrastructure → appearance/input → dev tools → org ecosystem → apps). Global predicates/path constants (`*is-mac*`, `*org-path*`, …) stay at the top of `config.el`.

### Code Style

- Use `;;; filename.el --- description` header comment
- **Prefer `setup` macro**: Use `setup` macro from `init-setup.el` for configuration wherever possible; only fall back to `after!` or bare `setopt`/`setq` when `setup` cannot express the construct
- Use `after!` for package-specific configuration only when `setup` is insufficient
- Prefer `setopt` over `setq` for user options
- Add `(provide 'filename)` at end of files
- **Prefer defaults over explicit config**: If a setting matches the package or Doom default, delete the explicit override and rely on the default. Only write configuration that actually differs from the default.
- **Guard `pcase`-derived paths before using in lists**: When a variable is set via `pcase system-name` and not all hosts are covered, the value may be `nil` on unmatched hosts. Never put such a value directly into a list (e.g. `(list (list var))`); wrap it with `(when var ...)` to avoid inserting `(nil)` entries that cause `wrong-type-argument` errors downstream.

### Package Management

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

1. Org core (log/latex/babel/file-apps, attach, deft, publish): `lisp/init-org.el`
2. Agenda / capture / calendar / work-mode: `lisp/init-org-agenda.el`
3. Bibliography / citations (citar/reftex): `lisp/init-biblio.el`
4. Org-roam: `lisp/init-roam.el`

### Reading Stack (calibredb / org-noter)

Feature code lives in `lisp/init-read.el` (setup + hooks) and `lisp/lib/lib-read.el`
(helpers). Core invariants — keep them, do not regress:

- **Everything goes through OPDS — no local library / sqlite.** `calibredb-root-dir`
  is the OPDS content-server URL on every host; search, open and noter all use OPDS
  download. Do not re-introduce local-vs-OPDS branching, `metadata.db` queries, or a
  local-first open advice.
- **The calibre id is the key; the OPDS acquisition URL is the portable handle.**
  Extract the id from the entry `:file-path` URL (`/get/<fmt>/<id>/`); never
  reverse-infer it from a filename or `Title (id)/` directory.
- **Downloads are cached and centralized in `+wd/calibre--download`** (curl
  `--digest`, landing at `<calibredb-opds-download-dir>/<title>.<fmt>`; returns the
  path without re-downloading if it already exists). The command and the parse hook
  share it.
- **Notes use one unified `CDB-<id>.org`, written in exactly one place**
  (`+wd/calibre--ensure-note-file`): `:NOTER_DOCUMENT:` (bare download filename),
  `:CALIBRE_ID:`, `:CALIBRE_URL:` (full OPDS acquisition URL). Start org-noter from
  that org buffer (A-mode), not via `find-additional-notes-functions`.
- **Opening resolves via `org-noter-parse-document-property-hook` in two steps:**
  use `NOTER_DOCUMENT` if the file exists, else re-download via the heading's
  `:CALIBRE_URL:` (read with `(org-entry-get nil "CALIBRE_URL" t)`) — so a notes
  file opens on any machine.
- Helpers that call lazily-loaded calibredb/org-noter symbols must
  `declare-function`/`defvar` them so `lib-read.el` byte-compiles clean.

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
- In GUI Emacs (macOS and Linux), Enter sends `<return>`, not `RET`. `RET` was bound to `meow-line` in Normal state but `<return>` was not, causing it to fall through to `newline`. Fixed by binding `<return>` → `meow-line` in Normal state.
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
