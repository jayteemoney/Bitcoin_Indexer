import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test ordinals storage contract initialization",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Test getting total ordinals (should be 0 initially)
        let block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'get-total-ordinals', [], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, types.uint(0));
        
        // Test contract active status
        block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'is-contract-active', [], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, types.bool(true));
    },
});

Clarinet.test({
    name: "Test adding a new ordinal to storage",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create test ordinal data
        const inscriptionId = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
        const contentType = 'image/png';
        const contentSize = 1024;
        const bitcoinTxHash = '0xabcdef1234567890abcdef1234567890abcdef12';
        const bitcoinBlockHeight = 800000;
        
        // Add ordinal
        let block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'add-ordinal', [
                types.buff(inscriptionId),
                types.ascii(contentType),
                types.uint(contentSize),
                types.principal(wallet1.address),
                types.buff(bitcoinTxHash),
                types.uint(bitcoinBlockHeight),
                types.none()
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
        
        // Verify ordinal was added
        block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'get-ordinal-data', [
                types.buff(inscriptionId)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        const ordinalData = block.receipts[0].result.expectSome();
        
        // Verify total count increased
        block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'get-total-ordinals', [], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, types.uint(1));
    },
});

Clarinet.test({
    name: "Test ordinals indexer main functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Test indexer status
        let block = chain.mineBlock([
            Tx.contractCall('ordinals-indexer', 'get-indexer-status', [], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        const status = block.receipts[0].result.expectOk();
        
        // Test indexing a new ordinal
        const inscriptionId = '0x9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba';
        const contentType = 'text/plain';
        const contentSize = 512;
        const bitcoinTxHash = '0xfedcba0987654321fedcba0987654321fedcba09';
        const bitcoinBlockHeight = 800001;
        
        block = chain.mineBlock([
            Tx.contractCall('ordinals-indexer', 'index-ordinal', [
                types.buff(inscriptionId),
                types.ascii(contentType),
                types.uint(contentSize),
                types.principal(wallet1.address),
                types.buff(bitcoinTxHash),
                types.uint(bitcoinBlockHeight),
                types.none()
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
        
        // Verify ordinal exists
        block = chain.mineBlock([
            Tx.contractCall('ordinals-indexer', 'ordinal-exists', [
                types.buff(inscriptionId)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, types.bool(true));
    },
});

Clarinet.test({
    name: "Test sBTC bridge functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Test bridge status
        let block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'get-bridge-status', [], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        const status = block.receipts[0].result.expectOk();
        
        // Test submitting Bitcoin transaction for verification
        const bitcoinTxHash = '0x1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
        const bitcoinBlockHeight = 800002;
        const ordinalData = [
            {
                'inscription-id': '0x1111111111111111111111111111111111111111111111111111111111111111',
                'content-type': 'image/jpeg',
                'content-size': types.uint(2048),
                'owner': wallet1.address
            }
        ];
        
        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'submit-bitcoin-tx-for-verification', [
                types.buff(bitcoinTxHash),
                types.uint(bitcoinBlockHeight),
                types.list([
                    types.tuple({
                        'inscription-id': types.buff('0x1111111111111111111111111111111111111111111111111111111111111111'),
                        'content-type': types.ascii('image/jpeg'),
                        'content-size': types.uint(2048),
                        'owner': types.principal(wallet1.address)
                    })
                ])
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
        
        // Verify transaction is pending
        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'get-pending-bitcoin-tx', [
                types.buff(bitcoinTxHash)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectSome();
    },
});

Clarinet.test({
    name: "Test search functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // First add an ordinal to search for
        const inscriptionId = '0x2222333344445555666677778888999900001111222233334444555566667777';
        const contentType = 'application/json';
        const contentSize = 256;
        const bitcoinTxHash = '0x2222333344445555666677778888999900001111';
        const bitcoinBlockHeight = 800003;
        
        let block = chain.mineBlock([
            Tx.contractCall('ordinals-indexer', 'index-ordinal', [
                types.buff(inscriptionId),
                types.ascii(contentType),
                types.uint(contentSize),
                types.principal(wallet1.address),
                types.buff(bitcoinTxHash),
                types.uint(bitcoinBlockHeight),
                types.none()
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
        
        // Test search by owner
        block = chain.mineBlock([
            Tx.contractCall('ordinals-search', 'search-by-owner', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        // Should return some results
        
        // Test search statistics
        block = chain.mineBlock([
            Tx.contractCall('ordinals-search', 'get-search-stats', [], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        const searchStats = block.receipts[0].result.expectOk();
    },
});
