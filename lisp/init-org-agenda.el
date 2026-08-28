;;; init-org-agenda.el --- Org agenda, counters, and work mode -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)

(defun +wd/org-count-total-update ()
  "Recompute COUNT_* stats for the current entry into its properties."
  (interactive)
  (require 'calc)
  (when (derived-mode-p 'org-mode)
    (save-excursion
      (org-back-to-heading t)
      (when (org-entry-get (point) "COUNT_TOTAL")
        (let ((total 0) (times 0) (in-src nil) (in-drawer nil) (dates nil)
              (heading (point))
              (end (save-excursion (org-end-of-subtree t t) (point))))
          (org-end-of-meta-data t)
          (while (< (point) end)
            (let ((raw (buffer-substring-no-properties
                        (line-beginning-position) (line-end-position))))
              (cond
               ((string-match-p "^[ \t]*#\\+begin_src" raw) (setq in-src t))
               ((string-match-p "^[ \t]*#\\+end_src" raw) (setq in-src nil))
               ((and in-drawer (string-match-p "^[ \t]*:END:[ \t]*$" raw))
                (setq in-drawer nil))
               ((and (not in-drawer)
                     (string-match-p "^[ \t]*:[A-Za-z][A-Za-z0-9_@#%-]*:[ \t]*$" raw))
                (setq in-drawer t))
               ((and (not in-src) (not in-drawer))
                (let ((date (and (string-match "\\[\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" raw)
                                 (match-string 1 raw)))
                      (line (replace-regexp-in-string
                             "[x×]" "*"
                             (replace-regexp-in-string
                              "\\[[^]]*\\]\\|<[^>]*>" " " raw))))
                  (when (string-match
                         "[0-9.]+\\(?:[ \t]*[-+*/][ \t]*[0-9.]+\\)*" line)
                    (let ((v (ignore-errors (calc-eval (match-string 0 line)))))
                      (when (stringp v)
                        (setq total (+ total (string-to-number v)))
                        (setq times (1+ times))
                        (when (and date (not (member date dates)))
                          (push date dates)))))))))
            (forward-line 1))
          (org-entry-put heading "COUNT_TOTAL" (number-to-string total))
          (org-entry-put heading "COUNT_TIMES" (number-to-string times))
          (org-entry-put heading "COUNT_DAYS" (number-to-string (length dates)))
          (when (called-interactively-p 'any)
            (message "COUNT_TOTAL = %s, COUNT_TIMES = %s, COUNT_DAYS = %s"
                     total times (length dates)))
          (list total times (length dates)))))))

(defun +wd/org-search-by-tags (org-match-string)
  "Search org and roam files for entries matching ORG-MATCH-STRING."
  (interactive "sTags match: ")
  (let ((org-use-tag-inheritance nil)
        (todo-filter "+TODO<>\"DONE\"+TODO<>\"KILL\"+TODO<>\"[X]\""))
    (org-tags-view nil
                   (string-join
                    (mapcar (lambda (branch)
                              (concat branch todo-filter))
                            (split-string org-match-string "|"))
                    "|"))))

(defun diary-sunrise ()
  (let ((dss (diary-sunrise-sunset)))
    (with-temp-buffer
      (insert dss)
      (goto-char (point-min))
      (while (re-search-forward " ([^)]*)" nil t)
        (replace-match "" nil nil))
      (goto-char (point-min))
      (search-forward ",")
      (buffer-substring (point-min) (match-beginning 0)))))

(defun diary-sunset ()
  (let ((dss (diary-sunrise-sunset))
        start end)
    (with-temp-buffer
      (insert dss)
      (goto-char (point-min))
      (while (re-search-forward " ([^)]*)" nil t)
        (replace-match "" nil nil))
      (goto-char (point-min))
      (search-forward ", ")
      (setq start (match-end 0))
      (search-forward " at")
      (setq end (match-beginning 0))
      (goto-char start)
      (capitalize-word 1)
      (buffer-substring start end))))

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

(defun +wd/org-read-date-default-current-time (orig &optional with-time to-time
                                                   from-string prompt default-time
                                                   default-input &rest args)
  "Call ORIG with current time when `org-read-date' receives a date-only default."
  (let* ((effective-default
          (if (and default-time (not default-input))
              (org-current-time)
            default-time))
         (result (apply orig t to-time from-string prompt
                        effective-default default-input args)))
    (when (boundp 'org-time-was-given)
      (setq org-time-was-given t))
    result))

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

(setup org
  (:advice org-read-date :around #'+wd/org-read-date-default-current-time)
  (:hooks kill-emacs-hook +wd/org-agenda-work-mode-cleanup-roam-link)
  (:when-loaded
    (when (not (string= (system-name) "ubuntu2204"))
      (add-hook 'org-after-note-stored-hook #'+wd/org-count-total-update))
    (org-toggle-sticky-agenda 1)))

(provide 'init-org-agenda)
;;; init-org-agenda.el ends here
