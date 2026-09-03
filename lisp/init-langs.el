;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

;; flycheck's emacs-lisp checker spawns a bare emacs process without Doom macros loaded,
;; producing false "free variable" warnings for config files. Just it out.
(setup emacs-lisp-mode
  (:hook (lambda () (flycheck-mode -1))))

(setup makefile-mode
  (:match-file "Kbuild"))

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

(setup makefile-mode
  (:match-file "Makefile.*"))

(setup haskell-ts-mode
  (:bind
   (kbd (concat doom-localleader-alt-key " b")) #'haskell-interactive-bring
   (kbd (concat doom-localleader-alt-key " B")) #'haskell-process-cabal-build
   (kbd (concat doom-localleader-alt-key " c")) #'haskell-process-cabal
   (kbd (concat doom-localleader-alt-key " i")) #'haskell-process-do-info
   (kbd (concat doom-localleader-alt-key " r")) #'haskell-process-load-file
   (kbd (concat doom-localleader-alt-key " t")) #'haskell-process-do-type))

(provide 'init-langs)
;;; init-langs.el ends here
