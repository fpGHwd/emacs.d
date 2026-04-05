;;; autosar-can-mode.el --- Inspect BLF frames with AUTOSAR ARXML -*- lexical-binding: t; -*-

;; Author: Wang Ding(ggwdwhu@gmail.com), codex
;; Keywords: tools, autosar, can
;; Package-Requires: ((emacs "28.1"))

;;; Commentary:

;; A single-file workflow for automotive CAN analysis inside Emacs.
;;
;; Features:
;; - `autosar-can-mode' for `.arxml' files.
;; - Parse common AUTOSAR signal mapping nodes from ARXML.
;; - Read BLF directly through an embedded Python backend.
;; - Decode CAN signals bit-by-bit using ARXML mapping metadata.
;; - Present the latest decoded signal values in a tabulated report buffer.
;;
;; Usage:
;; 1. Visit an `.arxml' file. `autosar-can-mode' will be enabled automatically.
;; 2. Install `python-can' in the Python environment used by Emacs.
;; 3. Optionally set `autosar-can-python-executable'.
;; 3. Run `M-x autosar-can-compare-blf'.
;;
;; Notes:
;; - AUTOSAR schemas differ between vendors. This parser is intentionally
;;   heuristic and targets the common CAN / I-PDU / signal mapping cases.
;; - BLF parsing is delegated to an embedded Python snippet using `python-can'.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'nxml-mode)
(require 'subr-x)
(require 'tabulated-list)
(require 'xml)

(defgroup autosar-can nil
  "Inspect BLF traces with AUTOSAR ARXML."
  :group 'tools
  :prefix "autosar-can-")

(defcustom autosar-can-python-executable
  (or (executable-find "python3")
      (executable-find "python"))
  "Python executable used to read BLF files with `python-can'."
  :type '(choice (const :tag "Not found" nil) file)
  :group 'autosar-can)

(defcustom autosar-can-max-frames 20000
  "Maximum number of decoded text frames read from the BLF dump."
  :type 'integer
  :group 'autosar-can)

(defcustom autosar-can-default-id-filter nil
  "Optional default CAN ID filter.

When non-nil, only matching CAN IDs are decoded. Accepts integers, hex strings
like \"0x123\", or nil."
  :type '(choice (const :tag "No filter" nil)
                 integer
                 string)
  :group 'autosar-can)

(defface autosar-can-warning-face
  '((t :inherit font-lock-warning-face))
  "Face used for warnings in report buffers."
  :group 'autosar-can)

(defvar-local autosar-can--report-state nil
  "State plist used by `autosar-can-report-mode'.")

(defvar autosar-can-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-b") #'autosar-can-compare-blf)
    (define-key map (kbd "C-c C-r") #'autosar-can-compare-blf)
    map)
  "Keymap for `autosar-can-mode'.")

(defvar autosar-can-report-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "g") #'autosar-can-report-refresh)
    (define-key map (kbd "f") #'autosar-can-report-set-id-filter)
    map)
  "Keymap for `autosar-can-report-mode'.")

(define-derived-mode autosar-can-mode nxml-mode "AUTOSAR-CAN"
  "Major mode for AUTOSAR ARXML CAN analysis."
  (setq-local comment-start "<!--")
  (setq-local comment-end "-->"))

(define-derived-mode autosar-can-report-mode tabulated-list-mode "AUTOSAR-BLF"
  "Mode for decoded BLF signal reports."
  (setq tabulated-list-format
        [("CAN ID" 10 t)
         ("Frame" 24 t)
         ("Signal" 28 t)
         ("Start" 6 t)
         ("Len" 5 t)
         ("Order" 8 t)
         ("Raw" 18 t)
         ("Seen" 6 t)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-sort-key '("CAN ID" . nil))
  (tabulated-list-init-header))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.arxml\\'" . autosar-can-mode))

(defun autosar-can-compare-blf (blf-file &optional id-filter)
  "Decode BLF-FILE with the current ARXML buffer.

Optional argument ID-FILTER limits decoding to a single CAN ID."
  (interactive
   (list (read-file-name "BLF file: " nil nil t nil
                         (lambda (file)
                           (not (file-directory-p file))))
         (let ((raw (read-string "CAN ID filter (hex, empty for all): "
                                 (when autosar-can-default-id-filter
                                   (format "%s" autosar-can-default-id-filter)))))
           (unless (string-empty-p raw) raw))))
  (unless buffer-file-name
    (user-error "Current ARXML buffer is not visiting a file"))
  (let* ((parsed-filter (autosar-can--normalize-id-filter (or id-filter autosar-can-default-id-filter)))
         (arxml-file buffer-file-name)
         (arxml-db (autosar-can--parse-arxml arxml-file))
         (frames (autosar-can--read-blf-frames blf-file))
         (decoded (autosar-can--decode-frames arxml-db frames parsed-filter))
         (report-buffer (get-buffer-create "*AUTOSAR BLF Report*")))
    (with-current-buffer report-buffer
      (autosar-can-report-mode)
      (setq autosar-can--report-state
            (list :arxml-file arxml-file
                  :blf-file blf-file
                  :id-filter parsed-filter
                  :entries decoded))
      (autosar-can--render-report decoded arxml-db frames))
    (pop-to-buffer report-buffer)))

(defun autosar-can-report-refresh ()
  "Refresh the current AUTOSAR BLF report."
  (interactive)
  (unless autosar-can--report-state
    (user-error "No report state in current buffer"))
  (let* ((arxml-file (plist-get autosar-can--report-state :arxml-file))
         (blf-file (plist-get autosar-can--report-state :blf-file))
         (id-filter (plist-get autosar-can--report-state :id-filter))
         (arxml-db (autosar-can--parse-arxml arxml-file))
         (frames (autosar-can--read-blf-frames blf-file))
         (decoded (autosar-can--decode-frames arxml-db frames id-filter)))
    (setq autosar-can--report-state
          (plist-put autosar-can--report-state :entries decoded))
    (autosar-can--render-report decoded arxml-db frames)
    (message "Refreshed %s" (file-name-nondirectory blf-file))))

(defun autosar-can-report-set-id-filter (raw)
  "Set CAN ID filter to RAW and refresh the current report."
  (interactive
   (list (read-string "CAN ID filter (hex, empty for all): "
                      (when-let ((current (plist-get autosar-can--report-state :id-filter)))
                        (format "0x%X" current)))))
  (unless autosar-can--report-state
    (user-error "No report state in current buffer"))
  (setf (plist-get autosar-can--report-state :id-filter)
        (autosar-can--normalize-id-filter (unless (string-empty-p raw) raw)))
  (autosar-can-report-refresh))

(defun autosar-can--render-report (decoded arxml-db frames)
  "Render DECODED entries using ARXML-DB and FRAMES."
  (let* ((summary (autosar-can--report-summary decoded arxml-db frames))
         (rows (mapcar #'autosar-can--tabulated-row decoded)))
    (setq header-line-format (propertize (concat " " summary) 'face 'shadow))
    (let ((inhibit-read-only t))
      (setq tabulated-list-entries rows)
      (tabulated-list-print t))))

(defun autosar-can--tabulated-row (entry)
  "Convert decoded ENTRY to a `tabulated-list-entries' row."
  (let ((id (plist-get entry :id))
        (frame (plist-get entry :frame-name))
        (signal (plist-get entry :signal-name))
        (start (plist-get entry :start-bit))
        (length (plist-get entry :length))
        (order (plist-get entry :byte-order))
        (raw (plist-get entry :raw))
        (seen (plist-get entry :seen-count)))
    (list (format "%s/%s" id signal)
          (vector (format "0x%03X" id)
                  (or frame "?")
                  (or signal "?")
                  (number-to-string start)
                  (number-to-string length)
                  (or order "?")
                  (format "%s" raw)
                  (number-to-string seen)))))

(defun autosar-can--report-summary (decoded arxml-db frames)
  "Return summary text for DECODED entries using ARXML-DB and FRAMES."
  (let ((frame-def-count (hash-table-count (plist-get arxml-db :frames-by-id)))
        (signal-count (length (plist-get arxml-db :signals)))
        (frame-count (length frames))
        (decoded-count (length decoded)))
    (format "ARXML frames: %d, ARXML signals: %d, trace frames: %d, decoded signals: %d"
            frame-def-count signal-count frame-count decoded-count)))

(defun autosar-can--read-blf-frames (blf-file)
  "Read BLF-FILE with the embedded Python backend."
  (unless autosar-can-python-executable
    (user-error "Set autosar-can-python-executable to a usable Python interpreter"))
  (unless (file-readable-p blf-file)
    (user-error "BLF file is not readable: %s" blf-file))
  (autosar-can--read-blf-frames-via-python blf-file))

(defconst autosar-can--python-blf-reader
  (concat
   "import json, sys\n"
   "try:\n"
   "    import can\n"
   "except Exception as exc:\n"
   "    sys.stderr.write('python-can import failed: %s\\n' % (exc,))\n"
   "    sys.exit(2)\n"
   "path = sys.argv[1]\n"
   "limit = int(sys.argv[2])\n"
   "frames = []\n"
   "reader = can.BLFReader(path)\n"
   "try:\n"
   "    for index, msg in enumerate(reader):\n"
   "        if index >= limit:\n"
   "            break\n"
   "        data = bytes(msg.data).hex().upper()\n"
   "        frames.append({\n"
   "            'id': int(msg.arbitration_id),\n"
   "            'data': data,\n"
   "            'extended': bool(getattr(msg, 'is_extended_id', False)),\n"
   "            'dlc': int(getattr(msg, 'dlc', len(msg.data))),\n"
   "        })\n"
   "finally:\n"
   "    close = getattr(reader, 'stop', None) or getattr(reader, 'close', None)\n"
   "    if close is not None:\n"
   "        close()\n"
   "json.dump(frames, sys.stdout)\n")
  "Embedded Python code used to read BLF via `python-can'.")

(defun autosar-can--read-blf-frames-via-python (blf-file)
  "Read BLF-FILE through `python-can' and return frame plists."
  (let ((stdout (generate-new-buffer " *autosar-can-python-out*"))
        (stderr-file (make-temp-file "autosar-can-python-stderr-")))
    (unwind-protect
        (let ((status (process-file autosar-can-python-executable
                                    nil
                                    (list stdout stderr-file)
                                    nil
                                    "-c"
                                    autosar-can--python-blf-reader
                                    (expand-file-name blf-file)
                                    (number-to-string autosar-can-max-frames))))
          (unless (eq status 0)
            (let ((stderr (with-temp-buffer
                            (insert-file-contents stderr-file)
                            (string-trim (buffer-string)))))
              (user-error "Python BLF backend failed: %s"
                          (if (string-empty-p stderr)
                              (format "exit code %s" status)
                            stderr))))
          (with-current-buffer stdout
            (goto-char (point-min))
            (autosar-can--frames-from-json
             (json-parse-buffer :array-type 'list :object-type 'plist))))
      (when (buffer-live-p stdout)
        (kill-buffer stdout))
      (ignore-errors (delete-file stderr-file)))))

(defun autosar-can--frames-from-json (items)
  "Convert Python JSON ITEMS to internal frame plists."
  (mapcar (lambda (item)
            (list :id (plist-get item :id)
                  :data (autosar-can--hex-to-bytes (or (plist-get item :data) ""))))
          items))

(defun autosar-can--hex-to-bytes (hex)
  "Convert HEX string to a vector of bytes."
  (let* ((clean (replace-regexp-in-string "[^0-9A-Fa-f]" "" hex))
         (normalized (if (cl-oddp (length clean))
                         (concat "0" clean)
                       clean))
         (len (/ (length normalized) 2))
         (bytes (make-vector len 0))
         (i 0))
    (while (< i len)
      (aset bytes i
            (string-to-number
             (substring normalized (* i 2) (+ (* i 2) 2))
             16))
      (setq i (1+ i)))
    bytes))

(defun autosar-can--decode-frames (arxml-db frames id-filter)
  "Decode FRAMES with ARXML-DB, optionally filtered by ID-FILTER."
  (let ((frames-by-id (plist-get arxml-db :frames-by-id))
        (latest (make-hash-table :test #'equal)))
    (dolist (frame frames)
      (let ((id (plist-get frame :id)))
        (when (or (null id-filter) (= id id-filter))
          (dolist (frame-def (gethash id frames-by-id))
            (dolist (signal (plist-get frame-def :signals))
              (when-let ((value (autosar-can--decode-signal-value frame signal)))
                (let ((key (cons id (plist-get signal :signal-name))))
                  (puthash key
                           (plist-put
                            (plist-put
                             (plist-put value :id id)
                             :frame-name (plist-get frame-def :frame-name))
                            :seen-count (1+ (or (plist-get (gethash key latest) :seen-count) 0)))
                           latest))))))))
    (let (entries)
      (maphash (lambda (_ entry) (push entry entries)) latest)
      (sort entries
            (lambda (a b)
              (if (= (plist-get a :id) (plist-get b :id))
                  (string-lessp (or (plist-get a :signal-name) "")
                                (or (plist-get b :signal-name) ""))
                (< (plist-get a :id) (plist-get b :id))))))))

(defun autosar-can--decode-signal-value (frame signal)
  "Decode SIGNAL from FRAME and return a plist."
  (let* ((start-bit (plist-get signal :start-bit))
         (length (plist-get signal :length))
         (byte-order (plist-get signal :byte-order))
         (data (plist-get frame :data)))
    (when (and (integerp start-bit)
               (integerp length)
               (> length 0)
               (vectorp data)
               (> (length data) 0))
      (condition-case nil
          (let ((raw (pcase byte-order
                       ((or "little" "intel") (autosar-can--decode-little-endian data start-bit length))
                       ((or "big" "motorola") (autosar-can--decode-big-endian data start-bit length))
                       (_ (autosar-can--decode-little-endian data start-bit length)))))
            (list :signal-name (plist-get signal :signal-name)
                  :start-bit start-bit
                  :length length
                  :byte-order byte-order
                  :raw raw))
        (args-out-of-range nil)))))

(defun autosar-can--decode-little-endian (data start-bit length)
  "Decode little-endian DATA from START-BIT for LENGTH bits."
  (let ((value 0)
        (i 0))
    (while (< i length)
      (let* ((absolute (+ start-bit i))
             (byte-index (/ absolute 8))
             (bit-index (% absolute 8))
             (bit (if (< byte-index (length data))
                      (logand 1 (ash (aref data byte-index) (- bit-index)))
                    0)))
        (setq value (logior value (ash bit i))))
      (setq i (1+ i)))
    value))

(defun autosar-can--decode-big-endian (data start-bit length)
  "Decode big-endian DATA from START-BIT for LENGTH bits.

The implementation follows the usual Motorola bit numbering used in DBC-like
CAN tooling."
  (let ((value 0)
        (bit-pos start-bit))
    (dotimes (_ length value)
      (let* ((byte-index (/ bit-pos 8))
             (bit-index (% bit-pos 8))
             (bit (if (< byte-index (length data))
                      (logand 1 (ash (aref data byte-index) (- bit-index)))
                    0)))
        (setq value (logior (ash value 1) bit))
        (setq bit-pos (if (= bit-index 0)
                          (+ bit-pos 15)
                        (1- bit-pos)))))))

(defun autosar-can--normalize-id-filter (value)
  "Normalize CAN ID filter VALUE to an integer or nil."
  (cond
   ((null value) nil)
   ((integerp value) value)
   ((stringp value)
    (let ((trimmed (string-trim value)))
      (cond
       ((string-empty-p trimmed) nil)
       ((string-prefix-p "0x" (downcase trimmed))
        (string-to-number trimmed 16))
       (t (string-to-number trimmed 16)))))
   (t nil)))

(defun autosar-can--parse-arxml (file)
  "Parse AUTOSAR ARXML FILE into a compact database plist."
  (let* ((tree (with-temp-buffer
                 (insert-file-contents file)
                 (if (fboundp 'libxml-parse-xml-region)
                     (libxml-parse-xml-region (point-min) (point-max))
                   (car (xml-parse-region (point-min) (point-max))))))
         (signal-defs (make-hash-table :test #'equal))
         (pdu-signals (make-hash-table :test #'equal))
         (frame-pdus (make-hash-table :test #'equal))
         (frames-by-id (make-hash-table :test #'equal)))
    (autosar-can--walk tree nil
                       (lambda (node ancestors)
                         (autosar-can--collect-signal-definition node signal-defs)
                         (autosar-can--collect-pdu-signal-mapping node ancestors signal-defs pdu-signals)
                         (autosar-can--collect-frame-pdu-mapping node ancestors frame-pdus)
                         (autosar-can--collect-can-frame-triggering node frame-pdus pdu-signals frames-by-id)))
    (list :signal-defs signal-defs
          :signals (autosar-can--hash-values signal-defs)
          :frames-by-id frames-by-id)))

(defun autosar-can--collect-signal-definition (node signal-defs)
  "Collect signal definition from NODE into SIGNAL-DEFS."
  (let ((tag (autosar-can--tag-name node)))
    (when (and (string-match-p "SIGNAL\\'" tag)
               (not (string-match-p "GROUP\\'" tag)))
      (when-let ((name (autosar-can--child-text node "SHORT-NAME")))
        (puthash name
                 (list :signal-name name
                       :length (autosar-can--maybe-number
                                (or (autosar-can--child-text node "LENGTH")
                                    (autosar-can--child-text node "BIT-LENGTH")))
                       :base-type (or (autosar-can--ref-basename
                                       (autosar-can--child-text node "BASE-TYPE-REF"))
                                      (autosar-can--child-text node "BASE-TYPE")))
                 signal-defs)))))

(defun autosar-can--collect-pdu-signal-mapping (node ancestors signal-defs pdu-signals)
  "Collect signal mapping from NODE using ANCESTORS.
SIGNAL-DEFS and PDU-SIGNALS are mutable tables."
  (let ((tag (autosar-can--tag-name node)))
    (when (string-match-p "SIGNAL-TO-.*MAPPING\\'" tag)
      (let* ((pdu-name (autosar-can--ancestor-short-name
                        ancestors
                        (lambda (name)
                          (string-match-p "PDU\\'" name))))
             (signal-name (or (autosar-can--ref-basename
                               (autosar-can--first-ref-text node "SIGNAL"))
                              (autosar-can--ref-basename
                               (autosar-can--first-ref-text node "I-SIGNAL"))
                              (autosar-can--ref-basename
                               (autosar-can--first-ref-text node "SYSTEM-SIGNAL"))
                              (autosar-can--child-text node "SHORT-NAME")))
             (length (autosar-can--maybe-number
                      (or (autosar-can--child-text node "LENGTH")
                          (autosar-can--child-text node "BIT-LENGTH")
                          (plist-get (gethash signal-name signal-defs) :length))))
             (start-bit (autosar-can--maybe-number
                         (or (autosar-can--child-text node "START-POSITION")
                             (autosar-can--child-text node "START-BIT"))))
             (byte-order (autosar-can--normalize-byte-order
                          (or (autosar-can--child-text node "PACKING-BYTE-ORDER")
                              (autosar-can--child-text node "BYTE-ORDER")))))
        (when (and pdu-name signal-name (integerp start-bit) (integerp length))
          (puthash pdu-name
                   (cons (list :signal-name signal-name
                               :start-bit start-bit
                               :length length
                               :byte-order byte-order)
                         (gethash pdu-name pdu-signals))
                   pdu-signals))))))

(defun autosar-can--collect-frame-pdu-mapping (node ancestors frame-pdus)
  "Collect frame to PDU mapping from NODE using ANCESTORS into FRAME-PDUS."
  (let ((tag (autosar-can--tag-name node)))
    (when (or (string-match-p "PDU-TO-FRAME-MAPPING\\'" tag)
              (string-match-p "FRAME-PORT-REF\\'" tag))
      (let* ((frame-name (autosar-can--ancestor-short-name
                          ancestors
                          (lambda (name)
                            (string-match-p "FRAME\\'" name))))
             (pdu-name (or (autosar-can--ref-basename
                            (autosar-can--first-ref-text node "PDU"))
                           (autosar-can--ref-basename (autosar-can--node-text node)))))
        (when (and frame-name pdu-name)
          (puthash frame-name
                   (cl-remove-duplicates
                    (cons pdu-name (gethash frame-name frame-pdus))
                    :test #'equal)
                   frame-pdus))))))

(defun autosar-can--collect-can-frame-triggering (node frame-pdus pdu-signals frames-by-id)
  "Collect CAN frame triggering from NODE into FRAMES-BY-ID."
  (let ((tag (autosar-can--tag-name node)))
    (when (string= tag "CAN-FRAME-TRIGGERING")
      (let* ((identifier (autosar-can--maybe-number (autosar-can--child-text node "IDENTIFIER")))
             (frame-name (or (autosar-can--ref-basename (autosar-can--first-ref-text node "FRAME"))
                             (autosar-can--child-text node "SHORT-NAME")))
             (direct-pdu (autosar-can--ref-basename (autosar-can--first-ref-text node "PDU")))
             (pdu-names (cl-remove-duplicates
                         (append (and direct-pdu (list direct-pdu))
                                 (gethash frame-name frame-pdus))
                         :test #'equal))
             (signals (cl-mapcan (lambda (pdu-name)
                                   (copy-sequence (gethash pdu-name pdu-signals)))
                                 pdu-names)))
        (when (and (integerp identifier) signals)
          (puthash identifier
                   (cons (list :id identifier
                               :frame-name frame-name
                               :pdu-names pdu-names
                               :signals (nreverse signals))
                         (gethash identifier frames-by-id))
                   frames-by-id))))))

(defun autosar-can--walk (node ancestors fn)
  "Walk XML NODE depth-first.
ANCESTORS is the current ancestor list passed to FN."
  (when (listp node)
    (funcall fn node ancestors)
    (let ((new-ancestors (cons node ancestors)))
      (dolist (child (xml-node-children node))
        (when (listp child)
          (autosar-can--walk child new-ancestors fn))))))

(defun autosar-can--ancestor-short-name (ancestors predicate)
  "Return nearest ancestor short name in ANCESTORS matching PREDICATE."
  (cl-loop for node in ancestors
           for tag = (autosar-can--tag-name node)
           when (and (funcall predicate tag)
                     (autosar-can--child-text node "SHORT-NAME"))
           return (autosar-can--child-text node "SHORT-NAME")))

(defun autosar-can--first-ref-text (node hint)
  "Return first descendant ref text from NODE whose tag contains HINT."
  (cl-loop for child in (xml-node-children node)
           when (listp child)
           for tag = (autosar-can--tag-name child)
           thereis (cond
                    ((and (string-match-p "REF\\'" tag)
                          (string-match-p (regexp-quote hint) tag))
                     (autosar-can--node-text child))
                    (t (autosar-can--first-ref-text child hint)))))

(defun autosar-can--child-text (node child-tag)
  "Return direct CHILD-TAG text from NODE."
  (when-let ((child (autosar-can--child node child-tag)))
    (autosar-can--node-text child)))

(defun autosar-can--child (node child-tag)
  "Return first direct CHILD-TAG child from NODE."
  (cl-find-if
   (lambda (child)
     (and (listp child)
          (string= (autosar-can--tag-name child) child-tag)))
   (xml-node-children node)))

(defun autosar-can--node-text (node)
  "Return flattened text content from NODE."
  (let ((parts '()))
    (cl-labels ((collect (n)
                  (dolist (child (xml-node-children n))
                    (cond
                     ((stringp child) (push child parts))
                     ((listp child) (collect child))))))
      (collect node))
    (string-trim (string-join (nreverse parts) ""))))

(defun autosar-can--tag-name (node)
  "Return NODE tag name without XML namespace decoration."
  (let ((name (xml-node-name node)))
    (cond
     ((symbolp name)
      (let ((raw (symbol-name name)))
        (if (string-match ":" raw)
            (car (last (split-string raw ":")))
          raw)))
     ((stringp name) name)
     (t (format "%s" name)))))

(defun autosar-can--ref-basename (text)
  "Return basename of AUTOSAR reference TEXT."
  (when (and text (not (string-empty-p text)))
    (car (last (split-string (string-trim text) "/" t)))))

(defun autosar-can--normalize-byte-order (value)
  "Normalize ARXML byte order VALUE."
  (let ((text (downcase (or value ""))))
    (cond
     ((or (string-match-p "most-significant-byte-last" text)
          (string-match-p "least-significant-byte-first" text)
          (string= text "intel"))
      "little")
     ((or (string-match-p "most-significant-byte-first" text)
          (string-match-p "big" text)
          (string= text "motorola"))
      "big")
     (t "little"))))

(defun autosar-can--maybe-number (value)
  "Parse VALUE into a number when possible."
  (when value
    (let ((trimmed (string-trim (format "%s" value))))
      (cond
       ((string-empty-p trimmed) nil)
       ((string-prefix-p "0x" (downcase trimmed))
        (string-to-number trimmed 16))
       ((string-match-p "\\`[0-9]+\\'" trimmed)
        (string-to-number trimmed 10))
       (t nil)))))

(defun autosar-can--hash-values (table)
  "Return TABLE values as a list."
  (let (values)
    (maphash (lambda (_ value) (push value values)) table)
    values))

(provide 'autosar-can-mode)

;;; autosar-can-mode.el ends here
