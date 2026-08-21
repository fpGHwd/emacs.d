;;; lib-pdf-sync.el --- Remote PDF annotation sync -*- lexical-binding: t; -*-

;; Transfer only annotations (JSON). Skip duplicates on remote PDF.

(defvar +wd/pdf-sync-python-code
  "import fitz,sqlite3,sys,os,glob,json
A=json.load(open(sys.argv[1]))
if not A:os.unlink(sys.argv[1]);sys.exit(0)
r=sqlite3.connect(sys.argv[2]+'/metadata.db').execute('SELECT path FROM books WHERE id=?',(sys.argv[3],)).fetchone()
if not r:sys.exit(1)
f=glob.glob(sys.argv[2]+'/'+r[0]+'/*.pdf')[0]
d=fitz.open(f)
# dedup by (page, type, rounded rect)
seen=set((i,a.type[1],tuple(round(v,1)for v in a.rect))for i in range(len(d))for a in d[i].annots())
for a in A:
 e=a['edges'];t=a['type'];R=fitz.Rect(e if isinstance(e[0],(int,float))else e[0])
 k=(a['page']-1,t,tuple(round(v,1)for v in R))
 if k in seen:continue
 p=d[a['page']-1]
 if t=='Text':p.add_text_annot(R.tl,a.get('contents',''))
 else:getattr(p,{'Highlight':'add_highlight_annot','Underline':'add_underline_annot','StrikeOut':'add_strikeout_annot','Squiggly':'add_squiggly_annot'}.get(t,'add_highlight_annot'))(R)
d.save(f);d.close();os.unlink(sys.argv[1])")

(defun +wd/pdf-annot-iter (pdf-file fn)
  "Iterate over all annotations in PDF-FILE, calling FN for each.
FN is called with (PAGE TYPE EDGES CONTENTS)."
  (let ((pages (pdf-info-number-of-pages pdf-file)))
    (dotimes (i pages)
      (dolist (a (pdf-info-getannots (1+ i) pdf-file))
        (funcall fn (1+ i)
                 (alist-get 'type a)
                 (alist-get 'edges a)
                 (alist-get 'contents a))))))

(defun +wd/pdf-annot-export (pdf-file json-file)
  "Export annotations from PDF-FILE to JSON-FILE."
  (let (annots)
    (+wd/pdf-annot-iter pdf-file
      (lambda (page type edges contents)
        (push (list :page page :type type :edges edges :contents contents) annots)))
    (with-temp-file json-file (insert (json-encode (nreverse annots))))
    json-file))

(defun +wd/pdf-calibre-id-from-file (file)
  "Extract Calibre ID from FILE name like CDB-1234.pdf."
  (let ((base (file-name-base file)))
    (if (string-match "CDB-\\([0-9]+\\)" base)
        (match-string 1 base)
      (user-error "Cannot derive Calibre ID from %s" file))))

(defun +wd/pdf-annot-sync (&optional calibre-id)
  "Sync current PDF annotations to remote Calibre book.
CALIBRE-ID is optional; if omitted, derived from buffer file name (CDB-NNNN.pdf)."
  (interactive)
  (unless (derived-mode-p 'pdf-view-mode) (user-error "Not a PDF buffer"))
  (let* ((id (or calibre-id
                 (and (buffer-file-name)
                      (+wd/pdf-calibre-id-from-file (buffer-file-name)))
                 (user-error "No CALIBRE-ID and file name doesn't match CDB-NNNN")))
         (json (make-temp-file "annots" nil ".json"))
         (remote-json (format "/dev/shm/annots-%s.json" id))
         (lib +wd/calibre-local-library-root))
    (unwind-protect
        (progn
          (+wd/pdf-annot-export (pdf-view-buffer-file-name) json)
          (call-process "scp" nil nil nil json (format "nixos-nuc:%s" remote-json))
          (with-temp-buffer
            (insert +wd/pdf-sync-python-code)
            (let ((e (call-process-region (point-min) (point-max) "ssh" nil nil nil
                                           "nixos-nuc" "python3" "-" remote-json lib id)))
              (if (zerop e) (message "Synced %s" id) (error "Sync failed")))))
      (when (file-exists-p json) (delete-file json)))))

(provide 'lib-pdf-sync)
;;; lib-pdf-sync.el ends here
