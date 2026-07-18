;;; lib-org.el --- org/roam/vulpea helpers -*- lexical-binding: t; -*-

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

(defun +wd/org-count-total-update ()
  "Recompute COUNT_* stats for the current entry into its properties.

Acts only on entries carrying a `COUNT_TOTAL' property (opt-in), so it is
safe from a global hook.  Scans the entry body, skipping src blocks and
drawers (e.g. `:LOGBOOK:' CLOCK lines are metadata, not count entries):

- COUNT_TOTAL: sum of count values.  A count is the first arithmetic token
  on a line; `N*M' forms are evaluated with `calc-eval' (`x'/`×' accepted,
  the part left of any `=' is used), a bare number is taken as-is.  Tokens
  that calc cannot parse (e.g. \"...\") are skipped.
- COUNT_TIMES: number of lines that contributed a count.
- COUNT_DAYS: number of distinct `[YYYY-MM-DD]' days on lines that
  contributed a count.

Timestamps are stripped before arithmetic so dates are not counted."
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

(defun +wd/org-prepend-inactive-timestamp-to-heading ()
  "在当前 Org headline 中，在 TODO keyword 后插入 inactive timestamp（带 []）。"
  (interactive)
  (save-excursion
    (org-back-to-heading t)
    (let* ((components (org-heading-components))
           (todo (nth 2 components))
           (ts (format-time-string
                (concat "[" (cdr org-time-stamp-formats) "]")
                (current-time))))

      (beginning-of-line)
      (looking-at "^\\*+\\s-*")
      (goto-char (match-end 0))

      (when todo
        (forward-word 1)
        (skip-chars-forward " "))

      (unless (looking-at org-ts-regexp-inactive)
        (insert ts " ")))))

;; ---------------------------------------------------------------------------
;; org-agenda-work-mode: toggle work-specific agenda files and Org Roam sources
;; ---------------------------------------------------------------------------

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

(provide 'lib-org)
;;; lib-org.el ends here
