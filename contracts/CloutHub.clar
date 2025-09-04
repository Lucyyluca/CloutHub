;; CloutHub - Reputation-based Social Platform
;; A comprehensive smart contract for managing user reputation, achievements, and marketplace services

;; =============================================================================
;; CONSTANTS
;; =============================================================================

(define-constant ERR_NOT_AUTHORIZED u201)
(define-constant ERR_INVALID_AMOUNT u202)
(define-constant ERR_USER_NOT_FOUND u203)
(define-constant ERR_ACHIEVEMENT_EXISTS u204)
(define-constant ERR_ACHIEVEMENT_NOT_FOUND u205)
(define-constant ERR_ALREADY_EARNED u206)
(define-constant ERR_INSUFFICIENT_REPUTATION u207)
(define-constant ERR_INVALID_DELEGATION u208)
(define-constant ERR_SELF_DELEGATION u209)
(define-constant ERR_PROPOSAL_NOT_FOUND u210)
(define-constant ERR_VOTING_ENDED u211)
(define-constant ERR_ALREADY_VOTED u212)
(define-constant ERR_PROPOSAL_ACTIVE u213)
(define-constant ERR_SERVICE_NOT_FOUND u214)
(define-constant ERR_SERVICE_INACTIVE u215)
(define-constant ERR_INSUFFICIENT_CATEGORY_REP u216)
(define-constant ERR_ALREADY_IN_PROGRAM u217)
(define-constant ERR_NOT_IN_PROGRAM u218)
(define-constant ERR_PROGRAM_EXPIRED u219)
(define-constant ERR_INVALID_MENTOR u220)
(define-constant ERR_INVALID_INPUT u221)
(define-constant ERR_STRING_TOO_LONG u222)
(define-constant ERR_INVALID_PRINCIPAL u223)
(define-constant ERR_SYSTEM_PAUSED u224)
(define-constant ERR_EMERGENCY_MODE u225)
(define-constant ERR_OWNER_ONLY u226)
(define-constant ERR_CRITICAL_OPERATION u227)
(define-constant ERR_EMERGENCY_TIMEOUT u228)
(define-constant ERR_MAX_EMERGENCY_ACTIONS u229)

;; Permission bitmasks
(define-constant PERM_AWARD_POINTS u1)
(define-constant PERM_MANAGE_ACHIEVEMENTS u2)
(define-constant PERM_MANAGE_ADMINS u4)
(define-constant PERM_SYSTEM_CONFIG u8)
(define-constant PERM_MANAGE_SERVICES u16)
(define-constant PERM_MANAGE_REHABILITATION u32)

;; Categories
(define-constant CAT_TECHNICAL "technical")
(define-constant CAT_COMMUNITY "community")
(define-constant CAT_GOVERNANCE "governance")
(define-constant CAT_CREATIVITY "creativity")

;; Service status
(define-constant STATUS_ACTIVE "active")
(define-constant STATUS_COMPLETED "completed")
(define-constant STATUS_EXPIRED "expired")

;; Validation constants
(define-constant MAX_STRING_LENGTH u500)
(define-constant MAX_REPUTATION_POINTS u1000000)
(define-constant MIN_REPUTATION_POINTS u0)
(define-constant MAX_PERMISSIONS u63)
(define-constant MAX_REQUIREMENTS u1000000)

;; Emergency constants
(define-constant EMERGENCY_TIMEOUT u1008) ;; ~1 week in blocks
(define-constant MAX_EMERGENCY_ACTIONS u10)

;; =============================================================================
;; INPUT VALIDATION FUNCTIONS
;; =============================================================================

(define-private (validate-principal (user principal))
  (not (is-eq user 'SP000000000000000000002Q6VF78))
)

(define-private (validate-string-length (str (string-ascii 500)))
  (<= (len str) MAX_STRING_LENGTH)
)

(define-private (validate-reputation-amount (amount uint))
  (and 
    (>= amount MIN_REPUTATION_POINTS)
    (<= amount MAX_REPUTATION_POINTS)
  )
)

(define-private (validate-permissions (permissions uint))
  (<= permissions MAX_PERMISSIONS)
)

(define-private (validate-requirements (requirements uint))
  (<= requirements MAX_REQUIREMENTS)
)

(define-private (validate-non-zero (value uint))
  (> value u0)
)

(define-private (sanitize-uint (value uint))
  (if (<= value MAX_REPUTATION_POINTS) value u0)
)

(define-private (validate-category-string (category (string-ascii 20)))
  (or 
    (is-eq category CAT_TECHNICAL)
    (is-eq category CAT_COMMUNITY)
    (is-eq category CAT_GOVERNANCE)
    (is-eq category CAT_CREATIVITY)
  )
)

;; Helper function to truncate strings for record-history
(define-private (truncate-reason (reason (string-ascii 200)))
  (if (<= (len reason) u100)
    (unwrap-panic (as-max-len? reason u100))
    (unwrap-panic (as-max-len? (unwrap-panic (slice? reason u0 u100)) u100))
  )
)

;; =============================================================================
;; EMERGENCY SAFETY CONTROLS
;; =============================================================================

(define-private (assert-not-paused)
  (begin
    (asserts! (is-eq (var-get paused) false) (err ERR_SYSTEM_PAUSED))
    (ok true)
  )
)

(define-private (assert-not-emergency)
  (begin
    (asserts! (is-eq (var-get emergency-mode) false) (err ERR_EMERGENCY_MODE))
    (ok true)
  )
)

(define-private (assert-owner-only)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_OWNER_ONLY))
    (ok true)
  )
)

(define-private (assert-critical-operation-allowed)
  (begin
    (try! (assert-not-paused))
    (try! (assert-not-emergency))
    (ok true)
  )
)

(define-private (is-emergency-admin (admin principal))
  (or 
    (is-eq admin (var-get contract-owner))
    (is-eq admin (var-get emergency-admin))
  )
)

(define-private (check-emergency-timeout)
  (let (
    (activated-at (var-get emergency-activated-at))
  )
    (if (and (> activated-at u0) 
             (> (- stacks-block-height activated-at) EMERGENCY_TIMEOUT))
      (begin
        (var-set emergency-mode false)
        (var-set emergency-activated-at u0)
        true
      )
      true
    )
  )
)

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

;; Core reputation data with timestamp tracking
(define-map reputations 
  { user: principal } 
  { 
    total-score: uint,
    last-updated: uint,
    category-scores: { technical: uint, community: uint, governance: uint, creativity: uint },
    spent-reputation: uint ;; Track reputation spent on services
  }
)

;; Admin system with roles and permissions
(define-map admin-roles 
  { admin: principal } 
  { 
    role: (string-ascii 20),
    permissions: uint, ;; bitmask for permissions
    appointed-at: uint,
    appointed-by: principal
  }
)

;; Achievement system
(define-map achievements
  { achievement-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    points-reward: uint,
    category: (string-ascii 20),
    requirements: uint, ;; encoded requirements
    is-active: bool
  }
)

;; User achievements tracking
(define-map user-achievements
  { user: principal, achievement-id: uint }
  { earned-at: uint, points-awarded: uint }
)

;; Delegation system - users can delegate voting power
(define-map delegations
  { delegator: principal }
  { delegate: principal, delegated-at: uint, voting-power: uint }
)

;; Reputation history for transparency
(define-map reputation-history
  { user: principal, entry-id: uint }
  {
    action: (string-ascii 30),
    points-change: int,
    category: (string-ascii 20),
    timestamp: uint,
    awarded-by: principal,
    reason: (string-ascii 100)
  }
)

;; Governance proposals
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposer: principal,
    created-at: uint,
    voting-ends-at: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool,
    proposal-type: (string-ascii 20)
  }
)

;; Proposal votes tracking
(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint, voted-at: uint }
)

;; Marketplace services
(define-map marketplace-services
  { service-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    reputation-cost: uint,
    category-requirements: { technical: uint, community: uint, governance: uint, creativity: uint },
    provider: principal,
    is-active: bool,
    created-at: uint,
    usage-count: uint
  }
)

;; Service purchases tracking
(define-map service-purchases
  { user: principal, service-id: uint, purchase-id: uint }
  {
    purchased-at: uint,
    reputation-spent: uint,
    status: (string-ascii 20) ;; "active", "completed", "expired"
  }
)

;; User service access
(define-map user-service-access
  { user: principal }
  {
    active-services: (list 10 uint),
    total-spent: uint,
    last-purchase: uint
  }
)

;; Rehabilitation programs
(define-map rehabilitation-programs
  { user: principal }
  {
    program-type: (string-ascii 30),
    start-block: uint,
    end-block: uint,
    required-actions: uint,
    completed-actions: uint,
    mentor: (optional principal),
    recovery-multiplier: uint,
    is-active: bool,
    penalty-reason: (string-ascii 100)
  }
)

;; Penalty tracking
(define-map user-penalties
  { user: principal, penalty-id: uint }
  {
    penalty-type: (string-ascii 30),
    points-deducted: uint,
    issued-at: uint,
    issued-by: principal,
    reason: (string-ascii 100),
    rehabilitation-eligible: bool
  }
)

;; Mentorship relationships
(define-map mentorship-relationships
  { mentor: principal, mentee: principal }
  {
    started-at: uint,
    program-type: (string-ascii 30),
    progress-score: uint,
    is-active: bool
  }
)

;; Emergency action tracking
(define-map emergency-actions
  { action-id: uint }
  {
    action-type: (string-ascii 30),
    executed-by: principal,
    executed-at: uint,
    reason: (string-ascii 200),
    affected-users: (list 10 principal)
  }
)

;; =============================================================================
;; DATA VARIABLES
;; =============================================================================

(define-data-var contract-owner principal tx-sender)
(define-data-var emergency-admin principal tx-sender)
(define-data-var admins (list 20 principal) (list tx-sender))
(define-data-var next-achievement-id uint u1)
(define-data-var next-history-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-service-id uint u1)
(define-data-var next-penalty-id uint u1)
(define-data-var next-purchase-id uint u1)
(define-data-var next-emergency-action-id uint u1)

;; Emergency controls
(define-data-var paused bool false)
(define-data-var emergency-mode bool false)
(define-data-var emergency-activated-at uint u0)
(define-data-var emergency-actions-count uint u0)

;; Reputation decay settings
(define-data-var decay-rate uint u5) ;; 5% per period
(define-data-var decay-period uint u144) ;; ~1 day in blocks (assuming 10min blocks)
(define-data-var min-reputation uint u10) ;; minimum reputation floor

;; Governance settings
(define-data-var proposal-threshold uint u100) ;; min reputation to create proposals
(define-data-var voting-period uint u1008) ;; ~1 week in blocks

;; Marketplace settings
(define-data-var marketplace-fee-rate uint u5) ;; 5% fee on services
(define-data-var min-service-cost uint u50) ;; minimum reputation cost for services

;; Rehabilitation settings
(define-data-var rehabilitation-period uint u4032) ;; ~4 weeks in blocks
(define-data-var mentor-bonus-rate uint u10) ;; 10% bonus for successful mentoring

;; Admin being removed (for filter function)
(define-data-var admin-to-remove principal 'SP000000000000000000002Q6VF78)

;; =============================================================================
;; UTILITY FUNCTIONS
;; =============================================================================

(define-private (max-uint (a uint) (b uint))
  (if (> a b) a b)
)

(define-private (min-uint (a uint) (b uint))
  (if (< a b) a b)
)

;; =============================================================================
;; EMERGENCY MANAGEMENT FUNCTIONS
;; =============================================================================

(define-public (pause-contract)
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (has-permission tx-sender PERM_SYSTEM_CONFIG)) (err ERR_NOT_AUTHORIZED))
    (var-set paused true)
    (unwrap-panic (record-emergency-action "contract-paused" "System paused for maintenance or security" (list)))
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (has-permission tx-sender PERM_SYSTEM_CONFIG)) (err ERR_NOT_AUTHORIZED))
    (var-set paused false)
    (unwrap-panic (record-emergency-action "contract-unpaused" "System resumed normal operations" (list)))
    (ok true)
  )
)

(define-public (activate-emergency-mode (reason (string-ascii 200)))
  (begin
    (asserts! (validate-string-length reason) (err ERR_STRING_TOO_LONG))
    (asserts! (is-emergency-admin tx-sender) (err ERR_NOT_AUTHORIZED))
    (var-set emergency-mode true)
    (var-set emergency-activated-at stacks-block-height)
    (var-set emergency-actions-count u0)
    (unwrap-panic (record-emergency-action "emergency-activated" reason (list)))
    (ok true)
  )
)

(define-public (deactivate-emergency-mode)
  (begin
    (asserts! (is-emergency-admin tx-sender) (err ERR_NOT_AUTHORIZED))
    (var-set emergency-mode false)
    (var-set emergency-activated-at u0)
    (unwrap-panic (record-emergency-action "emergency-deactivated" "Emergency mode deactivated" (list)))
    (ok true)
  )
)

(define-public (set-emergency-admin (new-emergency-admin principal))
  (begin
    (try! (assert-owner-only))
    (asserts! (validate-principal new-emergency-admin) (err ERR_INVALID_PRINCIPAL))
    (var-set emergency-admin new-emergency-admin)
    (unwrap-panic (record-emergency-action "emergency-admin-changed" "Emergency admin updated" (list new-emergency-admin)))
    (ok true)
  )
)

(define-public (emergency-reputation-reset (user principal) (reason (string-ascii 200)))
  (begin
    (asserts! (validate-principal user) (err ERR_INVALID_PRINCIPAL))
    (asserts! (validate-string-length reason) (err ERR_STRING_TOO_LONG))
    (asserts! (is-emergency-admin tx-sender) (err ERR_NOT_AUTHORIZED))
    (asserts! (var-get emergency-mode) (err ERR_EMERGENCY_MODE))
    (asserts! (< (var-get emergency-actions-count) MAX_EMERGENCY_ACTIONS) (err ERR_MAX_EMERGENCY_ACTIONS))
    
    ;; Reset user reputation to minimum
    (map-set reputations
      { user: user }
      {
        total-score: (var-get min-reputation),
        last-updated: stacks-block-height,
        category-scores: { technical: u0, community: u0, governance: u0, creativity: u0 },
        spent-reputation: u0
      }
    )
    
    (var-set emergency-actions-count (+ (var-get emergency-actions-count) u1))
    (unwrap-panic (record-emergency-action "reputation-reset" reason (list user)))
    ;; Truncate reason to fit record-history parameter type
    (record-history user "emergency-reset" (to-int (- u0 (var-get min-reputation))) "system" (truncate-reason reason))
    (ok true)
  )
)

(define-private (record-emergency-action (action-type (string-ascii 30)) (reason (string-ascii 200)) (affected-users (list 10 principal)))
  (let (
    (action-id (var-get next-emergency-action-id))
  )
    (map-set emergency-actions
      { action-id: action-id }
      {
        action-type: action-type,
        executed-by: tx-sender,
        executed-at: stacks-block-height,
        reason: reason,
        affected-users: affected-users
      }
    )
    (var-set next-emergency-action-id (+ action-id u1))
    (ok true)
  )
)

;; =============================================================================
;; PRIVATE FUNCTIONS
;; =============================================================================

(define-private (has-permission (admin principal) (permission uint))
  (begin
    (asserts! (validate-principal admin) false)
    (asserts! (validate-permissions permission) false)
    (match (map-get? admin-roles { admin: admin })
      admin-data (> (bit-and (get permissions admin-data) permission) u0)
      false
    )
  )
)

(define-private (apply-decay (current-score uint) (last-updated uint))
  (let (
    (sanitized-score (sanitize-uint current-score))
    (sanitized-updated (if (> last-updated stacks-block-height) stacks-block-height last-updated))
    (blocks-passed (- stacks-block-height sanitized-updated))
    (decay-periods (/ blocks-passed (var-get decay-period)))
  )
    (if (> decay-periods u0)
      (let (
        (decay-factor (pow u95 decay-periods)) ;; 95% retention per period
        (decayed-score (/ (* sanitized-score decay-factor) (pow u100 decay-periods)))
      )
        (max-uint decayed-score (var-get min-reputation))
      )
      sanitized-score
    )
  )
)

(define-private (record-history (user principal) (action (string-ascii 30)) (points-change int) (category (string-ascii 20)) (reason (string-ascii 100)))
  (begin
    (asserts! (validate-principal user) false)
    (asserts! (validate-string-length action) false)
    (asserts! (validate-category-string category) false)
    (asserts! (validate-string-length reason) false)
    (let (
      (history-id (var-get next-history-id))
    )
      (map-set reputation-history
        { user: user, entry-id: history-id }
        {
          action: action,
          points-change: points-change,
          category: category,
          timestamp: stacks-block-height,
          awarded-by: tx-sender,
          reason: reason
        }
      )
      (var-set next-history-id (+ history-id u1))
      true
    )
  )
)

;; Returns the user's current (possibly decayed) reputation score
(define-private (get-current-reputation (user principal))
  (begin
    (asserts! (validate-principal user) u0)
    (let (
      (current-rep (default-to 
        { total-score: u0, last-updated: stacks-block-height, category-scores: { technical: u0, community: u0, governance: u0, creativity: u0 }, spent-reputation: u0 }
        (map-get? reputations { user: user })
      ))
    )
      (apply-decay (get total-score current-rep) (get last-updated current-rep))
    )
  )
)

;; Check if user meets category requirements
(define-private (meets-category-requirements (user principal) (requirements { technical: uint, community: uint, governance: uint, creativity: uint }))
  (begin
    (asserts! (validate-principal user) false)
    (asserts! (validate-reputation-amount (get technical requirements)) false)
    (asserts! (validate-reputation-amount (get community requirements)) false)
    (asserts! (validate-reputation-amount (get governance requirements)) false)
    (asserts! (validate-reputation-amount (get creativity requirements)) false)
    (let (
      (user-rep (default-to 
        { total-score: u0, last-updated: stacks-block-height, category-scores: { technical: u0, community: u0, governance: u0, creativity: u0 }, spent-reputation: u0 }
        (map-get? reputations { user: user })
      ))
      (user-categories (get category-scores user-rep))
    )
      (and
        (>= (get technical user-categories) (get technical requirements))
        (>= (get community user-categories) (get community requirements))
        (>= (get governance user-categories) (get governance requirements))
        (>= (get creativity user-categories) (get creativity requirements))
      )
    )
  )
)

;; Fixed filter function for admin removal
(define-private (is-not-target-admin (admin principal))
  (not (is-eq admin (var-get admin-to-remove)))
)

;; Apply rehabilitation multiplier without circular dependency
(define-private (apply-rehabilitation-multiplier (user principal) (points uint))
  (begin
    (asserts! (validate-principal user) points)
    (asserts! (validate-reputation-amount points) points)
    (match (map-get? rehabilitation-programs { user: user })
      program-data 
        (if (and (get is-active program-data) (<= stacks-block-height (get end-block program-data)))
          (let (
            (sanitized-points (sanitize-uint points))
            (sanitized-multiplier (sanitize-uint (get recovery-multiplier program-data)))
          )
            (/ (* sanitized-points (+ u100 sanitized-multiplier)) u100)
          )
          points
        )
      points
    )
  )
)

(define-private (update-category-score (scores { technical: uint, community: uint, governance: uint, creativity: uint }) (category (string-ascii 20)) (points uint))
  (begin
    (asserts! (validate-category-string category) scores)
    (asserts! (validate-reputation-amount points) scores)
    (let (
      (sanitized-points (sanitize-uint points))
    )
      (if (is-eq category CAT_TECHNICAL)
        (merge scores { technical: (+ (get technical scores) sanitized-points) })
        (if (is-eq category CAT_COMMUNITY)
          (merge scores { community: (+ (get community scores) sanitized-points) })
          (if (is-eq category CAT_GOVERNANCE)
            (merge scores { governance: (+ (get governance scores) sanitized-points) })
            (if (is-eq category CAT_CREATIVITY)
              (merge scores { creativity: (+ (get creativity scores) sanitized-points) })
              scores
            )
          )
        )
      )
    )
  )
)

;; Direct reputation update function to avoid circular dependencies
(define-private (direct-reputation-update (user principal) (points uint) (category (string-ascii 20)) (reason (string-ascii 100)))
  (begin
    (asserts! (validate-principal user) (err ERR_INVALID_PRINCIPAL))
    (asserts! (validate-reputation-amount points) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-category-string category) (err ERR_INVALID_INPUT))
    (asserts! (validate-string-length reason) (err ERR_STRING_TOO_LONG))
    (let (
      (current-rep (default-to 
        { total-score: u0, last-updated: stacks-block-height, category-scores: { technical: u0, community: u0, governance: u0, creativity: u0 }, spent-reputation: u0 }
        (map-get? reputations { user: user })
      ))
      (decayed-score (apply-decay (get total-score current-rep) (get last-updated current-rep)))
      (sanitized-points (sanitize-uint points))
      (new-category-scores (update-category-score (get category-scores current-rep) category sanitized-points))
    )
      (map-set reputations 
        { user: user }
        {
          total-score: (+ decayed-score sanitized-points),
          last-updated: stacks-block-height,
          category-scores: new-category-scores,
          spent-reputation: (get spent-reputation current-rep)
        }
      )
      (record-history user "mentor-bonus" (to-int sanitized-points) category reason)
      (ok true)
    )
  )
)

;; =============================================================================
;; ADMIN MANAGEMENT
;; =============================================================================

(define-public (add-admin (new-admin principal) (role (string-ascii 20)) (permissions uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-principal new-admin) (err ERR_INVALID_PRINCIPAL))
    (asserts! (validate-string-length role) (err ERR_STRING_TOO_LONG))
    (asserts! (validate-permissions permissions) (err ERR_INVALID_AMOUNT))
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) 
                  (has-permission tx-sender PERM_MANAGE_ADMINS)) (err ERR_NOT_AUTHORIZED))
    (map-set admin-roles
      { admin: new-admin }
      {
        role: role,
        permissions: permissions,
        appointed-at: stacks-block-height,
        appointed-by: tx-sender
      }
    )
    ;; Use unwrap-panic to handle the list operation safely
    (var-set admins (unwrap-panic (as-max-len? (append (var-get admins) new-admin) u20)))
    (ok true)
  )
)

(define-public (remove-admin (admin principal))
  (begin
    (try! (assert-critical-operation-allowed))
    (asserts! (validate-principal admin) (err ERR_INVALID_PRINCIPAL))
    ;; Only contract owner can remove admins (critical operation)
    (try! (assert-owner-only))
    ;; Prevent removing the contract owner
    (asserts! (not (is-eq admin (var-get contract-owner))) (err ERR_CRITICAL_OPERATION))
    
    (let ((admin-data (map-get? admin-roles { admin: admin })))
      (let ((unwrapped-admin (unwrap! admin-data (err ERR_USER_NOT_FOUND))))
        (map-delete admin-roles { admin: admin })
        ;; Set the admin to remove and filter the list
        (var-set admin-to-remove admin)
        (var-set admins (filter is-not-target-admin (var-get admins)))
        (unwrap-panic (record-emergency-action "admin-removed" "Admin privileges revoked" (list admin)))
        (ok true)
      )
    )
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (assert-owner-only))
    (asserts! (validate-principal new-owner) (err ERR_INVALID_PRINCIPAL))
    (asserts! (not (is-eq new-owner (var-get contract-owner))) (err ERR_INVALID_INPUT))
    
    ;; Update admin roles for new owner
    (map-set admin-roles
      { admin: new-owner }
      {
        role: "owner",
        permissions: u63,
        appointed-at: stacks-block-height,
        appointed-by: tx-sender
      }
    )
    
    ;; Remove old owner from admin roles but keep in admins list for history
    (map-delete admin-roles { admin: (var-get contract-owner) })
    
    ;; Transfer ownership
    (var-set contract-owner new-owner)
    (unwrap-panic (record-emergency-action "ownership-transferred" "Contract ownership transferred" (list new-owner)))
    (ok true)
  )
)

;; =============================================================================
;; REPUTATION MANAGEMENT
;; =============================================================================

(define-public (award-points (user principal) (points uint) (category (string-ascii 20)) (reason (string-ascii 100)))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-principal user) (err ERR_INVALID_PRINCIPAL))
    (asserts! (validate-reputation-amount points) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-non-zero points) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-category-string category) (err ERR_INVALID_INPUT))
    (asserts! (validate-string-length reason) (err ERR_STRING_TOO_LONG))
    (asserts! (has-permission tx-sender PERM_AWARD_POINTS) (err ERR_NOT_AUTHORIZED))
    
    (let (
      (current-rep (default-to 
        { total-score: u0, last-updated: stacks-block-height, category-scores: { technical: u0, community: u0, governance: u0, creativity: u0 }, spent-reputation: u0 }
        (map-get? reputations { user: user })
      ))
      (decayed-score (apply-decay (get total-score current-rep) (get last-updated current-rep)))
      (sanitized-points (sanitize-uint points))
      (new-category-scores (update-category-score (get category-scores current-rep) category sanitized-points))
      ;; Apply rehabilitation multiplier if user is in program
      (final-points (apply-rehabilitation-multiplier user sanitized-points))
      (sanitized-final-points (sanitize-uint final-points))
    )
      (map-set reputations 
        { user: user }
        {
          total-score: (+ decayed-score sanitized-final-points),
          last-updated: stacks-block-height,
          category-scores: new-category-scores,
          spent-reputation: (get spent-reputation current-rep)
        }
      )
      (record-history user "award" (to-int sanitized-final-points) category reason)
      ;; Update rehabilitation progress if applicable (simplified to avoid circular dependency)
      (try! (update-rehabilitation-progress-simple user))
      (ok true)
    )
  )
)

;; Simplified rehabilitation progress update without circular dependency
(define-private (update-rehabilitation-progress-simple (user principal))
  (begin
    (asserts! (validate-principal user) (err ERR_INVALID_PRINCIPAL))
    (match (map-get? rehabilitation-programs { user: user })
      program-data
        (if (and (get is-active program-data) (<= stacks-block-height (get end-block program-data)))
          (let (
            (new-completed (+ (get completed-actions program-data) u1))
          )
            (map-set rehabilitation-programs
              { user: user }
              (merge program-data { completed-actions: new-completed })
            )
            ;; Check if program is completed
            (if (>= new-completed (get required-actions program-data))
              (complete-rehabilitation-program-simple user)
              (ok true)
            )
          )
          (ok true)
        )
      (ok true)
    )
  )
)

;; Simplified completion without circular dependency
(define-private (complete-rehabilitation-program-simple (user principal))
  (begin
    (asserts! (validate-principal user) (err ERR_INVALID_PRINCIPAL))
    (match (map-get? rehabilitation-programs { user: user })
      program-data
        (begin
          ;; Mark program as completed
          (map-set rehabilitation-programs
            { user: user }
            (merge program-data { is-active: false })
          )
          
          ;; Record completion history first
          (record-history user "rehabilitation-complete" (to-int u0) "system" "program-completed")
          
          ;; Award mentor bonus if applicable using direct update
          (match (get mentor program-data)
            mentor-principal
              (let (
                (mentor-bonus (/ (* (var-get mentor-bonus-rate) u100) u100))
                (sanitized-bonus (sanitize-uint mentor-bonus))
              )
                (try! (direct-reputation-update mentor-principal sanitized-bonus CAT_COMMUNITY "successful-mentoring"))
                (ok true)
              )
            (ok true)
          )
        )
      (ok true)
    )
  )
)

(define-public (deduct-points (user principal) (points uint) (reason (string-ascii 100)))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-principal user) (err ERR_INVALID_PRINCIPAL))
    (asserts! (validate-reputation-amount points) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-non-zero points) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-string-length reason) (err ERR_STRING_TOO_LONG))
    (asserts! (has-permission tx-sender PERM_AWARD_POINTS) (err ERR_NOT_AUTHORIZED))
    
    (let (
      (current-rep (unwrap! (map-get? reputations { user: user }) (err ERR_USER_NOT_FOUND)))
      (decayed-score (apply-decay (get total-score current-rep) (get last-updated current-rep)))
      (sanitized-points (sanitize-uint points))
      (new-score (if (> decayed-score sanitized-points) (- decayed-score sanitized-points) u0))
      (penalty-id (var-get next-penalty-id))
    )
      (map-set reputations 
        { user: user }
        (merge current-rep { total-score: new-score, last-updated: stacks-block-height })
      )
      ;; Record penalty for potential rehabilitation
      (map-set user-penalties
        { user: user, penalty-id: penalty-id }
        {
          penalty-type: "reputation-deduction",
          points-deducted: sanitized-points,
          issued-at: stacks-block-height,
          issued-by: tx-sender,
          reason: reason,
          rehabilitation-eligible: (>= sanitized-points u50) ;; Major penalties are eligible for rehabilitation
        }
      )
      (var-set next-penalty-id (+ penalty-id u1))
      (record-history user "deduct" (to-int (- u0 sanitized-points)) "penalty" reason)
      (ok true)
    )
  )
)

;; =============================================================================
;; ACHIEVEMENT SYSTEM
;; =============================================================================

(define-public (create-achievement (name (string-ascii 50)) (description (string-ascii 200)) (points-reward uint) (category (string-ascii 20)) (requirements uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-string-length name) (err ERR_STRING_TOO_LONG))
    (asserts! (validate-string-length description) (err ERR_STRING_TOO_LONG))
    (asserts! (validate-reputation-amount points-reward) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-category-string category) (err ERR_INVALID_INPUT))
    (asserts! (validate-requirements requirements) (err ERR_INVALID_AMOUNT))
    (asserts! (has-permission tx-sender PERM_MANAGE_ACHIEVEMENTS) (err ERR_NOT_AUTHORIZED))
    
    (let (
      (achievement-id (var-get next-achievement-id))
      (sanitized-points (sanitize-uint points-reward))
      (sanitized-requirements (sanitize-uint requirements))
    )
      (map-set achievements
        { achievement-id: achievement-id }
        {
          name: name,
          description: description,
          points-reward: sanitized-points,
          category: category,
          requirements: sanitized-requirements,
          is-active: true
        }
      )
      (var-set next-achievement-id (+ achievement-id u1))
      (ok achievement-id)
    )
  )
)

(define-public (award-achievement (user principal) (achievement-id uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-principal user) (err ERR_INVALID_PRINCIPAL))
    (asserts! (validate-non-zero achievement-id) (err ERR_INVALID_AMOUNT))
    (asserts! (has-permission tx-sender PERM_MANAGE_ACHIEVEMENTS) (err ERR_NOT_AUTHORIZED))
    
    (let (
      (achievement (unwrap! (map-get? achievements { achievement-id: achievement-id }) (err ERR_ACHIEVEMENT_NOT_FOUND)))
    )
      (asserts! (is-none (map-get? user-achievements { user: user, achievement-id: achievement-id })) (err ERR_ALREADY_EARNED))
      (asserts! (get is-active achievement) (err ERR_ACHIEVEMENT_NOT_FOUND))
      
      (map-set user-achievements
        { user: user, achievement-id: achievement-id }
        { earned-at: stacks-block-height, points-awarded: (get points-reward achievement) }
      )
      
      ;; Award the points directly without calling award-points to avoid circular dependency
      (let (
        (current-rep (default-to 
          { total-score: u0, last-updated: stacks-block-height, category-scores: { technical: u0, community: u0, governance: u0, creativity: u0 }, spent-reputation: u0 }
          (map-get? reputations { user: user })
        ))
        (decayed-score (apply-decay (get total-score current-rep) (get last-updated current-rep)))
        (sanitized-points (sanitize-uint (get points-reward achievement)))
        (new-category-scores (update-category-score (get category-scores current-rep) (get category achievement) sanitized-points))
      )
        (map-set reputations 
          { user: user }
          {
            total-score: (+ decayed-score sanitized-points),
            last-updated: stacks-block-height,
            category-scores: new-category-scores,
            spent-reputation: (get spent-reputation current-rep)
          }
        )
        (record-history user "achievement" (to-int sanitized-points) (get category achievement) (get name achievement))
        (ok true)
      )
    )
  )
)

;; =============================================================================
;; MARKETPLACE SYSTEM FUNCTIONS
;; =============================================================================

(define-public (create-service (name (string-ascii 50)) (description (string-ascii 200)) (reputation-cost uint) (category-requirements { technical: uint, community: uint, governance: uint, creativity: uint }))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-string-length name) (err ERR_STRING_TOO_LONG))
    (asserts! (validate-string-length description) (err ERR_STRING_TOO_LONG))
    (asserts! (validate-reputation-amount reputation-cost) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-reputation-amount (get technical category-requirements)) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-reputation-amount (get community category-requirements)) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-reputation-amount (get governance category-requirements)) (err ERR_INVALID_AMOUNT))
    (asserts! (validate-reputation-amount (get creativity category-requirements)) (err ERR_INVALID_AMOUNT))
    (asserts! (has-permission tx-sender PERM_MANAGE_SERVICES) (err ERR_NOT_AUTHORIZED))
    (asserts! (>= reputation-cost (var-get min-service-cost)) (err ERR_INVALID_AMOUNT))
    
    (let (
      (service-id (var-get next-service-id))
      (sanitized-cost (sanitize-uint reputation-cost))
      (sanitized-requirements {
        technical: (sanitize-uint (get technical category-requirements)),
        community: (sanitize-uint (get community category-requirements)),
        governance: (sanitize-uint (get governance category-requirements)),
        creativity: (sanitize-uint (get creativity category-requirements))
      })
    )
      (map-set marketplace-services
        { service-id: service-id }
        {
          name: name,
          description: description,
          reputation-cost: sanitized-cost,
          category-requirements: sanitized-requirements,
          provider: tx-sender,
          is-active: true,
          created-at: stacks-block-height,
          usage-count: u0
        }
      )
      (var-set next-service-id (+ service-id u1))
      (ok service-id)
    )
  )
)

(define-public (purchase-service (service-id uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-non-zero service-id) (err ERR_INVALID_AMOUNT))
    (let (
      (service (unwrap! (map-get? marketplace-services { service-id: service-id }) (err ERR_SERVICE_NOT_FOUND)))
      (user-rep (unwrap! (map-get? reputations { user: tx-sender }) (err ERR_USER_NOT_FOUND)))
      (current-score (get-current-reputation tx-sender))
      (sanitized-cost (sanitize-uint (get reputation-cost service)))
      (purchase-id (var-get next-purchase-id))
    )
      (asserts! (get is-active service) (err ERR_SERVICE_INACTIVE))
      (asserts! (>= current-score sanitized-cost) (err ERR_INSUFFICIENT_REPUTATION))
      (asserts! (meets-category-requirements tx-sender (get category-requirements service)) (err ERR_INSUFFICIENT_CATEGORY_REP))
      
      ;; Deduct reputation cost
      (map-set reputations
        { user: tx-sender }
        (merge user-rep { 
          total-score: (- current-score sanitized-cost),
          spent-reputation: (+ (get spent-reputation user-rep) sanitized-cost),
          last-updated: stacks-block-height
        })
      )
      
      ;; Record purchase
      (map-set service-purchases
        { user: tx-sender, service-id: service-id, purchase-id: purchase-id }
        {
          purchased-at: stacks-block-height,
          reputation-spent: sanitized-cost,
          status: STATUS_ACTIVE
        }
      )
      
      ;; Update service usage count
      (map-set marketplace-services
        { service-id: service-id }
        (merge service { usage-count: (+ (get usage-count service) u1) })
      )
      
      ;; Update user service access
      (let (
        (current-access (default-to 
          { active-services: (list), total-spent: u0, last-purchase: u0 }
          (map-get? user-service-access { user: tx-sender })
        ))
      )
        (map-set user-service-access
          { user: tx-sender }
          {
            active-services: (unwrap-panic (as-max-len? (append (get active-services current-access) service-id) u10)),
            total-spent: (+ (get total-spent current-access) sanitized-cost),
            last-purchase: stacks-block-height
          }
        )
      )
      
      (var-set next-purchase-id (+ purchase-id u1))
      (record-history tx-sender "service-purchase" (to-int (- u0 sanitized-cost)) "marketplace" (get name service))
      (ok purchase-id)
    )
  )
)

(define-public (deactivate-service (service-id uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-non-zero service-id) (err ERR_INVALID_AMOUNT))
    (let (
      (service (unwrap! (map-get? marketplace-services { service-id: service-id }) (err ERR_SERVICE_NOT_FOUND)))
    )
      (asserts! (or (is-eq tx-sender (get provider service)) 
                    (has-permission tx-sender PERM_MANAGE_SERVICES)) (err ERR_NOT_AUTHORIZED))
      
      (map-set marketplace-services
        { service-id: service-id }
        (merge service { is-active: false })
      )
      (ok true)
    )
  )
)

;; =============================================================================
;; REHABILITATION SYSTEM FUNCTIONS
;; =============================================================================

(define-public (start-rehabilitation-program (user principal) (program-type (string-ascii 30)) (penalty-reason (string-ascii 100)))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-principal user) (err ERR_INVALID_PRINCIPAL))
    (asserts! (validate-string-length program-type) (err ERR_STRING_TOO_LONG))
    (asserts! (validate-string-length penalty-reason) (err ERR_STRING_TOO_LONG))
    (asserts! (has-permission tx-sender PERM_MANAGE_REHABILITATION) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-none (map-get? rehabilitation-programs { user: user })) (err ERR_ALREADY_IN_PROGRAM))
    
    (let (
      (program-duration (var-get rehabilitation-period))
      (required-actions (if (is-eq program-type "minor") u5 u10))
      (recovery-multiplier (if (is-eq program-type "minor") u20 u50))
    )
      (map-set rehabilitation-programs
        { user: user }
        {
          program-type: program-type,
          start-block: stacks-block-height,
          end-block: (+ stacks-block-height program-duration),
          required-actions: required-actions,
          completed-actions: u0,
          mentor: none,
          recovery-multiplier: recovery-multiplier,
          is-active: true,
          penalty-reason: penalty-reason
        }
      )
      (record-history user "rehabilitation-start" (to-int u0) "system" program-type)
      (ok true)
    )
  )
)

(define-public (assign-mentor (mentee principal) (mentor principal))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-principal mentee) (err ERR_INVALID_PRINCIPAL))
    (asserts! (validate-principal mentor) (err ERR_INVALID_PRINCIPAL))
    (asserts! (has-permission tx-sender PERM_MANAGE_REHABILITATION) (err ERR_NOT_AUTHORIZED))
    (asserts! (not (is-eq mentee mentor)) (err ERR_INVALID_MENTOR))
    
    (let (
      (program (unwrap! (map-get? rehabilitation-programs { user: mentee }) (err ERR_NOT_IN_PROGRAM)))
      (mentor-rep (get-current-reputation mentor))
    )
      (asserts! (get is-active program) (err ERR_PROGRAM_EXPIRED))
      (asserts! (>= mentor-rep u500) (err ERR_INSUFFICIENT_REPUTATION)) ;; Mentors need high reputation
      
      (map-set rehabilitation-programs
        { user: mentee }
        (merge program { mentor: (some mentor) })
      )
      
      (map-set mentorship-relationships
        { mentor: mentor, mentee: mentee }
        {
          started-at: stacks-block-height,
          program-type: (get program-type program),
          progress-score: u0,
          is-active: true
        }
      )
      (ok true)
    )
  )
)

(define-public (complete-rehabilitation-action (user principal) (action-description (string-ascii 100)))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-principal user) (err ERR_INVALID_PRINCIPAL))
    (asserts! (validate-string-length action-description) (err ERR_STRING_TOO_LONG))
    (asserts! (has-permission tx-sender PERM_MANAGE_REHABILITATION) (err ERR_NOT_AUTHORIZED))
    
    (let (
      (program (unwrap! (map-get? rehabilitation-programs { user: user }) (err ERR_NOT_IN_PROGRAM)))
    )
      (asserts! (get is-active program) (err ERR_PROGRAM_EXPIRED))
      (asserts! (<= stacks-block-height (get end-block program)) (err ERR_PROGRAM_EXPIRED))
      
      (let (
        (new-completed (+ (get completed-actions program) u1))
      )
        (map-set rehabilitation-programs
          { user: user }
          (merge program { completed-actions: new-completed })
        )
        
        (record-history user "rehabilitation-action" (to-int u1) "system" action-description)
        
        ;; Check if program is completed
        (if (>= new-completed (get required-actions program))
          (complete-rehabilitation-program-simple user)
          (ok true)
        )
      )
    )
  )
)

;; =============================================================================
;; GOVERNANCE SYSTEM
;; =============================================================================

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (proposal-type (string-ascii 20)))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-string-length title) (err ERR_STRING_TOO_LONG))
    (asserts! (validate-string-length description) (err ERR_STRING_TOO_LONG))
    (asserts! (validate-string-length proposal-type) (err ERR_STRING_TOO_LONG))
    (let (
      (user-rep (get-current-reputation tx-sender))
      (proposal-id (var-get next-proposal-id))
    )
      (asserts! (>= user-rep (var-get proposal-threshold)) (err ERR_INSUFFICIENT_REPUTATION))
      
      (map-set proposals
        { proposal-id: proposal-id }
        {
          title: title,
          description: description,
          proposer: tx-sender,
          created-at: stacks-block-height,
          voting-ends-at: (+ stacks-block-height (var-get voting-period)),
          votes-for: u0,
          votes-against: u0,
          executed: false,
          proposal-type: proposal-type
        }
      )
      (var-set next-proposal-id (+ proposal-id u1))
      (ok proposal-id)
    )
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-non-zero proposal-id) (err ERR_INVALID_AMOUNT))
    (let (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err ERR_PROPOSAL_NOT_FOUND)))
      (user-rep (get-current-reputation tx-sender))
      (existing-vote (map-get? proposal-votes { proposal-id: proposal-id, voter: tx-sender }))
      (sanitized-rep (sanitize-uint user-rep))
    )
      (asserts! (is-none existing-vote) (err ERR_ALREADY_VOTED))
      (asserts! (<= stacks-block-height (get voting-ends-at proposal)) (err ERR_VOTING_ENDED))
      (asserts! (> sanitized-rep u0) (err ERR_INSUFFICIENT_REPUTATION))
      
      ;; Record the vote
      (map-set proposal-votes
        { proposal-id: proposal-id, voter: tx-sender }
        { vote: vote-for, voting-power: sanitized-rep, voted-at: stacks-block-height }
      )
      
      ;; Update proposal vote counts
      (if vote-for
        (map-set proposals
          { proposal-id: proposal-id }
          (merge proposal { votes-for: (+ (get votes-for proposal) sanitized-rep) })
        )
        (map-set proposals
          { proposal-id: proposal-id }
          (merge proposal { votes-against: (+ (get votes-against proposal) sanitized-rep) })
        )
      )
      (ok true)
    )
  )
)

(define-public (delegate-voting-power (delegate principal))
  (begin
    (try! (assert-not-paused))
    (asserts! (validate-principal delegate) (err ERR_INVALID_PRINCIPAL))
    (asserts! (not (is-eq tx-sender delegate)) (err ERR_SELF_DELEGATION))
    (let (
      (user-rep (get-current-reputation tx-sender))
      (sanitized-rep (sanitize-uint user-rep))
    )
      (asserts! (> sanitized-rep u0) (err ERR_INSUFFICIENT_REPUTATION))
      
      (map-set delegations
        { delegator: tx-sender }
        { delegate: delegate, delegated-at: stacks-block-height, voting-power: sanitized-rep }
      )
      (ok true)
    )
  )
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-user-reputation (user principal))
  (begin
    (asserts! (validate-principal user) none)
    (let (
      (rep-data (map-get? reputations { user: user }))
    )
      (match rep-data
        data (some {
          total-score: (get-current-reputation user),
          category-scores: (get category-scores data),
          spent-reputation: (get spent-reputation data),
          last-updated: (get last-updated data)
        })
        none
      )
    )
  )
)

(define-read-only (get-service-details (service-id uint))
  (begin
    (asserts! (validate-non-zero service-id) none)
    (map-get? marketplace-services { service-id: service-id })
  )
)

(define-read-only (get-user-rehabilitation-status (user principal))
  (begin
    (asserts! (validate-principal user) none)
    (map-get? rehabilitation-programs { user: user })
  )
)

(define-read-only (get-user-service-access (user principal))
  (begin
    (asserts! (validate-principal user) none)
    (map-get? user-service-access { user: user })
  )
)

(define-read-only (has-user-purchased-service (user principal) (service-id uint))
  (begin
    (asserts! (validate-principal user) false)
    (asserts! (validate-non-zero service-id) false)
    (let (
      (user-access (map-get? user-service-access { user: user }))
    )
      (match user-access
        access-data 
          (is-some (index-of? (get active-services access-data) service-id))
        false
      )
    )
  )
)

(define-read-only (get-achievement-details (achievement-id uint))
  (begin
    (asserts! (validate-non-zero achievement-id) none)
    (map-get? achievements { achievement-id: achievement-id })
  )
)

(define-read-only (get-proposal-details (proposal-id uint))
  (begin
    (asserts! (validate-non-zero proposal-id) none)
    (map-get? proposals { proposal-id: proposal-id })
  )
)

(define-read-only (get-admin-details (admin principal))
  (begin
    (asserts! (validate-principal admin) none)
    (map-get? admin-roles { admin: admin })
  )
)

(define-read-only (get-contract-status)
  {
    paused: (var-get paused),
    emergency-mode: (var-get emergency-mode),
    emergency-activated-at: (var-get emergency-activated-at),
    emergency-actions-count: (var-get emergency-actions-count),
    contract-owner: (var-get contract-owner),
    emergency-admin: (var-get emergency-admin)
  }
)

(define-read-only (get-emergency-action (action-id uint))
  (begin
    (asserts! (validate-non-zero action-id) none)
    (map-get? emergency-actions { action-id: action-id })
  )
)

;; Initialize contract with owner as first admin
(map-set admin-roles
  { admin: (var-get contract-owner) }
  {
    role: "owner",
    permissions: u63, ;; All permissions
    appointed-at: stacks-block-height,
    appointed-by: (var-get contract-owner)
  }
)
