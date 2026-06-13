;;; lib-util.el --- General utilities -*- lexical-binding: t; -*-


(defun surround-quotes (&optional arg)
  "Enclose following ARG sexps in quotes.
Leave point after open-quote."
  (interactive "*P")
  (insert-pair arg ?\" ?\"))


;; open vscode in current line
(defun +wd/open-with-vscode ()
  "Open current file with vscode."
  (interactive)
  (let ((line (number-to-string (line-number-at-pos)))
        (column (number-to-string (current-column))))
    (apply 'call-process "code" nil nil nil (list (concat buffer-file-name ":" line ":" column) "--goto"))))


;; for workspace
(defun +wd/update-current-workspaces-to-saved-ones ()
  (interactive)
  (let* ((+workspaces-data-file (concat (system-name) "_workspaces"))
         (current-ws (+workspace-list-names))
         (saved-ws (persp-list-persp-names-in-file
                    (expand-file-name +workspaces-data-file persp-save-dir)))
         (intersection (cl-intersection current-ws saved-ws :test 'equal)))
    (dolist (ws intersection)
      (+workspace-save ws))))

(defcustom +wd/workspace-hourly-cleanup-pattern "^#[0-9]+$"
  "Workspace name regexp to be auto-removed hourly."
  :type 'regexp
  :group 'doom)

(defcustom +wd/workspace-hourly-cleanup-interval 3600
  "Interval in seconds for auto-removing numbered tag workspaces."
  :type 'integer
  :group 'doom)

(defvar +wd/workspace-hourly-cleanup-timer nil
  "Timer used to cleanup numbered tag workspaces hourly.")

(defun +wd/workspace-hourly-cleanup-target-p (name)
  "Return non-nil if NAME should be cleaned up."
  (and (stringp name)
       (string-match-p +wd/workspace-hourly-cleanup-pattern name)))

(defun +wd/workspace-delete-by-predicate (pred)
  "Delete all current workspaces whose names satisfy PRED.
PRED accepts one arg NAME and returns non-nil to delete."
  (let ((deleted nil)
        (keep-going t))
    ;; Re-scan after each pass to avoid missing workspaces while current
    ;; workspace changes during deletion.
    (while keep-going
      (setq keep-going nil)
      (let ((snapshot (copy-sequence (+workspace-list-names))))
        (dolist (name snapshot)
          (when (funcall pred name)
            (setq keep-going t)
            (ignore-errors
              (when (and (fboundp '+workspace-exists-p)
                         (+workspace-exists-p name)
                         (fboundp '+workspace-kill))
                (+workspace-kill name t)))
            (ignore-errors
              (when (fboundp '+workspace-delete)
                (+workspace-delete name)))
            (push name deleted)))))
    (nreverse (delete-dups deleted))))

(defun +wd/workspace-hourly-cleanup ()
  "Remove runtime/saved workspaces whose names look like #<number>."
  (interactive)
  (when (fboundp '+workspace-list-names)
    (+wd/workspace-delete-by-predicate #'+wd/workspace-hourly-cleanup-target-p)))

(defun +wd/workspace-hourly-cleanup-start ()
  "Start hourly cleanup timer for #<number> workspaces."
  (interactive)
  (when (timerp +wd/workspace-hourly-cleanup-timer)
    (cancel-timer +wd/workspace-hourly-cleanup-timer))
  (setq +wd/workspace-hourly-cleanup-timer
        (run-at-time
         +wd/workspace-hourly-cleanup-interval
         +wd/workspace-hourly-cleanup-interval
         #'+wd/workspace-hourly-cleanup)))

(provide 'lib-util)
;;; lib-util.el ends here
