;;; init-term.el --- Terminal emulator (vterm) configuration -*- lexical-binding: t; -*-

(use-package! vterm
  :defer t
  :custom
  ;; Prefer vendored libvterm to avoid depending on system curses/ncurses headers.
  (vterm-module-cmake-args "-DUSE_SYSTEM_LIBVTERM=Off")
  (vterm-shell (let ((zsh-path (executable-find "zsh")))
                 (if zsh-path
                     zsh-path
                   (executable-find "bash"))))
  (vterm-tramp-shells '(("sshx" login-shell "/bin/zsh" "/bin/bash")
                        ("ssh" login-shell "/bin/zsh" "/bin/bash")
                        ("scp" login-shell "/bin/zsh" "/bin/bash")
                        ("docker" "/bin/zsh" "/bin/bash" "/bin/sh"))))

(add-hook 'vterm-mode-hook #'meow-insert)

(provide 'init-term)
;;; init-term.el ends here
