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
  (org-id-locations-file (expand-file-name "org-id-locations" doom-cache-dir))
  (org-agenda-diary-file (expand-file-name "etc/diary" doom-user-dir))
  (diary-file (expand-file-name "etc/diary" doom-user-dir))
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
     (plantuml . t))))

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


(defun +wd/org-noter--current-session ()
  "Return current org-noter session object, or nil if unavailable."
  (when (require 'org-noter-core nil t)
    (cond
     ;; Newer/packaged builds may not expose `org-noter--get-session`.
     ((boundp 'org-noter--session)
      (and (org-noter--session-p org-noter--session) org-noter--session))
     ((fboundp 'org-noter--get-session)
      (ignore-errors (org-noter--get-session)))
     (t nil))))

(defun +wd/org-noter--page-progress (&optional session)
  "Return current page and total pages as (CURRENT . TOTAL) for SESSION."
  (let* ((session (or session (+wd/org-noter--current-session)))
         (doc-buffer (and session (org-noter--session-doc-buffer session))))
    (when (buffer-live-p doc-buffer)
      (with-current-buffer doc-buffer
        (cond
         ((and (derived-mode-p 'pdf-view-mode)
               (fboundp 'pdf-view-current-page)
               (fboundp 'pdf-cache-number-of-pages))
          (cons (pdf-view-current-page)
                (pdf-cache-number-of-pages)))
         ((derived-mode-p 'doc-view-mode)
          (let ((current (if (fboundp 'doc-view-current-page)
                             (doc-view-current-page)
                           (and (boundp 'doc-view-current-page)
                                doc-view-current-page)))
                (total (if (boundp 'doc-view-last-page-number)
                           doc-view-last-page-number
                         nil)))
            (when (and (numberp current) (numberp total) (> total 0))
              (cons current total))))
         (t nil))))))

(defun +wd/org-noter--find-noter-document-heading-point ()
  "Return nearest headline point that locally defines NOTER_DOCUMENT."
  (org-with-wide-buffer
   (save-excursion
     (when (org-before-first-heading-p)
       (outline-next-heading))
     (when (org-at-heading-p)
       (let ((found nil))
         (while (and (not found) (org-at-heading-p))
           (when (org-entry-get nil "NOTER_DOCUMENT" nil)
             (setq found (point)))
           (unless found
             (if (org-up-heading-safe)
                 t
               (goto-char (point-min)))))
         found)))))

(defun +wd/org-noter--same-notes-buffer-p (buffer-a buffer-b)
  "Return non-nil when BUFFER-A and BUFFER-B are same or share base buffer."
  (let ((a (and (buffer-live-p buffer-a) buffer-a))
        (b (and (buffer-live-p buffer-b) buffer-b)))
    (and a
         b
         (or (eq a b)
             (eq (buffer-base-buffer a) b)
             (eq a (buffer-base-buffer b))
             (eq (buffer-base-buffer a) (buffer-base-buffer b))))))

(defcustom +wd/calibredb-sync-progress-column "percentage"
  "Calibre custom column name used to store reading progress."
  :type 'string
  :group 'org-noter)

(defcustom +wd/calibredb-sync-library-url "http://localhost:8080/"
  "Calibre content server URL for progress sync."
  :type 'string
  :group 'org-noter)

(defcustom +wd/calibredb-sync-username "wd"
  "Calibre content server username for progress sync."
  :type 'string
  :group 'org-noter)

(defcustom +wd/calibredb-sync-password-store-key "calibre-lib/wd"
  "Password-store key used to fetch calibre content server password."
  :type 'string
  :group 'org-noter)

(defun +wd/org-noter--document-filename-from-property (noter-document)
  "Derive final filename (with extension) from NOTER-DOCUMENT path."
  (when (and (stringp noter-document) (not (string-empty-p noter-document)))
    (let* ((raw (string-trim noter-document))
           (clean (replace-regexp-in-string "\\`file:" "" raw))
           (path (car (split-string clean "::"))))
      (file-name-nondirectory path))))

(defun +wd/org-noter--calibredb-base-args ()
  "Build base calibredb args for calibre content server."
  (let ((pw (when (and (fboundp 'password-store-get)
                       (stringp +wd/calibredb-sync-password-store-key)
                       (not (string-empty-p +wd/calibredb-sync-password-store-key)))
              (ignore-errors
                (password-store-get +wd/calibredb-sync-password-store-key)))))
    (if (and (stringp +wd/calibredb-sync-library-url)
             (not (string-empty-p +wd/calibredb-sync-library-url))
             (stringp +wd/calibredb-sync-username)
             (not (string-empty-p +wd/calibredb-sync-username))
             (stringp pw)
             (not (string-empty-p pw)))
        (list (concat "--with-library=" +wd/calibredb-sync-library-url)
              (concat "--username=" +wd/calibredb-sync-username)
              (concat "--password=" pw))
      nil)))

(defun +wd/org-noter--calibre-id-from-path (path)
  "Extract calibre numeric id from parent directory of PATH."
  (when (stringp path)
    (let ((dir (file-name-nondirectory
                (directory-file-name (file-name-directory path)))))
      (when (string-match ".*(\\([0-9]+\\))\\'" dir)
        (match-string 1 dir)))))

(defun +wd/org-noter-sync-calibredb-percentage (target ratio &optional silent)
  "Sync current book progress RATIO (0-100 scale) to calibredb #percentage."
  (let* ((bin (executable-find "calibredb"))
         (base-args (+wd/org-noter--calibredb-base-args)))
    (when (and bin base-args (numberp ratio) (>= ratio 0))
      (let* ((noter-document (save-excursion
                               (goto-char target)
                               (org-entry-get (point) "NOTER_DOCUMENT" nil)))
             (filename (+wd/org-noter--document-filename-from-property noter-document)))
        (when (and (stringp filename) (not (string-empty-p filename)))
          (let* ((case-fold-search t)
                 (matches (directory-files-recursively
                           +wd/org-noter-calibre-library-root
                           (concat (regexp-quote filename) "\\'")))
                 (value (format "%.1f" ratio))
                 (updated-ids nil))
            (dolist (path matches)
              (let ((id (+wd/org-noter--calibre-id-from-path path)))
                (when id
                  (let ((ok
                         (eq 0 (apply #'call-process bin nil nil nil
                                      (append base-args
                                              (list "set_custom"
                                                    +wd/calibredb-sync-progress-column
                                                    id value))))))
                    (when ok
                      (push id updated-ids))))))
            (unless silent
              (message "calibredb #percentage synced: %s -> %s (%s)"
                       filename
                       value
                       (if updated-ids
                           (mapconcat #'identity (reverse (delete-dups updated-ids)) ",")
                         "no-id-updated")))))))))

(defun +wd/org-noter-update-read-progress (&optional silent)
  "Update NOTER_READ at the headline which defines NOTER_DOCUMENT."
  (interactive)
  (let* ((session (+wd/org-noter--current-session))
         (notes-buffer (and session (org-noter--session-notes-buffer session)))
         (progress (+wd/org-noter--page-progress session))
         (target (+wd/org-noter--find-noter-document-heading-point)))
    (when (and session
               (buffer-live-p notes-buffer)
               (+wd/org-noter--same-notes-buffer-p (current-buffer) notes-buffer)
               progress
               target)
        (let* ((current (car progress))
               (total (cdr progress))
               (ratio (* 100.0 (/ (float current) total)))
               (value (format "%.1f%% (%d/%d)" ratio current total)))
          (save-excursion
            (goto-char target)
            (org-entry-put (point) "NOTER_READ" value))
          (+wd/org-noter-sync-calibredb-percentage target ratio t)
          (unless silent
            (message "NOTER_READ -> %s" value))))))

(defun +wd/org-noter-auto-update-read-progress ()
  "Auto update NOTER_READ on DONE/KILL inside org-noter notes buffer."
  (when (and (derived-mode-p 'org-mode)
             (bound-and-true-p org-noter-notes-mode)
             (bound-and-true-p org-state)
             (member org-state '("DONE" "KILL")))
    (+wd/org-noter-update-read-progress t)))


(use-package! org-noter
  :defer t
  :custom
  (org-noter-doc-split-fraction '(0.618 . 0.382))
  :config

  (defcustom +wd/org-noter-calibre-library-root
    (file-truename "~/Calibre Library")
    "Root directory used to resolve `:NOTER_DOCUMENT:` files for org-noter."
    :type 'directory
    :group 'org-noter)

  (defun +wd/org-noter--find-document-in-calibre (document)
    "Resolve DOCUMENT by filename under `+wd/org-noter-calibre-library-root`."
    (let* ((doc (and (stringp document) (string-trim document)))
           (expanded (and doc (expand-file-name doc))))
      (cond
       ((or (null doc) (string-empty-p doc)) nil)
       ((file-exists-p expanded) expanded)
       ((not (file-directory-p +wd/org-noter-calibre-library-root)) nil)
       (t
        (let* ((filename (file-name-nondirectory expanded))
               (matches (directory-files-recursively
                         +wd/org-noter-calibre-library-root
                         (concat "\\`" (regexp-quote filename) "\\'")))
               ;; Prefer the shortest path when duplicate filenames exist.
               (sorted (sort matches (lambda (a b) (< (length a) (length b))))))
          (car sorted))))))

  (defun +wd/org-noter-parse-document-property-calibre (document &rest _)
    "Hook for `org-noter-parse-document-property-hook` to resolve DOCUMENT path."
    (+wd/org-noter--find-document-in-calibre document))

  (add-hook 'org-noter-parse-document-property-hook
            #'+wd/org-noter-parse-document-property-calibre)
  (add-hook 'org-after-todo-state-change-hook
            #'+wd/org-noter-auto-update-read-progress))

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
  (setopt citar-bibliography '("~/org/refs/zotero.bib"
                               "~/org/refs/calibre.bib"
                               "~/org/refs/citar.bib")
          citar-library-paths (pcase (system-name)
                                ("ubuntu2204" '("~/Sync/citar-lib/"))
                                ("arch-nuc" '("/home/data/books/citar-library/")))
          citar-notes-paths '("~/org/roam/notes/")))

(after! reftex
  (setopt reftex-default-bibliography citar-bibliography))

(after! citar-org-roam
  (setopt citar-org-roam-subdir "notes/"))


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


(defun +wd/org-work-agenda-files ()
  "Return work agenda directories for the configured year window."
  (let ((year-number (string-to-number (format-time-string "%Y")))
        (files nil))
    (dotimes (offset (1+ +wd/seven-year-life))
      (let* ((year-str (number-to-string (- year-number offset)))
             (org-dir (expand-file-name (concat "~/org/work/current/org/" year-str)))
             (noter-dir (expand-file-name (concat "~/org/work/current/noter/" year-str))))
        (when (file-directory-p org-dir)
          (push org-dir files))
        (when (file-directory-p noter-dir)
          (push noter-dir files))))
    (nreverse files)))

(defvar +wd/org-agenda-work-mode--saved-agenda-files nil
  "Snapshot of `org-agenda-files' before `org-agenda-work-mode' is enabled.")

(defun +wd/org-agenda-work-mode-update-agenda-files ()
  "Enable work agenda files and restore the previous state when disabled."
  (if org-agenda-work-mode
      (progn
        (unless +wd/org-agenda-work-mode--saved-agenda-files
          (setq +wd/org-agenda-work-mode--saved-agenda-files
                (copy-sequence org-agenda-files)))
        (setq org-agenda-files
              (cl-union org-agenda-files (+wd/org-work-agenda-files) :test #'equal)))
    (when +wd/org-agenda-work-mode--saved-agenda-files
      (setq org-agenda-files +wd/org-agenda-work-mode--saved-agenda-files
            +wd/org-agenda-work-mode--saved-agenda-files nil))))

(defun +wd/org-agenda-work-mode-update-roam-link ()
  "Create or remove the Org Roam work symlink for `org-agenda-work-mode'."
  (let ((target (expand-file-name "~/org/work/zone/roam"))
        (link (expand-file-name "~/org/roam/zone")))
    (cond
     (org-agenda-work-mode
      (unless (file-symlink-p link)
        (when (file-exists-p link)
          (user-error "%s exists and is not a symlink" link))
        (make-symbolic-link target link t)))
     ((file-symlink-p link)
      (delete-file link)))))

(defun +wd/org-agenda-work-mode-sync-roam ()
  "Refresh Org Roam after `org-agenda-work-mode' changes."
  (when (or (featurep 'org-roam)
            (require 'org-roam nil t))
    (org-roam-db-sync)))

(defun +wd/org-agenda-work-mode-apply ()
  "Apply the current `org-agenda-work-mode' state."
  (+wd/org-agenda-work-mode-update-agenda-files)
  (+wd/org-agenda-work-mode-update-roam-link)
  (+wd/org-agenda-work-mode-sync-roam)
  (message "org-agenda-work-mode %s" (if org-agenda-work-mode "enabled" "disabled")))

(define-minor-mode org-agenda-work-mode
  "Toggle work-specific Org agenda and Org Roam sources."
  :init-value nil
  :global t
  :lighter " OrgWork"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c w a") #'org-agenda)
            map)
  :group 'org-agenda-work
  (+wd/org-agenda-work-mode-apply))

(provide 'init-org)
;;; init-org.el ends here
