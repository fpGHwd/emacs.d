;;; lib-read.el --- org-noter / calibre reading integration -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'json)
(require 'org)
(require 'seq)
(require 'subr-x)
(require 'org-noter)

;; calibredb / org-noter are loaded lazily; declare what we call at runtime.
(defvar calibredb-root-dir)
(defvar calibredb-library-alist)
(defvar calibredb-opds-download-dir)
(defvar org-noter-notes-search-path)
(defvar org-noter-property-doc-file)
(defvar org-noter-get-buffer-file-name-hook)
(defvar org-noter--start-location-override)
(declare-function password-store-get "password-store")
(declare-function calibredb-getattr "calibredb-core")
(declare-function calibredb-find-candidate-at-point "calibredb-utils")
(declare-function calibredb-opds-request-page "calibredb-opds")
(declare-function calibredb-opds-request-search-page "calibredb-opds")
(declare-function calibredb-opds-download "calibredb-opds")
(declare-function org-noter "org-noter")
(declare-function org-noter--doc-approx-location "org-noter-core")

;;; calibredb Digest auth advices
;;
;; Calibre content server requires HTTP Digest authentication, but calibredb
;; hardcodes Basic auth (or no auth).  Three advices patch the OPDS workflow:
;;
;; 1. `calibredb-opds-request-page' — inject `curl --digest --user' via
;;    `request-curl-options' so page listings authenticate correctly.
;;
;; 2. `calibredb-opds-request-search-page' — calibredb GETs the raw
;;    {searchTerms} template URL (returns 404).  This advice substitutes
;;    the actual keyword and delegates to `calibredb-opds-request-page'
;;    (which already carries Digest auth).
;;
;; 3. `calibredb-opds-download' — calibredb shells out to `curl -u' (Basic);
;;    this advice rewrites it to `curl --digest -u' so book downloads work.

(defun +wd/calibredb-opds-request-page--digest-auth (oldfn url &optional account password)
  "Advice around `calibredb-opds-request-page': use Digest auth.
calibredb hardcodes Basic auth; Calibre content server requires Digest."
  (let* ((info (cdr (assoc calibredb-root-dir calibredb-library-alist)))
         (account (or account (alist-get 'account info)))
         (password (or password (alist-get 'password info))))
    (if (and account password)
        (let* ((_ (defvar request-curl-options nil))
               (request-curl-options
                (list "--digest" "--user" (format "%s:%s" account password))))
          (funcall oldfn url))
      (funcall oldfn url account password))))

(defun +wd/calibredb-opds-request-search-page--digest-auth (oldfn url keyword &rest _)
  "Advice around `calibredb-opds-request-search-page': substitute keyword directly.
calibredb tries to GET the raw {searchTerms} template URL which Calibre returns
404 for.  Bypass it: substitute the keyword and call `calibredb-opds-request-page'
(which already handles Digest auth via its own advice)."
  (let ((search-url (replace-regexp-in-string "{[^}]*}" (url-hexify-string keyword) url)))
    (calibredb-opds-request-page search-url)))

(defun +wd/calibredb-opds-download--digest-auth (oldfn title url fmt &optional account password)
  "Advice around `calibredb-opds-download': add --digest to curl.
calibredb uses `curl -u' (Basic); Calibre requires `curl --digest -u'."
  (cl-letf* ((orig (symbol-function 'start-process-shell-command))
             ((symbol-function 'start-process-shell-command)
              (lambda (name buf cmd &rest args)
                (apply orig name buf
                       (replace-regexp-in-string "curl -u" "curl --digest -u" cmd)
                       args))))
    (funcall oldfn title url fmt account password)))

;;; calibre: OPDS download, unified CDB-<id>.org, open in org-noter

(defun +wd/calibre--entry-id (entry)
  "Return the calibre numeric id (string) for calibredb ENTRY, or nil.
The id lives inside the OPDS acquisition URL `.../get/<fmt>/<id>/...'."
  (let ((path (and entry (calibredb-getattr entry :file-path))))
    (when (and (stringp path)
               (string-match "/get/[^/]+/\\([0-9]+\\)/" path))
      (match-string 1 path))))

(defun +wd/calibre--download (title url format)
  "Download URL to <download-dir>/TITLE.FORMAT and return the path, or nil.
Cached: if the target already exists it is returned without re-downloading.
Uses Digest auth with the account/password stored in `calibredb-library-alist'."
  (let* ((file (expand-file-name (format "%s.%s" title format)
                                 calibredb-opds-download-dir))
         (info (cdr (assoc calibredb-root-dir calibredb-library-alist)))
         (account (alist-get 'account info))
         (password (alist-get 'password info))
         (args (append '("--digest" "-fsL")
                       (when (and account password)
                         (list "--user" (format "%s:%s" account password)))
                       (list url "-o" file))))
    (make-directory calibredb-opds-download-dir t)
    (cond
     ((file-exists-p file) file)
     ((and (eq 0 (apply #'call-process "curl" nil nil nil args))
           (file-exists-p file))
      file))))

(defun +wd/calibre--ensure-note-file (id title author doc-name url)
  "Ensure CDB-ID.org exists in the org-noter notes dir; return its path.
When absent, pre-create it with a `* TITLE - AUTHOR' heading and the
properties `:NOTER_DOCUMENT: DOC-NAME' (a bare download filename, not an
absolute path, so the notes file stays portable), `:CALIBRE_ID: ID' and
`:CALIBRE_URL: URL' (the OPDS acquisition URL used to re-download the
document on any machine).  This is the single place the unified notes
format is written."
  (let* ((notes-dir (or (car org-noter-notes-search-path)
                        (expand-file-name "~/org/noter/current")))
         (note (expand-file-name (format "CDB-%s.org" id) notes-dir)))
    (make-directory notes-dir t)
    (unless (file-exists-p note)
      (with-temp-file note
        (insert (format "* %s - %s\n:PROPERTIES:\n:NOTER_DOCUMENT: %s\n:CALIBRE_ID: %s\n:CALIBRE_URL: %s\n:END:\n"
                        (or title "Unknown") (or author "Unknown")
                        doc-name id url))))
    note))

(defun +wd/calibredb-org-noter ()
  "Create a unified CDB-<id>.org for the calibre book at point and open it.
Read id/title/author and the OPDS acquisition URL from the calibredb entry
and write the notes file directly from that metadata — the document is NOT
downloaded here; it is fetched lazily by the resolvers on
`org-noter-parse-document-property-hook' when the session opens."
  (interactive)
  (let* ((entry (car (calibredb-find-candidate-at-point)))
         (id (+wd/calibre--entry-id entry))
         (title (calibredb-getattr entry :book-title))
         (author (calibredb-getattr entry :author-sort))
         (url (calibredb-getattr entry :file-path))
         (fmt (and (stringp url)
                   (string-match "/get/\\([^/]+\\)/" url)
                   (match-string 1 url)))
         (doc-name (if fmt (format "%s.%s" title fmt) title)))
    (unless id
      (user-error "No calibre id for entry at point"))
    (find-file (+wd/calibre--ensure-note-file id title author doc-name url))
    (org-noter)))

;;; org-noter document resolution — resolvers tried in order via
;;; `org-noter-parse-document-property-hook' (run-hook-with-args-until-success).
;;; Each takes the NOTER_DOCUMENT string and returns an openable path or nil.

(defun +wd/org-noter--document-file-name (&optional document-file-name)
  "Return the current org-noter document file name."
  (or (run-hook-with-args-until-success 'org-noter-get-buffer-file-name-hook
                                        major-mode)
      document-file-name
      buffer-file-truename
      buffer-file-name))

(defun +wd/org-noter--matching-document-property-p (document-name)
  "Return non-nil if point is on a matching `NOTER_DOCUMENT' property."
  (let ((noter-document (string-trim (match-string 3))))
    (string= document-name (file-name-nondirectory noter-document))))

(defun +wd/org-noter-find-note-by-document-name (document-path)
  "Find a notes file under `~/org/noter/' for DOCUMENT-PATH.
Match by comparing DOCUMENT-PATH's file name with the file name part of each
`NOTER_DOCUMENT' property, so both bare names and absolute paths work."
  (when-let* ((document-path (and (stringp document-path) document-path))
              (document-name (file-name-nondirectory document-path))
              (notes-root (expand-file-name "~/org/noter/"))
              (_ (file-directory-p notes-root)))
    (catch 'done
      (dolist (note (directory-files-recursively notes-root "\\.org\\'"))
        (with-temp-buffer
          (insert-file-contents note)
          (goto-char (point-min))
          (while (re-search-forward (org-re-property org-noter-property-doc-file) nil t)
            (when (+wd/org-noter--matching-document-property-p document-name)
              (throw 'done note))))))))

(defun +wd/org-noter--goto-document-heading (document-path)
  "Move point to the heading in the current notes buffer for DOCUMENT-PATH."
  (let ((document-name (file-name-nondirectory document-path)))
    (goto-char (point-min))
    (catch 'found
      (while (re-search-forward (org-re-property org-noter-property-doc-file) nil t)
        (when (+wd/org-noter--matching-document-property-p document-name)
          (org-back-to-heading t)
          (throw 'found t))))))

(defun +wd/org-noter-create-session-from-document-by-document-name
    (arg document-file-name)
  "Create an org-noter session by matching `NOTER_DOCUMENT' file names.
This supports notes files stored anywhere under `~/org/noter/', including
`CDB-<id>.org' files whose `NOTER_DOCUMENT' is a bare cached download name."
  (when-let* ((document-path (+wd/org-noter--document-file-name document-file-name))
              (note (+wd/org-noter-find-note-by-document-name document-path)))
    (let ((location (org-noter--doc-approx-location)))
      (with-current-buffer (find-file-noselect note)
        (when (+wd/org-noter--goto-document-heading document-path)
          (let ((org-noter--start-location-override location))
            (org-noter arg)))))))

(defun +wd/org-noter--clean-document (document)
  "Return DOCUMENT trimmed to a non-empty string, or nil."
  (let ((doc (and (stringp document) (string-trim document))))
    (and doc (not (string-empty-p doc)) doc)))

(defun +wd/org-noter-parse-document-existing (document &rest _)
  "Return DOCUMENT as an existing file path, or nil.
Primary resolver on `org-noter-parse-document-property-hook'."
  (when-let* ((doc (+wd/org-noter--clean-document document))
              (expanded (expand-file-name doc calibredb-opds-download-dir)))
    (and (file-exists-p expanded) expanded)))

(defvar +wd/calibre-local-library-root "/mnt/home/data/books/calibre-lib"
  "Local calibre library root on this machine.
The same data the content server exposes, reached through a local mount.
Calibre stores each book at `<root>/<author>/<title> (<id>)/<file>', so
`+wd/org-noter-parse-document-local' globs it by id to open in place.")

(defvar +wd/calibre-document-formats '("pdf" "epub" "mobi" "azw3" "azw" "djvu")
  "Document formats to open, highest priority first.
When a book directory holds several formats, the earliest match wins.")

(defun +wd/org-noter-parse-document-local (&optional _document &rest _)
  "Locate the document in the local calibre library by `:CALIBRE_ID', or nil.
Secondary resolver on `org-noter-parse-document-property-hook': calibre
stores each book at `<root>/<author>/<title> (<id>)/<file>', so glob that
directory by id under `+wd/calibre-local-library-root' and open the file in
place — no copy, no download.  Depends only on `:CALIBRE_ID'; the format is
chosen locally by `+wd/calibre-document-formats' priority."
  (when-let* ((id (org-entry-get nil "CALIBRE_ID" t))
              (hit (seq-some
                    (lambda (ext)
                      (car (file-expand-wildcards
                            (expand-file-name (format "*/* (%s)/*.%s" id ext)
                                              +wd/calibre-local-library-root))))
                    +wd/calibre-document-formats)))
    (and (file-readable-p hit) hit)))

(defun +wd/org-noter-parse-document-download (document &rest _)
  "Re-download DOCUMENT via the heading's `:CALIBRE_URL' property, or nil.
Fallback resolver on `org-noter-parse-document-property-hook', tried after
`+wd/org-noter-parse-document-existing'.  The file is cached in
`calibredb-opds-download-dir'.  Requires point on the heading (org-noter's
create-session path guarantees this)."
  (when-let* ((doc (+wd/org-noter--clean-document document))
              (url (org-entry-get nil "CALIBRE_URL" t))
              (fmt (or (and (string-match "/get/\\([^/]+\\)/" url)
                            (match-string 1 url))
                       (file-name-extension doc))))
    (message "org-noter: downloading %s from calibre OPDS..." doc)
    (+wd/calibre--download (file-name-sans-extension (file-name-nondirectory doc))
                           url fmt)))

;;; org-noter -> calibre reading progress

(defun +wd/org-noter-update-calibre-progress ()
  "Update Calibre Read column from DONE/KILL org-noter page coverage."
  (interactive)
  (when (derived-mode-p 'org-mode)
    (cl-labels
        ((page-number
          (value)
          (cond
           ((integerp value) value)
           ((numberp value) (truncate value))
           ((consp value) (page-number (car value)))
           ((stringp value)
            (condition-case nil
                (page-number (read value))
              (error nil)))))
         (calibre-http
          (server method path &optional data)
          (let ((json-file (and data (make-temp-file "calibre-progress-" nil ".json")))
                (output-buffer (generate-new-buffer " *calibre-http-output*")))
            (unwind-protect
                (with-temp-buffer
                  (when json-file
                    (with-temp-file json-file
                      (insert (json-encode data))))
                  (insert (format "url = \"%s\"\n" (concat server path)))
                  (insert (format "request = \"%s\"\n" method))
                  (insert "silent\nshow-error\nfail\ndigest\n")
                  (insert (format "user = \"wd:%s\"\n" (password-store-get "calibre-lib/wd")))
                  (when data
                    (insert "header = \"Content-Type: application/json\"\n")
                    (insert (format "data-binary = \"@%s\"\n" json-file)))
                  (let ((exit (apply #'call-process-region
                                     (point-min) (point-max)
                                     "curl" nil output-buffer nil
                                     '("-K" "-"))))
                    (with-current-buffer output-buffer
                      (let ((output (string-trim (buffer-string))))
                        (unless (zerop exit)
                          (user-error "calibre server request failed: %s" output))
                        output))))
              (when (and json-file (file-exists-p json-file))
                (delete-file json-file))
              (kill-buffer output-buffer)))))
      (save-excursion
        (catch 'no-calibre-id
          (while (not (org-entry-get nil "CALIBRE_ID"))
            (unless (org-up-heading-safe)
              (throw 'no-calibre-id nil)))
          (let* ((root (point-marker))
                 (id (org-entry-get nil "CALIBRE_ID"))
                 (server (progn
                           (unless (and (boundp 'calibredb-root-dir)
                                        (stringp calibredb-root-dir))
                             (user-error "calibredb-root-dir is not configured"))
                           (replace-regexp-in-string "/opds/?\\'" "" calibredb-root-dir)))
                 (json-array-type 'list)
                 (json-object-type 'alist)
                 (book (json-read-from-string
                        (calibre-http server "GET" (format "/ajax/book/%s/" id))))
                 (pages-meta (alist-get (intern "#pages") (alist-get 'user_metadata book)))
                 (total-pages (alist-get (intern "#value#") pages-meta))
                 entries intervals)
            (unless (and (integerp total-pages) (> total-pages 0))
              (user-error "Missing positive Calibre Pages value for book %s" id))
            (org-map-tree
             (lambda ()
               (when-let* ((page (page-number (org-entry-get nil "NOTER_PAGE"))))
                 (push (list (org-outline-level) (org-get-todo-state) page)
                       entries))))
            (setq entries (nreverse entries))
            (cl-loop for tail on entries
                     for (level todo page) = (car tail)
                     when (member todo '("DONE" "KILL"))
                     do (let* ((next (seq-find
                                      (lambda (entry)
                                        (and (<= (nth 0 entry) level)
                                             (nth 2 entry)))
                                      (cdr tail)))
                               (start (max 1 (min page total-pages)))
                               (end (or (and next (nth 2 next))
                                        (1+ total-pages)))
                               (end (max 1 (min end (1+ total-pages)))))
                          (when (< start end)
                            (push (cons start end) intervals))))
            (let ((completed-pages 0)
                  (merged nil))
              (dolist (interval (sort intervals
                                       (lambda (a b) (< (car a) (car b)))))
                (if (and merged (<= (car interval) (cdar merged)))
                    (setcdr (car merged) (max (cdar merged) (cdr interval)))
                  (push interval merged)))
              (dolist (interval merged)
                (cl-incf completed-pages (- (cdr interval) (car interval))))
              (let* ((percentage (/ (* completed-pages 1000.0) total-pages))
                     (percentage (/ (round percentage) 10.0))
                     (read-date (format-time-string "%Y-%m-%dT%H:%M:%S+08:00"
                                                    (current-time)
                                                    "Asia/Shanghai")))
                (goto-char root)
                (org-entry-put nil "NOTER_READ" (format "%.1f%%" percentage))
                (calibre-http server "POST" (format "/cdb/set-fields/%s/" id)
                              `((changes . ((,(intern "#percentage") . ,percentage)
                                             (,(intern "#read_date") . ,read-date)))
                                (loaded_book_ids . [,(string-to-number id)])))
                (message "calibre: %s Read %.1f%% (%d/%d)"
                         id percentage completed-pages total-pages)))))))))

;;; calibre bulk import

(defun +wd/add-book-to-calibre ()
  (interactive)
  (let* ((postfix (list ".pdf" ".epub" ".mobi" ".azw" ".azw3"))
         (path-list (mapcar #'file-truename '("~/Downloads"
                                              "/mnt/nas/data-wd/book"
                                              "/mnt/nas/datb-wd/book")))
         (bin-path (executable-find "calibredb"))
         (password (password-store-get "calibre-lib/wd"))
         (bash-path (executable-find "bash")))
    (dolist (pa path-list)
      (dolist (pf postfix)
        (when (file-directory-p pa)
          (dolist (path (directory-files pa t pf))
            (let* ((cmd (concat bin-path
                                " --with-library=http://nixos-nuc:8080"
                                " --username=wd"
                                " --password=" password
                                " --duplicates add " "'" path "'")))
              (set-process-sentinel
               (start-process "calibredb-add-book" nil bash-path "-c" cmd)
               (lambda (_proc event)
                 (when (string-equal event "finished\n")
                   (delete-file path)
                   (message "Add to calibre & delete origin: %s" path)))))))))))

(provide 'lib-read)
;;; lib-read.el ends here
