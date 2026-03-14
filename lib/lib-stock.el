;;; get-stock.el get stock -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Wang Ding
;;
;; Author: Wang Ding <ggwdwhu@gmail.com>
;; Maintainer: Wang Ding <ggwdwhu@gmail.com>
;; Created: September 15, 2025
;; Modified: September 15, 2025
;; Version: 0.0.1
;; Keywords: Symbol’s value as variable is void: finder-known-keywords
;; Homepage: https://github.com/fpGHwd/get-stock
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;
;;
;;; Code:

(require 'ledger-exec)
(require 'ert)
(require 'json)


;; How can we improve the implementation of the call-myfun function?
;; ledger -f ~/Documents/finance/ledger.dat reg assets:stock
;; ledger -f ~/Sync/org/ledger/2025/2025.ledger bal assets:stock | grep  -E "(sz|sh)[0-9]{6}"

(defvar wd-stock-ledger-stocks-cmd
  "ledger -f ~/org/ledger/current.ledger bal assets:stock | grep  -E \"(sz|sh)[0-9]{6}\""
  "Command to get stock information from ledger file.")


(defun wd-stock-init-hash-table ()
  "Test hash table for stock code and name."
  (interactive)
  (let* ((stock-name-code-table (make-hash-table :test 'equal))
         (raw-str (shell-command-to-string wd-stock-ledger-stocks-cmd))
         (lines (split-string raw-str "\n" t "[ \t]+")))
    ;; 把每行的代码和名称放进hash表
    (dolist (line lines)
      (let ((split-strings (split-string line "\\s-+" t)))
        (puthash (nth 2 split-strings) (nth 1 split-strings) stock-name-code-table)))
    stock-name-code-table))

;; get stock list
;; (gethash "sz002240" wd-stock-name-code-table)

;; get stock name
;; (setq stock-list (hash-table-keys wd-stock-name-code-table))

;; stock and price association list
;;;###autoload
(defun +wd/stock-get-stock-and-price ()
  (interactive)
  (let* ((init-hash-table (wd-stock-init-hash-table))
         (name-abbre (hash-table-keys init-hash-table))
         (stock-list-str (string-join name-abbre " "))
         (cmd (concat "LD_PRELOAD=/usr/lib/libstdc++.so.6 /home/data/python-venvs/main-3.13.7/bin/python3 /home/wd/org/ledger/2025/update-stock-price.py " stock-list-str))
         (output (shell-command-to-string cmd))
         (lines (split-string output "\n" t " "))
         (json-line
          (seq-find (lambda (l) (string-match-p "^\\[.*{.*}.*\\]$" l)) lines))
         (price-file-path "~/org/ledger/current/price.ledger"))
    (when json-line
      ;; (pp (json-parse-string json-line))
      (let* ((associate-list)
             (price-list (mapcar (lambda (item)
                                   (let* ((code (gethash "code" item))
                                          (price (gethash "close" item))
                                          (market (gethash "market" item))
                                          (code-abbre (gethash "code" item)))
                                     (push (cons (concat (downcase market) code) price) associate-list)))
                                 (json-parse-string json-line))))
        (dolist (pair associate-list)
          (let* ((stock-name (gethash (car pair) init-hash-table))
                 (price (cdr pair))
                 (date (format-time-string "%Y-%m-%d"))
                 (currency "CNY")
                 (comment-str (concat "   # " (car pair))) ; reading easily, as comment
                 (price-string (concat "P  "
                                       date "  "
                                       stock-name "   "
                                       (number-to-string price) " "
                                       currency)))
            ;; (message "stock-name: %s, price: %s" stock-name price)
            ;; (message "price-string: %s" price-string)
            (with-temp-buffer
              (insert-file-contents price-file-path)
              (goto-char (point-min))
              (unless (search-forward price-string nil t)
                (progn
                  (goto-char (point-max))
                  (unless (bolp) (insert "\n"))
                  (insert price-string "\n")
                  (write-region (point-min) (point-max) price-file-path nil 'silent)
                  (message "Line appended: %s" price-string))))))))))


(defvar +wd/update-stock-price-timer nil "Timer for auto-updating stock price.")
(unless +wd/update-stock-price-timer
  (setq +wd/update-stock-price-timer (run-at-time "18:30 tomorrow" 86400 #'+wd/stock-get-stock-and-price)))

;; write to file like:
;; P  2025-09-11  SZSXLN   18.42 CNY

;; ledger -f your.ledger --price-db prices.db prices SZSXLN
;; 显示最新价格
;; ledger -f /home/wd/Sync/org/ledger/2025/stock.ledger --price-db /home/wd/Sync/org/ledger/2025/price.db prices szSXLN
;; ledger -f /home/wd/Sync/org/ledger/2025/stock.ledger prices szSXLN
;; 显示股票的总资产：已完成
;; ledger -f /home/wd/Sync/org/ledger/2025/stock.ledger --price-db /home/wd/Sync/org/ledger/2025/price.db bal ^Assets:stock -X CNY
;; ledger -f /home/wd/Sync/org/ledger/2025/stock.ledger bal ^Assets:stock -X CNY


;; ledger -f stock.ledger bal Assets:stock --depth 3 --flat
;; ; ledger -f stock.ledger bal 'Assets:stock:(sz|sh)[0-9]{6}'
;; ; ledger -f /home/wd/Sync/org/ledger/2025/stock.ledger bal -V -e $(date '+%Y-%m-%d')

;; ; 获取 ledger 未平仓账户；
;; ; 更新数据库更新持有股票的账户的当前价格，使用 python 更新价格到 ledger 数据库文件中
;; ; 判断已持仓的账户是否需要卖出：当前价格，买的时候价格（或者说赢利了多少）
;; ; 使用 ledger -f stock.ledger bal -V -e $(date '+%Y-%m-%d') 计算当前总价值

;; 邮件发送到自己的手机上提醒


(provide 'lib-stock)
