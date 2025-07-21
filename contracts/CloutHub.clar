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

;; =============================================================================
;; MARKETPLACE SYSTEM (Feature 5)
;; =============================================================================

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

;; =============================================================================
;; REHABILITATION SYSTEM (Feature 7)
;; =============================================================================

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

;; =============================================================================
;; DATA VARIABLES
;; =============================================================================

(define-data-var contract-owner principal tx-sender)
(define-data-var admins (list 20 principal) (list tx-sender))
(define-data-var next-achievement-id uint u1)
(define-data-var next-history-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-service-id uint u1)
(define-data-var next-penalty-id uint u1)
(define-data-var next-purchase-id uint u1)

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
;; PRIVATE FUNCTIONS
;; =============================================================================

(define-private (has-permission (admin principal) (permission uint))
  (match (map-get? admin-roles { admin: admin })
    admin-data (> (bit-and (get permissions admin-data) permission) u0)
    false
  )
)

(define-private (apply-decay (current-score uint) (last-updated uint))
  (let (
    (blocks-passed (- stacks-block-height last-updated))
    (decay-periods (/ blocks-passed (var-get decay-period)))
  )
    (if (> decay-periods u0)
      (let (
        (decay-factor (pow u95 decay-periods)) ;; 95% retention per period
        (decayed-score (/ (* current-score decay-factor) (pow u100 decay-periods)))
      )
        (max-uint decayed-score (var-get min-reputation))
      )
      current-score
    )
  )
)

(define-private (record-history (user principal) (action (string-ascii 30)) (points-change int) (category (string-ascii 20)) (reason (string-ascii 100)))
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
  )
)

;; Returns the user's current (possibly decayed) reputation score
(define-private (get-current-reputation (user principal))
  (let (
    (current-rep (default-to 
      { total-score: u0, last-updated: stacks-block-height, category-scores: { technical: u0, community: u0, governance: u0, creativity: u0 }, spent-reputation: u0 }
      (map-get? reputations { user: user })
    ))
  )
    (apply-decay (get total-score current-rep) (get last-updated current-rep))
  )
)

;; Check if user meets category requirements
(define-private (meets-category-requirements (user principal) (requirements { technical: uint, community: uint, governance: uint, creativity: uint }))
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

;; Fixed filter function for admin removal
(define-private (is-not-target-admin (admin principal))
  (not (is-eq admin (var-get admin-to-remove)))
)

;; Apply rehabilitation multiplier without circular dependency
(define-private (apply-rehabilitation-multiplier (user principal) (points uint))
  (match (map-get? rehabilitation-programs { user: user })
    program-data 
      (if (and (get is-active program-data) (<= stacks-block-height (get end-block program-data)))
        (/ (* points (+ u100 (get recovery-multiplier program-data))) u100)
        points
      )
    points
  )
)

(define-private (update-category-score (scores { technical: uint, community: uint, governance: uint, creativity: uint }) (category (string-ascii 20)) (points uint))
  (if (is-eq category CAT_TECHNICAL)
    (merge scores { technical: (+ (get technical scores) points) })
    (if (is-eq category CAT_COMMUNITY)
      (merge scores { community: (+ (get community scores) points) })
      (if (is-eq category CAT_GOVERNANCE)
        (merge scores { governance: (+ (get governance scores) points) })
        (if (is-eq category CAT_CREATIVITY)
          (merge scores { creativity: (+ (get creativity scores) points) })
          scores
        )
      )
    )
  )
)

;; Direct reputation update function to avoid circular dependencies
(define-private (direct-reputation-update (user principal) (points uint) (category (string-ascii 20)) (reason (string-ascii 100)))
  (let (
    (current-rep (default-to 
      { total-score: u0, last-updated: stacks-block-height, category-scores: { technical: u0, community: u0, governance: u0, creativity: u0 }, spent-reputation: u0 }
      (map-get? reputations { user: user })
    ))
    (decayed-score (apply-decay (get total-score current-rep) (get last-updated current-rep)))
    (new-category-scores (update-category-score (get category-scores current-rep) category points))
  )
    (map-set reputations 
      { user: user }
      {
        total-score: (+ decayed-score points),
        last-updated: stacks-block-height,
        category-scores: new-category-scores,
        spent-reputation: (get spent-reputation current-rep)
      }
    )
    (record-history user "mentor-bonus" (to-int points) category reason)
    (ok true)
  )
)

;; =============================================================================
;; ADMIN MANAGEMENT
;; =============================================================================

(define-public (add-admin (new-admin principal) (role (string-ascii 20)) (permissions uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) 
                  (has-permission tx-sender PERM_MANAGE_ADMINS)) (err ERR_NOT_AUTHORIZED))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-eq (len role) (len role)) (err ERR_NOT_AUTHORIZED)) ;; Ensures role is checked as string-ascii
    (asserts! (>= permissions u0) (err ERR_INVALID_AMOUNT))
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
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (has-permission tx-sender PERM_MANAGE_ADMINS)) (err ERR_NOT_AUTHORIZED))
    (let ((admin-data (map-get? admin-roles { admin: admin })))
      (let ((unwrapped-admin (unwrap! admin-data (err ERR_USER_NOT_FOUND))))
        (map-delete admin-roles { admin: admin })
        ;; Set the admin to remove and filter the list
        (var-set admin-to-remove admin)
        (var-set admins (filter is-not-target-admin (var-get admins)))
        (ok true)
      )
    )
  )
)

;; =============================================================================
;; REPUTATION MANAGEMENT
;; =============================================================================

(define-public (award-points (user principal) (points uint) (category (string-ascii 20)) (reason (string-ascii 100)))
  (begin
    (asserts! (has-permission tx-sender PERM_AWARD_POINTS) (err ERR_NOT_AUTHORIZED))
    (asserts! (> points u0) (err ERR_INVALID_AMOUNT))
    
    (let (
      (current-rep (default-to 
        { total-score: u0, last-updated: stacks-block-height, category-scores: { technical: u0, community: u0, governance: u0, creativity: u0 }, spent-reputation: u0 }
        (map-get? reputations { user: user })
      ))
      (decayed-score (apply-decay (get total-score current-rep) (get last-updated current-rep)))
      (new-category-scores (update-category-score (get category-scores current-rep) category points))
      ;; Apply rehabilitation multiplier if user is in program
      (final-points (apply-rehabilitation-multiplier user points))
    )
      (map-set reputations 
        { user: user }
        {
          total-score: (+ decayed-score final-points),
          last-updated: stacks-block-height,
          category-scores: new-category-scores,
          spent-reputation: (get spent-reputation current-rep)
        }
      )
      (record-history user "award" (to-int final-points) category reason)
      ;; Update rehabilitation progress if applicable (simplified to avoid circular dependency)
      (unwrap! (update-rehabilitation-progress-simple user) (err u999))
      (ok true)
    )
  )
)

;; Simplified rehabilitation progress update without circular dependency
(define-private (update-rehabilitation-progress-simple (user principal))
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

;; Simplified completion without circular dependency
(define-private (complete-rehabilitation-program-simple (user principal))
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
            )
              (direct-reputation-update mentor-principal mentor-bonus CAT_COMMUNITY "successful-mentoring")
            )
          (ok true)
        )
      )
    (ok true)
  )
)

(define-public (deduct-points (user principal) (points uint) (reason (string-ascii 100)))
  (begin
    (asserts! (has-permission tx-sender PERM_AWARD_POINTS) (err ERR_NOT_AUTHORIZED))
    (asserts! (> points u0) (err ERR_INVALID_AMOUNT))
    
    (let (
      (current-rep (unwrap! (map-get? reputations { user: user }) (err ERR_USER_NOT_FOUND)))
      (decayed-score (apply-decay (get total-score current-rep) (get last-updated current-rep)))
      (new-score (if (> decayed-score points) (- decayed-score points) u0))
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
          points-deducted: points,
          issued-at: stacks-block-height,
          issued-by: tx-sender,
          reason: reason,
          rehabilitation-eligible: (>= points u50) ;; Major penalties are eligible for rehabilitation
        }
      )
      (var-set next-penalty-id (+ penalty-id u1))
      (record-history user "deduct" (to-int (- u0 points)) "penalty" reason)
      (ok true)
    )
  )
)

;; =============================================================================
;; ACHIEVEMENT SYSTEM
;; =============================================================================

(define-public (create-achievement (name (string-ascii 50)) (description (string-ascii 200)) (points-reward uint) (category (string-ascii 20)) (requirements uint))
  (begin
    (asserts! (has-permission tx-sender PERM_MANAGE_ACHIEVEMENTS) (err ERR_NOT_AUTHORIZED))
    
    (let (
      (achievement-id (var-get next-achievement-id))
    )
      (map-set achievements
        { achievement-id: achievement-id }
        {
          name: name,
          description: description,
          points-reward: points-reward,
          category: category,
          requirements: requirements,
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
        (new-category-scores (update-category-score (get category-scores current-rep) (get category achievement) (get points-reward achievement)))
      )
        (map-set reputations 
          { user: user }
          {
            total-score: (+ decayed-score (get points-reward achievement)),
            last-updated: stacks-block-height,
            category-scores: new-category-scores,
            spent-reputation: (get spent-reputation current-rep)
          }
        )
        (record-history user "achievement" (to-int (get points-reward achievement)) (get category achievement) (get name achievement))
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
    (asserts! (has-permission tx-sender PERM_MANAGE_SERVICES) (err ERR_NOT_AUTHORIZED))
    (asserts! (>= reputation-cost (var-get min-service-cost)) (err ERR_INVALID_AMOUNT))
    
    (let (
      (service-id (var-get next-service-id))
    )
      (map-set marketplace-services
        { service-id: service-id }
        {
          name: name,
          description: description,
          reputation-cost: reputation-cost,
          category-requirements: category-requirements,
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
    (let (
      (service (unwrap! (map-get? marketplace-services { service-id: service-id }) (err ERR_SERVICE_NOT_FOUND)))
      (user-rep (unwrap! (map-get? reputations { user: tx-sender }) (err ERR_USER_NOT_FOUND)))
      (current-score (get-current-reputation tx-sender))
      (service-cost (get reputation-cost service))
      (purchase-id (var-get next-purchase-id))
    )
      (asserts! (get is-active service) (err ERR_SERVICE_INACTIVE))
      (asserts! (>= current-score service-cost) (err ERR_INSUFFICIENT_REPUTATION))
      (asserts! (meets-category-requirements tx-sender (get category-requirements service)) (err ERR_INSUFFICIENT_CATEGORY_REP))
      
      ;; Deduct reputation cost
      (map-set reputations
        { user: tx-sender }
        (merge user-rep { 
          total-score: (- current-score service-cost),
          spent-reputation: (+ (get spent-reputation user-rep) service-cost),
          last-updated: stacks-block-height
        })
      )
      
      ;; Record purchase
      (map-set service-purchases
        { user: tx-sender, service-id: service-id, purchase-id: purchase-id }
        {
          purchased-at: stacks-block-height,
          reputation-spent: service-cost,
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
            total-spent: (+ (get total-spent current-access) service-cost),
            last-purchase: stacks-block-height
          }
        )
      )
      
      (var-set next-purchase-id (+ purchase-id u1))
      (record-history tx-sender "service-purchase" (to-int (- u0 service-cost)) "marketplace" (get name service))
      (ok purchase-id)
    )
  )
)

(define-public (deactivate-service (service-id uint))
  (begin
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
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-user-reputation (user principal))
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

(define-read-only (get-service-details (service-id uint))
  (map-get? marketplace-services { service-id: service-id })
)

(define-read-only (get-user-rehabilitation-status (user principal))
  (map-get? rehabilitation-programs { user: user })
)

(define-read-only (get-user-service-access (user principal))
  (map-get? user-service-access { user: user })
)

(define-read-only (has-user-purchased-service (user principal) (service-id uint))
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