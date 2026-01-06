
import { Cl, ClarityType } from "@stacks/transactions";
import { describe, expect, it } from "vitest";

const CONTRACT = "CloutHub";
const ERR_ALREADY_EARNED = 206;
const ERR_INSUFFICIENT_REPUTATION = 207;
const ERR_SELF_DELEGATION = 209;
const ERR_SYSTEM_PAUSED = 224;

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const principal = (address: string) => Cl.standardPrincipal(address);

const getUserReputation = (address: string) =>
  simnet.callReadOnlyFn(CONTRACT, "get-user-reputation", [principal(address)], deployer).result;

const unwrapOptional = (result: any) => {
  expect(result).toHaveClarityType(ClarityType.OptionalSome);
  return result.value;
};

const unwrapTuple = (result: any) => {
  expect(result).toHaveClarityType(ClarityType.Tuple);
  return result.value;
};

describe("CloutHub core flows", () => {
  it("initializes owner and admin role", () => {
    const status = simnet.callReadOnlyFn(CONTRACT, "get-contract-status", [], deployer);
    expect(status.result).toBeTuple({
      paused: Cl.bool(false),
      "emergency-mode": Cl.bool(false),
      "emergency-activated-at": Cl.uint(0),
      "emergency-actions-count": Cl.uint(0),
      "contract-owner": principal(deployer),
      "emergency-admin": principal(deployer),
    });

    const admin = simnet.callReadOnlyFn(CONTRACT, "get-admin-details", [principal(deployer)], deployer);
    const adminData = unwrapTuple(unwrapOptional(admin.result));
    expect(adminData.role).toBeAscii("owner");
    expect(adminData.permissions).toBeUint(63);
    expect(adminData["appointed-by"]).toBePrincipal(deployer);
    expect(adminData["appointed-at"]).toHaveClarityType(ClarityType.UInt);
  });

  it("adds and removes admins", () => {
    const add = simnet.callPublicFn(
      CONTRACT,
      "add-admin",
      [principal(wallet1), Cl.stringAscii("moderator"), Cl.uint(1)],
      deployer,
    );
    expect(add.result).toBeOk(Cl.bool(true));

    const admin = simnet.callReadOnlyFn(CONTRACT, "get-admin-details", [principal(wallet1)], deployer);
    const adminData = unwrapTuple(unwrapOptional(admin.result));
    expect(adminData.role).toBeAscii("moderator");
    expect(adminData.permissions).toBeUint(1);
    expect(adminData["appointed-by"]).toBePrincipal(deployer);
    expect(adminData["appointed-at"]).toHaveClarityType(ClarityType.UInt);

    const remove = simnet.callPublicFn(CONTRACT, "remove-admin", [principal(wallet1)], deployer);
    expect(remove.result).toBeOk(Cl.bool(true));

    const after = simnet.callReadOnlyFn(CONTRACT, "get-admin-details", [principal(wallet1)], deployer);
    expect(after.result).toBeNone();
  });

  it("awards reputation and surfaces deduct underflow", () => {
    const award = simnet.callPublicFn(
      CONTRACT,
      "award-points",
      [principal(wallet1), Cl.uint(100), Cl.stringAscii("technical"), Cl.stringAscii("init")],
      deployer,
    );
    expect(award.result).toBeOk(Cl.bool(true));

    const rep = unwrapTuple(unwrapOptional(getUserReputation(wallet1)));
    expect(rep["total-score"]).toBeUint(100);
    expect(rep["spent-reputation"]).toBeUint(0);
    expect(rep["last-updated"]).toHaveClarityType(ClarityType.UInt);

    const categories = unwrapTuple(rep["category-scores"]);
    expect(categories.technical).toBeUint(100);
    expect(categories.community).toBeUint(0);
    expect(categories.governance).toBeUint(0);
    expect(categories.creativity).toBeUint(0);

    expect(() =>
      simnet.callPublicFn(
        CONTRACT,
        "deduct-points",
        [principal(wallet1), Cl.uint(30), Cl.stringAscii("penalty")],
        deployer,
      ),
    ).toThrow(/ArithmeticUnderflow/);

    const repAfter = unwrapTuple(unwrapOptional(getUserReputation(wallet1)));
    expect(repAfter["total-score"]).toBeUint(100);
    expect(repAfter["spent-reputation"]).toBeUint(0);
    expect(repAfter["last-updated"]).toHaveClarityType(ClarityType.UInt);
  });

  it("creates and awards achievements", () => {
    const create = simnet.callPublicFn(
      CONTRACT,
      "create-achievement",
      [
        Cl.stringAscii("founding"),
        Cl.stringAscii("first user achievement"),
        Cl.uint(50),
        Cl.stringAscii("community"),
        Cl.uint(0),
      ],
      deployer,
    );
    expect(create.result).toBeOk(Cl.uint(1));

    const award = simnet.callPublicFn(
      CONTRACT,
      "award-achievement",
      [principal(wallet2), Cl.uint(1)],
      deployer,
    );
    expect(award.result).toBeOk(Cl.bool(true));

    const rep = unwrapTuple(unwrapOptional(getUserReputation(wallet2)));
    expect(rep["total-score"]).toBeUint(50);
    expect(rep["spent-reputation"]).toBeUint(0);
    expect(rep["last-updated"]).toHaveClarityType(ClarityType.UInt);

    const categories = unwrapTuple(rep["category-scores"]);
    expect(categories.technical).toBeUint(0);
    expect(categories.community).toBeUint(50);
    expect(categories.governance).toBeUint(0);
    expect(categories.creativity).toBeUint(0);

    const doubleAward = simnet.callPublicFn(
      CONTRACT,
      "award-achievement",
      [principal(wallet2), Cl.uint(1)],
      deployer,
    );
    expect(doubleAward.result).toBeErr(Cl.uint(ERR_ALREADY_EARNED));
  });

  it("creates services and surfaces purchase underflow", () => {
    const createService = simnet.callPublicFn(
      CONTRACT,
      "create-service",
      [
        Cl.stringAscii("consulting"),
        Cl.stringAscii("1h session"),
        Cl.uint(100),
        Cl.tuple({
          technical: Cl.uint(0),
          community: Cl.uint(0),
          governance: Cl.uint(0),
          creativity: Cl.uint(0),
        }),
      ],
      deployer,
    );
    expect(createService.result).toBeOk(Cl.uint(1));

    const details = simnet.callReadOnlyFn(CONTRACT, "get-service-details", [Cl.uint(1)], deployer);
    const serviceData = unwrapTuple(unwrapOptional(details.result));
    expect(serviceData.name).toBeAscii("consulting");
    expect(serviceData["reputation-cost"]).toBeUint(100);
    expect(serviceData["is-active"]).toBeBool(true);

    const fund = simnet.callPublicFn(
      CONTRACT,
      "award-points",
      [principal(wallet1), Cl.uint(150), Cl.stringAscii("technical"), Cl.stringAscii("fund")],
      deployer,
    );
    expect(fund.result).toBeOk(Cl.bool(true));

    expect(() => simnet.callPublicFn(CONTRACT, "purchase-service", [Cl.uint(1)], wallet1)).toThrow(
      /ArithmeticUnderflow/,
    );
  });

  it("creates proposals and records votes", () => {
    const fund = simnet.callPublicFn(
      CONTRACT,
      "award-points",
      [principal(wallet1), Cl.uint(120), Cl.stringAscii("governance"), Cl.stringAscii("threshold")],
      deployer,
    );
    expect(fund.result).toBeOk(Cl.bool(true));

    const proposal = simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [Cl.stringAscii("new-rule"), Cl.stringAscii("update policy"), Cl.stringAscii("policy")],
      wallet1,
    );
    expect(proposal.result).toBeOk(Cl.uint(1));

    const voterFund = simnet.callPublicFn(
      CONTRACT,
      "award-points",
      [principal(wallet2), Cl.uint(50), Cl.stringAscii("governance"), Cl.stringAscii("vote")],
      deployer,
    );
    expect(voterFund.result).toBeOk(Cl.bool(true));

    const vote = simnet.callPublicFn(CONTRACT, "vote-on-proposal", [Cl.uint(1), Cl.bool(true)], wallet2);
    expect(vote.result).toBeOk(Cl.bool(true));

    const details = simnet.callReadOnlyFn(CONTRACT, "get-proposal-details", [Cl.uint(1)], deployer);
    const proposalData = unwrapTuple(unwrapOptional(details.result));
    expect(proposalData.title).toBeAscii("new-rule");
    expect(proposalData.description).toBeAscii("update policy");
    expect(proposalData.proposer).toBePrincipal(wallet1);
    expect(proposalData["created-at"]).toHaveClarityType(ClarityType.UInt);
    expect(proposalData["voting-ends-at"]).toHaveClarityType(ClarityType.UInt);
    expect(proposalData["votes-for"]).toBeUint(50);
    expect(proposalData["votes-against"]).toBeUint(0);
    expect(proposalData.executed).toBeBool(false);
    expect(proposalData["proposal-type"]).toBeAscii("policy");
  });

  it("runs rehabilitation and rewards mentor bonus", () => {
    const mentorFund = simnet.callPublicFn(
      CONTRACT,
      "award-points",
      [principal(wallet2), Cl.uint(600), Cl.stringAscii("community"), Cl.stringAscii("mentor")],
      deployer,
    );
    expect(mentorFund.result).toBeOk(Cl.bool(true));

    const start = simnet.callPublicFn(
      CONTRACT,
      "start-rehabilitation-program",
      [principal(wallet1), Cl.stringAscii("minor"), Cl.stringAscii("penalty")],
      deployer,
    );
    expect(start.result).toBeOk(Cl.bool(true));

    const assign = simnet.callPublicFn(
      CONTRACT,
      "assign-mentor",
      [principal(wallet1), principal(wallet2)],
      deployer,
    );
    expect(assign.result).toBeOk(Cl.bool(true));

    for (let i = 0; i < 5; i += 1) {
      const action = simnet.callPublicFn(
        CONTRACT,
        "complete-rehabilitation-action",
        [principal(wallet1), Cl.stringAscii(`task-${i + 1}`)],
        deployer,
      );
      expect(action.result).toBeOk(Cl.bool(true));
    }

    const rehab = simnet.callReadOnlyFn(
      CONTRACT,
      "get-user-rehabilitation-status",
      [principal(wallet1)],
      deployer,
    );
    const rehabData = unwrapTuple(unwrapOptional(rehab.result));
    expect(rehabData["program-type"]).toBeAscii("minor");
    expect(rehabData["start-block"]).toHaveClarityType(ClarityType.UInt);
    expect(rehabData["end-block"]).toHaveClarityType(ClarityType.UInt);
    expect(rehabData["required-actions"]).toBeUint(5);
    expect(rehabData["completed-actions"]).toBeUint(5);
    expect(rehabData.mentor).toBeSome(principal(wallet2));
    expect(rehabData["recovery-multiplier"]).toBeUint(20);
    expect(rehabData["is-active"]).toBeBool(false);
    expect(rehabData["penalty-reason"]).toBeAscii("penalty");

    const mentorRep = unwrapTuple(unwrapOptional(getUserReputation(wallet2)));
    expect(mentorRep["total-score"]).toBeUint(610);
    expect(mentorRep["spent-reputation"]).toBeUint(0);
    expect(mentorRep["last-updated"]).toHaveClarityType(ClarityType.UInt);

    const mentorCategories = unwrapTuple(mentorRep["category-scores"]);
    expect(mentorCategories.technical).toBeUint(0);
    expect(mentorCategories.community).toBeUint(610);
    expect(mentorCategories.governance).toBeUint(0);
    expect(mentorCategories.creativity).toBeUint(0);
  });

  it("blocks state changes while paused", () => {
    const pause = simnet.callPublicFn(CONTRACT, "pause-contract", [], deployer);
    expect(pause.result).toBeOk(Cl.bool(true));

    const award = simnet.callPublicFn(
      CONTRACT,
      "award-points",
      [principal(wallet1), Cl.uint(10), Cl.stringAscii("technical"), Cl.stringAscii("paused")],
      deployer,
    );
    expect(award.result).toBeErr(Cl.uint(ERR_SYSTEM_PAUSED));
  });

  it("delegates voting power with reputation checks", () => {
    const noRep = simnet.callPublicFn(
      CONTRACT,
      "delegate-voting-power",
      [principal(wallet2)],
      wallet1,
    );
    expect(noRep.result).toBeErr(Cl.uint(ERR_INSUFFICIENT_REPUTATION));

    const fund = simnet.callPublicFn(
      CONTRACT,
      "award-points",
      [principal(wallet1), Cl.uint(25), Cl.stringAscii("governance"), Cl.stringAscii("delegate")],
      deployer,
    );
    expect(fund.result).toBeOk(Cl.bool(true));

    const selfDelegate = simnet.callPublicFn(
      CONTRACT,
      "delegate-voting-power",
      [principal(wallet1)],
      wallet1,
    );
    expect(selfDelegate.result).toBeErr(Cl.uint(ERR_SELF_DELEGATION));

    const delegate = simnet.callPublicFn(
      CONTRACT,
      "delegate-voting-power",
      [principal(wallet2)],
      wallet1,
    );
    expect(delegate.result).toBeOk(Cl.bool(true));

    const delegation = simnet.getMapEntry(
      CONTRACT,
      "delegations",
      Cl.tuple({ delegator: principal(wallet1) }),
    );
    const delegationData = unwrapTuple(unwrapOptional(delegation));
    expect(delegationData.delegate).toBePrincipal(wallet2);
    expect(delegationData["voting-power"]).toBeUint(25);
    expect(delegationData["delegated-at"]).toHaveClarityType(ClarityType.UInt);
  });

  it("updates emergency admin and toggles emergency mode", () => {
    const setAdmin = simnet.callPublicFn(
      CONTRACT,
      "set-emergency-admin",
      [principal(wallet1)],
      deployer,
    );
    expect(setAdmin.result).toBeOk(Cl.bool(true));

    const activate = simnet.callPublicFn(
      CONTRACT,
      "activate-emergency-mode",
      [Cl.stringAscii("maintenance")],
      wallet1,
    );
    expect(activate.result).toBeOk(Cl.bool(true));

    const activeStatus = simnet.callReadOnlyFn(CONTRACT, "get-contract-status", [], deployer);
    const activeData = unwrapTuple(activeStatus.result);
    expect(activeData["emergency-mode"]).toBeBool(true);
    expect(activeData["emergency-admin"]).toBePrincipal(wallet1);

    const deactivate = simnet.callPublicFn(CONTRACT, "deactivate-emergency-mode", [], wallet1);
    expect(deactivate.result).toBeOk(Cl.bool(true));

    const inactiveStatus = simnet.callReadOnlyFn(CONTRACT, "get-contract-status", [], deployer);
    const inactiveData = unwrapTuple(inactiveStatus.result);
    expect(inactiveData["emergency-mode"]).toBeBool(false);
  });
});
