;;; init-mail.el --- Email (mu4e) -*- lexical-binding: t; -*-

;; mu4e ships with the Nix-installed `mu`; setup has no :load-path, so register
;; it and the autoloads explicitly (the use-package! :load-path/:commands equivalent).
(add-to-list 'load-path
             (expand-file-name "~/.nix-profile/share/emacs/site-lisp/elpa/mu4e-1.12.13"))
(autoload 'mu4e "mu4e" nil t)
(autoload 'mu4e-compose-new "mu4e" nil t)

(defvar +wd/mu4e-index-timer nil "Timer for auto-updating mu4e index.")

(setup mu4e
  (:hooks mu4e-main-mode-hook
          (lambda ()
            (unless +wd/mu4e-index-timer
              (setq +wd/mu4e-index-timer
                    (run-at-time nil (* 5 60) #'mu4e-update-index)))))
  (:when-loaded
    (setq mu4e-mu-binary (executable-find "mu")
          sendmail-program (executable-find "msmtp")
          send-mail-function #'smtpmail-send-it
          message-sendmail-f-is-evil t
          message-sendmail-extra-arguments '("--read-envelope-from")
          message-send-mail-function #'message-send-mail-with-sendmail
          mu4e-get-mail-command "true")))

(provide 'init-mail)
;;; init-mail.el ends here
