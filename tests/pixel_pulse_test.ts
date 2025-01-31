import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a challenge with NFT reward",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("pixel_pulse", "create-challenge", [
                types.ascii("Test Challenge"),
                types.uint(1000),
                types.uint(100),
                types.some(types.ascii("ipfs://QmTest"))
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk();
        assertEquals(block.receipts[0].result.expectOk(), types.uint(0));
    }
});

Clarinet.test({
    name: "Can submit video, receive votes, and update stats",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("pixel_pulse", "create-challenge", [
                types.ascii("Test Challenge"),
                types.uint(1000),
                types.uint(100),
                types.none()
            ], deployer.address),
            
            Tx.contractCall("pixel_pulse", "submit-video", [
                types.ascii("Test Video"),
                types.uint(0)
            ], wallet1.address),
            
            Tx.contractCall("pixel_pulse", "vote-video", [
                types.uint(0)
            ], deployer.address)
        ]);
        
        block.receipts.forEach(receipt => {
            receipt.result.expectOk();
        });
        
        // Verify updated stats
        let stats = chain.callReadOnlyFn(
            "pixel_pulse",
            "get-user-stats",
            [types.principal(wallet1.address)],
            wallet1.address
        );
        
        assertEquals(stats.result.expectSome()['total-votes-received'], types.uint(1));
    }
});

Clarinet.test({
    name: "Can complete challenge, receive rewards and update leaderboard",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("pixel_pulse", "create-challenge", [
                types.ascii("Test Challenge"),
                types.uint(1000),
                types.uint(100),
                types.some(types.ascii("ipfs://QmTest"))
            ], deployer.address),
            
            Tx.contractCall("pixel_pulse", "complete-challenge", [
                types.uint(0)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        
        // Verify leaderboard entry
        let leaderboard = chain.callReadOnlyFn(
            "pixel_pulse",
            "get-leaderboard-entry",
            [types.principal(wallet1.address)],
            wallet1.address
        );
        
        assertEquals(leaderboard.result.expectSome()['challenges-won'], types.uint(1));
        assertEquals(leaderboard.result.expectSome()['nfts-earned'], types.uint(1));
    }
});

Clarinet.test({
    name: "Can transfer NFT reward",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        
        // Create challenge with NFT, complete it, then transfer NFT
        let block = chain.mineBlock([
            Tx.contractCall("pixel_pulse", "create-challenge", [
                types.ascii("Test Challenge"),
                types.uint(1000),
                types.uint(100),
                types.some(types.ascii("ipfs://QmTest"))
            ], deployer.address),
            
            Tx.contractCall("pixel_pulse", "complete-challenge", [
                types.uint(0)
            ], wallet1.address),
            
            Tx.contractCall("pixel_pulse", "transfer", [
                types.uint(0),
                types.principal(wallet1.address),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);
        
        block.receipts.forEach(receipt => {
            receipt.result.expectOk();
        });
        
        // Verify new NFT owner
        let nftOwner = chain.callReadOnlyFn(
            "pixel_pulse",
            "get-owner",
            [types.uint(0)],
            deployer.address
        );
        
        assertEquals(nftOwner.result.expectOk(), types.principal(wallet2.address));
    }
});
