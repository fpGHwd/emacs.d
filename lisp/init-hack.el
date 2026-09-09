;;; init-hack.el --- Binary analysis tools -*- lexical-binding: t; -*-

(setup elf-mode
  ;; Match ELF files by magic number, not just by extension
  ;; Note: \x7f does NOT work in Elisp strings; use octal \177 instead
  (add-to-list 'magic-mode-alist '("\177ELF" . elf-mode))
  (:when-loaded
    (:setopt elf-mode-command "readelf -a -W %s")))

(setup demangle-mode
  ;; Auto-enable in compilation buffers and shell output with symbols
  (:hooks compilation-mode-hook demangle-mode))

(provide 'init-hack)
;;; init-hack.el ends here
