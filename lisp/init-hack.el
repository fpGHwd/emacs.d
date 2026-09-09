;;; init-hack.el --- Binary analysis tools -*- lexical-binding: t; -*-

(setup elf-mode
  (:with-function elf-mode
    (:autoload-this "elf-mode"))
  (:match-file "\\.\\(so\\|o\\|elf\\|bin\\)$"))

(setup demangle-mode
  (:with-function demangle-mode
    (:autoload-this "demangle-mode"))
  ;; Auto-enable in compilation buffers and shell output with symbols
  (:hooks compilation-mode-hook demangle-mode))

(setup disaster
  (:with-function disaster
    (:autoload-this "disaster")))

(provide 'init-hack)
;;; init-hack.el ends here
