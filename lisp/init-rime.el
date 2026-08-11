;;; init-rime.el --- Input method (Rime) -*- lexical-binding: t; -*-

(setq default-input-method "rime")

(defvar-local +wd/rime-was-active nil
  "Whether rime was active before leaving insert state.")

(defun +wd/rime-toggle-on-insert-change ()
  "Toggle rime on meow insert state change.
On insert exit: save state and deactivate.
On insert enter: restore if previously active."
  (if (meow-insert-mode-p)
      (when +wd/rime-was-active
        (activate-input-method "rime"))
    (setq +wd/rime-was-active (and (boundp 'current-input-method) current-input-method))
    (deactivate-input-method)))

(defun +my/rime-compile-module-advice (orig-fun &rest _)
  "Around advice: call ORIG-FUN, on error fall back to `make lib' via nix-shell."
  (condition-case nil
      (funcall orig-fun)
    (error
     (let ((default-directory (file-name-as-directory rime--root)))
       (unless (zerop (shell-command "nix-shell -p gcc gnumake --run \"make clean && make lib\""))
         (error "Rime fallback compile failed"))))))

(defun +pyim-probe-telega-msg ()
  "Return if current point is at a telega button."
  (s-contains? "telega" (symbol-name (get-text-property (point)
                                                        'category))))

(setup rime
  (:bind "M-\\" rime-force-enable)
  (:option
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
    ;; Input method follows editing state: save rime state on exit, restore on enter
    (add-hook 'meow-insert-exit-hook #'+wd/rime-toggle-on-insert-change)
    (add-hook 'meow-insert-enter-hook #'+wd/rime-toggle-on-insert-change)
    (advice-add 'rime-compile-module :around #'+my/rime-compile-module-advice)))

(provide 'init-rime)
;;; init-rime.el ends here
