;;; init-schedule.el --- User scheduled tasks -*- lexical-binding: t; -*-

;; ---------------------------------------------------------------------------
;; Auto-commit and push ~/org at scheduled time
;; ---------------------------------------------------------------------------

(defvar +wd/org-autocommit-repo "~/org"
  "Directory to auto-commit and push.")

(defvar +wd/org-autocommit-timer nil
  "Timer for scheduled org auto-commit.")

(defun +wd/org-autocommit ()
  "Stage all changes in `+wd/org-autocommit-repo', commit, and push.
Skip if there are no changes.  Commit message includes timestamp.
After committing, reschedule for the next day at 17:30."
  (interactive)
  (require 'magit)
  (let ((default-directory (expand-file-name +wd/org-autocommit-repo)))
    (magit-call-git "add" "-A")
    (unless (= 0 (magit-call-git "diff" "--cached" "--quiet"))
      (magit-call-git "commit" "-m" "auto-commit")
      (magit-call-git "push")))
  ;; Reschedule for tomorrow 17:30
  (+wd/org-autocommit-schedule))

(defun +wd/org-autocommit-schedule ()
  "Schedule `+wd/org-autocommit' for the next 17:30.
If 17:30 has already passed today, schedule for tomorrow."
  (interactive)
  (when (timerp +wd/org-autocommit-timer)
    (cancel-timer +wd/org-autocommit-timer))
  (let* ((now (current-time))
         (today-1730 (encode-time 0 30 17 (nth 3 (decode-time now))
                                  (nth 4 (decode-time now))
                                  (nth 5 (decode-time now))))
         (next-run (if (time-less-p now today-1730)
                       today-1730
                     (time-add today-1730 86400))))
    (setq +wd/org-autocommit-timer
          (run-at-time next-run nil #'+wd/org-autocommit))
    (message "Org auto-commit scheduled at %s"
             (format-time-string "%Y-%m-%d %H:%M" next-run))))

;; ---------------------------------------------------------------------------
;; user-schedule-mode: minor mode to enable scheduled tasks
;; ---------------------------------------------------------------------------

(define-minor-mode user-schedule-mode
  "Toggle user scheduled tasks (e.g. daily org auto-commit)."
  :init-value t
  :global t
  :lighter " Sched"
  :group 'user-schedule
  (if user-schedule-mode
      (+wd/org-autocommit-schedule)
    (when (timerp +wd/org-autocommit-timer)
      (cancel-timer +wd/org-autocommit-timer)
      (setq +wd/org-autocommit-timer nil))))

;; Enable by default
(when (string= (system-name) "ubuntu2204")
  (user-schedule-mode +1))

(provide 'init-schedule)
;;; init-schedule.el ends here
