;;; lib-calibre.el --- Calibre integration helpers -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'json)
(require 'seq)
(require 'subr-x)

(defvar +wd/calibre-local-library-root "/mnt/home/data/books/calibre-lib"
  "Local calibre library root on this machine.")

(defvar +wd/calibre-document-formats '("pdf" "epub" "mobi" "azw3" "azw" "djvu")
  "Document formats to open, highest priority first.")

(defun +wd/calibredb-configure-opds ()
  "Configure shared Calibre OPDS variables used by calibredb and org-noter."
  (require 'dns)
  (let ((password (password-store-get "calibre-lib/wd")))
    (setq calibredb-root-dir
          (let ((dns-servers '("100.100.100.100"))
                (dns-servers-valid-for-interfaces t)
                (dns-timeout 2))
            (if (dns-query "nixos-nuc" 'A)
                "http://nixos-nuc:8080/opds"
              "https://lib.autove.dev/opds"))
          calibredb-opds-download-dir "~/.cache/calibre/downloads/"
          calibredb-download-dir "~/.cache/calibre/downloads/"
          calibredb-library-alist
          `(("http://nixos-nuc:8080/opds"
             (name . "calibre")
             (account . "wd")
             (auth . digest)
             (password . ,password))
            ("https://lib.autove.dev/opds"
             (name . "calibre-cloudflare")
             (account . "wd")
             (auth . digest)
             (password . ,password))))))

(defun +wd/calibre-content-server ()
  "Return the configured Calibre content server URL without the OPDS suffix."
  (unless (and (boundp 'calibredb-root-dir)
               (stringp calibredb-root-dir))
    (user-error "calibredb-root-dir is not configured"))
  (replace-regexp-in-string "/opds/?\\'" "" calibredb-root-dir))

(defun +wd/calibre-http (server method path &optional data output-file)
  "Request Calibre SERVER with METHOD and PATH.
When DATA is non-nil, send it as JSON.  When OUTPUT-FILE is non-nil,
write the response there and return an empty string."
  (require 'calibredb-opds)
  (let ((json-file (and data (make-temp-file "calibre-request-" nil ".json")))
        (output-buffer (generate-new-buffer " *calibre-http-output*"))
        (url (concat server path)))
    (unwind-protect
        (let* ((auth-info (calibredb-opds-auth-info url))
               (auth-headers (calibredb-opds-auth-headers auth-info))
               (args (append '("-fsSL")
                             (calibredb-opds-request-curl-options auth-info)
                             (mapcan (lambda (header)
                                       (list "-H" (format "%s: %s"
                                                          (car header)
                                                          (cdr header))))
                                     auth-headers)
                             (list "-X" method)
                             (when data
                               (with-temp-file json-file
                                 (insert (json-encode data)))
                               (list "-H" "Content-Type: application/json"
                                     "--data-binary" (concat "@" json-file)))
                             (when output-file
                               (list "-o" output-file))
                             (list url)))
               (exit (apply #'call-process "curl" nil output-buffer nil args)))
          (with-current-buffer output-buffer
            (let ((output (string-trim (buffer-string))))
              (unless (zerop exit)
                (user-error "calibre server request failed: %s" output))
              output)))
      (when (and json-file (file-exists-p json-file))
        (delete-file json-file))
      (kill-buffer output-buffer))))

(defun +wd/calibre-book-format (id)
  "Return the preferred document format for Calibre book ID."
  (unless (string-match-p "\\`[0-9]+\\'" id)
    (user-error "Invalid Calibre book id: %s" id))
  (let* ((json-array-type 'list)
         (json-object-type 'alist)
         (book (json-read-from-string
                (+wd/calibre-http
                 (+wd/calibre-content-server)
                 "GET"
                 (format "/ajax/book/%s/" id))))
         (formats (alist-get 'formats book))
         (format (or (seq-find (lambda (format)
                                  (member format formats))
                                +wd/calibre-document-formats)
                     (car formats))))
    (unless format
      (user-error "Missing Calibre file metadata for book %s" id))
    format))

(defun +wd/org-noter-resolve-calibre-document (document &rest _)
  "Resolve an empty or stale org-noter DOCUMENT from CALIBRE_ID."
  (save-excursion
    (catch 'resolved
      (while t
        (when-let* ((id (org-entry-get nil "CALIBRE_ID")))
          (let* ((format (+wd/calibre-book-format id))
                 (download-file (expand-file-name
                                 (format "CDB-%s.%s" id format)
                                 calibredb-opds-download-dir))
                 (document-file
                  (if (file-readable-p download-file)
                      download-file
                    (message "org-noter: downloading Calibre book %s..." id)
                    (make-directory calibredb-opds-download-dir t)
                    (+wd/calibre-http
                     (+wd/calibre-content-server)
                     "GET"
                     (format "/get/%s/%s/Calibre_Library" format id)
                     nil
                     download-file)
                    (unless (file-readable-p download-file)
                      (user-error "Calibre download produced no readable file for book %s" id))
                    download-file)))
            (org-entry-put nil "NOTER_DOCUMENT" document-file)
            (throw 'resolved document-file)))
        (unless (org-up-heading-safe)
          (throw 'resolved nil))))))

(defun +wd/org-noter-update-calibre-progress ()
  "Update Calibre Read column from org-noter or Calibre viewer progress."
  (interactive)
  (when (and (derived-mode-p 'org-mode)
             (member (and (boundp 'org-state) org-state) '("DONE" "KILL"))
             ;; This hook runs before `org-auto-repeat-maybe', so do not let
             ;; Calibre progress updates block recurring scheduled tasks.
             (not (org-get-repeat)))
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
         (calibre-progress-date
          (time)
          (format-time-string "%Y-%m-%dT%H:%M:%S+08:00"
                              time
                              "Asia/Shanghai"))
         (calibre-viewer-progress
          (id format)
          (unless (string-match-p "\\`[0-9]+\\'" id)
            (user-error "Invalid Calibre book id: %s" id))
          (unless (string-match-p "\\`[[:alnum:]]+\\'" format)
            (user-error "Invalid Calibre format: %s" format))
          (let* ((db (expand-file-name "metadata.db" +wd/calibre-local-library-root))
                 (sqlite (or (executable-find "sqlite3")
                             (user-error "sqlite3 executable not found")))
                 (query (format (concat "SELECT pos_frac, epoch "
                                        "FROM last_read_positions "
                                        "WHERE book = %s AND upper(format) = '%s' "
                                        "ORDER BY epoch DESC "
                                        "LIMIT 1;")
                                id (upcase format)))
                 (output-buffer (generate-new-buffer " *calibre-progress-sqlite*")))
            (unless (file-readable-p db)
              (user-error "Calibre metadata database not readable: %s" db))
            (unwind-protect
                (let ((exit (call-process sqlite nil output-buffer nil
                                          "-tabs" "-noheader" db query)))
                  (with-current-buffer output-buffer
                    (let* ((output (string-trim (buffer-string)))
                           (fields (and (not (string-empty-p output))
                                        (split-string output "\t")))
                           (pos-frac (and (= (length fields) 2)
                                          (string-to-number (car fields))))
                           (epoch (and (= (length fields) 2)
                                       (string-to-number (cadr fields)))))
                      (unless (zerop exit)
                        (user-error "Calibre progress query failed: %s" output))
                      (unless (and pos-frac epoch)
                        (user-error "Missing Calibre viewer progress for book %s %s"
                                    id (upcase format)))
                      (list (/ (round (* pos-frac 1000.0)) 10.0)
                            (calibre-progress-date (seconds-to-time epoch))
                            nil nil))))
              (kill-buffer output-buffer))))
         (org-noter-page-progress
          (id server)
          (let* ((json-array-type 'list)
                 (json-object-type 'alist)
                 (book (json-read-from-string
                        (+wd/calibre-http server "GET" (format "/ajax/book/%s/" id))))
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
              (list (/ (round (/ (* completed-pages 1000.0) total-pages)) 10.0)
                    (calibre-progress-date (current-time))
                    completed-pages
                    total-pages)))))
      (save-excursion
        (catch 'no-calibre-id
          (while (not (org-entry-get nil "CALIBRE_ID"))
            (unless (org-up-heading-safe)
              (throw 'no-calibre-id nil)))
          (let* ((root (point-marker))
                 (id (org-entry-get nil "CALIBRE_ID"))
                 (document (org-entry-get nil "NOTER_DOCUMENT"))
                 (format (or (and (stringp document)
                                   (not (string-empty-p (string-trim document)))
                                   (when-let* ((extension (file-name-extension document)))
                                     (downcase extension)))
                             (+wd/calibre-book-format id)))
                 (server (+wd/calibre-content-server)))
            (unless format
              (user-error "Missing document format for Calibre book %s" id))
            (pcase-let ((`(,percentage ,read-date ,completed-pages ,total-pages)
                         (if (string= format "pdf")
                             (org-noter-page-progress id server)
                           (calibre-viewer-progress id format))))
              (goto-char root)
              (org-entry-put nil "NOTER_READ" (format "%.1f%%" percentage))
              (+wd/calibre-http server "POST" (format "/cdb/set-fields/%s/" id)
                                `((changes . ((,(intern "#percentage") . ,percentage)
                                               (,(intern "#read_date") . ,read-date)))
                                  (loaded_book_ids . [,(string-to-number id)])))
              (if total-pages
                  (message "calibre: %s Read %.1f%% (%d/%d)"
                           id percentage completed-pages total-pages)
                (message "calibre: %s %s Read %.1f%%"
                         id (upcase format) percentage)))))))))

(defun +wd/calibredb-org-noter ()
  "Create and show a unified CDB-<id>.org for the calibre book at point."
  (interactive)
  (let* ((entry (car (calibredb-find-candidate-at-point)))
         (url (calibredb-getattr entry :file-path))
         (id (or (and (stringp url)
                      (string-match "/get/[^/]+/\\([0-9]+\\)/" url)
                      (match-string 1 url))
                 (calibredb-getattr entry :id)))
         (title (calibredb-getattr entry :book-title))
         (author (calibredb-getattr entry :author-sort))
         (notes-dir (file-truename "~/org/noter/current"))
         (noter-root (file-truename "~/org/noter/"))
         (note (and id
                    (or (when (file-directory-p noter-root)
                          (require 'org)
                          (catch 'found
                            (dolist (file (directory-files-recursively noter-root "\\.org\\'"))
                              (with-temp-buffer
                                (insert-file-contents file)
                                (delay-mode-hooks (org-mode))
                                (org-with-wide-buffer
                                 (goto-char (point-min))
                                 (while (re-search-forward org-heading-regexp nil t)
                                   (when (string= (org-entry-get nil "CALIBRE_ID") id)
                                     (throw 'found file))))))))
                        (expand-file-name (format "CDB-%s.org" id) notes-dir)))))
    (unless id
      (user-error "No calibre id for entry at point"))
    (make-directory notes-dir t)
    (unless (file-exists-p note)
      (with-temp-file note
        (insert (format "* %s - %s\n:PROPERTIES:\n:NOTER_DOCUMENT:\n:CALIBRE_ID: %s\n:END:\n"
                        (or title "Unknown") (or author "Unknown")
                        id))))
    (display-buffer-in-side-window
     (find-file-noselect note)
     '((side . right) (slot . 0) (window-width . 0.4)))))

(defun +wd/add-book-to-calibre ()
  "Import books from inbox directories into Calibre."
  (interactive)
  (let* ((calibredb (or (executable-find "calibredb")
                       (user-error "calibredb executable not found")))
         (password (password-store-get "calibre-lib/wd"))
         (formats '(".pdf" ".epub" ".mobi" ".azw" ".azw3"))
         (directories (mapcar #'file-truename
                              '("~/Downloads"
                                "/mnt/nas/data-wd/book"
                                "/mnt/nas/datb-wd/book"))))
    (dolist (directory directories)
      (when (file-directory-p directory)
        (dolist (format formats)
          (dolist (path (directory-files directory t (concat (regexp-quote format) "\\'")))
            (let ((process (start-process "calibredb-add-book" nil calibredb
                                          "--with-library=http://nixos-nuc:8080"
                                          "--username=wd"
                                          (format "--password=%s" password)
                                          "add"
                                          "--duplicates"
                                          path)))
              (set-process-sentinel
               process
               (lambda (_proc event)
                 (if (string-equal event "finished\n")
                     (progn
                       (delete-file path)
                       (message "Add to calibre & delete origin: %s" path))
                   (message "Failed to add book to calibre: %s (%s)"
                            path (string-trim event))))))))))))

(provide 'lib-calibre)
;;; lib-calibre.el ends here
