;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(add-hook! 'doom-load-theme-hook
  (set-face-attribute 'font-lock-comment-face t :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face t :slant 'italic))

(add-to-list 'default-frame-alist '(fullscreen . fullboth))

(setq imenu-auto-rescan t)

(setup dirvish
  (:when-loaded
    (:with-map dirvish-mode-map
      (:bind "TAB" dirvish-subtree-toggle))))

(provide 'init-ui)
;;; init-ui.el ends here
