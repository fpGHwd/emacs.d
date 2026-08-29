;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(defun +wd/italicize-theme-faces ()
  "Italicize comment and keyword faces after theme load."
  (set-face-attribute 'font-lock-comment-face t :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face t :slant 'italic))

(setup doom
  (:hooks doom-load-theme-hook +wd/italicize-theme-faces))

(if (eq system-type 'darwin)
    (setup frame
      (:option mac-frame-tabbing nil)
      (:hooks
       emacs-startup-hook
       (lambda ()
         (run-at-time "0.5 sec" nil #'mac-toggle-frame-fullscreen))
       after-make-frame-functions
       (lambda (_frame)
         (run-at-time "0.5 sec" nil #'mac-toggle-frame-fullscreen))))
  (setup frame
    (:option (prepend default-frame-alist) '(fullscreen . fullboth))))

(setup dirvish
  (:when-loaded
    (:with-map dirvish-mode-map
      (:bind "TAB" dirvish-subtree-toggle))))

(provide 'init-ui)
;;; init-ui.el ends here
