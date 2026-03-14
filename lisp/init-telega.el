;;; init-telega.el --- telega configuration -*- lexical-binding: t; -*-
;;; Copyright (C) 2024 Wang Ding

;; https://github.com/zevlg/telega.el
(setup telega
  (:only-if (or (string= (system-name) "nixos-nuc")
                (string= (system-name) "arch-nuc")))
  (:defer (telega t))
  (:when-loaded
    (:also-load lib-telega)
    (:option
     telega-cache-dir (file-truename "~/.config/telega/cache")
     telega-directory (file-truename "~/.config/telega/")
     telega-server-logfile (file-truename "~/.config/telega/telega-server.log")
     telega-temp-dir (file-truename "~/.config/telega/temp")
     telega-database-dir (file-truename "~/.config/telega/")
     telega-server-libs-prefix (getenv "LIBTDLIB_ROOT"))
    ;; (:hooks telega-chat-mode-hook (lambda () (company-mode -1)))

    (when (or (string= system-name "arch-nuc")
              (string= system-name "nixos-nuc"))
      (add-hook 'telega-chat-update-hook #'+wd/telega-chat-update-function))
    ;; telea font
    (when (member "Sarasa Mono SC" (font-family-list))
      (make-face 'telega-align-by-sarasa)
      (set-face-font 'telega-align-by-sarasa (font-spec :family "Sarasa Mono SC"))
      (add-hook! '(telega-chat-mode-hook telega-root-mode-hook)
        (buffer-face-set 'telega-align-by-sarasa)))))

(provide 'init-telega)
