;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(require 'solar)

(defvar dirvish-mode-map)
(defvar +wd/solar-theme-timer nil)

(defun +wd/solar-theme--properties (theme)
  "Return Doom theme properties for THEME."
  (unless (custom-theme-p theme)
    (load-theme theme t t))
  (get theme 'theme-properties))

(defun +wd/solar-theme--candidates (theme background-mode)
  "Return likely counterparts for THEME with BACKGROUND-MODE."
  (let* ((name (symbol-name theme))
         (names (pcase background-mode
                  ('light '(("light" . "dark")
                            ("day" . "night")
                            ("white" . "black")))
                  ('dark '(("dark" . "light")
                           ("night" . "day")
                           ("black" . "white")))))
         (match
          (seq-find
           (lambda (pair)
             (string-match (format "-%s\\(?:-.*\\)?\\'" (car pair)) name))
           names))
         (base (and match (substring name 0 (match-beginning 0)))))
    (delete-dups
     (append (and match
                  (list (intern (concat base "-" (cdr match))) (intern base)))
             (list (intern (concat name
                                   (if (eq background-mode 'light)
                                       "-dark"
                                     "-light"))))))))

(defun +wd/solar-theme--pair (theme)
  "Return the (LIGHT . DARK) pair containing THEME."
  (let* ((properties (+wd/solar-theme--properties theme))
         (mode (plist-get properties :background-mode))
         (family (plist-get properties :family)))
    (unless (and family (memq mode '(light dark)))
      (error "Theme %S lacks Doom family or background-mode metadata" theme))
    (let* ((target-mode (if (eq mode 'light) 'dark 'light))
           (available (custom-available-themes))
           (counterpart
            (seq-find
             (lambda (candidate)
               (and (memq candidate available)
                    (let ((candidate-properties
                           (+wd/solar-theme--properties candidate)))
                      (and (eq (plist-get candidate-properties :family) family)
                           (eq (plist-get candidate-properties :background-mode)
                               target-mode)))))
             (+wd/solar-theme--candidates theme mode))))
      (unless counterpart
        (error "Cannot infer an installed light/dark counterpart for theme %S"
               theme))
      (if (eq mode 'light)
          (cons theme counterpart)
        (cons counterpart theme)))))

(defun +wd/solar-theme--times (date)
  "Return sunrise and sunset times for Gregorian DATE."
  (let* ((calendar-latitude +wd/latitude)
         (calendar-longitude +wd/longitude)
         (solar-times (solar-sunrise-sunset date))
         (sunrise-hour (car (nth 0 solar-times)))
         (sunset-hour (car (nth 1 solar-times))))
    (unless (and (numberp sunrise-hour) (numberp sunset-hour))
      (error "Cannot calculate sunrise and sunset for %S" date))
    (let ((midnight (encode-time 0 0 0
                                 (nth 1 date) (nth 0 date) (nth 2 date))))
      (cons (time-add midnight
                      (seconds-to-time (round (* sunrise-hour 3600))))
            (time-add midnight
                      (seconds-to-time (round (* sunset-hour 3600))))))))

(defun +wd/solar-theme--load (theme)
  "Replace the active themes with THEME."
  (setq-default doom-theme theme)
  (unless (equal custom-enabled-themes (list theme))
    (mapc #'disable-theme custom-enabled-themes)
    (load-theme theme t)))

(defun +wd/solar-theme-schedule ()
  "Select a theme for the current solar period and schedule the next change."
  (interactive)
  (when (timerp +wd/solar-theme-timer)
    (cancel-timer +wd/solar-theme-timer))
  (setq +wd/solar-theme-timer nil)
  (let* ((now (current-time))
         (today (calendar-current-date))
         (today-times (+wd/solar-theme--times today))
         (sunrise (car today-times))
         (sunset (cdr today-times))
         (active-theme
          (or (seq-find #'doom--theme-is-colorscheme-p custom-enabled-themes)
              (and (symbolp doom-theme) doom-theme)
              (error "No active Doom theme from which to infer a pair")))
         (theme-pair (+wd/solar-theme--pair active-theme))
         (daytime (and (not (time-less-p now sunrise))
                       (time-less-p now sunset)))
         (theme (if daytime (car theme-pair) (cdr theme-pair)))
         (next-change
          (cond
           ((time-less-p now sunrise) sunrise)
           ((time-less-p now sunset) sunset)
           (t
            (let ((tomorrow
                   (calendar-gregorian-from-absolute
                    (1+ (calendar-absolute-from-gregorian today)))))
              (car (+wd/solar-theme--times tomorrow)))))))
    (+wd/solar-theme--load theme)
    (setq +wd/solar-theme-timer
          (run-at-time (time-convert next-change 'list)
                       nil #'+wd/solar-theme-schedule))
    (message "Solar theme %s; next change at %s"
             theme (format-time-string "%Y-%m-%d %H:%M" next-change))))

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

(+wd/solar-theme-schedule)

(provide 'init-ui)
;;; init-ui.el ends here
