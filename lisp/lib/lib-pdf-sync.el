;;; lib-pdf-sync.el --- Sync PDF annotations to Calibre -*- lexical-binding: t; -*-

(require 'json)
(require 'seq)
(require 'subr-x)
(require 'lib-calibre)

(defvar +wd/pdf-sync-ssh-host "nixos-nuc"
  "SSH host that can access the Calibre library files.")

(defvar +wd/pdf-sync-remote-library-root +wd/calibre-local-library-root
  "Calibre library root on `+wd/pdf-sync-ssh-host'.")

(defvar +wd/pdf-sync-remote-python-file
  (expand-file-name "pdf-sync/replay.py"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Local Python script sent to `+wd/pdf-sync-ssh-host' for annotation replay.")

(defun +wd/pdf-sync--remote-python-code ()
  "Return the remote annotation replay Python script."
  (unless (file-readable-p +wd/pdf-sync-remote-python-file)
    (user-error "PDF sync script is not readable: %s"
                +wd/pdf-sync-remote-python-file))
  (with-temp-buffer
    (insert-file-contents +wd/pdf-sync-remote-python-file)
    (buffer-string)))

(defun +wd/pdf-sync--calibre-id-from-file (file)
  "Extract a Calibre book id from FILE named like CDB-1234.pdf."
  (when-let* ((base (and file (file-name-base file))))
    (when (string-match "\\`CDB-\\([0-9]+\\)\\'" base)
      (match-string 1 base))))

(defun +wd/pdf-sync--calibre-id (&optional calibre-id)
  "Return CALIBRE-ID or derive it from the current PDF buffer."
  (or (and calibre-id (format "%s" calibre-id))
      (+wd/pdf-sync--calibre-id-from-file (buffer-file-name))
      (user-error "Cannot derive Calibre id from current PDF file name")))

(defun +wd/pdf-sync--annotation (annotation)
  "Return ANNOTATION without pdf-tools' process-local id."
  (seq-keep
   (lambda (cell)
     (unless (eq (car cell) 'id)
       (cons (car cell)
             (+wd/pdf-sync--json-value
              (pcase (car cell)
                ((or 'created 'modified)
                 (+wd/pdf-sync--pdf-date (cdr cell)))
                (_ (cdr cell)))))))
   annotation))

(defun +wd/pdf-sync--pdf-date (value)
  "Return VALUE as a PDF date string, or nil when VALUE is empty."
  (when value
    (condition-case nil
        (let* ((time (apply #'encode-time (decode-time value)))
               (zone (format-time-string "%z" time))
               (sign (substring zone 0 1))
               (hours (substring zone 1 3))
               (minutes (substring zone 3 5)))
          (format "%s%s%s'%s'"
                  (format-time-string "D:%Y%m%d%H%M%S" time)
                  sign hours minutes))
      (error
       (format "%s" value)))))

(defun +wd/pdf-sync--json-value (value)
  "Return VALUE in a shape `json-encode' serializes predictably."
  (cond
   ((null value) nil)
   ((vectorp value)
    (vconcat (mapcar #'+wd/pdf-sync--json-value (append value nil))))
   ((listp value) (vconcat (mapcar #'+wd/pdf-sync--json-value value)))
   (t value)))

(defun +wd/pdf-sync-export-annotations (pdf-file json-file)
  "Export annotations from PDF-FILE to JSON-FILE."
  (let ((annots nil)
        (pages (pdf-info-number-of-pages pdf-file)))
    (dotimes (index pages)
      (dolist (annotation (pdf-info-getannots (1+ index) pdf-file))
        (push (+wd/pdf-sync--annotation annotation) annots)))
    (with-temp-file json-file
      (let ((json-encoding-pretty-print t))
        (insert (json-encode (nreverse annots)))))
    json-file))

(defun +wd/pdf-sync--call (program &rest args)
  "Run PROGRAM with ARGS and return trimmed stdout."
  (let ((buffer (generate-new-buffer (format " *%s*" program))))
    (unwind-protect
        (let ((exit (apply #'call-process program nil buffer nil args)))
          (with-current-buffer buffer
            (let ((output (string-trim (buffer-string))))
              (unless (zerop exit)
                (user-error "%s failed: %s" program output))
              output)))
      (kill-buffer buffer))))

(defun +wd/pdf-sync--call-region (start end program &rest args)
  "Run PROGRAM with region START to END as stdin and return trimmed stdout."
  (let ((buffer (generate-new-buffer (format " *%s*" program))))
    (unwind-protect
        (let ((exit (apply #'call-process-region
                           start end program nil buffer nil args)))
          (with-current-buffer buffer
            (let ((output (string-trim (buffer-string))))
              (unless (zerop exit)
                (user-error "%s failed: %s" program output))
              output)))
      (kill-buffer buffer))))

;;;###autoload
(defun +wd/pdf-annot-sync (&optional calibre-id)
  "Sync current PDF annotations to the remote Calibre PDF.
CALIBRE-ID defaults to the id in a CDB-<id>.pdf file name."
  (interactive)
  (unless (derived-mode-p 'pdf-view-mode)
    (user-error "Not a PDF buffer"))
  (let* ((id (+wd/pdf-sync--calibre-id calibre-id))
         (pdf-file (pdf-view-buffer-file-name))
         (json-file (make-temp-file (format "pdf-annots-%s-" id) nil ".json"))
         (remote-json (format "/dev/shm/pdf-annots-%s-%s.json"
                              id (format-time-string "%s%N"))))
    (unwind-protect
        (progn
          (+wd/pdf-sync-export-annotations pdf-file json-file)
          (+wd/pdf-sync--call "scp" json-file
                              (format "%s:%s" +wd/pdf-sync-ssh-host remote-json))
          (let ((added (with-temp-buffer
                         (insert (+wd/pdf-sync--remote-python-code))
                         (+wd/pdf-sync--call-region
                          (point-min) (point-max)
                          "ssh" +wd/pdf-sync-ssh-host
                          "python3" "-" remote-json
                          +wd/pdf-sync-remote-library-root id))))
            (message "PDF annotation sync: book %s, added %s annotations"
                     id added)))
      (when (file-exists-p json-file)
        (delete-file json-file)))))

(defun +wd/pdf-sync-query-on-kill ()
  "Ask whether to sync annotations before killing the current PDF buffer."
  (when (and (derived-mode-p 'pdf-view-mode)
             (+wd/pdf-sync--calibre-id-from-file (pdf-view-buffer-file-name))
             (yes-or-no-p "Sync PDF annotations before closing? "))
    (+wd/pdf-annot-sync))
  t)

(defun +wd/pdf-sync-enable-query-on-kill ()
  "Enable annotation sync prompt for the current PDF buffer."
  (add-hook 'kill-buffer-query-functions #'+wd/pdf-sync-query-on-kill nil t))

(provide 'lib-pdf-sync)
;;; lib-pdf-sync.el ends here
