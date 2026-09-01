;;; config.el --- Load wd's configuration -*- lexical-binding: t; -*-

;; Bootstrap project-local setup directives before using them.
(load (expand-file-name "lisp/init-setup" doom-user-dir))

;; Cache the contents of `load-path' directories so library loading can skip
;; directories that cannot contain the requested file (Emacs 31+).
(when (boundp 'load-path-filter-function)
  (setq load-path-filter-function
        #'load-path-filter-cache-directory-files))

(setup emacs
  (:setopt (prepend* load-path)
           (list (expand-file-name "lisp" doom-user-dir)
                 (expand-file-name "lisp/dev" doom-user-dir))))

;; From Lucius
;; Produce backtraces when errors occur: can be helpful to diagnose startup issues
;; (setq debug-on-error t)
(defconst *is-mac* (eq system-type 'darwin))
(defconst *is-linux* (memq system-type '(gnu gnu/linux gnu/kfreebsd berkeley-unix)))
(defconst *golden-ratio* (/ (- (sqrt 5) 1) 2))

;; infrastructure
(require 'init-session)

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
