;;; ../../Sync/dotfiles/doom.d/lisp/init-ui.el -*- lexical-binding: t; -*-

(require 'seq)

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


;; font guardrails: resolve safe fallbacks and warn for missing preferred fonts
(defconst +wd/preferred-code-font "Fira Code")
(defconst +wd/preferred-cjk-font "Sarasa Gothic SC")
(defconst +wd/preferred-fixed-font "Sarasa Fixed SC")

(defconst +wd/font-download-links
  '(("Fira Code" . "https://github.com/tonsky/FiraCode")
    ("Sarasa Gothic SC" . "https://github.com/be5invis/Sarasa-Gothic")
    ("Sarasa Fixed SC" . "https://github.com/be5invis/Sarasa-Gothic")))

(defun +wd/font-installed-p (family)
  "Return non-nil if FAMILY is available in current Emacs font database."
  (and family
       (or (member family (font-family-list))
           (find-font (font-spec :family family)))))

(defun +wd/first-installed-font (candidates)
  "Return first installed font from CANDIDATES, or nil."
  (seq-find #'+wd/font-installed-p candidates))

(defun +wd/font-install-warning-message (missing)
  "Build a warning message for MISSING fonts."
  (concat
   "Missing preferred fonts detected:\n"
   (mapconcat
    (lambda (name)
      (format "- %s\n  download: %s"
              name
              (or (cdr (assoc name +wd/font-download-links)) "(no link)")))
    missing
    "\n")
   "\nInstall to system font directory, refresh cache (e.g. `fc-cache -fv`), then restart Emacs."))

(defvar +wd/font-warning-shown nil
  "Whether missing preferred font warning has been shown in this session.")

(defun +wd/warn-missing-preferred-fonts ()
  "Warn once when preferred fonts are missing."
  (unless +wd/font-warning-shown
    (let ((missing (seq-filter
                    (lambda (f) (not (+wd/font-installed-p f)))
                    (list +wd/preferred-code-font
                          +wd/preferred-cjk-font
                          +wd/preferred-fixed-font))))
      (when missing
        (setq +wd/font-warning-shown t)
        (display-warning 'init-ui (+wd/font-install-warning-message missing) :warning)))))

(defconst +wd/code-font-family
  (or (+wd/first-installed-font '("Fira Code" "Sarasa Fixed SC" "Sarasa Mono SC" "Noto Sans Mono CJK SC"))
      "Monospace"))

(defconst +wd/cjk-font-family
  (or (+wd/first-installed-font '("Sarasa Gothic SC" "Noto Sans CJK SC" "Noto Sans CJK"))
      "Sans"))

(defconst +wd/fixed-font-family
  (or (+wd/first-installed-font '("Sarasa Fixed SC" "Sarasa Mono SC" "Noto Sans Mono CJK SC"))
      "Monospace"))

;; override doom font setting
(setq doom-font (font-spec :family +wd/code-font-family :weight 'regular :size (if (string= (system-name) "ubuntu2204") 16 15)))
(setq doom-variable-pitch-font (font-spec :family +wd/cjk-font-family :weight 'regular))
;; Keep symbol fallback in a true monospace family for line-drawing tables.
(setq doom-unicode-font (font-spec :family +wd/fixed-font-family))
                                        ;(when (not (featurep :system 'macos))
                                        ;  (setq doom-serif-font (font-spec :family "Noto Serif CJK SC" :weight 'regular)))


(defun +wd/apply-cjk-fontset (&optional frame)
  "Keep CJK fallback stable across daemon and emacsclient frames."
  (with-selected-frame (or frame (selected-frame))
    ;; 如果不把这玩意设置为 nil, 会默认去用 fontset-default 来展示, 配置无效
    (setq use-default-font-for-symbols nil)
    (dolist (charset '(kana han cjk-misc bopomofo))
      (set-fontset-font t charset (font-spec :family +wd/cjk-font-family)))
    ;; Ensure fixed-pitch does not fall back to generic Monospace (which can mismatch glyph metrics).
    (set-face-attribute 'fixed-pitch (or frame (selected-frame)) :family +wd/fixed-font-family)
    ;; Force monospace fallback for line-drawing and arrows used by meow cheatsheet.
    (set-fontset-font t '(#x2500 . #x257F) (font-spec :family +wd/fixed-font-family))
    (set-fontset-font t '(#x2190 . #x21FF) (font-spec :family +wd/fixed-font-family))
    (+wd/warn-missing-preferred-fonts)))

(add-hook! 'after-setting-font-hook #'+wd/apply-cjk-fontset)
(add-hook! 'server-after-make-frame-hook #'+wd/apply-cjk-fontset)


(add-hook! 'doom-load-theme-hook
  (set-face-attribute 'font-lock-comment-face t :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face t :slant 'italic))


(require 'lib-misc)
(when (not *is-mac*)
  (add-to-list 'default-frame-alist '(fullscreen . fullboth)))

;; auto save saved workspaces
;; (add-hook! 'doom-after-init-hook #'(lambda () (run-with-idle-timer 1800 nil #'+wd/update-current-workspaces-to-saved-ones)))
(add-hook! 'doom-after-init-hook #'+wd/workspace-hourly-cleanup-start)

(after! xclip
  (unless (display-graphic-p)
    (when (or (executable-find "xclip")
              (executable-find "xsel")
              (and (executable-find "wl-copy")
                   (executable-find "wl-paste")))
      (xclip-mode 1))))

(provide 'init-ui)
