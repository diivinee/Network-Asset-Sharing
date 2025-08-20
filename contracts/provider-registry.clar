;; Provider Registry Contract
;; Manages registration and verification of network service providers

(define-map network-providers
  { provider-id: uint }
  {
    company-name: (string-ascii 50),
    license-number: (string-ascii 20),
    verified: bool,
    registration-block: uint,
    trust-score: uint
  }
)

(define-map provider-principals
  { owner: principal }
  { provider-id: uint }
)

(define-data-var next-provider-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROVIDER-EXISTS (err u101))
(define-constant ERR-PROVIDER-NOT-FOUND (err u102))
(define-constant ERR-INVALID-SCORE (err u103))

;; Register new provider
(define-public (register-provider (company-name (string-ascii 50)) (license-number (string-ascii 20)))
  (let ((provider-id (var-get next-provider-id)))
    (asserts! (is-none (map-get? provider-principals { owner: tx-sender })) ERR-PROVIDER-EXISTS)
    (map-set network-providers
      { provider-id: provider-id }
      {
        company-name: company-name,
        license-number: license-number,
        verified: false,
        registration-block: block-height,
        trust-score: u50
      }
    )
    (map-set provider-principals { owner: tx-sender } { provider-id: provider-id })
    (var-set next-provider-id (+ provider-id u1))
    (ok provider-id)
  )
)

;; Verify provider (contract owner only)
(define-public (verify-provider (provider-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (match (map-get? network-providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set network-providers
          { provider-id: provider-id }
          (merge provider-data { verified: true })
        )
        (ok true)
      )
      ERR-PROVIDER-NOT-FOUND
    )
  )
)

;; Update trust score
(define-public (update-trust-score (provider-id uint) (new-score uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-score u100) ERR-INVALID-SCORE)
    (match (map-get? network-providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set network-providers
          { provider-id: provider-id }
          (merge provider-data { trust-score: new-score })
        )
        (ok true)
      )
      ERR-PROVIDER-NOT-FOUND
    )
  )
)

;; Get provider info
(define-read-only (get-provider (provider-id uint))
  (map-get? network-providers { provider-id: provider-id })
)

;; Get provider by principal
(define-read-only (get-provider-by-principal (owner principal))
  (map-get? provider-principals { owner: owner })
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-id uint))
  (match (map-get? network-providers { provider-id: provider-id })
    provider-data (get verified provider-data)
    false
  )
)