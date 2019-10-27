#lang racket/base

(require web-server/servlet
         web-server/servlet-dispatch
         web-server/web-server)

(provide start)

(define here
  (simplify-path
   (build-path (syntax-source #'here) 'up)))

(define (hello req)
  (response/output
   (lambda (out)
     (display "success!" out))))

(define (start)
  (serve
   #:port 9111
   #:dispatch (dispatch/servlet hello)
   #:dispatch-server-connect@ (make-ssl-connect@ (build-path here "cert.pem")
                                                 (build-path here "key.pem"))))

(module+ main
  (start))