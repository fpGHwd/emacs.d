;;; init-rime.el --- Input method (Rime) -*- lexical-binding: t; -*-

(defvar-local +wd/rime--was-active-p nil)

(setup rime
  (:bind "M-\\" rime-force-enable)
  (:setopt
   default-input-method "rime"
   rime-posframe-properties (list :background-color "#666699"
                                  :foreground-color "#dcdccc"
                                  :font (format "Sarasa Gothic SC-%d" (1+ (font-get doom-font :size))))
   rime-show-candidate 'posframe
   rime-disable-predicates '(rime-predicate-auto-english-p
                             rime-predicate-current-uppercase-letter-p
                             +pyim-probe-telega-msg)
   rime-inline-ascii-trigger 'shift-l
   rime-emacs-module-header-root (expand-file-name "../../../../include" data-directory)
   rime-librime-root (file-truename "~/.nix-profile/")
   rime-user-data-dir (file-truename "~/.config/rime"))
  (:when-loaded
    (:hooks
     meow-insert-exit-hook
     (lambda ()
       (setq +wd/rime--was-active-p (equal current-input-method "rime"))
       (deactivate-input-method))
     meow-insert-enter-hook
     (lambda ()
       (when +wd/rime--was-active-p
         (activate-input-method "rime"))))
    
    (defun +pyim-probe-telega-msg ()
      "Return if current point is at a telega button."
      (s-contains? "telega" (symbol-name (get-text-property (point)
                                                            'category))))))

(provide 'init-rime)
;;; init-rime.el ends here
