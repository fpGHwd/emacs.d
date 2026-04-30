;;; ../../Sync/dotfiles/doom.d/lib/lib-misc.el -*- lexical-binding: t; -*-


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


(defun +wd/update-bash-history (&optional args)
  "Update bash history hourly."
  (interactive)
  (let* ((dotdrop-cmd (executable-find "dotdrop"))
         (dotfiles-dir (file-truename "~/.config/dotfiles"))
         (bash-eternal-history (expand-file-name "~/.config/bash/bash_eternal_history"))
         (bash-eternal-history-dotdrop (expand-file-name (concat dotfiles-dir "config/bash/bash_eternal_history-ubuntu2004")))
         (bash-eternal-history-tmp (expand-file-name (concat dotfiles-dir "config/bash/bash_eternal_history-bak-ubuntu2004"))))
    (when dotdrop-cmd
      (let ((cmd (format "%s -c %s update --force -k f_bash_eternal_history" dotdrop-cmd (concat dotfiles-dir "dotdrop-config.yaml")))) ;; 更新的是 bak 文件
        ;; (message "%s" cmd)
        (shell-command-to-string cmd)
        (let* ((size1 (nth 7 (file-attributes bash-eternal-history-dotdrop)))
               (size2 (nth 7 (file-attributes bash-eternal-history-tmp))))
          (if (> size2 size1)
              (copy-file bash-eternal-history-tmp bash-eternal-history-dotdrop t)
            (copy-file bash-eternal-history-dotdrop bash-eternal-history t)))))))

(defun +wd/magit-push-to-gerrit (arg)
  "Push HEAD to remote branch. SAIC limited.
The `ARG` parameter is used to distinguish whether to use current branch or specify a remote branch.
1 to specify a remote branch, nil current branch to remote same branch."
  (interactive "p")
  (let* ((current-branch (magit-get-current-branch))
         (remote-name (magit-read-remote "select remote"))
         (gitlab-url (magit-get "remote" remote-name "url"))
         (gerrit-url (replace-regexp-in-string "\\(^https?://[^/]+/\\)" "\\1a/" gitlab-url))
         (remote-branch (pcase arg
                          (1 (replace-regexp-in-string ".*/" "" (magit-read-remote-branch "remote branch")))
                          (_ current-branch))))
    (magit-git-command
     (concat "git push " gerrit-url " HEAD:refs/for/" remote-branch))))



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

;; rime
(defun +wd/sync-emacs-rime-dict ()
  "Sync EMACS rime dictionary to git repository with default remote."
  (interactive)
  (let* ((rime-dir "~/.config/rime")
         (tmp-dir (concat rime-dir "/sync/tmp"))
         (tmp-file (concat tmp-dir "/rime_ice.userdb.txt"))
         (dict-file-relative "sync/rime-emacs/rime_ice.userdb.txt")
         (dict-file (concat rime-dir "/" dict-file-relative))
         (default-directory rime-dir)
         (commit-message (concat "update by elisp on " (format-time-string "%Y/%m/%d %H:%M:%S")))
         (upstream (magit-get-upstream-branch)))
    (mkdir tmp-dir t)
    (copy-file dict-file tmp-file t)
    (require 'magit)
    (magit-fetch-all-prune)           ; error handle
    (magit-reset-hard upstream)
    (rime-sync)
    (magit-stage-file dict-file-relative)
    (magit-commit-create `("--all" "-m" ,commit-message))
    (magit-push-current-to-upstream nil)))

(defun +wd/org--marker-id (source-file pos)
  (format "%s::%s" (or source-file "") pos))

(defun +wd/org--item-at-point-plist ()
  (let* ((source-file (or (buffer-file-name) ""))
         (pos (point))
         (todo (or (org-get-todo-state) ""))
         (id (or (org-id-get) "")))
    `((id . ,id)
      (marker_id . ,(+wd/org--marker-id source-file pos))
      (title . ,(org-get-heading t t t t))
      (todo_state . ,todo)
      (tags . ,(or (org-get-tags) '()))
      (scheduled . ,(org-entry-get (point) "SCHEDULED"))
      (deadline . ,(org-entry-get (point) "DEADLINE"))
      (source_file . ,source-file))))

(defun +wd/org--item-from-agenda-marker (marker)
  (when (and (markerp marker) (marker-buffer marker))
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (when (and (derived-mode-p 'org-mode)
                   (not (org-before-first-heading-p)))
          (+wd/org--item-at-point-plist))))))

(defun +wd/org--find-item-by-json (item)
  (require 'org-id)
  (let* ((marker-id (alist-get 'marker_id item nil nil #'string=))
         (id (alist-get 'id item nil nil #'string=)))
    (cond
     ((and (stringp marker-id) (string-match "^\\(.*\\)::\\([0-9]+\\)$" marker-id))
      (let* ((file (match-string 1 marker-id))
             (pos (string-to-number (match-string 2 marker-id))))
        (when (and (stringp file)
                   (> (length file) 0)
                   (file-exists-p file))
          (find-file file)
          (goto-char (min (max pos (point-min)) (point-max)))
          (when (and (derived-mode-p 'org-mode)
                     (not (org-before-first-heading-p)))
            t))))
     ((and (stringp id) (> (length id) 0))
      (let ((m (org-id-find id 'marker)))
        (when (markerp m)
          (switch-to-buffer (marker-buffer m))
          (goto-char m)
          (when (and (derived-mode-p 'org-mode)
                     (not (org-before-first-heading-p)))
            t))))
     (t nil))))

(defun +wd/org-todos-json ()
  "Return TODO items in agenda as a JSON string.

Only entries with TODO keyword exactly equal to \"TODO\" are included.
Fields: id, marker_id, title, todo_state, tags, scheduled, deadline, source_file.
Return shape: {\"count\":N,\"items\":[...]}"
  (interactive)
  (require 'json)
  (require 'org)
  (require 'org-agenda)
  (let (items)
    ;; Keep TODO extraction aligned with current sticky agenda context.
    (save-window-excursion
      (if (buffer-live-p (get-buffer org-agenda-buffer-name))
          (with-current-buffer org-agenda-buffer-name
            (org-agenda-redo))
        (org-agenda-list)))
    (org-map-entries
     (lambda ()
       (let ((todo (org-get-todo-state)))
         (when (and todo (string= todo "TODO"))
           (push (+wd/org--item-at-point-plist) items))))
     nil 'agenda)
    (json-encode
     `((count . ,(length items))
       (items . ,(nreverse items))))))

(defun +wd/org-agenda-json ()
  "Return agenda entries from the currently generated agenda view as JSON.

This follows the same window/filter as agenda UI (for example 7-day page).
Fields: id, marker_id, title, todo_state, tags, scheduled, deadline, source_file.
Return shape: {\"count\":N,\"items\":[...]}"
  (interactive)
  (require 'json)
  (require 'org)
  (require 'org-agenda)
  (let (items)
    (save-window-excursion
      ;; Sticky agenda buffers should be refreshed with `org-agenda-redo`.
      ;; Calling `org-agenda-list` again can raise:
      ;; \"Sticky agenda buffer, use 'r' to refresh\".
      (if (buffer-live-p (get-buffer org-agenda-buffer-name))
          (with-current-buffer org-agenda-buffer-name
            (org-agenda-redo))
        (org-agenda-list))
      (with-current-buffer org-agenda-buffer-name
        (save-excursion
          (goto-char (point-min))
          (while (< (point) (point-max))
            (let* ((marker (or (get-text-property (point) 'org-hd-marker)
                               (get-text-property (point) 'org-marker)))
                   (item (+wd/org--item-from-agenda-marker marker)))
              (when item
                (push item items)))
            (forward-line 1)))))
    (json-encode
     `((count . ,(length items))
       (items . ,(nreverse items))))))

(defun +wd/org-item-schedule-json (item-json schedule-spec)
  "Schedule org item from ITEM-JSON and return operation result as JSON."
  (interactive "sitem-json: \nschedule: ")
  (require 'json)
  (require 'org)
  (require 'org-id)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (let* ((id (or (org-id-get) (org-id-get-create))))
            (org-schedule nil schedule-spec)
            (save-buffer)
            (json-encode `((ok . t)
                           (message . "scheduled")
                           (item . ,(+wd/org--item-at-point-plist)))))))
    (error
     (json-encode `((ok . :json-false)
                    (message . ,(format "%s" err))
                    (item . nil))))))

(defun +wd/org-item-todo-json (item-json todo-state)
  "Set TODO state for org item from ITEM-JSON and return operation result as JSON."
  (interactive "sitem-json: \nstate: ")
  (require 'json)
  (require 'org)
  (require 'org-id)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (progn
            (or (org-id-get) (org-id-get-create))
            (org-todo todo-state)
            (save-buffer)
            (json-encode `((ok . t)
                           (message . "todo state updated")
                           (item . ,(+wd/org--item-at-point-plist)))))))
    (error
     (json-encode `((ok . :json-false)
                    (message . ,(format "%s" err))
                    (item . nil))))))

(provide 'lib-misc)
