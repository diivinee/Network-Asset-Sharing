;; Network Asset Sharing Contract
;; Facilitates sharing and leasing of telecommunications network assets

(define-map network-assets
  { asset-id: uint }
  {
    owner-id: uint,
    asset-type: (string-ascii 20),
    location: (string-ascii 50),
    total-capacity: uint,
    available-capacity: uint,
    sharing-enabled: bool,
    lease-rate: uint
  }
)

(define-map lease-agreements
  { agreement-id: uint }
  {
    asset-id: uint,
    lessor-id: uint,
    lessee-id: uint,
    start-block: uint,
    lease-duration: uint,
    capacity-leased: uint,
    total-cost: uint,
    active: bool
  }
)

(define-data-var next-asset-id uint u1)
(define-data-var next-agreement-id uint u1)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-ASSET-NOT-FOUND (err u301))
(define-constant ERR-INSUFFICIENT-CAPACITY (err u302))
(define-constant ERR-AGREEMENT-NOT-FOUND (err u303))
(define-constant ERR-SHARING-DISABLED (err u304))

;; Register network asset
(define-public (register-network-asset
  (asset-type (string-ascii 20))
  (location (string-ascii 50))
  (total-capacity uint)
  (lease-rate uint)
  (owner-id uint))
  (let ((asset-id (var-get next-asset-id)))
    (map-set network-assets
      { asset-id: asset-id }
      {
        owner-id: owner-id,
        asset-type: asset-type,
        location: location,
        total-capacity: total-capacity,
        available-capacity: total-capacity,
        sharing-enabled: true,
        lease-rate: lease-rate
      }
    )
    (var-set next-asset-id (+ asset-id u1))
    (ok asset-id)
  )
)

;; Create lease agreement
(define-public (create-lease-agreement
  (asset-id uint)
  (lessee-id uint)
  (lease-duration uint)
  (capacity-needed uint))
  (match (map-get? network-assets { asset-id: asset-id })
    asset-data
    (let ((agreement-id (var-get next-agreement-id))
          (total-cost (* (* (get lease-rate asset-data) capacity-needed) lease-duration)))
      (asserts! (get sharing-enabled asset-data) ERR-SHARING-DISABLED)
      (asserts! (>= (get available-capacity asset-data) capacity-needed) ERR-INSUFFICIENT-CAPACITY)

      ;; Update asset capacity
      (map-set network-assets
        { asset-id: asset-id }
        (merge asset-data {
          available-capacity: (- (get available-capacity asset-data) capacity-needed)
        })
      )

      ;; Create lease agreement
      (map-set lease-agreements
        { agreement-id: agreement-id }
        {
          asset-id: asset-id,
          lessor-id: (get owner-id asset-data),
          lessee-id: lessee-id,
          start-block: block-height,
          lease-duration: lease-duration,
          capacity-leased: capacity-needed,
          total-cost: total-cost,
          active: true
        }
      )

      (var-set next-agreement-id (+ agreement-id u1))
      (ok agreement-id)
    )
    ERR-ASSET-NOT-FOUND
  )
)

;; End lease agreement
(define-public (end-lease-agreement (agreement-id uint))
  (match (map-get? lease-agreements { agreement-id: agreement-id })
    agreement-data
    (match (map-get? network-assets { asset-id: (get asset-id agreement-data) })
      asset-data
      (begin
        ;; Restore capacity
        (map-set network-assets
          { asset-id: (get asset-id agreement-data) }
          (merge asset-data {
            available-capacity: (+ (get available-capacity asset-data) (get capacity-leased agreement-data))
          })
        )

        ;; Deactivate agreement
        (map-set lease-agreements
          { agreement-id: agreement-id }
          (merge agreement-data { active: false })
        )
        (ok true)
      )
      ERR-ASSET-NOT-FOUND
    )
    ERR-AGREEMENT-NOT-FOUND
  )
)

;; Get asset info
(define-read-only (get-network-asset (asset-id uint))
  (map-get? network-assets { asset-id: asset-id })
)

;; Get lease agreement
(define-read-only (get-lease-agreement (agreement-id uint))
  (map-get? lease-agreements { agreement-id: agreement-id })
)