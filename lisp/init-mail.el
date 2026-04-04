;;; ../../Sync/dotfiles/doom.d/lisp/init-mail.el -*- lexical-binding: t; -*-

(use-package! mu4e
  :defer t
  :commands (mu4e mu4e-compose-new)
  :load-path
  ("/opt/homebrew/opt/mu/share/emacs/site-lisp/mu/mu4e/"
   "/usr/share/emacs/site-lisp/mu4e"
   "/home/wd/.nix-profile/share/emacs/site-lisp/elpa/mu4e-1.12.13")
  :init
  (defvar +wd/mu4e-index-timer nil "Timer for auto-updating mu4e index.")
  :hook
  (mu4e-main-mode . (lambda ()
                      (unless +wd/mu4e-index-timer
                        (setq +wd/mu4e-index-timer
                              (run-at-time nil (* 5 60) #'mu4e-update-index)))))
  :config
  (setq mu4e-mu-binary (pcase (system-name)
                         ("macbook-m1-pro" "/opt/homebrew/bin/mu")
                         ("ubuntu2204" "/home/wd/.local/bin/mu")
                         ("nixos-nuc" "/home/wd/.nix-profile/bin/mu")
                         (_ "/usr/bin/mu"))
        sendmail-program (executable-find "msmtp")
        send-mail-function #'smtpmail-send-it
        message-sendmail-f-is-evil t
        message-sendmail-extra-arguments '("--read-envelope-from")
        message-send-mail-function #'message-send-mail-with-sendmail
        mu4e-get-mail-command "true"))

(provide 'init-mail)
