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

;; identity
(setup emacs
  (:setopt
   user-full-name "Wang Ding"
   user-mail-address "ggwdwhu@gmail.com"
   initial-scratch-message
   (concat ";; Happy hacking, " user-full-name " - Emacs ♥ you!\n\n")))


(setup auth-source
  (:setopt auth-sources (list (expand-file-name "etc/authinfo.gpg" doom-user-dir))))

(setup recentf
  (:when-loaded ;; use `:when-loaded` to override doom's configuration
    (:setopt recentf-max-saved-items 2000)))

(setup uniquify
  (:also-load persp-mode)
  (:when-loaded
    (:setopt uniquify-buffer-name-style 'forward
             uniquify-separator "/")
    ;; override persp config uniquify and set priority
    (:hooks persp-mode-hook
            (:hook-options
             (lambda ()
               (setq uniquify-buffer-name-style 'forward
                     uniquify-separator "/"))
             :depth t))))

(provide 'init-ui)
;;; init-ui.el ends here
