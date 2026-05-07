;;; ../../Sync/dotfiles/doom.d/lisp/init-misc.el -*- lexical-binding: t; -*-

(setq! +workspaces-data-file (concat (system-name) "_workspaces"))


(use-package! bing-dict
  :hook (doom-first-file-hook . (lambda () (require 'bing-dict)))
  :custom
  (bing-dict-vocabulary-save t)
  (bing-dict-vocabulary-file (concat doom-user-dir "/etc/bing-dict/vocabulary.org"))
  :config
  (map! :leader :desc "Search word via Bing Dictionary" "sy" #'bing-dict-brief))


;; keyfreq
(use-package! keyfreq
  :hook (doom-first-buffer-hook . (lambda () (keyfreq-mode 1)))
  :custom
  (keyfreq-autosave-mode 1)
  (keyfreq-file (expand-file-name "emacs.keyfreq" doom-local-dir))
  (keyfreq-file-lock (expand-file-name ".emacs.keyfreq.lock" doom-local-dir))
  (keyfreq-excluded-commands '(self-insert-command
                               forward-char
                               backward-char
                               previous-line
                               next-line
                               evil-next-line
                               evil-previous-line
                               evil-forward-char
                               evil-backward-char
                               evil-next-visual-line
                               evil-previous-visual-line
                               evil-forward-WORD-begin
                               evil-backward-WORD-begin)))

;; leetcode
;; (use-package! leetcode
;;   :defer t
;;   :custom
;;   (leetcode-save-solutions t)
;;   (leetcode-directory (concat  (file-truename "~/Sync/leetcode/") (format-time-string "%Y")))
;;   (leetcode-prefer-language "python3"))


;; org-mobile
;; (use-package! org-mobile
;;   :defer t
;;   :custom
;;   (org-mobile-encryption-password (password-store-get "org/org-mobile"))
;;   (org-mobile-directory "/srv/http/dav/org")
;;   (org-mobile-files '("~/org/2025/todo.org")))


(use-package! auth-source
  :defer t
  :custom
  (auth-source-save-behavior 'ask)
  (auth-sources '("~/.config/doom/etc/authinfo.gpg")))


;; (use-package! ispell
;;   :defer t
;;   :custom
;;   ;; (ispell-extra-args '("--sug-mode=ultra"))
;;   (ispell-dictionary "english")
;;   (ispell-personal-dictionary (concat doom-user-dir "etc/ispell-personal-dictionary"))

;;   :config
;;   (pushnew! ispell-skip-region-alist
;;             '("#\\+begin_src" . "#\\+end_src"))

;;   (advice-add 'ispell-lookup-words :around
;;               (lambda (orig &rest args)
;;                 (shut-up (apply orig args)))))


(use-package! doom-ui
  :init
  (setq initial-scratch-message ";; Happy hacking,  - Emacs loves Melt!\12\12")

  :custom
  ;; (doom-theme 'doom-one)
  ;; (doom-theme 'doom-one-light)
  (initial-scratch-message (concat ";; Happy hacking, " user-full-name " - Emacs ♥ you!\n\n"))
  (fancy-splash-image (file-truename (concat doom-user-dir "assets/2025/bitmap_resized_2.png")))

  (imenu-auto-rescan t)

  (user-full-name "Wang Ding")
  (user-mail-address "ggwdwhu@gmail.com"))


(use-package! wakatime-mode
  :hook (doom-first-file-hook . global-wakatime-mode)
  :custom
  (wakatime-cli-path (or (executable-find "wakatime-cli")
                         (executable-find "wakatime")))
  (wakatime-api-key (password-store-get "wakatime/WAKATIME_API_KEY"))
  (wakatime-disable-on-error t))


;; gif-screencast
;; https://github.com/Ambrevar/emacs-gif-screencast
;; https://blog.3vyd.com/blog/posts-output/2019-12-15-emacs-gif/
(use-package! gif-screencast
  :defer t
  :custom
  (gif-screencast-convert-program (executable-find "magick"))
  (gif-screencast-convert-args '("convert" "-delay" "10" "-loop" "0"))
  (gif-screencast-args '("-x")) ;; To shut up the shutter sound of `screencapture' (see `gif-screencast-command').
  (gif-screencast-cropping-program "mogrify") ;; Optional: Used to crop the capture to the Emacs frame.
  (gif-screencast-capture-format "ppm")
  :config
  (with-eval-after-load 'gif-screencast
    (define-key gif-screencast-mode-map (kbd "<f8>") 'gif-screencast-toggle-pause)
    (define-key gif-screencast-mode-map (kbd "<f9>") 'gif-screencast-stop))

  (when (string= system-name "macbook-m1-pro")
    (advice-add ;; 适配mac自带的视网膜屏幕
     #'gif-screencast--cropping-region
     :around
     (lambda (oldfun &rest r)
       (apply #'format "%dx%d+%d+%d"
              (mapcar
               (lambda (x) (* 2 (string-to-number x)))
               (split-string (apply oldfun r) "[+x]")))))))


(use-package! vterm
  :defer t
  :custom
  (vterm-shell (let ((zsh-path (executable-find "zsh")))
                 (if zsh-path
                     zsh-path
                   (executable-find "bash"))))
  (vterm-tramp-shells '(("sshx" login-shell "/bin/zsh" "/bin/bash")
                        ("ssh" login-shell "/bin/zsh" "/bin/bash")
                        ("scp" login-shell "/bin/zsh" "/bin/bash")
                        ("docker" "/bin/zsh" "/bin/bash" "/bin/sh"))))


(use-package! magit-clone
  :defer t
  :custom
  (magit-clone-default-directory (concat (file-truename "~/projects/github/current") "/")))


(use-package! recentf
  :hook (doom-first-file-hook . recentf-mode)
  :config
  (setq recentf-max-saved-items 5000))


(use-package! eldoc
  :defer t
  :custom
  (eldoc-idle-delay 2))


;; (toggle-debug-on-error)  ;; you can do this everywhere
(when (string= (system-name) "ubuntu2204")
  (after! doom
    (add-to-list '+lookup-provider-url-alist
                 '("Bing" "https://cn.bing.com/search?go=Search&q=%s&qs=ds&form=QBRE"))))

(after! doom
  (add-to-list '+lookup-provider-url-alist
               '("NixOS Package Search" "https://search.nixos.org/packages?channel=25.11&query=%s")))

(setup haskell-mode
  (:hook org-mode (lambda ()
                    (org-babel-do-load-languages 'org-babel-load-languages '((haskell . t))))))

;; (setq mac-command-modifier 'meta)

;; (after! spell-fu
;;   (setq spell-fu-idle-delay 30))  ; default is 0.25

;; (after! flyspell
;;   (setq flyspell-lazy-idle-seconds 30))

;; (after! ein
;;   (let* ((urls '(https://jupyter.autove.dev"))
;;          (urls-new (when (not (string= "ubuntu2204" (system-name)))
;;                  (append '("http://nixos-nuc.local:8888") urls))))
;;     (setq ein:urls urls-new
;;           ein:jupyter-default-notebook-directory "/home/wd/Sync/projects/2025/hikyuu"
;;           ein:jupyter-server-use-subcommand "server")))

;; after! 本质就是 eval-after-load, 也是 with-eval-after-load
;; (after! gdb-mi
;;   (setq! gdb-debuginfod-enable nil))


(setq source-directory (pcase (system-name)
                         ("macbook-m1-pro" "/sshx:wd@nixos-nuc.local:~/projects/github/2024/emacs/src")
                         ("ubuntu2204"  "~/github/2024/emacs/src")
                         (_ "~/projects/github/2024/emacs/src")))

(use-package! find-func
  :custom
  (find-function-C-source-directory source-directory))

;; https://github.com/karthink/elfeed-tube?tab=readme-ov-file#step-i-add-youtube-subscriptions-to-elfeed
;; (use-package elfeed-tube
;;   ;; :ensure t ;; or :straight t
;;   :after elfeed
;;   :demand t
;;   :config
;;   ;; (setq elfeed-tube-auto-save-p nil) ; default value
;;   ;; (setq elfeed-tube-auto-fetch-p t)  ; default value
;;   (elfeed-tube-setup)

;;   :bind (:map elfeed-show-mode-map
;;          ("F" . elfeed-tube-fetch)
;;          ([remap save-buffer] . elfeed-tube-save)
;;          :map elfeed-search-mode-map
;;          ("F" . elfeed-tube-fetch)
;;          ([remap save-buffer] . elfeed-tube-save)))

;; (remove-hook! 'before-save-hook 'lsp--format-buffer-on-save)

(setup magit
  (:also-load lib-magit))

;; (setup meow
;;   :config
;;   (setq blink-cursor-interval 0.61)
;;   (add-hook 'org-capture-mode-hook #'meow-insert)
;;   ;; (add-hook 'git-commit-mode-hook #'meow-insert)
;;   ;; (add-hook 'vterm-mode-hook #'meow-insert) # vterm-mode-hook not used
;;   )


;; (setup pdf-view
;;   (:hook pdf-view-mode #'toggle-frame-fullscreen)) ;; failed

(use-package! pine-script-mode)

;; setup myself lib to auto backup .zshrc to /mnt/data/.zshrc every day at midnight
(setup lib-save-and-restore-softlinks-in-nixos
  (:with-function auto-backup-zshrc-to-mnt (:autoload-this))
  (:with-function +wd/remove-deprecated-files (:autoload-this))
  (progn
    (defvar my/foo-timer nil
      "Timer for my foo task.")
    (when (string= (system-name) "nixos-nuc")
      (when (not (string= (system-name) "ubuntu2204"))
        (unless (timerp my/foo-timer)
          (setq my/foo-timer (run-at-time "00:00" (* 24 60 60) #'auto-backup-zshrc-to-mnt)))))
    (when (string= (system-name) "ubuntu2204")
      (run-at-time "00:00" (* 24 60 60) '+wd/remove-deprecated-files "args"))))


;; add for some tramp/vterm connection, LSP json-rpc session
(setq envrc-remote 1)

;; LSP over TRAMP (ssh://nixos-nuc):
;; Prefer remote-resolvable JSON LS commands instead of local absolute npm paths.
(after! tramp
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path)
  (dolist (p '("~/.nix-profile/bin" "/etc/profiles/per-user/wd/bin" "/run/current-system/sw/bin"))
    (add-to-list 'tramp-remote-path p)))

(after! lsp-mode
  (defvar +wd/json-ls-remote-candidates
    '("json-language-server"
      "json-languageserver"
      "vscode-json-language-server"
      "vscode-json-languageserver")
    "Candidate executables for JSON language server on remote hosts.")

  (defun +wd/tramp-json-ls-executable ()
    "Return remote JSON language server executable, or nil if unavailable."
    (when (file-remote-p default-directory)
      (cl-loop for exe in +wd/json-ls-remote-candidates
               when (eq 0 (process-file "sh" nil nil nil "-lc"
                                        (format "command -v %s >/dev/null 2>&1" exe)))
               return exe)))

  (defun +wd/maybe-disable-json-ls-on-tramp ()
    "Disable json-ls in remote JSON buffers when no server command exists."
    (when (and (file-remote-p default-directory)
               (null (+wd/tramp-json-ls-executable)))
      (setq-local lsp-disabled-clients
                  (cl-adjoin 'json-ls lsp-disabled-clients :test #'eq))
      (message "Remote json-ls disabled: install vscode-json-language-server on remote host.")))

  (defun +wd/lsp-json-use-remote-command-a (orig-fn pkg)
    "Advice ORIG-FN to return remote JSON LS command for PKG over TRAMP."
    (if (and (eq pkg 'vscode-json-languageserver)
             (file-remote-p default-directory))
        (or (+wd/tramp-json-ls-executable) (funcall orig-fn pkg))
      (funcall orig-fn pkg)))

  (advice-add 'lsp-package-path :around #'+wd/lsp-json-use-remote-command-a)
  ;; Doom with +tree-sitter uses `json-ts-mode`, so guard both mode hooks.
  (add-hook 'json-mode-hook #'+wd/maybe-disable-json-ls-on-tramp)
  (add-hook 'json-ts-mode-hook #'+wd/maybe-disable-json-ls-on-tramp))

(provide 'init-misc)
;;; init-misc.el ends here
