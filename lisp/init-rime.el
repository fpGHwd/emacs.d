;;; init-rime.el --- Input method (Rime) -*- lexical-binding: t; -*-


(setup rime
  (defvar-local +wd/rime--was-active-p nil)

  (defun +pyim-probe-telega-msg ()
    "Return if current point is at a telega button."
    (s-contains? "telega" (symbol-name (get-text-property (point)
                                                          'category))))

  (defun +wd/rime-toggle-input-method (arg)
    "Toggle the input method in minibuffers or Meow insert mode."
    (interactive "P")
    (if (or (minibufferp)
            (meow-insert-mode-p)
            (and current-input-method (not arg)))
        (toggle-input-method arg t)
      (user-error "Input methods can only be enabled in minibuffers or Meow insert mode")))

  (:with-feature emacs
    (:with-map global-map
      (:bind "C-\\" +wd/rime-toggle-input-method)))
  (:bind "M-\\" rime-force-enable)
  (:option default-input-method "rime")

  (:when-loaded
    (:setopt
     rime-posframe-properties (list :background-color "#666699"
                                    :foreground-color "#dcdccc"
                                    :font (format "Sarasa Gothic SC-%d" (1+ (font-get doom-font :size))))
     rime-show-candidate 'posframe
     rime-disable-predicates '(rime-predicate-auto-english-p
                               rime-predicate-current-uppercase-letter-p
                               +pyim-probe-telega-msg)
     rime-emacs-module-header-root (expand-file-name "../../../../include" data-directory)
     rime-librime-root (file-truename "~/.nix-profile/")
     rime-user-data-dir (file-truename "~/.config/rime"))
    (:hooks
     meow-insert-exit-hook
     (lambda ()
       (setq +wd/rime--was-active-p (equal current-input-method "rime"))
       (deactivate-input-method))
     meow-insert-enter-hook
     (lambda ()
       (when +wd/rime--was-active-p
         (activate-input-method "rime"))))))

(provide 'init-rime)
;;; init-rime.el ends here
