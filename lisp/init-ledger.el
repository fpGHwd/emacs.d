;;; init-ledger.el --- Finance (ledger-mode) -*- lexical-binding: t; -*-

(setup ledger
  (:match-file "*.ledger")
  (:hook auto-revert-mode)
  (:setopt
   ledger-reports
   '(("month meal expense"
      "ledger -f %(ledger-file) --monthly register ^Expenses:Living:Food")
     ("stock current"
      "ledger -f %(ledger-file) bal ^Assets:Stock -V")
     ("stock net return"
      "ledger -f %(ledger-file) bal -V Assets:Stock Assets:Investment:Cash")
     ("stock monthly return"
      "ledger -f %(ledger-file) reg -V Assets:Stock Assets:Investment:Cash --monthly --collapse")
     ("month period"
      "ledger -f %(ledger-file) balance --period %(month) ^Income ^Expenses")
     ("year budget"
      "ledger --budget --yearly register ^Expenses -f %(ledger-file)")
     ("month budget"
      "ledger --budget --monthly register ^Expenses -f %(ledger-file)")
     ("cashflow" "ledger -f %(ledger-file) balance ^Income ^Expenses")
     ("net worth" "ledger -f %(ledger-file) balance ^Assets ^Liabilities")
     ("bal" "%(binary) -f %(ledger-file) bal")
     ;; ("bal" "%(binary) -f %(ledger-file) bal -V")
     ("reg" "%(binary) -f %(ledger-file) reg")
     ("payee" "%(binary) -f %(ledger-file) reg @%(payee)")
     ("account" "%(binary) -f %(ledger-file) reg %(account)"))
   ledger-schedule-file "~/org/ledger/2021/schedule.ledger"
   ledger-accounts-file "~/org/ledger/account.ledger"
   ledger-reconcile-default-commodity "CNY"
   ledger-reconcile-default-date-format "%Y-%m-%d"))

(provide 'init-ledger)
;;; init-ledger.el ends here
