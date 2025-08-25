;; sBTC Bridge Contract for Bitcoin Ordinals Integration
;; Handles Bitcoin transaction verification and cross-chain operations

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_BITCOIN_TX (err u301))
(define-constant ERR_VERIFICATION_FAILED (err u302))
(define-constant ERR_BRIDGE_INACTIVE (err u303))
(define-constant ERR_INSUFFICIENT_CONFIRMATIONS (err u304))

;; Minimum Bitcoin confirmations required
(define-constant MIN_BITCOIN_CONFIRMATIONS u6)

;; Data Variables
(define-data-var bridge-active bool true)
(define-data-var sbtc-contract principal tx-sender)
(define-data-var min-confirmations uint MIN_BITCOIN_CONFIRMATIONS)

;; Bitcoin Transaction Verification Storage
(define-map verified-bitcoin-txs
  { bitcoin-tx-hash: (buff 32) }
  {
    block-height: uint,
    confirmations: uint,
    verified-at: uint,
    ordinals-count: uint,
    is-valid: bool
  }
)

;; Pending Bitcoin Transactions
(define-map pending-bitcoin-txs
  { bitcoin-tx-hash: (buff 32) }
  {
    submitted-at: uint,
    submitter: principal,
    block-height: uint,
    ordinal-data: (list 10 {
      inscription-id: (buff 64),
      content-type: (string-ascii 50),
      content-size: uint,
      owner: principal
    })
  }
)

;; sBTC Operations Log
(define-map sbtc-operations
  { operation-id: uint }
  {
    operation-type: (string-ascii 20),
    bitcoin-tx-hash: (buff 32),
    stacks-tx-hash: (buff 32),
    amount: uint,
    status: (string-ascii 10),
    created-at: uint
  }
)

(define-data-var next-operation-id uint u1)

;; Read-only functions

;; Check if Bitcoin transaction is verified
(define-read-only (is-bitcoin-tx-verified (bitcoin-tx-hash (buff 32)))
  (match (map-get? verified-bitcoin-txs { bitcoin-tx-hash: bitcoin-tx-hash })
    tx-data (get is-valid tx-data)
    false
  )
)

;; Get Bitcoin transaction verification details
(define-read-only (get-bitcoin-tx-verification (bitcoin-tx-hash (buff 32)))
  (map-get? verified-bitcoin-txs { bitcoin-tx-hash: bitcoin-tx-hash })
)

;; Get pending Bitcoin transaction
(define-read-only (get-pending-bitcoin-tx (bitcoin-tx-hash (buff 32)))
  (map-get? pending-bitcoin-txs { bitcoin-tx-hash: bitcoin-tx-hash })
)

;; Check bridge status
(define-read-only (get-bridge-status)
  {
    active: (var-get bridge-active),
    sbtc-contract: (var-get sbtc-contract),
    min-confirmations: (var-get min-confirmations)
  }
)

;; Get sBTC operation details
(define-read-only (get-sbtc-operation (operation-id uint))
  (map-get? sbtc-operations { operation-id: operation-id })
)

;; Public functions

;; Submit Bitcoin transaction for verification
(define-public (submit-bitcoin-tx-for-verification
  (bitcoin-tx-hash (buff 32))
  (bitcoin-block-height uint)
  (ordinal-data (list 10 {
    inscription-id: (buff 64),
    content-type: (string-ascii 50),
    content-size: uint,
    owner: principal
  }))
)
  (let (
    (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    ;; Check if bridge is active
    (asserts! (var-get bridge-active) ERR_BRIDGE_INACTIVE)
    
    ;; Validate Bitcoin transaction hash
    (asserts! (is-eq (len bitcoin-tx-hash) u32) ERR_INVALID_BITCOIN_TX)
    (asserts! (> bitcoin-block-height u0) ERR_INVALID_BITCOIN_TX)
    
    ;; Check if transaction is not already pending or verified
    (asserts! (is-none (get-pending-bitcoin-tx bitcoin-tx-hash)) ERR_INVALID_BITCOIN_TX)
    (asserts! (not (is-bitcoin-tx-verified bitcoin-tx-hash)) ERR_INVALID_BITCOIN_TX)
    
    ;; Store pending transaction
    (map-set pending-bitcoin-txs
      { bitcoin-tx-hash: bitcoin-tx-hash }
      {
        submitted-at: current-timestamp,
        submitter: tx-sender,
        block-height: bitcoin-block-height,
        ordinal-data: ordinal-data
      }
    )
    
    (ok bitcoin-tx-hash)
  )
)

;; Verify Bitcoin transaction (simulated - in production would use Bitcoin SPV)
(define-public (verify-bitcoin-transaction
  (bitcoin-tx-hash (buff 32))
  (confirmations uint)
)
  (let (
    (pending-tx (unwrap! (get-pending-bitcoin-tx bitcoin-tx-hash) ERR_INVALID_BITCOIN_TX))
    (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    ;; Only contract owner can verify (in production, this would be automated)
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Check minimum confirmations
    (asserts! (>= confirmations (var-get min-confirmations)) ERR_INSUFFICIENT_CONFIRMATIONS)
    
    ;; Mark transaction as verified
    (map-set verified-bitcoin-txs
      { bitcoin-tx-hash: bitcoin-tx-hash }
      {
        block-height: (get block-height pending-tx),
        confirmations: confirmations,
        verified-at: current-timestamp,
        ordinals-count: (len (get ordinal-data pending-tx)),
        is-valid: true
      }
    )
    
    ;; Remove from pending
    (map-delete pending-bitcoin-txs { bitcoin-tx-hash: bitcoin-tx-hash })
    
    ;; Process ordinals indexing
    (try! (process-verified-ordinals bitcoin-tx-hash (get ordinal-data pending-tx)))
    
    (ok true)
  )
)

;; Create sBTC operation record
(define-public (create-sbtc-operation
  (operation-type (string-ascii 20))
  (bitcoin-tx-hash (buff 32))
  (stacks-tx-hash (buff 32))
  (amount uint)
)
  (let (
    (operation-id (var-get next-operation-id))
    (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    ;; Only authorized contracts can create operations
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) 
                  (is-eq tx-sender (var-get sbtc-contract))) ERR_UNAUTHORIZED)
    
    ;; Store operation
    (map-set sbtc-operations
      { operation-id: operation-id }
      {
        operation-type: operation-type,
        bitcoin-tx-hash: bitcoin-tx-hash,
        stacks-tx-hash: stacks-tx-hash,
        amount: amount,
        status: "pending",
        created-at: current-timestamp
      }
    )
    
    ;; Increment operation ID
    (var-set next-operation-id (+ operation-id u1))
    
    (ok operation-id)
  )
)

;; Update sBTC operation status
(define-public (update-sbtc-operation-status
  (operation-id uint)
  (new-status (string-ascii 10))
)
  (let (
    (operation (unwrap! (get-sbtc-operation operation-id) ERR_INVALID_BITCOIN_TX))
  )
    ;; Only contract owner can update status
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Update operation status
    (map-set sbtc-operations
      { operation-id: operation-id }
      (merge operation { status: new-status })
    )
    
    (ok true)
  )
)

;; Private helper functions

;; Process verified ordinals by calling the indexer
(define-private (process-verified-ordinals
  (bitcoin-tx-hash (buff 32))
  (ordinal-data (list 10 {
    inscription-id: (buff 64),
    content-type: (string-ascii 50),
    content-size: uint,
    owner: principal
  }))
)
  (let (
    (bitcoin-block-height (unwrap-panic 
                          (get block-height 
                               (unwrap-panic (get-bitcoin-tx-verification bitcoin-tx-hash)))))
  )
    ;; Process each ordinal in the transaction
    (fold process-single-verified-ordinal ordinal-data 
          { bitcoin-tx-hash: bitcoin-tx-hash, bitcoin-block-height: bitcoin-block-height })
    (ok true)
  )
)

;; Process single verified ordinal
(define-private (process-single-verified-ordinal
  (ordinal {
    inscription-id: (buff 64),
    content-type: (string-ascii 50),
    content-size: uint,
    owner: principal
  })
  (context {
    bitcoin-tx-hash: (buff 32),
    bitcoin-block-height: uint
  })
)
  (begin
    ;; Call the main indexer to store the ordinal
    (contract-call? .ordinals-indexer index-ordinal
                   (get inscription-id ordinal)
                   (get content-type ordinal)
                   (get content-size ordinal)
                   (get owner ordinal)
                   (get bitcoin-tx-hash context)
                   (get bitcoin-block-height context)
                   none)
    context
  )
)

;; Admin functions

;; Toggle bridge status
(define-public (toggle-bridge-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set bridge-active (not (var-get bridge-active)))
    (ok (var-get bridge-active))
  )
)

;; Update sBTC contract address
(define-public (update-sbtc-contract (new-sbtc-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set sbtc-contract new-sbtc-contract)
    (ok new-sbtc-contract)
  )
)

;; Update minimum confirmations requirement
(define-public (update-min-confirmations (new-min-confirmations uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= new-min-confirmations u1) ERR_INVALID_BITCOIN_TX)
    (var-set min-confirmations new-min-confirmations)
    (ok new-min-confirmations)
  )
)
