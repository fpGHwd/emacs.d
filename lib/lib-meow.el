;;; lib-meow.el --- Meow CJK selection helpers -*- lexical-binding: t -*-
;;; Commentary:
;;; This library only keeps CJK-related selection/navigation overrides for Meow.
;;; Code:

(defun meow-mark-thing-cjk (thing type &optional backward regexp-format)
  "Make expandable selection of THING with CJK-aware behavior.

THING is a symbol usable by `forward-thing'. TYPE is usually `word' or `line'.
Selection is made in forward direction unless BACKWARD is non-nil.
When REGEXP-FORMAT is a string, push a formatted regexp to search ring."
  (interactive "p")
  (emt-ensure)
  (let ((direction (if backward 'backward 'forward)))
    (if (or (eq type 'symbol) (not (looking-at-p "\\cc")))
        (meow--select-noncjk thing type backward regexp-format)
      (meow--select-cjk direction backward))))

(defun meow--select-noncjk (thing type backward regexp-format)
  "Select non-CJK text based on THING, TYPE and BACKWARD."
  (let* ((bounds (bounds-of-thing-at-point thing))
         (beg (car bounds))
         (end (cdr bounds)))
    (when beg
      (thread-first
        (meow--make-selection (cons 'expand type) beg end)
        (meow--select t backward))
      (when (stringp regexp-format)
        (let ((search (format regexp-format
                              (regexp-quote (buffer-substring-no-properties beg end)))))
          (meow--push-search search)
          (meow--highlight-regexp-in-buffer search))))))

(defun meow--select-cjk (direction backward)
  "Select CJK text based on DIRECTION and BACKWARD."
  (let* ((bounds (emt--get-bounds-at-point
                  (emt--move-by-word-decide-bounds-direction direction)))
         (beg (car bounds))
         (end (cdr bounds))
         (text (buffer-substring-no-properties beg end))
         (segments (append (emt-split text) nil))
         (pos (- (point) beg))
         (segment-bounds (car segments)))
    (dolist (bound segments)
      (when (and (>= pos (car bound)) (< pos (cdr bound)))
        (setq segment-bounds bound)))
    (when segment-bounds
      (let* ((seg-beg (+ beg (car segment-bounds)))
             (seg-end (+ beg (cdr segment-bounds)))
             (segment-text (buffer-substring-no-properties seg-beg seg-end))
             (regexp (regexp-quote segment-text)))
        (let ((selection (meow--make-selection (cons 'expand 'word) seg-beg seg-end)))
          (meow--select selection t backward)
          (meow--push-search regexp)
          (meow--highlight-regexp-in-buffer regexp))))))

(defun meow-next-thing-cjk (thing type n &optional include-syntax)
  "Create non-expandable selection of TYPE to next Nth THING with CJK support.

If N is negative, select to the beginning of previous Nth thing instead."
  (unless (equal type (cdr (meow--selection-type)))
    (meow--cancel-selection))
  (unless include-syntax
    (setq include-syntax
          (let ((thing-include-syntax
                 (or (alist-get thing meow-next-thing-include-syntax)
                     '("" ""))))
            (if (> n 0)
                (car thing-include-syntax)
              (cadr thing-include-syntax)))))
  (let* ((expand (equal (cons 'expand type) (meow--selection-type)))
         (_ (when expand
              (if (< n 0)
                  (meow--direction-backward)
                (meow--direction-forward))))
         (new-type (if expand (cons 'expand type) (cons 'select type)))
         (m (point))
         (p (save-mark-and-excursion
              (if (and (eq thing 'word) (eq system-type 'darwin))
                  (progn
                    (emt-ensure)
                    (if (> n 0)
                        (emt-forward-word n)
                      (emt-backward-word (- n))))
                (forward-thing thing n))
              (unless (= (point) m)
                (point)))))
    (when p
      (thread-first
        (meow--make-selection
         new-type
         (meow--fix-thing-selection-mark thing p m include-syntax)
         p
         expand)
        (meow--select t))
      (meow--maybe-highlight-num-positions
       (cons (apply-partially #'meow--backward-thing-1-cjk thing)
             (apply-partially #'meow--forward-thing-1-cjk thing))))))

(defun meow--forward-thing-1-cjk (thing)
  "Move forward one THING for CJK-aware highlighting."
  (let ((pos (point)))
    (if (eq thing 'word)
        (emt-forward-word 1)
      (forward-thing thing 1))
    (when (/= pos (point))
      (meow--hack-cursor-pos (point)))))

(defun meow--backward-thing-1-cjk (thing)
  "Move backward one THING for CJK-aware highlighting."
  (let ((pos (point)))
    (if (eq thing 'word)
        (emt-backward-word 1)
      (forward-thing thing -1))
    (when (/= pos (point))
      (point))))

(provide 'lib-meow)
;;; lib-meow.el ends here
