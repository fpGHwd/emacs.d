;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; Core input and utility packages
(package! rime)
;; (package! sis)  ; disabled: not needed with evil
(package! setup
  :recipe (:host github
           :repo "emacs-straight/setup"
           :branch "master"))

;; Productivity and tooling
;; (package! bing-dict)
;; (package! aidermacs)
;; (package! pine-script-mode)

;; Reading and personal knowledge
(package! nov
  :recipe (:host github
           :repo "wasamasa/nov.el"
           :branch "master"))
(package! mpv)
(package! elfeed-tube-mpv)

(package! calibredb
  :recipe (:host nil
           :type git
           :repo "https://ng.autove.dev/wd/calibredb.el.git"
           :branch "main"
           :local-repo "calibredb.el-gitea"))

;; Org ecosystem
(package! cal-china-x)
;; (package! org-super-agenda)
(package! org-roam-ui
  :recipe (:host github
           :repo "org-roam/org-roam-ui"
           :files ("*.el" "out")))
(package! vulpea)
(package! org-latex-impatient
  :recipe (:host github
           :repo "yangsheng6810/org-latex-impatient"
           :branch "master"))

;; Communication
(package! telega
  :recipe (:host github
           :repo "zevlg/telega.el"
           :branch "master"
           :files (:defaults "etc" "server" "Makefile"))
  :pin "fe91f0d4eed1cc4a6a4df4e69fd69cf98fc1ce65")

;; claude-code emacs integration
(package! claude-code-ide
  :recipe (:host github :repo "manzaltu/claude-code-ide.el"))

;; add android-mode for adb
;; (package! android-mode)

;; github markdown
;; (package! grip-mode)

(package! csv-mode)

;; Code folding with tree-sitter
(package! treesit-fold
  :recipe (:host github :repo "emacs-tree-sitter/treesit-fold"))

(package! emamux)

(package! codex-ide
  :recipe (:host github :repo "dgillis/emacs-codex-ide"))
