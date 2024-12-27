import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a new challenge",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("pixel_pulse", "create-challenge", [
                types.ascii("Test Challenge"),
                types.uint(1000),
                types.uint(100)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk();
        assertEquals(block.receipts[0].result.expectOk(), types.uint(0));
    }
});

Clarinet.test({
    name: "Can submit video to challenge and vote",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet1 = accounts.get("wallet_1")!;
        
        // First create a challenge
        let block = chain.mineBlock([
            Tx.contractCall("pixel_pulse", "create-challenge", [
                types.ascii("Test Challenge"),
                types.uint(1000),
                types.uint(100)
            ], deployer.address),
            
            // Submit video
            Tx.contractCall("pixel_pulse", "submit-video", [
                types.ascii("Test Video"),
                types.uint(0)
            ], wallet1.address),
            
            // Vote on video
            Tx.contractCall("pixel_pulse", "vote-video", [
                types.uint(0)
            ], deployer.address)
        ]);
        
        block.receipts.forEach(receipt => {
            receipt.result.expectOk();
        });
    }
});

Clarinet.test({
    name: "Can complete challenge and receive reward",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("pixel_pulse", "create-challenge", [
                types.ascii("Test Challenge"),
                types.uint(1000),
                types.uint(100)
            ], deployer.address),
            
            Tx.contractCall("pixel_pulse", "complete-challenge", [
                types.uint(0)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
    }
});