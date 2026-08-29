;;; init-term.el --- Terminal emulator (vterm) configuration -*- lexical-binding: t; -*-

(setup vterm
  (:option
   vterm-tramp-shells '(("sshx" login-shell "/bin/zsh" "/bin/bash")
                        ("ssh" login-shell "/bin/zsh" "/bin/bash")
                        ("scp" login-shell "/bin/zsh" "/bin/bash")
                        ("docker" "/bin/bash" "/bin/sh")))
  (:after meow
    (:option (prepend meow-mode-state-list) '(vterm-mode . insert))))

(provide 'init-term)
;;; init-term.el ends here
