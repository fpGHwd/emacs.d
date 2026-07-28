;;; lib-arxml.el --- ARXML breadcrumb helpers -*- lexical-binding: t; -*-

;; Cache for debounced breadcrumb updates
(defvar-local +wd/arxml--breadcrumb-cache nil
  "Cached ancestor chain: (start-tag-pos . chain).
chain is the list from `+wd/arxml-ancestor-chain'.
nil means no cache.")

(defvar-local +wd/arxml--breadcrumb-timer nil
  "Idle timer for debounced breadcrumb update.")

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

;; ---- Tree-sitter path (primary, O(D) total) ----

(defun +wd/arxml--stag-name (stag)
  "Extract tag Name text from STag node STAG."
  (let ((name-node nil)
        (count (treesit-node-child-count stag)))
    (dotimes (i count)
      (let ((c (treesit-node-child stag i)))
        (when (equal "Name" (treesit-node-type c))
          (setq name-node c))))
    (when name-node (treesit-node-text name-node))))

(defun +wd/arxml--ancestor-chain-treesit ()
  "Walk ancestors using tree-sitter xml grammar.
Return list of (tag-name start-pos short-name)."
  (let* ((node (treesit-node-at (point) 'xml))
         result)
    ;; Walk up to the nearest element node if point is on CharData/content
    (while (and node (not (equal "element" (treesit-node-type node))))
      (setq node (treesit-node-parent node)))
    (while (and node (not (equal "document" (treesit-node-type node))))
      (when (equal "element" (treesit-node-type node))
        (let* ((stag (treesit-node-child node 0))
               (tag-name (or (+wd/arxml--stag-name stag) ""))
               (start-pos (treesit-node-start node))
               (sn (+wd/arxml--get-short-name start-pos)))
          (push (list tag-name start-pos sn) result)))
      (setq node (treesit-node-parent node)))
    (nreverse result)))

;; ---- nxml path (fallback, O(D*N) total) ----

(defun +wd/arxml--ancestor-chain-nxml ()
  "Walk ancestors from point to root using nxml backward scanning.
Return list of (tag-name start-pos short-name).
O(D*N) total work -- use only as fallback when tree-sitter is not available."
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

;; ---- Dispatch ----

(defun +wd/arxml-ancestor-chain ()
  "Walk ancestors from point to root.
Return list of (tag-name start-pos short-name).
Uses tree-sitter when the xml grammar is available (O(D) total).
Falls back to nxml backward scanning when not (O(D*N) total)."
  (if (and (treesit-available-p)
           (treesit-language-available-p 'xml))
      (+wd/arxml--ancestor-chain-treesit)
    (+wd/arxml--ancestor-chain-nxml)))

;; ---- Cache helpers ----

(defun +wd/arxml--current-element-start ()
  "Return the start-tag position of the element containing point.
Uses tree-sitter when available, otherwise nxml."
  (if (and (treesit-available-p)
           (treesit-language-available-p 'xml))
      (let ((node (treesit-node-at (point) 'xml)))
        (while (and node (not (equal "element" (treesit-node-type node))))
          (setq node (treesit-node-parent node)))
        (when node (treesit-node-start node)))
    (save-excursion
      (require 'nxml-rap)
      (nxml-ensure-scan-up-to-date)
      (when (nxml-scan-element-backward (point) t)
        xmltok-start))))

;; ---- Debounce & cache ----

(defun +wd/arxml-breadcrumb-schedule ()
  "Schedule a debounced breadcrumb update via idle timer.
Only schedules if point has moved to a different element (cache miss).
This is called from `post-command-hook'."
  (when (derived-mode-p 'nxml-mode)
    (let ((current-start (+wd/arxml--current-element-start)))
      (unless (and +wd/arxml--breadcrumb-cache
                   (equal current-start (car +wd/arxml--breadcrumb-cache)))
        (when +wd/arxml--breadcrumb-timer
          (cancel-timer +wd/arxml--breadcrumb-timer))
        (setq +wd/arxml--breadcrumb-timer
              (run-with-idle-timer 0.15 nil
                                   #'+wd/arxml--breadcrumb-update-debounced
                                   (current-buffer)))))))

(defun +wd/arxml--breadcrumb-update-debounced (buffer)
  "Perform the actual breadcrumb update in BUFFER.
Called by the idle timer from `+wd/arxml-breadcrumb-schedule'."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when arxml-breadcrumb-mode
        (let* ((chain (+wd/arxml-ancestor-chain))
               (start (+wd/arxml--current-element-start))
               (fmt (+wd/arxml-breadcrumb-format chain)))
          (setq +wd/arxml--breadcrumb-cache (when start (cons start chain)))
          (if (string= fmt "")
              (setq header-line-format nil)
            (setq header-line-format (concat "  " fmt))))))))

(defun +wd/arxml-breadcrumb-invalidate-cache (_beg _end _len)
  "Invalidate breadcrumb cache on buffer content changes.
Registered on `after-change-functions' to handle edits that
modify element structure."
  (setq +wd/arxml--breadcrumb-cache nil))

;; ---- Formatting ----

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

;; ---- Interactive ----

(defun +wd/arxml-breadcrumb-click (event)
  "Handle mouse click on header-line breadcrumb. Jump to clicked segment."
  (interactive "e")
  (push-mark)
  (let* ((posn (event-start event))
         (offset (cdr (posn-string posn)))
         (chain (or (cdr +wd/arxml--breadcrumb-cache)
                    (+wd/arxml-ancestor-chain)))
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
  (let* ((chain (or (cdr +wd/arxml--breadcrumb-cache)
                    (+wd/arxml-ancestor-chain)))
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
