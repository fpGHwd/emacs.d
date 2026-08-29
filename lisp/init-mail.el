;;; init-mail.el --- Email (mu4e) -*- lexical-binding: t; -*-

(defvar +wd/mu4e-index-timer nil "Timer for auto-updating mu4e index.")

(setup mu4e
  (:option (prepend load-path)
           (expand-file-name
            "~/.nix-profile/share/emacs/site-lisp/elpa/mu4e-1.12.13"))
  (:with-function (mu4e mu4e-compose-new)
    (:autoload-this "mu4e" nil t))
  (:hooks mu4e-main-mode-hook
          (lambda ()
            (unless +wd/mu4e-index-timer
              (setq +wd/mu4e-index-timer
                    (run-at-time nil (* 5 60) #'mu4e-update-index)))))
  (:when-loaded
    (:option
     mu4e-mu-binary (executable-find "mu")
     mu4e-get-mail-command "true")
    (:with-feature sendmail
      (:option
       sendmail-program (executable-find "msmtp")
       send-mail-function #'smtpmail-send-it))
    (:with-feature message
      (:option
       message-sendmail-f-is-evil t
       message-sendmail-extra-arguments '("--read-envelope-from")
       message-send-mail-function #'message-send-mail-with-sendmail))))

(provide 'init-mail)
;;; init-mail.el ends here
