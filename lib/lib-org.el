;;; /home/wd/.config/dotfiles/doom.d/lib/lib-init-roam.el -*- lexical-binding: t; -*-

(require 'vulpea)

;; dynamic agenda https://github.com/brianmcgillion/doomd/blob/master/config.org
;; https://d12frosted.io/posts/2021-01-16-task-management-with-roam-vol5.html
;; The 'roam-agenda' tag is used to tell vulpea that there is a todo item in this file
(defun vulpea-buffer-p ()
  "Return non-nil if the currently visited buffer is a note."
  (and buffer-file-name
       (or (string-prefix-p
            (expand-file-name (file-name-as-directory "~/org/roam"))
            (file-name-directory buffer-file-name))
           (string-prefix-p
            (expand-file-name (file-name-as-directory "~/org/work/zone/roam"))
            (file-name-directory buffer-file-name)))))

(defun vulpea-project-p ()
  "Return non-nil if current buffer has any todo entry.

TODO entries marked as done are ignored, meaning the this
function returns nil if current buffer contains only completed
tasks.

Return t if active SCHEDULED/DEADLINE in property within a headline."
  (or (seq-find                       ; (3)
       (lambda (type)
         (eq type 'todo))
       (org-element-map                         ; (2)
           (org-element-parse-buffer 'headline) ; (1)
           'headline
         (lambda (h)
           (org-element-property :todo-type h))))
      (seq-find
       (lambda (type)
         (and (or (eq (org-element-property :type (nth 0 type)) 'active)
                  (eq (org-element-property :type (nth 0 type)) 'active-range)
                  (eq (org-element-property :type (nth 1 type)) 'active)
                  (eq (org-element-property :type (nth 1 type)) 'active-range))
              (not (nth 2 type))))
       (org-element-map
           (org-element-parse-buffer 'headline)
           'headline
         (lambda (h)
           (list (org-element-property :scheduled h)
                 (org-element-property :deadline h)
                 (org-element-property :closed h)))))))

(defun vulpea-project-update-tag (&optional arg)
  "Update PROJECT tag in the current buffer."
  (interactive "P")
  (when (and (not (active-minibuffer-window))
             (vulpea-buffer-p))
    (save-excursion
      (goto-char (point-min))
      (let* ((tags (vulpea-buffer-tags-get))
             (original-tags tags))
        (if (vulpea-project-p)
            (setq tags (cons "roam-agenda" tags))
          (setq tags (remove "roam-agenda" tags)))

        ;; cleanup duplicates
        (setq tags (seq-uniq tags))

        ;; update tags if changed
        (when (or (seq-difference tags original-tags)
                  (seq-difference original-tags tags))
          (apply #'vulpea-buffer-tags-set tags))))))

;; https://systemcrafters.net/build-a-second-brain-in-emacs/5-org-roam-hacks/
(defun my/org-roam-filter-by-tag (tag-name)
  (lambda (node)
    (member tag-name (org-roam-node-tags node))))

(defun my/org-roam-list-notes-by-tag (tag-name)
  (mapcar #'org-roam-node-file
          (seq-filter
           (my/org-roam-filter-by-tag tag-name)
           (org-roam-node-list))))

(defun dynamic-agenda-files-advice (orig-val)
  (let ((roam-agenda-files (delete-dups (my/org-roam-list-notes-by-tag "roam-agenda"))))
    (cl-union orig-val roam-agenda-files :test #'equal)))

(defun blog-post (title)
  (interactive "sEnter title: ")
  (let ((post-file (concat "~/org/blog/current/posts/"
                           (format-time-string "%Y-%m-%d")
                           "-"
                           title
                           ".org")))
    (progn
      (switch-to-buffer (find-file-noselect post-file))
      (insert (concat "#+startup: showall\n"
                      "#+options: toc:nil\n"
                      "#+begin_export html\n"
                      "---\n"
                      "layout     : post\n"
                      "title      : \n"
                      "categories : \n"
                      "tags       : \n"
                      "date       : \"" (format-time-string "%Y-%m-%d %H:%M:%S") "\"\n"
                      "---\n"
                      "#+end_export\n"
                      "#+TOC: headlines 2\n")))))

;; publish (project for blog)
(defun publish-project (project no-cache)
  (interactive "sName of project: \nsNo-cache?[y/n] ")
  (if (or (string= no-cache "y")
          (string= no-cache "Y"))
      (setq org-publish-use-timestamps-flag nil))
  (org-publish-project project)
  (setq org-publish-use-timestamps-flag t))

(defun +wd/handle-image-in-markdown (origin-path markdown-path)
  (interactive "fOrigin path: \nfMarkdown path: ") ; for debug
  (let* ((hakyll-root-path "/home/wd/projects/2025/hakyll"))
    (with-temp-buffer
      (insert-file-contents markdown-path)
      (goto-char (point-min))
      (while (re-search-forward "\\(.+?\\)(\\(.+\\.png\\))" nil t)
        (let* ((image-src-path (string-remove-prefix "file://" (match-string 2)))
               (org-attach-path org-attach-directory)
               (image-deploy-prefix (concat hakyll-root-path "/images/org-attach"))
               (image-attach-relative-path (string-remove-prefix org-attach-path image-src-path))
               (image-ref-link (concat "/images/org-attach" image-attach-relative-path))
               (image-deploy-path (concat image-deploy-prefix image-attach-relative-path))
               (image-handle-cmd (concat (executable-find "magick") " "
                                         image-src-path " -strip -resize 50% -quality 50% "
                                         image-deploy-path)))
          (unless (f-exists-p (file-name-directory image-deploy-path))
            (make-directory (file-name-directory image-deploy-path) t))
          (replace-match image-ref-link nil nil nil 2)
          (unless (file-exists-p image-deploy-path)
            (shell-command image-handle-cmd nil))))
      (write-region (point-min) (point-max) markdown-path))))


(defun my/hakyll-site-build-async ()
  "Run hakyll-site-build asynchronously."
  (interactive)
  (let ((default-directory "~/org/blog/"))
    (make-process
     :name "hakyll-build"
     :buffer "*hakyll-build*"
     :command '("hakyll-site-build")
     :sentinel
     (lambda (proc event)
       (when (string= event "finished\n")
         (message "Hakyll build finished ✅"))))))


(defun my/org-insert-updated-timestamp (backend)
  "Insert/update #+LAST_MODIFIED line before export."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^updated    :.*$" nil t)
        (replace-match (concat "updated    : \"" (format-time-string "%Y-%m-%d %H:%M:%S") "\""))
      (when (re-search-forward "^---\n#\\+end_export$" nil t)
        (beginning-of-line)
        (forward-line -1)
        (open-line 1)
        (insert (concat "updated    : \"" (format-time-string "%Y-%m-%d %H:%M:%S") "\""))))))


(defun my--diary-chinese-anniversary (lunar-month lunar-day &optional year mark)
  (if year
      (let* ((d-date (diary-make-date lunar-month lunar-day year))
             (a-date (calendar-absolute-from-gregorian d-date))
             (c-date (calendar-chinese-from-absolute a-date))
             (cycle (car c-date))
             (yy (cadr c-date))
             (y (+ (* 100 cycle) yy)))
        (diary-chinese-anniversary lunar-month lunar-day y mark))
    (diary-chinese-anniversary lunar-month lunar-day year mark)))

(defun +wd/org-split-string (string &optional separators)
  "Splits STRING into substrings at SEPARATORS.

SEPARATORS is a regular expression.  When nil, it defaults to
\"[ \f\t\n\r\v]+\".

Unlike `split-string', matching SEPARATORS at the beginning and
end of string are ignored."
  (let ((separators (or separators "[ \f\t\n\r\v]+")))
    (if (not (string-match separators string)) (list string)
      (let ((i (match-end 0))
            (results
             (and (/= 0 (match-beginning 0)) ;skip leading separator
                  (list (substring string 0 (match-beginning 0))))))
        (while (string-match separators string i)
          (push (substring string (- i 1) i) results) ; 将 seperator 添加进去
          (push (substring string i (match-beginning 0))
                results)
          (setq i (match-end 0)))
        (push (substring string (- i 1) i) results) ; 增加最后的 seperator
        (nreverse (if (= i (length string))
                      results         ;skip trailing separator
                    (cons (substring string i) results)))))))

;; copy link from org-link
;; https ://emacs.stackexchange.com/questions/3981/how-to-copy-links-out-of-org-mode
(defun +wd/org-link-copy (&optional arg)
  "Extract URL from org-mode link and add it to kill ring."
  (interactive "P")
  (let* ((link (org-element-lineage (org-element-context) '(link) t))
         (type (org-element-property :type link))
         (url (org-element-property :path link))
         (url (concat type ":" url)))
    (kill-new url)
    (message (concat "Copied URL: " url))))


(defun +wd/org-search-by-tags (org-match-string)
  "Use ORG-MATCH-STRING within org and roam files, via `org-search-view`."
  (let* ((tag-operator-list (+wd/org-split-string org-match-string "[+|-]"))
         (search-string "-{^\\\*+ \\(KILL\\|DONE\\|\\[X\\]\\).*}")
         (last-operator nil)
         (or-regex-str "+{\\(\\)}")
         (or-str "")
         (org-use-tag-inheritance nil))
    (dolist (elt tag-operator-list org-match-string)
      (if (or (string= elt "+") (string= elt "|") (string= elt "-"))
          (setq last-operator elt)
        (if (not (null last-operator))
            (if (or (string= last-operator "+") (string= last-operator "-"))
                (setq search-string (concat last-operator ":" elt ":"
                                            " " search-string))
              (if (string= or-str "")
                  (setq or-str (concat or-str ":" elt ":"))
                (setq or-str (concat or-str "\\|" ":" elt ":"))))
          (if (string= or-str "")
              (setq or-str (concat or-str ":" elt ":"))
            (setq or-str (concat or-str "\\|" ":" elt ":"))))))
    (setq or-regex-str (concat (substring or-regex-str 0 (- (length or-regex-str) (length "\\)}")))
                               or-str
                               (substring or-regex-str (- (length or-regex-str) (length "\\)}")))))
    (org-search-view nil (concat or-regex-str " " search-string) nil)))


;;Sunrise and Sunset
;;日出而作, 日落而息
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


(defun +wd/org--marker-id (source-file pos)
  (format "%s::%s" (or source-file "") pos))

(defun +wd/org--item-at-point-plist (&optional ensure-id)
  (require 'org-id)
  (save-excursion
    (org-back-to-heading t)
    (let* ((source-file (or (buffer-file-name) ""))
           (pos (point))
           (todo (or (org-get-todo-state) ""))
           ;; Default behavior keeps stable IDs for agenda/todo exports.
           ;; Tag search can pass ENSURE-ID=nil to avoid touching files.
           (id (if (eq ensure-id nil)
                   (or (org-id-get) "")
                 (or (org-id-get) (org-id-get-create) "")))
           (headline-line (buffer-substring-no-properties
                           (line-beginning-position)
                           (line-end-position)))
           (priority-value
            (if (and (stringp headline-line)
                     (string-match "\\[#\\([ABC]\\)\\]" headline-line))
                (match-string 1 headline-line)
              "")))
      `((id . ,id)
        (marker_id . ,(+wd/org--marker-id source-file pos))
        (headline . ,(org-get-heading t t t t))
        (keyword . ,todo)
        (priority . ,priority-value)
        (tags . ,(or (org-get-tags) (quote ())))
        (schedule . ,(org-entry-get (point) "SCHEDULED"))
        (deadline . ,(org-entry-get (point) "DEADLINE"))
        (source_file . ,source-file)))))
(defun +wd/org--item-from-agenda-marker (marker)
  (when (and (markerp marker) (marker-buffer marker))
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (when (and (derived-mode-p 'org-mode)
                   (not (org-before-first-heading-p)))
          (+wd/org--item-at-point-plist))))))

(defun +wd/org--find-item-position-by-id-in-capture-files (id)
  "Find heading by ID in capture target files and return (FILE . POS)."
  (catch 'found
    (dolist (file (list (expand-file-name +org-capture-todo-file org-directory)
                        (expand-file-name +org-capture-notes-file org-directory)
                        (expand-file-name +org-capture-journal-file)))
      (when (and (stringp file)
                 (> (length file) 0)
                 (file-exists-p file))
        (with-current-buffer (find-file-noselect file)
          (save-excursion
            (goto-char (point-min))
            (when (re-search-forward
                   (concat "^[ \t]*:ID:[ \t]*" (regexp-quote id) "[ \t]*$")
                   nil t)
              (org-back-to-heading t)
              (throw 'found (cons file (point))))))))
    nil))

(defun +wd/org--ensure-org-id-locations-hash-table ()
  "Normalize `org-id-locations' to hash-table to avoid org-id type errors."
  (when (and (boundp 'org-id-locations)
             org-id-locations
             (not (hash-table-p org-id-locations)))
    (setq org-id-locations
          (if (fboundp 'org-id-alist-to-hash)
              (org-id-alist-to-hash org-id-locations)
            (let ((ht (make-hash-table :test 'equal)))
              (dolist (pair org-id-locations)
                (when (and (consp pair) (stringp (car pair)))
                  (puthash (car pair) (cdr pair) ht)))
              ht)))))

(defun +wd/org--safe-org-id-add-location (id file)
  "Safely add ID location even when org-id cache is in legacy alist form."
  (+wd/org--ensure-org-id-locations-hash-table)
  (ignore-errors (org-id-add-location id file)))

(defun +wd/org--id-present-in-file-p (id file)
  "Return non-nil if FILE contains a heading with property ID."
  (when (and (stringp file)
             (> (length file) 0)
             (file-exists-p file))
    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (goto-char (point-min))
        (re-search-forward
         (concat "^[ \t]*:ID:[ \t]*" (regexp-quote id) "[ \t]*$")
         nil t)))))

(defun +wd/org--item-id-fast-known-p (id)
  "Return non-nil when ID can be confirmed quickly without global scan."
  (or (+wd/org--find-item-position-by-id-in-capture-files id)
      (progn
        (+wd/org--ensure-org-id-locations-hash-table)
        (let ((id-file (ignore-errors (org-id-find-id-file id))))
          (+wd/org--id-present-in-file-p id id-file)))))

(defun +wd/org--find-item-by-json (item)
  (require 'org-id)
  (require 'subr-x)
  (let* ((marker-id (alist-get 'marker_id item nil nil #'string=))
         (id (alist-get 'id item nil nil #'string=)))
    (cond
     ((and (stringp id) (> (length id) 0))
      (or
       ;; If request carries location, use it as strict tie-breaker.
       (when (and (stringp marker-id)
                  (string-match "^\\(.*\\)::\\([0-9]+\\)$" marker-id))
         (let* ((file (match-string 1 marker-id))
                (pos (string-to-number (match-string 2 marker-id))))
           (when (and (stringp file)
                      (> (length file) 0)
                      (file-exists-p file))
             (find-file file)
             (goto-char (min (max pos (point-min)) (point-max)))
             (when (and (derived-mode-p 'org-mode)
                        (not (org-before-first-heading-p))
                        (string= (or (org-entry-get (point) "ID") "") id))
               (+wd/org--safe-org-id-add-location id file)
               t))))
       ;; Fast path for freshly captured items.
       (let ((hit (+wd/org--find-item-position-by-id-in-capture-files id)))
         (when hit
           (find-file (car hit))
           (goto-char (cdr hit))
           (+wd/org--safe-org-id-add-location id (car hit))
           t))
       ;; Only do global org-id lookup when we can quickly confirm ID exists.
       (when (+wd/org--item-id-fast-known-p id)
         (let ((m (condition-case nil (org-id-find id 'marker) (error nil))))
           (when (markerp m)
             (switch-to-buffer (marker-buffer m))
             (goto-char m)
             (and (derived-mode-p 'org-mode)
                  (not (org-before-first-heading-p))))))))
     ((and (stringp marker-id) (string-match "^\\(.*\\)::\\([0-9]+\\)$" marker-id))
      (let* ((file (match-string 1 marker-id))
             (pos (string-to-number (match-string 2 marker-id))))
        (when (and (stringp file)
                   (> (length file) 0)
                   (file-exists-p file))
          (find-file file)
          (goto-char (min (max pos (point-min)) (point-max)))
          (and (derived-mode-p 'org-mode)
               (not (org-before-first-heading-p))))))
     (t nil))))
(defun +wd/org-keywords-json ()
  "Return TODO keyword sets from current org config as JSON.

Return shape: {\"all\":[...],\"not_done\":[...],\"done\":[...]}"
  (interactive)
  (require 'json)
  (require 'org)
  (let (all not-done done)
    (with-temp-buffer
      (org-mode)
      (org-set-regexps-and-options)
      (setq all (sort (delete-dups (copy-sequence org-todo-keywords-1)) #'string<)
            not-done (sort (delete-dups (copy-sequence org-not-done-keywords)) #'string<)
            done (sort (delete-dups (copy-sequence org-done-keywords)) #'string<)))
    (json-encode
     `((all . ,all)
       (not_done . ,not-done)
       (done . ,done)))))
(defun +wd/org-agenda-json (&optional mode)
  "Return agenda/todo entries as JSON.

MODE can be \"agenda\" (default) or \"todo\".
- agenda: entries from `org-agenda-list` visible view (same as agenda UI page).
- todo: entries in agenda scope whose TODO keyword is in `org-not-done-keywords`.

Fields: id, marker_id, headline, keyword, tags, schedule, deadline, source_file.
Return shape: {\"count\":N,\"items\":[...]} "
  (interactive)
  (require 'json)
  (require 'org)
  (require 'org-agenda)
  (let* ((mode-value (downcase (or mode "agenda")))
         (not-done-keys (+wd/org--not-done-keywords-from-config))
         (done-keys (+wd/org--done-keywords-from-config))
         (items nil))
    (pcase mode-value
      ("todo"
       ;; TODO mode does not need agenda buffer rebuild on every call.
       ;; Use agenda scope directly to reduce CPU cost for frequent polling.
       (org-map-entries
        (lambda ()
          (let ((todo (org-get-todo-state)))
            (when (and (stringp todo)
                       (member todo not-done-keys))
              (push (+wd/org--item-at-point-plist) items))))
        nil 'agenda))
      (_
       (save-window-excursion
         ;; Force real `org-agenda-list` content each time.
         ;; Do not reuse sticky agenda buffers from other agenda commands.
         (let ((org-agenda-sticky nil))
           (org-agenda-list))
         (with-current-buffer org-agenda-buffer-name
           (save-excursion
             (goto-char (point-min))
             (while (< (point) (point-max))
               (let* ((marker (or (get-text-property (point) 'org-hd-marker)
                                  (get-text-property (point) 'org-marker)))
                      (item (+wd/org--item-from-agenda-marker marker))
                      (todo (and item (alist-get 'keyword item nil nil #'string=))))
                 (when (and item (not (member todo done-keys)))
                   (push item items)))
               (forward-line 1)))))))
    (json-encode
     `((count . ,(length items))
       (items . ,(nreverse items))))))

(defun +wd/org-item-schedule-json (item-json schedule-spec)
  "Schedule org item from ITEM-JSON and return operation result as JSON."
  (require 'json)
  (require 'org)
  (require 'org-id)
  (require 'subr-x)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item))
             (sched (string-trim (or schedule-spec "")))
             (clear-p (or (string-empty-p sched) (string= sched "__CLEAR__"))))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (let* ((id (or (org-id-get) (org-id-get-create))))
            ;; Directly set schedule without interactive org-schedule
            (org-entry-put (point) "SCHEDULED" (if clear-p nil schedule-spec))
            (save-buffer)
            (json-encode `((ok . t)
                           (message . ,(if clear-p "schedule cleared" "scheduled"))
                           (item . ,(+wd/org--item-at-point-plist)))))))
    (error
     (json-encode `((ok . :json-false)
                    (message . ,(format "%s" err))
                    (item . nil))))))


(defun +wd/org-item-note-json (item-json note-text)
  "Add org note for item from ITEM-JSON and return operation result as JSON."
  (require 'json)
  (require 'org)
  (require 'org-id)
  (require 'subr-x)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item))
             (trimmed (string-trim (or note-text "")))
             (decoded (if (string-match-p "\\\\u[0-9a-fA-F]\\{4\\}" trimmed)
                          (json-parse-string
                           (concat "\""
                                   (replace-regexp-in-string "\"" "\\\\\"" trimmed t t)
                                   "\""))
                        trimmed)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (if (string-empty-p decoded)
              (json-encode '((ok . :json-false) (message . "note is empty") (item . nil)))
            (progn
              (or (org-id-get) (org-id-get-create))
              ;; Append note into the current entry log area without touching other content.
              (let* ((ts (format-time-string (org-time-stamp-format 'long 'inactive) (current-time)))
                     (indented (replace-regexp-in-string "\n" "\n  " decoded))
                     (note-entry (format "- Note taken on %s\n  %s\n" ts indented)))
                (save-excursion
                  (goto-char (org-log-beginning t))
                  (insert note-entry)))
              (save-buffer)
              (json-encode `((ok . t)
                             (message . "note added")
                             (item . ,(+wd/org--item-at-point-plist))))))))
    (error
     (json-encode `((ok . :json-false)
                    (message . ,(format "%s" err))
                    (item . nil))))))

(defun +wd/org-agenda-note-json (item-json note-text)
  "Alias for `+wd/org-item-note-json' for agenda action naming."
  (+wd/org-item-note-json item-json note-text))


(defun +wd/org-item-priority-json (item-json priority-value)
  "Set PRIORITY for org item from ITEM-JSON and return operation result as JSON.

PRIORITY-VALUE supports A/B/C or empty string to clear."
  (require 'json)
  (require 'org)
  (require 'org-id)
  (require 'subr-x)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item))
             (raw (string-trim (or priority-value "")))
             (prio (upcase raw)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (cond
           ((string-empty-p prio)
            (org-entry-put (point) "PRIORITY" nil)
            (save-buffer)
            (json-encode `((ok . t)
                           (message . "priority cleared")
                           (item . ,(+wd/org--item-at-point-plist)))))
           ((member prio '("A" "B" "C"))
            (org-entry-put (point) "PRIORITY" prio)
            (save-buffer)
            (json-encode `((ok . t)
                           (message . "priority updated")
                           (item . ,(+wd/org--item-at-point-plist)))))
           (t
            (json-encode '((ok . :json-false) (message . "invalid priority") (item . nil)))))))
    (error
     (json-encode `((ok . :json-false)
                    (message . ,(format "%s" err))
                    (item . nil))))))


(defun +wd/org-item-set-json (item-json todo-state priority-value schedule-spec)
  "Set TODO/PRIORITY/SCHEDULE for ITEM-JSON in one call and return JSON result.

TODO-STATE, PRIORITY-VALUE, SCHEDULE-SPEC can be empty to skip.
PRIORITY-VALUE supports A/B/C or empty string to clear."
  (require 'json)
  (require 'org)
  (require 'org-id)
  (require 'subr-x)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item))
             (state (string-trim (or todo-state "")))
             (prio-raw (string-trim (or priority-value "")))
             (prio (upcase prio-raw))
             (sched (string-trim (or schedule-spec ""))))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (progn
            (or (org-id-get) (org-id-get-create))
            (+wd/org--guard-archive-location)
            (+wd/org--call-with-safe-archive-location
             (lambda ()
               ;; Directly modify TODO state without org-todo
               (cond
                ((string= state "__SKIP__") nil)
                ((or (string= state "__CLEAR__") (string-empty-p state))
                 (org-back-to-heading t)
                 (skip-chars-forward "*+ ")
                 (when (re-search-forward org-todo-regexp (line-end-position) t)
                   (replace-match "")))
                (t
                 (org-back-to-heading t)
                 (skip-chars-forward "*+ ")
                 (if (re-search-forward org-todo-regexp (line-end-position) t)
                     (replace-match state)
                   (insert state " "))))))
            ;; Directly set priority without org-priority
            (cond
             ((or (string= prio "__SKIP__") (string-empty-p prio)) nil)
             ((string= prio "__CLEAR__") (org-entry-put (point) "PRIORITY" nil))
             ((member prio '("A" "B" "C")) (org-entry-put (point) "PRIORITY" prio))
             (t (error "invalid priority")))
            ;; Directly set schedule without org-schedule
            (cond
             ((string= sched "__SKIP__") nil)
             ((string= sched "__CLEAR__") (org-entry-put (point) "SCHEDULED" nil))
             ((string-empty-p sched) nil)
             (t (org-entry-put (point) "SCHEDULED" sched)))
            (save-buffer)
            (json-encode `((ok . t)
                           (message . "item updated")
                           (item . ,(+wd/org--item-at-point-plist)))))))
    (error
     (json-encode `((ok . :json-false)
                    (message . ,(format "%s" err))
                    (item . nil))))))

(defun +wd/org-item-todo-json (item-json todo-state)
  "Set TODO state for org item from ITEM-JSON and return operation result as JSON."
  (require 'json)
  (require 'org)
  (require 'org-id)
  (require 'subr-x)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (progn
            (or (org-id-get) (org-id-get-create))
            (+wd/org--guard-archive-location)
            (let* ((old-state (or (org-get-todo-state) ""))
                   (new-state (or todo-state ""))
                   (scheduled-raw (or (org-entry-get (point) "SCHEDULED") ""))
                   (deadline-raw (or (org-entry-get (point) "DEADLINE") ""))
                   (periodic-p (or (string-match-p "[.+]?+[0-9]+[hdwmy]" scheduled-raw)
                                   (string-match-p "[.+]?+[0-9]+[hdwmy]" deadline-raw)))
                   (transition-log-p (and periodic-p (not (string= old-state new-state)))))
              (+wd/org--call-with-safe-archive-location
               (lambda ()
                 ;; Call org-todo in non-interactive mode
                 (let ((noninteractive t)
                       (inhibit-redisplay t)
                       (org-inhibit-logging nil))
                   (condition-case err
                       (if (string-empty-p new-state)
                           ;; Clear TODO state
                           (when (org-get-todo-state)
                             (org-todo 'none))
                         ;; Set TODO state
                         (org-todo new-state))
                     (error nil)))))
              ;; For repeating entries, ensure a state log line exists when completed.
              ;; Example: - State "DONE"       from ""           [2026-04-26 Sun 16:41]
              (when transition-log-p
                (let* ((ts (format-time-string (org-time-stamp-format 'long 'inactive) (current-time)))
                       (from-label (if (string-empty-p old-state) "" old-state))
                       (to-label (if (string-empty-p new-state) "" new-state))
                       (state-line (format "- State \"%s\"       from \"%s\"           %s\n"
                                           to-label from-label ts)))
                  (save-excursion
                    (goto-char (org-log-beginning t))
                    (insert state-line))))
              (save-buffer))
            (json-encode `((ok . t)
                           (message . "todo state updated")
                           (item . ,(+wd/org--item-at-point-plist)))))))
    (error
     (json-encode `((ok . :json-false)
                    (message . ,(format "%s" err))
                    (item . nil))))))

(defun +wd/org--not-done-keywords-from-config ()
  "Return configured not-done TODO keywords, independent of runtime cache vars."
  (let (out)
    (dolist (seq org-todo-keywords)
      (let* ((parts (if (and (listp seq) (eq (car seq) 'sequence)) (cdr seq) seq))
             (left (if (member "|" parts)
                       (seq-take-while (lambda (x) (not (string= x "|"))) parts)
                     parts)))
        (dolist (kw left)
          (when (and (stringp kw) (not (string-empty-p kw)))
            (push (replace-regexp-in-string "(.*$" "" kw) out)))))
    (delete-dups (nreverse out))))

(defun +wd/org--done-keywords-from-config ()
  "Return configured done TODO keywords, independent of runtime cache vars."
  (let (out)
    (dolist (seq org-todo-keywords)
      (let* ((parts (if (and (listp seq) (eq (car seq) 'sequence)) (cdr seq) seq))
             (right (if (member "|" parts)
                        (cdr (member "|" parts))
                      nil)))
        (dolist (kw right)
          (when (and (stringp kw) (not (string-empty-p kw)))
            (push (replace-regexp-in-string "(.*$" "" kw) out)))))
    (delete-dups (nreverse out))))

(defun +wd/org-get-undone-items-with-tag (&optional tag)
  "Return org items filtered by TAG as JSON.

Include entries that are either:
1) in not-done TODO states, or
2) have no TODO keyword.

TAG can be nil/empty (no tag filter), plain tag like \"dev\", or match string like \"+dev\".
Not-done states are derived from `org-todo-keywords`.
Search scope is `agenda` files.

Return shape: {\"count\":N,\"items\":[...]}"
  (interactive)
  (require 'json)
  (require 'org)
  (require 'subr-x)
  (let* ((trimmed-tag (string-trim (or tag "")))
         (match (cond
                 ((string-empty-p trimmed-tag) nil)
                 ((string-prefix-p "+" trimmed-tag) trimmed-tag)
                 (t (concat "+" trimmed-tag))))
         (not-done-keys (+wd/org--not-done-keywords-from-config))
         (items nil))
    (let ((org-use-tag-inheritance nil))
      (org-map-entries
       (lambda ()
         (let ((todo (org-get-todo-state)))
           (when (or (null todo)
                     (string-empty-p todo)
                     (member todo not-done-keys))
             ;; Tag search is read-heavy; do not force UUID creation here.
             (push (+wd/org--item-at-point-plist nil) items))))
       match 'agenda))
    (json-encode
     `((count . ,(length items))
       (items . ,(nreverse items))))))

(defun +wd/org-ensure-id-by-marker-json (marker-id)
  "Ensure org ID for heading located by MARKER-ID and return JSON result."
  (require 'json)
  (require 'org)
  (require 'org-id)
  (condition-case err
      (progn
        (unless (and (stringp marker-id)
                     (string-match "^\\(.*\\)::\\([0-9]+\\)$" marker-id))
          (error "invalid marker_id"))
        (let* ((file (match-string 1 marker-id))
               (pos (string-to-number (match-string 2 marker-id))))
          (unless (and (stringp file) (> (length file) 0) (file-exists-p file))
            (error "marker file not found"))
          (with-current-buffer (find-file-noselect file)
            (save-excursion
              (goto-char (min (max pos (point-min)) (point-max)))
              (when (or (not (derived-mode-p 'org-mode))
                        (org-before-first-heading-p))
                (error "item not found"))
              (org-back-to-heading t)
              (let ((id (or (org-id-get) (org-id-get-create))))
                (save-buffer)
                (json-encode `((ok . t) (message . "id ensured") (id . ,id))))))))
    (error
     (json-encode `((ok . :json-false)
                    (message . ,(error-message-string err))
                    (id . nil))))))

(defun +wd/org-ensure-ids-by-markers-json (marker-ids-json)
  "Ensure org IDs for multiple headings in same file. Process high-to-low by point.
MARKER-IDS-JSON: JSON string, list of marker-id strings (format: \"file::point\")
Returns: JSON array of {markerId, newId, updatedMarkerId}."
  (require 'json)
  (require 'org)
  (require 'org-id)
  (condition-case err
      (let* ((marker-ids (json-read-from-string marker-ids-json))
             (parsed (mapcar (lambda (mid)
                               (if (string-match "^\\(.*\\)::\\([0-9]+\\)$" mid)
                                   `((marker-id . ,mid)
                                     (file . ,(match-string 1 mid))
                                     (pos . ,(string-to-number (match-string 2 mid))))
                                 (error "invalid marker_id format: %s" mid)))
                             marker-ids))
             (file (cdr (assoc 'file (car parsed))))
             (results '()))

        (unless (and (stringp file) (> (length file) 0) (file-exists-p file))
          (error "marker file not found: %s" file))

        ;; Sort by point descending (high to low) so inserted properties do not
        ;; shift positions of items that still need to be processed.
        (let ((sorted (sort parsed (lambda (a b)
                                      (> (cdr (assoc 'pos a))
                                         (cdr (assoc 'pos b)))))))
          (with-current-buffer (find-file-noselect file)
            (dolist (marker-data sorted)
              (let* ((marker-id (cdr (assoc 'marker-id marker-data)))
                     (pos (cdr (assoc 'pos marker-data)))
                     (new-id nil)
                     (updated-pos nil))
                (save-excursion
                  (goto-char (min (max pos (point-min)) (point-max)))
                  (when (or (not (derived-mode-p 'org-mode))
                            (org-before-first-heading-p))
                    (error "item not found at position %d" pos))
                  (org-back-to-heading t)
                  (setq new-id (or (org-id-get) (org-id-get-create)))
                  (save-buffer)
                  (setq updated-pos (point)))

                (push `((markerId . ,marker-id)
                        (newId . ,new-id)
                        (updatedMarkerId . ,(concat file "::" (number-to-string updated-pos))))
                      results)))))

        (json-encode (nreverse results)))
    (error
     (json-encode `((error . ,(error-message-string err)))))))

(defun +wd/org--clock-time-string (time)
  (format-time-string "[%Y-%m-%d %a %H:%M]" time))

(defun +wd/org--clock-interval-alist (start end)
  (let ((minutes (when (and start end)
                   (floor (/ (float-time (time-subtract end start)) 60.0)))))
    `((start . ,(+wd/org--clock-time-string start))
      (end . ,(and end (+wd/org--clock-time-string end)))
      (minutes . ,minutes))))

(defun +wd/org--archive-location-valid-p (loc)
  (and (stringp loc)
       (string-match-p "::" loc)))

(defun +wd/org--guard-archive-location ()
  "Normalize/repair `org-archive-location` in current buffer.
This avoids transient malformed values (e.g. propertized \"archive\")
that can break org operations."
  (let* ((raw org-archive-location)
         (clean (and (stringp raw) (substring-no-properties raw)))
         (fallback-raw (default-value 'org-archive-location))
         (fallback-clean (and (stringp fallback-raw) (substring-no-properties fallback-raw)))
         (final (cond
                 ((+wd/org--archive-location-valid-p clean) clean)
                 ((+wd/org--archive-location-valid-p fallback-clean) fallback-clean)
                 (t "%s_archive::"))))
    (setq-local org-archive-location final)))

(defun +wd/org--safe-archive-location ()
  (let* ((raw org-archive-location)
         (clean (and (stringp raw) (substring-no-properties raw)))
         (fallback-raw (default-value 'org-archive-location))
         (fallback-clean (and (stringp fallback-raw) (substring-no-properties fallback-raw))))
    (cond
     ((+wd/org--archive-location-valid-p clean) clean)
     ((+wd/org--archive-location-valid-p fallback-clean) fallback-clean)
     (t "%s_archive::"))))

(defun +wd/org--call-with-safe-archive-location (thunk)
  "Run THUNK while forcing org archive-location lookup to a safe value.
Overrides both org-get-local-archive-location and org-archive--compute-location
to handle propertized strings from fontified buffers."
  (require 'cl-lib)
  (let* ((safe (+wd/org--safe-archive-location))
         (orig-compute (symbol-function 'org-archive--compute-location)))
    (cl-letf (((symbol-function 'org-get-local-archive-location)
               (lambda (&rest _args) safe))
              ((symbol-function 'org-archive--compute-location)
               (lambda (loc)
                 (let ((clean (if (stringp loc) (substring-no-properties loc) loc)))
                   (funcall orig-compute
                            (if (+wd/org--archive-location-valid-p clean) clean safe))))))
      (funcall thunk))))

(defun +wd/org--save-buffer-without-hooks ()
  "Save current buffer while skipping save hooks for API mutations."
  (let ((before-save-hook nil)
        (after-save-hook nil)
        (write-file-functions nil)
        (write-contents-functions nil))
    (save-buffer)))

(defun +wd/org-item-clock-in-json (item-json)
  "Clock in org item from ITEM-JSON and return operation result as JSON."
  (require 'json)
  (require 'cl-lib)
  (require 'org)
  (require 'org-clock)
  (require 'org-id)
  (require 'subr-x)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (let ((target-buffer (current-buffer)))
            (unless (derived-mode-p 'org-mode)
              (error "target buffer is not org-mode"))
            (+wd/org--guard-archive-location)
            (org-back-to-heading t)
            (or (org-id-get) (org-id-get-create))
            (with-current-buffer target-buffer
              (+wd/org--guard-archive-location)
              (+wd/org--call-with-safe-archive-location
               (lambda ()
                 (with-timeout (8 (error "clock-in timeout"))
                   (let ((org-clock-in-resume t)
                         (org-clock-continuously nil)
                         (org-clock-persist-query-resume nil)
                         (org-clock-resolve-expert t)
                         (org-clock-clocked-in-display nil))
                     ;; Force non-interactive handling for dangling clocks.
                     ;; Keep 0 minutes and never block on prompt.
                     (cl-letf (((symbol-function 'read-char-exclusive) (lambda (&rest _args) ?k))
                               ((symbol-function 'read-char-choice) (lambda (&rest _args) ?k))
                               ((symbol-function 'read-number) (lambda (&rest _args) 0))
                               ((symbol-function 'read-string) (lambda (&rest _args) "0"))
                               ((symbol-function 'y-or-n-p) (lambda (&rest _args) t))
                               ((symbol-function 'yes-or-no-p) (lambda (&rest _args) t)))
                       (org-clock-in nil))))))
              (when (buffer-modified-p)
                (+wd/org--save-buffer-without-hooks)))
            (let ((clock-start-time (bound-and-true-p org-clock-start-time)))
              (json-encode
               `((ok . t)
                 (message . "clocked in")
                 (clock_interval . ,(+wd/org--clock-interval-alist clock-start-time nil))
                 (item . ,(+wd/org--item-at-point-plist))))))))
    (error
     (json-encode
      `((ok . :json-false)
        (message . ,(format "%s" err))
        (item . nil))))))

(defun +wd/org-item-clock-out-json (item-json)
  "Clock out org item from ITEM-JSON and return operation result as JSON."
  (require 'json)
  (require 'org)
  (require 'org-clock)
  (require 'org-id)
  (require 'subr-x)
  (condition-case err
      (let* ((total-start (current-time))
             (item (json-parse-string item-json :object-type 'alist :array-type 'list :null-object nil :false-object :json-false))
             (item-id (or (alist-get 'id item) ""))
             (marker-id (or (alist-get 'marker_id item) ""))
             (find-start (current-time))
             (ok (+wd/org--find-item-by-json item))
             (find-ms (floor (* 1000 (float-time (time-subtract (current-time) find-start))))))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (let ((target-buffer (current-buffer)))
            (unless (derived-mode-p 'org-mode)
              (error "target buffer is not org-mode"))
            (+wd/org--guard-archive-location)
            (org-back-to-heading t)
            (let* ((target-id (or (org-id-get) (org-id-get-create)))
                   (clock-marker (bound-and-true-p org-clock-marker)))
              (cond
               ((not (markerp clock-marker))
                (json-encode '((ok . :json-false) (message . "no active clock") (item . nil))))
               (t
                (let ((clock-id
                       (with-current-buffer (marker-buffer clock-marker)
                         (save-excursion
                           (goto-char clock-marker)
                           (or (org-id-get) "")))))
                  (if (not (string= target-id clock-id))
                      (json-encode '((ok . :json-false) (message . "active clock belongs to another item") (item . nil)))
                    (let ((clock-start-time (bound-and-true-p org-clock-start-time))
                          (clock-end-time (current-time))
                          clock-out-ms
                          save-ms)
                      (with-current-buffer target-buffer
                        (+wd/org--guard-archive-location)
                        (+wd/org--call-with-safe-archive-location
                         (lambda ()
                           (let ((clock-start (current-time)))
                             (with-timeout (8 (error "clock-out timeout"))
                               (let ((org-inhibit-logging t)
                                     (org-log-note-clock-out nil)
                                     (org-log-note-clock-in nil))
                                 (org-clock-out nil t)))
                             (setq clock-out-ms
                                   (floor (* 1000 (float-time (time-subtract (current-time) clock-start))))))))
                        (let ((save-start (current-time)))
                          (when (buffer-modified-p)
                            (+wd/org--save-buffer-without-hooks))
                          (setq save-ms
                                (floor (* 1000 (float-time (time-subtract (current-time) save-start)))))))
                      (message "[haskell-web][clock-out] id=%s marker=%s find_item_ms=%d clock_out_ms=%d save_buffer_ms=%d total_ms=%d"
                               item-id marker-id find-ms (or clock-out-ms 0) (or save-ms 0)
                               (floor (* 1000 (float-time (time-subtract (current-time) total-start)))))
                      (json-encode
                       `((ok . t)
                         (message . "clocked out")
                         (clock_interval . ,(+wd/org--clock-interval-alist clock-start-time clock-end-time))
                         (item . ,(+wd/org--item-at-point-plist)))))))))))))
    (error
     (json-encode `((ok . :json-false)
                    (message . ,(format "%s" err))
                    (item . nil))))))

(defun +wd/org-tag-stats-json ()
  "Return top 10 org tags by frequency as a JSON string."
  (require 'json)
  (condition-case err
      (let ((table (make-hash-table :test 'equal)))
        (dolist (file (org-agenda-files))
          (with-current-buffer (find-file-noselect file)
            (let ((org-use-tag-inheritance nil))
              (org-map-entries
               (lambda ()
                 (dolist (tag (org-get-tags nil t))
                   (puthash tag (1+ (gethash tag table 0)) table)))))))
        (let* ((pairs (let (result)
                        (maphash (lambda (k v) (push (cons k v) result)) table)
                        result))
               (sorted (sort pairs (lambda (a b) (> (cdr a) (cdr b)))))
               (items (mapcar (lambda (p) `((tag . ,(car p)) (count . ,(cdr p)))) sorted)))
          (json-encode `((ok . t) (message . "") (data . ,items)))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)) (data . []))))))

(defun +wd/org-prepend-under-headline (file headline entry-text)
  "Prepend ENTRY-TEXT under HEADLINE in FILE."
  (with-current-buffer (find-file-noselect file)
    (save-excursion
      (widen)
      (goto-char (point-min))
      (unless (re-search-forward (concat "^\\* " (regexp-quote headline) "\\s-*$") nil t)
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (insert "* " headline "\n"))
      (forward-line 1)
      (insert entry-text))
    (let ((coding-system-for-write 'utf-8))
      (save-buffer))))

(defun +wd/org-format-tags (tags)
  "Format TAGS list as org tag string like :tag1:tag2: or empty string."
  (if (and tags (not (null tags)))
      (concat " :" (mapconcat #'identity tags ":") ":")
    ""))

(defun +wd/org-capture-todo-json (title body tags &optional client-request-id)
  "Capture a TODO with TITLE, BODY and TAGS to org todo inbox. Return JSON string."
  (require 'json)
  (require 'org-id)
  (condition-case err
      (let* ((file (expand-file-name +org-capture-todo-file org-directory))
             (id-str (and (stringp client-request-id)
                          (not (string-empty-p (string-trim client-request-id)))
                          (string-trim client-request-id)))
             (tag-str (+wd/org-format-tags tags))
             (entry (concat "** [ ] " title tag-str "\n"
                            (if id-str
                                (concat ":PROPERTIES:\n:ID: " id-str "\n:END:\n")
                              "")
                            (if (string-empty-p body) "" (concat body "\n"))
                            "\n"))
             item)
        (+wd/org-prepend-under-headline file "Inbox" entry)
        (with-current-buffer (find-file-noselect file)
          (save-excursion
            (widen)
            (goto-char (point-min))
            (when (re-search-forward (concat "^\\* Inbox\\s-*$") nil t)
              (forward-line 1)
              (when id-str
                (+wd/org--safe-org-id-add-location id-str file))
              (setq item (+wd/org--item-at-point-plist t)))))
        (json-encode `((ok . t) (message . "todo captured") (item . ,item))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)))))))

(defun +wd/org-capture-notes-json (title body tags &optional client-request-id)
  "Capture a note with TITLE, BODY and TAGS to org notes inbox. Return JSON string."
  (require 'json)
  (require 'org-id)
  (condition-case err
      (let* ((file (expand-file-name +org-capture-notes-file org-directory))
             (date-stamp (format-time-string "[%Y-%m-%d %a]"))
             (id-str (and (stringp client-request-id)
                          (not (string-empty-p (string-trim client-request-id)))
                          (string-trim client-request-id)))
             (tag-str (+wd/org-format-tags tags))
             (entry (concat "** " date-stamp " " title tag-str "\n"
                            (if id-str
                                (concat ":PROPERTIES:\n:ID: " id-str "\n:END:\n")
                              "")
                            (if (string-empty-p body) "" (concat body "\n"))
                            "\n"))
             item)
        (+wd/org-prepend-under-headline file "Inbox" entry)
        (with-current-buffer (find-file-noselect file)
          (save-excursion
            (widen)
            (goto-char (point-min))
            (when (re-search-forward (concat "^\\* Inbox\\s-*$") nil t)
              (forward-line 1)
              (when id-str
                (+wd/org--safe-org-id-add-location id-str file))
              (setq item (+wd/org--item-at-point-plist t)))))
        (json-encode `((ok . t) (message . "note captured") (item . ,item))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)))))))

(defun +wd/org-capture-journal-json (title body tags &optional client-request-id)
  "Capture a journal entry under today's datetree in the journal file."
  (require 'json)
  (require 'org-id)
  (require 'org-datetree)
  (condition-case err
      (let* ((file (expand-file-name +org-capture-journal-file))
             (now (current-time))
             (timestamp (format-time-string "[%Y-%m-%d %a %H:%M]" now))
             (id-str (and (stringp client-request-id)
                          (not (string-empty-p (string-trim client-request-id)))
                          (string-trim client-request-id)))
             (tag-str (+wd/org-format-tags tags))
             (entry (concat "**** " timestamp " " title tag-str "\n"
                            (if id-str
                                (concat ":PROPERTIES:\n:ID: " id-str "\n:END:\n")
                              "")
                            (if (string-empty-p body) "" (concat body "\n"))
                            "\n"))
             item)
        (with-current-buffer (find-file-noselect file)
          (save-excursion
            (widen)
            (org-datetree-find-date-create
             (calendar-gregorian-from-absolute
              (time-to-days now)))
            (forward-line 1)
            (let ((insert-pos (point)))
              (insert entry)
              (goto-char insert-pos)
              (when id-str
                (+wd/org--safe-org-id-add-location id-str file))
              (setq item (+wd/org--item-at-point-plist t))))
          (let ((coding-system-for-write 'utf-8))
            (save-buffer)))
        (json-encode `((ok . t) (message . "journal captured") (item . ,item))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)))))))


;;; ---------------------------------------------------------------------------
;;; Item detail read / edit
;;; ---------------------------------------------------------------------------

(defun +wd/org--entry-body-text ()
  "Return the plain-text body of the entry at point.
Skips the heading line, planning lines, property drawers, and logbook.
Stops before the first child heading."
  (save-excursion
    (org-back-to-heading t)
    ;; org-end-of-meta-data with t skips properties, clocks, logbook
    (org-end-of-meta-data t)
    (let ((start (point))
          (limit (save-excursion (org-end-of-subtree t) (point))))
      ;; Stop at first child heading
      (let ((end (save-excursion
                   (if (re-search-forward "^\\*+ " limit t)
                       (line-beginning-position)
                     limit))))
        (string-trim (buffer-substring-no-properties start end))))))

(defun +wd/org--direct-children-plist ()
  "Return a list of item plists for direct children of the heading at point."
  (save-excursion
    (org-back-to-heading t)
    (let (result)
      (when (org-goto-first-child)
        (push (+wd/org--item-at-point-plist) result)
        (while (org-get-next-sibling)
          (push (+wd/org--item-at-point-plist) result)))
      (nreverse result))))

(defun +wd/org--direct-children-ids ()
  "Return direct child IDs for the heading at point."
  (let ((children (+wd/org--direct-children-plist))
        ids)
    (dolist (child children)
      (let ((id (alist-get 'id child nil nil #'string=)))
        (when (and (stringp id) (> (length id) 0))
          (push id ids))))
    (nreverse ids)))

(defun +wd/org--entry-properties-alist ()
  "Return user-facing properties for the entry at point."
  (let ((props (org-entry-properties (point) 'standard))
        out)
    (dolist (kv props)
      (let ((k (car kv))
            (v (cdr kv)))
        (unless (member k '("CATEGORY" "ALLTAGS" "BLOCKED" "FILE" "PRIORITY" "ITEM" "TODO"))
          (push (cons (downcase k) (or v "")) out))))
    (nreverse out)))

(defun +wd/org--clock-duration-minutes (start-raw end-raw fallback)
  "Parse clock duration in minutes from START-RAW/END-RAW or FALLBACK."
  (or
   (condition-case nil
       (let* ((start-time (org-time-string-to-time start-raw))
              (end-time (org-time-string-to-time end-raw))
              (seconds (float-time (time-subtract end-time start-time))))
         (max 0 (truncate (/ seconds 60.0))))
     (error nil))
   (when (and (stringp fallback)
              (string-match "^\\([0-9]+\\):\\([0-9][0-9]\\)$" fallback))
     (+ (* 60 (string-to-number (match-string 1 fallback)))
        (string-to-number (match-string 2 fallback))))
   0))

(defun +wd/org--clock-entries ()
  "Return CLOCK entries for the full subtree at point (current heading + descendants)."
  (save-excursion
    (org-back-to-heading t)
    (let ((limit (save-excursion (org-end-of-subtree t) (point)))
          entries)
      (forward-line 1)
      (while (re-search-forward
              "^[ \t]*CLOCK:[ \t]*\\(\\[[^]]+\\]\\)--\\(\\[[^]]+\\]\\)\\(?:[ \t]*=>[ \t]*\\([0-9]+:[0-9][0-9]\\)\\)?"
              limit t)
        (let* ((start-raw (match-string 1))
               (end-raw (match-string 2))
               (fallback (match-string 3))
               (raw (string-trim (buffer-substring-no-properties
                                  (line-beginning-position)
                                  (line-end-position)))))
          (push `((start . ,start-raw)
                  (end . ,end-raw)
                  (duration_minutes . ,(+wd/org--clock-duration-minutes start-raw end-raw fallback))
                  (raw . ,raw))
                entries)))
      (nreverse entries))))

(defun +wd/org--logbook-entries ()
  "Return structured CLOCK entries from current heading's LOGBOOK drawer only."
  (save-excursion
    (org-back-to-heading t)
    (let* ((meta-limit (save-excursion (org-end-of-meta-data t) (point)))
           (body-start (save-excursion (forward-line 1) (point)))
           entries)
      (goto-char body-start)
      (when (re-search-forward "^[ \t]*:LOGBOOK:[ \t]*$" meta-limit t)
        (let ((drawer-start (line-end-position))
              drawer-end)
          (when (re-search-forward "^[ \t]*:END:[ \t]*$" meta-limit t)
            (setq drawer-end (line-beginning-position))
            (goto-char drawer-start)
            (while (re-search-forward
                    "^[ \t]*CLOCK:[ \t]*\\(\\[[^]]+\\]\\)--\\(\\[[^]]+\\]\\)\\(?:[ \t]*=>[ \t]*\\([0-9]+:[0-9][0-9]\\)\\)?"
                    drawer-end t)
              (let ((start-raw (match-string 1))
                    (end-raw (match-string 2))
                    (fallback (match-string 3)))
                (push `((start . ,start-raw)
                        (end . ,end-raw)
                        (duration_minutes . ,(+wd/org--clock-duration-minutes start-raw end-raw fallback)))
                      entries))))))
      (nreverse entries))))

(defun +wd/org-item-get-detail-json (item-json)
  "Return full detail of an item: heading, body, and direct children."
  (require 'json)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list
                                      :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (data . nil)))
          (let* ((base (+wd/org--item-at-point-plist))
                 (body (+wd/org--entry-body-text))
                 (children (+wd/org--direct-children-plist))
                 (children-ids (+wd/org--direct-children-ids))
                 (properties (+wd/org--entry-properties-alist))
                 (clock-entries (+wd/org--clock-entries))
                 (logbook (+wd/org--logbook-entries))
                 (pos (point))
                 (id (alist-get 'id base nil nil #'string=))
                 (source-file (alist-get 'source_file base nil nil #'string=))
                 (heading (alist-get 'headline base nil nil #'string=))
                 (todo (alist-get 'keyword base nil nil #'string=))
                 (priority (alist-get 'priority base nil nil #'string=))
                 (tags (alist-get 'tags base nil nil #'string=))
                 (scheduled (alist-get 'schedule base nil nil #'string=))
                 (deadline (alist-get 'deadline base nil nil #'string=))
                 (level (org-current-level)))
            (json-encode `((ok . t)
                           (message . "")
                           (data . ((item . ,base)
                                    (body . ,body)
                                    (children . ,children)
                                    (id . ,id)
                                    (file . ,source-file)
                                    (pos . ,pos)
                                    (level . ,level)
                                    (headline . ,heading)
                                    (keyword . ,todo)
                                    (priority . ,priority)
                                    (tags . ,tags)
                                    (schedule . ,scheduled)
                                    (deadline . ,deadline)
                                    (properties . ,properties)
                                    (children_ids . ,children-ids)
                                    (clock_entries . ,clock-entries)
                                    (logbook . ,logbook))))))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)) (data . nil))))))

(defun +wd/org-item-set-heading-json (item-json new-heading)
  "Replace the heading text of an item (preserving todo, priority, tags)."
  (require 'json)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list
                                      :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (org-edit-headline new-heading)
          (save-buffer)
          (json-encode `((ok . t)
                         (message . "heading updated")
                         (item . ,(+wd/org--item-at-point-plist))))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)) (item . nil))))))

(defun +wd/org-item-set-body-json (item-json body-text)
  "Replace the body content of an item (text after metadata, before children)."
  (require 'json)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list
                                      :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (org-back-to-heading t)
          (org-end-of-meta-data t)
          (let* ((start (point))
                 (limit (save-excursion (org-end-of-subtree t) (point)))
                 (end (save-excursion
                        (if (re-search-forward "^\\*+ " limit t)
                            (line-beginning-position)
                          limit))))
            (delete-region start end)
            (unless (string-empty-p (string-trim body-text))
              (insert (string-trim body-text) "\n")))
          (save-buffer)
          (json-encode `((ok . t)
                         (message . "body updated")
                         (item . ,(+wd/org--item-at-point-plist))))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)) (item . nil))))))

(defun +wd/org-item-set-tags-json (item-json tags-json)
  "Replace tags of an item with TAGS-JSON array."
  (require 'json)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list
                                      :null-object nil :false-object :json-false))
             (tags (json-parse-string tags-json :object-type 'alist :array-type 'list
                                      :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item))
             (normalized-tags (seq-filter #'stringp tags)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (org-back-to-heading t)
          (org-set-tags normalized-tags)
          (save-buffer)
          (json-encode `((ok . t)
                         (message . "tags updated")
                         (item . ,(+wd/org--item-at-point-plist))))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)) (item . nil))))))

(defun +wd/org-item-add-child-json (item-json child-json)
  "Add a child heading under the item at point.
CHILD-JSON: {\"heading\":\"...\",\"keyword\":\"TODO\",\"body\":\"...\"}"
  (require 'json)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list
                                      :null-object nil :false-object :json-false))
             (child (json-parse-string child-json :object-type 'alist :array-type 'list
                                       :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (let* ((level (org-current-level))
                 (stars (make-string (1+ level) ?*))
                 (todo (or (alist-get 'keyword child nil nil #'string=) ""))
                 (heading (or (alist-get 'heading child nil nil #'string=) ""))
                 (body (or (alist-get 'body child nil nil #'string=) ""))
                 (heading-line (concat stars
                                       (if (string-empty-p todo) "" (concat " " todo))
                                       " " heading "\n"))
                 (body-line (if (string-empty-p (string-trim body)) ""
                              (concat (string-trim body) "\n"))))
            (org-end-of-subtree t t)
            (insert heading-line body-line)
            (save-buffer)
            (json-encode `((ok . t)
                           (message . "child added")
                           (item . ,(+wd/org--item-at-point-plist)))))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)) (item . nil))))))


(defun +wd/org-item-delete-json (item-json)
  "Delete an item and its subtree."
  (require 'json)
  (condition-case err
      (let* ((item (json-parse-string item-json :object-type 'alist :array-type 'list
                                      :null-object nil :false-object :json-false))
             (ok (+wd/org--find-item-by-json item)))
        (if (not ok)
            (json-encode '((ok . :json-false) (message . "item not found") (item . nil)))
          (org-cut-subtree)
          (save-buffer)
          (json-encode '((ok . t) (message . "item deleted") (item . nil)))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)) (item . nil))))))


(defun +wd/org-mode-restart-json ()
  "Restart org-mode runtime state and return JSON result."
  (require 'json)
  (condition-case err
      (progn
        (org-mode-restart)
        (json-encode '((ok . t) (message . "org restarted") (item . nil))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)) (item . nil))))))


(defun +wd/org-capture-extension-url-json (file entry-text)
  "Prepend extension URL capture ENTRY-TEXT under * Inbox for iOS in FILE."
  (require 'json)
  (condition-case err
      (progn
        (+wd/org-prepend-under-headline file "Inbox for iOS" entry-text)
        (json-encode '((ok . t) (message . "capture inserted"))))
    (error
     (json-encode `((ok . :json-false) (message . ,(format "%s" err)))))))

(provide 'lib-org)
