;;; lib-reading.el --- Reading progress helpers -*- lexical-binding: t; -*-

(require 'json)
(require 'org)
(require 'seq)
(require 'subr-x)

(defcustom +wd/calibredb-sync-progress-column "percentage"
  "Calibre custom column name used to store reading progress."
  :type 'string
  :group 'org-noter)

(defcustom +wd/calibredb-sync-read-date-column "read_date"
  "Calibre custom column name used to store last read timestamp."
  :type 'string
  :group 'org-noter)

(defcustom +wd/calibredb-sync-library-url "http://localhost:8080/"
  "Calibre content server URL for progress sync."
  :type 'string
  :group 'org-noter)

(defcustom +wd/calibredb-sync-username "wd"
  "Calibre content server username for progress sync."
  :type 'string
  :group 'org-noter)

(defcustom +wd/calibredb-sync-password-store-key "calibre-lib/wd"
  "Password-store key used to fetch calibre content server password."
  :type 'string
  :group 'org-noter)

(defcustom +wd/org-noter-calibre-library-root
  (file-truename "~/Calibre Library")
  "Root directory used to resolve `:NOTER_DOCUMENT:` files for org-noter."
  :type 'directory
  :group 'org-noter)

(defun +wd/org-noter--current-session ()
  "Return current org-noter session object, or nil if unavailable."
  (when (require 'org-noter-core nil t)
    (cond
     ((boundp 'org-noter--session)
      (and (org-noter--session-p org-noter--session) org-noter--session))
     ((fboundp 'org-noter--get-session)
      (ignore-errors (org-noter--get-session)))
     (t nil))))

(defun +wd/org-noter--page-progress (&optional session)
  "Return current page and total pages as (CURRENT . TOTAL) for SESSION."
  (let* ((session (or session (+wd/org-noter--current-session)))
         (doc-buffer (and session (org-noter--session-doc-buffer session))))
    (when (buffer-live-p doc-buffer)
      (with-current-buffer doc-buffer
        (cond
         ((and (derived-mode-p 'pdf-view-mode)
               (fboundp 'pdf-view-current-page)
               (fboundp 'pdf-cache-number-of-pages))
          (cons (pdf-view-current-page)
                (pdf-cache-number-of-pages)))
         ((derived-mode-p 'doc-view-mode)
          (let ((current (if (fboundp 'doc-view-current-page)
                             (doc-view-current-page)
                           (and (boundp 'doc-view-current-page)
                                doc-view-current-page)))
                (total (if (boundp 'doc-view-last-page-number)
                           doc-view-last-page-number
                         nil)))
            (when (and (numberp current) (numberp total) (> total 0))
              (cons current total))))
         ((derived-mode-p 'nov-mode)
          (let* ((idx (and (boundp 'nov-documents-index) nov-documents-index))
                 (docs (and (boundp 'nov-documents) nov-documents))
                 (total (and (sequencep docs) (length docs)))
                 (current (and (integerp idx) (1+ idx))))
            (when (and (numberp current) (numberp total) (> total 0))
              (cons (max 1 (min current total)) total))))
         (t nil))))))

(defun +wd/org-noter--find-noter-document-heading-point ()
  "Return nearest headline point that locally defines NOTER_DOCUMENT."
  (org-with-wide-buffer
   (save-excursion
     (when (org-before-first-heading-p)
       (outline-next-heading))
     (when (org-at-heading-p)
       (let ((found nil))
         (while (and (not found) (org-at-heading-p))
           (when (org-entry-get nil "NOTER_DOCUMENT" nil)
             (setq found (point)))
           (unless found
             (if (org-up-heading-safe)
                 t
               (goto-char (point-min)))))
         found)))))

(defun +wd/org-noter--same-notes-buffer-p (buffer-a buffer-b)
  "Return non-nil when BUFFER-A and BUFFER-B are same or share base buffer."
  (let ((a (and (buffer-live-p buffer-a) buffer-a))
        (b (and (buffer-live-p buffer-b) buffer-b)))
    (and a
         b
         (or (eq a b)
             (eq (buffer-base-buffer a) b)
             (eq a (buffer-base-buffer b))
             (eq (buffer-base-buffer a) (buffer-base-buffer b))))))

(defun +wd/org-noter--document-filename-from-property (noter-document)
  "Derive final filename (with extension) from NOTER-DOCUMENT path."
  (when (and (stringp noter-document) (not (string-empty-p noter-document)))
    (let* ((raw (string-trim noter-document))
           (clean (replace-regexp-in-string "\\`file:" "" raw))
           (path (car (split-string clean "::"))))
      (file-name-nondirectory path))))

(defun +wd/calibre-ebook-viewer--json-read-file (path)
  "Read JSON file PATH as alist/list, or return nil when unavailable."
  (when (and (stringp path) (file-readable-p path))
    (let ((json-object-type 'alist)
          (json-array-type 'list)
          (json-key-type 'string)
          (json-false nil))
      (ignore-errors
        (json-read-file path)))))

(defun +wd/calibre-ebook-viewer--last-read-from-annotations (cache-path)
  "Return newest last-read annotation alist from CACHE-PATH."
  (let* ((home (expand-file-name "~"))
         (ann-file (expand-file-name
                    (format ".cache/calibre/ev2/f/%s/calibre-book-annotations.json"
                            cache-path)
                    home))
         (ann (+wd/calibre-ebook-viewer--json-read-file ann-file))
         (best nil))
    (when (listp ann)
      (dolist (item ann)
        (when (and (listp item)
                   (string= (or (alist-get "type" item nil nil #'string=) "")
                            "last-read"))
          (if (not best)
              (setq best item)
            (let ((old-ts (or (alist-get "timestamp" best nil nil #'string=) ""))
                  (new-ts (or (alist-get "timestamp" item nil nil #'string=) "")))
              (when (string-lessp old-ts new-ts)
                (setq best item)))))))
    best))

(defun +wd/calibre-ebook-viewer--progress-from-cache (cache-path)
  "Compute progress percent for CACHE-PATH using viewer CFI and manifest."
  (let* ((home (expand-file-name "~"))
         (manifest-file (expand-file-name
                         (format ".cache/calibre/ev2/f/%s/calibre-book-manifest.json"
                                 cache-path)
                         home))
         (manifest (+wd/calibre-ebook-viewer--json-read-file manifest-file))
         (last-read (+wd/calibre-ebook-viewer--last-read-from-annotations cache-path))
         (cfi (and (listp last-read)
                   (alist-get "pos" last-read nil nil #'string=)))
         (spine (and (listp manifest)
                     (alist-get "spine" manifest nil nil #'string=)))
         (files (and (listp manifest)
                     (alist-get "files" manifest nil nil #'string=)))
         (total (and (listp manifest)
                     (or (alist-get "total_length" manifest nil nil #'string=)
                         (alist-get "spine_length" manifest nil nil #'string=)))))
    (when (and (stringp cfi)
               (listp spine)
               (> (length spine) 0)
               (listp files)
               (numberp total)
               (> total 0))
      (let* ((head-step (and (string-match "epubcfi(/\\([0-9]+\\)" cfi)
                             (string-to-number (match-string 1 cfi))))
             (idx (and (numberp head-step)
                       (max 0 (min (1- (length spine))
                                   (1- (floor (/ head-step 2.0))))))))
        (when (integerp idx)
          (let* ((prev 0.0)
                 (cur-path (nth idx spine))
                 (cur-meta (and (stringp cur-path)
                                (alist-get cur-path files nil nil #'string=)))
                 (cur-len (or (and (listp cur-meta)
                                   (alist-get "length" cur-meta nil nil #'string=))
                              0))
                 (offset (and (string-match ":\\([0-9]+\\)[^0-9]*\\'" cfi)
                              (string-to-number (match-string 1 cfi))))
                 (frac (if (and (numberp cur-len) (> cur-len 0)
                                (numberp offset) (>= offset 0))
                           (min 1.0 (/ (float offset) cur-len))
                         0.0)))
            (dolist (p (seq-take spine idx))
              (let* ((meta (and (stringp p)
                                (alist-get p files nil nil #'string=)))
                     (len (or (and (listp meta)
                                   (alist-get "length" meta nil nil #'string=))
                              0)))
                (setq prev (+ prev (float len)))))
            (* 100.0 (/ (+ prev (* frac (float cur-len)))
                        (float total)))))))))

(defun +wd/calibre-ebook-viewer-nov-get-percentage (filename)
  "Return ebook-viewer progress percentage (0-100) for FILENAME.
FILENAME should be the basename of the epub file (without directory)."
  (interactive "sEpub filename (basename): ")
  (let* ((target (and (stringp filename) (string-trim filename)))
         (target-base (and (stringp target) (file-name-base target)))
         (home (expand-file-name "~"))
         (viewer-file (expand-file-name ".config/calibre/viewer-webengine.json" home))
         (metadata-file (expand-file-name ".cache/calibre/ev2/metadata.json" home))
         (viewer (+wd/calibre-ebook-viewer--json-read-file viewer-file))
         (metadata (+wd/calibre-ebook-viewer--json-read-file metadata-file))
         (entries (and (listp metadata)
                       (alist-get "entries" metadata nil nil #'string=)))
         (recent (and (listp viewer)
                      (alist-get "session_data" viewer nil nil #'string=)))
         (recent-opened (and (listp recent)
                             (alist-get "standalone_recently_opened" recent nil nil #'string=)))
         (book-path nil)
         (cache-path nil)
         (percentage nil))
    (when (and (stringp target) (not (string-empty-p target)))
      (when (listp recent-opened)
        (let ((best-ts ""))
          (dolist (it recent-opened)
            (let* ((key (and (listp it) (alist-get "key" it nil nil #'string=)))
                   (ts (or (and (listp it)
                                (alist-get "timestamp" it nil nil #'string=))
                           ""))
                   (base (and (stringp key) (file-name-nondirectory key))))
              (when (and (stringp key)
                         (stringp base)
                         (or (string= base target)
                             (string= (file-name-base base) target-base))
                         (or (string-empty-p best-ts)
                             (string-lessp best-ts ts)))
                (setq best-ts ts
                      book-path key))))))
      (when (listp entries)
        (let ((best-ts "")
              (best-cache nil))
          (dolist (bucket (mapcar #'cdr entries))
            (when (listp bucket)
              (dolist (it bucket)
                (let* ((bp (and (listp it) (alist-get "book_path" it nil nil #'string=)))
                       (cp (and (listp it) (alist-get "path" it nil nil #'string=)))
                       (base (and (stringp bp) (file-name-nondirectory bp)))
                       (match (and (stringp cp)
                                   (stringp base)
                                   (or (and (stringp book-path)
                                            (string= bp book-path))
                                       (string= base target)
                                       (string= (file-name-base base) target-base)))))
                  (when match
                    (let* ((last-read (+wd/calibre-ebook-viewer--last-read-from-annotations cp))
                           (ts (or (and (listp last-read)
                                        (alist-get "timestamp" last-read nil nil #'string=))
                                   "")))
                      (when (or (string-empty-p best-ts)
                                (string-lessp best-ts ts))
                        (setq best-ts ts
                              best-cache cp))))))))
          (setq cache-path best-cache)))
      (when (stringp cache-path)
        (setq percentage (+wd/calibre-ebook-viewer--progress-from-cache cache-path))))
    (when (called-interactively-p 'interactive)
      (if (numberp percentage)
          (message "%s -> %.2f%%" target percentage)
        (message "No progress found for %s" target)))
    percentage))

(defun +wd/org-noter--calibredb-base-args ()
  "Build base calibredb args for calibre content server."
  (let ((pw (when (and (fboundp 'password-store-get)
                       (stringp +wd/calibredb-sync-password-store-key)
                       (not (string-empty-p +wd/calibredb-sync-password-store-key)))
              (ignore-errors
                (password-store-get +wd/calibredb-sync-password-store-key)))))
    (if (and (stringp +wd/calibredb-sync-library-url)
             (not (string-empty-p +wd/calibredb-sync-library-url))
             (stringp +wd/calibredb-sync-username)
             (not (string-empty-p +wd/calibredb-sync-username))
             (stringp pw)
             (not (string-empty-p pw)))
        (list (concat "--with-library=" +wd/calibredb-sync-library-url)
              (concat "--username=" +wd/calibredb-sync-username)
              (concat "--password=" pw))
      nil)))

(defun +wd/org-noter--calibre-id-from-path (path)
  "Extract calibre numeric id from parent directory of PATH."
  (when (stringp path)
    (let ((dir (file-name-nondirectory
                (directory-file-name (file-name-directory path)))))
      (when (string-match ".*(\\([0-9]+\\))\\'" dir)
        (match-string 1 dir)))))

(defun +wd/org-noter-sync-calibredb-percentage (target ratio &optional silent)
  "Sync current book progress RATIO (0-100 scale) to calibredb #percentage."
  (let* ((bin (executable-find "calibredb"))
         (base-args (+wd/org-noter--calibredb-base-args)))
    (when (and bin base-args (numberp ratio) (>= ratio 0))
      (let* ((noter-document (save-excursion
                               (goto-char target)
                               (org-entry-get (point) "NOTER_DOCUMENT" nil)))
             (filename (+wd/org-noter--document-filename-from-property noter-document)))
        (when (and (stringp filename) (not (string-empty-p filename)))
          (let* ((case-fold-search t)
                 (matches (directory-files-recursively
                           +wd/org-noter-calibre-library-root
                           (concat (regexp-quote filename) "\\'")))
                 (value (format "%.1f" ratio))
                 (read-date (format-time-string "%Y-%m-%d %H:%M:%S"))
                 (updated-ids nil))
            (dolist (path matches)
              (let ((id (+wd/org-noter--calibre-id-from-path path)))
                (when id
                  (let ((ok-progress
                         (eq 0 (apply #'call-process bin nil nil nil
                                      (append base-args
                                              (list "set_custom"
                                                    +wd/calibredb-sync-progress-column
                                                    id value)))))
                        (ok-read-date
                         (eq 0 (apply #'call-process bin nil nil nil
                                      (append base-args
                                              (list "set_custom"
                                                    +wd/calibredb-sync-read-date-column
                                                    id read-date))))))
                    (when (or ok-progress ok-read-date)
                      (push id updated-ids))))))
            (unless silent
              (message "calibredb synced: %s -> progress=%s read_date=%s (%s)"
                       filename
                       value
                       read-date
                       (if updated-ids
                           (mapconcat #'identity (reverse (delete-dups updated-ids)) ",")
                         "no-id-updated")))))))))

(defun +wd/org-noter-update-read-progress (&optional silent)
  "Update NOTER_READ at the headline which defines NOTER_DOCUMENT."
  (interactive)
  (let* ((session (+wd/org-noter--current-session))
         (notes-buffer (and session (org-noter--session-notes-buffer session)))
         (progress (+wd/org-noter--page-progress session))
         (target (+wd/org-noter--find-noter-document-heading-point)))
    (when (and session
               (buffer-live-p notes-buffer)
               (+wd/org-noter--same-notes-buffer-p (current-buffer) notes-buffer)
               progress
               target)
      (let* ((current (car progress))
             (total (cdr progress))
             (ratio (* 100.0 (/ (float current) total)))
             (value (format "%.1f%% (%d/%d)" ratio current total)))
        (save-excursion
          (goto-char target)
          (org-entry-put (point) "NOTER_READ" value))
        (+wd/org-noter-sync-calibredb-percentage target ratio t)
        (unless silent
          (message "NOTER_READ -> %s" value))))))

(defun +wd/org-noter-auto-update-read-progress ()
  "Auto update NOTER_READ on DONE/KILL inside org-noter notes buffer."
  (when (and (derived-mode-p 'org-mode)
             (bound-and-true-p org-noter-notes-mode)
             (bound-and-true-p org-state)
             (member org-state '("DONE" "KILL")))
    (+wd/org-noter-update-read-progress t)))

(provide 'lib-reading)
