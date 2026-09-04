;;; init-mail.el --- Email (mu4e) -*- lexical-binding: t; -*-

(setup mu4e
  (defvar +wd/mu4e-index-timer nil "Timer for auto-updating mu4e index.")
  (:with-function (mu4e mu4e-compose-new)
    (:autoload-this "mu4e" nil t))
  (:hooks mu4e-main-mode-hook
          (lambda ()
            (unless +wd/mu4e-index-timer
              (setq +wd/mu4e-index-timer
                    (run-at-time nil (* 5 60) #'mu4e-update-index)))))
  (:when-loaded
    (:setopt
     mu4e-mu-binary (executable-find "mu")
     mu4e-get-mail-command "true"))
  (:with-feature smtpmail
    (:setopt
     smtpmail-smtp-server "smtp.gmail.com"
     smtpmail-smtp-service 587
     smtpmail-stream-type 'starttls
     smtpmail-smtp-user user-mail-address
     send-mail-function #'smtpmail-send-it))
  (:with-feature message
    (:setopt
     message-send-mail-function #'smtpmail-send-it)))

(provide 'init-mail)
;;; init-mail.el ends here
