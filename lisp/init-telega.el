;;; init-telega.el --- telega configuration -*- lexical-binding: t; -*-
;;; Copyright (C) 2024 Wang Ding

(defvar +wd/ledger-file-name "~/org/ledger/current.ledger")
(defvar ledger-mutex (make-mutex "open ledger file"))
(defvar +wd/telegram-cmb-chat-id nil)

(defun +wd/telega-normalize-transaction-value (chat-text amount)
  "Return AMOUNT adjusted for special transaction text in CHAT-TEXT."
  (if (and (stringp chat-text)
           (string-match-p "退货" chat-text))
      (abs amount)
    amount))

(defun +wd/telega-parse-transaction-time (chat-text chat-date)
  "Parse transaction time from CHAT-TEXT, falling back to CHAT-DATE's year."
  (let ((current-year (format-time-string "%Y" chat-date))
        (weekday-names ["Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat"])
        (parsed nil))
    (when (and (stringp chat-text)
               (or (string-match
                    "\\([0-9]\\{2\\}\\)月\\([0-9]\\{2\\}\\)日\\s-*\\([0-9]\\{2\\}\\):\\([0-9]\\{2\\}\\)\\(?::\\([0-9]\\{2\\}\\)\\)?"
                    chat-text)
                   (string-match
                    "交易时间：? ?\\([0-9]\\{2\\}\\)月\\([0-9]\\{2\\}\\)日\\s-*\\([0-9]\\{2\\}\\):\\([0-9]\\{2\\}\\)\\(?::\\([0-9]\\{2\\}\\)\\)?"
                    chat-text)))
      (let* ((month (string-to-number (match-string 1 chat-text)))
             (day (string-to-number (match-string 2 chat-text)))
             (hour (string-to-number (match-string 3 chat-text)))
             (minute (string-to-number (match-string 4 chat-text)))
             (second (string-to-number (or (match-string 5 chat-text) "00")))
             (year (string-to-number current-year))
             (time (encode-time second minute hour day month year))
             (weekday (aref weekday-names (nth 6 (decode-time time)))))
        (setq parsed
              (format "%04d/%02d/%02d %s %02d:%02d:%02d"
                      year month day weekday hour minute second))))
    parsed))

(defun +wd/telega-match-group (regexp text &optional group)
  "Return REGEXP GROUP from TEXT, or nil when REGEXP does not match."
  (when (and (stringp text)
             (string-match regexp text))
    (match-string (or group 1) text)))

(defun +wd/telega-transaction-dedup-keys (transaction-text)
  "Return structured dedup keys for TRANSACTION-TEXT."
  (let* ((lines (split-string transaction-text "\n" t))
         (headline (car lines))
         (alt-headline (and headline
                            (replace-regexp-in-string
                             "\\([0-9]\\{4\\}/[0-9]\\{2\\}/[0-9]\\{2\\}\\)[[:space:]]+"
                             "\\1 * "
                             headline)))
         (alt-headline-pending (and headline
                                    (replace-regexp-in-string
                                     "\\([0-9]\\{4\\}/[0-9]\\{2\\}/[0-9]\\{2\\}\\)[[:space:]]+"
                                     "\\1 ! "
                                     headline))))
    (delq nil (list headline alt-headline alt-headline-pending))))

(defun +wd/write-transactions (transaction-text)
  "Append TRANSACTION-TEXT to the ledger file unless already present."
  (with-mutex ledger-mutex
    (when (string= (system-name) "nixos-nuc")
      (with-temp-buffer
        (insert-file-contents +wd/ledger-file-name)
        (goto-char (point-max))
        (let ((buffer-string (buffer-substring (point-min) (point-max)))
              (dedup-keys (+wd/telega-transaction-dedup-keys transaction-text)))
          (when (and dedup-keys
                     (not (seq-some
                           (lambda (key)
                             (string-match-p (regexp-quote key) buffer-string))
                           dedup-keys)))
            (insert transaction-text)
            (write-region (point-min) (point-max) +wd/ledger-file-name)))))))

(defun +wd/creditcard-transaction (chat-text chat-date)
  "Return a ledger transaction parsed from Telega CHAT-TEXT and CHAT-DATE."
  (let* ((card-number-regexp "尾号\\(5048\\|6798\\|2972\\|6912\\)\\w*")
         (transaction-pattern-regexp "交易类型：:? ?\\(.*\\)")
         (trader-name-regexp "交易商户：:? ?\\(.*\\)")
         (value-regexp "交易金额：:? ?\\(人民币活期\\)?\\([-+]?[-0-9,.]*\\)\\(人民币\\)?")
         (card-number (+wd/telega-match-group card-number-regexp chat-text 1))
         (transaction-date-time (+wd/telega-parse-transaction-time chat-text chat-date))
         (transaction-pattern (+wd/telega-match-group transaction-pattern-regexp chat-text 1))
         (trader-name (+wd/telega-match-group trader-name-regexp chat-text 1))
         (value (+wd/telega-match-group value-regexp chat-text 2))
         (stripped-value (and value
                              (replace-regexp-in-string (regexp-quote (string ?,)) "" value)))
         (pufa-p (string= card-number "6912"))
         (raw-value (and stripped-value
                         (if pufa-p
                             (string-to-number stripped-value)
                           (* -1 (string-to-number stripped-value)))))
         (real-value (+wd/telega-normalize-transaction-value chat-text raw-value))
         (ledger-account (cond ((or (string= card-number "5048")
                                    (string= card-number "6798")
                                    (string= card-number "2972"))
                                "Liabilities:CreditCard:CMB-5048")
                               ((string= card-number "6912")
                                "Assets:Liquid:Bank:SPDB-6912")))
         (description (if pufa-p transaction-pattern trader-name)))
    (when (and card-number stripped-value ledger-account description)
      (concat "\n"
              (if transaction-date-time
                  (concat transaction-date-time "[" (format-time-string "%H:%M:%S" chat-date) "]")
                (format-time-string "%Y/%m/%d %a %H:%M:%S" chat-date))
              " "
              description
              "\n"
              "    " ledger-account "  " (number-to-string real-value) " CNY\n"
              "    Expenses:\n"))))

(defun +wd/telega-chat-update-function (chat)
  "Write matching bank notification messages from CHAT to ledger."
  (let ((+wd/cmb-chat-id (string-to-number +wd/telegram-cmb-chat-id)))
    (when (= +wd/cmb-chat-id (plist-get chat :id))
      (let* ((msg (plist-get chat :last_message))
             (chat-text (plist-get (plist-get (plist-get msg :content) :text) :text))
             (chat-date (plist-get msg :date))
             (account-need-p (string-match "交易金额" chat-text)))
        (when account-need-p
          (let ((transaction-text (+wd/creditcard-transaction chat-text chat-date)))
            (when transaction-text
              (+wd/write-transactions transaction-text))))))))

;; https://github.com/zevlg/telega.el
(setup telega
  (:when-loaded
    (when *is-home*
      (:defer (telega t))
      (:setopt
       telega-cache-dir (file-truename "~/.config/telega/cache")
       telega-directory (file-truename "~/.config/telega/")
       telega-server-logfile (file-truename "~/.config/telega/telega-server.log")
       telega-temp-dir (file-truename "~/.config/telega/temp")
       telega-database-dir (file-truename "~/.config/telega/")
       telega-server-libs-prefix (file-truename "~/.nix-profile/"))
      (setq +wd/telegram-cmb-chat-id
               (password-store-get "telegram/TELEGRAM_CMB_CHAT_ID"))
      (:hooks telega-chat-update-hook +wd/telega-chat-update-function
              telega-chat-mode-hook (lambda () (company-mode -1)))
      ;; telea font
      (when (member "Sarasa Mono SC" (font-family-list))
        (make-face 'telega-align-by-sarasa)
        (set-face-font 'telega-align-by-sarasa (font-spec :family "Sarasa Mono SC"))
        (:hooks
         telega-chat-mode-hook (lambda () (buffer-face-set 'telega-align-by-sarasa))
         telega-root-mode-hook (lambda () (buffer-face-set 'telega-align-by-sarasa)))))))

(provide 'init-telega)
;;; init-telega.el ends here
