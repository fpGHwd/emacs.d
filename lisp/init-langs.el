;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

;; flycheck's emacs-lisp checker spawns a bare emacs process without Doom macros loaded,
;; producing false "free variable" warnings for config files. Just it out.
(setup emacs-lisp-mode
  (:hook (lambda () (flycheck-mode -1))))

(setup makefile-mode
  (:match-file "Kbuild"))

(setup eglot
  (:option eglot-max-file-watches 524288))

(setup sql
  (:option sql-mysql-program "mariadb"))

(setup nix-mode
  (:when-loaded
    (require 'nix-format)))

(setup nxml-mode
  (:also-load lib-arxml)
  (:hook (lambda ()
           (when (string-suffix-p ".arxml" (or buffer-file-name ""))
             (arxml-breadcrumb-mode 1)))))

(setup haskell-ts-mode
  (:when-loaded
    (map! :map haskell-ts-mode-map
          :localleader
          "b" #'haskell-interactive-bring
          "B" #'haskell-process-cabal-build
          "c" #'haskell-process-cabal
          "i" #'haskell-process-do-info
          "r" #'haskell-process-load-file
          "t" #'haskell-process-do-type)
    (add-to-list 'meow-mode-state-list '(haskell-interactive-mode . insert))))

(provide 'init-langs)
;;; init-langs.el ends here
