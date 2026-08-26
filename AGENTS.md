# AGENTS.md - Emacs Configuration

## Purpose

This document defines the execution contract for AI agents working in this Doom Emacs configuration repository. It establishes principles, file organization rules, coding conventions, and safety rules that should shape future automated edits.

## Non-Goals

- This is not a generic Emacs tutorial.
- This does not replace Doom Emacs or upstream package documentation.
- This does not manage external tool dependencies (those are in the Nix configuration).

## Documentation Boundary

`AGENTS.md` is for durable agent execution contracts: repository structure conventions,
coding invariants, workflow requirements, safety rules, and project-wide principles that should shape future automated edits.

Ordinary documentation under `docs/` and `.codebuddy/skills/emacs-utils/references/` is for troubleshooting notes, incident records, command transcripts, version compatibility findings, and operational procedures. Link from `AGENTS.md` only when a document establishes an enduring rule agents must follow.

## Core Principles

- **Flat module layout**: `lisp/` has no subdirectories. Each `init-<area>.el` has a single cohesive responsibility.
- **Runtime validation before file writes**: For Elisp and other interpreted configuration, proposed behavior must be tested in the live runtime first via `emacsclient -e` or another direct temporary eval path. Confirm the behavior works before editing the persistent configuration file.
- **Root cause before repair**: Do not write production code, install bypasses, or block the failing path before the root cause is confirmed by call stack, logs, or runtime state inspection.
- **Prefer defaults over explicit config**: If a setting matches the package or Doom default, delete the explicit override.
- **Host-aware configuration**: Active hosts are `nixos-nuc`, `macos-m1`, and `ubuntu2204`; `arch-nuc` and `macbook-m1-pro` are retired.
- **Separation of concerns**: Input methods register themselves on editing-state hooks in their own module; the editor module must not depend on input-method packages.
- **Doom module override discipline**: Doom modules use `use-package! :config` which re-executes unconditionally on `doom/reload`. User config runs *before* the Doom `:config` block and gets overridden. To guarantee user values win, use `doom-after-modules-config-hook`.
- **Helper placement**: Heavier helpers go in `lib/lib-<area>.el`, loaded via `(:also-load lib-<area>)`. Move a defun there once it is unreferenced from / incidental to the init module.

## Configuration Rules

### File Placement

- **Doom modules**: Changes in `init.el` (enable/disable modules)
- **Package declarations**: Add `package!` forms in `packages.el`
- **Feature configuration**: one cohesive responsibility per `lisp/init-<area>.el`
- **Helper functions**: `lib/lib-<area>.el`, loaded inside the owning feature's setup
- **Load order**: `config.el` requires modules in grouped order (infrastructure → appearance/input → dev tools → org ecosystem → apps). Global predicates/path constants stay at the top of `config.el`.

### Code Style

- Use `;;; filename.el --- description` header comment; `(provide 'filename)` at end.
- **Prefer `setup` macro** from `init-setup.el`; fall back to `after!` only when `setup` cannot express the construct.
- **Keep `setup :when-loaded` narrow**: Put plain `:option`, hooks, autoloads, and top-level `:also-load` outside `:when-loaded`. Never nest `:also-load` inside `:when-loaded`.
- Prefer `setopt` over `setq` for user options.
- When aggregating satellite packages under an owning `setup` block, use `:bind-into` for cross-feature keymap bindings and `:with-feature` for plain satellite options.
- **Guard `pcase`-derived paths**: When a variable is set via `pcase system-name` and not all hosts are covered, wrap it with `(when var ...)` before inserting into lists.
- **Named hook and advice targets**: Keep package connection points in `init-*.el`, but make targets named functions when they need stable reload, removal, or debugging.
- **Do not pre-remove `define-advice` reload targets**: `define-advice` replaces existing advice with the same name on reload. No manual `advice-remove` before `define-advice` unless intentionally removing an existing advice.
- **Fonts are required local dependencies**: Font configuration should name required installed fonts directly and fail loudly when absent. No fallback chains or warning-only missing-font behavior.
- **Do not define config functions from personal Org Babel blocks at startup**: Functions used by Emacs configuration must live in `lisp/` or `lisp/lib/`.
- **Calibre rules** (field-scoped overrides, annotated copies, independent progress tracking): See `.codebuddy/skills/emacs-utils/references/emacs_config_coding_rules.org`

### Package Management

- Keep package recipes portable and declarative. Use `DOOMGITCONFIG` with cross-platform credential helpers; do not encode credentials or macOS-only keychain helpers in synchronized recipes.

## External Dependencies

External tools are managed through Nix (`~/.config/nix.d/modules/emacs.nix`). See `references/emacs_config_coding_rules.org` for the dependency list and update workflow.

## Definition of Done

A configuration change is complete when:

- Correct file location (lisp/, packages.el, or init.el)
- `doom sync` completed without errors
- Emacs restarts successfully
- Feature works as expected
- No errors in `*Messages*` buffer
- External dependencies (if any) added to Nix and applied
- Before committing: verify `emacsclient -e '(doom/reload)'` reports success and `*Messages*` contains no new errors. For structural changes, grep config.el and lisp/ for dangling `require` calls.

## Default Agent Behavior

When instructions are ambiguous:

- Prefer `lisp/init-<feature>.el` for feature-specific code
- Use `after!` for package-specific configuration only when `setup` is insufficient
- Add new packages to `packages.el`, not directly in init.el
- External tools go to Nix configuration, not shell commands
- Validate in live runtime before editing persistent files
- Apply **Root cause before repair** strictly
- **Documentation target**: Unless explicitly directed, add troubleshooting notes to the relevant skill's `references/` directory. Do not write project-level docs without explicit direction.

## Skill References

For concrete how-to, workflows, troubleshooting, and detailed reference material, consult the `emacs-utils` skill:

- **Skill location**: `~/.codebuddy/skills/emacs-utils/`
- **Repository structure & module layout**: `references/emacs_config_coding_rules.org`
- **Coding rules checklist**: `references/emacs_config_review_checklist.org`
- **Doom/keymap/meow specifics**: `references/emacs_keymap_common_sense.org`, `references/emacs_keymap_leader.org`, `references/emacs_keymap_prefix_overview.org`
- **Troubleshooting & incidents**: `references/emacs_troubleshooting.org`
- **Elisp core concepts**: `references/elisp_concepts_guide.org`
- **Workflow templates & snippets**: `references/project_templates_and_snippets.org`
- **Edebug**: `references/emacs_edebug.org`
- **GDB C-level debugging**: `references/emacs_gdb_debug.org`
- **Open files via emacsclient**: `SKILL.md` Section 1
