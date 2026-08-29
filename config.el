;;; config.el --- Load wd's configuration -*- lexical-binding: t; -*-

;; Bootstrap setup before loading the project-local setup extensions.
(require 'setup)
(setup emacs
  (:option (prepend* load-path)
           (list (expand-file-name "lisp" doom-user-dir)
                 (expand-file-name "lisp/dev" doom-user-dir))))

;; From Lucius
;; Produce backtraces when errors occur: can be helpful to diagnose startup issues
;; (setq debug-on-error t)
(defconst *is-mac* (eq system-type 'darwin))
(defconst *is-linux* (memq system-type '(gnu gnu/linux gnu/kfreebsd berkeley-unix)))
(defconst *golden-ratio* (/ (- (sqrt 5) 1) 2))

;; infrastructure
(require 'init-setup)
(require 'init-session)

;; appearance & input
(require 'init-fonts)
(require 'init-ui)
(require 'init-editor)
(require 'init-rime)

;; dev tools
(require 'init-langs)
(require 'init-vcs)
(require 'init-term)
(require 'init-remote)
(require 'init-lookup)

;; org ecosystem
(require 'init-org)
(require 'init-org-agenda)
(require 'init-org-capture)
(require 'init-org-publish)
(require 'init-biblio)
(require 'init-roam)

;; reading
(require 'init-calibre)
(require 'init-ebooks)
(require 'init-pdf)
(require 'init-org-noter)

;; apps
(require 'init-schedule)
(require 'init-ledger)
(require 'init-llm)
(require 'init-mail)
(require 'init-telega)
