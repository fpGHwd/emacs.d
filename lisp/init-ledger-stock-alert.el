;;; init-ledger-stock-alert.el --- Ledger stock price alerts -*- lexical-binding: t; -*-

(require 'subr-x)

(declare-function ledger-exec-ledger "ledger-exec"
                  (input-buffer &optional output-buffer &rest args))
(declare-function message-goto-body "message")
(declare-function message-mail "message"
                  (&optional to subject other-headers continue switch-function
                             yank-action send-actions return-action &rest ignored))
(declare-function message-send-mail "message" (&optional arg))
(declare-function url-retrieve "url"
                  (url callback &optional cbargs silent inhibit-cookies))

(defvar url-http-end-of-headers)
(defvar url-http-response-status)
(defvar message-generate-new-buffers)
(defvar message-send-mail-function)

(defgroup +wd/stock-alert nil
  "Email alerts for profitable A-share holdings."
  :group 'ledger)

(defcustom +wd/stock-alert-ledger-file "~/org/ledger/2026/2026.ledger"
  "Ledger journal from which stock holdings are calculated."
  :type 'file
  :group '+wd/stock-alert)

(defcustom +wd/stock-alert-profit-step 0.05
  "Gain ratio between consecutive profit alert levels."
  :type 'number
  :group '+wd/stock-alert)

(defcustom +wd/stock-alert-poll-interval (* 5 60)
  "Seconds between stock price checks during A-share trading hours."
  :type 'integer
  :group '+wd/stock-alert)

(defconst +wd/stock-alert--quote-url "https://qt.gtimg.cn/q=")

(defvar +wd/stock-alert--timer nil)
(defvar +wd/stock-alert--request-in-flight nil)
(defvar +wd/stock-alert--levels (make-hash-table :test #'equal))

(defun +wd/stock-alert--number (string context)
  "Parse STRING as a decimal number or report invalid CONTEXT."
  (unless (string-match-p "\\`-?[0-9]+\\(?:\\.[0-9]+\\)?\\'" string)
    (error "Invalid %s in Ledger output: %S" context string))
  (string-to-number string))

(defun +wd/stock-alert--ledger-output ()
  "Return stock posting data produced by Ledger."
  (require 'ledger-exec)
  (let ((file (expand-file-name +wd/stock-alert-ledger-file)))
    (unless (file-readable-p file)
      (error "Stock alert Ledger file is not readable: %s" file))
    (with-temp-buffer
      (setq default-directory (file-name-directory file))
      (insert-file-contents file)
      (let ((source (current-buffer)))
        (with-temp-buffer
          (ledger-exec-ledger
           source (current-buffer) "register" "^Assets:Stock:"
           "--format"
           "%(date)\t%(account)\t%(quantity(amount))\t%(commodity(amount))\t%(quantity(cost))\n")
          (buffer-string))))))

(defun +wd/stock-alert--parse-ledger-output (output)
  "Calculate open stock holdings from Ledger OUTPUT.
Return plists containing :symbol, :quantity, and moving-average :cost."
  (let ((positions (make-hash-table :test #'equal)))
    (dolist (line (split-string output "\n" t))
      (pcase (split-string line "\t")
        (`(,_date ,_account ,quantity-text ,commodity-text ,cost-text)
         (let ((symbol (string-trim commodity-text "\"" "\"")))
           (when (string-match-p "\\`\\(?:SH\\|SZ\\)\\.[0-9]\\{6\\}\\'" symbol)
             (let* ((quantity (+wd/stock-alert--number quantity-text "quantity"))
                    (old (or (gethash symbol positions) '(0.0 . 0.0)))
                    (old-quantity (car old))
                    (old-cost (cdr old)))
               (cond
                ((> quantity 0)
                 (let* ((total-cost (+wd/stock-alert--number cost-text "cost"))
                        (new-quantity (+ old-quantity quantity)))
                   (unless (> total-cost 0)
                     (error "Non-positive buy cost for %s: %s" symbol cost-text))
                   (puthash symbol
                            (cons new-quantity
                                  (/ (+ (* old-quantity old-cost) total-cost)
                                     new-quantity))
                            positions)))
                ((< quantity 0)
                 (let ((new-quantity (+ old-quantity quantity)))
                   (when (< new-quantity -1e-8)
                     (error "Stock sale exceeds recorded holding for %s" symbol))
                   (if (< (abs new-quantity) 1e-8)
                       (remhash symbol positions)
                     (puthash symbol (cons new-quantity old-cost) positions)))))))))
        (_ (error "Malformed Ledger stock row: %S" line))))
    (let (holdings)
      (maphash (lambda (symbol position)
                 (push (list :symbol symbol
                             :quantity (car position)
                             :cost (cdr position))
                       holdings))
               positions)
      (sort holdings
            (lambda (left right)
              (string< (plist-get left :symbol)
                       (plist-get right :symbol)))))))

(defun +wd/stock-alert--holdings ()
  "Return current stock holdings calculated from the configured journal."
  (+wd/stock-alert--parse-ledger-output (+wd/stock-alert--ledger-output)))

(defun +wd/stock-alert--quote-code (symbol)
  "Convert Ledger stock SYMBOL to the Tencent quote code syntax."
  (replace-regexp-in-string "\\." "" (downcase symbol)))

(defun +wd/stock-alert--parse-quotes (body symbols expected-date)
  "Parse Tencent quote BODY for SYMBOLS dated EXPECTED-DATE.
Return a hash table keyed by Ledger stock symbol."
  (let ((quotes (make-hash-table :test #'equal)))
    (dolist (line (split-string body "\n" t))
      (when (string-match
             "\\`v_\\(sh\\|sz\\)\\([0-9]\\{6\\}\\)=\"\\(.*\\)\";[[:space:]]*\\'"
             line)
        (let* ((symbol (upcase (concat (match-string 1 line) "."
                                       (match-string 2 line))))
               (fields (split-string (match-string 3 line) "~"))
               (name (nth 1 fields))
               (code (nth 2 fields))
               (price-text (nth 3 fields))
               (timestamp (nth 30 fields)))
          (when (member symbol symbols)
            (unless (and name code price-text timestamp
                         (string= code (substring symbol 3))
                         (string-match-p "\\`[0-9]\\{14\\}\\'" timestamp)
                         (string-prefix-p expected-date timestamp))
              (error "Malformed or stale Tencent quote for %s" symbol))
            (let ((price (+wd/stock-alert--number price-text "quote price")))
              (unless (> price 0)
                (error "Non-positive Tencent quote for %s" symbol))
              (puthash symbol
                       (list :symbol symbol :name name :price price
                             :timestamp timestamp)
                       quotes))))))
    (dolist (symbol symbols)
      (unless (gethash symbol quotes)
        (error "Tencent response omitted held stock %s" symbol)))
    quotes))

(defun +wd/stock-alert--level (gain)
  "Return the alert level for GAIN."
  (if (< gain 0)
      0
    (1+ (floor (+ (/ gain +wd/stock-alert-profit-step) 1e-9)))))

(defun +wd/stock-alert--format-timestamp (timestamp)
  "Format Tencent quote TIMESTAMP for display."
  (format "%s-%s-%s %s:%s:%s"
          (substring timestamp 0 4) (substring timestamp 4 6)
          (substring timestamp 6 8) (substring timestamp 8 10)
          (substring timestamp 10 12) (substring timestamp 12 14)))

(defun +wd/stock-alert--mail-body (alerts)
  "Return the summary mail body for ALERTS."
  (concat
   "以下持仓刚刚上穿盈利提醒档位：\n\n"
   (mapconcat
    (lambda (alert)
      (format "[%s] %s (%s)\n  持仓 %.0f 股，成本 %.4f，现价 %.2f，收益 %.2f%%\n  行情时间 %s"
              (format "%.0f%%"
                      (* 100 +wd/stock-alert-profit-step
                         (1- (plist-get alert :level))))
              (plist-get alert :name) (plist-get alert :symbol)
              (plist-get alert :quantity) (plist-get alert :cost)
              (plist-get alert :price) (* 100 (plist-get alert :gain))
              (+wd/stock-alert--format-timestamp
               (plist-get alert :timestamp))))
    alerts "\n\n")
   "\n"))

(defun +wd/stock-alert--send-mail (alerts)
  "Send one summary email for ALERTS."
  (require 'message)
  (unless (and (stringp user-mail-address)
               (not (string-empty-p user-mail-address)))
    (error "`user-mail-address' is not configured"))
  (unless (functionp message-send-mail-function)
    (error "`message-send-mail-function' is not configured"))
  (let ((message-generate-new-buffers t)
        mail-buffer)
    (unwind-protect
        (progn
          (message-mail
           user-mail-address
           (format "[A股提醒] %d 只持仓上穿盈利档位" (length alerts))
           nil nil
           (lambda (name)
             (setq mail-buffer (get-buffer-create name))
             (set-buffer mail-buffer)))
          (with-current-buffer mail-buffer
            (message-goto-body)
            (insert (+wd/stock-alert--mail-body alerts))
            (message-send-mail)))
      (when (buffer-live-p mail-buffer)
        (with-current-buffer mail-buffer
          (set-buffer-modified-p nil))
        (kill-buffer mail-buffer)))))

(defun +wd/stock-alert--forget-closed-positions (holdings)
  "Discard alert state for symbols absent from HOLDINGS."
  (let ((open (make-hash-table :test #'equal)) stale)
    (dolist (holding holdings)
      (puthash (plist-get holding :symbol) t open))
    (maphash (lambda (symbol _level)
               (unless (gethash symbol open)
                 (push symbol stale)))
             +wd/stock-alert--levels)
    (dolist (symbol stale)
      (remhash symbol +wd/stock-alert--levels))))

(defun +wd/stock-alert--process-quotes (holdings quotes)
  "Update alert state and email upward transitions in HOLDINGS using QUOTES."
  (let (alerts)
    (dolist (holding holdings)
      (let* ((symbol (plist-get holding :symbol))
             (quote (gethash symbol quotes))
             (cost (plist-get holding :cost))
             (price (plist-get quote :price))
             (gain (/ (- price cost) (float cost)))
             (level (+wd/stock-alert--level gain))
             (old-level (gethash symbol +wd/stock-alert--levels 0)))
        (cond
         ((> level old-level)
          (push (list :symbol symbol
                      :quantity (plist-get holding :quantity)
                      :cost cost
                      :name (plist-get quote :name)
                      :price price
                      :timestamp (plist-get quote :timestamp)
                      :gain gain
                      :level level)
                alerts))
         ((< level old-level)
          (puthash symbol level +wd/stock-alert--levels)))))
    (setq alerts
          (sort alerts
                (lambda (left right)
                  (string< (plist-get left :symbol)
                           (plist-get right :symbol)))))
    (when alerts
      (+wd/stock-alert--send-mail alerts)
      (dolist (alert alerts)
        (puthash (plist-get alert :symbol)
                 (plist-get alert :level)
                 +wd/stock-alert--levels)))
    alerts))

(defun +wd/stock-alert--quote-callback (status holdings)
  "Handle Tencent quote response STATUS for HOLDINGS."
  (unwind-protect
      (condition-case err
          (progn
            (when-let* ((request-error (plist-get status :error)))
              (error "Tencent quote request failed: %S" request-error))
            (unless (eq url-http-response-status 200)
              (error "Tencent quote request returned HTTP %S"
                     url-http-response-status))
            (goto-char url-http-end-of-headers)
            (let* ((body (decode-coding-string
                          (buffer-substring-no-properties (point) (point-max))
                          'gb18030))
                   (symbols (mapcar (lambda (holding)
                                      (plist-get holding :symbol))
                                    holdings))
                   (quotes (+wd/stock-alert--parse-quotes
                            body symbols
                            (format-time-string "%Y%m%d" nil 28800)))
                   (alerts (+wd/stock-alert--process-quotes holdings quotes)))
              (if alerts
                  (message "Stock alert sent for %d holding(s)" (length alerts))
                (message "Stock alert check completed; no upward transition"))))
        (error
         (display-warning '+wd/stock-alert (error-message-string err) :error)))
    (setq +wd/stock-alert--request-in-flight nil)
    (kill-buffer (current-buffer))))

(defun +wd/stock-alert-check ()
  "Check current A-share holdings and email new profit-level crossings."
  (interactive)
  (when +wd/stock-alert--request-in-flight
    (user-error "A stock alert request is already in progress"))
  (let ((holdings (+wd/stock-alert--holdings)))
    (+wd/stock-alert--forget-closed-positions holdings)
    (if (null holdings)
        (progn
          (clrhash +wd/stock-alert--levels)
          (message "Stock alert check completed; no open stock holdings"))
      (require 'url)
      (let* ((codes (mapconcat
                     (lambda (holding)
                       (+wd/stock-alert--quote-code
                        (plist-get holding :symbol)))
                     holdings ","))
             (url (concat +wd/stock-alert--quote-url codes)))
        (setq +wd/stock-alert--request-in-flight t)
        (condition-case err
            (url-retrieve url #'+wd/stock-alert--quote-callback
                          (list holdings) t t)
          (error
           (setq +wd/stock-alert--request-in-flight nil)
           (signal (car err) (cdr err))))))))

(defun +wd/stock-alert--market-open-p (&optional time)
  "Return non-nil when TIME is within mainland A-share trading hours."
  (let* ((weekday (string-to-number
                   (format-time-string "%u" time 28800)))
         (hour (string-to-number
                (format-time-string "%H" time 28800)))
         (minute (string-to-number
                  (format-time-string "%M" time 28800)))
         (clock (+ (* hour 60) minute)))
    (and (<= 1 weekday 5)
         (or (<= (+ (* 9 60) 30) clock (+ (* 11 60) 30))
             (<= (* 13 60) clock (* 15 60))))))

(defun +wd/stock-alert--tick ()
  "Run a stock check when the A-share market is open."
  (when (and (+wd/stock-alert--market-open-p)
             (not +wd/stock-alert--request-in-flight))
    (condition-case err
        (+wd/stock-alert-check)
      (error
       (display-warning '+wd/stock-alert (error-message-string err) :error)))))

(defun +wd/stock-alert-start ()
  "Start or replace the A-share stock alert timer."
  (when (timerp +wd/stock-alert--timer)
    (cancel-timer +wd/stock-alert--timer))
  (setq +wd/stock-alert--timer
        (run-at-time nil +wd/stock-alert-poll-interval
                     #'+wd/stock-alert--tick)))

(+wd/stock-alert-start)

(provide 'init-ledger-stock-alert)
;;; init-ledger-stock-alert.el ends here
