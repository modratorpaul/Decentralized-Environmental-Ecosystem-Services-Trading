;; Ecosystem Verification Contract
;; Validates and registers natural habitat areas

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ECOSYSTEM_EXISTS (err u101))
(define-constant ERR_ECOSYSTEM_NOT_FOUND (err u102))
(define-constant ERR_INVALID_DATA (err u103))

;; Data structures
(define-map ecosystems
  { ecosystem-id: uint }
  {
    owner: principal,
    location: (string-ascii 100),
    ecosystem-type: (string-ascii 50),
    area-hectares: uint,
    verified: bool,
    verifier: (optional principal),
    verification-date: (optional uint),
    created-at: uint
  }
)

(define-map authorized-verifiers principal bool)
(define-data-var next-ecosystem-id uint u1)

;; Authorization functions
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set authorized-verifiers verifier true))
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-delete authorized-verifiers verifier))
  )
)

;; Ecosystem registration
(define-public (register-ecosystem
  (location (string-ascii 100))
  (ecosystem-type (string-ascii 50))
  (area-hectares uint))
  (let ((ecosystem-id (var-get next-ecosystem-id)))
    (asserts! (> area-hectares u0) ERR_INVALID_DATA)
    (asserts! (is-none (map-get? ecosystems { ecosystem-id: ecosystem-id })) ERR_ECOSYSTEM_EXISTS)

    (map-set ecosystems
      { ecosystem-id: ecosystem-id }
      {
        owner: tx-sender,
        location: location,
        ecosystem-type: ecosystem-type,
        area-hectares: area-hectares,
        verified: false,
        verifier: none,
        verification-date: none,
        created-at: block-height
      }
    )

    (var-set next-ecosystem-id (+ ecosystem-id u1))
    (ok ecosystem-id)
  )
)

;; Ecosystem verification
(define-public (verify-ecosystem (ecosystem-id uint))
  (let ((ecosystem-data (unwrap! (map-get? ecosystems { ecosystem-id: ecosystem-id }) ERR_ECOSYSTEM_NOT_FOUND)))
    (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (get verified ecosystem-data)) ERR_INVALID_DATA)

    (map-set ecosystems
      { ecosystem-id: ecosystem-id }
      (merge ecosystem-data {
        verified: true,
        verifier: (some tx-sender),
        verification-date: (some block-height)
      })
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-ecosystem (ecosystem-id uint))
  (map-get? ecosystems { ecosystem-id: ecosystem-id })
)

(define-read-only (is-ecosystem-verified (ecosystem-id uint))
  (match (map-get? ecosystems { ecosystem-id: ecosystem-id })
    ecosystem-data (get verified ecosystem-data)
    false
  )
)

(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (map-get? authorized-verifiers verifier))
)

(define-read-only (get-next-ecosystem-id)
  (var-get next-ecosystem-id)
)
