;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(add-hook! 'doom-load-theme-hook
  (set-face-attribute 'font-lock-comment-face t :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face t :slant 'italic))

(if (eq system-type 'darwin)
    (progn
      (setq mac-frame-tabbing nil)
      (add-hook 'emacs-startup-hook
                (lambda ()
                  (run-at-time "0.5 sec" nil #'mac-toggle-frame-fullscreen)))
      (add-hook 'after-make-frame-functions
                (lambda (_frame)
                  (run-at-time "0.5 sec" nil #'mac-toggle-frame-fullscreen))))
  (add-to-list 'default-frame-alist '(fullscreen . fullboth)))

(setq imenu-auto-rescan t)

(setup dirvish
  (:when-loaded
    (:with-map dirvish-mode-map
      (:bind "TAB" dirvish-subtree-toggle))))

(provide 'init-ui)
;;; init-ui.el ends here
