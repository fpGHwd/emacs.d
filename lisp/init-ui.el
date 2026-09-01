;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(setup doom
  (:hooks doom-load-theme-hook
          (lambda ()
            (set-face-attribute 'font-lock-comment-face nil :slant 'italic)
            (set-face-attribute 'font-lock-keyword-face nil :slant 'italic))))

(if (eq system-type 'darwin)
    (setup frame
      (:setopt mac-frame-tabbing nil)
      (:hooks
       emacs-startup-hook
       (lambda ()
         (run-at-time "0.5 sec" nil #'mac-toggle-frame-fullscreen))
       after-make-frame-functions
       (lambda (_frame)
         (run-at-time "0.5 sec" nil #'mac-toggle-frame-fullscreen))))
  (setup frame
    (:setopt (prepend default-frame-alist) '(fullscreen . fullboth))))

(setup dirvish
  (:when-loaded
    (:with-map dirvish-mode-map
      (:bind "TAB" dirvish-subtree-toggle))))

(provide 'init-ui)
;;; init-ui.el ends here
