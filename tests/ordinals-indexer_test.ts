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

Clarinet.test({
    name: "Test enhanced storage statistics and validation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        // Test enhanced storage statistics
        let block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'get-storage-statistics', [], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        const stats = block.receipts[0].result.expectOk();

        // Test content type validation
        block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'is-valid-content-type', [
                types.ascii('image/png')
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, types.bool(true));

        // Test invalid content type
        block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'is-valid-content-type', [
                types.ascii('invalid-type')
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, types.bool(false));
    },
});

Clarinet.test({
    name: "Test batch processing functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;

        // Create batch of ordinals
        const batchData = [
            {
                'inscription-id': types.buff('0x1111111111111111111111111111111111111111111111111111111111111111'),
                'content-type': types.ascii('image/png'),
                'content-size': types.uint(1024),
                'owner': types.principal(wallet1.address),
                'bitcoin-tx-hash': types.buff('0x1111222233334444555566667777888899990000'),
                'bitcoin-block-height': types.uint(800010),
                'metadata-uri': types.none()
            },
            {
                'inscription-id': types.buff('0x2222222222222222222222222222222222222222222222222222222222222222'),
                'content-type': types.ascii('text/plain'),
                'content-size': types.uint(512),
                'owner': types.principal(wallet2.address),
                'bitcoin-tx-hash': types.buff('0x2222333344445555666677778888999900001111'),
                'bitcoin-block-height': types.uint(800011),
                'metadata-uri': types.none()
            }
        ];

        // Test batch indexing
        let block = chain.mineBlock([
            Tx.contractCall('ordinals-indexer', 'batch-index-ordinals', [
                types.list(batchData.map(data => types.tuple(data)))
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();

        // Verify batch statistics
        block = chain.mineBlock([
            Tx.contractCall('ordinals-indexer', 'get-indexing-stats', [], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        const batchStats = block.receipts[0].result.expectOk();

        // Verify storage statistics updated
        block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'get-storage-statistics', [], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        const storageStats = block.receipts[0].result.expectOk();
    },
});

Clarinet.test({
    name: "Test enhanced validation and error handling",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        // Test invalid content size (too large)
        let block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'add-ordinal', [
                types.buff('0x3333333333333333333333333333333333333333333333333333333333333333'),
                types.ascii('image/png'),
                types.uint(104857601), // Exceeds MAX_CONTENT_SIZE
                types.principal(wallet1.address),
                types.buff('0x3333444455556666777788889999000011112222'),
                types.uint(800020),
                types.none()
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectErr(types.uint(106)); // ERR_INVALID_SIZE_RANGE

        // Test invalid content size (too small)
        block = chain.mineBlock([
            Tx.contractCall('ordinals-storage', 'add-ordinal', [
                types.buff('0x4444444444444444444444444444444444444444444444444444444444444444'),
                types.ascii('image/png'),
                types.uint(0), // Below MIN_CONTENT_SIZE
                types.principal(wallet1.address),
                types.buff('0x4444555566667777888899990000111122223333'),
                types.uint(800021),
                types.none()
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectErr(types.uint(106)); // ERR_INVALID_SIZE_RANGE
    },
});

Clarinet.test({
    name: "Test Bitcoin block header submission and verification",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;

        // Test submitting Bitcoin block header
        const blockHeight = 800050;
        const blockHash = '0x1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
        const previousBlockHash = '0x0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff';
        const merkleRoot = '0xaaaabbbbccccddddeeeeffff1111222233334444555566667777888899990000';

        let block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'submit-bitcoin-block-header', [
                types.uint(blockHeight),
                types.buff(blockHash),
                types.buff(previousBlockHash),
                types.buff(merkleRoot),
                types.uint(1640995200), // timestamp
                types.uint(404472624), // difficulty
                types.uint(123456789)   // nonce
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();

        // Verify the block header was stored
        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'get-bitcoin-block-header', [
                types.uint(blockHeight)
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        const headerData = block.receipts[0].result.expectSome();

        // Test block header verification
        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'verify-bitcoin-block-header', [
                types.uint(blockHeight)
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
    },
});

Clarinet.test({
    name: "Test Merkle proof submission and verification",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;

        // First submit and verify a block header
        const blockHeight = 800051;
        const blockHash = '0x2222333344445555666677778888999900001111aaaabbbbccccddddeeeeffff';
        const previousBlockHash = '0x1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
        const merkleRoot = '0xbbbbccccddddeeeeffff2222333344445555666677778888999900001111aaaa';

        let block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'submit-bitcoin-block-header', [
                types.uint(blockHeight),
                types.buff(blockHash),
                types.buff(previousBlockHash),
                types.buff(merkleRoot),
                types.uint(1640995800),
                types.uint(404472624),
                types.uint(987654321)
            ], deployer.address)
        ]);

        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'verify-bitcoin-block-header', [
                types.uint(blockHeight)
            ], deployer.address)
        ]);

        // Now test Merkle proof submission
        const txHash = '0x3333444455556666777788889999000011112222aaaabbbbccccddddeeeeffff';
        const merklePath = [
            '0x4444555566667777888899990000111122223333aaaabbbbccccddddeeeeffff',
            '0x5555666677778888999900001111222233334444aaaabbbbccccddddeeeeffff'
        ];

        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'submit-merkle-proof', [
                types.buff(txHash),
                types.uint(blockHeight),
                types.list(merklePath.map(path => types.buff(path))),
                types.uint(0) // tx index
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();

        // Verify Merkle proof
        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'verify-merkle-proof', [
                types.buff(txHash)
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
    },
});

Clarinet.test({
    name: "Test sBTC deposit creation and confirmation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        // First create a verified Bitcoin transaction
        const bitcoinTxHash = '0x4444555566667777888899990000111122223333aaaabbbbccccddddeeeeffff';

        // Submit for verification (simplified)
        let block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'submit-bitcoin-tx-for-verification', [
                types.buff(bitcoinTxHash),
                types.uint(800052),
                types.list([
                    types.tuple({
                        'inscription-id': types.buff('0x5555555555555555555555555555555555555555555555555555555555555555'),
                        'content-type': types.ascii('image/png'),
                        'content-size': types.uint(1024),
                        'owner': types.principal(wallet1.address)
                    })
                ])
            ], wallet1.address)
        ]);

        // Verify the transaction
        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'verify-bitcoin-transaction', [
                types.buff(bitcoinTxHash),
                types.uint(6) // confirmations
            ], deployer.address)
        ]);

        // Create sBTC deposit
        const depositAmount = 100000; // 0.001 BTC
        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'create-sbtc-deposit', [
                types.buff(bitcoinTxHash),
                types.principal(wallet1.address),
                types.uint(depositAmount)
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        const depositId = block.receipts[0].result.expectOk();

        // Confirm the deposit
        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'confirm-sbtc-deposit', [
                depositId
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();

        // Check deposit status
        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'get-sbtc-deposit', [
                depositId
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        const depositData = block.receipts[0].result.expectSome();
    },
});

Clarinet.test({
    name: "Test Bitcoin-verified ordinal indexing",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        // First create a verified Bitcoin transaction (simplified setup)
        const bitcoinTxHash = '0x6666777788889999000011112222333344445555aaaabbbbccccddddeeeeffff';

        // Submit and verify Bitcoin transaction
        let block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'submit-bitcoin-tx-for-verification', [
                types.buff(bitcoinTxHash),
                types.uint(800053),
                types.list([
                    types.tuple({
                        'inscription-id': types.buff('0x6666666666666666666666666666666666666666666666666666666666666666'),
                        'content-type': types.ascii('text/plain'),
                        'content-size': types.uint(512),
                        'owner': types.principal(wallet1.address)
                    })
                ])
            ], wallet1.address)
        ]);

        block = chain.mineBlock([
            Tx.contractCall('sbtc-bridge', 'verify-bitcoin-transaction', [
                types.buff(bitcoinTxHash),
                types.uint(6)
            ], deployer.address)
        ]);

        // Test Bitcoin-verified ordinal indexing
        const inscriptionId = '0x6666666666666666666666666666666666666666666666666666666666666666';
        block = chain.mineBlock([
            Tx.contractCall('ordinals-indexer', 'index-bitcoin-verified-ordinal', [
                types.buff(inscriptionId),
                types.ascii('text/plain'),
                types.uint(512),
                types.principal(wallet1.address),
                types.buff(bitcoinTxHash),
                types.uint(800053),
                types.none()
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();

        // Check enhanced indexing statistics
        block = chain.mineBlock([
            Tx.contractCall('ordinals-indexer', 'get-indexing-stats', [], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        const stats = block.receipts[0].result.expectOk();

        // Check system status
        block = chain.mineBlock([
            Tx.contractCall('ordinals-indexer', 'get-system-status', [], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        const systemStatus = block.receipts[0].result.expectOk();
    },
});
