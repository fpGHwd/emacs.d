;;; init-schedule.el --- Host-aware scheduled tasks -*- lexical-binding: t; -*-

(require 'lib-calibre)

;; ---------------------------------------------------------------------------
;; Auto-commit: configurable repo list
;; ---------------------------------------------------------------------------

(defvar +wd/org-autocommit-timer nil
  "Timer for scheduled org auto-commit.")

(defvar +wd/calibre-import-timer nil
  "Timer for scheduled Calibre import.")

(defcustom +wd/org-autocommit-repos
  '(("~/org" . "auto-commit"))
  "List of (REPO-DIR . COMMIT-MSG) pairs for auto-commit.
Each entry is a cons cell:
  REPO-DIR    — absolute or home-relative path to the git repository
  COMMIT-MSG  — commit message string

Example:
  ((\"~/org\" . \"auto-commit\")
   (\"~/projects/dotfiles\" . \"sync\"))"
  :type '(repeat (cons string string))
  :group 'user-schedule)

(defun +wd/org-autocommit--commit-one (repo msg)
  "Stage, commit, and push REPO with commit message MSG.
Skip if no changes.  Return t if a commit was made."
  (require 'magit)
  (let ((default-directory (expand-file-name repo)))
    (magit-call-git "add" "-A")
    (unless (= 0 (magit-call-git "diff" "--cached" "--quiet"))
      (magit-call-git "commit" "-m" msg)
      (magit-call-git "push")
      (message "Auto-committed %s" repo)
      t)))

(defun +wd/org-autocommit ()
  "Auto-commit all repos in `+wd/org-autocommit-repos'.
After committing, reschedule for the next day at 17:30."
  (interactive)
  (dolist (spec +wd/org-autocommit-repos)
    (+wd/org-autocommit--commit-one (car spec) (cdr spec)))
  (+wd/org-autocommit-schedule))

(defun +wd/org-autocommit-schedule ()
  "Schedule `+wd/org-autocommit' for the next 17:30."
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

(defun +wd/calibre-import-schedule ()
  "Schedule `+wd/add-book-to-calibre' weekly."
  (interactive)
  (when (timerp +wd/calibre-import-timer)
    (cancel-timer +wd/calibre-import-timer))
  (let ((weekly (* 7 24 60 60)))
    (setq +wd/calibre-import-timer
          (run-at-time weekly weekly #'+wd/add-book-to-calibre))
    (message "Calibre import scheduled every 7 days")))

;; ---------------------------------------------------------------------------
;; Host-aware task registry
;; ---------------------------------------------------------------------------

(defcustom +wd/user-schedule-tasks
  '((:name "Org auto-commit"
     :timer +wd/org-autocommit-timer
     :schedule +wd/org-autocommit-schedule
     :hosts ("ubuntu2204"))
    (:name "Calibre import"
     :timer +wd/calibre-import-timer
     :schedule +wd/calibre-import-schedule
     :hosts t))
  "Scheduled task registry.
Each element is a plist:
  :name     — human-readable name
  :timer    — variable symbol holding the timer object
  :schedule — function symbol to call to start scheduling
  :hosts    — list of host names (matching `system-name') where this
task runs, or `t' to run on all hosts.

Add new tasks by pushing to this list."
  :type '(repeat
          (plist :options
                 ((:name string)
                  (:timer symbol)
                  (:schedule function)
                  (:hosts (choice (const :tag "All hosts" t)
                                  (repeat string))))))
  :group 'user-schedule)

;; ---------------------------------------------------------------------------
;; Task control
;; ---------------------------------------------------------------------------

(defun +wd/user-schedule--current-host-p (hosts)
  "Return t if HOSTS includes the current host.
HOSTS may be `t' (all hosts) or a list of host name strings."
  (or (eq hosts t)
      (and (listp hosts)
           (member (system-name) hosts))))

(defun +wd/user-schedule-start ()
  "Start all tasks in `+wd/user-schedule-tasks' matching the current host."
  (dolist (task +wd/user-schedule-tasks)
    (let ((name (plist-get task :name))
          (schedule-fn (plist-get task :schedule))
          (hosts (plist-get task :hosts)))
      (when (+wd/user-schedule--current-host-p hosts)
        (funcall schedule-fn)
        (message "Scheduled: %s" name)))))

(defun +wd/user-schedule-stop ()
  "Cancel all running scheduled tasks."
  (interactive)
  (dolist (task +wd/user-schedule-tasks)
    (let* ((timer-var (plist-get task :timer))
           (timer (symbol-value timer-var)))
      (when (timerp timer)
        (cancel-timer timer)
        (set timer-var nil))))
  (message "All scheduled tasks stopped"))

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(+wd/user-schedule-start)

(provide 'init-schedule)
;;; init-schedule.el ends here
