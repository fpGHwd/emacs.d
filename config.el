;;; config.el --- Load wd's configuration -*- lexical-binding: t; -*-

;; Add path
(add-load-path! "lisp/" "lib/")

;; From Lucius
;; Produce backtraces when errors occur: can be helpful to diagnose startup issues
;; (setq debug-on-error t)
;; ignore native compile warning
(setq warning-minimum-level :emergency)
;; Enable with t if you prefer
(defconst *spell-check-support-enabled* nil )
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

;; exec-path - consolidated and de-duplicated
(let ((paths (list "~/.local/bin"
                   (concat (getenv "EMACSDIR") "/bin")
                   "~/.config/emacs/bin")))
  (dolist (p (cl-remove-duplicates (delq nil (mapcar #'expand-file-name paths)) :test #'equal))
    (add-to-list 'exec-path p)))

;; utilities
(if (not *is-mac*) (require 'init-mail))
(require 'init-ledger)
(require 'init-telega)

;; UI
(require 'init-ui)
(require 'init-rime)                    ;; rime font-size = (+1 init-ui)

;; reading
(require 'init-read)

;; writing
;; (require 'init-editing)

;; org-mode
(require 'init-org)
(require 'init-roam)

;; AI
(require 'init-gptel)

(when (or (string= (system-name) "arch-nuc")
          (string= (system-name) "nixos-nuc"))
  (require 'lib-stock))

(require 'init-haskell)

;; others
(require 'init-misc)
;; (require 'init-elfeed)
