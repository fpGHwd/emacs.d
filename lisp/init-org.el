;;; init-org.el --- Org-mode core configuration -*- lexical-binding: t; -*-

(setq org-directory (file-truename "~/org/org/current"))

(setup org
  (keymap-global-set "C-c i" #'org-insert-item)
  ;; (org-mode-hook . (lambda () (company-mode -1)))
  (:hooks
   org-mode-hook auto-revert-mode
   org-mode-hook variable-pitch-mode
   org-mode-hook (lambda () (when (org-property-values "GPTEL_SYSTEM")
                              (progn (gptel-mode)
                                     (rename-buffer (concat "ChatGPT/GPTel:" (buffer-name)))))))
  (:when-loaded
    (:also-load lib-org)
    (:option
     ;; week display in org-mode
     ;; https://emacs-china.org/t/topic/1551/15
     ;; https://stackoverflow.com/questions/28913294/emacs-org-mode-language-of-time-stamps
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
     rmh-elfeed-org-files '("~/org/elfeed/elfeed.org"))
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

    ;; Load `+wd/org-count-total-update' from the `count-fn' block in
    ;; habit.org, then refresh COUNT_* after each stored log note (e.g. the
    ;; count note added on TODO DONE).
    (let ((org-confirm-babel-evaluate nil))
      (with-current-buffer (find-file-noselect "~/org/beorg/habit.org")
        (org-babel-goto-named-src-block "count-fn")
        (org-babel-execute-src-block)))
    (add-hook 'org-after-note-stored-hook #'+wd/org-count-total-update)))


(setup org-attach
  (:when-loaded
    (:option
     org-attach-directory (file-truename "~/.local/org-attach")
     org-attach-id-dir (file-truename "~/.local/org-attach"))))


(setup dired
  (:hooks dired-mode-hook (lambda () (define-key dired-mode-map (kbd "C-c C-x a")
                                                 #'org-attach-dired-to-subtree))))


(setup deft
  (:when-loaded
    (:option deft-directory "~/org/deft")))

(setup ox-publish
  (:when-loaded
    (:also-load lib-org)
    (:option
     org-publish-project-alist
     '(("org-blog"
        ;; Path to your org files.
        :base-directory "~/org/blog/current/posts/"
        :base-extension "org"
        ;; Path to your Jekyll project.
        :publishing-directory "~/org/blog/current/outputs/"
        :recursive t
        :publishing-function org-md-publish-to-md
        :publishing-extension "markdown"
        :headline-levels 4
        ;; :html-extension "html"
        :body-only t )
       ;; ("org-blog-static"
       ;;  :base-directory "~/org/blog/jekyll"
       ;;  :base-extension "css\\|js\\|png\\|jpg\\|jpeg\\|gif\\|pdf\\|mp3\\|ogg\\|swf\\|php"
       ;;  :publishing-directory "~/blog/jekyll"
       ;;  :recursive t
       ;;  :publishing-function org-publish-attachment)
       ;; ("jekyll" :components ("org-blog" "org-blog-static"))
       ))
    (add-hook 'org-export-before-processing-hook #'my/org-insert-updated-timestamp)
    (add-hook 'org-publish-after-publishing-hook #'+wd/handle-image-in-markdown)

    ;; 这个快捷键放在全局比较好
    (map! :leader
          (:prefix-map ("c" . "code")
           :desc "Write New Blog" "B" #'blog-post))

    (add-to-list 'file-coding-system-alist '("\\.bib" . utf-8))))


(setup org-latex-impatient
  (:hooks org-mode-hook org-latex-impatient-mode) ; 这个写法是常用的
  (:when-loaded
    (:option
     max-image-size nil
     org-latex-impatient-tex2svg-bin (executable-find "tex2svg"))))

;; use spectable on KDE, override doom config: /home/wd/.config/emacs/modules/lang/org/contrib/dragndrop.el
(setup org-download
  (:when-loaded
    (when (and (featurep :system 'linux)
               (executable-find "spectacle"))
      (setq org-download-screenshot-method (concat (executable-find "spectacle") " -br -o %s")))))


(setup so-long
  (:when-loaded
    (add-to-list 'doom-file-lines-threshold-alist
                 '("\\.org\\'" . 50000))))

(provide 'init-org)
;;; init-org.el ends here
