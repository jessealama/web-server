#lang web-server/base

(require racket/match
         racket/stxparam
         "lib.rkt"
         "syntax.rkt"
         (for-syntax "lib.rkt"
                     racket/base
                     syntax/parse
                     syntax/strip-context))

(provide formlet* =>*)

(define-syntax-parameter =>*
  (λ (stx) (raise-syntax-error '=>* "Only allowed inside formlet*" stx)))

(define (snoc x l) (append l (list x)))

(struct label-formlet (p))

(define (label-formlet-answers labels formlet)
  (label-formlet
   (cross (pure (λ anss
                  (λ (answers) 
                    (for ([label (in-list labels)]
                          [ans (in-list anss)])
                      (hash-update! answers label (λ (l) (snoc ans l)) null)))))
          formlet)))

(define xexpr-forest->label-formlet
  (match-lambda
    [(list)
     (pure (λ (x) x))]
    [(list-rest xe xf)
     (cross* (pure (lambda (xe-populate-hash! xf-populate-hash!)
                     (lambda (answers)
                       (xe-populate-hash! answers)
                       (xf-populate-hash! answers))))
             (xexpr->label-formlet xe)
             (xexpr-forest->label-formlet xf))]))

(define xexpr->label-formlet
  (match-lambda
    [(#%#-mark l)
     (xexpr-forest->label-formlet l)]
    [(list (? symbol? tag) (list (list (? symbol? attr) (? string? str)) ...) xexpr ...)
     (tag-xexpr tag (map list attr str)
                (xexpr-forest->label-formlet xexpr))]
    [(list (? symbol? tag) xexpr ...)
     (tag-xexpr tag null
                (xexpr-forest->label-formlet xexpr))]
    [(label-formlet p)
     p]
    [(? string? s)
     (text s)]))

(define (label-formlet-cross handler xexpr/labeled-formlets)
  (cross (pure (λ (populate-hash!)
                 (define ht (make-hasheq))
                 (populate-hash! ht)
                 (handler ht)))
         (xexpr->label-formlet xexpr/labeled-formlets)))

(struct #%#-mark (l))
(define-syntax-rule (inner-#%# e ...) (#%#-mark (list e ...)))

(define-syntax (formlet* stx)
  (syntax-parse stx 
    [(_ q e:expr)
     (let ()
       (define label->name (make-hash))
       (define (this-=>* stx)
         (syntax-parse stx
           #:literals (values)
           [(=>* formlet:expr name:id)
            #'(=>* formlet (values name))]
           [(_ formlet:expr (values name:id ...))
            (define names (syntax->list #'(name ...)))
            (define labels (map (compose1 gensym syntax->datum) names))
            (for ([label (in-list labels)]
                  [name (in-list names)])
              (hash-set! label->name label (replace-context #'e name)))
            #`(label-formlet-answers '#,labels formlet)]))
       (define q-raw 
         (local-expand #`(syntax-parameterize ([=>* #,this-=>*]
                                               [#%# (make-rename-transformer #'inner-#%#)])
                           q)
                       'expression null))
       (with-syntax ([((label . name) ...)
                      (for/list ([(k v) (in-hash label->name)])
                        (cons k v))])
         (quasisyntax/loc stx
           (label-formlet-cross (lambda (labeled)
                                  (let ([name (hash-ref labeled 'label null)]
                                        ...)
                                    e))
                                #,q-raw))))]))
