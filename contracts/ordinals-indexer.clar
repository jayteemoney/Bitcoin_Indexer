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

;; Data Variables
(define-data-var indexer-version (string-ascii 10) "1.0.0")
(define-data-var indexing-active bool true)
(define-data-var last-indexed-block uint u0)

;; Indexing Statistics
(define-data-var total-indexed uint u0)
(define-data-var successful-indexes uint u0)
(define-data-var failed-indexes uint u0)

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

;; Batch index multiple ordinals
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
    (results (map process-single-ordinal ordinals-list))
  )
    ;; Only contract owner can batch index
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (ok results)
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

;; Get indexing statistics
(define-read-only (get-indexing-stats)
  {
    total: (var-get total-indexed),
    successful: (var-get successful-indexes),
    failed: (var-get failed-indexes),
    success-rate: (if (> (var-get total-indexed) u0)
                    (/ (* (var-get successful-indexes) u100) (var-get total-indexed))
                    u0)
  }
)
