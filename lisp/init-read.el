;;; init-read.el --- Settings for reading eBooks -*- lexical-binding: t; -*-
;;; Copyright (C) 2024 Wang Ding

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

(defun +wd/org-noter-resolve-calibre-document (document &rest _)
  "Resolve org-noter DOCUMENT from cache, local calibre library, or OPDS."
  (when-let* ((id (org-entry-get nil "CALIBRE_ID" t)))
    (let* ((doc (and (stringp document) (string-trim document)))
           (fmt (and doc (file-name-extension doc)))
           (server (replace-regexp-in-string "/opds/?$" "" calibredb-root-dir))
           (url (and fmt
                     (format "%s/get/%s/%s/Calibre_Library" server fmt id)))
           (file (and doc fmt
                      (expand-file-name
                       (format "%s.%s"
                               (file-name-sans-extension
                                (file-name-nondirectory doc))
                               fmt)
                       calibredb-opds-download-dir)))
           (local-file
            (seq-some
             (lambda (ext)
               (car (file-expand-wildcards
                     (expand-file-name
                      (format "*/* (%s)/*.%s" id ext)
                      +wd/calibre-local-library-root))))
             +wd/calibre-document-formats)))
      (unless (and doc (not (string-empty-p doc)))
        (user-error "Missing NOTER_DOCUMENT for Calibre book %s" id))
      (unless (and fmt url file)
        (user-error "Cannot infer Calibre document URL for book %s" id))
      (or (and (file-exists-p file) file)
          (and local-file (file-readable-p local-file) local-file)
          (let* ((info (cdr (assoc calibredb-root-dir calibredb-library-alist)))
                 (account (alist-get 'account info))
                 (password (alist-get 'password info))
                 (args (append '("--digest" "-fsSL")
                               (when (and account password)
                                 (list "--user" (format "%s:%s" account password)))
                               (list url "-o" file))))
            (message "org-noter: downloading %s from calibre OPDS..." doc)
            (make-directory calibredb-opds-download-dir t)
            (unless (eq 0 (apply #'call-process "curl" nil nil nil args))
              (user-error "Failed to download Calibre document for book %s" id))
            (unless (file-exists-p file)
              (user-error "Calibre download produced no file for book %s" id))
            file)))))

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
                (font-lock-flush (line-beginning-position) (line-end-position))
                (font-lock-ensure (line-beginning-position) (line-end-position))
                (calibre-http server "POST" (format "/cdb/set-fields/%s/" id)
                              `((changes . ((,(intern "#percentage") . ,percentage)
                                             (,(intern "#read_date") . ,read-date)))
                                (loaded_book_ids . [,(string-to-number id)])))
                (message "calibre: %s Read %.1f%% (%d/%d)"
                         id percentage completed-pages total-pages)))))))))

(setup calibredb
  (:also-load lib-util)
  (:option
   calibredb-search-page-max-rows 30
   calibredb-id-width 6
   calibredb-size-show t
   calibredb-format-all-the-icons t
   calibredb-format-icons-in-terminal t
   calibredb-format-nerd-icons t)
  (:when-loaded
    (:after meow
      (add-to-list 'meow-mode-state-list '(calibredb-search-mode . motion)))

    ;; Search/browse always go through the OPDS content server; the local
    ;; library (if present) is used only to open the on-disk copy.
    (+wd/calibredb-configure-opds)

    (add-hook 'calibredb-search-mode-hook
              (lambda () (buffer-face-set :family "Sarasa Fixed SC")))

    ;; One-key: create a unified CDB-<id>.org for the book at point.
    (:bind-into calibredb-search "n" #'+wd/calibredb-org-noter)))


;; nov.el
;; https://emacs-china.org/t/emacs-epub/4713/11
;; FIXME: errors while opening `nov' files with Unicode characters
(setup nov
  (:match-file "*.epub")
  (:when-loaded
    (with-no-warnings
      (defun my-nov-content-unique-identifier (content)
        "Return the the unique identifier for CONTENT."
        (when-let* ((name (nov-content-unique-identifier-name content))
                    (selector (format "package>metadata>identifier[id='%s']"
                                      (regexp-quote name)))
                    (id (car (esxml-node-children (esxml-query selector content)))))
          (intern id)))
      (advice-add #'nov-content-unique-identifier :override #'my-nov-content-unique-identifier))))

(setup pdf-tools
  (:when-loaded
    (:option pdf-view-continuous t)
    (defun +wd/pdf-view-enable-midnight-for-dark-theme ()
      "Enable midnight mode for PDFs when the active theme is dark."
      (require 'color)
      (when-let* ((background (face-background 'default nil t))
                  (rgb (color-name-to-rgb background)))
        (when (color-dark-p rgb)
          (pdf-view-midnight-minor-mode 1))))

    (add-hook 'pdf-view-mode-hook #'+wd/pdf-view-enable-midnight-for-dark-theme)

    (setq pdf-annot-default-annotation-properties
          '((t         (label . "Wang Ding"))
            (text       (color . "#FFD966") (icon . "Note"))
            (highlight  (color . "#FFD966"))
            (underline  (color . "#93C47D"))
            (squiggly   (color . "#E06C75"))
            (strike-out (color . "#76A5AF"))))

    (map! :map pdf-view-mode-map
          :localleader
          (:prefix ("a" . "annotate")
                   "t" #'pdf-annot-add-text-annotation
                   "h" #'pdf-annot-add-highlight-markup-annotation
                   "u" #'pdf-annot-add-underline-markup-annotation
                   "s" #'pdf-annot-add-squiggly-markup-annotation
                   "x" #'pdf-annot-add-strikeout-markup-annotation
                   "l" #'pdf-annot-list-annotations
                   "d" #'pdf-annot-delete))))


(setup org-noter
  (defun +wd/calibredb-org-noter ()
    "Create and show a unified CDB-<id>.org for the calibre book at point."
    (interactive)
    (let* ((entry (car (calibredb-find-candidate-at-point)))
           (url (calibredb-getattr entry :file-path))
           (id (and (stringp url)
                    (string-match "/get/[^/]+/\\([0-9]+\\)/" url)
                    (match-string 1 url)))
           (title (calibredb-getattr entry :book-title))
           (author (calibredb-getattr entry :author-sort))
           (fmt (and (stringp url)
                     (string-match "/get/\\([^/]+\\)/" url)
                     (match-string 1 url)))
           (doc-name (if fmt (format "%s.%s" title fmt) title))
           (notes-dir (or (car org-noter-notes-search-path)
                          (expand-file-name "~/org/noter/current")))
           (note (and id (expand-file-name (format "CDB-%s.org" id) notes-dir))))
      (unless id
        (user-error "No calibre id for entry at point"))
      (make-directory notes-dir t)
      (unless (file-exists-p note)
        (with-temp-file note
          (insert (format "* %s - %s\n:PROPERTIES:\n:NOTER_DOCUMENT: %s\n:CALIBRE_ID: %s\n:END:\n"
                          (or title "Unknown") (or author "Unknown")
                          doc-name id))))
      (display-buffer-in-side-window
       (find-file-noselect note)
       '((side . right) (slot . 0) (window-width . 0.4)))))

  ;; Keep raw-document sessions from appending book headings to the main notes.
  (:option org-noter-doc-split-fraction '(0.618 . 0.382)
           org-noter-notes-search-path (list (file-truename "~/org/noter/current")))
  (:when-loaded
    (+wd/calibredb-configure-opds)
    (add-hook 'org-noter-parse-document-property-hook
              #'+wd/org-noter-resolve-calibre-document 10)))

(setup org
  (:when-loaded
    (+wd/calibredb-configure-opds)
    (add-hook 'org-after-todo-state-change-hook
              #'+wd/org-noter-update-calibre-progress)))


(provide 'init-read)
;;; init-read.el ends here
