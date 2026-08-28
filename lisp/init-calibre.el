;;; init-calibre.el --- Calibre and calibredb integration -*- lexical-binding: t; -*-

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
  "Request Calibre SERVER with METHOD and PATH."
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
  (require 'calibredb)
  (+wd/calibredb-configure-opds)
  (let* ((calibredb (or (executable-find calibredb-program)
                       (and (file-executable-p calibredb-program)
                            calibredb-program)
                       (user-error "calibredb executable not found")))
         (library (or (assoc calibredb-root-dir calibredb-library-alist)
                      (user-error "Current Calibre library is not configured")))
         (account (alist-get 'account (cdr library)))
         (password (alist-get 'password (cdr library)))
         (server (+wd/calibre-content-server))
         (formats (mapcar (lambda (format) (concat "." format))
                          +wd/calibre-document-formats))
         (directories (mapcar #'file-truename
                              '("~/Downloads"
                                "/mnt/nas/data-wd/book"
                                "/mnt/nas/datb-wd/book"))))
    (dolist (directory directories)
      (when (file-directory-p directory)
        (dolist (format formats)
          (dolist (path (directory-files directory t (concat (regexp-quote format) "\\'")))
            (let* ((title (file-name-base path))
                   (process (apply #'start-process
                                   "calibredb-add-book" nil calibredb
                                   (append
                                    (list (format "--with-library=%s" server)
                                          (format "--username=%s" account)
                                          (format "--password=%s" password)
                                          "add")
                                    (when calibredb-add-duplicate
                                      '("--duplicates"))
                                    (list (format "--title=%s" title)
                                          path)))))
              (set-process-sentinel
               process
               (lambda (_proc event)
                 (if (string-equal event "finished\n")
                     (progn
                       (delete-file path)
                       (message "Add to calibre & delete origin: %s" path))
                   (user-error "Failed to add book to calibre: %s (%s)"
                               path (string-trim event))))))))))))

(setup calibredb
  (:option
   calibredb-search-page-max-rows 30
   calibredb-id-width 6
   calibredb-size-show t
   calibredb-format-all-the-icons t
   calibredb-format-icons-in-terminal t
   calibredb-format-nerd-icons t)
  (:after meow
    (add-to-list 'meow-mode-state-list '(calibredb-search-mode . motion)))
  (:when-loaded
    (+wd/calibredb-configure-opds)
    (:hooks calibredb-search-mode-hook
            (lambda () (buffer-face-set :family "Sarasa Fixed SC")))
    (:bind-into calibredb-search "n" #'+wd/calibredb-org-noter)))

(provide 'init-calibre)
;;; init-calibre.el ends here
