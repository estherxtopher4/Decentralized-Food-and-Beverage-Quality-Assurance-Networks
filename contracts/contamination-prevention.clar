;; Contamination Prevention Contract
;; Prevents and manages food contamination incidents

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_ALERT_NOT_FOUND (err u401))
(define-constant ERR_INVALID_SEVERITY (err u402))

;; Severity levels
(define-constant SEVERITY_LOW u1)
(define-constant SEVERITY_MEDIUM u2)
(define-constant SEVERITY_HIGH u3)
(define-constant SEVERITY_CRITICAL u4)

;; Alert status
(define-constant ALERT_ACTIVE u1)
(define-constant ALERT_RESOLVED u2)
(define-constant ALERT_DISMISSED u3)

;; Data structures
(define-map contamination-alerts
  { alert-id: uint }
  {
    batch-id: uint,
    producer-id: uint,
    contamination-type: (string-ascii 100),
    severity: uint,
    description: (string-ascii 500),
    reported-date: uint,
    reported-by: principal,
    status: uint,
    resolution-notes: (string-ascii 500)
  }
)

(define-map prevention-measures
  { measure-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    implementation-date: uint,
    effectiveness-score: uint,
    active: bool
  }
)

(define-data-var next-alert-id uint u1)
(define-data-var next-measure-id uint u1)

;; Report contamination alert
(define-public (report-contamination
  (batch-id uint)
  (producer-id uint)
  (contamination-type (string-ascii 100))
  (severity uint)
  (description (string-ascii 500)))
  (let ((alert-id (var-get next-alert-id)))
    (asserts! (<= severity SEVERITY_CRITICAL) ERR_INVALID_SEVERITY)
    (asserts! (>= severity SEVERITY_LOW) ERR_INVALID_SEVERITY)
    (map-set contamination-alerts
      { alert-id: alert-id }
      {
        batch-id: batch-id,
        producer-id: producer-id,
        contamination-type: contamination-type,
        severity: severity,
        description: description,
        reported-date: block-height,
        reported-by: tx-sender,
        status: ALERT_ACTIVE,
        resolution-notes: ""
      }
    )
    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

;; Resolve contamination alert
(define-public (resolve-alert
  (alert-id uint)
  (resolution-notes (string-ascii 500)))
  (let ((alert-data (unwrap! (map-get? contamination-alerts { alert-id: alert-id }) ERR_ALERT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set contamination-alerts
      { alert-id: alert-id }
      (merge alert-data {
        status: ALERT_RESOLVED,
        resolution-notes: resolution-notes
      })
    )
    (ok true)
  )
)

;; Add prevention measure
(define-public (add-prevention-measure
  (name (string-ascii 100))
  (description (string-ascii 500))
  (effectiveness-score uint))
  (let ((measure-id (var-get next-measure-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set prevention-measures
      { measure-id: measure-id }
      {
        name: name,
        description: description,
        implementation-date: block-height,
        effectiveness-score: effectiveness-score,
        active: true
      }
    )
    (var-set next-measure-id (+ measure-id u1))
    (ok measure-id)
  )
)

;; Get contamination alert
(define-read-only (get-contamination-alert (alert-id uint))
  (map-get? contamination-alerts { alert-id: alert-id })
)

;; Get prevention measure
(define-read-only (get-prevention-measure (measure-id uint))
  (map-get? prevention-measures { measure-id: measure-id })
)

;; Check if batch has active contamination alerts
(define-read-only (has-active-contamination-alert (batch-id uint))
  ;; Simplified check - in real implementation would iterate through all alerts
  (is-some (map-get? contamination-alerts { alert-id: batch-id }))
)
