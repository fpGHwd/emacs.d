;;; ../Sync/dotfiles/doom.d/lisp/init-org.el -*- lexical-binding: t; -*-

(setq org-directory (file-truename "~/org/org/current"))

(setq +wd/seven-year-life 7) ;; 七年一生
(use-package! org
  :defer t
  :after lib-org
  :custom
  ;; week display in org-mode
  ;; https://emacs-china.org/t/topic/1551/15
  ;; https://stackoverflow.com/questions/28913294/emacs-org-mode-language-of-time-stamps
  (system-time-locale "C")
  (org-log-done 'time)
  (org-archive-location "~/org/org/current/archive.org.bak::* From %s")
  (org-id-locations-file (concat doom-cache-dir "/org-id-locations"))
  (org-agenda-diary-file (concat doom-user-dir "etc/diary"))

  (diary-file (concat doom-user-dir "etc/diary"))
  (org-agenda-include-diary t)
  (org-agenda-files (let* ((year-number (string-to-number (format-time-string "%Y")))
                           (add-year year-number))
                      (while (<= (- year-number add-year) +wd/seven-year-life)
                        (let ((add-year-str (number-to-string add-year)))
                          (cl-pushnew (concat "~/org/org/" add-year-str) org-agenda-files)
                          (cl-pushnew (concat "~/org/noter/" add-year-str) org-agenda-files))
                        (cl-decf add-year))
                      org-agenda-files))

  (org-agenda-start-day (pcase (system-name)
                         ("ubuntu2204" "-3d")
                         (_ "-1d")))
  (org-agenda-span (pcase (system-name)
                     ("ubuntu2204" 10)
                     (_ 6)))

  (org-crypt-key "ggwdwhu@gmail.com")

  (org-agenda-show-inherited-tags 'always)
  (org-agenda-sorting-strategy
   '((agenda habit-down time-up urgency-down category-keep)
     (todo urgency-down category-keep)
     (tags urgency-down timestamp-down category-keep) (search alpha-up)))
  ;; (org-agenda-use-tag-inheritance '(todo agenda))

  (org-refile-targets '((nil :maxlevel . 1) (org-agenda-files :maxlevel . 1)))

  (org-image-actual-width 600)
  ;; (org-tags-match-list-sublevels nil)

  ;; (org-use-tag-inheritance nil)

  ;; (auto-save-interval 300)
  ;; (auto-save-visited-interval 300)
  ;; (auto-save-visited-mode t)

  (org-deadline-warning-days 7)
  (org-format-latex-options
   '(:foreground auto :background default :scale 1.5 :html-foreground "Black"
     :html-background "Transparent" :html-scale 1.0 :matchers
     ("begin" "$1" "$" "$$" "\\(" "\\[")))
  (org-journal-dir "~/org/journal")
  (rmh-elfeed-org-files '("~/org/elfeed/elfeed.org"))
  :hook
  (org-mode-hook . auto-revert-mode)
  (org-mode-hook . variable-pitch-mode)
  ;; (org-mode-hook . (lambda () (company-mode -1)))
  (org-mode-hook . (lambda () (when (org-property-values "GPTEL_SYSTEM")
                                (progn (gptel-mode)
                                       (rename-buffer (concat "ChatGPT/GPTel:" (buffer-name)))))))
  :bind
  (("C-c i" . org-insert-item))

  :config
  ;;(require 'lib-org)
  (add-to-list 'org-tags-exclude-from-inheritance "roam-agenda")

  ;; emacsclient "org-protocol://capture?template=mc&title=title2 :tag:&body=ok"
  (defvar +wd/org-capture-file-for-ios (expand-file-name "notes_ios.org" org-directory))
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
  ;; (add-to-list 'org-file-apps '("\\.minder" . "minder"))

  (add-to-list 'org-file-apps '("\\.drawio\\'" . "/opt/drawio/drawio %s"))
  (add-to-list 'org-file-apps '("\\.minder\\'" . "/usr/bin/minder %s"))

  (org-toggle-sticky-agenda 1)

  ;; org-agenda-goto automatically narrow
  (after! org-agenda
    (defadvice! +wd/org-agenda-goto-narrow (&rest _)
      "When org-agenda-goto narrow to current HEADLINE."
      :after #'org-agenda-goto
      (org-narrow-to-subtree)))

  (after! org-roam-node
    (defadvice! +wd/org-capture-goto-narrow (&rest _)
      "When org-capture-goto narrow to current HEADLINE."
      :after #'org-roam-node-find
      (org-narrow-to-subtree)))

  (org-babel-do-load-languages
   'org-babel-load-languages
   '((jupyter . t)
     (gnuplot . t)
     (plantuml . t)))
  )

;; TODO: 只显示当前 headline 到最顶层父节点的路径，其他的内容都隐藏起来，作为 hook 添加到 org-agenda-goto 和 org-roam-node-find 之后
;; (defun my/org-show-path-only ()
;;   "Show only the chain from top-level ancestor to current headline."
;;   (interactive)
;;   ;; 找到最顶层父节点
;;   (save-excursion
;;     (while (org-up-heading-safe)))
;;   (org-narrow-to-subtree)
;;   ;; 只显示 headline
;;   (org-overview)
;;   ;; 展开当前 headline 及其父链
;;   (org-reveal))




(setup org-super-agenda
  ;; (:with-hook org-agenda (org-super-agenda-mode))
  (:when-loaded
    (:option
     org-super-agenda-groups
     '((:name "Today"
        :time-grid t
        :todo "TODAY")
       ;; (:order-multi (1 (:todo ("HOLD" "IDEA" "[-]" "[?]") :order 2)
       ;;                  (:todo ("PROJ") :order 4)
       ;;                  (:todo ("STRT") :order 3)
       ;;                  (:todo ("TODO" "[ ]") :order 0)
       ;;                  (:todo ("WAIT") :order 1)))
       (:order-multi (2
                      ;; (:name "Important" :tag "bills" :priority "A")
                      (:name "Reading & Courses" :tag ("book" "course"))
                      (:name "Audio" :tag "audio")
                      (:name "Develop" :tag ("dev" "emacs" "source"))
                      (:name "Work" :tag ("jira" "work"))
                      ;; (:name "Chore" :tag "chore")
                      ;; (:name "Trading" :tag "trading")
                      ;; (:name "Beorg" :tag "beorg")
                      ))
       ;; (:order-multi (5 (:name "Shopping in town"
       ;;                   :and (:tag "shopping" :tag "@town"))
       ;;                  (:name "Food-related"
       ;;                   :tag ("food" "dinner"))
       ;;                  (:name "Personal"
       ;;                   :habit t
       ;;                   :tag "personal")
       ;;                  (:name "Space-related (non-moon-or-planet-related)"
       ;;                   :and (:regexp ("space" "NASA")
       ;;                         :not (:regexp "moon" :tag "planet")))))
       (:priority<= "B" :order 1)))))


(use-package! cal-china-x
  :defer t
  :config
  (setq mark-holidays-in-calendar t)
  (setq cal-china-x-important-holidays cal-china-x-chinese-holidays)
  (setq cal-china-x-general-holidays '((holiday-lunar 1 15 "元宵节")))
  (setq calendar-holidays
        (append cal-china-x-important-holidays
                cal-china-x-general-holidays)))


(use-package! org-attach
  :defer t
  :custom
  (org-attach-directory (file-truename "~/.local/org-attach"))
  (org-attach-id-dir (file-truename "~/.local/org-attach")))


(use-package! dired
  :defer t
  :hook
  (dired-mode . (lambda () (define-key dired-mode-map (kbd "C-c C-x a")
                                       #'org-attach-dired-to-subtree))))

(use-package! org-noter
  :defer t
  :custom
  (org-noter-doc-split-fraction '(0.618 . 0.382))
  :config
  (add-to-list 'org-noter-notes-search-path (file-truename "~/org/noter/current")))

(use-package! deft
  :defer t
  :custom
  (deft-directory "~/org/deft"))

(use-package! ox-publish
  :defer t
  :init
  (require 'lib-org)
  :custom
  (org-publish-project-alist
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
  :config
  (add-hook 'org-export-before-processing-hook #'my/org-insert-updated-timestamp)
  (add-hook 'org-publish-after-publishing-hook #'+wd/handle-image-in-markdown)

  ;; 这个快捷键放在全局比较好
  (map! :leader
        (:prefix-map ("c" . "code")
         :desc "Write New Blog" "B" #'blog-post))

  (add-to-list 'file-coding-system-alist '("\\.bib" . utf-8)))


(use-package! org-latex-impatient
  :defer t
  :hook (org-mode-hook . org-latex-impatient-mode) ; 这个写法是常用的
  ;; :init
  :custom
  (max-image-size nil)
  (org-latex-impatient-tex2svg-bin (executable-find "tex2svg")))


(after! citar
  (setq! citar-bibliography '("~/org/refs/zotero.bib"
                              "~/org/refs/calibre.bib"
                              "~/org/refs/citar.bib")
         citar-library-paths (pcase (system-name)
                               ("ubuntu2204" '("~/Sync/citar-lib/"))
                               ("arch-nuc" '("/home/data/books/citar-library/")))
         citar-notes-paths '("~/org/roam/notes/")))

(after! reftex
  (setq! reftex-default-bibliography citar-bibliography))

(after! citar-org-roam
  (setq! citar-org-roam-subdir "notes/"))


(use-package! calendar
  :defer t
  :custom
  (calendar-mark-diary-entries-flag t)
  (calendar-week-start-day 1)
  (calendar-latitude 31.108024)
  (calendar-longitude 121.372327))

;; use spectable on KDE, override doom config: /home/wd/.config/emacs/modules/lang/org/contrib/dragndrop.el
(use-package! org-download
  :defer t
  :after org
  :config
  (when (and (featurep :system 'linux)
             (executable-find "spectacle"))
    (setq org-download-screenshot-method (concat (executable-find "spectacle") " -r -b -o %s"))))


(define-minor-mode org-agenda-work-mode
  "A minor mode for org-agenda-work."
  :init-value nil
  :lighter " OrgWork"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c w a") #'org-agenda)
            map)
  :group 'org-agenda-work
  (progn (if org-agenda-work-mode
             (message "org-agenda-work-mode enabled")
           (message "org-agenda-work-mode disabled"))
         (let* ((year-number (string-to-number (format-time-string "%Y")))
                (add-year year-number))
           (while (<= (- year-number add-year) +wd/seven-year-life)
             (let ((add-year-str (number-to-string add-year)))
               (if org-agenda-work-mode
                   (progn (cl-pushnew (concat "~/org/work/current/org/" add-year-str) org-agenda-files :test #'equal)
                          (cl-pushnew (concat "~/org/work/current/noter/" add-year-str) org-agenda-files :test #'equal))
                 (progn (setq org-agenda-files (cl-remove (concat "~/org/work/current/org/" add-year-str) org-agenda-files :test #'equal))
                        (setq org-agenda-files (cl-remove (concat "~/org/work/current/noter/" add-year-str) org-agenda-files :test #'equal)))))
             (cl-decf add-year)))
         (if org-agenda-work-mode
             (make-symbolic-link (file-truename "~/org/work/zone/roam") "~/org/roam/zone"  t)
           (delete-file (expand-file-name "~/org/roam/zone")))
         (org-roam-db-sync)))

(provide 'init-org)
;;; init-org.el ends here
