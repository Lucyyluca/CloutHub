# CloutHub Smart Contract

CloutHub is a Clarity smart contract for the Stacks blockchain that implements a **reputation-based governance, achievement, marketplace, and rehabilitation system** for decentralized communities and platforms.

---

## Features

- **Reputation System:**  
  - Tracks users' reputation scores, including category breakdowns (technical, community, governance, creativity).
  - Supports reputation decay over time, reputation spending, and history tracking.

- **Admin Roles & Permissions:**  
  - Flexible admin management with role-based permissions using bitmasks.
  - Only authorized admins can manage reputation, achievements, services, and rehabilitation programs.

- **Achievements:**  
  - Admins can define and award achievements to users, granting reputation points.

- **Marketplace:**  
  - Services can be created and purchased using reputation.
  - Tracks service usage and user access.

- **Governance:**  
  - Proposal and voting system (data structures included).

- **Rehabilitation:**  
  - Penalized users can enter rehabilitation programs, complete actions, and be mentored for reputation recovery.

---

## Key Data Structures

- `reputations`: Tracks user reputation, category scores, spent reputation, and last update.
- `admin-roles`: Stores admin roles, permissions, and appointment info.
- `achievements` & `user-achievements`: Achievement definitions and user awards.
- `marketplace-services`, `service-purchases`, `user-service-access`: Marketplace and service usage tracking.
- `rehabilitation-programs`, `user-penalties`, `mentorship-relationships`: Rehabilitation and penalty management.

---

## Main Public Functions

- **Admin Management**
  - `add-admin(new-admin, role, permissions)`
  - `remove-admin(admin)`

- **Reputation Management**
  - `award-points(user, points, category, reason)`
  - `deduct-points(user, points, reason)`

- **Achievements**
  - `create-achievement(name, description, points-reward, category, requirements)`
  - `award-achievement(user, achievement-id)`

- **Marketplace**
  - `create-service(name, description, reputation-cost, category-requirements)`
  - `purchase-service(service-id)`
  - `deactivate-service(service-id)`

- **Rehabilitation**
  - `start-rehabilitation-program(user, program-type, penalty-reason)`
  - `assign-mentor(mentee, mentor)`
  - `complete-rehabilitation-action(user, action-description)`

- **Read-Only Queries**
  - `get-user-reputation(user)`
  - `get-service-details(service-id)`
  - `get-user-rehabilitation-status(user)`
  - `get-user-service-access(user)`
  - `has-user-purchased-service(user, service-id)`

---

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
