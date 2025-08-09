# CloutHub Smart Contract

CloutHub is a Clarity smart contract for the Stacks blockchain that implements a **reputation-based governance, achievement, marketplace, and rehabilitation system** for decentralized communities and platforms.

## Recent Updates

Added new features:
- **Governance System:**
  - Proposal creation and voting mechanism
  - Delegation of voting power
  - Configurable voting periods and thresholds
- **Enhanced Rehabilitation System:**
  - Mentor assignment and tracking
  - Progress monitoring
  - Completion rewards
  - Rehabilitation multipliers for earned points
- **Extended Marketplace Features:**
  - Category-based requirements
  - Service usage tracking
  - Purchase history
  - Active service listing

## Core Features

- **Reputation System:**  
  - Category-based scoring (technical, community, governance, creativity)
  - Time-based decay
  - Spending tracking
  - Action history

- **Admin Management:**  
  - Role-based permissions
  - Granular access control
  - Admin appointment tracking

- **Achievement System:**  
  - Custom achievements
  - Point rewards
  - Category-specific awards

- **Marketplace:**  
  - Reputation-based services
  - Category requirements
  - Usage analytics

## New Functions

### Governance
```clarity
create-proposal(title, description, proposal-type)
vote-on-proposal(proposal-id, vote-for)
delegate-voting-power(delegate)
```

### Rehabilitation
```clarity
start-rehabilitation-program(user, program-type, penalty-reason)
assign-mentor(mentee, mentor)
complete-rehabilitation-action(user, action-description)
```

### New Query Functions
```clarity
get-user-rehabilitation-status(user)
get-achievement-details(achievement-id)
get-proposal-details(proposal-id)
get-admin-details(admin)
```

## Enhanced Data Structures

- **Proposals:**
  ```clarity
  proposals: { title, description, votes-for, votes-against, ... }
  proposal-votes: { vote, voting-power, voted-at }
  ```

- **Rehabilitation:**
  ```clarity
  rehabilitation-programs: { program-type, actions, mentor, multiplier, ... }
  mentorship-relationships: { mentor, mentee, progress, status }
  ```

## Configuration Settings

Added new system variables:
- `proposal-threshold`: Minimum reputation for creating proposals
- `voting-period`: Duration of voting windows
- `rehabilitation-period`: Length of rehabilitation programs
- `mentor-bonus-rate`: Reward rate for successful mentoring
- `marketplace-fee-rate`: Service fees
- `min-service-cost`: Minimum service pricing

## Error Handling

New error constants:
- `ERR_PROPOSAL_ACTIVE`
- `ERR_SERVICE_INACTIVE`
- `ERR_INSUFFICIENT_CATEGORY_REP`
- `ERR_ALREADY_IN_PROGRAM`
- `ERR_PROGRAM_EXPIRED`
- `ERR_INVALID_MENTOR`

## Usage

Deploy the contract on the Stacks blockchain. Use the public functions to manage users, reputation, achievements, marketplace services, and rehabilitation programs. Only authorized admins can perform sensitive actions.

---

## Permissions

Admin actions are controlled by permission bitmasks:

- `PERM_AWARD_POINTS`
- `PERM_MANAGE_ACHIEVEMENTS`
- `PERM_MANAGE_ADMINS`
- `PERM_SYSTEM_CONFIG`
- `PERM_MANAGE_SERVICES`
- `PERM_MANAGE_REHABILITATION`

---

## Error Codes

The contract uses error codes for robust validation and access control, such as:

- `ERR_NOT_AUTHORIZED`
- `ERR_INVALID_AMOUNT`
- `ERR_USER_NOT_FOUND`
- `ERR_ACHIEVEMENT_EXISTS`
- `ERR_ALREADY_EARNED`
- `ERR_INSUFFICIENT_REPUTATION`
- ...and more.

---

## License

This contract is provided for educational and experimental use. Please review and audit before deploying in production.

---

## Author

Lucy Madaki

---

For more details, see the contract source code in CloutHub.clar.
