;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

;; flycheck's emacs-lisp checker spawns a bare emacs process without Doom macros loaded,
;; producing false "free variable" warnings for config files. Just it out.
(add-hook! 'emacs-lisp-mode-hook (flycheck-mode -1))

(setup eglot
  (:option eglot-max-file-watches 524288))

(after! treesit
  (setf (alist-get 'go treesit-language-source-alist)
        '("https://github.com/tree-sitter/tree-sitter-go" "v0.23.4" nil nil nil nil))
  (setf (alist-get 'xml treesit-language-source-alist)
        '("https://github.com/tree-sitter/tree-sitter-xml" nil "grammars/xml/src" nil nil nil)))

(setup sql
  (:option sql-mysql-program "mariadb"))

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
          "t" #'haskell-process-do-type)))

(provide 'init-langs)
;;; init-langs.el ends here
