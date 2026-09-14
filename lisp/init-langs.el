;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

(setup emacs-lisp-mode
  (:hook (lambda () (flycheck-mode -1))))

(setup makefile-mode
  (:setopt (prepend* auto-mode-alist)
           '(("\\(?:\\`\\|/\\)Kbuild\\'" . makefile-mode)
             ("\\(?:\\`\\|/\\)Makefile\\.[^/]*\\'" . makefile-mode))))

(setup sql
  (:setopt sql-mysql-program "mariadb"))

(setup nix-mode
  (:when-loaded
    (require 'nix-format)))

(setup json-mode
  (:setopt (prepend auto-mode-alist)
           '("\\(?:\\`\\|/\\)Android\\.bp\\'" . json-mode)))

(setup haskell-ts-mode
  (:setopt haskell-ts-use-indent t)
  (:bind-into haskell-ts-mode
    (kbd (concat doom-localleader-alt-key " b")) #'haskell-interactive-bring
    (kbd (concat doom-localleader-alt-key " B")) #'haskell-process-cabal-build
    (kbd (concat doom-localleader-alt-key " c")) #'haskell-process-cabal
    (kbd (concat doom-localleader-alt-key " i")) #'haskell-process-do-info
    (kbd (concat doom-localleader-alt-key " r")) #'haskell-process-load-file
    (kbd (concat doom-localleader-alt-key " t")) #'haskell-process-do-type))

(provide 'init-langs)
;;; init-langs.el ends here
