;;; init-schedule.el --- User scheduled tasks -*- lexical-binding: t; -*-

(require 'json)
(require 'subr-x)

;; ---------------------------------------------------------------------------
;; Auto-commit and push ~/org at scheduled time
;; ---------------------------------------------------------------------------

(defvar +wd/org-autocommit-repo "~/org"
  "Directory to auto-commit and push.")

(defvar +wd/org-autocommit-timer nil
  "Timer for scheduled org auto-commit.")

(defun +wd/org-autocommit ()
  "Stage all changes in `+wd/org-autocommit-repo', commit, and push.
Skip if there are no changes.  Commit message includes timestamp.
After committing, reschedule for the next day at 17:30."
  (interactive)
  (require 'org)
  (let ((default-directory (expand-file-name +wd/org-autocommit-repo)))
    (magit-with-toplevel
      (magit-stage-modified t)
      (when (magit-anything-staged-p)
        (magit-run-git "commit" "-m" "auto-commit")
        (magit-push-current-to-pushremote nil))))
  ;; Reschedule for tomorrow 17:30
  (+wd/org-autocommit-schedule))

(defun +wd/org-autocommit-schedule ()
  "Schedule `+wd/org-autocommit' for the next 17:30.
If 17:30 has already passed today, schedule for tomorrow."
  (interactive)
  (when (timerp +wd/org-autocommit-timer)
    (cancel-timer +wd/org-autocommit-timer))
  (let* ((now (current-time))
         (today-1730 (encode-time 0 30 17 (nth 3 (decode-time now))
                                  (nth 4 (decode-time now))
                                  (nth 5 (decode-time now))))
         (next-run (if (time-less-p now today-1730)
                       today-1730
                     (time-add today-1730 86400))))
    (setq +wd/org-autocommit-timer
          (run-at-time next-run nil #'+wd/org-autocommit))
    (message "Org auto-commit scheduled at %s"
             (format-time-string "%Y-%m-%d %H:%M" next-run))))

;; ---------------------------------------------------------------------------
;; user-schedule-mode: minor mode to enable scheduled tasks
;; ---------------------------------------------------------------------------

(define-minor-mode user-schedule-mode
  "Toggle user scheduled tasks (e.g. daily org auto-commit)."
  :init-value t
  :global t
  :lighter " Sched"
  :group 'user-schedule
  (if user-schedule-mode
      (+wd/org-autocommit-schedule)
    (when (timerp +wd/org-autocommit-timer)
      (cancel-timer +wd/org-autocommit-timer)
      (setq +wd/org-autocommit-timer nil))))

;; Enable by default
(when (string= (system-name) "ubuntu2204")
  (user-schedule-mode +1))

(defvar +wd/stock-ledger-focus-timer nil)

(defun +wd/stock-ledger-run ()
  "Capture stock state and append ledger diff."
  (interactive)
  (let* ((json (string-trim (shell-command-to-string "/Users/wd/bin/capture-ths-after-close")))
         (data (condition-case nil
                   (json-parse-string json :object-type 'alist :array-type 'list)
                 (error
                  (message "Stock capture returned non-json: %s" json)
                  nil)))
         (suffix (alist-get 'suffix data))
         (holdings (alist-get 'holdings data))
         (assets (alist-get 'assets data))
         (ledger-file (expand-file-name "~/org/ledger/2026/stock.ledger"))
         (captured-at (alist-get 'captured_at data))
         old target seen rows old-cash new-cash cny-total)
    (when (and suffix holdings)
      (dolist (line (split-string
                     (shell-command-to-string
                      (format "ledger -f %s bal Assets:stock --flat"
                              (shell-quote-argument ledger-file)))
                     "\n" t))
        (when (string-match "^[ \t]*\\([-+]?[0-9.]+\\) \\([^ \t]+\\)[ \t]+Assets:[Ss]tock:\\(S[HZ][0-9]\\{6\\}\\)$" line)
          (push (list (match-string 3 line)
                      (string-to-number (match-string 1 line))
                      (match-string 2 line)
                      nil)
                old))
        (when (string-match "^[ \t]*\\([-+]?[0-9.]+\\) CNY[ \t]+Assets:[Ss]tock:[Gg]uosheng$" line)
          (setq old-cash (string-to-number (match-string 1 line)))))
      (dolist (holding holdings)
        (let* ((code (alist-get 'code holding))
               (trading-market (alist-get 'trading_market holding))
               (market (cond
                        ((and trading-market (string-match-p "\\(沪\\|上海\\|SH\\)" trading-market)) "SH")
                        ((and trading-market (string-match-p "\\(深\\|深圳\\|SZ\\)" trading-market)) "SZ")
                        ((string-prefix-p "6" code) "SH")
                        (t "SZ")))
               (account (concat market code))
               (qty (or (alist-get 'actual_quantity holding)
                        (alist-get 'share_balance holding)
                        (alist-get 'available_balance holding))))
          (push (list account qty (alist-get 'name holding)
                      (or (alist-get 'cost_price holding)
                          (alist-get 'market_price holding)))
                target)))
      (dolist (stock (append target old))
        (let ((account (car stock)))
          (unless (member account seen)
            (push account seen)
            (let* ((new (or (cadr (assoc account target)) 0))
                   (old-qty (or (cadr (assoc account old)) 0))
                   (delta (- new old-qty)))
              (when (/= delta 0)
                (let* ((holding (or (assoc account target)
                                    (assoc account old)))
                       (name (or (nth 2 holding) account))
                       (price (nth 3 holding)))
                  (push (format "    %-34s %10s %s%s\n"
                                (concat "Assets:Stock:" account)
                                delta
                                name
                                (if price (format " @ CNY %s" price) ""))
                        rows)
                  (when price
                    (setq cny-total (+ (or cny-total 0) (* delta price))))))))))
      (setq new-cash (or (alist-get 'available_cash assets)
                         (alist-get 'cash_balance assets)))
      (when new-cash
        (let ((delta (- new-cash (or old-cash 0))))
          (when (/= delta 0)
            (push (format "    %-34s %10.2f CNY\n"
                          "Assets:Stock:Guosheng"
                          delta)
                  rows)
            (setq cny-total (+ (or cny-total 0) delta)))))
      (with-current-buffer (find-file-noselect ledger-file)
        (goto-char (point-min))
        (unless (or (null rows) (search-forward suffix nil t))
          (goto-char (point-max))
          (unless (bolp) (insert "\n"))
          (insert
           (format "\n; AUTO capture-ths %s %s/%s\n%s \"A-share trade diff\"\n%s    %s\n\n"
                   captured-at
                   (alist-get 'remote_dir data)
                   suffix
                   (format-time-string "%Y/%m/%d %a %H:%M:%S" (date-to-time captured-at))
                   (mapconcat #'identity (nreverse rows) "")
                   (if (> (or cny-total 0) 0)
                       "Income:Investment:Trade Adjustment"
                     "Expenses:Investment:Trade Adjustment")))
          (save-buffer))))
    (when suffix
      (message "stock ledger: %s" suffix))))

(when (eq system-type 'darwin)
  (add-hook
   'focus-in-hook
   (lambda ()
     (when (>= (string-to-number (format-time-string "%H%M")) 1500)
       (when (timerp +wd/stock-ledger-focus-timer)
         (cancel-timer +wd/stock-ledger-focus-timer))
       (setq +wd/stock-ledger-focus-timer
             (run-at-time
              "1 min" nil
              #'+wd/stock-ledger-run))))))

(provide 'init-schedule)
;;; init-schedule.el ends here
