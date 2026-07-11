;;; init-fonts.el --- Fonts and CJK fontset -*- lexical-binding: t; -*-

(defconst +wd/code-font "Fira Code")
(defconst +wd/cjk-font "Sarasa Gothic SC")
(defconst +wd/fixed-cjk-font "Sarasa Fixed SC")
(defconst +wd/font-size (if (string= (system-name) "ubuntu2204") 16 15))

(dolist (family (list +wd/code-font +wd/cjk-font +wd/fixed-cjk-font))
  (unless (find-font (font-spec :family family))
    (error "Required font is not installed: %s" family)))

;; override doom font setting
(setq doom-font (font-spec :family +wd/code-font :weight 'regular :size +wd/font-size))
(setq doom-variable-pitch-font (font-spec :family +wd/cjk-font :weight 'regular))
;; Keep symbol fallback in a true monospace family for line-drawing tables.
(setq doom-unicode-font (font-spec :family +wd/fixed-cjk-font))

(defun +wd/apply-cjk-fontset (&optional frame)
  "Apply configured CJK fonts to FRAME."
  (with-selected-frame (or frame (selected-frame))
    ;; 如果不把这玩意设置为 nil, 会默认去用 fontset-default 来展示, 配置无效
    (setq use-default-font-for-symbols nil)
    (dolist (charset '(kana han cjk-misc bopomofo))
      (set-fontset-font t charset (font-spec :family +wd/cjk-font)))
    ;; Ensure fixed-pitch does not fall back to generic Monospace (which can mismatch glyph metrics).
    (set-face-attribute 'fixed-pitch (or frame (selected-frame)) :family +wd/fixed-cjk-font)
    ;; Force monospace fallback for line-drawing and arrows used by meow cheatsheet.
    (set-fontset-font t '(#x2500 . #x257F) (font-spec :family +wd/fixed-cjk-font))
    (set-fontset-font t '(#x2190 . #x21FF) (font-spec :family +wd/fixed-cjk-font))))

(add-hook! 'after-setting-font-hook #'+wd/apply-cjk-fontset)
(add-hook! 'server-after-make-frame-hook #'+wd/apply-cjk-fontset)

(provide 'init-fonts)
;;; init-fonts.el ends here
