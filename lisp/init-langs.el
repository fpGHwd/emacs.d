;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

(use-package! pine-script-mode)

(after! lsp-haskell
  (setq lsp-haskell-formatting-provider "brittany"))

(provide 'init-langs)
;;; init-langs.el ends here
