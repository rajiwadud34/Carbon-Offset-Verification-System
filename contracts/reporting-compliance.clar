;; Reporting and Compliance Contract
;; Manages corporate sustainability reporting and regulatory compliance

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-REPORT-NOT-FOUND (err u401))
(define-constant ERR-INVALID-INPUT (err u402))
(define-constant ERR-ORGANIZATION-NOT-FOUND (err u403))
(define-constant ERR-COMPLIANCE-NOT-FOUND (err u404))
(define-constant ERR-INVALID-PERIOD (err u405))
(define-constant ERR-REPORT-ALREADY-EXISTS (err u406))
(define-constant ERR-INVALID-STATUS (err u407))
(define-constant ERR-CERTIFICATION-EXPIRED (err u408))

;; Data Variables
(define-data-var next-organization-id uint u1)
(define-data-var next-report-id uint u1)
(define-data-var next-compliance-id uint u1)
(define-data-var total-organizations uint u0)
(define-data-var total-reports uint u0)

;; Report Status Constants
(define-constant REPORT-DRAFT "draft")
(define-constant REPORT-SUBMITTED "submitted")
(define-constant REPORT-VERIFIED "verified")
(define-constant REPORT-CERTIFIED "certified")
(define-constant REPORT-REJECTED "rejected")

;; Compliance Status Constants
(define-constant COMPLIANCE-COMPLIANT "compliant")
(define-constant COMPLIANCE-NON-COMPLIANT "non-compliant")
(define-constant COMPLIANCE-PENDING "pending")
(define-constant COMPLIANCE-UNDER-REVIEW "under-review")

;; Organization Data Structure
(define-map organizations
  { organization-id: uint }
  {
    name: (string-ascii 100),
    legal-entity: (string-ascii 100),
    industry-sector: (string-ascii 50),
    country: (string-ascii 50),
    contact-person: principal,
    registration-number: (string-ascii 50),
    size-category: (string-ascii 20), ;; "small", "medium", "large"
    reporting-standards: (list 10 (string-ascii 50)),
    regulatory-requirements: (list 20 (string-ascii 100)),
    baseline-year: uint,
    baseline-emissions: uint,
    reduction-target: uint,
    target-year: uint,
    created-at: uint,
    updated-at: uint
  }
)

;; Sustainability Reports
(define-map sustainability-reports
  { report-id: uint }
  {
    organization-id: uint,
    reporting-period: uint,
    report-type: (string-ascii 50), ;; "annual", "quarterly", "project-specific"
    total-emissions: uint,
    scope1-emissions: uint,
    scope2-emissions: uint,
    scope3-emissions: uint,
    emission-reductions: uint,
    credits-purchased: uint,
    credits-retired: uint,
    net-emissions: uint,
    reduction-percentage: uint,
    methodology-used: (string-ascii 100),
    verification-standard: (string-ascii 50),
    report-hash: (string-ascii 64),
    status: (string-ascii 20),
    submitted-by: principal,
    verified-by: (optional principal),
    certification-body: (optional (string-ascii 100)),
    submission-date: uint,
    verification-date: (optional uint),
    certification-date: (optional uint),
    created-at: uint,
    updated-at: uint
  }
)

;; Compliance Records
(define-map compliance-records
  { compliance-id: uint }
  {
    organization-id: uint,
    regulation-name: (string-ascii 100),
    jurisdiction: (string-ascii 50),
    compliance-period: uint,
    required-reduction: uint,
    achieved-reduction: uint,
    compliance-gap: uint,
    offset-requirement: uint,
    offsets-applied: uint,
    status: (string-ascii 20),
    compliance-score: uint,
    penalties: uint,
    compliance-officer: principal,
    assessment-date: uint,
    next-assessment: uint,
    supporting-documents: (list 10 (string-ascii 64)),
    created-at: uint,
    updated-at: uint
  }
)

;; Regulatory Framework Definitions
(define-map regulatory-frameworks
  { framework-id: uint }
  {
    name: (string-ascii 100),
    jurisdiction: (string-ascii 50),
    description: (string-ascii 500),
    emission-threshold: uint,
    reduction-requirement: uint,
    offset-allowance: uint,
    reporting-frequency: uint, ;; in months
    penalty-rate: uint,
    effective-date: uint,
    expiry-date: (optional uint),
    created-by: principal,
    created-at: uint
  }
)

;; Sustainability Metrics Aggregation
(define-map sustainability-metrics
  { organization-id: uint, metric-period: uint }
  {
    total-projects: uint,
    active-projects: uint,
    total-credits-issued: uint,
    total-credits-retired: uint,
    average-project-efficiency: uint,
    carbon-intensity: uint,
    reduction-trajectory: uint,
    compliance-score: uint,
    sustainability-rating: uint,
    calculated-at: uint,
    valid-until: uint
  }
)

(define-data-var next-framework-id uint u1)

;; Administrative Functions

;; Register organization
(define-public (register-organization
  (name (string-ascii 100))
  (legal-entity (string-ascii 100))
  (industry-sector (string-ascii 50))
  (country (string-ascii 50))
  (registration-number (string-ascii 50))
  (size-category (string-ascii 20))
  (reporting-standards (list 10 (string-ascii 50)))
  (regulatory-requirements (list 20 (string-ascii 100)))
  (baseline-year uint)
  (baseline-emissions uint)
  (reduction-target uint)
  (target-year uint))
  (let
    (
      (organization-id (var-get next-organization-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; Input validation
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> baseline-emissions u0) ERR-INVALID-INPUT)
    (asserts! (> reduction-target u0) ERR-INVALID-INPUT)
    (asserts! (> target-year baseline-year) ERR-INVALID-PERIOD)

    ;; Create organization record
    (map-set organizations
      { organization-id: organization-id }
      {
        name: name,
        legal-entity: legal-entity,
        industry-sector: industry-sector,
        country: country,
        contact-person: tx-sender,
        registration-number: registration-number,
        size-category: size-category,
        reporting-standards: reporting-standards,
        regulatory-requirements: regulatory-requirements,
        baseline-year: baseline-year,
        baseline-emissions: baseline-emissions,
        reduction-target: reduction-target,
        target-year: target-year,
        created-at: current-time,
        updated-at: current-time
      }
    )

    ;; Update counters
    (var-set next-organization-id (+ organization-id u1))
    (var-set total-organizations (+ (var-get total-organizations) u1))

    (ok organization-id)
  )
)

;; Submit sustainability report
(define-public (submit-sustainability-report
  (organization-id uint)
  (reporting-period uint)
  (report-type (string-ascii 50))
  (total-emissions uint)
  (scope1-emissions uint)
  (scope2-emissions uint)
  (scope3-emissions uint)
  (emission-reductions uint)
  (credits-purchased uint)
  (credits-retired uint)
  (methodology-used (string-ascii 100))
  (verification-standard (string-ascii 50))
  (report-hash (string-ascii 64)))
  (let
    (
      (report-id (var-get next-report-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (organization (unwrap! (map-get? organizations { organization-id: organization-id }) ERR-ORGANIZATION-NOT-FOUND))
      (net-emissions (- total-emissions credits-retired))
      (reduction-percentage (if (> (get baseline-emissions organization) u0)
        (/ (* emission-reductions u100) (get baseline-emissions organization))
        u0))
    )
    ;; Authorization check
    (asserts! (is-eq tx-sender (get contact-person organization)) ERR-NOT-AUTHORIZED)

    ;; Input validation
    (asserts! (is-eq (+ scope1-emissions scope2-emissions scope3-emissions) total-emissions) ERR-INVALID-INPUT)
    (asserts! (>= credits-purchased credits-retired) ERR-INVALID-INPUT)
    (asserts! (> (len report-hash) u0) ERR-INVALID-INPUT)

    ;; Create report record
    (map-set sustainability-reports
      { report-id: report-id }
      {
        organization-id: organization-id,
        reporting-period: reporting-period,
        report-type: report-type,
        total-emissions: total-emissions,
        scope1-emissions: scope1-emissions,
        scope2-emissions: scope2-emissions,
        scope3-emissions: scope3-emissions,
        emission-reductions: emission-reductions,
        credits-purchased: credits-purchased,
        credits-retired: credits-retired,
        net-emissions: net-emissions,
        reduction-percentage: reduction-percentage,
        methodology-used: methodology-used,
        verification-standard: verification-standard,
        report-hash: report-hash,
        status: REPORT-SUBMITTED,
        submitted-by: tx-sender,
        verified-by: none,
        certification-body: none,
        submission-date: current-time,
        verification-date: none,
        certification-date: none,
        created-at: current-time,
        updated-at: current-time
      }
    )

    ;; Update counters
    (var-set next-report-id (+ report-id u1))
    (var-set total-reports (+ (var-get total-reports) u1))

    ;; Update sustainability metrics
    (update-sustainability-metrics organization-id reporting-period)

    (ok report-id)
  )
)

;; Verify sustainability report (only contract owner or authorized verifier)
(define-public (verify-sustainability-report
  (report-id uint)
  (verification-standard (string-ascii 50))
  (certification-body (string-ascii 100)))
  (let
    (
      (report (unwrap! (map-get? sustainability-reports { report-id: report-id }) ERR-REPORT-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; Only contract owner can verify reports
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status report) REPORT-SUBMITTED) ERR-INVALID-STATUS)

    ;; Update report status
    (map-set sustainability-reports
      { report-id: report-id }
      (merge report {
        status: REPORT-VERIFIED,
        verified-by: (some tx-sender),
        certification-body: (some certification-body),
        verification-date: (some current-time),
        updated-at: current-time
      })
    )

    (ok true)
  )
)

;; Assess compliance
(define-public (assess-compliance
  (organization-id uint)
  (regulation-name (string-ascii 100))
  (jurisdiction (string-ascii 50))
  (compliance-period uint)
  (required-reduction uint)
  (achieved-reduction uint)
  (offsets-applied uint)
  (supporting-documents (list 10 (string-ascii 64))))
  (let
    (
      (compliance-id (var-get next-compliance-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (organization (unwrap! (map-get? organizations { organization-id: organization-id }) ERR-ORGANIZATION-NOT-FOUND))
      (compliance-gap (if (>= achieved-reduction required-reduction) u0 (- required-reduction achieved-reduction)))
      (offset-requirement (if (> compliance-gap offsets-applied) (- compliance-gap offsets-applied) u0))
      (compliance-score (calculate-compliance-score required-reduction achieved-reduction offsets-applied))
      (status (if (is-eq offset-requirement u0) COMPLIANCE-COMPLIANT COMPLIANCE-NON-COMPLIANT))
    )
    ;; Only contract owner can assess compliance
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    ;; Input validation
    (asserts! (> required-reduction u0) ERR-INVALID-INPUT)
    (asserts! (> (len regulation-name) u0) ERR-INVALID-INPUT)

    ;; Create compliance record
    (map-set compliance-records
      { compliance-id: compliance-id }
      {
        organization-id: organization-id,
        regulation-name: regulation-name,
        jurisdiction: jurisdiction,
        compliance-period: compliance-period,
        required-reduction: required-reduction,
        achieved-reduction: achieved-reduction,
        compliance-gap: compliance-gap,
        offset-requirement: offset-requirement,
        offsets-applied: offsets-applied,
        status: status,
        compliance-score: compliance-score,
        penalties: (if (is-eq status COMPLIANCE-NON-COMPLIANT) (* offset-requirement u10) u0),
        compliance-officer: tx-sender,
        assessment-date: current-time,
        next-assessment: (+ current-time u31536000), ;; Next year
        supporting-documents: supporting-documents,
        created-at: current-time,
        updated-at: current-time
      }
    )

    ;; Update compliance counter
    (var-set next-compliance-id (+ compliance-id u1))

    (ok compliance-id)
  )
)

;; Create regulatory framework
(define-public (create-regulatory-framework
  (name (string-ascii 100))
  (jurisdiction (string-ascii 50))
  (description (string-ascii 500))
  (emission-threshold uint)
  (reduction-requirement uint)
  (offset-allowance uint)
  (reporting-frequency uint)
  (penalty-rate uint)
  (effective-date uint)
  (expiry-date (optional uint)))
  (let
    (
      (framework-id (var-get next-framework-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; Only contract owner can create frameworks
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    ;; Input validation
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> emission-threshold u0) ERR-INVALID-INPUT)
    (asserts! (> reduction-requirement u0) ERR-INVALID-INPUT)

    ;; Create framework record
    (map-set regulatory-frameworks
      { framework-id: framework-id }
      {
        name: name,
        jurisdiction: jurisdiction,
        description: description,
        emission-threshold: emission-threshold,
        reduction-requirement: reduction-requirement,
        offset-allowance: offset-allowance,
        reporting-frequency: reporting-frequency,
        penalty-rate: penalty-rate,
        effective-date: effective-date,
        expiry-date: expiry-date,
        created-by: tx-sender,
        created-at: current-time
      }
    )

    ;; Update framework counter
    (var-set next-framework-id (+ framework-id u1))

    (ok framework-id)
  )
)

;; Read-only Functions

;; Get organization details
(define-read-only (get-organization (organization-id uint))
  (map-get? organizations { organization-id: organization-id })
)

;; Get sustainability report
(define-read-only (get-sustainability-report (report-id uint))
  (map-get? sustainability-reports { report-id: report-id })
)

;; Get compliance record
(define-read-only (get-compliance-record (compliance-id uint))
  (map-get? compliance-records { compliance-id: compliance-id })
)

;; Get regulatory framework
(define-read-only (get-regulatory-framework (framework-id uint))
  (map-get? regulatory-frameworks { framework-id: framework-id })
)

;; Get sustainability metrics
(define-read-only (get-sustainability-metrics (organization-id uint) (metric-period uint))
  (map-get? sustainability-metrics { organization-id: organization-id, metric-period: metric-period })
)

;; Check organization compliance status
(define-read-only (check-compliance-status (organization-id uint) (regulation-name (string-ascii 100)))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; This would iterate through compliance records to find the latest status
    ;; Simplified implementation returns a default status
    (some COMPLIANCE-PENDING)
  )
)

;; Calculate organization carbon intensity
(define-read-only (calculate-carbon-intensity (organization-id uint) (reporting-period uint))
  (match (map-get? sustainability-reports { report-id: u1 }) ;; Simplified - would need proper lookup
    report
      (let
        (
          (organization (unwrap-panic (map-get? organizations { organization-id: organization-id })))
          (baseline (get baseline-emissions organization))
        )
        (if (> baseline u0)
          (some (/ (* (get total-emissions report) u100) baseline))
          none
        )
      )
    none
  )
)

;; Get compliance summary for organization
(define-read-only (get-compliance-summary (organization-id uint))
  (let
    (
      (organization (map-get? organizations { organization-id: organization-id }))
    )
    (match organization
      org
        (some {
          total-requirements: (len (get regulatory-requirements org)),
          compliant-count: u0, ;; Would calculate from compliance records
          non-compliant-count: u0,
          pending-count: u0,
          overall-score: u85 ;; Would calculate from actual compliance data
        })
      none
    )
  )
)

;; Get total statistics
(define-read-only (get-total-organizations)
  (var-get total-organizations)
)

(define-read-only (get-total-reports)
  (var-get total-reports)
)

;; Private Functions

;; Update sustainability metrics
(define-private (update-sustainability-metrics (organization-id uint) (metric-period uint))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (valid-until (+ current-time u2592000)) ;; Valid for 30 days
    )
    ;; Simplified metrics calculation
    (map-set sustainability-metrics
      { organization-id: organization-id, metric-period: metric-period }
      {
        total-projects: u5, ;; Would calculate from actual data
        active-projects: u3,
        total-credits-issued: u1000,
        total-credits-retired: u800,
        average-project-efficiency: u85,
        carbon-intensity: u75,
        reduction-trajectory: u12,
        compliance-score: u90,
        sustainability-rating: u4, ;; 1-5 scale
        calculated-at: current-time,
        valid-until: valid-until
      }
    )
    true
  )
)

;; Calculate compliance score
(define-private (calculate-compliance-score (required uint) (achieved uint) (offsets uint))
  (let
    (
      (total-reduction (+ achieved offsets))
      (score (if (> required u0)
        (/ (* total-reduction u100) required)
        u100))
    )
    (if (> score u100) u100 score)
  )
)

;; Validate reporting period
(define-private (is-valid-reporting-period (period uint))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (current-year (/ current-time u31536000)) ;; Approximate year calculation
    )
    (and (>= period u2020) (<= period (+ current-year u1)))
  )
)

;; Get next IDs
(define-read-only (get-next-organization-id)
  (var-get next-organization-id)
)

(define-read-only (get-next-report-id)
  (var-get next-report-id)
)

;; Initialize contract
(define-private (init)
  (begin
    (var-set next-organization-id u1)
    (var-set next-report-id u1)
    (var-set next-compliance-id u1)
    (var-set next-framework-id u1)
    (var-set total-organizations u0)
    (var-set total-reports u0)
    true
  )
)

;; Contract initialization
(init)
