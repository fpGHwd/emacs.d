;;; lib-arxml.el --- ARXML breadcrumb mode and helpers -*- lexical-binding: t; -*-

;;; ---- Ancestor chain: data extraction ----

(defun +wd/arxml--treesit-available-p ()
  "Return non-nil if tree-sitter xml grammar is available."
  (and (treesit-available-p)
       (treesit-language-available-p 'xml)))

(defun +wd/arxml--stag-name (stag)
  "Extract tag Name text from STag node STAG.
The Name child is always at index 1 in the XML grammar."
  (let ((name-node (treesit-node-child stag 1)))
    (when (and name-node (equal "Name" (treesit-node-type name-node)))
      (treesit-node-text name-node))))

(defun +wd/arxml--ts-short-name (element-node)
  "Extract SHORT-NAME child value from ELEMENT-NODE using tree-sitter.
Returns nil if no SHORT-NAME child found."
  (let ((content (treesit-node-child element-node 1))
        sn-el sn-text)
    (when content
      (setq sn-el
            (treesit-search-subtree
             content
             (lambda (n)
               (and (equal "element" (treesit-node-type n))
                    (let ((stag (treesit-node-child n 0)))
                      (when stag
                        (equal "SHORT-NAME"
                               (+wd/arxml--stag-name stag))))))
             nil nil 5))
      (when sn-el
        (let ((sn-content (treesit-node-child sn-el 1)))
          (when sn-content
            (setq sn-text (treesit-node-text sn-content t))
            (unless (string-match-p "\\`[ \t\n\r]*\\'" sn-text)
              (string-trim sn-text))))))))

(defun +wd/arxml--get-short-name (start)
  "Extract direct SHORT-NAME child value from element starting at START.
Uses buffer text search; only used as nxml fallback."
  (save-excursion
    (goto-char start)
    (when (search-forward ">" (+ start 500) t)
      (skip-chars-forward " \t\n\r")
      (when (looking-at "<SHORT-NAME>\\([^<]+\\)</SHORT-NAME>")
        (match-string 1)))))

(defun +wd/arxml--ancestor-chain-treesit ()
  "Walk ancestors using tree-sitter xml grammar.
Return list of (tag-name start-pos short-name)."
  (let* ((node (treesit-node-at (point) 'xml))
         result)
    (while (and node (not (equal "element" (treesit-node-type node))))
      (setq node (treesit-node-parent node)))
    (while (and node (not (equal "document" (treesit-node-type node))))
      (when (equal "element" (treesit-node-type node))
        (let* ((stag (treesit-node-child node 0))
               (tag-name (or (+wd/arxml--stag-name stag) ""))
               (start-pos (treesit-node-start node))
               (sn (+wd/arxml--ts-short-name node)))
          (push (list tag-name start-pos sn) result)))
      (setq node (treesit-node-parent node)))
    (nreverse result)))

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

(defun +wd/arxml-ancestor-chain ()
  "Walk ancestors from point to root.
Return list of (tag-name start-pos short-name).
Uses tree-sitter when the xml grammar is available, nxml otherwise."
  (if (+wd/arxml--treesit-available-p)
      (+wd/arxml--ancestor-chain-treesit)
    (+wd/arxml--ancestor-chain-nxml)))

;;; ---- Breadcrumb mode ----

(defvar-local +wd/arxml--breadcrumb-cache nil
  "Cached ancestor chain: (start-tag-pos . chain).
nil means no cache.")

(defvar-local +wd/arxml--breadcrumb-timer nil
  "Idle timer for debounced breadcrumb update.")

(defvar-local +wd/arxml--treesit-ready nil
  "Non-nil once the treesit xml parser has completed its first full parse.")

(defvar +wd/arxml-breadcrumb-map
  (let ((map (make-sparse-keymap)))
    (define-key map [header-line mouse-1] #'+wd/arxml-breadcrumb-click)
    map)
  "Keymap for clickable breadcrumb segments in header-line.")

(defvar arxml-breadcrumb-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c c f") #'+wd/arxml-breadcrumb-jump-to-ancestor)
    map)
  "Keymap for `arxml-breadcrumb-mode'.")

(defun +wd/arxml--ensure-treesit-parsed ()
  "Ensure treesit xml parser has completed its first full parse.
On large files the first parse can take many seconds; trigger it
eagerly so the tree is ready before the user starts navigating."
  (when (and (+wd/arxml--treesit-available-p)
             (not +wd/arxml--treesit-ready))
    (when-let ((parser (car (treesit-parser-list))))
      (treesit-parser-root-node parser)
      (setq +wd/arxml--treesit-ready t))))

(defun +wd/arxml--current-element-start ()
  "Return the start-tag position of the element containing point.
Uses tree-sitter when available, otherwise nxml.
Returns nil if treesit hasn't parsed yet to avoid blocking."
  (if (+wd/arxml--treesit-available-p)
      (if (not +wd/arxml--treesit-ready)
          nil
        (let ((node (treesit-node-at (point) 'xml)))
          (while (and node (not (equal "element" (treesit-node-type node))))
            (setq node (treesit-node-parent node)))
          (when node (treesit-node-start node))))
    (save-excursion
      (require 'nxml-rap)
      (nxml-ensure-scan-up-to-date)
      (when (nxml-scan-element-backward (point) t)
        xmltok-start))))

(defun +wd/arxml-breadcrumb-schedule ()
  "Schedule a debounced breadcrumb update via idle timer.
Skips if treesit hasn't parsed yet to avoid blocking post-command-hook."
  (when (derived-mode-p 'nxml-mode)
    (if (and (+wd/arxml--treesit-available-p)
             (not +wd/arxml--treesit-ready))
        (unless +wd/arxml--breadcrumb-timer
          (setq +wd/arxml--breadcrumb-timer
                (run-with-idle-timer 0.3 nil
                                     #'+wd/arxml--breadcrumb-eager-parse
                                     (current-buffer))))
      (let ((current-start (+wd/arxml--current-element-start)))
        (unless (and +wd/arxml--breadcrumb-cache
                     (equal current-start (car +wd/arxml--breadcrumb-cache)))
          (when +wd/arxml--breadcrumb-timer
            (cancel-timer +wd/arxml--breadcrumb-timer))
          (setq +wd/arxml--breadcrumb-timer
                (run-with-idle-timer 0.15 nil
                                     #'+wd/arxml--breadcrumb-update-debounced
                                     (current-buffer))))))))

(defun +wd/arxml--breadcrumb-eager-parse (buffer)
  "Trigger treesit parse for BUFFER and then update breadcrumb."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when arxml-breadcrumb-mode
        (+wd/arxml--ensure-treesit-parsed)
        (when +wd/arxml--treesit-ready
          (+wd/arxml--breadcrumb-update-debounced buffer))))))

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
  "Invalidate breadcrumb cache on buffer content changes."
  (setq +wd/arxml--breadcrumb-cache nil))

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

;;; ---- Folding ----

(declare-function treesit-fold-mode "treesit-fold" t)
(declare-function treesit-fold-parsers-xml "treesit-fold-parsers" nil)

(defun +wd/arxml--setup-treesit-fold ()
  "Configure treesit-fold for nxml-mode with XML grammar rules."
  (when (and (require 'treesit-fold nil t)
             (+wd/arxml--treesit-available-p))
    (unless (assq 'nxml-mode treesit-fold-range-alist)
      (add-to-list 'treesit-fold-range-alist
                   (cons 'nxml-mode (treesit-fold-parsers-xml))))
    (treesit-fold-mode 1)))

;;;###autoload
(define-minor-mode arxml-breadcrumb-mode
  "Toggle ARXML breadcrumb display in header-line."
  :init-value nil
  :lighter " Breadcrumb"
  :keymap arxml-breadcrumb-mode-map
  (if arxml-breadcrumb-mode
      (progn
        (add-hook 'post-command-hook #'+wd/arxml-breadcrumb-schedule nil t)
        (add-hook 'after-change-functions #'+wd/arxml-breadcrumb-invalidate-cache nil t)
        (run-with-idle-timer 0.1 nil #'+wd/arxml--ensure-treesit-parsed)
        (+wd/arxml--setup-treesit-fold))
    (remove-hook 'post-command-hook #'+wd/arxml-breadcrumb-schedule t)
    (remove-hook 'after-change-functions #'+wd/arxml-breadcrumb-invalidate-cache t)
    (when (bound-and-true-p treesit-fold-mode)
      (treesit-fold-mode -1))
    (when +wd/arxml--breadcrumb-timer
      (cancel-timer +wd/arxml--breadcrumb-timer))
    (setq +wd/arxml--breadcrumb-timer nil
          +wd/arxml--breadcrumb-cache nil
          +wd/arxml--treesit-ready nil)
    (setq header-line-format nil)))

(provide 'lib-arxml)
;;; lib-arxml.el ends here
