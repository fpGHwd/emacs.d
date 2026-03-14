;;; ../../Sync/dotfiles/doom.d/lib/lib-rime.el -*- lexical-binding: t; -*-


(defun +pyim-probe-telega-msg ()
  "Return if current point is at a telega button."
  (s-contains? "telega" (symbol-name (get-text-property (point)
                                                        'category))))

(provide 'lib-rime)
