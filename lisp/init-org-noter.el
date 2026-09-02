;;; init-org-noter.el --- Org-noter Calibre integration -*- lexical-binding: t; -*-

(require 'init-calibre)

(defun +wd/org-noter-resolve-calibre-document (document &rest _)
  "Resolve an empty or stale org-noter DOCUMENT from CALIBRE_ID."
  (if (and document (file-readable-p document))
      document
    (catch 'resolved
      (while t
        (when-let* ((id (org-entry-get nil "CALIBRE_ID"))
                    (format (+wd/calibre-book-format id))
                    (download-file (expand-file-name
                                    (format "CDB-%s.%s" id format)
                                    calibredb-opds-download-dir)))
          (unless (file-readable-p download-file)
            (message "org-noter: downloading Calibre book %s..." id)
            (make-directory calibredb-opds-download-dir t)
            (+wd/calibre-http
             (+wd/calibre-content-server)
             "GET"
             (format "/get/%s/%s/Calibre_Library" format id)
             nil
             download-file)
            (unless (file-readable-p download-file)
              (user-error "Calibre download produced no readable file for book %s" id)))
          (org-entry-put nil "NOTER_DOCUMENT" download-file)
          (throw 'resolved download-file))
        (unless (org-up-heading-safe)
          (throw 'resolved nil))))))

(defun +wd/org-noter-current-node-operation ()
  "Run an Org operation on the node at the PDF viewport center."
  (interactive)
  (let* ((operation last-command-event)
         (session (and (boundp 'org-noter--session) org-noter--session))
         doc-window center-location target target-location ignore-until-level)
    (unless (and session
                 (org-noter--valid-session session)
                 (eq (org-noter--session-doc-buffer session) (current-buffer)))
      (user-error "No active Org-noter session for this document"))
    (setq doc-window
          (get-buffer-window (org-noter--session-doc-buffer session)
                             (org-noter--session-frame session)))
    (unless (window-live-p doc-window)
      (user-error "Org-noter document window is not visible"))
    (save-selected-window
      (with-selected-window doc-window
        (let ((percentage
               (org-noter--conv-page-scroll-percentage
                (+ (window-vscroll) (/ (window-body-height) 2.0))
                (+ (window-hscroll) (/ (window-body-width) 2.0)))))
          (setq center-location
                (cons (image-mode-window-get 'page) percentage))))
      (with-current-buffer (org-noter--session-notes-buffer session)
        (save-excursion
          (org-element-map
              (org-element-contents (org-noter--parse-root))
              org-noter--note-search-element-type
            (lambda (element)
              (let ((level (org-element-property :level element))
                    (doc-file (org-noter--doc-file-property element))
                    (location (org-noter--parse-location-property element)))
                (when (and ignore-until-level
                           (<= level ignore-until-level))
                  (setq ignore-until-level nil))
                (cond
                 (ignore-until-level)
                 ((and doc-file
                       (not (string= doc-file
                                     (org-noter--session-property-text session))))
                  (setq ignore-until-level level))
                 ((and location
                       (org-noter--compare-locations
                        '<= location center-location)
                       (or (not target-location)
                           (org-noter--compare-locations
                            '>= location target-location)))
                  (setq target element
                        target-location location)))))
            nil nil org-noter--note-search-no-recurse)
          (unless target
            (user-error "No Org-noter node at or before PDF viewport center"))
          (goto-char (org-element-property :begin target))
          (when (memq operation '(?o ?x))
            (unless (and (org-clocking-p)
                         (marker-buffer org-clock-hd-marker)
                         (eq (marker-buffer org-clock-hd-marker)
                             (or (buffer-base-buffer) (current-buffer)))
                         (= (marker-position org-clock-hd-marker) (point)))
              (user-error "Current node is not clocked in%s"
                          (if (org-clocking-p)
                              (format "; active clock: %s" org-clock-heading)
                            ""))))
          (pcase operation
            (?i (org-clock-in))
            (?o (org-clock-out))
            (?d (org-todo 'done))
            (?t (call-interactively #'org-todo))
            (?x (org-clock-cancel))
            (_ (error "Unsupported Org-noter operation: %S" operation))))))))

(defun +wd/org-noter-update-calibre-progress ()
  "Update Calibre Read column from org-noter or Calibre viewer progress."
  (interactive)
  (when (and (derived-mode-p 'org-mode)
             (member (and (boundp 'org-state) org-state) '("DONE" "KILL"))
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
          (id format server)
          (unless (string-match-p "\\`[0-9]+\\'" id)
            (user-error "Invalid Calibre book id: %s" id))
          (unless (string-match-p "\\`[[:alnum:]]+\\'" format)
            (user-error "Invalid Calibre format: %s" format))
          (let* ((json-array-type 'list)
                 (json-object-type 'alist)
                 (library-id (alist-get 'default_library_id
                                        (json-read-from-string
                                         (+wd/calibre-http server "GET"
                                                           "/interface-data/update/"))))
                 (data (json-read-from-string
                        (+wd/calibre-http
                         server "GET"
                         (format "/book-get-last-read-position/%s/%s-%s"
                                 library-id id format))))
                 (positions (alist-get (intern (format "%s:%s" id format)) data))
                 (latest (car (sort (copy-sequence positions)
                                    (lambda (a b)
                                      (> (or (alist-get 'epoch a) 0)
                                         (or (alist-get 'epoch b) 0)))))))
            (unless library-id
              (user-error "Missing Calibre content server library id"))
            (unless latest
              (user-error "Missing Calibre viewer progress for book %s %s"
                          id (upcase format)))
            (let ((pos-frac (alist-get 'pos_frac latest))
                  (epoch (alist-get 'epoch latest)))
              (unless (and (numberp pos-frac) (<= 0.0 pos-frac 1.0))
                (user-error "Invalid Calibre viewer progress %S for book %s %s"
                            pos-frac id (upcase format)))
              (unless (numberp epoch)
                (user-error "Missing Calibre viewer progress time for book %s %s"
                            id (upcase format)))
              (list (/ (round (* pos-frac 1000.0)) 10.0)
                    (calibre-progress-date (seconds-to-time epoch))
                    nil nil))))
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
                 (format (+wd/calibre-book-format id))
                 (server (+wd/calibre-content-server)))
            (unless format
              (user-error "Missing document format for Calibre book %s" id))
            (pcase-let ((`(,percentage ,read-date ,completed-pages ,total-pages)
                         (if (string= format "pdf")
                             (org-noter-page-progress id server)
                           (calibre-viewer-progress id format server))))
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

(setup org-noter
  (:setopt org-noter-doc-split-fraction '(0.7 . 0.3)
           org-noter-notes-search-path (list (file-truename "~/org/noter/current")))
  (:bind-into pdf-view
    "z" (cons "Melt's Sugar for PDF" (make-sparse-keymap))
    "z i" (cons "clock in" #'+wd/org-noter-current-node-operation)
    "z o" (cons "clock out" #'+wd/org-noter-current-node-operation)
    "z d" (cons "done" #'+wd/org-noter-current-node-operation)
    "z t" (cons "todo" #'+wd/org-noter-current-node-operation)
    "z x" (cons "cancel clock" #'+wd/org-noter-current-node-operation))
  (:hooks org-noter-parse-document-property-hook
          (:hook-options +wd/org-noter-resolve-calibre-document :depth 10))
  (:when-loaded
    (+wd/calibredb-configure-opds)))

(setup org
  (:hooks org-after-todo-state-change-hook +wd/org-noter-update-calibre-progress)
  (:when-loaded
    (+wd/calibredb-configure-opds)))

(provide 'init-org-noter)
;;; init-org-noter.el ends here
