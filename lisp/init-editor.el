;;; init-editor.el --- Modal editing (meow), lispy, and clipboard -*- lexical-binding: t; -*-

(setup meow
  (:when-loaded
    ;; meow's suppress-keymap only blocks self-insert; RET/backspace are bound to
    ;; functional commands (newline/delete) and fall through to the major-mode in
    ;; normal state. Bind them explicitly so they don't edit. Only affects normal
    ;; state (motion state for dired/magit uses a separate keymap).
    (meow-normal-define-key '("RET" . meow-line))
    (meow-normal-define-key '("<return>" . meow-line))
    (meow-normal-define-key '("DEL" . ignore))
    (meow-normal-define-key '("<backspace>" . ignore))
    (meow-normal-define-key '("C-o" . better-jumper-jump-backward))
    (meow-normal-define-key '("%" . lispy-different))
    (meow-normal-define-key '("=" . indent-region))
    (:option
     blink-cursor-interval 0.618
     meow-cursor-type-normal 'box
     meow-cursor-type-motion 'box
     meow-cursor-type-beacon 'box
     meow-cursor-type-insert 'bar)
    ;; Box-drawing chars in the cheatsheet fall back to Sarasa Fixed SC; force
    ;; the whole buffer to use it so ASCII and box chars share the same metrics.
    (advice-add 'meow-cheatsheet :after
                (lambda (&rest _)
                  (when-let ((buf (get-buffer "*Meow Cheatsheet*")))
                    (with-current-buffer buf
                      (when (member "Sarasa Fixed SC" (font-family-list))
                        (buffer-face-set
                         `(:family "Sarasa Fixed SC")))
                      ;; The cheatsheet is a read-only text-mode buffer, so meow
                      ;; puts it in normal state where `q' is suppressed. Drop
                      ;; normal state here and let `q' close the popup.
                      (meow-normal-mode -1)
                      (local-set-key "q" #'quit-window)))))
    (:hooks
     meow-insert-exit-hook deactivate-input-method
     ;; lispy belongs only in insert mode.
     meow-normal-mode-hook (lambda () (when meow-normal-mode (lispy-mode -1)))
     meow-insert-enter-hook (lambda () (when (derived-mode-p 'emacs-lisp-mode 'lisp-mode 'scheme-mode 'clojure-mode) (lispy-mode 1))))))

;; terminal clipboard
(setup xclip
  (:when-loaded
    (unless (display-graphic-p)
      (when (or (executable-find "xclip")
                (executable-find "xsel")
                (and (executable-find "wl-copy")
                     (executable-find "wl-paste")))
        (xclip-mode 1)))))

(provide 'init-editor)
;;; init-editor.el ends here
