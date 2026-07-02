;;; lib-read.el --- org-noter / calibre / zathura reading integration -*- lexical-binding: t; -*-

(require 'org)
(require 'seq)
(require 'subr-x)
(require 'org-noter)

;; calibredb / org-noter are loaded lazily; declare what we call at runtime.
(defvar calibredb-root-dir)
(defvar calibredb-library-alist)
(defvar calibredb-opds-download-dir)
(defvar org-noter-notes-search-path)
(defvar org-noter-property-note-location)
(declare-function calibredb-getattr "calibredb-core")
(declare-function calibredb-find-candidate-at-point "calibredb-utils")
(declare-function org-noter "org-noter")
(declare-function org-noter--get-session "org-noter-core")
(declare-function org-noter--session-p "org-noter-core")
(declare-function org-noter--session-doc-buffer "org-noter-core")
(declare-function org-noter--session-notes-buffer "org-noter-core")
(declare-function org-noter--parse-root "org-noter-core")
(declare-function pdf-view-current-page "pdf-view")
(declare-function pdf-view-goto-page "pdf-view")

;;; org-noter session basics

(defun +wd/org-noter--current-session ()
  "Return current org-noter session object, or nil if unavailable."
  (when (require 'org-noter-core nil t)
    (cond
     ((boundp 'org-noter--session)
      (and (org-noter--session-p org-noter--session) org-noter--session))
     ((fboundp 'org-noter--get-session)
      (ignore-errors (org-noter--get-session)))
     (t nil))))

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

(defun +wd/org-noter-parse-document-local (&optional document &rest _)
  "Locate the document in the local calibre library by `:CALIBRE_ID', or nil.
Secondary resolver on `org-noter-parse-document-property-hook': calibre
stores each book at `<root>/<author>/<title> (<id>)/<file>', so glob that
directory by id under `+wd/calibre-local-library-root' and open the file in
place — no copy, no download.  Format comes from `:CALIBRE_URL' (falling
back to DOCUMENT's extension)."
  (when-let* ((id (org-entry-get nil "CALIBRE_ID" t))
              (url (org-entry-get nil "CALIBRE_URL" t))
              (fmt (or (and (string-match "/get/\\([^/]+\\)/" url) (match-string 1 url))
                       (and (stringp document) (file-name-extension document))))
              (pat (expand-file-name (format "*/* (%s)/*.%s" id fmt)
                                     +wd/calibre-local-library-root))
              (hit (car (file-expand-wildcards pat))))
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

;;; zathura <-> org-noter page sync

(defun +wd/zathura-last-page (file)
  "Return the last viewed 1-based page of FILE from zathura's database.
zathura stores page numbers 0-based in its `fileinfo' table; this
returns the 1-based page matching `pdf-view-current-page', or nil when
unavailable.  Falls back to matching by basename when FILE is not stored
verbatim (e.g. zathura canonicalised the path)."
  (let ((db (expand-file-name "zathura/bookmarks.sqlite"
                              (or (getenv "XDG_DATA_HOME")
                                  (expand-file-name "~/.local/share")))))
    (when (and (fboundp 'sqlite-available-p) (sqlite-available-p)
               (stringp file) (file-readable-p db))
      (let ((conn (sqlite-open db)))
        (unwind-protect
            (let ((row (or (car (sqlite-select
                                 conn
                                 "SELECT page FROM fileinfo WHERE file = ? \
ORDER BY time DESC LIMIT 1"
                                 (list file)))
                           (car (sqlite-select
                                 conn
                                 "SELECT page FROM fileinfo WHERE file LIKE ? \
ORDER BY time DESC LIMIT 1"
                                 (list (concat "%/" (file-name-nondirectory file))))))))
              (when (and row (numberp (car row)))
                (1+ (car row))))
          (sqlite-close conn))))))

(defun +wd/org-noter-goto-doc-page (session page)
  "Move SESSION's pdf-view document buffer to 1-based PAGE."
  (let ((doc-buffer (and (org-noter--session-p session)
                         (org-noter--session-doc-buffer session))))
    (when (buffer-live-p doc-buffer)
      (with-current-buffer doc-buffer
        (when (and (derived-mode-p 'pdf-view-mode)
                   (fboundp 'pdf-view-goto-page))
          (let ((window (get-buffer-window doc-buffer t)))
            (if window
                (pdf-view-goto-page page window)
              (pdf-view-goto-page page))))))))

(defun +wd/org-noter-set-root-page (session page)
  "Set NOTER_PAGE on SESSION's root heading to PAGE, then save the notes file."
  (let ((notes-buffer (and (org-noter--session-p session)
                           (org-noter--session-notes-buffer session))))
    (when (buffer-live-p notes-buffer)
      (with-current-buffer notes-buffer
        (org-with-wide-buffer
         (let ((inhibit-read-only t)
               (ast (org-noter--parse-root session)))
           (goto-char (org-element-property :begin ast))
           (org-entry-put nil org-noter-property-note-location
                          (number-to-string page))))
        (when buffer-file-name (save-buffer)))
      (message "org-noter: %s <- %d (from zathura)"
               org-noter-property-note-location page))))

(defun +wd/zathura-open-current-pdf ()
  "Open the current pdf-view buffer's file in zathura at the current page.
When invoked inside an org-noter session, the page last viewed in zathura
is written back to the root heading's NOTER_PAGE property once zathura is
closed, so reading progress stays in sync across both viewers."
  (interactive)
  (unless (derived-mode-p 'pdf-view-mode)
    (user-error "Not in a pdf-view buffer"))
  (let* ((file buffer-file-name)
         (session (+wd/org-noter--current-session))
         (session (and (org-noter--session-p session)
                       (eq (org-noter--session-doc-buffer session)
                           (current-buffer))
                       session)))
    (make-process
     :name "zathura"
     :noquery t
     :command (list "zathura" "-P" (number-to-string (pdf-view-current-page)) file)
     :sentinel
     (lambda (_proc event)
       (when (and session (string-prefix-p "finished" event))
         (when-let* ((page (+wd/zathura-last-page file)))
           (+wd/org-noter-goto-doc-page session page)
           (+wd/org-noter-set-root-page session page)))))))

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
