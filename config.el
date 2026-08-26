;;; config.el --- Load wd's configuration -*- lexical-binding: t; -*-

;; Add path
(add-load-path! "lisp/" "lisp/lib/" "lisp/dev")

;; From Lucius
;; Produce backtraces when errors occur: can be helpful to diagnose startup issues
;; (setq debug-on-error t)
(defconst *is-mac* (eq system-type 'darwin))
(defconst *is-linux* (memq system-type '(gnu gnu/linux gnu/kfreebsd berkeley-unix)))
(defconst *org-path* "~/org/")
(defconst *golden-ratio* (/ (- (sqrt 5) 1) 2))
;; Font family constants live in init-fonts.el.

;; infrastructure
(require 'init-setup)
(require 'init-session)

(setq default-input-method "rime")

;; appearance & input
(require 'init-fonts)
(require 'init-ui)
(require 'init-editor)
(require 'init-rime)                    ;; rime font-size = (+1 init-fonts)

;; dev tools
(require 'init-langs)
(require 'init-vcs)
(require 'init-term)
(require 'init-remote)
(require 'init-lookup)

;; org ecosystem
(require 'init-org)
(require 'init-biblio)
(require 'init-roam)

;; apps
(require 'init-schedule)
(require 'init-read)
(require 'init-ledger)
(require 'init-llm)
(require 'init-mail)
(require 'init-telega)

;; machine specific
(when (string= (system-name) "ubuntu2204")
  (require '8155-debug))
