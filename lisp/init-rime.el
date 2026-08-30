;;; init-rime.el --- Input method (Rime) -*- lexical-binding: t; -*-

(defvar-local +wd/rime--was-active-p nil)

(setup rime
  (:bind "M-\\" rime-force-enable)
  (:option
   default-input-method "rime"
   rime-posframe-properties (list :background-color "#666699"
                                  :foreground-color "#dcdccc"
                                  :font (format "Sarasa Gothic SC-%d" (1+ (font-get doom-font :size))))
   rime-show-candidate 'posframe
   rime-disable-predicates '(rime-predicate-auto-english-p
                             rime-predicate-current-uppercase-letter-p
                             +pyim-probe-telega-msg)
   rime-inline-ascii-trigger 'shift-l
   rime-emacs-module-header-root (concat (getenv "LIBEMACS_ROOT") "/include")
   rime-librime-root (getenv "LIBRIME_ROOT")
   module-file-suffix (getenv "MODULE_FILE_SUFFIX")
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
                                                            'category))))

    (defun +my/rime-compile-module-advice (orig-fun &rest _)
      "Around advice: call ORIG-FUN, on error fall back to `make lib' via nix-shell."
      (condition-case nil
          (funcall orig-fun)
        (user-error
         (let ((default-directory (file-name-as-directory rime--root)))
           (unless (zerop (shell-command "nix-shell -p gcc gnumake --run \"make clean && make lib\""))
             (user-error "Rime fallback compile failed"))))))

    (:advice rime-compile-module :around #'+my/rime-compile-module-advice)))

(provide 'init-rime)
;;; init-rime.el ends here
