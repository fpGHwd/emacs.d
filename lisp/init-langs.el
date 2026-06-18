;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

(setup eglot
  (:option eglot-max-file-watches 524288))

(setup pine-script-mode
  (:require pine-script-mode))

(provide 'init-langs)
;;; init-langs.el ends here
