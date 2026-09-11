;;; init-mail.el --- Email (mu4e) -*- lexical-binding: t; -*-

(setup mu4e
  (:when-loaded
    (:setopt
     mu4e-get-mail-command "true"
     mu4e-update-interval (* 5 60)))
  (:with-feature smtpmail
    (:setopt
     smtpmail-smtp-server "smtp.gmail.com"
     smtpmail-smtp-service 587
     smtpmail-smtp-user user-mail-address
     send-mail-function #'smtpmail-send-it)))

(provide 'init-mail)
;;; init-mail.el ends here
