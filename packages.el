;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; To install a package with Doom you must declare them here and run 'doom sync'
;; on the command line, then restart Emacs for the changes to take effect -- or
;; use 'M-x doom/reload'.


;; To install SOME-PACKAGE from MELPA, ELPA or emacsmirror:
                                        ;(package! some-package)
                                        ;
;; (package! helm-spotify-plus)
(package! rime)
(package! cal-china-x)
(package! bing-dict)
;; (package! leetcode)

;; To install a package directly from a remote git repo, you must specify a
;; `:recipe'. You'll find documentation on what `:recipe' accepts here:
;; https://github.com/raxod502/straight.el#the-recipe-format
                                        ;(package! another-package
                                        ;  :recipe (:host github :repo "username/repo"))

(package! telega
  :recipe (:host github
           :repo "zevlg/telega.el"
           :branch "master"
           :files (:defaults "etc" "server" "Makefile"))
  ;; :pin "66e83c8674042d47bf2cada05192f3d0b7e967a1"
  :pin "fe91f0d4eed1cc4a6a4df4e69fd69cf98fc1ce65"
  )

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe':
                                        ;(package! this-package
                                        ;  :recipe (:host github :repo "username/repo"
                                        ;           :files ("some-file.el" "src/lisp/*.el")))

;; If you'd like to disable a package included with Doom, you can do so here
;; with the `:disable' property:
                                        ;(package! builtin-package :disable t)

;; You can override the recipe of a built in package without having to specify
;; all the properties for `:recipe'. These will inherit the rest of its recipe
;; from Doom or MELPA/ELPA/Emacsmirror:
                                        ;(package! builtin-package :recipe (:nonrecursive t))
                                        ;(package! builtin-package-2 :recipe (:repo "myfork/package"))

;; Specify a `:branch' to install a package from a particular branch or tag.
;; This is required for some packages whose default branch isn't 'master' (which
;; our package manager can't deal with; see raxod502/straight.el#279)
                                        ;(package! builtin-package :recipe (:branch "develop"))

;; Use `:pin' to specify a particular commit to install.
                                        ;(package! builtin-package :pin "1a2b3c4d5e")


;; Doom's packages are pinned to a specific commit and updated from release to
;; release. The `unpin!' macro allows you to unpin single packages...
                                        ;(unpin! pinned-package)
;; ...or multiple packages
                                        ;(unpin! pinned-package another-pinned-package)
;; ...Or *all* packages (NOT RECOMMENDED; will likely break things)
                                        ;(unpin! t)


;; (package! use-proxy)

;; https://github.com/casouri/valign
;; (package! valign)

(progn
  (package! websocket)
  (package! org-roam-ui :recipe (:host github :repo "org-roam/org-roam-ui" :files ("*.el" "out"))))


(package! keyfreq)

;; (package! meow)
;; (package! sis)

(package! wakatime-mode)

;; (package! simple-httpd)

;; (package! zotxt-emacs
;;   :recipe (:host github
;;            :repo "egh/zotxt-emacs")
;;   :pin "d344e7ac281a083f4e39e95b5664633a015e2b3b")

;; (package! lsp-bridge
;;   :recipe (:host github
;;            :repo "manateelazycat/lsp-bridge"
;;            :files (:defaults "acm" "core" "langserver" "multiserver" "resources" "test" "lsp_bridge.py")))

(package! org-super-agenda)

;; install nethack
;; (package! nethack)

;; https://github.com/doomemacs/doomemacs/issues/7078#issuecomment-1428775097
                                        ; (package! transient :pin "c2bdf7e12c530eb85476d3aef317eb2941ab9440")
                                        ; (package! with-editor :pin "391e76a256aeec6b9e4cbd733088f30c677d965b")

;; (package! epc)

;; (package! aio)

;; https://github.com/NicolasPetton/Indium
;; (package! Indium
;;   :recipe (:host github
;;            :repo "NicolasPetton/Indium"
;;            :branch "master"
;;            :files (:defaults "doc" "img" "screenshots" "server" "sphinx-doc" "test"))
;;   :pin "8499e156bf7286846c3a2bf8c9e0c4d4f24b224c")

(package! vulpea)

;; epub reading plugin
(package! nov
  ;; https://github.com/wasamasa/nov.el
  :recipe (:host github
           :repo "wasamasa/nov.el"
           :branch "master"))

;; (package! tikz
;;   ;; https://github.com/wasamasa/nov.el
;;   :recipe (:host github
;;            :repo "emiliotorres/tikz"
;;            :branch "master"))

;; (package! gptel)

;; (package! whisper
;;   ;; https://github.com/wasamasa/nov.el
;;   :recipe (:host github
;;            :repo "natrys/whisper.el"
;;            :branch "master"))

;; add org-tree-slide
;; (package! org-tree-slide
;;   :recipe (:host github
;;            :repo "takaxp/org-tree-slide"
;;            :branch "master"))

;; add ejira: https://github.com/nyyManni/ejira
;; (package! ejira
;;   :recipe (:host github
;;            :repo "nyyManni/ejira"
;;            :branch "master"))

;; add elpy
;; (package! elpy)

(package! pine-script-mode)

;; (package! gif-screencast)

;; (package! org-pomodoro)


;; (package! auto-dim-other-buffers
;;   :recipe (:host github
;;            :repo "mina86/auto-dim-other-buffers.el"
;;            :branch "master"))

;; (package! goggles)
;; (package! indium)

(package! calibredb)

;; (package! sqlite3)

(package! aidermacs)

;; (package! emacs-syncthing.el)

;; (package! org-include-inline
;;   ;; https://github.com/wasamasa/nov.el
;;   :recipe (:host github
;;            :repo "yibie/org-include-inline"
;;            :branch "main"))

;; (package! realgud
;;   :recipe (:host github
;;            :repo "realgud/realgud"
;;            :branch "master"))

(package! org-latex-impatient
  :recipe (:host github
           :repo "yangsheng6810/org-latex-impatient"
           :branch "master"))

;; (package! org-ref)

;; (package! ein)

;; pcap
;; (package! pcap-mode
;;   :recipe (:host github
;;            :repo "apconole/pcap-mode"
;;            :branch "master"))

(package! setup
  :recipe (:host github
           :repo "emacs-straight/setup"
           :branch "master"))

;; (package! elfeed-tube)
;; (package! elfeed-tube-mpv)

;; (package! emt
;;   :recipe (:host github
;;            :repo "roife/emt"
;;            :branch "master"))

;; (package! ebib
;;   :recipe (:host github
;;            :repo "joostkremers/ebib"
;;            :branch "master"))

;; (package! meow-tree-sitter)

