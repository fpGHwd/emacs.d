;;; init-editor.el --- Modal editing (meow), lispy, and clipboard -*- lexical-binding: t; -*-

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

(defun +wd/meow-normal-return ()
  (interactive)
  (cond
   ((derived-mode-p 'org-mode) (call-interactively #'+org/dwim-at-point))
   (t (ignore))))

(when (eq system-type 'gnu/linux)
  (setup (:require xclip)
    (:setopt xclip-method 'wl-copy
             xclip-program "wl-copy")
    (:when-loaded
      (:setopt
       interprogram-cut-function
       (apply-partially #'xclip-set-selection 'CLIPBOARD)
       interprogram-paste-function
       (apply-partially #'xclip-get-selection 'CLIPBOARD)))))

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
    (:with-feature frame
      (:setopt blink-cursor-interval 0.618))
    (meow-normal-define-key
     '("RET" . +wd/meow-normal-return)
     '("DEL" . ignore)
     '("C-o" . better-jumper-jump-backward)
     '("=" . indent-region)
     '("q" . quit-window))
    (:hooks prog-mode-hook
            (lambda ()
              (meow-normal-define-key '("%" . lispy-different))))
    (:advice meow-cheatsheet :after
             (lambda (&rest _)
               (when-let ((buf (get-buffer "*Meow Cheatsheet*")))
                 (with-current-buffer buf
                   (buffer-face-set :family "Sarasa Fixed SC")))))))

(provide 'init-editor)
;;; init-editor.el ends here
