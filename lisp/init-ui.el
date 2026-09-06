;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(defvar dirvish-mode-map)

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
            (set-face-attribute 'font-lock-keyword-face nil :slant 'italic))))

;; Doom Themes reverses these faces, which forms a cycle when Gnus is loaded
;; after the theme on Emacs 31.
(setup gnus
  (custom-set-faces
   '(gnus-group-news-low-empty
     ((t (:inherit gnus-group-mail-1-empty :weight normal)))))
  (:when-loaded
    (face-spec-set 'gnus-group-news-low
                   '((t (:inherit gnus-group-mail-1 :weight bold)))
                   'face-defface-spec)
    (face-spec-set 'gnus-group-news-low-empty
                   '((t (:inherit gnus-group-mail-1-empty :weight normal)))
                   'face-defface-spec)))

(setup frame
  (:when-loaded
    (:setopt (prepend default-frame-alist)
             (if *is-mac*
                 '(fullscreen . fullscreen)
               '(fullscreen . fullboth)))
    (when *is-mac*
      (:setopt mac-frame-tabbing nil))))

(setup dirvish
  (:when-loaded
    (:bind-into dirvish "TAB" dirvish-subtree-toggle)))

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
