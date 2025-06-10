;; Batch Tracking Contract
;; Tracks food production batches throughout the supply chain

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_BATCH_NOT_FOUND (err u301))
(define-constant ERR_INVALID_STATUS (err u302))
(define-constant ERR_PRODUCER_NOT_VERIFIED (err u303))

;; Batch status constants
(define-constant STATUS_CREATED u0)
(define-constant STATUS_PROCESSING u1)
(define-constant STATUS_QUALITY_TESTED u2)
(define-constant STATUS_APPROVED u3)
(define-constant STATUS_SHIPPED u4)
(define-constant STATUS_DELIVERED u5)
(define-constant STATUS_RECALLED u6)

;; Data structures
(define-map batches
  { batch-id: uint }
  {
    producer-id: uint,
    product-name: (string-ascii 100),
    production-date: uint,
    expiry-date: uint,
    quantity: uint,
    status: uint,
    location: (string-ascii 200),
    created-by: principal
  }
)

(define-map batch-history
  { batch-id: uint, sequence: uint }
  {
    timestamp: uint,
    status: uint,
    location: (string-ascii 200),
    updated-by: principal,
    notes: (string-ascii 300)
  }
)

(define-map batch-sequence-counter
  { batch-id: uint }
  { count: uint }
)

(define-data-var next-batch-id uint u1)

;; Create a new batch
(define-public (create-batch
  (producer-id uint)
  (product-name (string-ascii 100))
  (expiry-blocks uint)
  (quantity uint)
  (location (string-ascii 200)))
  (let ((batch-id (var-get next-batch-id)))
    ;; Simplified producer verification
    (asserts! (> producer-id u0) ERR_PRODUCER_NOT_VERIFIED)
    (map-set batches
      { batch-id: batch-id }
      {
        producer-id: producer-id,
        product-name: product-name,
        production-date: block-height,
        expiry-date: (+ block-height expiry-blocks),
        quantity: quantity,
        status: STATUS_CREATED,
        location: location,
        created-by: tx-sender
      }
    )
    (map-set batch-sequence-counter
      { batch-id: batch-id }
      { count: u0 }
    )
    ;; Record initial history entry
    (unwrap-panic (add-batch-history batch-id STATUS_CREATED location "Batch created"))
    (var-set next-batch-id (+ batch-id u1))
    (ok batch-id)
  )
)

;; Update batch status
(define-public (update-batch-status
  (batch-id uint)
  (new-status uint)
  (location (string-ascii 200))
  (notes (string-ascii 300)))
  (let ((batch-data (unwrap! (map-get? batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND)))
    (asserts! (<= new-status STATUS_RECALLED) ERR_INVALID_STATUS)
    (map-set batches
      { batch-id: batch-id }
      (merge batch-data {
        status: new-status,
        location: location
      })
    )
    (unwrap-panic (add-batch-history batch-id new-status location notes))
    (ok true)
  )
)

;; Add batch history entry
(define-private (add-batch-history
  (batch-id uint)
  (status uint)
  (location (string-ascii 200))
  (notes (string-ascii 300)))
  (let ((counter-data (unwrap! (map-get? batch-sequence-counter { batch-id: batch-id }) ERR_BATCH_NOT_FOUND))
        (sequence (+ (get count counter-data) u1)))
    (map-set batch-history
      { batch-id: batch-id, sequence: sequence }
      {
        timestamp: block-height,
        status: status,
        location: location,
        updated-by: tx-sender,
        notes: notes
      }
    )
    (map-set batch-sequence-counter
      { batch-id: batch-id }
      { count: sequence }
    )
    (ok sequence)
  )
)

;; Get batch information
(define-read-only (get-batch (batch-id uint))
  (map-get? batches { batch-id: batch-id })
)

;; Get batch history entry
(define-read-only (get-batch-history (batch-id uint) (sequence uint))
  (map-get? batch-history { batch-id: batch-id, sequence: sequence })
)

;; Get batch history count
(define-read-only (get-batch-history-count (batch-id uint))
  (map-get? batch-sequence-counter { batch-id: batch-id })
)
