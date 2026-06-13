;;; config.el --- Load wd's configuration -*- lexical-binding: t; -*-

;; Add path
(add-load-path! "lisp/" "lisp/lib/")

;; From Lucius
;; Produce backtraces when errors occur: can be helpful to diagnose startup issues
;; (setq debug-on-error t)
(defconst *is-mac* (eq system-type 'darwin))
(defconst *is-linux* (memq system-type '(gnu gnu/linux gnu/kfreebsd berkeley-unix)))
(defconst *org-path* "~/org/")
(defconst *fallback-fonts* '("Fira Code" "Jigmo" "Jigmo2" "Jigmo3"))
(defconst *font-size* (if *is-mac* 14 15))
(defconst *golden-ratio* (/ (- (sqrt 5) 1) 2))
;; (defconst *default-font* (format (if *is-mac* "MonoLisa Lucius %d" "PragmataPro Liga %d") *font-size*))
(defconst *default-font* (format (if *is-mac* "Monaco %d" "PragmataPro Liga %d") *font-size*))
(defconst *org-font* (format "Aporetic Serif Mono %d" *font-size*))
(defconst *term-default-font* (format "Aporetic Serif Mono %d" *font-size*))
(defconst *prog-font* (format "Aporetic Serif Mono %d" *font-size*))
(defconst *zh-default-font* "LXGW WenKai Screen")
(defconst *nerd-icons-font* "Symbols Nerd Font Mono")
(defconst *emoji-fonts* '("Apple Color Emoji"
                          "Noto Color Emoji"
                          "Noto Emoji"
                          "Segoe UI Emoji"))
(defconst *symbol-font* '("Apple Symbols"
                          "Segoe UI Symbol"
                          "Symbola"
                          "Symbol"))

;; Add setup support
(require 'init-setup)

;; utilities
(if (not *is-mac*) (require 'init-mail))
(require 'init-ledger)
(require 'init-telega)

;; UI
(require 'init-ui)
(require 'init-rime)                    ;; rime font-size = (+1 init-ui)

;; reading
(require 'init-read)

;; org-mode
(require 'init-org)
(require 'init-roam)

;; AI
(require 'init-llm)

(require 'init-misc)

;; others
(require 'init-tramp)
(require 'init-lookup)
(require 'init-vcs)
(require 'init-term)
(require 'init-langs)

(when (file-exists-p "~/projects/2026/haskell-web/scripts/elisp/lib-org-capture.el")
  (load "~/projects/2026/haskell-web/scripts/elisp/lib-org-capture.el"))
;; (require 'init-elfeed)
