;;; lib-read.el --- org-noter / calibre / zathura reading integration -*- lexical-binding: t; -*-

(require 'org)
(require 'seq)
(require 'subr-x)

;; calibredb / org-noter are loaded lazily; declare what we call at runtime.
(defvar calibredb-root-dir)
(defvar calibredb-library-alist)
(defvar calibredb-opds-download-dir)
(defvar org-noter-notes-search-path)
(defvar org-noter-property-note-location)
(declare-function calibredb-getattr "calibredb-core")
(declare-function calibredb-get-file-path "calibredb-utils")
(declare-function calibredb-find-candidate-at-point "calibredb-utils")
(declare-function org-noter "org-noter")
(declare-function org-noter--get-session "org-noter-core")
(declare-function org-noter--session-p "org-noter-core")
(declare-function org-noter--session-doc-buffer "org-noter-core")
(declare-function org-noter--session-notes-buffer "org-noter-core")
(declare-function org-noter--parse-root "org-noter-core")
(declare-function pdf-view-current-page "pdf-view")
(declare-function pdf-view-goto-page "pdf-view")

(defcustom +wd/calibre-local-library-root "/mnt/home/data/books/calibre-lib"
  "Local Calibre library root.
When it exists on this machine, a book id is resolved to a local file
path here (see `+wd/calibre--local-file'), so books open from the local
disk instead of being downloaded.  It is also the fallback search root
when a `:NOTER_DOCUMENT:' path no longer exists."
  :type 'directory
  :group 'org-noter)

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

;;; calibre: id -> local file, unified CDB-<id>.org, open in org-noter

(defun +wd/calibre--entry-id (entry)
  "Return the calibre numeric id (string) for calibredb ENTRY, or nil.
OPDS entries carry the id inside the acquisition URL
`.../get/<fmt>/<id>/...'; local entries carry it in the parent directory
`<Title> (<id>)'."
  (let ((path (and entry (calibredb-getattr entry :file-path))))
    (when (stringp path)
      (cond
       ((string-match "/get/[^/]+/\\([0-9]+\\)/" path) (match-string 1 path))
       ((string-match "(\\([0-9]+\\))/[^/]*\\'" path) (match-string 1 path))))))

(defun +wd/calibre--local-file (id &optional format)
  "Return the absolute path of calibre book ID under the local library, or nil.
Query the local `metadata.db' directly, independent of calibredb's global
connection.  When FORMAT is non-nil prefer that format."
  (let ((db (expand-file-name "metadata.db" +wd/calibre-local-library-root)))
    (when (and id (fboundp 'sqlite-available-p) (sqlite-available-p)
               (file-readable-p db))
      (let ((conn (sqlite-open db)))
        (unwind-protect
            (let* ((rows (sqlite-select
                          conn
                          "SELECT b.path, d.name, d.format FROM books b \
JOIN data d ON d.book = b.id WHERE b.id = ?"
                          (list (if (stringp id) (string-to-number id) id))))
                   (row (or (and format
                                 (seq-find (lambda (r)
                                             (string-equal-ignore-case (nth 2 r) format))
                                           rows))
                            (car rows))))
              (when row
                (let ((path (expand-file-name
                             (concat (file-name-as-directory (nth 0 row))
                                     (nth 1 row) "." (downcase (nth 2 row)))
                             +wd/calibre-local-library-root)))
                  (when (file-exists-p path) path))))
          (sqlite-close conn))))))

(defun +wd/calibre--download (title url format)
  "Synchronously download URL to <download-dir>/TITLE.FORMAT, return path or nil.
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
    (when (and (eq 0 (apply #'call-process "curl" nil nil nil args))
               (file-exists-p file))
      file)))

(defun +wd/calibre--ensure-note-file (id title author doc-name)
  "Ensure CDB-ID.org exists in the org-noter notes dir; return its path.
When absent, pre-create it with a `* TITLE - AUTHOR' heading and
`:NOTER_DOCUMENT: DOC-NAME', where DOC-NAME is the calibre database
filename (a bare basename, not an absolute path) so the notes file stays
portable across machines; `+wd/org-noter-parse-document-property-calibre'
resolves it to a real file at open time.  This is the single place the
unified notes format is written."
  (let* ((notes-dir (or (car org-noter-notes-search-path)
                        (expand-file-name "~/org/noter")))
         (note (expand-file-name (format "CDB-%s.org" id) notes-dir)))
    (make-directory notes-dir t)
    (unless (file-exists-p note)
      (with-temp-file note
        (insert (format "* %s - %s\n:PROPERTIES:\n:NOTER_DOCUMENT: %s\n:CALIBRE_ID: %s\n:END:\n"
                        (or title "Unknown") (or author "Unknown") doc-name id))))
    note))

(defun +wd/calibredb-get-file-path--local-first (oldfn entry &optional prompt)
  "Advice: prefer the local library file when calibredb resolves to a http URL.
Keeps OPDS as the single search backend while opening the on-disk copy
when the book exists in the local library."
  (let ((path (funcall oldfn entry prompt)))
    (if (and (stringp path) (string-prefix-p "http" path)
             (file-directory-p +wd/calibre-local-library-root))
        (or (+wd/calibre--local-file (+wd/calibre--entry-id entry)
                                     (calibredb-getattr entry :book-format))
            path)
      path)))

(defun +wd/calibredb-org-noter ()
  "Open the calibre book at point in org-noter via a unified CDB-<id>.org.
Read the authoritative id/title/author from the calibredb entry, resolve
the document to a local library file when present, else download it via
OPDS, then create/open `CDB-<id>.org' and start `org-noter'.  The notes
format is identical regardless of how the document is obtained."
  (interactive)
  (let* ((entry (car (calibredb-find-candidate-at-point)))
         (id (+wd/calibre--entry-id entry))
         (title (calibredb-getattr entry :book-title))
         (author (calibredb-getattr entry :author-sort))
         (format (calibredb-getattr entry :book-format))
         (doc-path (or (+wd/calibre--local-file id format)
                       (+wd/calibre--download
                        title (calibredb-getattr entry :file-path) format))))
    (unless id
      (user-error "No calibre id for entry at point"))
    (unless doc-path
      (user-error "Could not resolve or download document for id %s" id))
    (find-file (+wd/calibre--ensure-note-file
                id title author (file-name-nondirectory doc-path)))
    (org-noter)))

;;; org-noter document resolution fallback

(defun +wd/org-noter-parse-document-property-calibre (document &rest _)
  "Resolve DOCUMENT (a bare calibre filename or a path) to an openable file.
Hook for `org-noter-parse-document-property-hook': return DOCUMENT as-is
when it exists, otherwise search the local calibre library and the OPDS
download dir by basename and return the shortest match."
  (let* ((doc (and (stringp document) (string-trim document)))
         (expanded (and doc (expand-file-name doc))))
    (cond
     ((or (null doc) (string-empty-p doc)) nil)
     ((file-exists-p expanded) expanded)
     (t
      (let* ((filename (file-name-nondirectory expanded))
             (roots (seq-filter
                     (lambda (d) (and (stringp d) (file-directory-p d)))
                     (list +wd/calibre-local-library-root
                           (and (boundp 'calibredb-opds-download-dir)
                                (expand-file-name calibredb-opds-download-dir)))))
             (matches (mapcan
                       (lambda (root)
                         (directory-files-recursively
                          root (concat "\\`" (regexp-quote filename) "\\'")))
                       roots))
             (sorted (sort matches (lambda (a b) (< (length a) (length b))))))
        (car sorted))))))

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
