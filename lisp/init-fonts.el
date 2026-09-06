;;; init-fonts.el --- Fonts and CJK fontset -*- lexical-binding: t; -*-

(defun +wd/apply-cjk-fontset (&optional frame)
  "Apply configured CJK fonts to FRAME."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (dolist (family (delete-dups
                       (list +wd/code-font +wd/cjk-font +wd/fixed-cjk-font)))
        (unless (find-font (font-spec :family family))
          (error "Required font is not installed: %s" family)))
      ;; 如果不把这玩意设置为 nil, 会默认去用 fontset-default 来展示, 配置无效
      (setq use-default-font-for-symbols nil)
      (dolist (charset '(kana han cjk-misc bopomofo))
        (set-fontset-font t charset (font-spec :family +wd/cjk-font)))
      ;; Ensure fixed-pitch does not fall back to generic Monospace (which can mismatch glyph metrics).
      (set-face-attribute 'fixed-pitch (selected-frame) :family +wd/fixed-cjk-font)
      ;; Force monospace fallback for line-drawing and arrows used by meow cheatsheet.
      (set-fontset-font t '(#x2500 . #x257F) (font-spec :family +wd/fixed-cjk-font))
      (set-fontset-font t '(#x2190 . #x21FF) (font-spec :family +wd/fixed-cjk-font)))))

(setup fonts
  (:setopt
   doom-font (font-spec :family +wd/code-font :weight 'regular :size +wd/font-size)
   doom-variable-pitch-font (font-spec :family +wd/cjk-font :weight 'regular)
   ;; Keep symbol fallback in a true monospace family for line-drawing tables.
   doom-unicode-font (font-spec :family +wd/fixed-cjk-font))
  (:hooks
   after-setting-font-hook +wd/apply-cjk-fontset
   server-after-make-frame-hook +wd/apply-cjk-fontset))

(provide 'init-fonts)
;;; init-fonts.el ends here
