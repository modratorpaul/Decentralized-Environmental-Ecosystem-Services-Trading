;; Credit Issuance Contract
;; Creates and manages tradable ecosystem service credits

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_CREDIT_NOT_FOUND (err u301))
(define-constant ERR_INSUFFICIENT_BALANCE (err u302))
(define-constant ERR_INVALID_AMOUNT (err u303))
(define-constant ERR_SERVICE_NOT_MEASURED (err u304))

;; Data structures
(define-map credits
  { credit-id: uint }
  {
    ecosystem-id: uint,
    service-type: (string-ascii 50),
    amount: uint,
    vintage-year: uint,
    issued-to: principal,
    issued-at: uint,
    retired: bool
  }
)

(define-map credit-balances
  { owner: principal, ecosystem-id: uint, service-type: (string-ascii 50) }
  uint
)

(define-data-var next-credit-id uint u1)
(define-data-var service-quantification-contract (optional principal) none)

;; Contract setup
(define-public (set-service-quantification-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (var-set service-quantification-contract (some contract)))
  )
)

;; Credit issuance
(define-public (issue-credits
  (ecosystem-id uint)
  (service-type (string-ascii 50))
  (amount uint)
  (vintage-year uint)
  (recipient principal))
  (let ((credit-id (var-get next-credit-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    ;; Note: In a real implementation, we would verify the service measurement
    ;; For simplicity, we'll proceed with issuance

    (map-set credits
      { credit-id: credit-id }
      {
        ecosystem-id: ecosystem-id,
        service-type: service-type,
        amount: amount,
        vintage-year: vintage-year,
        issued-to: recipient,
        issued-at: block-height,
        retired: false
      }
    )

    ;; Update balance
    (let ((current-balance (default-to u0 (map-get? credit-balances
                                          { owner: recipient, ecosystem-id: ecosystem-id, service-type: service-type }))))
      (map-set credit-balances
        { owner: recipient, ecosystem-id: ecosystem-id, service-type: service-type }
        (+ current-balance amount)
      )
    )

    (var-set next-credit-id (+ credit-id u1))
    (ok credit-id)
  )
)

;; Credit transfer
(define-public (transfer-credits
  (ecosystem-id uint)
  (service-type (string-ascii 50))
  (amount uint)
  (recipient principal))
  (let ((sender-balance (default-to u0 (map-get? credit-balances
                                       { owner: tx-sender, ecosystem-id: ecosystem-id, service-type: service-type })))
        (recipient-balance (default-to u0 (map-get? credit-balances
                                          { owner: recipient, ecosystem-id: ecosystem-id, service-type: service-type }))))
    (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    ;; Update sender balance
    (map-set credit-balances
      { owner: tx-sender, ecosystem-id: ecosystem-id, service-type: service-type }
      (- sender-balance amount)
    )

    ;; Update recipient balance
    (map-set credit-balances
      { owner: recipient, ecosystem-id: ecosystem-id, service-type: service-type }
      (+ recipient-balance amount)
    )

    (ok true)
  )
)

;; Credit retirement
(define-public (retire-credits
  (ecosystem-id uint)
  (service-type (string-ascii 50))
  (amount uint))
  (let ((balance (default-to u0 (map-get? credit-balances
                                { owner: tx-sender, ecosystem-id: ecosystem-id, service-type: service-type }))))
    (asserts! (>= balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    ;; Update balance
    (map-set credit-balances
      { owner: tx-sender, ecosystem-id: ecosystem-id, service-type: service-type }
      (- balance amount)
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-credit (credit-id uint))
  (map-get? credits { credit-id: credit-id })
)

(define-read-only (get-balance (owner principal) (ecosystem-id uint) (service-type (string-ascii 50)))
  (default-to u0 (map-get? credit-balances { owner: owner, ecosystem-id: ecosystem-id, service-type: service-type }))
)

(define-read-only (get-next-credit-id)
  (var-get next-credit-id)
)
