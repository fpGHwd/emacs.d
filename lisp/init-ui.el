;;; ../../Sync/dotfiles/doom.d/lisp/init-ui.el -*- lexical-binding: t; -*-

; set fonts
;; (add-hook! 'after-setting-font-hook
;;   (lambda ()
;;     (when window-system
;;       (setup faces
;;         (:also-load lib-face)
;;         (configure-ligatures)
;;         (:hooks window-setup-hook +setup-fonts
;;                 server-after-make-frame-hook +setup-fonts
;;                 default-text-scale-mode-hook +setup-fonts)
;;         (when doom--system-macos-p
;;           (:with-mode (vterm-mode eshell-mode) (:set-font *term-default-font*))
;;           (:with-mode (latex-mode prog-mode nxml-mode magit-status-mode magit-diff-mode diff-mode) (:set-font *prog-font*))
;;           (:with-mode nov-mode (:set-font (replace-regexp-in-string "13" "16" *default-font*)))
;;           (:with-mode dired-mode (:set-font *org-font*))
;;           (:with-mode (org-mode ebib-index-mode ebib-entry-mode) (:set-font *org-font*)))
;;         (:advice face-at-point :around #'+suggest-other-faces)))))


;; override doom font setting
(setq doom-font (font-spec :family "Fira Code" :weight 'regular :size (if (string= (system-name) "ubuntu2204") 16 15)))
(setq doom-variable-pitch-font (font-spec :family "Sarasa Gothic SC" :weight 'regular))
                                        ;(when (not (featurep :system 'macos))
                                        ;  (setq doom-serif-font (font-spec :family "Noto Serif CJK SC" :weight 'regular)))


(add-hook!
 'after-setting-font-hook
 #'(lambda ()
     ;; 如果不把这玩意设置为 nil, 会默认去用 fontset-default 来展示, 配置无效
     (setq use-default-font-for-symbols nil)
     (dolist (charset '(kana han cjk-misc bopomofo))
       (set-fontset-font t charset (font-spec :family "Sarasa Gothic SC")))))


(add-hook! 'doom-load-theme-hook
  (set-face-attribute 'font-lock-comment-face t :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face t :slant 'italic))


(require 'lib-misc)
(when (not *is-mac*)
  (add-to-list 'default-frame-alist '(fullscreen . fullboth)))

;; auto save saved workspaces
(add-hook! 'doom-after-init-hook #'(lambda () (run-with-idle-timer 1800 nil #'+wd/update-current-workspaces-to-saved-ones)))
(add-hook! 'doom-after-init-hook #'+wd/workspace-hourly-cleanup-start)

(after! xclip
  (unless (display-graphic-p)
    (when (or (executable-find "xclip")
              (executable-find "xsel")
              (and (executable-find "wl-copy")
                   (executable-find "wl-paste")))
      (xclip-mode 1))))

(provide 'init-ui)
