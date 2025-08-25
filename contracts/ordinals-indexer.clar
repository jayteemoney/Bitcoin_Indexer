;; Bitcoin Ordinals Indexer Main Contract
;; Coordinates ordinals indexing operations and provides main API

;; Import storage contract
(use-trait storage-trait .ordinals-storage.storage-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_ORDINAL (err u201))
(define-constant ERR_INDEXING_FAILED (err u202))
(define-constant ERR_STORAGE_ERROR (err u203))
(define-constant ERR_BATCH_PROCESSING_DISABLED (err u204))
(define-constant ERR_INVALID_BATCH_SIZE (err u205))

;; Enhanced validation constants
(define-constant MAX_BATCH_SIZE u50)
(define-constant MIN_BATCH_SIZE u1)

;; Data Variables
(define-data-var indexer-version (string-ascii 10) "3.0.0")
(define-data-var indexing-active bool true)
(define-data-var last-indexed-block uint u0)
(define-data-var batch-indexing-enabled bool true)
(define-data-var sbtc-integration-enabled bool true)
(define-data-var last-bitcoin-sync-height uint u0)

;; Indexing Statistics
(define-data-var total-indexed uint u0)
(define-data-var successful-indexes uint u0)
(define-data-var failed-indexes uint u0)
(define-data-var batch-operations uint u0)
(define-data-var total-batch-items uint u0)
(define-data-var bitcoin-verified-ordinals uint u0)
(define-data-var sbtc-bridged-ordinals uint u0)

;; Events
(define-data-var ordinal-indexed-event 
  {
    inscription-id: (buff 64),
    owner: principal,
    block-height: uint,
    timestamp: uint
  }
  {
    inscription-id: 0x,
    owner: tx-sender,
    block-height: u0,
    timestamp: u0
  }
)

;; Read-only functions

;; Get indexer status
(define-read-only (get-indexer-status)
  {
    version: (var-get indexer-version),
    active: (var-get indexing-active),
    last-indexed-block: (var-get last-indexed-block),
    total-indexed: (var-get total-indexed),
    successful-indexes: (var-get successful-indexes),
    failed-indexes: (var-get failed-indexes)
  }
)

;; Get ordinal by inscription ID (proxy to storage)
(define-read-only (get-ordinal (inscription-id (buff 64)))
  (contract-call? .ordinals-storage get-ordinal-data inscription-id)
)

;; Get ordinals by owner (proxy to storage)
(define-read-only (get-user-ordinals (owner principal))
  (contract-call? .ordinals-storage get-ordinals-by-owner owner)
)

;; Get ordinals by content type (proxy to storage)
(define-read-only (get-ordinals-by-type (content-type (string-ascii 50)))
  (contract-call? .ordinals-storage get-ordinals-by-content-type content-type)
)

;; Check if ordinal exists
(define-read-only (ordinal-exists (inscription-id (buff 64)))
  (is-some (contract-call? .ordinals-storage get-ordinal-data inscription-id))
)

;; Public functions

;; Index a new Bitcoin Ordinal
(define-public (index-ordinal
  (inscription-id (buff 64))
  (content-type (string-ascii 50))
  (content-size uint)
  (owner principal)
  (bitcoin-tx-hash (buff 32))
  (bitcoin-block-height uint)
  (metadata-uri (optional (string-utf8 256)))
)
  (let (
    (current-block block-height)
  )
    ;; Check if indexing is active
    (asserts! (var-get indexing-active) ERR_UNAUTHORIZED)
    
    ;; Validate ordinal data
    (asserts! (> (len inscription-id) u0) ERR_INVALID_ORDINAL)
    (asserts! (> content-size u0) ERR_INVALID_ORDINAL)
    (asserts! (> bitcoin-block-height u0) ERR_INVALID_ORDINAL)
    
    ;; Check if ordinal already exists
    (asserts! (not (ordinal-exists inscription-id)) ERR_INVALID_ORDINAL)
    
    ;; Store ordinal in storage contract
    (match (contract-call? .ordinals-storage add-ordinal
                          inscription-id
                          content-type
                          content-size
                          owner
                          bitcoin-tx-hash
                          bitcoin-block-height
                          metadata-uri)
      success (begin
        ;; Update statistics
        (var-set total-indexed (+ (var-get total-indexed) u1))
        (var-set successful-indexes (+ (var-get successful-indexes) u1))
        (var-set last-indexed-block (max (var-get last-indexed-block) bitcoin-block-height))
        
        ;; Emit indexing event
        (var-set ordinal-indexed-event {
          inscription-id: inscription-id,
          owner: owner,
          block-height: current-block,
          timestamp: (unwrap-panic (get-block-info? time (- block-height u1)))
        })
        
        (ok inscription-id)
      )
      error (begin
        ;; Update failed statistics
        (var-set failed-indexes (+ (var-get failed-indexes) u1))
        (err ERR_STORAGE_ERROR)
      )
    )
  )
)

;; Enhanced batch index multiple ordinals
(define-public (batch-index-ordinals
  (ordinals-list (list 50 {
    inscription-id: (buff 64),
    content-type: (string-ascii 50),
    content-size: uint,
    owner: principal,
    bitcoin-tx-hash: (buff 32),
    bitcoin-block-height: uint,
    metadata-uri: (optional (string-utf8 256))
  }))
)
  (let (
    (batch-size (len ordinals-list))
    (current-block block-height)
  )
    ;; Enhanced validation
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (var-get indexing-active) ERR_UNAUTHORIZED)
    (asserts! (var-get batch-indexing-enabled) ERR_BATCH_PROCESSING_DISABLED)
    (asserts! (and (>= batch-size MIN_BATCH_SIZE)
                   (<= batch-size MAX_BATCH_SIZE)) ERR_INVALID_BATCH_SIZE)

    ;; Use storage contract's batch functionality
    (match (contract-call? .ordinals-storage batch-add-ordinals ordinals-list)
      success (begin
        ;; Update batch statistics
        (var-set batch-operations (+ (var-get batch-operations) u1))
        (var-set total-batch-items (+ (var-get total-batch-items) batch-size))
        (var-set successful-indexes (+ (var-get successful-indexes)
                                      (get successful success)))
        (var-set failed-indexes (+ (var-get failed-indexes)
                                  (get failed success)))
        (var-set total-indexed (+ (var-get total-indexed) batch-size))

        (ok success)
      )
      error (begin
        (var-set failed-indexes (+ (var-get failed-indexes) batch-size))
        (err ERR_STORAGE_ERROR)
      )
    )
  )
)

;; Index Bitcoin-verified ordinal with sBTC integration
(define-public (index-bitcoin-verified-ordinal
  (inscription-id (buff 64))
  (content-type (string-ascii 50))
  (content-size uint)
  (owner principal)
  (bitcoin-tx-hash (buff 32))
  (bitcoin-block-height uint)
  (metadata-uri (optional (string-utf8 256)))
)
  (let (
    (current-block block-height)
  )
    ;; Check if indexing and sBTC integration are active
    (asserts! (var-get indexing-active) ERR_UNAUTHORIZED)
    (asserts! (var-get sbtc-integration-enabled) ERR_UNAUTHORIZED)

    ;; Verify Bitcoin transaction through sBTC bridge
    (asserts! (contract-call? .sbtc-bridge is-bitcoin-tx-verified bitcoin-tx-hash) ERR_STORAGE_ERROR)

    ;; Index the ordinal using standard process
    (match (index-ordinal inscription-id content-type content-size owner
                        bitcoin-tx-hash bitcoin-block-height metadata-uri)
      success (begin
        ;; Update Bitcoin-specific statistics
        (var-set bitcoin-verified-ordinals (+ (var-get bitcoin-verified-ordinals) u1))
        (var-set last-bitcoin-sync-height (max (var-get last-bitcoin-sync-height) bitcoin-block-height))

        (ok success)
      )
      error (err error)
    )
  )
)

;; Sync ordinals from sBTC bridge
(define-public (sync-ordinals-from-sbtc-bridge
  (bitcoin-tx-hash (buff 32))
)
  (let (
    (bridge-status (contract-call? .sbtc-bridge get-bridge-status))
  )
    ;; Only contract owner can sync
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (var-get sbtc-integration-enabled) ERR_UNAUTHORIZED)

    ;; Check if Bitcoin transaction is verified in bridge
    (asserts! (contract-call? .sbtc-bridge is-bitcoin-tx-verified bitcoin-tx-hash) ERR_STORAGE_ERROR)

    ;; Get pending transaction data from bridge
    (match (contract-call? .sbtc-bridge get-pending-bitcoin-tx bitcoin-tx-hash)
      pending-tx (begin
        ;; Process ordinals from the transaction
        (var-set sbtc-bridged-ordinals (+ (var-get sbtc-bridged-ordinals) u1))
        (ok bitcoin-tx-hash)
      )
      (ok bitcoin-tx-hash) ;; Transaction already processed
    )
  )
)

;; Update ordinal metadata (proxy to storage)
(define-public (update-ordinal-metadata
  (inscription-id (buff 64))
  (new-metadata-uri (optional (string-utf8 256)))
)
  (contract-call? .ordinals-storage update-ordinal-metadata inscription-id new-metadata-uri)
)

;; Search ordinals with basic filtering
(define-public (search-ordinals
  (owner-filter (optional principal))
  (content-type-filter (optional (string-ascii 50)))
  (min-size (optional uint))
  (max-size (optional uint))
)
  (let (
    (base-results (if (is-some owner-filter)
                    (contract-call? .ordinals-storage get-ordinals-by-owner (unwrap-panic owner-filter))
                    (if (is-some content-type-filter)
                      (contract-call? .ordinals-storage get-ordinals-by-content-type (unwrap-panic content-type-filter))
                      none)))
  )
    ;; Return filtered results (basic implementation)
    (ok base-results)
  )
)

;; Private helper functions

;; Process single ordinal for batch operations
(define-private (process-single-ordinal (ordinal-data {
  inscription-id: (buff 64),
  content-type: (string-ascii 50),
  content-size: uint,
  owner: principal,
  bitcoin-tx-hash: (buff 32),
  bitcoin-block-height: uint,
  metadata-uri: (optional (string-utf8 256))
}))
  (index-ordinal
    (get inscription-id ordinal-data)
    (get content-type ordinal-data)
    (get content-size ordinal-data)
    (get owner ordinal-data)
    (get bitcoin-tx-hash ordinal-data)
    (get bitcoin-block-height ordinal-data)
    (get metadata-uri ordinal-data)
  )
)

;; Admin functions

;; Toggle indexing status
(define-public (toggle-indexing)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set indexing-active (not (var-get indexing-active)))
    (ok (var-get indexing-active))
  )
)

;; Update indexer version
(define-public (update-version (new-version (string-ascii 10)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set indexer-version new-version)
    (ok new-version)
  )
)

;; Reset statistics (emergency function)
(define-public (reset-statistics)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set total-indexed u0)
    (var-set successful-indexes u0)
    (var-set failed-indexes u0)
    (var-set last-indexed-block u0)
    (ok true)
  )
)

;; Get enhanced indexing statistics with Bitcoin integration
(define-read-only (get-indexing-stats)
  {
    total: (var-get total-indexed),
    successful: (var-get successful-indexes),
    failed: (var-get failed-indexes),
    batch-operations: (var-get batch-operations),
    total-batch-items: (var-get total-batch-items),
    bitcoin-verified: (var-get bitcoin-verified-ordinals),
    sbtc-bridged: (var-get sbtc-bridged-ordinals),
    last-bitcoin-sync: (var-get last-bitcoin-sync-height),
    success-rate: (if (> (var-get total-indexed) u0)
                    (/ (* (var-get successful-indexes) u100) (var-get total-indexed))
                    u0),
    bitcoin-verification-rate: (if (> (var-get total-indexed) u0)
                                 (/ (* (var-get bitcoin-verified-ordinals) u100) (var-get total-indexed))
                                 u0),
    batch-enabled: (var-get batch-indexing-enabled),
    sbtc-integration-enabled: (var-get sbtc-integration-enabled),
    avg-batch-size: (if (> (var-get batch-operations) u0)
                      (/ (var-get total-batch-items) (var-get batch-operations))
                      u0)
  }
)

;; Toggle batch indexing
(define-public (toggle-batch-indexing)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set batch-indexing-enabled (not (var-get batch-indexing-enabled)))
    (ok (var-get batch-indexing-enabled))
  )
)

;; Toggle sBTC integration
(define-public (toggle-sbtc-integration)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set sbtc-integration-enabled (not (var-get sbtc-integration-enabled)))
    (ok (var-get sbtc-integration-enabled))
  )
)

;; Get storage contract statistics
(define-read-only (get-storage-stats)
  (contract-call? .ordinals-storage get-storage-statistics)
)

;; Get sBTC bridge statistics
(define-read-only (get-sbtc-bridge-stats)
  (contract-call? .sbtc-bridge get-bridge-statistics)
)

;; Get comprehensive system status
(define-read-only (get-system-status)
  {
    indexer: (get-indexer-status),
    indexing-stats: (get-indexing-stats),
    storage-stats: (get-storage-stats),
    bridge-stats: (get-sbtc-bridge-stats)
  }
)
