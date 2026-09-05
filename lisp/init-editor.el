;;; init-editor.el --- Editing, keymaps, and clipboard -*- lexical-binding: t; -*-

(defun surround-quotes (&optional arg)
  "Enclose following ARG sexps in quotes."
  (interactive "*P")
  (insert-pair arg ?\" ?\"))

(defun +wd/open-with-vscode ()
  "Open current file with vscode."
  (interactive)
  (let ((line (number-to-string (line-number-at-pos)))
        (column (number-to-string (current-column))))
    (apply 'call-process "code" nil nil nil (list (concat buffer-file-name ":" line ":" column) "--goto"))))

(setup meow
  (:hooks doom-after-reload-hook (lambda ()
            (setq meow-cursor-type-normal 'box
                  meow-cursor-type-motion 'box
                  meow-cursor-type-beacon 'box
                  meow-cursor-type-insert 'bar
                  blink-cursor-interval 0.618)))
  (:when-loaded
    (:setopt
     meow-use-clipboard t
     meow-cursor-type-normal 'box
     meow-cursor-type-motion 'box
     meow-cursor-type-beacon 'box
     meow-cursor-type-insert 'bar
     (prepend meow-mode-state-list) '(inferior-emacs-lisp-mode . insert))
    (:with-feature vterm
      (:setopt (prepend meow-mode-state-list) '(vterm-mode . insert)))
    (:with-feature gud
      (:setopt (prepend meow-mode-state-list) '(gud-mode . insert)))
    (:with-feature haskell-interactive-mode
      (:setopt (prepend meow-mode-state-list)
               '(haskell-interactive-mode . insert)))
    (:with-feature calibredb-search
      (:setopt (prepend meow-mode-state-list)
               '(calibredb-search-mode . motion)))
    (:with-feature telega-modes
      (when *is-home*
        (:setopt
         (prepend* meow-mode-state-list)
         '((telega-webpage-mode . motion)
           (telega-image-mode . motion)
           (telega-chat-mode . motion)
           (telega-root-mode . motion)))))
    (:with-feature prog-mode
      (:hooks prog-mode-hook
              (lambda ()
                (meow-normal-define-key '("%" . lispy-different)))))
    (:with-feature frame
      (:setopt blink-cursor-interval 0.618))
    (:with-feature pdf-annot
      (:hooks pdf-annot-edit-contents-minor-mode-hook
              (lambda () (meow-insert))))
    (meow-normal-define-key
     '("DEL" . ignore)
     '("C-o" . better-jumper-jump-backward)
     '("=" . indent-region)
     '("q" . quit-window))))

(provide 'init-editor)
;;; init-editor.el ends here
