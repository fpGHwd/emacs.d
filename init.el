;;; init.el -*- lexical-binding: t; -*-

(defconst *not-work* (not (string= (system-name) "ubuntu2204")))

(doom! :input

       :completion
       (corfu +orderless)     ; complete with cap(f), cape and a flying feather!
       (vertico +icons)       ; the search engine of the future

       :ui
       doom                   ; what makes DOOM look the way it does
       hl-todo                ; highlight TODO/FIXME/NOTE/DEPRECATED/HACK/REVIEW
       modeline               ; snazzy, Atom-inspired modeline, plus API
       (popup +defaults)      ; tame sudden yet inevitable temporary windows
       (vc-gutter +pretty)    ; vcs diff in the fringe
       (window-select +numbers)         ; visually switch windows
       workspaces             ; tab emulation, persistence & separate workspaces
       zen                    ; distraction-free coding or writing

       :editor
       file-templates              ; auto-snippets for empty files
       (format +onsave)            ; automated prettiness
       lispy                       ; vim for lisp, for people who don't like vim
       multiple-cursors            ; editing in many places at once
       snippets                    ; my elves. They type so I don't have to
       word-wrap                   ; soft wrapping with language-aware indent
       (meow +qwerty +tree-sitter)

       :emacs
       (dired +dirvish +icons)       ; making dired pretty [functional]
       tramp                         ; remote files at your arthritic fingertips
       undo              ; persistent, smarter undo for your inevitable mistakes
       vc                ; version-control and Emacs, sitting in a tree

       :term
       ghostel                          ; the best terminal emulation in Emacs

       :checkers
       (syntax +childframe +icons)   ; tasing you for every semicolon you forget

       :tools
       (:if *not-work* biblio)     ; Writes a PhD for you (citation needed)   
       (collab +tunnel)            ; buffers with friends
       (debugger +lsp)             ; stepping through code, to help you add bugs
       direnv
       (eval +overlay)                        ; run code, run (also, repls)
       (lookup +docsets +dictionary +offline) ; navigate your code and its documentation
       (:if *not-work* llm)   
       (lsp +eglot)
       (magit +forge)                   ; a git porcelain for Emacs
       make                             ; run make tasks from Emacs
       (pass +auth)                     ; password manager for nerds
       pdf                              ; pdf enhancements
       tmux                             ; an API for interacting with tmux
       tree-sitter

       :os
       (:if (featurep :system 'macos) macos) ; improve compatibility with macOS
       tty                              ; improve the terminal Emacs experience

       :lang
       (cc +lsp +tree-sitter)                       ; C > C++ == 1
       (:if *not-work* (clojure +tree-sitter +lsp)) ; java with a lisp
       (:if *not-work* common-lisp) ; if you've seen one lisp, you've seen them all
       emacs-lisp                   ; drown in parentheses
       (:if *not-work* (go +lsp +tree-sitter)) ; the hipster dialect
       (haskell +lsp +tree-sitter)      ; a language that's lazier than I am
       (json +lsp +tree-sitter)         ; At least it ain't XML
       (:if *not-work* (latex +fold +lsp)) ; writing papers in Emacs has never been so fun
       (:if *not-work* ledger)             ; be audit you can be
       (nix +tree-sitter +lsp)             ; I hereby declare "nix geht mehr!"
       (org +crypt +gnuplot
            +journal +dragndrop
            +pandoc +noter
            +roam +pretty)              ; organize your plain life in plain text
       (:if *not-work* racket)            ; a DSL for DSLs
       (:if *not-work* plantuml)        ; diagrams for confusing people more
       (python +lsp +poetry +tree-sitter)
       (:if *not-work* (rust +tree-sitter)) ; Fe2O3.unwrap().unwrap().unwrap().unwrap()
       (:if *not-work* scad)            ; trust the preview, regret the render
       ;; (:if *not-work* (scheme +guile)) ; a fully conniving family of lisps
       (sh +tree-sitter)             ; she sells {ba,z,fi}sh shells on the C xor
       (:if *not-work* swift)        ; who asked for emoji variables?

       :email
       (mu4e +gmail +mbsync +org)

       :app
       calendar
       (:if *not-work* everywhere)      ; *leave* Emacs!? You must be joking
       irc                              ; how neckbeards socialize
       (rss +org +youtube)              ; emacs as an RSS reader

       :config
       (default +bindings +smartparens +gnupg))
