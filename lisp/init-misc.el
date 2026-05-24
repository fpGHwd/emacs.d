;;; init-misc.el --- Compatibility entrypoint for misc modules -*- lexical-binding: t; -*-

(require 'init-ui-misc)
(require 'init-tools-misc)
(require 'init-core-runtime)

(if-let (file-org-capture "~/projects/2026/haskell-web/scripts/elisp/lib-org-capture.el")
  (load file-org-capture))

(provide 'init-misc)
;;; init-misc.el ends here
