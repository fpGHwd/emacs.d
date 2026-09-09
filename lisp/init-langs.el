;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

(defvar haskell-ts-mode-map)

;; flycheck's emacs-lisp checker spawns a bare emacs process without Doom macros loaded,
;; producing false "free variable" warnings for config files. Disable it.
(setup emacs-lisp-mode
  (:hook (lambda () (flycheck-mode -1))))

(setup makefile-mode
  (:match-file "Kbuild")
  (:match-file "Makefile.*"))

(setup eglot
  (:setopt eglot-max-file-watches 524288))

(setup sql
  (:setopt sql-mysql-program "mariadb"))

(setup nix-mode
  (:when-loaded
    (require 'nix-format)))

;; (setup nxml-mode
;;   (:also-load lib-arxml)
;;   (:hook (lambda ()
;;            (when (string-suffix-p ".arxml" (or buffer-file-name ""))
;;              (arxml-breadcrumb-mode 1)))))

(setup json-mode
  (:match-file "Android.bp"))

(setup haskell-ts-mode
  (:setopt haskell-ts-use-indent t)
  ;; (:hooks haskell-ts-mode-hook
  ;;         (lambda ()
  ;;           (eglot-ensure)
  ;;           (add-hook 'before-save-hook #'eglot-format-buffer nil t)))
  (:bind-into haskell-ts-mode
    (kbd (concat doom-localleader-alt-key " b")) #'haskell-interactive-bring
    (kbd (concat doom-localleader-alt-key " B")) #'haskell-process-cabal-build
    (kbd (concat doom-localleader-alt-key " c")) #'haskell-process-cabal
    (kbd (concat doom-localleader-alt-key " i")) #'haskell-process-do-info
    (kbd (concat doom-localleader-alt-key " r")) #'haskell-process-load-file
    (kbd (concat doom-localleader-alt-key " t")) #'haskell-process-do-type))

(provide 'init-langs)
;;; init-langs.el ends here
