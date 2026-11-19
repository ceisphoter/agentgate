# AgentGate 🛡️

**Agent ID gated campaigns, claims and daily check-ins on BNB Chain.**
One address, one claim — sybil-resistant by design.

🌐 **Live app:** https://ceisphoter.github.io/agentgate/
📜 **Contract (BNB Chain):** `TO_BE_FILLED_AFTER_DEPLOYMENT`
🔎 **Agent ID contract:** `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (SPACE ID Agent ID, ERC-721)

Built for the **Binance Wallet × BNB Chain Agent ID Hackathon** (Nov–Dec 2026).

## The problem

Airdrops, allowlists, beta invites and community rewards are drowning in sybil
farms: one person spins up hundreds of fresh wallets and drains allocations
meant for real users. Projects fight back with captchas, social tasks and
manual reviews — all off-chain, all gameable.

## The AgentGate answer

Agent ID is the on-chain identity of an Agentic Wallet: one non-transferable
`name.ai` NFT per user, claimed inside the Binance App. AgentGate turns that
identity into a **permissionless on-chain gate**:

- **Anyone** can open a campaign (title, link, time window, claim cap).
- **Only Agent ID holders can claim** — the contract checks
  `balanceOf(claimer) > 0` on the official Agent ID contract, on-chain,
  at the moment of the claim. No lists, no servers, no screenshots.
- **One claim per Agent ID address per campaign**, recorded permanently —
  a public, auditable participation proof anyone can verify.
- **Daily check-ins** give verified agents a reason to return, and give
  projects a live signal of how many *real* Agent IDs are active.

Because an Agent ID is one-per-person and non-transferable, a campaign on
AgentGate is sybil-resistant by construction, not by policy.

## How Agent ID is used (core, not decoration)

| Use | Where |
| --- | --- |
| Access control for claims | `claim()` reverts unless `agentId.balanceOf(msg.sender) > 0` |
| Access control for check-ins | `checkIn()` has the same on-chain gate |
| Public identity signal | `isAgentHolder(address)` view for any integrator |
| Sybil-resistant metrics | `uniqueClaimers` counts distinct Agent ID addresses, not wallets-created-yesterday |

The Agent ID contract address is an **immutable** constructor argument —
the gate can never be quietly repointed.

## Safety design (hackathon red lines, respected by architecture)

- The contract is **not payable** and never holds, moves, or approves user
  assets. Claims are free; there are no transfers and no allowances at all.
- There is **no contract owner and no admin function**. The only privileged
  role is a campaign's own creator closing *their own* campaign — disclosed
  here and in the source.
- No QR-code / pairing-code login, no session storage, no credential
  collection: the web app talks to the user's own wallet through the
  standard injected provider, and every transaction is shown and confirmed
  by the user in their wallet.
- No promises of returns anywhere. AgentGate is a tool, not an investment.

## Repository layout

```
src/AgentGate.sol     the contract (MIT, Solidity 0.8.24)
test/AgentGate.t.sol  Foundry tests — 9/9 passing
docs/                 the static web app (GitHub Pages)
```

## Build & test

```bash
forge install
forge test
```

## Verify the deployment yourself

```bash
cast call <AGENTGATE_ADDRESS> "agentId()(address)" --rpc-url https://bsc-dataseed.bnbchain.org
# → 0x60b9262456de011f7d15a54cdd8c48baaa8b022f
```

## License

MIT
