;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(setup doom
  (:hooks doom-load-theme-hook
          (lambda ()
            (set-face-attribute 'font-lock-comment-face t :slant 'italic) ;; keyword need not to be italic
            ;; gnus-group-news-low-empty → gnus-group-news-low → gnus-group-news-low-empty
            ;; cycle breaks `make-frame' in Emacs 31
            (set-face-attribute 'gnus-group-news-low-empty t :inherit nil))))

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
