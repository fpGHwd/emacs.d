;;; init-term.el --- Terminal emulator (vterm) configuration -*- lexical-binding: t; -*-

(setup vterm
  (:option
   ;; Prefer vendored libvterm to avoid depending on system curses/ncurses headers.
   vterm-module-cmake-args "-DUSE_SYSTEM_LIBVTERM=Off"
   vterm-shell (or (executable-find "zsh") (executable-find "bash"))
   vterm-tramp-shells '(("sshx" login-shell "/bin/zsh" "/bin/bash")
                        ("ssh" login-shell "/bin/zsh" "/bin/bash")
                        ("scp" login-shell "/bin/zsh" "/bin/bash")
                        ("docker" "/bin/bash" "/bin/sh")))
  (:hook meow-insert))

(provide 'init-term)
;;; init-term.el ends here
