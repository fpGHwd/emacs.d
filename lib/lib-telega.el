;;; ../../Sync/dotfiles/doom.d/lib/lib-telega.el -*- lexical-binding: t; -*-

(defun get-value-by-key-sequence (plist keys)
  "根据键序列获取嵌套的 plist 中的值"
  (let ((value plist))
    (dolist (key keys value)
      (setq value (plist-get value key)))
    value))

;; update telega hook to accounting
(defvar +wd/ledger-file-name "~/org/ledger/current.ledger")
(defvar ledger-mutex (make-mutex "open ledger file"))

(defun +wd/telega-normalize-transaction-value (chat-text amount)
  "Return AMOUNT adjusted for special transaction text in CHAT-TEXT.
Messages containing \"退货\" should always produce a positive amount."
  (if (and (stringp chat-text)
           (string-match-p "退货" chat-text))
      (abs amount)
    amount))

(defun +wd/telega-parse-transaction-time (chat-text chat-date)
  "Parse transaction time from CHAT-TEXT, falling back to CHAT-DATE's year.
Recognizes message headers like \"尾号5048信用卡04月19日19:11\" and explicit
fields like \"交易时间：04月19日 19:11\"."
  (let ((current-year (format-time-string "%Y" chat-date))
        (parsed nil))
    (when (and (stringp chat-text)
               (or (string-match
                    "\\([0-9]\\{2\\}\\)月\\([0-9]\\{2\\}\\)日\\s-*\\([0-9]\\{2\\}\\):\\([0-9]\\{2\\}\\)\\(?::\\([0-9]\\{2\\}\\)\\)?"
                    chat-text)
                   (string-match
                    "交易时间：? ?\\([0-9]\\{2\\}\\)月\\([0-9]\\{2\\}\\)日\\s-*\\([0-9]\\{2\\}\\):\\([0-9]\\{2\\}\\)\\(?::\\([0-9]\\{2\\}\\)\\)?"
                    chat-text)))
      (setq parsed
            (format "%s/%s/%s * %s:%s:%s"
                    current-year
                    (match-string 1 chat-text)
                    (match-string 2 chat-text)
                    (match-string 3 chat-text)
                    (match-string 4 chat-text)
                    (or (match-string 5 chat-text) "00"))))
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
                             "\\([^[:space:]]+\\)[[:space:]]+\\*[[:space:]]+"
                             "\\1 "
                             headline))))
    (delq nil (list headline alt-headline))))

(defun +wd/write-transactions (transaction-text)
  (with-mutex ledger-mutex
    (when (string= (system-name) "nixos-nuc")
      (with-temp-buffer
        (insert-file-contents +wd/ledger-file-name)
        (goto-char (point-max))
        (let*
            ((buffer-string (buffer-substring (point-min) (point-max)))
             (dedup-keys (+wd/telega-transaction-dedup-keys transaction-text)))
          (when (and dedup-keys
                     (not (seq-some
                           (lambda (key)
                             (string-match-p (regexp-quote key) buffer-string))
                           dedup-keys)))
            (progn
              (insert transaction-text)
              (write-region (point-min) (point-max) +wd/ledger-file-name))))))))

(defun +wd/creditcard-transaction (chat-text chat-date)
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
         (ledger-account (progn
                           (cond ((or (string= card-number "5048")
                                      (string= card-number "6798")
                                      (string= card-number "2972"))
                                  (concat "Liabilities:credit card:cmb-5048:" card-number))
                                 ((string= card-number "6912")
                                  "Assets:current:deposit:spdb-6912"))))
         (description (if pufa-p transaction-pattern trader-name)))
    (when (and card-number stripped-value ledger-account description)
      (concat "\n"
              (if transaction-date-time
                  transaction-date-time
                (format-time-string "%Y/%m/%d * %a %H:%M:%S" chat-date))
              " "
              description
              "\n"
              "    " ledger-account "  " (number-to-string real-value) " CNY  ;\n"
              "    Expenses:\n"))))

(defun +wd/guanaitong-transaction (chat-text chat-date)
  ;; (message "chat-text: %s" chat-text)
  (let* ((value-regexp "变动金额：:? ?[-+]?\\([-0-9,.]*\\)")
         (value (+wd/telega-match-group value-regexp chat-text 1))
         (stripped-value (and value
                              (replace-regexp-in-string (regexp-quote (string ?,)) "" value)))
         (raw-value (and stripped-value
                         (* -1 (string-to-number stripped-value))))
         (real-value (+wd/telega-normalize-transaction-value chat-text raw-value))
         (ledger-account "Assets:token:lunch")
         (transaction-string (and stripped-value
                                  (concat  "\n"
                                           (format-time-string "%Y/%m/%d * %a %H:%M:%S" chat-date)
                                           " 关爱通消费\n"
                                           "    " ledger-account "  " (number-to-string real-value) " CNY  ;\n"
                                           "    Expenses:\n"))))
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
          (let ((transaction-text (+wd/guanaitong-transaction chat-text chat-date)))
            (when transaction-text
              (+wd/write-transactions transaction-text))))
        (when (and account-need-p (not guanaitong-p))
          (let ((transaction-text (+wd/creditcard-transaction chat-text chat-date)))
            (when transaction-text
              (+wd/write-transactions transaction-text))))))))

(provide 'lib-telega)
