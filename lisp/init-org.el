;;; init-org.el --- Org-mode core configuration -*- lexical-binding: t; -*-

(setq org-directory "~/org/org/current")
(setq +wd/seven-year-life 7) ;; 七年一生

(add-hook! 'org-mode-hook (flycheck-mode -1))

(setup org
  (:also-load lib-org uniquify)

  (:hooks
   org-mode-hook mixed-pitch-mode
   org-mode-hook (lambda ()
                   (setq org-agenda-start-day "-1d"
                         org-agenda-span 4))
   org-mode-hook (lambda () (when (org-property-values "GPTEL_SYSTEM")
                              (progn (gptel-mode)
                                     (rename-buffer (concat "ChatGPT/GPTel:" (buffer-name)))))))

  (:option
   ;; https://emacs-china.org/t/topic/1551/15
   system-time-locale "C"
   org-log-done 'time
   org-archive-location "~/org/org/current/archive.org.bak::* From %s"
   org-id-locations-file (expand-file-name "org-id-locations" doom-cache-dir)
   org-crypt-key "ggwdwhu@gmail.com"
   org-image-actual-width 600
   org-deadline-warning-days 7
   org-format-latex-options
   '(:foreground auto :background default :scale 1.5 :html-foreground "Black"
     :html-background "Transparent" :html-scale 1.0 :matchers
     ("begin" "$1" "$" "$$" "\\(" "\\["))
   org-journal-dir "~/org/journal"
   ;; org-journal-enable-agenda-integration t  ;; not use now
   rmh-elfeed-org-files '("~/org/elfeed/elfeed.org")
   ;; agenda
   org-agenda-diary-file (expand-file-name "etc/diary" doom-user-dir)
   diary-file (expand-file-name "etc/diary" doom-user-dir)
   org-agenda-include-diary t
   org-agenda-files (let ((year-number (string-to-number (format-time-string "%Y")))
                          (files '("~/org/beorg/")))
                      (dotimes (offset (1+ +wd/seven-year-life))
                        (let ((year-str (number-to-string (- year-number offset))))
                          (push (concat "~/org/org/" year-str) files)
                          (push (concat "~/org/noter/" year-str) files)))
                      files)
   org-agenda-show-inherited-tags 'always
   org-agenda-sorting-strategy
   '((agenda habit-down time-up urgency-down category-keep)
     (todo urgency-down category-keep)
     (tags urgency-down timestamp-down category-keep) (search alpha-up))
   org-refile-targets '((nil :maxlevel . 1) (org-agenda-files :maxlevel . 1))
   org-timer-default-timer 25)

  (:with-feature org-attach
    (:option
     org-attach-id-dir (file-truename "~/.local/org-attach")
     org-attach-sync-delete-empty-dir t))

  (:with-feature calendar
    (:option
     calendar-mark-diary-entries-flag t
     calendar-week-start-day 1
     calendar-latitude 31.108024
     calendar-longitude 121.372327))

  (:with-feature cal-china-x
    (:when-loaded
      (setq mark-holidays-in-calendar t)
      (setq cal-china-x-important-holidays cal-china-x-chinese-holidays)
      (setq cal-china-x-general-holidays '((holiday-lunar 1 15 "元宵节")))
      (setq calendar-holidays
            (append cal-china-x-important-holidays
                    cal-china-x-general-holidays))))

  (:with-feature ox-publish
    (:option
     org-publish-project-alist
     '(("org-blog"
        :base-directory "~/org/blog/current/posts/"
        :base-extension "org"
        :publishing-directory "~/org/blog/current/outputs/"
        :recursive t
        :publishing-function org-md-publish-to-md
        :publishing-extension "markdown"
        :headline-levels 4
        :body-only t)))
    (:when-loaded
      (add-hook 'org-export-before-processing-hook #'my/org-insert-updated-timestamp)
      (add-hook 'org-publish-after-publishing-hook #'+wd/handle-image-in-markdown)
      (add-to-list 'file-coding-system-alist '("\\.bib" . utf-8))))

  (:with-feature so-long
    (:when-loaded
      (add-to-list 'doom-file-lines-threshold-alist
                   '("\\.org\\'" . 50000))))

  (:when-loaded
    (:after meow
      (add-hook 'org-capture-mode-hook #'meow-insert-mode))
    (add-hook 'org-capture-mode-hook (lambda () (eldoc-mode -1)))

    (add-to-list 'org-tags-exclude-from-inheritance "roam-agenda")
    (add-to-list 'org-file-apps '("\\.drawio\\'" . "/opt/drawio/drawio %s"))
    (add-to-list 'org-file-apps '("\\.minder\\'" . "/usr/bin/minder %s"))


    (org-babel-do-load-languages
     'org-babel-load-languages
     '((jupyter . t)
       (gnuplot . t)
       (plantuml . t)
       (haskell . t)
       (makefile . t)))
    (setq org-babel-haskell-command "ghci")

    (when (not (string= (system-name) "ubuntu2204"))
      (add-hook 'org-after-note-stored-hook #'+wd/org-count-total-update))

    (org-toggle-sticky-agenda 1)

    (:face org-block ((t (:inherit fixed-pitch))))
    (:face org-code ((t (:inherit (shadow fixed-pitch)))))
    (:face org-document-info ((t (:foreground "dark orange"))))
    (:face org-document-info-keyword ((t (:inherit (shadow fixed-pitch)))))
    (:face org-indent ((t (:inherit (org-hide fixed-pitch)))))
    (:face org-link ((t (:foreground "royal blue" :underline t))))
    (:face org-meta-line ((t (:inherit (font-lock-comment-face fixed-pitch)))))
    (:face org-property-value ((t (:inherit fixed-pitch))))
    (:face org-special-keyword ((t (:inherit (font-lock-comment-face fixed-pitch)))))
    (:face org-table ((t (:inherit fixed-pitch :foreground "#83a598"))))
    (:face org-tag ((t (:inherit (shadow fixed-pitch) :weight bold :height 0.8))))
    (:face org-verbatim ((t (:inherit (shadow fixed-pitch)))))

    ;; emacsclient "org-protocol://capture?template=mc&title=title2 :tag:&body=ok"
    (defvar +wd/org-capture-file-for-ios (expand-file-name "notes_ios.org" org-directory))
    (defvar +wd/scheduled-capture-args nil
      "Plist holding :title, :scheduled, :body for the `cs' capture template.
Set before calling `org-capture' with template key `cs'.")
    (add-to-list 'org-capture-templates '("c" "Capture for external app or command"))
    (add-to-list 'org-capture-templates
                 '("cn" "Capture Notes" entry (file+headline +org-capture-notes-file "Inbox")
                   "* %u %:description\n%:initial\n" :immediate-finish t :prepend t))
    (add-to-list 'org-capture-templates
                 '("ci" "Capture Bunch of Notes from iOS" entry (file+headline +wd/org-capture-file-for-ios "Inbox for iOS")
                   "* %:description\n%:initial\n" :immediate-finish t :prepend t))
    (add-to-list 'org-capture-templates
                 '("ct" "Capture Todo" entry (file+headline +org-capture-todo-file "Inbox")
                   "* [ ] %:description\n%:initial\n" :immediate-finish t :prepend t))
    (add-to-list 'org-capture-templates
                 '("cj" "Capture Journal" entry (file+olp+datetree +org-capture-journal-file)
                   "* %U %:description\n%:initial\n" :immediate-finish t :prepend t))
    (add-to-list 'org-capture-templates
                 '("cs" "Scheduled Capture" entry (file+headline +org-capture-todo-file "Inbox")
                   "* %u %(or (plist-get +wd/scheduled-capture-args :title) \"无标题\")\nSCHEDULED: %(plist-get +wd/scheduled-capture-args :scheduled)\n%(or (plist-get +wd/scheduled-capture-args :body) \"\")"
                   :immediate-finish t :prepend t))

    ;; Default org-read-date to current time (not 00:00) when timestamp has no time component.
    (advice-add 'org-read-date :around #'+wd/org-read-date-default-current-time)
    (add-hook 'kill-emacs-hook #'+wd/org-agenda-work-mode-cleanup-roam-link)
    (load "~/projects/2026/haskell-web/scripts/lib-org-capture.el" t)
    (:bind-into dired "C-c C-x a" #'org-attach-dired-to-subtree)
    (:with-feature org-latex-impatient
      (:hooks org-mode-hook org-latex-impatient-mode)
      (:option
       max-image-size nil
       org-latex-impatient-border-color "#666699"
       org-latex-impatient-tex2svg-bin (executable-find "tex2svg")))
    (map! :map org-mode-map
          :localleader
          :desc "Insert a item"       "i" #'org-insert-item
          :desc "Copy org link"      "y" #'+wd/org-link-copy
          :desc "Toggle narrow to subtree" "N" #'org-toggle-narrow-to-subtree)))


(provide 'init-org)
;;; init-org.el ends here
