;; Carbon Credit Management Contract
;; Handles credit issuance, transfers, retirement, and ownership tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-CREDIT-NOT-FOUND (err u201))
(define-constant ERR-INVALID-INPUT (err u202))
(define-constant ERR-INSUFFICIENT-BALANCE (err u203))
(define-constant ERR-CREDIT-ALREADY-RETIRED (err u204))
(define-constant ERR-INVALID-VINTAGE (err u205))
(define-constant ERR-INVALID-QUALITY-RATING (err u206))
(define-constant ERR-PROJECT-NOT-ACTIVE (err u207))
(define-constant ERR-TRANSFER-TO-SELF (err u208))
(define-constant ERR-CREDIT-EXPIRED (err u209))

;; Data Variables
(define-data-var next-credit-id uint u1)
(define-data-var total-credits-issued uint u0)
(define-data-var total-credits-retired uint u0)
(define-data-var total-credits-active uint u0)

;; Credit Status Constants
(define-constant STATUS-ACTIVE "active")
(define-constant STATUS-RETIRED "retired")
(define-constant STATUS-EXPIRED "expired")
(define-constant STATUS-SUSPENDED "suspended")

;; Carbon Credit Data Structure
(define-map carbon-credits
  { credit-id: uint }
  {
    project-id: uint,
    owner: principal,
    original-owner: principal,
    amount: uint,
    remaining-amount: uint,
    vintage: uint,
    issuance-date: uint,
    expiry-date: uint,
    retirement-date: (optional uint),
    quality-rating: uint,
    serial-number: (string-ascii 100),
    verification-report: (string-ascii 200),
    status: (string-ascii 20),
    methodology: (string-ascii 100),
    created-at: uint,
    updated-at: uint
  }
)

;; Credit Ownership Tracking
(define-map credit-balances
  { owner: principal, project-id: uint, vintage: uint }
  { total-amount: uint, active-amount: uint, retired-amount: uint }
)

;; Credit Transfer History
(define-map credit-transfers
  { credit-id: uint, transfer-id: uint }
  {
    from: principal,
    to: principal,
    amount: uint,
    transfer-date: uint,
    reason: (string-ascii 200)
  }
)

;; Credit Retirement Records
(define-map credit-retirements
  { retirement-id: uint }
  {
    credit-id: uint,
    owner: principal,
    amount: uint,
    retirement-date: uint,
    retirement-reason: (string-ascii 200),
    beneficiary: (optional (string-ascii 100)),
    certificate-hash: (string-ascii 64)
  }
)

;; Retirement ID counter
(define-data-var next-retirement-id uint u1)
(define-data-var next-transfer-id uint u1)

;; Administrative Functions

;; Issue new carbon credits (only contract owner)
(define-public (issue-credits
  (project-id uint)
  (amount uint)
  (vintage uint)
  (quality-rating uint)
  (serial-number (string-ascii 100))
  (verification-report (string-ascii 200))
  (methodology (string-ascii 100))
  (expiry-years uint))
  (let
    (
      (credit-id (var-get next-credit-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (expiry-date (+ current-time (* expiry-years u31536000))) ;; seconds in a year
    )
    ;; Only contract owner can issue credits
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    ;; Input validation
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (and (>= quality-rating u1) (<= quality-rating u5)) ERR-INVALID-QUALITY-RATING)
    (asserts! (and (>= vintage u2020) (<= vintage u2050)) ERR-INVALID-VINTAGE)
    (asserts! (> (len serial-number) u0) ERR-INVALID-INPUT)
    (asserts! (> expiry-years u0) ERR-INVALID-INPUT)

    ;; Create credit record
    (map-set carbon-credits
      { credit-id: credit-id }
      {
        project-id: project-id,
        owner: tx-sender,
        original-owner: tx-sender,
        amount: amount,
        remaining-amount: amount,
        vintage: vintage,
        issuance-date: current-time,
        expiry-date: expiry-date,
        retirement-date: none,
        quality-rating: quality-rating,
        serial-number: serial-number,
        verification-report: verification-report,
        status: STATUS-ACTIVE,
        methodology: methodology,
        created-at: current-time,
        updated-at: current-time
      }
    )

    ;; Update owner balance
    (update-credit-balance tx-sender project-id vintage amount u0)

    ;; Update counters
    (var-set next-credit-id (+ credit-id u1))
    (var-set total-credits-issued (+ (var-get total-credits-issued) amount))
    (var-set total-credits-active (+ (var-get total-credits-active) amount))

    (ok credit-id)
  )
)

;; Transfer credits to another owner
(define-public (transfer-credits
  (credit-id uint)
  (to principal)
  (amount uint)
  (reason (string-ascii 200)))
  (let
    (
      (credit (unwrap! (map-get? carbon-credits { credit-id: credit-id }) ERR-CREDIT-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (transfer-id (var-get next-transfer-id))
    )
    ;; Authorization and validation
    (asserts! (is-eq tx-sender (get owner credit)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq tx-sender to)) ERR-TRANSFER-TO-SELF)
    (asserts! (is-eq (get status credit) STATUS-ACTIVE) ERR-CREDIT-ALREADY-RETIRED)
    (asserts! (>= (get remaining-amount credit) amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (< current-time (get expiry-date credit)) ERR-CREDIT-EXPIRED)

    ;; Update credit ownership
    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit {
        owner: to,
        remaining-amount: (- (get remaining-amount credit) amount),
        updated-at: current-time
      })
    )

    ;; Create new credit for recipient if partial transfer
    (if (> (get remaining-amount credit) amount)
      (let
        (
          (new-credit-id (var-get next-credit-id))
        )
        (map-set carbon-credits
          { credit-id: new-credit-id }
          (merge credit {
            owner: to,
            amount: amount,
            remaining-amount: amount,
            created-at: current-time,
            updated-at: current-time
          })
        )
        (var-set next-credit-id (+ new-credit-id u1))
        true
      )
      true
    )

    ;; Record transfer
    (map-set credit-transfers
      { credit-id: credit-id, transfer-id: transfer-id }
      {
        from: tx-sender,
        to: to,
        amount: amount,
        transfer-date: current-time,
        reason: reason
      }
    )

    ;; Update balances
    (update-credit-balance tx-sender (get project-id credit) (get vintage credit) u0 amount)
    (update-credit-balance to (get project-id credit) (get vintage credit) amount u0)

    (var-set next-transfer-id (+ transfer-id u1))
    (ok true)
  )
)

;; Retire credits for offset claims
(define-public (retire-credits
  (credit-id uint)
  (amount uint)
  (retirement-reason (string-ascii 200))
  (beneficiary (optional (string-ascii 100))))
  (let
    (
      (credit (unwrap! (map-get? carbon-credits { credit-id: credit-id }) ERR-CREDIT-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (retirement-id (var-get next-retirement-id))
      (certificate-hash (generate-certificate-hash credit-id amount current-time))
    )
    ;; Authorization and validation
    (asserts! (is-eq tx-sender (get owner credit)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status credit) STATUS-ACTIVE) ERR-CREDIT-ALREADY-RETIRED)
    (asserts! (>= (get remaining-amount credit) amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (< current-time (get expiry-date credit)) ERR-CREDIT-EXPIRED)

    ;; Update credit status
    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit {
        remaining-amount: (- (get remaining-amount credit) amount),
        status: (if (is-eq (- (get remaining-amount credit) amount) u0) STATUS-RETIRED STATUS-ACTIVE),
        retirement-date: (if (is-eq (- (get remaining-amount credit) amount) u0) (some current-time) none),
        updated-at: current-time
      })
    )

    ;; Record retirement
    (map-set credit-retirements
      { retirement-id: retirement-id }
      {
        credit-id: credit-id,
        owner: tx-sender,
        amount: amount,
        retirement-date: current-time,
        retirement-reason: retirement-reason,
        beneficiary: beneficiary,
        certificate-hash: certificate-hash
      }
    )

    ;; Update balances and counters
    (update-credit-balance tx-sender (get project-id credit) (get vintage credit) u0 amount)
    (var-set total-credits-retired (+ (var-get total-credits-retired) amount))
    (var-set total-credits-active (- (var-get total-credits-active) amount))
    (var-set next-retirement-id (+ retirement-id u1))

    (ok retirement-id)
  )
)

;; Suspend credits (only contract owner)
(define-public (suspend-credits (credit-id uint) (reason (string-ascii 200)))
  (let
    (
      (credit (unwrap! (map-get? carbon-credits { credit-id: credit-id }) ERR-CREDIT-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; Only contract owner can suspend
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status credit) STATUS-ACTIVE) ERR-INVALID-INPUT)

    ;; Update status
    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit {
        status: STATUS-SUSPENDED,
        updated-at: current-time
      })
    )

    (ok true)
  )
)

;; Reactivate suspended credits (only contract owner)
(define-public (reactivate-credits (credit-id uint))
  (let
    (
      (credit (unwrap! (map-get? carbon-credits { credit-id: credit-id }) ERR-CREDIT-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; Only contract owner can reactivate
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status credit) STATUS-SUSPENDED) ERR-INVALID-INPUT)
    (asserts! (< current-time (get expiry-date credit)) ERR-CREDIT-EXPIRED)

    ;; Update status
    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit {
        status: STATUS-ACTIVE,
        updated-at: current-time
      })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get credit details
(define-read-only (get-credit (credit-id uint))
  (map-get? carbon-credits { credit-id: credit-id })
)

;; Get credit balance for owner
(define-read-only (get-credit-balance (owner principal) (project-id uint) (vintage uint))
  (map-get? credit-balances { owner: owner, project-id: project-id, vintage: vintage })
)

;; Get transfer history
(define-read-only (get-transfer-history (credit-id uint) (transfer-id uint))
  (map-get? credit-transfers { credit-id: credit-id, transfer-id: transfer-id })
)

;; Get retirement record
(define-read-only (get-retirement-record (retirement-id uint))
  (map-get? credit-retirements { retirement-id: retirement-id })
)

;; Get total statistics
(define-read-only (get-total-credits-issued)
  (var-get total-credits-issued)
)

(define-read-only (get-total-credits-retired)
  (var-get total-credits-retired)
)

(define-read-only (get-total-credits-active)
  (var-get total-credits-active)
)

;; Check if credit is active and valid
(define-read-only (is-credit-valid (credit-id uint))
  (match (map-get? carbon-credits { credit-id: credit-id })
    credit
      (and
        (is-eq (get status credit) STATUS-ACTIVE)
        (> (get remaining-amount credit) u0)
        (< (unwrap-panic (get-block-info? time (- block-height u1))) (get expiry-date credit))
      )
    false
  )
)

;; Get credit owner
(define-read-only (get-credit-owner (credit-id uint))
  (match (map-get? carbon-credits { credit-id: credit-id })
    credit (some (get owner credit))
    none
  )
)

;; Calculate credit value based on quality and vintage
(define-read-only (calculate-credit-value (credit-id uint) (base-price uint))
  (match (map-get? carbon-credits { credit-id: credit-id })
    credit
      (let
        (
          (quality-multiplier (get-quality-multiplier (get quality-rating credit)))
          (vintage-multiplier (get-vintage-multiplier (get vintage credit)))
        )
        (some (/ (* (* base-price quality-multiplier) vintage-multiplier) u10000))
      )
    none
  )
)

;; Private Functions

;; Update credit balance for owner
(define-private (update-credit-balance
  (owner principal)
  (project-id uint)
  (vintage uint)
  (add-active uint)
  (add-retired uint))
  (let
    (
      (current-balance (default-to
        { total-amount: u0, active-amount: u0, retired-amount: u0 }
        (map-get? credit-balances { owner: owner, project-id: project-id, vintage: vintage })))
    )
    (map-set credit-balances
      { owner: owner, project-id: project-id, vintage: vintage }
      {
        total-amount: (+ (get total-amount current-balance) add-active add-retired),
        active-amount: (+ (get active-amount current-balance) add-active),
        retired-amount: (+ (get retired-amount current-balance) add-retired)
      }
    )
  )
)

;; Generate certificate hash for retirement
(define-private (generate-certificate-hash (credit-id uint) (amount uint) (timestamp uint))
  ;; Simple hash generation - in production would use proper cryptographic hash
  (int-to-ascii (+ (* credit-id u1000000) (* amount u1000) timestamp))
)

;; Get quality rating multiplier (1-5 scale to percentage)
(define-private (get-quality-multiplier (rating uint))
  (if (is-eq rating u5) u120
    (if (is-eq rating u4) u110
      (if (is-eq rating u3) u100
        (if (is-eq rating u2) u90
          u80))))
)

;; Get vintage multiplier (newer vintages worth more)
(define-private (get-vintage-multiplier (vintage uint))
  (let
    (
      (current-year u2024) ;; Would be dynamic in production
      (age (- current-year vintage))
    )
    (if (<= age u2) u110
      (if (<= age u5) u100
        (if (<= age u10) u95
          u90)))
  )
)

;; Get next credit ID
(define-read-only (get-next-credit-id)
  (var-get next-credit-id)
)

;; Initialize contract
(define-private (init)
  (begin
    (var-set next-credit-id u1)
    (var-set total-credits-issued u0)
    (var-set total-credits-retired u0)
    (var-set total-credits-active u0)
    (var-set next-retirement-id u1)
    (var-set next-transfer-id u1)
    true
  )
)

;; Contract initialization
(init)
