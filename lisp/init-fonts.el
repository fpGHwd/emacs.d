;;; init-fonts.el --- Fonts, font constants, and CJK fontset -*- lexical-binding: t; -*-

(require 'seq)

;; Font family constants (depend on *is-mac*/*font-size* defined in config.el).
(defconst *fallback-fonts* '("Fira Code" "Jigmo" "Jigmo2" "Jigmo3"))
(defconst *font-size* (if *is-mac* 14 15))
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
        (display-warning 'init-fonts (+wd/font-install-warning-message missing) :warning)))))

;; override doom font setting
(setq doom-font (font-spec :family +wd/preferred-code-font :weight 'regular :size (if (string= (system-name) "ubuntu2204") 16 15)))
(setq doom-variable-pitch-font (font-spec :family +wd/preferred-cjk-font :weight 'regular))
;; Keep symbol fallback in a true monospace family for line-drawing tables.
(setq doom-unicode-font (font-spec :family +wd/preferred-fixed-font))
                                        ;(when (not (featurep :system 'macos))
                                        ;  (setq doom-serif-font (font-spec :family "Noto Serif CJK SC" :weight 'regular)))

(defun +wd/apply-cjk-fontset (&optional frame)
  "Keep CJK fallback stable across daemon and emacsclient frames."
  (let ((cjk-font (or (and (+wd/font-installed-p +wd/preferred-cjk-font) +wd/preferred-cjk-font)
                      (+wd/first-installed-font '("Noto Sans CJK SC" "Noto Sans CJK"))
                      "Sans"))
        (fixed-font (or (and (+wd/font-installed-p +wd/preferred-fixed-font) +wd/preferred-fixed-font)
                        (+wd/first-installed-font '("Sarasa Mono SC" "Noto Sans Mono CJK SC"))
                        "Monospace")))
  (with-selected-frame (or frame (selected-frame))
    ;; 如果不把这玩意设置为 nil, 会默认去用 fontset-default 来展示, 配置无效
    (setq use-default-font-for-symbols nil)
    (dolist (charset '(kana han cjk-misc bopomofo))
      (set-fontset-font t charset (font-spec :family cjk-font)))
    ;; Ensure fixed-pitch does not fall back to generic Monospace (which can mismatch glyph metrics).
    (set-face-attribute 'fixed-pitch (or frame (selected-frame)) :family fixed-font)
    ;; Force monospace fallback for line-drawing and arrows used by meow cheatsheet.
    (set-fontset-font t '(#x2500 . #x257F) (font-spec :family fixed-font))
    (set-fontset-font t '(#x2190 . #x21FF) (font-spec :family fixed-font))
    (+wd/warn-missing-preferred-fonts))))

(add-hook! 'after-setting-font-hook #'+wd/apply-cjk-fontset)
(add-hook! 'server-after-make-frame-hook #'+wd/apply-cjk-fontset)

(provide 'init-fonts)
;;; init-fonts.el ends here
