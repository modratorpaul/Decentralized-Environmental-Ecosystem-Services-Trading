;; 
;; Validates ecosystem service delivery and impact

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_REPORT_NOT_FOUND (err u501))
(define-constant ERR_INVALID_DATA (err u502))
(define-constant ERR_ALREADY_VERIFIED (err u503))

;; Data structures
(define-map impact-reports
  { report-id: uint }
  {
    ecosystem-id: uint,
    service-type: (string-ascii 50),
    reporting-period: uint,
    actual-delivery: uint,
    expected-delivery: uint,
    reporter: principal,
    verified: bool,
    verifier: (optional principal),
    verification-date: (optional uint),
    created-at: uint
  }
)

(define-map authorized-impact-verifiers principal bool)
(define-data-var next-report-id uint u1)

;; Authorization functions
(define-public (add-impact-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set authorized-impact-verifiers verifier true))
  )
)

(define-public (remove-impact-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-delete authorized-impact-verifiers verifier))
  )
)

;; Impact reporting
(define-public (submit-impact-report
  (ecosystem-id uint)
  (service-type (string-ascii 50))
  (reporting-period uint)
  (actual-delivery uint)
  (expected-delivery uint))
  (let ((report-id (var-get next-report-id)))
    (asserts! (> actual-delivery u0) ERR_INVALID_DATA)
    (asserts! (> expected-delivery u0) ERR_INVALID_DATA)

    (map-set impact-reports
      { report-id: report-id }
      {
        ecosystem-id: ecosystem-id,
        service-type: service-type,
        reporting-period: reporting-period,
        actual-delivery: actual-delivery,
        expected-delivery: expected-delivery,
        reporter: tx-sender,
        verified: false,
        verifier: none,
        verification-date: none,
        created-at: block-height
      }
    )

    (var-set next-report-id (+ report-id u1))
    (ok report-id)
  )
)

;; Impact verification
(define-public (verify-impact-report (report-id uint))
  (let ((report-data (unwrap! (map-get? impact-reports { report-id: report-id }) ERR_REPORT_NOT_FOUND)))
    (asserts! (default-to false (map-get? authorized-impact-verifiers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (get verified report-data)) ERR_ALREADY_VERIFIED)

    (map-set impact-reports
      { report-id: report-id }
      (merge report-data {
        verified: true,
        verifier: (some tx-sender),
        verification-date: (some block-height)
      })
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-impact-report (report-id uint))
  (map-get? impact-reports { report-id: report-id })
)

(define-read-only (calculate-delivery-ratio (report-id uint))
  (match (map-get? impact-reports { report-id: report-id })
    report-data
      (let ((actual (get actual-delivery report-data))
            (expected (get expected-delivery report-data)))
        (if (> expected u0)
          (some (/ (* actual u100) expected))
          none
        )
      )
    none
  )
)

(define-read-only (is-authorized-impact-verifier (verifier principal))
  (default-to false (map-get? authorized-impact-verifiers verifier))
)

(define-read-only (get-next-report-id)
  (var-get next-report-id)
)
