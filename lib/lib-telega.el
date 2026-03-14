;;; ../../Sync/dotfiles/doom.d/lib/lib-telega.el -*- lexical-binding: t; -*-

(defun get-value-by-key-sequence (plist keys)
  "根据键序列获取嵌套的 plist 中的值"
  (let ((value plist))
    (dolist (key keys value)
      (setq value (plist-get value key)))
    value))

;; update telega hook to accounting
(defvar +wd/ledger-file-name "~/org/ledger/current.ledger")
(defvar +wd/ledger-file-name "~/org/ledger/accounts")
(defvar ledger-mutex (make-mutex "open ledger file"))

(defun +wd/write-transactions (transaction-text file-name chat-date)
  ;; (message "write transactions 1")
  (with-mutex ledger-mutex
    ;; (message "write transactions 2")
    (when (or  (string= (system-name) "nixos-nuc")
               (string= (system-name) "arch-nuc")) ;; only record on arch-nuc & nixos-nuc
      (with-temp-buffer
        (insert-file-contents +wd/ledger-file-name)
        (goto-char (point-max))
        (let*
            ((buffer-string (buffer-substring (point-min) (point-max)))
             (time-string-local (format-time-string "%a %H:%M:%S" chat-date))
             (match-string1 (concat (format-time-string "%Y/%m/%d \\* %a %H:%M:%S" chat-date)))
             (match-string2 (concat (format-time-string "%Y/%m/%d %a %H:%M:%S" chat-date))))
          ;; (message "match-string1: %s; match-string2: %s" match-string1 match-string2)
          (when (not (or (string-match match-string1 buffer-string)
                         (string-match match-string2 buffer-string)))
            (progn
              (insert transaction-text)
              (write-region (point-min) (point-max) +wd/ledger-file-name))))))))

(defun +wd/creditcard-transaction (chat-text chat-date)
  (let* ((card-number-regexp "尾号\\(5048\\|6798\\|2972\\|6912\\)\\w*")
         (transaction-date-time-regexp "交易时间：:? ?\\(.*\\)")
         (transaction-pattern-regexp "交易类型：:? ?\\(.*\\)")
         (trader-name-regexp "交易商户：:? ?\\(.*\\)")
         (value-regexp "交易金额：:? ?\\(人民币活期\\)?\\([-+]?[-0-9,.]*\\)\\(人民币\\)?")
         (card-number (progn (string-match card-number-regexp chat-text)
                             (match-string 1 chat-text)))
         (current-year (format-time-string "%Y" chat-date))
         (transaction-date-time nil
                                ;; (replace-regexp-in-string
                                ;;  "交易时间：:? ?\\([0-9]+\\)月\\([0-9]+\\)日 \\([0-9]+\\):\\([0-9]+\\):?\\([0-9]+\\)?"
                                ;;  (format "%s-\\1-\\2 \\3:\\4" current-year) chat-text)
                                ) 
         ;; (parsed-time-string (parse-time-string transaction-date-time))
         (transaction-pattern (progn (string-match transaction-pattern-regexp chat-text)
                                     (match-string 1 chat-text)))
         (trader-name (progn (string-match trader-name-regexp chat-text)
                             (match-string 1 chat-text)))
         (value (progn (string-match value-regexp chat-text)
                       (match-string 2 chat-text)))
         (stripped-value (replace-regexp-in-string (regexp-quote (string ?,)) "" value))
         (pufa-p (string= card-number "6912"))
         (real-value (if pufa-p (string-to-number stripped-value)
                       (* -1 (string-to-number stripped-value))))
         (ledger-account (progn
                           (cond ((or (string= card-number "5048")
                                      (string= card-number "6798")
                                      (string= card-number "2972"))
                                  (concat "Liabilities:credit card:cmb-5048:" card-number))
                                 ((string= card-number "6912")
                                  "Assets:current:deposit:spdb-6912"))))
         (transaction-string (concat "\n"
                                     (if transaction-date-time
                                         transaction-date-time
                                       (format-time-string "%Y/%m/%d * %a %H:%M:%S" chat-date))
                                     " "
                                     (if (string= card-number "6912")
                                         transaction-pattern
                                       trader-name)
                                     "\n"
                                     "    " ledger-account "  " (number-to-string real-value) " CNY  ;\n"
                                     "    Expenses:\n")))
    transaction-string))

(defun +wd/guanaitong-transaction (chat-text chat-date)
  ;; (message "chat-text: %s" chat-text)
  (let* ((value-regexp "变动金额：:? ?[-+]?\\([-0-9,.]*\\)")
         (value (progn (string-match value-regexp chat-text)
                       (match-string 1 chat-text)))
         (stripped-value (replace-regexp-in-string (regexp-quote (string ?,)) "" value))
         (real-value (* -1 (string-to-number stripped-value)))
         (ledger-account "Assets:token:lunch")
         (transaction-string (concat  "\n"
                                      (format-time-string "%Y/%m/%d * %a %H:%M:%S" chat-date)
                                      " 关爱通消费\n"
                                      "    " ledger-account "  " (number-to-string real-value) " CNY  ;\n"
                                      "    Expenses:\n")))
    transaction-string))

(defvar +wd/telegram-cmb-chat-id (password-store-get "telegram/TELEGRAM_CMB_CHAT_ID"))
(defun +wd/telega-chat-update-function (chat)
  "When CHAT update, then do something."
  (let ((+wd/cmb-chat-id (string-to-number +wd/telegram-cmb-chat-id)))
    (when (= +wd/cmb-chat-id (plist-get chat :id))
      (let* ((chat-text (get-value-by-key-sequence chat '(:last_message :content :text :text)))
             (chat-date (get-value-by-key-sequence chat '(:last_message :date)))
             (guanaitong-p (string-match "余额变动提示" chat-text))
             (account-need-p (or (string-match "交易金额" chat-text) guanaitong-p)))
        (when (and account-need-p guanaitong-p)
          (+wd/write-transactions (+wd/guanaitong-transaction chat-text chat-date) +wd/ledger-file-name chat-date))
        (when (and account-need-p (not guanaitong-p))
          (+wd/write-transactions (+wd/creditcard-transaction chat-text chat-date) +wd/ledger-file-name chat-date))))))

(provide 'lib-telega)
