;;; lib-arxml.el --- ARXML breadcrumb helpers -*- lexical-binding: t; -*-

(defvar +wd/arxml-breadcrumb-map
  (let ((map (make-sparse-keymap)))
    (define-key map [header-line mouse-1] #'+wd/arxml-breadcrumb-click)
    map)
  "Keymap for clickable breadcrumb segments in header-line.")

(defun +wd/arxml--get-short-name (start)
  "Extract direct SHORT-NAME child value from element starting at START."
  (save-excursion
    (goto-char start)
    (when (search-forward ">" (+ start 500) t)
      (skip-chars-forward " \t\n\r")
      (when (looking-at "<SHORT-NAME>\\([^<]+\\)</SHORT-NAME>")
        (match-string 1)))))

(defun +wd/arxml-ancestor-chain ()
  "Walk ancestors from point to root.
Return list of (tag-name start-pos short-name)."
  (require 'nxml-rap)
  (nxml-ensure-scan-up-to-date)
  (let (result pos)
    (setq pos (point))
    (catch 'done
      (while t
        (unless (nxml-scan-element-backward pos t)
          (throw 'done nil))
        (let ((name (xmltok-start-tag-qname))
              (start xmltok-start)
              (sn (+wd/arxml--get-short-name xmltok-start)))
          (push (list name start sn) result)
          (when (= start (point-min))
            (throw 'done nil))
          (setq pos start))))
    (nreverse result)))

(defun +wd/arxml-breadcrumb-format (chain)
  "Format CHAIN into a clickable breadcrumb string for the header-line."
  (if (not chain) ""
    (let (segments)
      (dolist (entry chain)
        (let ((name (car entry)) (sn (caddr entry)))
          (push (if sn (format "%s[%s]" name sn) name) segments)))
      (propertize (mapconcat #'identity (nreverse segments) " > ")
                  'keymap +wd/arxml-breadcrumb-map
                  'mouse-face 'highlight))))

(defun +wd/arxml-breadcrumb-update ()
  "Update header-line with ancestor chain of XML element at point."
  (when (derived-mode-p 'nxml-mode)
    (let* ((chain (+wd/arxml-ancestor-chain))
           (fmt (+wd/arxml-breadcrumb-format chain)))
      (if (string= fmt "")
          (setq header-line-format nil)
        (setq header-line-format (concat "  " fmt))))))

(defun +wd/arxml-breadcrumb-click (event)
  "Handle mouse click on header-line breadcrumb. Jump to clicked segment."
  (interactive "e")
  (push-mark)
  (let* ((posn (event-start event))
         (offset (cdr (posn-string posn)))
         (chain (+wd/arxml-ancestor-chain))
         (current-offset 0))
    (dolist (entry chain)
      (let* ((name (car entry))
             (sn (caddr entry))
             (seg (if sn (format "%s[%s]" name sn) name))
             (seg-len (length seg)))
        (when (and (>= offset current-offset)
                   (< offset (+ current-offset seg-len)))
          (goto-char (cadr entry))
          (recenter))
        (setq current-offset (+ current-offset seg-len 3))))))

(defun +wd/arxml-breadcrumb-jump-to-ancestor ()
  "Jump to an ancestor element chosen via completing-read."
  (interactive)
  (push-mark)
  (let* ((chain (+wd/arxml-ancestor-chain))
         (choices (mapcar (lambda (entry)
                            (let ((name (car entry)) (sn (caddr entry)))
                              (if sn (format "%s[%s]" name sn) name)))
                          chain))
         (choice (completing-read "Jump to: " choices nil t))
         (idx (cl-position choice choices :test #'string=)))
    (when idx
      (goto-char (cadr (nth idx chain)))
      (recenter))))

(provide 'lib-arxml)
;;; lib-arxml.el ends here
