;;; config.el --- Load wd's configuration -*- lexical-binding: t; -*-

(dolist (dir (list (expand-file-name "lisp" doom-user-dir)
                   (expand-file-name "lisp/dev" doom-user-dir)))
  (add-to-list 'load-path dir))

;; From Lucius
;; Produce backtraces when errors occur: can be helpful to diagnose startup issues
;; (setq debug-on-error t)
(defconst *is-mac* (eq system-type 'darwin))
(defconst *is-home* (string= (system-name) "nixos-nuc"))
(defconst *is-work* (string= (system-name) "ubuntu2204"))
;; fonts
(defconst +wd/code-font "Sarasa Fixed SC")
(defconst +wd/cjk-font "Sarasa Gothic SC")
(defconst +wd/fixed-cjk-font "Sarasa Fixed SC")
(defconst +wd/font-size (if *is-work* 18 16))

;; Bootstrap project-local setup directives before using them.
(load (expand-file-name "lisp/init-setup" doom-user-dir))

;; appearance & input
(require 'init-fonts)
(require 'init-ui)
(require 'init-editor)
(require 'init-rime)

;; dev tools
(require 'init-langs)
(require 'init-vcs)
(require 'init-remote)

;; org ecosystem
(require 'init-org)
(require 'init-org-agenda)
(require 'init-org-publish)
(require 'init-roam)

;; reading
(require 'init-calibre)
(require 'init-pdf)
(require 'init-org-noter)

;; apps
(require 'init-schedule)
(require 'init-ledger)
(require 'init-llm)
(require 'init-mail)
(require 'init-ledger-stock-alert)
(require 'init-telega)
