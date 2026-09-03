;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(setup doom
  (defvar-keymap +wd/leader-map
    :doc "Personal Doom leader commands."
    "r" (cons "Reading via Calibre" #'calibredb)
    "B" (cons "Write a new blog" #'blog-post)
    "Q" (cons "Search org by tags" #'+wd/org-search-by-tags)
    "e" (cons "Elfeed" #'elfeed))

  (:with-map doom-leader-map
    (:bind "z" (cons "melt's-utils" +wd/leader-map)))
  (:hooks doom-load-theme-hook
          (lambda ()
            (set-face-attribute 'font-lock-comment-face nil :slant 'italic)
            (set-face-attribute 'font-lock-keyword-face nil :slant 'italic)))
  (:setopt initial-major-mode 'lisp-interaction-mode))

(setup frame
  (:setopt (prepend default-frame-alist) '(fullscreen . fullboth))
  (when *is-mac*
    (:hooks
     emacs-startup-hook
     (lambda ()
       (run-at-time "0.5 sec" nil #'mac-toggle-frame-fullscreen))
     after-make-frame-functions
     (lambda (_frame)
       (run-at-time "0.5 sec" nil #'mac-toggle-frame-fullscreen)))
    (:setopt mac-frame-tabbing nil)))

(setup dirvish
  (:when-loaded
    (:with-map dirvish-mode-map
      (:bind "TAB" dirvish-subtree-toggle))))

(provide 'init-ui)
;;; init-ui.el ends here
