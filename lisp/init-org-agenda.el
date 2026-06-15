;;; init-org-agenda.el --- Org agenda, capture, calendar, and work-mode -*- lexical-binding: t; -*-

(setq +wd/seven-year-life 7) ;; 七年一生

(setup org
  (:hooks org-capture-mode-hook meow-insert)
  (:when-loaded
    (:option
     org-agenda-diary-file (expand-file-name "etc/diary" doom-user-dir)
     diary-file (expand-file-name "etc/diary" doom-user-dir)
     org-agenda-include-diary t
     org-agenda-files (let* ((year-number (string-to-number (format-time-string "%Y")))
                             (add-year year-number))
                        (while (<= (- year-number add-year) +wd/seven-year-life)
                          (let ((add-year-str (number-to-string add-year)))
                            (cl-pushnew (concat "~/org/org/" add-year-str) org-agenda-files)
                            (cl-pushnew (concat "~/org/noter/" add-year-str) org-agenda-files))
                          (cl-decf add-year))
                        (cl-pushnew "~/org/beorg/" org-agenda-files)
                        org-agenda-files)
     org-agenda-start-day "-1d"
     org-agenda-span 4
     org-agenda-show-inherited-tags 'always
     org-agenda-sorting-strategy
     '((agenda habit-down time-up urgency-down category-keep)
       (todo urgency-down category-keep)
       (tags urgency-down timestamp-down category-keep) (search alpha-up))
     ;; (org-agenda-use-tag-inheritance '(todo agenda))
     org-refile-targets '((nil :maxlevel . 1) (org-agenda-files :maxlevel . 1)))
    (org-toggle-sticky-agenda 1)

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

    ;; Default the org-read-date prompt to the current time (not 00:00) when the
    ;; existing timestamp carries no time component.
    (advice-add 'org-read-date :around
                (lambda (orig &optional with-time to-time from-string prompt default-time default-input &rest args)
                  (let* ((effective-default
                          (if (and default-time (not default-input))
                              (org-current-time)
                            default-time))
                         (result (apply orig t to-time from-string prompt
                                        effective-default default-input args)))
                    (when (boundp 'org-time-was-given)
                      (setq org-time-was-given t))
                    result)))))


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


(setup calendar
  (:when-loaded
    (:option
     calendar-mark-diary-entries-flag t
     calendar-week-start-day 1
     calendar-latitude 31.108024
     calendar-longitude 121.372327)))

(setup cal-china-x
  (:when-loaded
    (setq mark-holidays-in-calendar t)
    (setq cal-china-x-important-holidays cal-china-x-chinese-holidays)
    (setq cal-china-x-general-holidays '((holiday-lunar 1 15 "元宵节")))
    (setq calendar-holidays
          (append cal-china-x-important-holidays
                  cal-china-x-general-holidays))))


;; ----------------------------------------------------------------------------
;; org-agenda-work-mode: toggle work-specific agenda files and Org Roam sources
;; ----------------------------------------------------------------------------

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

(defun +wd/org-agenda-work-mode-cleanup-roam-link ()
  "Remove the work Org Roam symlink when Emacs is shutting down."
  (let ((link (expand-file-name "~/org/roam/zone")))
    (when (file-symlink-p link)
      (delete-file link))))

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

(add-hook 'kill-emacs-hook #'+wd/org-agenda-work-mode-cleanup-roam-link)

(provide 'init-org-agenda)
;;; init-org-agenda.el ends here
